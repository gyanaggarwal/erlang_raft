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

-define(BKUP,                "_bkup").
-define(INIT_BKUP,           "_init_bkup").

-define(LEADER_PRESENT,      1).
-define(NO_LEADER_PRESENT,   0).

-define(LEADER_CHANGE_1,     {?LEADER_PRESENT, 1}).
-define(LEADER_CHANGE_2,     {?LEADER_PRESENT, 2}).
-define(NO_LEADER_CHANGE_1,  {?NO_LEADER_PRESENT, 1}).
-define(NO_LEADER_CHANGE_2,  {?NO_LEADER_PRESENT, 2}).
-define(LEADER_FULL_CONFIG,  {?LEADER_PRESENT, 0}).

-record(er_test_config,      {raft_nodes                :: list(),
                              initial_nodes             :: list(),
                              sleep_time                :: non_neg_integer(),
                              config_change_min         :: non_neg_integer(),
			      config_change_max		:: non_neg_integer(),
                              full_config_change        :: non_neg_integer(),
			      log_entries_min           :: non_neg_integer(),
	                      log_entries_max           :: non_neg_integer()}).

-record(er_test_scenario,    {test_case_no              :: non_neg_integer(),
                              leader_status             :: non_neg_integer(),
                              config_change             :: non_neg_integer(),
                              log_entries               :: non_neg_integer()}).

-record(er_test_status,      {config_state              :: term(),
                              not_in_config_state       :: term(),
                              log_index_state           :: term(),
                              log_entries_state         :: term()}).

-record(er_test_result,      {test_case_no              :: non_neg_integer(),
                              log_entries               :: non_neg_integer(),
                              leader_id                 :: atom(),
                              config                    :: list(),
                              test_status               :: term(),
                              initial_state             :: list(),
                              final_state               :: list()}).

-record(er_test_results,     {prev_test_result          :: #er_test_result{},
                              curr_test_result          :: #er_test_result{}}).

 