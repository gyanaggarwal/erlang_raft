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

-module(sm_server).

-behavior(gen_server).

-export([start_link/0]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state_machine, {term=0, index=0, data}).

-define(SERVER, ?MODULE).

-spec start_link() -> {ok, pid()}.
start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec init(list()) -> {ok, #state_machine{}}.
init([]) ->
  {ok, #state_machine{}}.

handle_call(read, _From, State) ->
  {reply, get_tuple(State), State};
handle_call({write, {Term, Index, Data}}, _From, _State) ->
  NewState = #state_machine{term=Term, index=Index, data=Data},
  {reply, get_tuple(NewState), NewState};
handle_call({update, [{Term, Index, Cmd} | _]}, _From, State) ->
  NewState = new_state(Term, Index, Cmd, State),
  {reply, get_tuple(NewState), NewState};
handle_call({update, []}, _From, State) ->
  {reply, get_tuple(State), State}.

handle_cast(_, State) ->
  {noreply, State}.

handle_info(_, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

new_state(Term, Index, Cmd, #state_machine{term=CurrTerm, index=CurrIndex} = State) ->
  case Term > CurrTerm orelse (Term =:= CurrTerm andalso Index > CurrIndex) of
    true  -> #state_machine{term=Term, index=Index, data=Cmd};
    false -> State
  end.

get_tuple(#state_machine{term=Term, index=Index, data=Data}) ->
  {Term, Index, Data}.