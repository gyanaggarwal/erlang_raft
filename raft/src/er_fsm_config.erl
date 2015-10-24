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

-module(er_fsm_config).

-export([get_env/0, 
         get_election_timeout/1, 
         get_heartbeat_timeout/1,
         get_log_request_timeout/1,
         get_node_id/1,
         get_log_entry_operation_api/1,
         get_log_file_header_version/1,
         get_log_entry_trailer_magic/1,
         get_state_machine_api/1,
         get_data_dir/1,
         get_file_replicated_log/1,
         get_file_metadata/1,
         get_file_config/1,
         get_optimistic_mode/1,
         get_debug_mode/1,
         get_sup_restart_intensity/1,
         get_sup_restart_period/1,
         get_sup_child_shutdown/1,
         get_log_retention_size/1]).

-export([data_dir/0,
         file_replicated_log/0,
         file_metadata/0,
         sup_restart_intensity/0,
         sup_restart_period/0,
         sup_child_shutdown/0]).

-include("er_fsm.hrl").

-define(ELECTION_TIMEOUT_MIN,      10).
-define(ELECTION_TIMEOUT_MAX,      20).
-define(HEARTBEAT_TIMEOUT,         5).
-define(LOG_REQUEST_TIMEOUT,       5).
-define(LOG_ENTRY_OPERATION_API,   rl_entry_operation_api).
-define(LOG_FILE_HEADER_VERSION,   1).
-define(LOG_ENTRY_TRAILER_MAGIC,   <<"\xFE\xED\xFE\xED\xFE\xED\xFE\xED">>).
-define(STATE_MACHINE_API,         undefined).
-define(DATA_DIR,                  "").
-define(FILE_REPLICATED_LOG,       "_repl.log").
-define(FILE_METADATA,             "_meta.dat").
-define(FILE_CONFIG,               "_raft_cfg").
-define(OPTIMISTIC_MODE,           true).
-define(DEBUG_MODE,                false).
-define(SUP_RESTART_INTENSITY,     1).
-define(SUP_RESTART_PERIOD,        5).
-define(SUP_CHILD_SHUTDOWN,        2000).
-define(LOG_RETENTION_SIZE_MIN,    10).
-define(LOG_RETENTION_SIZE_MAX,    1000).

-spec get_env() -> #er_app_config{}.
get_env() ->
  NodeName           = er_util:get_node_name(),
  DataDir            = er_config:get_env(erlang_raft, data_dir, ?DATA_DIR),
  FileSuffixReplLog  = er_config:get_env(erlang_raft, file_replicated_log, ?FILE_REPLICATED_LOG),
  FileSuffixMetadata = er_config:get_env(erlang_raft, file_metadata, ?FILE_METADATA),
  FileSuffixRaftCfg  = er_config:get_env(erlang_raft, file_config, ?FILE_CONFIG),

  #er_app_config{election_timeout_min    = er_config:get_env(erlang_raft, election_timeout_min,    ?ELECTION_TIMEOUT_MIN),
                 election_timeout_max    = er_config:get_env(erlang_raft, election_timeout_max,    ?ELECTION_TIMEOUT_MAX),
                 heartbeat_timeout       = er_config:get_env(erlang_raft, heartbeat_timeout,       ?HEARTBEAT_TIMEOUT),
                 log_request_timeout     = er_config:get_env(erlang_raft, log_request_timeout,     ?LOG_REQUEST_TIMEOUT),
                 node_id                 = node(),
                 log_entry_operation_api = er_config:get_env(erlang_raft, log_entry_operation_api, ?LOG_ENTRY_OPERATION_API),
                 log_file_header_version = er_config:get_env(erlang_raft, log_file_header_version, ?LOG_FILE_HEADER_VERSION),
                 log_entry_trailer_magic = er_config:get_env(erlang_raft, log_entry_trailer_magic, ?LOG_ENTRY_TRAILER_MAGIC),
                 state_machine_api       = er_config:get_env(erlang_raft, state_machine_api,       ?STATE_MACHINE_API),
                 data_dir                = DataDir,
                 file_replicated_log     = get_file_name(NodeName, DataDir, FileSuffixReplLog),
                 file_metadata           = get_file_name(NodeName, DataDir, FileSuffixMetadata),
                 file_config             = get_file_name(NodeName, DataDir, FileSuffixRaftCfg),
                 optimistic_mode         = er_config:get_env(erlang_raft, optimistic_mode,         ?OPTIMISTIC_MODE),
                 debug_mode              = er_config:get_env(erlang_raft, debug_mode,              ?DEBUG_MODE),
                 sup_restart_intensity   = er_config:get_env(erlang_raft, sup_restart_intensity,   ?SUP_RESTART_INTENSITY),
                 sup_restart_period      = er_config:get_env(erlang_raft, sup_restart_period,      ?SUP_RESTART_PERIOD),
                 sup_child_shutdown      = er_config:get_env(erlang_raft, sup_child_shutdown,      ?SUP_CHILD_SHUTDOWN),
                 log_retention_size_min  = er_config:get_env(erlang_raft, log_retention_size_min,  ?LOG_RETENTION_SIZE_MIN),
                 log_retention_size_max  = er_config:get_env(erlang_raft, log_retention_size_max,  ?LOG_RETENTION_SIZE_MAX)}.

