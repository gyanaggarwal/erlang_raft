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

-module(er_replicated_log_api).

-export([read/1,
         read/0, 
         append/2,
         append/1, 
         append_entry/2,
         append_entry/1,
         append_entry_compact/2, 
         write/2,
         write/1,
         last_entry/1,
         last_entry/0,
         copy/1]).

-include("er_fsm.hrl").

-type status_input()  :: ?ER_STABLE | ?ER_KEEP_STATUS.
-type status_output() :: error | ?ER_UNDEFINED | ?ER_STABLE | ?ER_TRUNCATED.

-spec read(Status :: status_input()) -> {ok, queue:queue(), status_output()} | {error, atom()}.
read(Status) ->
  {ok, Q0, NewStatus} = er_util:check_call(?RL_SERVER, {read, Status}),
  Q1 = er_util:remove_uncommited_entries(Q0, 0, 0, er_queue:new()),
  {ok, Q1, NewStatus}.

-spec read() -> {ok, queue:queue(), status_output()} | {error, atom()}.
read() ->
  read(?ER_STABLE).

-spec copy({BkupFlag :: ?CREATE_BKUP | ?RESTORE_BKUP, DeleteRaftData :: true | false, FileVersion :: string()}) -> ok | {error, atom()}.
copy({BkupFlag, DeleteRaftData, FileVersion}) ->
  er_util:check_call(?RL_SERVER, {copy, {BkupFlag, DeleteRaftData, FileVersion}}).

-spec append(Entries :: queue:queue(), Status :: status_input()) -> {ok, status_output()} | {error, atom(), status_output()}.
append(Entries, Status) ->
  er_util:check_call(?RL_SERVER, {append, {Entries, Status}}).

-spec append(Entries :: queue:queue()) -> {ok, status_output()} | {error, atom(), status_output()}.
append(Entries) ->
  append(Entries, ?ER_KEEP_STATUS).

-spec append_entry(Entry :: #er_log_entry{}, Status :: status_input()) -> {ok, status_output()} | {error, atom(), status_output()}.
append_entry(Entry, Status) ->
  append(er_queue:insert(Entry, er_queue:new()), Status).

-spec append_entry(Entry :: #er_log_entry{}) -> {ok, status_output()} | {error, atom(), status_output()}.
append_entry(Entry) ->
  append_entry(Entry, ?ER_KEEP_STATUS).

-spec append_entry_compact(Entry :: #er_log_entry{}, State :: #er_raft_state{}) -> #er_snapshot{} | {error, atom(), status_output()}.
append_entry_compact(Entry, #er_raft_state{log_entries=LogEntries, applied_term=AppliedTerm, applied_index=AppliedIndex, app_config=AppConfig}) ->
  case append_entry(Entry, ?ER_KEEP_STATUS) of
    {ok, _Status} ->
      case er_fsm_config:get_log_retention_size(AppConfig) of
        {_, infinity} ->
          #er_snapshot{};
        {Min, Max}    ->
          case er_queue:len(LogEntries) >= Max of
            true  ->
              compact_log(AppliedTerm, AppliedIndex, Min);
            false ->
              #er_snapshot{}
          end
      end;
    Other        -> 
      Other
  end.

-spec write(Entries :: queue:queue(), Status :: status_input()) -> {ok, status_output()} | {error, atom(), status_output()}.
write(Entries, Status) ->
  er_util:check_call(?RL_SERVER, {write, {Entries, Status}}).

-spec write(Entries :: queue:queue()) -> {ok, status_output()} | {error, atom(), status_output()}.
write(Entries) ->
  write(Entries, ?ER_STABLE).

-spec last_entry(Status :: status_input()) -> {ok, #er_log_entry{} | ?ER_EMPTY, status_output()} | {error, atom(), status_output()}.
last_entry(Status) ->
  er_util:check_call(?RL_SERVER, {last_entry, Status}).

-spec last_entry() -> {ok, #er_log_entry{} | ?ER_EMPTY, status_output()} | {error, atom(), status_output()}.
last_entry() ->
  last_entry(?ER_KEEP_STATUS).

-spec compact_log(AppliedTerm :: non_neg_integer(), AppliedIndex :: non_neg_integer(), MinCount :: non_neg_integer()) -> #er_snapshot{}.
compact_log(AppliedTerm, AppliedIndex, MinCount) ->
  {ok, Qi0, _} = read(),
  {value, #er_log_entry{term=Term, index=Index}} = er_queue:peek_lifo(Qi0),
  Qo0 = er_util:applied_sub_list(Qi0, Term, Index, AppliedTerm, AppliedIndex, MinCount, er_queue:new()),
  {ok, _Status} = write(Qo0),
  #er_snapshot{log_entries=Qo0, log_stats=?ER_REQUEST, unique_id=#er_unique_id{log_entries=er_util:unique_id(Qo0)}}.




