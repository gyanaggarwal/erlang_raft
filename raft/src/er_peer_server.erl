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
  PeerNodeList = peer_node_list(RequestVote),
  Reply = gen_server:multi_call(PeerNodeList, ?ER_RAFT_SERVER, {?PEER_REQUEST_VOTE, RequestVote}, er_fsm_config:get_log_request_timeout(AppConfig)),
  {reply, Reply, State};
handle_call({?APPEND_ENTRIES_OP, AppendEntries}, _From, #er_peer_state{app_config=AppConfig}=State) ->
  PeerNodeList = peer_node_list(AppendEntries),
  Reply = gen_server:multi_call(PeerNodeList, ?ER_RAFT_SERVER, {?PEER_APPEND_ENTRIES_OP, AppendEntries}, er_fsm_config:get_log_request_timeout(AppConfig)),
  {reply, Reply, State};
handle_call({?APPEND_ENTRIES_CONFIG, OldConfigEntry, AppendEntries}, _From, #er_peer_state{app_config=AppConfig}=State) ->
  PeerNodeList = peer_node_list(OldConfigEntry, AppendEntries),
  Reply = gen_server:multi_call(PeerNodeList, ?ER_RAFT_SERVER, {?PEER_APPEND_ENTRIES_CONFIG, AppendEntries}, er_fsm_config:get_log_request_timeout(AppConfig)),
  {reply, Reply, State};
handle_call({?INSTALL_SNAPSHOT, {NodeList, Snapshot}}, _From, #er_peer_state{app_config=AppConfig}=State) ->
  Reply = gen_server:multi_call(NodeList, ?ER_RAFT_SERVER, {?PEER_INSTALL_SNAPSHOT, Snapshot}, er_fsm_config:get_log_request_timeout(AppConfig)),
  {reply, Reply, State}.

handle_cast({?APPEND_ENTRIES_NOOP, AppendEntries}, State) ->
  PeerNodeList = peer_node_list(AppendEntries),
  gen_server:abcast(PeerNodeList, ?ER_RAFT_SERVER, {?PEER_APPEND_ENTRIES_NOOP, AppendEntries}),
  {noreply, State}.  

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

peer_node_list(OldConfigEntry, #er_append_entries{leader_info=#er_leader_info{config_entry=NewConfigEntry}}) ->
  OldConfigList = er_util:config_list(OldConfigEntry),
  NewConfigList = er_util:config_list(NewConfigEntry),
  ConfigList = er_util:merge_list(OldConfigList, NewConfigList),
  er_util:peer_node_list(ConfigList).

peer_node_list(#er_append_entries{leader_info=#er_leader_info{config_entry=ConfigEntry}}) ->
  peer_node_list(ConfigEntry);
peer_node_list(#er_request_vote{config_entry=ConfigEntry}) ->
  peer_node_list(ConfigEntry);
peer_node_list(#er_log_entry{}=ConfigEntry) ->
  ConfigList = er_util:config_list(ConfigEntry),
  er_util:peer_node_list(ConfigList).


