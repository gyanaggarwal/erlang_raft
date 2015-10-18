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

-module(er_util).

-export([get_election_timeout/1, 
         get_node_name/0,
         get_file_name/3,
         get_temp_file_name/3,
         check_call/2,
         check_cast/2,
         config_list/1,
         log_entry_lifo/1,
         cmd_id/1,
         unique_id/1,
         peer_node_list/1,
         merge_list/2,
         add_log_entry_id/2,
         validate_log_entry_id/2,
         applied_sub_list/7,
         intersection/3,
         equal_list/2,
         get_last_term_index/1]).

-include("er_fsm.hrl").

-spec get_election_timeout({ElectionTimeoutMin :: non_neg_integer(), ElectionTimeoutMax :: non_neg_integer()}) -> non_neg_integer().
get_election_timeout({ElectionTimeoutMin, ElectionTimeoutMax}) ->
  random:uniform(ElectionTimeoutMax-ElectionTimeoutMin)+ElectionTimeoutMin.

-spec get_node_name() -> string().
get_node_name() ->
  lists:takewhile(fun(X) -> X =/= $@ end, atom_to_list(node())).

-spec get_file_name(NodeName :: string(), DataDir :: string(), FileName :: string()) -> string().
get_file_name(NodeName, DataDir, FileName) ->
  DataDir ++ NodeName ++ FileName.

-spec get_temp_file_name(NodeName :: string(), DataDir :: string(), FileName :: string()) -> string().
get_temp_file_name(NodeName, DataDir, FileName) ->
  get_file_name(NodeName, DataDir, get_temp_file_name(FileName)).

-spec get_temp_file_name(string()) -> string().
get_temp_file_name(FileName) ->
  ?TEMP_SUFFIX ++ FileName.

-spec check_call(Server :: atom(), Request :: term()) -> {error, ?ER_UNAVAILABLE} | term().
check_call(Server, Request) ->
  case whereis(Server) of
    undefined ->
      {error, ?ER_UNAVAILABLE};
    _         ->
      gen_server:call(Server, Request)
  end.

-spec check_cast(Server :: atom(), Request :: term()) -> {error, ?ER_UNAVAILABLE} | ok.
check_cast(Server, Request) ->
  case whereis(Server) of
    undefined ->
      {error, ?ER_UNAVAILABLE};
    _         ->
      gen_server:cast(Server, Request)
  end.

