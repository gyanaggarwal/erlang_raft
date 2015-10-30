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
-module(er_test_run).

-export([run_test/1]).

-include("er_test.hrl").

run_test(AppConfig) ->
  random:seed(erlang:phash2([node()]), erlang:monotonic_time(), erlang:unique_integer()),
  InitialBkup = ?INIT_BKUP,
  erlang_raft_test:copy_state(er_test_config:get_raft_nodes(AppConfig), {true, InitialBkup}),
  TestCases=er_test_util:create_test_cases(AppConfig),
  run_test(TestCases, AppConfig).
  
run_test(TestCases, AppConfig) ->
  FullConfig = er_test_config:get_raft_nodes(AppConfig),
  InitialNodes = er_test_config:get_initial_nodes(AppConfig),
  SleepTime = er_test_config:get_sleep_time(AppConfig),
  lists:foldl(fun(X, Acc) -> run_test(X, Acc, FullConfig, InitialNodes, SleepTime) end, #er_test_results{}, TestCases).
  
run_test(#er_test_scenario{test_case_no=TestCaseNo, leader_status=LeaderStatus, config_change=ConfigChange, log_entries=LogEntries}, 
         #er_test_results{curr_test_result=TestResult}=TestResults, 
         FullConfig, 
         InitialNodes,
         SleepTime) ->
  case valid_test_result(TestResult) of 
    true  ->
      {LeaderId, Config} = er_test_util:next_config(TestResult, FullConfig, InitialNodes, LeaderStatus, ConfigChange),
      NewTestResult = er_test_case:test_case(TestCaseNo, LeaderId, Config, LogEntries, SleepTime, FullConfig),
      TestResults#er_test_results{prev_test_result=TestResult, curr_test_result=NewTestResult};
    false ->
      TestResults
  end.
 
valid_test_result(undefined) ->
  true;
valid_test_result(#er_test_result{test_status=TestStatus}) ->
  er_test_case:valid_state(TestStatus).


