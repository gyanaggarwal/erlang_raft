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

-module(er_sup).

-behavior(supervisor).

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

-spec start_link() -> {ok, pid()} | term().
start_link() ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, []).

-spec init(Arg :: list()) -> {ok, {tuple(), list()}}.
init([]) ->
  AppConfig        = er_fsm_config:get_env(),
  RestartIntensity = er_fsm_config:get_sup_restart_intensity(AppConfig),
  RestartPeriod    = er_fsm_config:get_sup_restart_period(AppConfig),
  ChildShutdown    = er_fsm_config:get_sup_child_shutdown(AppConfig),

  Raft  = {er_raft_server, {er_raft_server, start_link, [AppConfig]},
           permanent, ChildShutdown, worker, [er_raft_server]},
  Log   = {rl_server,      {rl_server,      start_link, [AppConfig]},
           permanent, ChildShutdown, worker, [rl_server]},
  Peer  = {er_peer_server, {er_peer_server, start_link, [AppConfig]},
           permanent, ChildShutdown, worker, [er_peer_server]},  
  Event = {er_event,       {er_event,       start_link, []},
           permanent, ChildShutdown, worker, [er_event]},

  Childern        = [Raft, Log, Peer, Event],
  RestartStrategy = {one_for_one, RestartIntensity, RestartPeriod},

  {ok, {RestartStrategy, Childern}}.

