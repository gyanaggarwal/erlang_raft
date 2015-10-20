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

-module(er_snapshot).

-export([raft_snapshot/1, 
         raft_log_entry/1, 
         raft_vote/1]).

-include("er_fsm.hrl").

-spec raft_snapshot(AppConfig :: #er_app_config{}) -> {ok, #er_snapshot{}}.
raft_snapshot(AppConfig) ->
  RequestSnapshot = #er_snapshot{state_machine=?ER_REQUEST, log_entries=?ER_REQUEST, log_stats=?ER_REQUEST, voted_for=?ER_REQUEST},
  read_snapshot(AppConfig, RequestSnapshot).

-spec raft_log_entry(AppConfig :: #er_app_config{}) -> {ok, #er_snapshot{}}.
raft_log_entry(AppConfig) ->
  RequestSnapshot = #er_snapshot{state_machine=?ER_REQUEST, log_entries=?ER_REQUEST, log_stats=?ER_REQUEST},
  read_snapshot(AppConfig, RequestSnapshot).

-spec raft_vote(AppConfig :: #er_app_config{}) -> {ok, #er_snapshot{}}.
raft_vote(AppConfig) ->
  RequestSnapshot = #er_snapshot{voted_for=?ER_REQUEST},
  read_snapshot(AppConfig, RequestSnapshot).

-spec read_state_machine(AppConfig :: #er_app_config{}, Snapshot :: #er_snapshot{}) ->  #er_snapshot{}.
read_state_machine(AppConfig, Snapshot) ->
  case Snapshot#er_snapshot.state_machine of
    ?ER_REQUEST ->
      StateMachine = er_fsm_config:get_state_machine_api(AppConfig),
      Snapshot#er_snapshot{state_machine=StateMachine:read()};
    _Other      ->
      Snapshot
  end.

-spec read_voted_for(AppConfig :: #er_app_config{}, Snapshot :: #er_snapshot{}) -> #er_snapshot{}.
read_voted_for(AppConfig, Snapshot) ->
  case Snapshot#er_snapshot.voted_for of
    ?ER_REQUEST ->
      Vote1 = case er_persist_data_api:read_vote(AppConfig) of
                ?ER_EMPTY   -> ?ER_EMPTY;
                {ok, Vote}  -> Vote
              end,
      Snapshot#er_snapshot{voted_for=Vote1};
    _Other      ->
      Snapshot
  end.

-spec read_log_entries(AppConfig :: #er_app_config{}, Snapshot :: #er_snapshot{}) -> #er_snapshot{}.
read_log_entries(_AppConfig, Snapshot) ->
  case Snapshot#er_snapshot.log_entries of
    ?ER_REQUEST ->
      {ok, Q0, _Status} = er_replicated_log_api:read(),
      case er_queue:is_queue(Q0) of
        true  ->
          Snapshot1 = case Snapshot#er_snapshot.log_stats of
                        ?ER_REQUEST ->
                          Snapshot#er_snapshot{unique_id=Snapshot#er_snapshot.unique_id#er_unique_id{log_entries=er_util:unique_id(Q0)}};
                        _           ->
                          Snapshot
                      end,
          Snapshot1#er_snapshot{log_entries=Q0};
        false ->
          Snapshot#er_snapshot{log_entries=er_queue:new()}
      end;
    _Other      ->
      Snapshot
  end.

-spec read_snapshot(AppConfig :: #er_app_config{}, Snapshot :: #er_snapshot{}) -> {ok, #er_snapshot{}} | {error, atom()}.
read_snapshot(AppConfig, Snapshot) ->
  Snapshot1 = read_state_machine(AppConfig, Snapshot),
  Snapshot2 = read_voted_for(AppConfig, Snapshot1),
  {ok, read_log_entries(AppConfig, Snapshot2)}.
