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

-module(erlang_raft_test).

-export([get_state/1,
         set_state/2,
         copy_state/2,
         raft_test/9,
         raft_test/0,
         test_print/1]).

-include("er_fsm.hrl").
-include("er_test.hrl").

-define(RAFT_NODES,         [er_n1, er_n2, er_n3, er_n4, er_n5]).
-define(INITIAL_NODES,      [er_n1, er_n2, er_n3]).
-define(SLEEP_TIME,         5000).
-define(CONFIG_CHANGE_MIN,  50).
-define(CONFIG_CHANGE_MAX,  70).
-define(FULL_CONFIG_CHANGE, 7).
-define(LOG_ENTRIES_MIN,    20).
-define(LOG_ENTRIES_MAX,    50).
-define(RESULT_FILE_NAME,   "raft_test_results.txt").

-spec get_state(Nodes :: list()) -> list().
get_state(Nodes) ->
  {Replies, _} = gen_server:multi_call(Nodes, ?ER_RAFT_SERVER, ?GET_RAFT_SERVER_STATE),
  Replies.

-spec set_state(Nodes :: list(), StateList :: list()) -> list().
set_state(Nodes, {StateList, FileVersion}) ->
  {Replies, _} = gen_server:multi_call(Nodes, ?ER_RAFT_SERVER, {?SET_RAFT_SERVER_STATE, {StateList, FileVersion}}),
  Replies.

-spec copy_state(Nodes :: list(), {DeleteRaftData :: true | false, FileVersion :: string()}) -> list().
copy_state(Nodes, {DeleteRaftData, FileVersion}) ->
  {Replies, _} = gen_server:multi_call(Nodes, ?ER_RAFT_SERVER, {?BKUP_RAFT_SERVER_STATE, {DeleteRaftData, FileVersion}}),
  Replies.

-spec raft_test(RaftNodes :: list(),
                InitialNodes :: list(),
                SleepTime :: non_neg_integer(),
                ConfigChangeMin :: non_neg_integer(),
                ConfigChangeMax :: non_neg_integer(),
                FullConfigChange :: non_neg_integer(),
                LogEntriesMin :: non_neg_integer(),
                LogEntriesMax :: non_neg_integer(),
                FileName :: string()) -> term().
raft_test(RaftNodes,
          InitialNodes,
      	  SleepTime, 
      	  ConfigChangeMin, 
          ConfigChangeMax, 
          FullConfigChange,
      	  LogEntriesMin, 
          LogEntriesMax,
          FileName) ->
  AppConfig = er_test_config:get_env(RaftNodes,
                                     InitialNodes,
                                     SleepTime, 
                                     ConfigChangeMin, 
                                     ConfigChangeMax, 
                                     FullConfigChange,
                                     LogEntriesMin, 
                                     LogEntriesMax),
  TestResults = er_test_run:run_test(AppConfig),
  er_test_results:print(FileName, TestResults).

raft_test() ->
  raft_test(?RAFT_NODES,
            ?INITIAL_NODES,
            ?SLEEP_TIME,
            ?CONFIG_CHANGE_MIN,
            ?CONFIG_CHANGE_MAX,
            ?FULL_CONFIG_CHANGE,
            ?LOG_ENTRIES_MIN,
            ?LOG_ENTRIES_MAX,
            ?RESULT_FILE_NAME).

test_print(FileName) ->
  PrevTestStatus = #er_test_status{},
  PrevTestResult = #er_test_result{test_status=PrevTestStatus},
  CurrTestStatus = #er_test_status{},
  CurrTestResult = #er_test_result{test_status=CurrTestStatus},
  TestResults = #er_test_results{prev_test_result=PrevTestResult, curr_test_result=CurrTestResult},
  er_test_results:print(FileName, TestResults).


