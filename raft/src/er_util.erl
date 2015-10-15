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
         read_snapshot/2,
         config_list/1,
         log_entry_lifo/1,
         cmd_id/1,
         unique_id/1,
         peer_node_list/1,
         merge_list/2,
         add_log_entry_id/2,
         validate_log_entry_id/2,
         applied_sub_list/7]).

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

%-spec read_config(AppConfig :: #er_app_config{}, Snapshot :: #er_snapshot{}) -> #er_snapshot{}.
%read_config(AppConfig, Snapshot) ->
%  case Snapshot#er_snapshot.config_entry of
%    ?ER_REQUEST ->
%      Entry1 = case er_persist_data_api:read_config(AppConfig) of
%                 ?ER_EMPTY   -> ?ER_EMPTY;
%                 {ok, Entry} -> Entry
%               end,
%      Snapshot#er_snapshot{config_entry=Entry1, unique_id=add_config_entry_id(Entry1, Snapshot#er_snapshot.unique_id)};
%    _Other      ->
%      Snapshot
%  end.

-spec read_state_machine(AppConfig :: #er_app_config{}, Snapshot :: #er_snapshot{}) ->	#er_snapshot{}.
read_state_machine(AppConfig, Snapshot) ->
  case Snapshot#er_snapshot.state_machine of
    ?ER_REQUEST ->
      StateMachine = er_fsm_config:get_state_machine_api(AppConfig),
      Snapshot#er_snapshot{state_machine=StateMachine:read()};
    _Other      ->
      Snapshot
  end.

-spec read_voted_for(AppConfig :: #er_app_config{}, Snapshot :: #er_snapshot{}) -> #er_snapshot{}.
read_voted_for(AppConfig, Snapshot) ->
  case Snapshot#er_snapshot.voted_for of
    ?ER_REQUEST	->
      Vote1 = case er_persist_data_api:read_vote(AppConfig) of
                ?ER_EMPTY   -> ?ER_EMPTY;
                {ok, Vote}  -> Vote
              end,
      Snapshot#er_snapshot{voted_for=Vote1};
    _Other      ->
      Snapshot
  end.

-spec read_log_entries(AppConfig :: #er_app_config{}, Snapshot :: #er_snapshot{}) -> #er_snapshot{}.
read_log_entries(_AppConfig, Snapshot) ->
  case Snapshot#er_snapshot.log_entries of
    ?ER_REQUEST ->
      {ok, Q0, _Status} = er_replicated_log_api:read(),
      case er_queue:is_queue(Q0) of 
        true  -> 
          Snapshot1 = case Snapshot#er_snapshot.log_stats of
                        ?ER_REQUEST ->
                          Snapshot#er_snapshot{log_entry_count=er_queue:len(Q0), unique_id=Snapshot#er_snapshot.unique_id#er_unique_id{log_entries=unique_id(Q0)}};
                        _           ->
                          Snapshot
                      end,
          Snapshot1#er_snapshot{log_entries=Q0};
        false -> 
          Snapshot#er_snapshot{log_entry_count=0, log_entries=er_queue:new()}
      end;
    _Other      ->
      Snapshot
  end.

-spec read_snapshot(AppConfig :: #er_app_config{}, Snapshot :: #er_snapshot{}) -> {ok, #er_snapshot{}} | {error, atom()}.
read_snapshot(AppConfig, Snapshot) ->
  Snapshot1 = read_state_machine(AppConfig, Snapshot),
  Snapshot2 = read_voted_for(AppConfig, Snapshot1),
  {ok, read_log_entries(AppConfig, Snapshot2)}.

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

%-spec add_config_entry_id(Entry :: #er_log_entry{}, UniqueId :: #er_unique_id{}) -> #er_unique_id{}.
%add_config_entry_id(Entry, UniqueId) ->
%  case cmd_id(Entry) of
%    undefined -> UniqueId;
%    Id        -> UniqueId#er_unique_id{config_entry=Id}
%  end.

-spec add_log_entry_id(Entry :: #er_log_entry{}, UniqueId :: #er_unique_id{}) -> #er_unique_id{}.
add_log_entry_id(Entry, UniqueId) ->
  LogEntrySet = add_id(Entry, UniqueId#er_unique_id.log_entries),
  UniqueId#er_unique_id{log_entries=LogEntrySet}.

%-spec validate_config_entry_id(Entry :: #er_log_entry{}, UniqueId :: #er_unique_id{}) -> boolean().
%validate_config_entry_id(Entry, UniqueId) ->
%  case cmd_id(Entry) of
%    undefined -> false;
%    Id        -> Id =/= UniqueId#er_unique_id.config_entry
%  end.

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
