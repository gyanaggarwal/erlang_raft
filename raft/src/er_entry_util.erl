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

-module(er_entry_util).

-export([make_log_entry/2,
         make_append_entries/3,
         make_install_snapshot/2,
         make_reply/4,
         make_request_vote/1,
         make_leader_info/3]).

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
make_request_vote(#er_raft_state{current_term=CurrentTerm, prev_log_term=PrevLogTerm, prev_log_index=PrevLogIndex, config_entry=ConfigEntry}) ->
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
make_append_entries(?TYPE_NOOP,  _Entry, #er_raft_state{current_term=CurrentTerm, leader_id=LeaderId, config_entry=ConfigEntry}) ->
  #er_append_entries{type=?TYPE_NOOP, leader_info=make_leader_info(LeaderId, CurrentTerm, ConfigEntry)};
make_append_entries(?TYPE_OP, Entry=#er_log_entry{}, State=#er_raft_state{}) ->
  Q0 = er_queue:insert(Entry, er_queue:new()),
  #er_append_entries{type=?TYPE_OP,
                     leader_info=make_leader_info(State#er_raft_state.leader_id, State#er_raft_state.current_term, State#er_raft_state.config_entry),
                     prev_log_term=State#er_raft_state.prev_log_term,
                     prev_log_index=State#er_raft_state.prev_log_index,
                     prev_log_type=State#er_raft_state.prev_log_type,
                     leader_commit_term=State#er_raft_state.commit_term,
                     leader_commit_index=State#er_raft_state.commit_index,
                     log_entries=Q0}.  

-spec make_install_snapshot(Snapshot :: #er_snapshot{}, State :: #er_raft_state{}) -> #er_snapshot{}.
make_install_snapshot(Snapshot, #er_raft_state{leader_id=LeaderId, current_term=CurrentTerm, config_entry=ConfigEntry}) ->
  Snapshot#er_snapshot{leader_info=make_leader_info(LeaderId, CurrentTerm, ConfigEntry)}.

-spec make_reply({Replies :: list(), BadNodes :: list()}, ConfigEntry :: #er_log_entry{}, OptimisticMode :: boolean(), FinalFlag :: boolean()) -> term().
make_reply({Replies, _BadNodes}, ConfigEntry, OptimisticMode, FinalFlag) ->
  NodeReply = make_node_reply(Replies, #node_reply{}),
  ConfigList = er_util:config_list(ConfigEntry),
  make_output_reply(NodeReply, ConfigList, FinalFlag, OptimisticMode).

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
  
-spec make_leader_info(LeaderId :: atom(), LeaderTerm :: non_neg_integer(), ConfigEntry :: #er_log_entry{}) -> #er_leader_info{}.
make_leader_info(LeaderId, LeaderTerm, ConfigEntry) ->
  #er_leader_info{leader_id=LeaderId, leader_term=LeaderTerm, config_entry=ConfigEntry}.
