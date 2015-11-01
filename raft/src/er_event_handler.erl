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

handle_event({state, {Module, Msg, StateData=#er_raft_state{}}}, State) ->
  io:format("[~p] ~p status=~p, leader_id=~p, current_term=~p, prev_log_term=~p, prev_log_index=~p, prev_log_type=~p, commit_term=~p, commit_index=~p, applied_term=~p, applied_index=~p~n",
            [Module,                                 Msg, 
             StateData#er_raft_state.status,         StateData#er_raft_state.leader_id,     
             StateData#er_raft_state.current_term,   StateData#er_raft_state.prev_log_term,             
             StateData#er_raft_state.prev_log_index, StateData#er_raft_state.prev_log_type,
             StateData#er_raft_state.commit_term,    StateData#er_raft_state.commit_index,
             StateData#er_raft_state.applied_term,   StateData#er_raft_state.applied_index]),
  {ok, State};
handle_event({data, {Module, Msg, DataMsg, Data}}, State) ->
  io:format("[~p] ~p ~p=~p~n", [Module, Msg, DataMsg, Data]),
  {ok, State}.



