%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Licensed to the Apache Software Foundation (ASF) under one
% or more contributor license agreements.  See the NOTICE file
% distributed with this work for additional information
% regarding copyright ownership.  The ASF licenses this file
% to you under the Apache License, Version 2.0 (the
% "License"); you may not use this file except in compliance
% with the License.  You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing,
% software distributed under the License is distributed on an
% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
% KIND, either express or implied.  See the License for the
% specific language governing permissions and limitations
% under the License.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


-module(er_entry_util).

-export([make_log_entry/2,
         make_append_entries/3,
         make_install_snapshot/2,
         make_reply/4,
         make_request_vote/1,
         make_leader_info/3,
         equal_list/2]).

-include("er_fsm.hrl").

-record(node_reply, {er_entry_accepted=[], 
                     er_entry_rejected=[],
                     er_request_snapshot=[],
                     er_entry_leader_id=[],
                     er_leader_step_down=[],
                     error=[]}).
 
-spec quorum(NodeList :: list()) -> non_neg_integer().
quorum(NodeList) ->
  QSize = length(NodeList) div 2,
  QSize1 = case lists:member(node(), NodeList) of
             true  -> QSize;
             false -> QSize+1
           end,
  QSize1.

-spec make_request_vote(State :: #er_raft_state{}) -> #er_request_vote{}.
make_request_vote(#er_raft_state{current_term=CurrentTerm, prev_log_term=PrevLogTerm, prev_log_index=PrevLogIndex, config=#er_config{current_config=ConfigEntry}}) ->
  #er_request_vote{vote=#er_vote{term=CurrentTerm+1, candidate_id=node(), prev_log_term=PrevLogTerm, prev_log_index=PrevLogIndex}, config_entry=ConfigEntry}.

-spec make_log_entry(Entry :: #er_cmd_entry{}, State :: #er_raft_state{}) -> #er_log_entry{}.
make_log_entry(#er_cmd_entry{type=?TYPE_CONFIG}=Entry, _State) ->
  #er_log_entry{entry=Entry};
make_log_entry(#er_cmd_entry{type=?TYPE_OP}=Entry, #er_raft_state{current_term=CurrentTerm, prev_log_index=PrevLogIndex}) ->
  #er_log_entry{term=CurrentTerm, index=PrevLogIndex+1, entry=Entry}.

-spec make_append_entries(Type :: ?TYPE_CONFIG | ?TYPE_OP | ?TYPE_NOOP, Entry :: #er_log_entry{}, State :: #er_raft_state{}) -> #er_append_entries{}.
make_append_entries(?TYPE_CONFIG,  Entry=#er_log_entry{}, #er_raft_state{current_term=CurrentTerm, leader_id=LeaderId}=State) ->
  Q0 = er_queue:insert(Entry, er_queue:new()),
  #er_append_entries{type=?TYPE_CONFIG, 
                     leader_info=make_leader_info(LeaderId, CurrentTerm, Entry), 
                     prev_log_term=State#er_raft_state.prev_log_term,
                     prev_log_index=State#er_raft_state.prev_log_index,
                     leader_commit_term=State#er_raft_state.commit_term,
                     leader_commit_index=State#er_raft_state.commit_index,
                     log_entries=Q0};
make_append_entries(?TYPE_NOOP,  _Entry, #er_raft_state{current_term=CurrentTerm, leader_id=LeaderId, config=#er_config{current_config=ConfigEntry}}) ->
  #er_append_entries{type=?TYPE_NOOP, leader_info=make_leader_info(LeaderId, CurrentTerm, ConfigEntry)};
make_append_entries(?TYPE_OP, Entry=#er_log_entry{}, State=#er_raft_state{}) ->
  Q0 = er_queue:insert(Entry, er_queue:new()),
  #er_append_entries{type=?TYPE_OP,
                     leader_info=make_leader_info(State#er_raft_state.leader_id, State#er_raft_state.current_term, State#er_raft_state.config#er_config.current_config),
                     prev_log_term=State#er_raft_state.prev_log_term,
                     prev_log_index=State#er_raft_state.prev_log_index,
                     leader_commit_term=State#er_raft_state.commit_term,
                     leader_commit_index=State#er_raft_state.commit_index,
                     log_entries=Q0}.  

-spec make_install_snapshot(Snapshot :: #er_snapshot{}, State :: #er_raft_state{}) -> #er_snapshot{}.
make_install_snapshot(Snapshot, #er_raft_state{leader_id=LeaderId, current_term=CurrentTerm, config=#er_config{current_config=ConfigEntry}}) ->
  Snapshot#er_snapshot{leader_info=make_leader_info(LeaderId, CurrentTerm, ConfigEntry)}.

-spec make_reply({Replies :: list(), BadNodes :: list()}, Config :: #er_config{}, OptimisticMode :: boolean(), FinalFlag :: boolean()) -> term().
make_reply({Replies, _BadNodes}, Config, OptimisticMode, FinalFlag) ->
  NodeReply = make_node_reply(Replies, #node_reply{}),
  ConfigList = config_node_list(Config),
  case Config#er_config.status of 
    ?ER_STABLE        -> 
      make_output_reply(NodeReply, ConfigList, FinalFlag, OptimisticMode);
    ?ER_CONFIG_CHANGE ->
       {_, ConfigList2} = ConfigList,
       NodeReply2 = filter_node_reply(NodeReply, ConfigList2),
       make_output_reply(NodeReply2, ConfigList2, FinalFlag, OptimisticMode)
%      {ConfigList1, ConfigList2} = ConfigList,
%      NodeReply1 = filter_node_reply(NodeReply, ConfigList1),
%      NodeReply2 = filter_node_reply(NodeReply, ConfigList2),
%      Reply1 = make_output_reply(NodeReply1, ConfigList1, FinalFlag, OptimisticMode),
%      Reply2 = make_output_reply(NodeReply2, ConfigList2, FinalFlag, OptimisticMode),
%      case {Reply1, Reply2} of
%        {{ok, _}, {ok, _}}                                                     ->
%          Reply1;
%        {{error, {?ER_LEADER_STEP_DOWN, _, LeaderTerm1}}, {error, {?ER_LEADER_STEP_DOWN, _, LeaderTerm2}}} when LeaderTerm1 > LeaderTerm2 ->
%          Reply1;
%        {{error, {?ER_LEADER_STEP_DOWN,	_, _}}, {error, {?ER_LEADER_STEP_DOWN, _, _}}}  ->
%          Reply2;
%        {{error, _}, _}                                                        ->
%          Reply1;
%        {_, {error, _}}                                                        ->
%          Reply2
%      end
  end.

-spec make_node_reply(Replies :: list(),  NodeReply :: #node_reply{}) -> #node_reply{}.
make_node_reply([{Node, Reply} | TReplies], NodeReply) ->
  NewNodeReply = case Reply of
                   ?ER_ENTRY_ACCEPTED                           ->
                     NodeReply#node_reply{er_entry_accepted=[{Node, Reply} | NodeReply#node_reply.er_entry_accepted]};
                   {?ER_LEADER_STEP_DOWN, LeaderId, LeaderTerm} ->
                     NodeReply#node_reply{er_leader_step_down=[{Node, {LeaderId, LeaderTerm}} | NodeReply#node_reply.er_leader_step_down]}; 
                   ?ER_ENTRY_REJECTED                           ->
      		     NodeReply#node_reply{er_entry_rejected=[Node | NodeReply#node_reply.er_entry_rejected]};
                   ?ER_REQUEST_SNAPSHOT                         ->
      		     NodeReply#node_reply{er_request_snapshot=[Node | NodeReply#node_reply.er_request_snapshot]};
                   {?ER_ENTRY_LEADER_ID, LeaderId}              ->
      		     NodeReply#node_reply{er_entry_leader_id=[{Node, LeaderId} | NodeReply#node_reply.er_entry_leader_id]};
                   {error, Reason}                              ->
      		     NodeReply#node_reply{error=[{Node, Reason} | NodeReply#node_reply.error]}
                 end,
  make_node_reply(TReplies, NewNodeReply);
make_node_reply([], NodeReply) ->
  NodeReply.

-spec make_output_reply(NodeReply :: #node_reply{}, ConfigList :: list(), FinalFlag :: boolean(), OptimisticMode :: boolean()) -> {ok, er_entry_accepted} |
                                                                                                                                  {error, er_unavailable} |
                                                                                                                                  {error, er_quorum_unreachable} |
                                                                                                                                  {error, {er_entry_leader_id, atom()}} |
                                                                                                                                  {error, {er_leader_step_down, atom(), non_neg_integer()}} |
                                                                                                                                  {install_snapshot, {list(), list()}}.
make_output_reply(NodeReply, ConfigList, FinalFlag, OptimisticMode) ->
  Quorum = quorum(ConfigList),
  case {total_reply(NodeReply) >= Quorum, length(NodeReply#node_reply.er_entry_leader_id) > 0, length(NodeReply#node_reply.er_leader_step_down) > 0} of
    {false, _, _}        ->
      {error, ?ER_QUORUM_UNREACHABLE};
    {true, true, _}      ->
      [{_, LeaderId} | _] = NodeReply#node_reply.er_entry_leader_id,  
      {error, {?ER_ENTRY_LEADER_ID, LeaderId}};
    {true, false, true}  ->
      [{_, LeaderId, LeaderTerm} | _] = NodeReply#node_reply.er_leader_step_down,
      {error, {?ER_LEADER_STEP_DOWN, LeaderId, LeaderTerm}};
    {true, false, false} ->
      LenAccepted = length(NodeReply#node_reply.er_entry_accepted),
      LenSnapshot = length(NodeReply#node_reply.er_request_snapshot),
      case {FinalFlag, OptimisticMode, LenAccepted >= Quorum, (LenAccepted+LenSnapshot) >= Quorum, LenSnapshot > 0} of
        {true, _, true, _, _}            ->
          {ok, ?ER_ENTRY_ACCEPTED};
        {true, _, false, _, _}           ->
          {error, ?ER_UNAVAILABLE};
        {false, _, _, false, _}          ->
          {error, ?ER_UNAVAILABLE};
        {false, true, true, _, _}        ->
          {ok, ?ER_ENTRY_ACCEPTED};
        {false, false, true, _, false}   ->
          {ok, ?ER_ENTRY_ACCEPTED};
        {false, true, false, true, true} ->
          {?INSTALL_SNAPSHOT, {NodeReply#node_reply.er_entry_accepted, NodeReply#node_reply.er_request_snapshot}};
        {false, false, _, true, true}    ->
          {?INSTALL_SNAPSHOT, {NodeReply#node_reply.er_entry_accepted, NodeReply#node_reply.er_request_snapshot}}
      end
  end.
        
-spec total_reply(NodeReply :: #node_reply{}) -> non_neg_integer().
total_reply(NodeReply) ->
  length(NodeReply#node_reply.er_entry_accepted)+
  length(NodeReply#node_reply.er_entry_rejected)+
  length(NodeReply#node_reply.er_request_snapshot)+
  length(NodeReply#node_reply.er_entry_leader_id)+
  length(NodeReply#node_reply.er_leader_step_down)+
  length(NodeReply#node_reply.error).
  
-spec intersection(List1 :: list(), ConfigList :: list(), OutList :: list()) -> list().
intersection([Node | TList], ConfigList, OutList) ->
  NewOutList = case lists:member(Node, ConfigList) of
                 true  ->
                   [Node | OutList];
                 false ->
                   OutList
               end,
  intersection(TList, ConfigList, NewOutList);
intersection([], _ConfigList, OutList) ->
  OutList.

-spec key_intersection(List1 :: list(), ConfigList :: list(), OutList :: list()) -> list().
key_intersection([{Node, Value} | TList], ConfigList, OutList) ->
  NewOutList = case lists:member(Node, ConfigList) of
                 true  ->
                   [{Node, Value} | OutList];
                 false ->
                   OutList
               end,
  key_intersection(TList, ConfigList, NewOutList);
key_intersection([], _ConfigList, OutList) ->
  OutList.

-spec filter_node_reply(NodeReply :: #node_reply{}, ConfigList :: list()) -> #node_reply{}. 
filter_node_reply(NodeReply, ConfigList) ->
  NodeReply#node_reply{er_entry_accepted=key_intersection(NodeReply#node_reply.er_entry_accepted, ConfigList, []),
                       er_entry_rejected=intersection(NodeReply#node_reply.er_entry_rejected, ConfigList, []),
                       er_request_snapshot=intersection(NodeReply#node_reply.er_request_snapshot, ConfigList, []),
                       er_entry_leader_id=key_intersection(NodeReply#node_reply.er_entry_leader_id, ConfigList, []),
                       error=key_intersection(NodeReply#node_reply.error, ConfigList, [])}.

-spec config_node_list(Config :: #er_config{}) -> list() | {list(), list()}.
config_node_list(#er_config{status=?ER_UNDEFINED}) ->
  [];
config_node_list(#er_config{status=?ER_STABLE, current_config=CurrentConfig}) ->
  er_util:config_list(CurrentConfig);
config_node_list(#er_config{status=?ER_CONFIG_CHANGE, current_config=CurrentConfig, new_config=NewConfig}) ->
  {er_util:config_list(CurrentConfig), er_util:config_list(NewConfig)};
config_node_list(_) ->
  [].

-spec equal_list(List1 :: list(), List2 :: list()) -> boolean().
equal_list(List1, List2) ->
  case length(List1) =:= length(List2) of
    true  ->
      List3 = intersection(List1, List2, []),
      length(List3) =:= length(List1);
    false -> 
      false
  end.

-spec make_leader_info(LeaderId :: atom(), LeaderTerm :: non_neg_integer(), ConfigEntry :: #er_log_entry{}) -> #er_leader_info{}.
make_leader_info(LeaderId, LeaderTerm, ConfigEntry) ->
  #er_leader_info{leader_id=LeaderId, leader_term=LeaderTerm, config_entry=ConfigEntry}.