-spec add_id(Entry :: #er_log_entry{}, USet :: sets:set()) -> sets:set().
add_id(Entry, USet) ->
  case cmd_id(Entry) of
    undefined -> USet;
    Id        -> USet1 = case USet of
                           undefined -> sets:new();
                           Other     -> Other
                         end,
                 sets:add_element(Id, USet1)
  end.

-spec add_log_entry_id(Entry :: #er_log_entry{}, UniqueId :: #er_unique_id{}) -> #er_unique_id{}.
add_log_entry_id(Entry, UniqueId) ->
  LogEntrySet = add_id(Entry, UniqueId#er_unique_id.log_entries),
  UniqueId#er_unique_id{log_entries=LogEntrySet}.

-spec validate_log_entry_id(Entry :: #er_log_entry{}, UniqueId :: #er_unique_id{}) -> boolean().
validate_log_entry_id(Entry, UniqueId) ->
  case cmd_id(Entry) of
    undefined -> false;
    Id        -> not sets:is_element(Id, UniqueId#er_unique_id.log_entries)
  end.

-spec config_list(ConfigEntry :: #er_log_entry{}) -> list().
config_list(ConfigEntry = #er_log_entry{}) ->
  ConfigEntry#er_log_entry.entry#er_cmd_entry.cmd;
config_list(_ConfigEntry) ->
  [].

-spec cmd_id(Entry :: #er_log_entry{}) -> term().
cmd_id(Entry = #er_log_entry{}) ->
  Entry#er_log_entry.entry#er_cmd_entry.id;
cmd_id(_Entry) ->
  undefined.

-spec log_entry_lifo(AppendEntries :: #er_append_entries{}) -> #er_log_entry{} | empty.
log_entry_lifo(AppendEntries) ->
  case er_queue:peek_lifo(AppendEntries#er_append_entries.log_entries) of
    empty          ->
      empty; 
    {value, Entry} ->
      Entry
  end.

-spec unique_id(Q0 :: queue:queue()) -> sets:set().
unique_id(Q0) ->
  lists:foldl(fun add_id/2, sets:new(), er_queue:to_list(Q0)).
                      
-spec peer_node_list(NodeList :: list()) -> list().
peer_node_list(NodeList) ->
  lists:filter(fun(N) -> N =/= node() end, NodeList).

-spec merge_list(List1 :: list(), List2 :: list()) -> list().
merge_list(List1, List2) ->
  lists:foldl(fun(N, Acc) -> case lists:member(N, Acc) of
                               true  -> Acc;
                               false -> [N | Acc]
                             end end, List1, List2).

-spec add_log_entry(Entry :: #er_log_entry{}, AppliedTerm :: non_neg_integer(), AppliedIndex :: non_neg_integer(), MinCount :: non_neg_integer(), Q0 :: queue:queue()) -> {non_neg_integer(), queue:queue()}.
add_log_entry(#er_log_entry{term=Term, index=Index}=Entry, AppliedTerm, AppliedIndex, MinCount, Q0) ->
  case {Term >= AppliedTerm andalso Index > AppliedIndex, MinCount > 0} of
    {true, _}      ->
      {MinCount, er_queue:insert_reverse(Entry, Q0)};
    {false, true}  ->
      {MinCount-1, er_queue:insert_reverse(Entry, Q0)};
    {false, false} ->
      {MinCount, Q0}
  end.

-spec applied_sub_list(Qi0 :: queue:queue(), CommitTerm :: non_neg_integer(), CommitIndex :: non_neg_integer(), AppliedTerm :: non_neg_integer(), AppliedIndex :: non_neg_integer(), MinCount :: non_neg_integer(), Qo0 :: queue:queue()) -> queue:queue().
applied_sub_list(Qi0, CommitTerm, CommitIndex, AppliedTerm, AppliedIndex, MinCount, Qo0) ->
  case er_queue:is_empty(Qi0) of 
    true  ->
      Qo0;
    false ->
      {{value, #er_log_entry{term=Term, index=Index}=Entry}, Qi1} = er_queue:take_lifo(Qi0),
      {MinCount1, Qo1} = case (Term =< CommitTerm andalso Index =< CommitIndex) of
                           true  ->
                             add_log_entry(Entry, AppliedTerm, AppliedIndex, MinCount, Qo0);
                           false ->
                             {MinCount, Qo0}
                         end,
      applied_sub_list(Qi1, CommitTerm, CommitIndex, AppliedTerm, AppliedIndex, MinCount1, Qo1)
  end.

-spec intersection(List1 :: list(), ConfigList :: list(), OutList :: list()) -> list().
intersection([Node | TList], ConfigList, OutList) ->
  NewOutList = case lists:member(Node, ConfigList) of
                 true  ->
                   [Node | OutList];
                 false ->
                   OutList
               end,
  intersection(TList, ConfigList, NewOutList);
intersection([], _ConfigList, OutList) ->
  OutList.

-spec equal_list(List1 :: list(), List2 :: list()) -> boolean().
equal_list(List1, List2) ->
  case length(List1) =:= length(List2) of
    true  ->
      List3 = intersection(List1, List2, []),
      length(List3) =:= length(List1);
    false ->
      false
  end.

-spec get_last_term_index(Q0 :: queue:queue()) -> {non_neg_integer(), non_neg_integer()}.
get_last_term_index(Q0) ->
  case er_queue:peek_lifo(Q0) of
    empty          ->
      {0, 0};
    {value, Entry} ->
      {Entry#er_log_entry.term, Entry#er_log_entry.index}
  end.
