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

-module(er_vote).

-export([valid/3]).

-include("er_fsm.hrl").

-spec valid(RequestVote :: #er_vote{}, CurrentVote :: #er_vote{}, State :: #er_raft_state{}) -> boolean().
valid(RequestVote, CurrentVote, State) ->
  valid_vote(RequestVote, CurrentVote) andalso valid_vote(RequestVote, State).

valid_vote(#er_vote{term=RequestTerm, prev_log_term=RequestLogTerm, prev_log_index=RequestLogIndex},
           #er_vote{term=CurrentTerm, prev_log_term=CurrentLogTerm, prev_log_index=CurrentLogIndex}) ->
  valid_vote(RequestTerm, RequestLogTerm, RequestLogIndex, CurrentTerm, CurrentLogTerm, CurrentLogIndex);
valid_vote(#er_vote{term=RequestTerm, prev_log_term=RequestLogTerm, prev_log_index=RequestLogIndex},
           #er_raft_state{current_term=CurrentTerm, prev_log_term=PrevLogTerm, prev_log_index=PrevLogIndex}) ->
  valid_vote(RequestTerm, RequestLogTerm, RequestLogIndex, CurrentTerm, PrevLogTerm, PrevLogIndex);
valid_vote(_, _) ->
  true.

valid_vote(RequestTerm, RequestLogTerm, RequestLogIndex, CurrentTerm, CurrentLogTerm, CurrentLogIndex) ->
  (RequestTerm > CurrentTerm andalso RequestLogTerm >= CurrentLogTerm andalso RequestLogIndex >= CurrentLogIndex) orelse
  (RequestTerm =:= CurrentTerm andalso RequestLogTerm > CurrentLogTerm andalso RequestLogIndex >= CurrentLogIndex) orelse
  (RequestTerm =:= CurrentTerm andalso RequestLogTerm =:= CurrentLogTerm andalso RequestLogIndex > CurrentLogIndex).
