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

{application, erlang_raft,
 [ {description, "a simple raft implementation"}
  ,{vsn, "0.1.0"}
  ,{modules, [er_app, er_sup, er_raft_server, er_event, er_peer_server, rl_server]}
  ,{registered, [er_sup, er_raft_server, er_event, er_peer_server, rl_server]}
  ,{applications, [kernel, stdlib]}
  ,{env, [ {election_timeout_min   , 10}
          ,{election_timeout_max   , 20}
          ,{heartbeat_timeout      , 5}
          ,{log_request_timeout    , 5}
          ,{log_entry_operation_api, rl_entry_operation_api}
          ,{log_file_header_version, 1}
          ,{log_entry_trailer_magic, <<"\xFE\xED\xFE\xED\xFE\xED\xFE\xED">>}
          ,{state_machine_api      , undefined}
          ,{data_dir               , ""}
          ,{file_replicated_log    , "_repl.log"}
          ,{file_metadata          , "_meta.dat"}
          ,{file_config            , "_raft.cfg"}
          ,{optimistic_mode        , true}
          ,{debug_mode             , false}
          ,{sup_restart_intensity  , 1}
          ,{sup_restart_period     , 5}
          ,{sup_child_shutdown     , 2000}
          ,{log_retention_size_min , 10}
          ,{log_retention_size_max , 1000}]}
  ,{mod, {er_app, []}}
 ]}.