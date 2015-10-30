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

-module(er_test_config).

-export([get_env/8,
         get_raft_nodes/1,
         get_initial_nodes/1,
         get_sleep_time/1,
         get_full_config_change/1,
         get_config_change/1,
         get_log_entries/1]).

-include("er_test.hrl").

get_env(RaftNodes,
        InitialNodes,
        SleepTime, 
        ConfigChangeMin, 
        ConfigChangeMax, 
        FullConfigChange,
        LogEntriesMin, 
        LogEntriesMax) ->
  #er_test_config{raft_nodes            = get_nodes(RaftNodes),
                  initial_nodes         = get_nodes(InitialNodes),
       		  sleep_time  		= SleepTime,
                  config_change_min     = ConfigChangeMin,
                  config_change_max     = ConfigChangeMax,
                  full_config_change    = FullConfigChange,
                  log_entries_min       = LogEntriesMin,
                  log_entries_max       = LogEntriesMax}.
  
-spec get_raft_nodes(TestConfig :: #er_test_config{}) -> list().
get_raft_nodes(#er_test_config{raft_nodes=Value}) ->
  Value.

-spec get_initial_nodes(TestConfig :: #er_test_config{}) -> list().
get_initial_nodes(#er_test_config{initial_nodes=Value}) ->
  Value.

-spec get_sleep_time(TestConfig :: #er_test_config{}) -> non_neg_integer().
get_sleep_time(#er_test_config{sleep_time=Value}) ->
  Value.

-spec get_full_config_change(TestConfig :: #er_test_config{}) -> non_neg_integer().
get_full_config_change(#er_test_config{full_config_change=Value}) ->
  Value.

-spec get_config_change(TestConfig :: #er_test_config{}) -> {non_neg_integer(), non_neg_integer()}.
get_config_change(#er_test_config{config_change_min=Min, config_change_max=Max}) ->
  {Min, Max}.

-spec get_log_entries(TestConfig :: #er_test_config{}) -> {non_neg_integer(), non_neg_integer()}.
get_log_entries(#er_test_config{log_entries_min=Min, log_entries_max=Max}) ->
  {Min, Max}.

get_nodes(Nodes) ->
  RestOfNode = er_util:get_rest_of_node_name(),
  lists:foldl(fun(X, Acc) -> [list_to_atom(atom_to_list(X) ++ RestOfNode) | Acc] end, [], Nodes).
