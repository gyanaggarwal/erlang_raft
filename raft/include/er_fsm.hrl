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

-define(TEMP_SUFFIX,                "_temp").

-define(TYPE_NOOP,                  0).
-define(TYPE_CONFIG,                1).
-define(TYPE_OP,                    2).

-define(ER_BAD_ENTRY,               er_bad_entry).
-define(ER_TRUNCATED,               er_truncated).
-define(ER_STABLE,                  er_stable).
-define(ER_KEEP_STATUS,             er_keep_status).
-define(ER_CONFIG_CHANGE,           er_config_change).
-define(ER_EMPTY,                   er_empty).
-define(ER_UNDEFINED,               er_undefined).
-define(ER_UNAVAILABLE,             er_unavailable).
-define(ER_REQUEST,                 er_request).
-define(ER_NOT_IN_CONFIG,           er_not_in_config).
-define(ER_FOLLOWER,                er_follower).
-define(ER_LEADER,                  er_leader).
-define(ER_CANDIDATE,               er_candidate).
-define(ER_ENTRY_ACCEPTED,          er_entry_accepted).
-define(ER_ENTRY_REJECTED,          er_entry_rejected).
-define(ER_CONFIG_ACCEPTED,         er_config_accepted).
-define(ER_CONFIG_REJECTED,         er_config_rejected).
-define(ER_CONFIG_CHANGE_ACCEPTED,  er_config_change_accepted).
-define(ER_CONFIG_CHANGE_REJECTED,  er_config_change_rejected).
-define(ER_ENTRY_LEADER_ID,         er_entry_leader_id).
-define(ER_ENTRY_DUPLICATE,         er_entry_duplicate).
-define(ER_REQUEST_SNAPSHOT,        er_request_snapshot).
-define(ER_LEADER_STEP_DOWN,        er_leader_step_down).
-define(ER_QUORUM_UNREACHABLE,      er_quorum_unreachable).

-define(ER_RAFT_SERVER,             er_raft_server).
-define(ER_PEER_SERVER,             er_peer_server).
-define(RL_SERVER,                  rl_server).

-define(LOG_ENTRY,                  log_entry).
-define(CONFIG_ENTRY,               config_entry).
-define(REQUEST_VOTE,    	    request_vote).
-define(INSTALL_SNAPSHOT,           install_snapshot).
-define(APPEND_ENTRIES_OP,          append_entries_op).
-define(APPEND_ENTRIES_NOOP,        append_entries_noop).
-define(APPEND_ENTRIES_CONFIG,      append_entries_config).
-define(PEER_REQUEST_VOTE,          peer_request_vote).
-define(PEER_INSTALL_SNAPSHOT,      peer_install_snapshot).
-define(PEER_APPEND_ENTRIES_OP,     peer_append_entries_op).
-define(PEER_APPEND_ENTRIES_NOOP,   peer_append_entries_noop).
-define(PEER_APPEND_ENTRIES_CONFIG, peer_append_entries_config).

-record(er_file_name,        {file_suffix               :: string(),
                              file_name                 :: string(),
                              temp_file_name            :: string()}).

-record(er_app_config,       {election_timeout_min      :: non_neg_integer(), 
                              election_timeout_max      :: non_neg_integer(),
                              heartbeat_timeout         :: non_neg_integer(),
                              log_request_timeout       :: non_neg_integer(),
                              node_id                   :: atom(),
                              log_entry_operation_api   :: atom(),
                              log_file_header_version   :: non_neg_integer(),
                              log_entry_trailer_magic   :: binary(),
                              state_machine_api         :: atom(),
                              data_dir                  :: string(),
                              file_replicated_log       :: #er_file_name{},
                              file_metadata             :: #er_file_name{},
                              file_config               :: #er_file_name{},
                              optimistic_mode=true      :: true | false,
                              debug_mode=false          :: true | false,
                              sup_restart_intensity     :: non_neg_integer(),
                              sup_restart_period        :: non_neg_integer(),
                              sup_child_shutdown        :: non_neg_integer(),
                              log_retention_size_max    :: non_neg_integer(),
                              log_retention_size_min    :: non_neg_integer()}).

