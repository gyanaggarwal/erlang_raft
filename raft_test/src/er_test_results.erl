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

-module(er_test_results).

-export([print/2]).

-include("er_fsm.hrl").
-include("er_test.hrl").

print(FileName, #er_test_results{prev_test_result=PrevTestResult, curr_test_result=CurrTestResult}) ->
  {ok, File} = file:open(FileName, [write]),
  print_test_result(File, prev_test_result, PrevTestResult),
  print_test_result(File, curr_test_result, CurrTestResult),
  file:close(File).

print_test_result(File, Header, undefined) ->
  print_none(File, Header);
print_test_result(File,
                  Header, 
                  #er_test_result{test_status=TestStatus, 
                                  initial_state=InitialState, 
                                  final_state=FinalState,
                                  test_case_no=TestCaseNo,
                                  leader_id=LeaderId,
                                  config=Config,
                                  log_entries=LogEntries}) ->
  print_header(File, Header),
  io:fwrite(File, 
            "   test_case_no=~p, leader_id=~p, config=~p, log_entries=~p~n", 
            [TestCaseNo, LeaderId, Config, LogEntries]),
  print_test_status(File, TestStatus),
  print_state(File, initial_state, InitialState),
  print_state(File, final_state, FinalState).

print_test_status(File, #er_test_status{config_state=ConfigState, not_in_config_state=NotInConfigState, log_index_state=LogIndexState, log_entries_state=LogEntriesState}) ->
  io:fwrite(File, 
            "   config_state=~p, not_in_config_state=~p, log_index_state=~p, log_entries_state=~p~n", 
            [ConfigState, NotInConfigState, LogIndexState, LogEntriesState]).

print_state(File, Header, undefined) ->
  print_none(File, Header);
print_state(File, Header, State) ->
  print_header(File, Header),
  print_state(File, State).

print_state(File, [H | T]) ->
  print_node(File, H),
  print_state(File, T);
print_state(_File, []) ->
  ok.

print_node(File, {Node, #er_raft_state{status=Status,
                                      leader_id=LeaderId,
                                      current_term=CurrentTerm,
                                      prev_log_term=PrevLogTerm,
                                      prev_log_index=PrevLogIndex,
                                      commit_term=CommitTerm,
                                      commit_index=CommitIndex}}) ->
  io:fwrite(File,
            "   node=~p, status=~p, leader_id=~p, current_term=~p, prev_log_term=~p, prev_log_index=~p, commit_term=~p, commit_index=~p~n",
            [Node, Status, LeaderId, CurrentTerm, PrevLogTerm, PrevLogIndex, CommitTerm, CommitIndex]).

print_header(File, Header) ->
  io:fwrite(File,
            "~n~p~n", 
            [Header]).

print_none(File, Header) ->
  print_header(File, Header),
  io:fwrite(File,
            "   ~p~n",
            [none]).


