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

-module(er_peer_server).

-behavior(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("er_fsm.hrl").

-define(SERVER, ?MODULE).

start_link(AppConfig) ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [AppConfig], []).

init([AppConfig]) ->
  {ok, #er_peer_state{app_config=AppConfig}}.
  
handle_call({?REQUEST_VOTE, RequestVote}, _From, #er_peer_state{app_config=AppConfig}=State) ->
  ConfigEntry = RequestVote#er_request_vote.config_entry,
  ConfigList = er_util:config_list(ConfigEntry),
  PeerNodeList = er_util:peer_node_list(ConfigList),
  Reply = gen_server:multi_call(PeerNodeList, ?ER_RAFT_SERVER, {?PEER_REQUEST_VOTE, RequestVote}),
  {reply, Reply, State, er_fsm_config:get_log_request_timeout(AppConfig)};
handle_call({?APPEND_ENTRIES_OP, AppendEntries}, _From, #er_peer_state{app_config=AppConfig}=State) ->
  ConfigEntry = AppendEntries#er_append_entries.leader_info#er_leader_info.config_entry,
  ConfigList = er_util:config_list(ConfigEntry),
  PeerNodeList = er_util:peer_node_list(ConfigList),
  Reply = gen_server:multi_call(PeerNodeList, ?ER_RAFT_SERVER, {?PEER_APPEND_ENTRIES_OP, AppendEntries}),
  {reply, Reply, State, er_fsm_config:get_log_request_timeout(AppConfig)};
handle_call({?APPEND_ENTRIES_CONFIG, {CurrentConfig, AppendEntries}}, _From, #er_peer_state{app_config=AppConfig}=State) ->
  NewConfigEntry = AppendEntries#er_append_entries.leader_info#er_leader_info.config_entry,
  AllConfigList =  er_util:merge_list(er_util:config_list(CurrentConfig), er_util:config_list(NewConfigEntry)),
  PeerNodeList = er_util:peer_node_list(AllConfigList),
  Reply = gen_server:multi_call(PeerNodeList, ?ER_RAFT_SERVER, {?PEER_APPEND_ENTRIES_CONFIG, AppendEntries}),
  {reply, Reply, State, er_fsm_config:get_log_request_timeout(AppConfig)};
handle_call({?INSTALL_SNAPSHOT, {NodeList, Snapshot}}, _From, #er_peer_state{app_config=AppConfig}=State) ->
  Reply = gen_server:multi_call(NodeList, ?ER_RAFT_SERVER, {?PEER_INSTALL_SNAPSHOT, Snapshot}),
  {reply, Reply, State, er_fsm_config:get_log_request_timeout(AppConfig)}.

handle_cast({?APPEND_ENTRIES_NOOP, AppendEntries}, State) ->
  ConfigEntry = AppendEntries#er_append_entries.leader_info#er_leader_info.config_entry,
  ConfigList = er_util:config_list(ConfigEntry),
  PeerNodeList = er_util:peer_node_list(ConfigList),
  gen_server:abcast(PeerNodeList, ?ER_RAFT_SERVER, {?PEER_APPEND_ENTRIES_NOOP, AppendEntries}),
  {noreply, State}.  

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
