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

-module(er_snapshot).

-export([raft_snapshot/1]).

-include("er_fsm.hrl").

-spec raft_snapshot(AppConfig :: #er_app_config{}) -> {ok, #er_snapshot{}}.
raft_snapshot(AppConfig) ->
  RequestSnapshot = #er_snapshot{state_machine=?ER_REQUEST, log_entries=?ER_REQUEST, log_stats=?ER_REQUEST},
  er_util:read_snapshot(AppConfig, RequestSnapshot).