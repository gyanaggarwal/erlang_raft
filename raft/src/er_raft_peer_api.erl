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

-module(er_raft_peer_api).

-export([request_vote/1,
         append_entries_op/1,
         append_entries_config/2,
         append_entries_noop/1,
         install_snapshot/2]).

-include("er_fsm.hrl").

-spec request_vote(RequestVote :: #er_request_vote{}) -> term() | {error, atom()}.
request_vote(RequestVote) ->
  call({?REQUEST_VOTE, RequestVote}).

-spec append_entries_op(AppendEntries :: #er_append_entries{}) -> term() | {error, atom()}.
append_entries_op(AppendEntries) ->
  call({?APPEND_ENTRIES_OP, AppendEntries}).

-spec append_entries_config(ConfigEntry :: #er_log_entry{}, AppendEntries :: #er_append_entries{}) -> term() | {error, atom()}.
append_entries_config(ConfigEntry, AppendEntries) ->
  call({?APPEND_ENTRIES_CONFIG, {ConfigEntry, AppendEntries}}).

-spec append_entries_noop(AppendEntries :: #er_append_entries{}) -> ok | {error, atom()}.
append_entries_noop(AppendEntries) ->
  cast({?APPEND_ENTRIES_NOOP, AppendEntries}).

-spec install_snapshot(NodeList ::list(), Snapshot :: #er_snapshot{}) -> term() | {error, atom()}.
install_snapshot(NodeList, Snapshot) ->
  call({?INSTALL_SNAPSHOT, {NodeList, Snapshot}}).

call(Request) ->
  er_util:check_call(?ER_PEER_SERVER, Request).

cast(Request) ->
  er_util:check_cast(?ER_PEER_SERVER, Request).