-spec get_election_timeout(AppConfig :: #er_app_config{}) -> {non_neg_integer(), non_neg_integer()}.
get_election_timeout(#er_app_config{election_timeout_min=ElectionTimeoutMin, election_timeout_max=ElectionTimeoutMax}) ->
  {ElectionTimeoutMin, ElectionTimeoutMax}.

-spec get_heartbeat_timeout(AppConfig :: #er_app_config{}) -> non_neg_integer().
get_heartbeat_timeout(#er_app_config{heartbeat_timeout=HeartbeatTimeout}) ->
  HeartbeatTimeout.

-spec get_log_request_timeout(AppConfig :: #er_app_config{}) -> non_neg_integer().
get_log_request_timeout(#er_app_config{log_request_timeout=LogRequestTimeout}) ->
  LogRequestTimeout.

-spec get_node_id(AppConfig :: #er_app_config{}) -> atom().
get_node_id(#er_app_config{node_id=NodeId}) ->
  NodeId.

-spec get_log_entry_operation_api(AppConfig :: #er_app_config{}) -> atom().
get_log_entry_operation_api(#er_app_config{log_entry_operation_api=LogEntryOperationApi}) ->
  LogEntryOperationApi.

-spec get_log_file_header_version(AppConfig :: #er_app_config{}) -> non_neg_integer().
get_log_file_header_version(#er_app_config{log_file_header_version=LogFileHeaderVersion}) ->
  LogFileHeaderVersion.

-spec get_log_entry_trailer_magic(AppConfig :: #er_app_config{}) -> binary().
get_log_entry_trailer_magic(#er_app_config{log_entry_trailer_magic=LogEntryTrailerMagic}) ->
  LogEntryTrailerMagic.

-spec get_state_machine_api(AppConfig :: #er_app_config{}) -> atom().
get_state_machine_api(#er_app_config{state_machine_api=StateMachineApi}) ->
  StateMachineApi.

-spec get_data_dir(AppConfig :: #er_app_config{}) -> string().
get_data_dir(#er_app_config{data_dir=DataDir}) ->
  DataDir.

-spec get_file_replicated_log(AppConfig :: #er_app_config{}) -> #er_file_name{}.
get_file_replicated_log(#er_app_config{file_replicated_log=FileReplicatedLog}) ->
  FileReplicatedLog.

-spec get_file_metadata(AppConfig :: #er_app_config{}) -> #er_file_name{}.
get_file_metadata(#er_app_config{file_metadata=FileMetadata}) ->
  FileMetadata.

-spec get_file_config(AppConfig :: #er_app_config{}) -> #er_file_name{}.
get_file_config(#er_app_config{file_config=FileConfig}) ->
  FileConfig.

-spec get_optimistic_mode(AppConfig :: #er_app_config{}) -> boolean().
get_optimistic_mode(#er_app_config{optimistic_mode=OptimisticMode}) ->
  OptimisticMode.

-spec get_debug_mode(AppConfig :: #er_app_config{}) -> boolean().
get_debug_mode(#er_app_config{debug_mode=DebugMode}) ->
  DebugMode.

-spec get_sup_restart_intensity(AppConfig :: #er_app_config{}) -> non_neg_integer().
get_sup_restart_intensity(#er_app_config{sup_restart_intensity=SupRestartIntensity}) ->
  SupRestartIntensity.

-spec get_sup_restart_period(AppConfig :: #er_app_config{}) -> non_neg_integer().
get_sup_restart_period(#er_app_config{sup_restart_period=SupRestartPeriod}) ->
  SupRestartPeriod.

-spec get_sup_child_shutdown(AppConfig :: #er_app_config{}) -> non_neg_integer().
get_sup_child_shutdown(#er_app_config{sup_child_shutdown=SupChildShutdown}) ->
  SupChildShutdown.

-spec get_log_retention_size(AppConfig :: #er_app_config{}) -> {non_neg_integer(), non_neg_integer() | infinity}.
get_log_retention_size(#er_app_config{log_retention_size_min=LogRetentionSizeMin, log_retention_size_max=LogRetentionSizeMax}) ->
  {LogRetentionSizeMin, LogRetentionSizeMax}.

-spec get_file_name(NodeName :: string(), DataDir :: string(), FileSuffix :: string()) -> #er_file_name{}.
get_file_name(NodeName, DataDir, FileSuffix) ->
  #er_file_name{file_suffix    = FileSuffix,
                file_name      = er_util:get_file_name(NodeName, DataDir, FileSuffix),
                temp_file_name = er_util:get_temp_file_name(NodeName, DataDir, FileSuffix)}.

-spec data_dir() -> string().
data_dir() ->
  er_config:get_env(erlang_raft, data_dir, ?DATA_DIR).

-spec file_replicated_log() -> string().
file_replicated_log() ->
  er_config:get_env(erlang_raft, file_replicated_log, ?FILE_REPLICATED_LOG).

-spec file_metadata() -> string().
file_metadata() ->
  er_config:get_env(erlang_raft, file_metadata, ?FILE_METADATA).

-spec sup_restart_intensity() -> non_neg_integer(). 
sup_restart_intensity() ->
  er_config:get_env(erlang_raft, sup_restart_intensity, ?SUP_RESTART_INTENSITY).

-spec sup_restart_period() -> non_neg_integer().
sup_restart_period() ->
  er_config:get_env(erlang_raft, sup_restart_period, ?SUP_RESTART_PERIOD).

-spec sup_child_shutdown() -> non_neg_integer().
sup_child_shutdown() ->
  er_config:get_env(erlang_raft, sup_child_shutdown, ?SUP_CHILD_SHUTDOWN).


