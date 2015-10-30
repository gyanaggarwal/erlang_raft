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

-module(er_test_util).

-export([create_test_cases/1,
         next_config/5,
         get_test_state/2]).

-include("er_fsm.hrl").
-include("er_test.hrl").

create_test_cases(AppConfig) ->
  FullConfigChange = er_test_config:get_full_config_change(AppConfig),
  TestCases = er_util:get_random(er_test_config:get_config_change(AppConfig)),
  FullConfigStep = TestCases div FullConfigChange,
  lists:reverse(lists:foldl(fun(X, Acc) -> make_test_case(X, Acc, TestCases, FullConfigStep, er_test_config:get_log_entries(AppConfig)) end, 
                            [], 
                            lists:seq(1, TestCases))).

make_test_case(CaseNo, TestList, TestCases, FullConfigStep, LogEntries) ->
  {L, C} = case (CaseNo =:= TestCases) orelse ((CaseNo rem FullConfigStep) =:= 0 andalso (TestCases - CaseNo) >= FullConfigStep) of
             true  ->
               ?LEADER_FULL_CONFIG;
             false ->
                get_test_scenario(random:uniform(4)) 
           end,
  [#er_test_scenario{test_case_no=CaseNo, leader_status=L, config_change=C, log_entries=er_util:get_random(LogEntries)} | TestList].

get_test_scenario(1) ->
  ?LEADER_CHANGE_1;
get_test_scenario(2) ->
  ?LEADER_CHANGE_2;
get_test_scenario(3) ->
  ?NO_LEADER_CHANGE_1;
get_test_scenario(4) ->
  ?NO_LEADER_CHANGE_2.

next_config(undefined, _, InitialNodes, _, _) ->
  [Node | _] = InitialNodes,
  {Node, InitialNodes};
next_config(#er_test_result{leader_id=LeaderId}, FullConfig, _, _, 0) ->
  {LeaderId, FullConfig};
next_config(#er_test_result{leader_id=LeaderId, config=Config}, FullConfig, _, LeaderStatus, ConfigChange) ->
  {LeaderId, get_config(Config, FullConfig, LeaderId, LeaderStatus, ConfigChange)}.

get_config(Config, FullConfig, LeaderId, ?LEADER_PRESENT, N) ->
  {CList1, FList1} = get_list(Config, FullConfig, LeaderId),
  CNodes = pick_nodes(CList1, [], N),
  FNodes = pick_nodes(FList1, [], N),
  (Config -- CNodes) ++ FNodes;
get_config(Config, FullConfig, LeaderId, ?NO_LEADER_PRESENT, N) ->
  {CList1, FList1} = get_list(Config, FullConfig, LeaderId),
  CNodes = pick_nodes(CList1, [], N-1),
  FNodes = pick_nodes(FList1, [], N),
  (CList1 -- CNodes) ++ FNodes.
 
pick_node(List) ->
  lists:nth(random:uniform(length(List)), List).

pick_nodes(_, Acc, 0) ->
  Acc;
pick_nodes([_ | _]=List, Acc, N) ->
  Node = pick_node(List),
  pick_nodes((List -- [Node]), [Node | Acc], N-1);
pick_nodes([], Acc, _) ->
  Acc.

get_list(Config, FullConfig, LeaderId) ->
  {Config -- [LeaderId], FullConfig -- Config}.

get_test_state([{Node, State} | Rest], Acc) ->
  get_test_state(Rest, [{Node, er_raft_state:get_light_weight_state(State)} | Acc]);
get_test_state([], Acc) ->
  Acc.


