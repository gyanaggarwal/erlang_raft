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

-module(er_state_machine_api).

-behavior(er_state_machine).

-export([read/0, update/1, write/1]).

-include("er_fsm.hrl").

-define(SERVER, sm_server).

-spec read() -> {non_neg_integer(), non_neg_integer(), term()}.
read() ->
  gen_server:call(?SERVER, read).

-spec update(Q0 :: queue:queue()) -> {non_neg_integer(), non_neg_integer(), term()}.
update(Q0) ->
  gen_server:call(?SERVER, {update_sync, make_cmd_list(Q0, [])}).

-spec write({Term :: non_neg_integer(), Index :: non_neg_integer(), Data :: term()}) -> {non_neg_integer(), non_neg_integer(), term()}.
write({Term, Index, Data}) ->
  gen_server:call(?SERVER, {write, {Term, Index, Data}}).

make_cmd_list(Q0, L0) ->
  case er_queue:take_fifo(Q0) of
    {empty, _}                                                                         ->
      L0;
    {{value, #er_log_entry{term=Term, index=Index, entry=#er_cmd_entry{cmd=Cmd}}}, Q1} ->
      L1 = [{Term, Index, Cmd} | L0],
      make_cmd_list(Q1, L1)
  end.