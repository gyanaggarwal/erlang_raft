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

-module(er_event).

-export([start_link/0, add_handler/2, delete_handler/2]).

-export([state/2, request/2, reply/2, data/3]).

-define(SERVER, ?MODULE).

start_link() ->
  gen_event:start_link({local, ?SERVER}).

add_handler(Handler, Args) ->
  gen_event:add_handler(?SERVER, Handler, Args).

delete_handler(Handler, Args) ->
  gen_event:delete_handler(?SERVER, Handler, Args).

event_notify(Tag, Event) ->
  gen_event:notify(?SERVER, {Tag, Event}).

state(Msg, State) ->
  event_notify(state, {Msg, State}).

data(Msg, DataMsg, Data) ->
  event_notify(data, {Msg, DataMsg, Data}).

request(Msg, Request) ->
  data(Msg, request, Request).

reply(Msg, Reply) ->
  data(Msg, reply, Reply).