%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Copyright (c) 2015 Gyanendra Aggarwal.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(er_raft_server).

-behavior(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

-include("er_fsm.hrl").

-define(SERVER, ?MODULE).

start_link(AppConfig) ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [AppConfig], []).

init([AppConfig]) ->
  State = er_raft_state:update_vote(#er_raft_state{app_config=AppConfig}),
  random:seed(erlang:phash2([node()]), erlang:monotonic_time(), erlang:unique_integer()),
  {ok, State, get_timeout(?ER_ENTRY_ACCEPTED, State)}.

handle_call({?LOG_ENTRY, CmdEntry}, _From, #er_raft_state{status=?ER_LEADER}=State) ->
  event_state("log_entry.00", State),
  NewState1 = er_raft_state:update_log_entry(State),
  LogEntry = er_entry_util:make_log_entry(CmdEntry, NewState1),
  {NewReply4, NewState4} = case er_util:validate_log_entry_id(LogEntry, NewState1#er_raft_state.unique_id) of
                             false ->
                               {{error, ?ER_ENTRY_DUPLICATE}, NewState1};
                             true  ->
                               AppendEntries = er_entry_util:make_append_entries(?TYPE_OP, LogEntry, NewState1),
                               process_leader_log_entry(AppendEntries, NewState1)
                           end,
  event_reply("log_entry.99", NewReply4),
  event_state("log_entry.99", NewState4),
  {reply, NewReply4, NewState4, get_timeout(NewReply4, NewState4)};

handle_call({?CONFIG_ENTRY, CmdEntry}, _From, #er_raft_state{status=?ER_NOT_IN_CONFIG}=State) ->
  event_state("config_entry.00", State),
  LogEntry = er_entry_util:make_log_entry(CmdEntry, State),
  AppendEntries = er_entry_util:make_append_entries(?TYPE_CONFIG, LogEntry, State),
  NewState = update_config(LogEntry, State),
  {NewReply2, NewState2} = case NewState#er_raft_state.status of
                             ?ER_FOLLOWER ->
                               NewReply = er_raft_peer_api:append_entries_config(AppendEntries),
                               NewReply1 = er_entry_util:make_reply(NewReply, NewState#er_raft_state.config_entry, er_fsm_config:get_optimistic_mode(NewState#er_raft_state.app_config), true),
                               case NewReply1 of 
                                 {ok, _}                                      ->
                                   {{ok, ?ER_CONFIG_ACCEPTED}, NewState};
                                 {error, _}                                   ->
                                   {NewReply1, State} 
                               end;
                             _            ->
                               {{error, ?ER_UNAVAILABLE}, State}
                           end,
  event_reply("config_entry.99", NewReply2),
  event_state("config_entry.99", NewState2),
  {reply, NewReply2, NewState2, get_timeout(NewReply2, NewState2)};
handle_call({?CONFIG_ENTRY, CmdEntry}, _From, #er_raft_state{status=?ER_LEADER}=State) ->
  event_state("config_entry.00", State),
  LogEntry = er_entry_util:make_log_entry(CmdEntry, State),
  CurrentConfigEntry = State#er_raft_state.config_entry,
  {NewReply2, NewState2} = case er_util:equal_list(er_util:config_list(LogEntry), er_util:config_list(CurrentConfigEntry)) of
                             true  ->
                               {{ok, ?ER_CONFIG_ACCEPTED}, State};
                             false ->
                               AppendEntries = er_entry_util:make_append_entries(?TYPE_CONFIG, LogEntry, State),
                               NewState = update_config(LogEntry, State),
                               NewReply = er_raft_peer_api:append_entries_config(AppendEntries),
                               process_leader_entry(NewReply, ?ER_CONFIG_ACCEPTED, ?ER_CONFIG_REJECTED, fun update_config_entry_leader_state/1, NewState)
                           end, 
  event_reply("config_entry.99", NewReply2),
  event_state("config_entry.99", NewState2),
  {reply, NewReply2, NewState2, get_timeout(NewReply2, NewState2)};

handle_call({?PEER_REQUEST_VOTE, #er_request_vote{vote=Vote, config_entry=ConfigEntry}}, _From, #er_raft_state{status=Status}=State) when Status =/= ?ER_LEADER ->
  event_state("peer_request_vote.00", State),
  NewState = update_config(ConfigEntry, State),
  {NewReply2, NewState2} = process_vote(Vote, NewState),
  event_reply("peer_request_vote.99", NewReply2),
  event_state("peer_request_vote.99", NewState2),
  {reply, NewReply2, NewState2, get_timeout(NewReply2, NewState2)};

handle_call({?PEER_APPEND_ENTRIES_OP, #er_append_entries{leader_info=LeaderInfo,
                                                         prev_log_term=EntryPrevLogTerm,
                                                         prev_log_index=EntryPrevLogIndex}=AppendEntries}, 
            _From, 
            #er_raft_state{status=Status, 
                           leader_id=StateLeaderId, 
                           current_term=StateCurrentTerm,
                           prev_log_term=StatePrevLogTerm,
                           prev_log_index=StatePrevLogIndex}=State) when Status =/= ?ER_LEADER ->
  event_state("peer_append_entries_op.00", State),
  {NewReply4, NewState4} = case (StateCurrentTerm > LeaderInfo#er_leader_info.leader_term) of
                             true  ->
                               {{error, ?ER_LEADER_STEP_DOWN, StateLeaderId, StateCurrentTerm}, State};
                             false ->
                               NewState1 = er_raft_state:update_log_entry(update_leader_info(LeaderInfo, State#er_raft_state{status=get_peer_status(State#er_raft_state.status)})),
                               case (StatePrevLogTerm =:= EntryPrevLogTerm andalso StatePrevLogIndex =:= EntryPrevLogIndex) of
                                 true  ->
                                   process_peer_log_entry(AppendEntries, NewState1);
                                 false ->  
                                   {?ER_REQUEST_SNAPSHOT, NewState1}
                               end
                           end,  
  event_reply("peer_append_entries_op.99", NewReply4),
  event_state("peer_append_entries_op.99", NewState4),
  {reply, NewReply4, NewState4, get_timeout(NewReply4, NewState4)};

handle_call({?PEER_APPEND_ENTRIES_CONFIG, #er_append_entries{leader_info=LeaderInfo}=AppendEntries}, _From, #er_raft_state{status=?ER_NOT_IN_CONFIG}=State) ->
  event_state("peer_append_entries_config.00", State),
  ConfigEntry = er_util:log_entry_lifo(AppendEntries),
  NewState2 = update_config(ConfigEntry, State),
  NewReply2 = case {LeaderInfo#er_leader_info.leader_id, 
                   (NewState2#er_raft_state.prev_log_term =:= AppendEntries#er_append_entries.prev_log_term andalso 
                    NewState2#er_raft_state.prev_log_index =:= AppendEntries#er_append_entries.prev_log_index)} of
                {undefined, _} ->
                  ?ER_ENTRY_ACCEPTED;
                {_, true}      ->
                  ?ER_ENTRY_ACCEPTED; 
                {_, false}     ->
                  ?ER_REQUEST_SNAPSHOT
              end,
  event_reply("peer_append_entries_config.99", NewReply2),
  event_state("peer_append_entries_config.99", NewState2),
  {reply, NewReply2, NewState2, get_timeout(NewReply2, NewState2)};

handle_call({?PEER_APPEND_ENTRIES_CONFIG, #er_append_entries{leader_info=LeaderInfo}}, _From, #er_raft_state{status=?ER_FOLLOWER, leader_id=LeaderId, current_term=CurrentTerm}=State) when LeaderId =/= undefined ->
  event_state("peer_append_entries_config.00", State),
  {NewReply2, NewState2} = case (CurrentTerm > LeaderInfo#er_leader_info.leader_term) of
                             true  ->
                               {{error, {?ER_LEADER_STEP_DOWN, LeaderId, CurrentTerm}}, State};
                             false ->
                               {?ER_ENTRY_ACCEPTED, update_leader_info(LeaderInfo, State)}
                           end,
  event_reply("peer_append_entries_config.99", NewReply2),
  event_state("peer_append_entries_config.99", NewState2),
  {reply, NewReply2, NewState2, get_timeout(NewReply2, NewState2)};

handle_call({?PEER_INSTALL_SNAPSHOT, #er_snapshot{leader_info=LeaderInfo, 
                                                  state_machine=StateMachineData, 
                                                  log_entries=LogEntries, 
                                                  voted_for=Vote}=Snapshot}, 
            _From, 
            #er_raft_state{status=Status, app_config=AppConfig}=State) when Status =/= ?ER_LEADER ->
  event_state("peer_install_snapshot.00", State),
  er_persist_data_api:write_vote(AppConfig, Vote),
  StateMachineApi = er_fsm_config:get_state_machine_api(AppConfig),
  StateMachineApi:write(StateMachineData),
  {NewReply2, NewState2} = case er_replicated_log_api:write(LogEntries) of 
                             {ok, _}            ->
                               NewState = update_leader_info(LeaderInfo, State),
                               NewState1 = er_raft_state:update_state(Snapshot, NewState),
                               {?ER_ENTRY_ACCEPTED, NewState1};
                             {error, Reason, _} ->
                               {{error, Reason}, State}
                           end,
  event_reply("peer_install_snapshot.99", NewReply2),
  event_state("peer_install_snapshot.99", NewState2),
  {reply, NewReply2, NewState2, get_timeout(NewReply2, NewState2)};

handle_call(?GET_RAFT_SERVER_STATUS, _From, State) ->
  Reply = [{status,                   State#er_raft_state.status},
           {node_id,                  node()},
           {leader_id,                State#er_raft_state.leader_id},
           {current_term,             State#er_raft_state.current_term},
           {prev_log_term,            State#er_raft_state.prev_log_term},
           {prev_log_index,           State#er_raft_state.prev_log_index},
           {commit_term,              State#er_raft_state.commit_term},
           {commit_index,             State#er_raft_state.commit_index},
           {applied_index,            State#er_raft_state.applied_term},
           {applied_index,            State#er_raft_state.applied_index},
           {vote,                     State#er_raft_state.vote}],
  {reply, Reply, State, get_timeout(?ER_ENTRY_ACCEPTED, State)};

handle_call(_, _From, #er_raft_state{status=?ER_FOLLOWER, leader_id=LeaderId}=State) when LeaderId =/= undefined->
  event_state("follower_call.00", State),
  Reply = {error, {?ER_ENTRY_LEADER_ID, LeaderId}},
  event_reply("follower_call.99", Reply),
  event_state("follower_call.99", State),
  {reply, Reply, State, get_timeout(Reply, State)};
handle_call(_, _From, State) ->
  event_state("other_call.00", State),
  Reply = {error, ?ER_UNAVAILABLE},
  event_reply("other_call.99", Reply),
  event_state("other_call.99", State),
  {reply, Reply, State, get_timeout(Reply, State)}.
  
handle_cast({?PEER_APPEND_ENTRIES_NOOP, #er_append_entries{leader_info=LeaderInfo}}, #er_raft_state{status=Status}=State) when Status =/= ?ER_LEADER ->
  NewState = update_leader_info(LeaderInfo, State),
  NewState2 = NewState#er_raft_state{status=get_peer_status(NewState#er_raft_state.status)},
  {noreply, NewState2, get_timeout(?ER_ENTRY_ACCEPTED, NewState2)};
handle_cast(_, State) ->
  event_state("other_cast.00", State),
  {noreply, State, get_timeout(?ER_ENTRY_ACCEPTED, State)}.

handle_info(timeout, #er_raft_state{status=?ER_FOLLOWER, config_entry=ConfigEntry}=State) when ConfigEntry =/= undefined ->
  event_state("timeout_info.00", State),
  NewState = State#er_raft_state{leader_id=undefined},
  NewState1 = update_status_change(?ER_CANDIDATE, NewState),
  NewState2 = request_vote(NewState1), 
  event_state("timeout_info.99", NewState2),
  {noreply, NewState2, get_timeout(?ER_ENTRY_ACCEPTED, NewState2)};
handle_info(timeout, #er_raft_state{status=?ER_CANDIDATE, config_entry=ConfigEntry}=State) when ConfigEntry =/= undefined ->
  event_state("timeout_info.00", State),
  NewState2 = request_vote(State),
  event_state("timeout_info.99", NewState2),
  {noreply, NewState2, get_timeout(?ER_ENTRY_ACCEPTED, NewState2)};
handle_info(timeout, #er_raft_state{status=?ER_LEADER, config_entry=ConfigEntry}=State) when ConfigEntry =/= undefined ->
  append_entries_noop(State),
  {noreply, State, get_timeout(?ER_ENTRY_ACCEPTED, State)};
handle_info(_, State) ->
  event_state("other_info.00", State),
  {noreply, State, get_timeout(?ER_ENTRY_ACCEPTED, State)}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

terminate(_Reason, _State) ->
  ok.

get_timeout(Reply, #er_raft_state{status=Status, app_config=AppConfig}) ->
  case {Reply, Status} of
    {?ER_REQUEST_SNAPSHOT, _} ->
      infinity;
    {_, ?ER_LEADER}           ->
      er_fsm_config:get_heartbeat_timeout(AppConfig);
    {_, ?ER_FOLLOWER}         ->
      er_util:get_election_timeout(er_fsm_config:get_election_timeout(AppConfig));
    {_, ?ER_CANDIDATE}        -> 
      er_util:get_election_timeout(er_fsm_config:get_election_timeout(AppConfig));
    {_, _}                    ->
      infinity
  end.

update_config(ConfigEntry=#er_log_entry{}, State) ->
  ConfigList = er_util:config_list(ConfigEntry),
  Status1 = case {State#er_raft_state.status, lists:member(node(), ConfigList)} of
              {?ER_NOT_IN_CONFIG, true} ->
                ?ER_FOLLOWER;
              {OtherStatus, true}       ->
                OtherStatus;
              {_, false}                ->
                ?ER_NOT_IN_CONFIG
            end,
  State1 = State#er_raft_state{config_entry=ConfigEntry},
  update_status_change(Status1, State1);
update_config(_, State) ->
  State.

update_leader_info(#er_leader_info{config_entry=ConfigEntry}=LeaderInfo, State) ->
  update_config(ConfigEntry, er_raft_state:update_leader_info(LeaderInfo, State)).

update_status_change(NewStatus, #er_raft_state{status=CurrentStatus}=State) when NewStatus =/= CurrentStatus ->
  event_state("update_status_change.00", State),
  NewState = case {CurrentStatus, NewStatus} of
               {?ER_NOT_IN_CONFIG, ?ER_FOLLOWER}      ->
                 er_raft_state:update_log_entry(State);
               {?ER_FOLLOWER,      ?ER_CANDIDATE}     ->
                 er_raft_state:update_log_entry(State);
               {?ER_CANDIDATE,     ?ER_LEADER}        ->
                 State#er_raft_state{leader_id=node()};
               {_,                 ?ER_NOT_IN_CONFIG} ->
                 er_raft_state:init_state(State);
               {_,                 _}                 ->
                 State
             end,
  NewState1 = NewState#er_raft_state{status=NewStatus},
  event_state("update_status_change.99", NewState1),
  NewState1;
update_status_change(_, State) ->
  State.

get_peer_status(Status) ->
  case Status of
    ?ER_NOT_IN_CONFIG -> ?ER_NOT_IN_CONFIG;
    _                 -> ?ER_FOLLOWER
  end.

request_vote(#er_raft_state{app_config=AppConfig, current_term=CurrentTerm}=State) ->
  RequestVote = er_entry_util:make_request_vote(State),
  ok = er_persist_data_api:write_vote(AppConfig, RequestVote#er_request_vote.vote),
  Reply = er_raft_peer_api:request_vote(RequestVote),
  Reply1 = er_entry_util:make_reply(Reply, State#er_raft_state.config_entry, er_fsm_config:get_optimistic_mode(AppConfig), true),
  Status1 = case Reply1 of
              {ok, _}                         ->
                ?ER_LEADER;
              {error, ?ER_QUORUM_UNREACHABLE} ->
                ?ER_NOT_IN_CONFIG;
              {error, _}                      ->
                ?ER_CANDIDATE
           end,
  NewState1 = State#er_raft_state{current_term=CurrentTerm+1, vote=RequestVote#er_request_vote.vote},
  NewState2 = update_status_change(Status1, NewState1),
  append_entries_noop(NewState2),
  NewState2.

append_entries_noop(#er_raft_state{status=?ER_LEADER}=State) ->
  AppendEntries = er_entry_util:make_append_entries(?TYPE_NOOP, undefined, State),
  er_raft_peer_api:append_entries_noop(AppendEntries);
append_entries_noop(_State) ->
  ok.
  
process_vote(RequestedVote, #er_raft_state{vote=CurrentVote, app_config=AppConfig}=State) ->
  case er_vote:valid(RequestedVote, CurrentVote, State) of
    true  -> er_persist_data_api:write_vote(AppConfig, RequestedVote), 
             {?ER_ENTRY_ACCEPTED, State#er_raft_state{vote=RequestedVote}};
    false -> {?ER_ENTRY_REJECTED, State}
  end.

process_install_snapshot(Replies1, InstallSnapshotNodes, ConfigEntry, FinalFlag, #er_raft_state{app_config=AppConfig}=State) ->
  {ok, RaftSnapshot} = er_snapshot:raft_snapshot(AppConfig),
  RaftSnapshot1 = RaftSnapshot#er_snapshot{leader_info=er_entry_util:make_leader_info(State#er_raft_state.leader_id,
                                                                                      State#er_raft_state.current_term,
                                                                                      ConfigEntry)},
  {Replies2, BadNodes2} = er_raft_peer_api:install_snapshot(InstallSnapshotNodes, RaftSnapshot1),
  er_entry_util:make_reply({Replies1 ++ Replies2, BadNodes2}, ConfigEntry, er_fsm_config:get_optimistic_mode(AppConfig), FinalFlag).

process_leader_entry(Reply1, AcceptMsg, RejectMsg, AcceptFun, #er_raft_state{config_entry=ConfigEntry, app_config=AppConfig}=NewState1) ->
  Reply2 = er_entry_util:make_reply(Reply1, ConfigEntry, er_fsm_config:get_optimistic_mode(AppConfig), false),
  case Reply2 of
    {ok, _}                                                ->
      NewState2 = AcceptFun(NewState1),
      {{ok, AcceptMsg}, NewState2};
    {?INSTALL_SNAPSHOT, {Replies1, InstallSnapshotNodes}}  ->
      Reply3 = process_install_snapshot(Replies1, InstallSnapshotNodes, ConfigEntry, true, NewState1),
      case Reply3 of
        {ok, _} ->
          NewState3 = AcceptFun(NewState1),
          {{ok, AcceptMsg}, NewState3};
        _       ->
          {{error, RejectMsg}, NewState1}
      end;
    {error, {?ER_LEADER_STEP_DOWN, LeaderId, LeaderTerm}} ->
      {{error, {?ER_ENTRY_LEADER_ID, LeaderId}}, 
       update_status_change(?ER_FOLLOWER, NewState1#er_raft_state{leader_id=LeaderId, current_term=LeaderTerm})};
    {error, _}                                            ->
      {{error, RejectMsg}, NewState1}
  end.

process_leader_log_entry(AppendEntries, State) ->
   {ok, NewState1} = append_log_entry(AppendEntries, State),
   Reply1 = er_raft_peer_api:append_entries_op(AppendEntries),
   process_leader_entry(Reply1, ?ER_ENTRY_ACCEPTED, ?ER_UNAVAILABLE, fun update_log_entry_leader_state/1, NewState1).

update_log_entry_leader_state(#er_raft_state{prev_log_term=PrevLogTerm, prev_log_index=PrevLogIndex}=State) ->
  NewState = State#er_raft_state{commit_term=PrevLogTerm, commit_index=PrevLogIndex},
  apply_log_entry(NewState).

update_config_entry_leader_state(State) ->
  State.

process_peer_log_entry(#er_append_entries{leader_commit_term=LeaderCommitTerm,
                                          leader_commit_index=LeaderCommitIndex}=AppendEntries, 
                       State) ->
  case append_log_entry(AppendEntries, State) of
    {ok, NewState} ->
      NewState1 = NewState#er_raft_state{commit_term=LeaderCommitTerm, commit_index=LeaderCommitIndex},
      NewState2 = apply_log_entry(NewState1),
      {?ER_ENTRY_ACCEPTED, NewState2};
    Other          ->
      Other
  end.

append_log_entry(AppendEntries, #er_raft_state{log_entries=LogEntries, unique_id=UniqueId}=State) ->
  LogEntry = er_util:log_entry_lifo(AppendEntries),
  case er_replicated_log_api:append_entry_compact(LogEntry, State) of
    {error, Reason, _}              ->
      {{error, Reason}, State};
    {ok, Q0, S0, _} ->
      {Q2, U2} = case er_queue:is_queue(Q0) of
                   false ->
                     Q1 = er_queue:insert(LogEntry, LogEntries),
                     U1 = er_util:add_log_entry_id(LogEntry, UniqueId),
                     {Q1, U1};
                   true  ->
                     {Q0, UniqueId#er_unique_id{log_entries=S0}}
                 end,
       NewState = State#er_raft_state{prev_log_term=LogEntry#er_log_entry.term,
                                      prev_log_index=LogEntry#er_log_entry.index,
                                      log_entries=Q2,
                                      unique_id=U2},
      {ok, NewState}
  end.

apply_log_entry(#er_raft_state{commit_term=CommitTerm,
                               commit_index=CommitIndex,
                               applied_term=AppliedTerm,
                               applied_index=AppliedIndex,
                               log_entries=LogEntries,
                               app_config=AppConfig}=State) ->
  NewLogEntries = er_util:applied_sub_list(LogEntries, CommitTerm, CommitIndex, AppliedTerm, AppliedIndex, 0, er_queue:new()),
  StateMachineApi = er_fsm_config:get_state_machine_api(AppConfig),
  case StateMachineApi:update(NewLogEntries) of
    {NewAppliedTerm, NewAppliedIndex, _} ->
      State#er_raft_state{applied_term=NewAppliedTerm, applied_index=NewAppliedIndex};
    _                                    ->
      State
  end.

event_state(Msg, State) ->
  er_event:state(?MODULE, Msg, State).

event_reply(Msg, Reply) ->
  er_event:reply(?MODULE, Msg, Reply).

