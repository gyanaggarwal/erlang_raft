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

-module(er_test_case).

-export([test_case/6,
         valid_state/1, 
         file_version/1]).

-include("er_fsm.hrl").
-include("er_test.hrl").

-define(FAILED,    failed).
-define(SUCCEEDED, succeeded).

test_case(TestCaseNo, LeaderId, Config, LogEntries, SleepTime, FullConfig) ->
  erlang_raft:config_entry(LeaderId, Config),
  timer:sleep(SleepTime),
  InitialStates = erlang_raft_test:get_state(FullConfig),
  ConfigStates = er_raft_state:get_config_list(InitialStates, Config),
  NotInConfigStates = er_raft_state:get_not_in_config_list(InitialStates, Config),
  LeaderState = er_raft_state:get_leader_state(ConfigStates),
  TestStatus = #er_test_status{config_state=er_raft_state:validate_config_state(ConfigStates, LeaderState), 
                               not_in_config_state=er_raft_state:validate_not_in_config_state(NotInConfigStates)},
  TestResult = #er_test_result{test_case_no=TestCaseNo, 
                               config=Config, 
                               log_entries=LogEntries, 
                               leader_id=LeaderState#er_raft_state.leader_id, 
                               test_status=TestStatus, 
                               initial_state=InitialStates},

  case valid_state(TestStatus) of
    true  ->
      lists:foreach(fun(X) -> erlang_raft:log_entry(LeaderState#er_raft_state.leader_id, make_ref(), (TestCaseNo*10000)+X) end, lists:seq(1, LogEntries)),
      FileVersion = file_version(TestCaseNo),
      FinalStates = erlang_raft_test:copy_state(FullConfig, {false, FileVersion}),
      ConfigStates1 = er_raft_state:get_config_list(FinalStates, Config),
      LeaderState1 = er_raft_state:get_leader_state(ConfigStates1),
      TestStatus1 = TestStatus#er_test_status{log_index_state=er_raft_state:validate_log_index_state(ConfigStates1, LeaderState1),
                                              log_entries_state=er_raft_state:validate_log_entries_state(LeaderState, LeaderState1, LogEntries)},
      test_and_print(TestCaseNo, TestStatus1),
      TestResult#er_test_result{test_status=TestStatus1, final_state=FinalStates};
   false ->
      print(TestCaseNo, ?FAILED),
      TestResult
   end.

valid_state(#er_test_status{config_state=?ER_VALID_STATE, not_in_config_state=?ER_VALID_STATE, log_index_state=undefined, log_entries_state=undefined}) ->
  true;
valid_state(#er_test_status{config_state=?ER_VALID_STATE, not_in_config_state=?ER_VALID_STATE, log_index_state=?ER_VALID_STATE, log_entries_state=?ER_VALID_STATE}) ->
  true;
valid_state(_) ->
  false.

file_version(TestCaseNo) ->
  ?BKUP ++ integer_to_list(TestCaseNo).

print(TestCaseNo, Result) ->
  io:fwrite("test_case_no=~p  ~p~n", [TestCaseNo, Result]).

test_and_print(TestCaseNo, TestStatus) ->
  Result = case valid_state(TestStatus) of
             true  -> ?SUCCEEDED;
             false -> ?FAILED
           end,
  print(TestCaseNo, Result).

