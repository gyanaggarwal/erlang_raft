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

-module(er_raft_state).

-export([update_state/2,
         init_state/1,
         update_vote/1,
         update_log_entry/1,
         update_leader_info/2]).

-include("er_fsm.hrl").

update_state(Snapshot, State) ->
  State1 = update_state_machine(Snapshot, State),
  State2 = update_voted_for(Snapshot, State1),
  update_log_entries(Snapshot, State2).

update_state_machine(#er_snapshot{state_machine={Term, Index, _Data}}, State) ->
  State#er_raft_state{commit_term=Term, commit_index=Index, applied_term=Term, applied_index=Index};
update_state_machine(_, State) ->
  State.

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
                          prev_log_index=NewIndex};
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