-record(er_cmd_entry,        {type                      :: ?TYPE_CONFIG | ?TYPE_OP,
                              id                        :: term(),
                              cmd                       :: term()}).

-record(er_log_entry,        {term=0                    :: non_neg_integer(),
                              index=0                   :: non_neg_integer(),
                              entry                     :: #er_cmd_entry{}}).

-record(er_leader_info,      {leader_id                 :: atom(),
                              leader_term=0             :: non_neg_integer(),
                              config_entry              :: #er_log_entry{}}).

-record(er_vote,             {term=0                    :: non_neg_integer(),
                              candidate_id              :: atom(),
                              prev_log_term=0           :: non_neg_integer(),
                              prev_log_index=0          :: non_neg_integer()}).

-record(er_config,           {status=?ER_UNDEFINED      :: ?ER_UNDEFINED | 
                                                           ?ER_STABLE | 
                                                           ?ER_CONFIG_CHANGE,
                              current_config            :: #er_log_entry{},
                              new_config                :: #er_log_entry{}}).
			      
-record(er_replicated_log,   {status=?ER_UNDEFINED      :: ?ER_UNDEFINED |
                                                           error |
                                                           ?ER_TRUNCATED |
                                                           ?ER_STABLE,
                              file                      :: file:io_device(),
                              app_config                :: #er_app_config{}}).

-record(er_request_vote,     {vote                      :: #er_vote{},
                              config_entry              :: #er_log_entry{}}).

-record(er_append_entries,   {type                      :: ?TYPE_NOOP | ?TYPE_OP |?TYPE_CONFIG,
                              leader_info               :: #er_leader_info{},
                              prev_log_term=0           :: non_neg_integer(),
                              prev_log_index=0          :: non_neg_integer(),
                              leader_commit_term=0      :: non_neg_integer(),
                              leader_commit_index=0     :: non_neg_integer(),
                              log_entries               :: queue:queue()}).

-record(er_unique_id,        {log_entries=sets:new()    :: sets:set()}).

-record(er_snapshot,         {leader_info               :: #er_leader_info{},
                              state_machine             :: undefined | ?ER_REQUEST | ?ER_EMPTY | term(),
                              voted_for                 :: undefined | ?ER_REQUEST | ?ER_EMPTY | #er_vote{},
                              log_entries               :: undefined | ?ER_REQUEST | ?ER_EMPTY | queue:queue(),
                              log_stats                 :: undefined | ?ER_REQUEST,
                              log_entry_count=0         :: non_neg_integer(),
                              unique_id=#er_unique_id{} :: #er_unique_id{}}).

-record(er_raft_state,       {status=?ER_NOT_IN_CONFIG  :: ?ER_FOLLOWER |
                                                           ?ER_LEADER |
                                                           ?ER_CANDIDATE |
                                                           ?ER_NOT_IN_CONFIG,
                              leader_id                 :: atom(),
                              log_entry_count=0         :: non_neg_integer(),
                              current_term=0            :: non_neg_integer(),
                              prev_log_term=0           :: non_neg_integer(),
                              prev_log_index=0          :: non_neg_integer(),      
                              commit_term=0             :: non_neg_integer(),
                              commit_index=0            :: non_neg_integer(),
                              applied_term=0            :: non_neg_integer(),
                              applied_index=0           :: non_neg_integer(),
                              log_entries               :: queue:queue(),
                              unique_id=#er_unique_id{} :: #er_unique_id{},
                              vote                      :: #er_vote{},
                              config                    :: #er_config{},
                              app_config                :: #er_app_config{}}).

-record(er_peer_state,       {app_config                :: #er_app_config{}}).
 