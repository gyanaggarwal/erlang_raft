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

-module(erlang_raft).

-export([log_entry/2, 
         log_entry/3, 
         config_entry/1, 
         config_entry/2, 
         get_status/1,
         set_status/2, 
         start/0, 
         stop/0,
         start_test_env/0,
         stop_test_env/0,
         raft_test/0]).

-include("er_fsm.hrl").

-define(ER_TEST_SERVER, er_test_server).

-spec log_entry(Id :: term(), Cmd :: term()) -> term().
log_entry(Id, Cmd) ->
  CmdEntry = cmd_entry(?TYPE_OP, Id, Cmd),
  call_entry({?LOG_ENTRY, CmdEntry}).

-spec config_entry(List :: list()) -> term().
config_entry(List) ->
  CmdEntry = cmd_entry(?TYPE_CONFIG, List),
  call_entry({?CONFIG_ENTRY, CmdEntry}).

-spec log_entry(Node :: atom(), Id :: term(), Cmd :: term()) -> term().
log_entry(Node, Id, Cmd) ->
  CmdEntry = cmd_entry(?TYPE_OP, Id, Cmd),
  call_entry(Node, {?LOG_ENTRY, CmdEntry}).

-spec config_entry(Node :: atom(), List :: list()) -> term().
config_entry(Node, List) ->
  CmdEntry = cmd_entry(?TYPE_CONFIG, List),
  call_entry(Node, {?CONFIG_ENTRY, CmdEntry}).

-spec get_status(Node :: atom()) -> {atom(), #er_raft_state{}}.
get_status(Node) ->
  call_entry(Node, ?GET_RAFT_SERVER_STATE).

-spec set_status(Node :: atom(), StateList :: list()) -> ok.
set_status(Node, StateList) ->
  call_entry(Node, {?SET_RAFT_SERVER_STATE, StateList}).

-spec call_entry(Request :: term()) -> term().
call_entry(Request) ->
  case gen_server:call(?ER_RAFT_SERVER, Request) of 
    {error, {_, Node}} ->
      gen_server:call({?ER_RAFT_SERVER, Node}, Request);
    Reply              ->
      Reply
  end.
 
-spec call_entry(Node :: atom(), Request :: term()) -> term().
call_entry(Node, Request) ->
  case gen_server:call({?ER_RAFT_SERVER, Node}, Request) of
    {error, {_, LeaderNode}} ->
      gen_server:call({?ER_RAFT_SERVER, LeaderNode}, Request);
    Reply                    ->
      Reply
  end.

-spec cmd_entry(Type :: ?TYPE_OP | ?TYPE_CONFIG, Id :: term(), Cmd :: term()) -> #er_cmd_entry{}.
cmd_entry(Type, Id, Cmd) ->
  #er_cmd_entry{type=Type, id=Id, cmd=Cmd}. 

-spec cmd_entry(Type :: ?TYPE_OP | ?TYPE_CONFIG, Cmd :: term()) -> #er_cmd_entry{}.
cmd_entry(Type, Cmd) ->
  #er_cmd_entry{type=Type, cmd=Cmd}.

start() ->
  application:start(state_machine),
  application:start(erlang_raft).

stop() ->
  application:stop(erlang_raft),
  application:stop(state_machine).

start_test_env() ->
  application:start(erlang_raft_test).

stop_test_env() ->
  application:stop(erlang_raft_test).

raft_test() ->
  gen_server:call(?ER_TEST_SERVER, raft_test).