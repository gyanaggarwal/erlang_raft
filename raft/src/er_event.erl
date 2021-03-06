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

-module(er_event).

-export([start_link/0, add_handler/2, delete_handler/2]).

-export([state/3, request/3, reply/3, data/4]).

-define(SERVER, ?MODULE).

start_link() ->
  gen_event:start_link({local, ?SERVER}).

add_handler(Handler, Args) ->
  gen_event:add_handler(?SERVER, Handler, Args).

delete_handler(Handler, Args) ->
  gen_event:delete_handler(?SERVER, Handler, Args).

event_notify(Tag, Event) ->
  gen_event:notify(?SERVER, {Tag, Event}).

state(Module, Msg, State) ->
  event_notify(state, {Module, Msg, State}).

data(Module, Msg, DataMsg, Data) ->
  event_notify(data, {Module, Msg, DataMsg, Data}).

request(Module, Msg, Request) ->
  data(Module, Msg, request, Request).

reply(Module, Msg, Reply) ->
  data(Module, Msg, reply, Reply).