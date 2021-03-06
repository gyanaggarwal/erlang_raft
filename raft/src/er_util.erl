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

-module(er_util).

-export([get_random/1, 
         get_node_name/0,
         get_rest_of_node_name/0,
         get_file_name/3,
         get_temp_file_name/3,
         get_version_file_name/4,
         check_call/2,
         check_cast/2,
         config_list/1,
         log_entry_lifo/1,
         cmd_id/1,
         unique_id/1,
         peer_node_list/1,
         merge_list/2,
         add_log_entry_id/2,
         remove_log_entry_id/2,
         validate_log_entry_id/2,
         applied_sub_list/7,
         remove_uncommited_entries/4,
         intersection/3,
         key_intersection/3,
         pred_list/2,
         pred_not_list/2,
         acc_list/2,
         pred_tuplelist/2,
         pred_not_tuplelist/2,
         acc_tuplelist/2,
         filter_list/5,
         equal_list/2,
         get_last_term_index/1]).

-include("er_fsm.hrl").

-spec get_random({Min :: non_neg_integer(), Max :: non_neg_integer()}) -> non_neg_integer().
get_random({Min, Max}) ->
  random:uniform(Max-Min)+Min.

-spec get_node_name() -> string().
get_node_name() ->
  lists:takewhile(fun(X) -> X =/= $@ end, atom_to_list(node())).

-spec get_rest_of_node_name() -> string().
get_rest_of_node_name() ->
  lists:dropwhile(fun(X) -> X =/= $@ end, atom_to_list(node())).

-spec get_file_name(NodeName :: string(), DataDir :: string(), FileName :: string()) -> string().
get_file_name(NodeName, DataDir, FileName) ->
  DataDir ++ NodeName ++ FileName.

-spec get_version_file_name(NodeName :: string(), DataDir :: string(), Version :: string(), FileName :: string()) -> string().
get_version_file_name(NodeName, DataDir, Version, FileName) ->
  get_file_name(NodeName, DataDir, get_version_file_name(Version, FileName)).

-spec get_temp_file_name(NodeName :: string(), DataDir :: string(), FileName :: string()) -> string().
get_temp_file_name(NodeName, DataDir, FileName) ->
  get_version_file_name(NodeName, DataDir, ?TEMP_SUFFIX, FileName).

-spec get_version_file_name(string(), string()) -> string().
get_version_file_name(Version, FileName) ->
  Version  ++ FileName.

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

-spec remove_id(Entry :: #er_log_entry{}, USet :: sets:set()) -> sets:set().
remove_id(Entry, USet) ->
  case cmd_id(Entry) of
    undefined -> USet;
    Id        -> case USet of
                   undefined -> USet;
                   _         -> sets:del_element(Id, USet)
                 end
  end.

-spec remove_log_entry_id(Entry :: #er_log_entry{}, UniqueId :: #er_unique_id{}) -> #er_unique_id{}.
remove_log_entry_id(Entry, UniqueId) ->
  LogEntrySet = remove_id(Entry, UniqueId#er_unique_id.log_entries),
  UniqueId#er_unique_id{log_entries=LogEntrySet}.
                
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

-spec remove_uncommited_entries(Qi0 :: queue:queue(), UncommitedTerm :: non_neg_integer(), UncommitedIndex :: non_neg_integer(), Qo0 :: queue:queue()) -> queue:queue().
remove_uncommited_entries(Qi0, UncommitedTerm, UncommitedIndex, Qo0) ->
  case er_queue:is_empty(Qi0) of
    true  ->
      Qo0;
    false ->
      {{value, #er_log_entry{term=Term, index=Index, entry=#er_cmd_entry{type=Type}}=Entry}, Qi1} = er_queue:take_lifo(Qi0),
      case Type of
        ?TYPE_OP            ->
          case Term =:= UncommitedTerm andalso Index =:= UncommitedIndex of
            true  ->
              remove_uncommited_entries(Qi1, 0, 0, Qo0);
            false ->
              remove_uncommited_entries(Qi1, 0, 0, er_queue:insert_reverse(Entry, Qo0))
          end;
        ?TYPE_OP_UNCOMMITED ->
          remove_uncommited_entries(Qi1, Term, Index, Qo0)
      end
  end.

-spec pred_list(Node :: term(), List :: list()) -> true | false.
pred_list(Node, List) ->
  lists:member(Node, List).

-spec pred_not_list(Node :: term(), List :: list()) -> true | false.
pred_not_list(Node, List) ->
  (not lists:member(Node, List)).

-spec acc_list(Node :: term(), List :: list()) -> list().
acc_list(Node, List) ->
  [Node | List].

- spec pred_tuplelist(tuple(), list()) -> true | false.
pred_tuplelist({Node, _}, List)	->
  pred_list(Node, List).

- spec pred_not_tuplelist(tuple(), list()) -> true | false.
pred_not_tuplelist({Node, _}, List) ->
  pred_not_list(Node, List).

-spec acc_tuplelist(tuple(), list()) -> list().
acc_tuplelist({_, Value}, List) ->
  acc_list(Value, List).

-spec intersection(List :: list(), ConfigList :: list(), OutList :: list()) -> list().
intersection(List, ConfigList, OutList) ->
  filter_list(List, ConfigList, OutList, fun pred_list/2, fun acc_list/2).

-spec key_intersection(List :: list(), ConfigList :: list(), OutList :: list()) -> list().
key_intersection(List, ConfigList, OutList) ->
  filter_list(List, ConfigList, OutList, fun pred_tuplelist/2, fun acc_list/2).

-spec filter_list(List :: list(), RefList :: list(), OutList :: list(), PredFun :: fun(), AccFun :: fun()) -> list().
filter_list([H | T], RefList, OutList, PredFun, AccFun) ->
  NewOutList = case PredFun(H, RefList) of
                 true  ->
                   AccFun(H, OutList);
                 false ->
                   OutList
               end,
  filter_list(T, RefList, NewOutList, PredFun, AccFun);
filter_list([], _, OutList, _, _) ->
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
