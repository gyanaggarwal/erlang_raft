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

-module(er_raft_state).

-export([update_state/2,
         init_state/1,
         update_vote/1,
         update_log_entry/1,
         update_leader_info/2]).

-export([get_config_list/2,
         get_not_in_config_list/2,
         get_leader_state/1,
         get_light_weight_state/1,
         validate_config_state/2,
         validate_not_in_config_state/1,
         validate_log_entries_state/3,
         validate_log_index_state/2]).

-include("er_fsm.hrl").

update_state(Snapshot, State) ->
  State1 = update_voted_for(Snapshot, State),
  update_log_entries(Snapshot, State1).

update_voted_for(#er_snapshot{voted_for=Vote}, State) ->
  update_voted_for(Vote, State);
update_voted_for(#er_vote{term=Term}=Vote, State) ->
  State#er_raft_state{vote=Vote, current_term=Term};
update_voted_for(_, State) ->
  State.

update_log_entries(#er_snapshot{log_entries=LogEntries, log_stats=LogStats}=Snapshot, State) ->
  case er_queue:is_queue(LogEntries) of
    true  ->
      UniqueId = case LogStats of
                   ?ER_REQUEST ->
                     State#er_raft_state.unique_id#er_unique_id{log_entries=Snapshot#er_snapshot.unique_id#er_unique_id.log_entries};
                   _           ->
                     State#er_raft_state.unique_id
                 end,
      {NewTerm, NewIndex} = er_util:get_last_term_index(LogEntries),

      State#er_raft_state{unique_id=UniqueId,
                          log_entries=LogEntries,
                          prev_log_term=NewTerm,
                          prev_log_index=NewIndex,
                          prev_log_type=?TYPE_OP};
    false ->
      State
  end.

update_log_entry(#er_raft_state{log_entries=undefined, app_config=AppConfig}=State) ->
  {ok, Snapshot} = er_snapshot:raft_log_entry(AppConfig),
  update_state(Snapshot, State);
update_log_entry(State) ->
  State.

update_vote(#er_raft_state{app_config=AppConfig}=State) ->
  {ok, Snapshot} = er_snapshot:raft_vote(AppConfig),
  update_state(Snapshot, State).

update_leader_info(#er_leader_info{leader_id=LeaderId, leader_term=LeaderTerm}, State) ->
  State#er_raft_state{leader_id=LeaderId, current_term=LeaderTerm}.

init_state(State) ->
  State#er_raft_state{leader_id=undefined}.

quorum(StateList) ->
  length(StateList) div 2.

get_list(StateTupleList, ConfigList, PredFun) ->
  er_util:filter_list(StateTupleList, ConfigList, [], PredFun, fun er_util:acc_tuplelist/2).

get_config_list(StateTupleList, ConfigList) ->
  get_list(StateTupleList, ConfigList, fun er_util:pred_tuplelist/2).

get_not_in_config_list(StateTupleList, ConfigList) ->
  get_list(StateTupleList, ConfigList, fun er_util:pred_not_tuplelist/2).

get_leader_state([#er_raft_state{status=?ER_LEADER}=State | _]) ->
  State;
get_leader_state([_ | Rest]) ->
  get_leader_state(Rest);
get_leader_state([]) ->
  undefined.

get_light_weight_state(State) ->
  #er_raft_state{status         = State#er_raft_state.status,
                 leader_id      = State#er_raft_state.leader_id,
                 current_term   = State#er_raft_state.current_term,
                 prev_log_term  = State#er_raft_state.prev_log_term,
                 prev_log_index = State#er_raft_state.prev_log_index,
                 commit_term    = State#er_raft_state.commit_term,
                 commit_index   = State#er_raft_state.commit_index,
                 applied_term   = State#er_raft_state.applied_term,
                 applied_index  = State#er_raft_state.applied_index,
                 unique_id      = undefined}.

validate_config_state(_, undefined) ->
  {?ER_INVALID_STATE, ?ER_CONFIG_STATE};
validate_config_state([#er_raft_state{status=?ER_LEADER} | Rest], LeaderState) ->
  validate_config_state(Rest, LeaderState);
validate_config_state([#er_raft_state{status=?ER_FOLLOWER, current_term=CurrentTerm, leader_id=LeaderId, prev_log_index=FollowerLogIndex} | Rest], 
                       #er_raft_state{current_term=CurrentTerm, leader_id=LeaderId, prev_log_index=LeaderLogIndex}=LeaderState) when LeaderLogIndex >= FollowerLogIndex ->
  validate_config_state(Rest, LeaderState);
validate_config_state([#er_raft_state{status=?ER_FOLLOWER} | _], _) ->
  {?ER_INVALID_STATE, ?ER_CONFIG_STATE};
validate_config_state([_ | _], _) ->
  {?ER_INVALID_STATE, ?ER_CONFIG_STATE};
validate_config_state([], _) ->
  ?ER_VALID_STATE.

validate_not_in_config_state([#er_raft_state{status=?ER_NOT_IN_CONFIG, leader_id=undefined} | Rest]) ->
  validate_not_in_config_state(Rest);
validate_not_in_config_state([_ | _]) ->
  {?ER_INVALID_STATE, ?ER_NOT_IN_CONFIG_STATE};
validate_not_in_config_state([]) ->
  ?ER_VALID_STATE.

validate_log_entries_state(#er_raft_state{prev_log_index=PrevLogIndex}, #er_raft_state{prev_log_index=CurrLogIndex}, LogEntries) when CurrLogIndex =:= (PrevLogIndex+LogEntries) ->
  ?ER_VALID_STATE;
validate_log_entries_state(_, _, _) ->
  {?ER_INVALID_STATE, ?ER_LOG_ENTRIES_STATE}.

validate_log_index_state(StateList, LeaderState) ->
  validate_log_index_state(StateList, LeaderState, quorum(StateList)).

validate_log_index_state(_, _, 0) ->
  ?ER_VALID_STATE;
validate_log_index_state([#er_raft_state{status=?ER_LEADER} | Rest], LeaderState, Quorum) ->
  validate_log_index_state(Rest, LeaderState, Quorum);
validate_log_index_state([#er_raft_state{status=?ER_FOLLOWER, prev_log_index=PrevLogIndex, commit_index=FollowerCommitIndex} | Rest],
                          #er_raft_state{prev_log_index=PrevLogIndex, commit_index=LeaderCommitIndex}=LeaderState,
                          Quorum) when LeaderCommitIndex >= FollowerCommitIndex andalso FollowerCommitIndex >= (LeaderCommitIndex-1) ->
  validate_log_index_state(Rest, LeaderState, Quorum-1);
validate_log_index_state([_ | Rest], LeaderState, Quorum) ->
  validate_log_index_state(Rest, LeaderState, Quorum); 
validate_log_index_state([], _, _) ->
  {?ER_INVALID_STATE, ?ER_LOG_INDEX_STATE}.





