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

-module(er_event_handler).

-behavior(gen_event).

-export([add_handler/0, delete_handler/0]).

-export([init/1, handle_call/2, handle_info/2, handle_event/2, terminate/2, code_change/3]).

-include("er_fsm.hrl").

add_handler() ->
  er_event:add_handler(?MODULE, []).

delete_handler() ->
  er_event:delete_handler(?MODULE, []).

init(State) ->
  {ok, State}.

terminate(_Args, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

handle_call(_Request, State) ->
  {ok, ok, State}.

handle_info(_Info, State) ->
  {ok, State}.

handle_event({state, {Msg, StateData=#er_raft_state{}}}, State) ->
  io:format("~p status=~p, leader_id=~p, log_entry_count=~p, current_term=~p, prev_log_term=~p, prev_log_index=~p, commit_term=~p, commit_index=~p, applied_term=~p, applied_index=~p~n",
            [Msg, 
             StateData#er_raft_state.status,          StateData#er_raft_state.leader_id,     
             StateData#er_raft_state.log_entry_count, StateData#er_raft_state.current_term,               
             StateData#er_raft_state.prev_log_term,   StateData#er_raft_state.prev_log_index,
             StateData#er_raft_state.commit_term,     StateData#er_raft_state.commit_index,
             StateData#er_raft_state.applied_term,    StateData#er_raft_state.applied_index]),
  {ok, State};
handle_event({data, {Msg, DataMsg, Data}}, State) ->
  io:format("~p ~p=~p~n", [Msg, DataMsg, Data]),
  {ok, State}.



