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

-module(rl_log_operation_api).

-include("er_fsm.hrl").

-export([open/2,
         close/2,
         read/2,
         last_entry/2,
         append/4, 
         write/5]).

-spec open(AppConfig :: #er_app_config{}, FileName :: string()) -> {ok, file:io_device(), non_neg_integer()} | {error, atom()}.
open(AppConfig, FileName) ->
  EntryOperation = er_fsm_config:get_log_entry_operation_api(AppConfig),
  rl_persist_log:open_log_file(FileName, er_fsm_config:get_log_file_header_version(AppConfig), EntryOperation:file_header_byte_size(AppConfig)).
      
-spec close(AppConfig :: #er_app_config{}, File :: file:io_device()) -> ok | {error, atom()}.
close(_AppConfig, File) ->
  rl_persist_log:close_log_file(File).

-spec read(AppConfig :: #er_app_config{}, File :: file:io_device()) ->  {atom(), non_neg_integer(), queue:queue()}.
read(AppConfig, File) ->
  EntryOperation = er_fsm_config:get_log_entry_operation_api(AppConfig),
  read(AppConfig, EntryOperation, File, EntryOperation:file_header_byte_size(AppConfig), queue:new(), ?ER_STABLE).

-spec read(AppConfig :: #er_app_config{}, EntryOperation :: atom(), File :: file:io_device(), Loc :: non_neg_integer(), Q0 :: queue:queue(), Status :: atom()) -> {atom(), non_neg_integer(), queue:queue()}.
read(AppConfig, EntryOperation, File, Loc, Q0, Status) ->
  case rl_persist_log:read_log(File, Loc, EntryOperation:header_byte_size(AppConfig)) of
    eof                -> 
      {Status, Loc, Q0};
    {error, _}         -> 
      {error, Loc, Q0};
    {ok, Loc1, HData} ->
      case EntryOperation:entry_header(AppConfig, HData) of
        ?ER_BAD_ENTRY       ->
          rl_persist_log:truncate_log(File, Loc),
          {?ER_TRUNCATED, Loc, Q0};
        {_, _, _, DataSize} ->
          case rl_persist_log:read_log(File, Loc1, DataSize+EntryOperation:trailer_byte_size(AppConfig)) of
            eof               ->
              rl_persist_log:truncate_log(File, Loc),
              {?ER_TRUNCATED, Loc, Q0};
            {error, _}        ->
              {error, Loc, Q0};
            {ok, Loc2, RData} ->
              case EntryOperation:binary_to_entry(AppConfig, HData, RData) of
                ?ER_BAD_ENTRY ->
                  rl_persist_log:truncate_log(File, Loc),
                  {?ER_TRUNCATED, Loc, Q0};
                {ok, Entry}   ->
                  read(AppConfig, EntryOperation, File, Loc2, queue:in(Entry, Q0), Status)
              end
          end
      end
  end.

-spec append(AppConfig :: #er_app_config{}, File :: file:io_device(), Loc :: non_neg_integer(), Q0 :: queue:queue()) -> {ok, non_neg_integer()} | {error, atom()}.          
append(AppConfig, File, Loc, Q0)->
 EntryOperation = er_fsm_config:get_log_entry_operation_api(AppConfig),
 append(AppConfig, EntryOperation, File, Loc, Q0).

-spec append(AppConfig :: #er_app_config{}, EntryOperation :: atom(), File :: file:io_device(), Loc :: non_neg_integer(), Q0 :: queue:queue()) -> {ok, non_neg_integer()} | {error, atom()}.
append(AppConfig, EntryOperation, File, Loc, Q0) ->
  case queue:out(Q0) of
    {empty, _}           ->
      file:sync(File),
      {ok, Loc};
    {{value, Entry}, Q1} ->
      {ok, NewLoc} = append_entry(AppConfig, EntryOperation, File, Loc, Entry),
      append(AppConfig, EntryOperation, File, NewLoc, Q1)
  end.

-spec append_entry(AppConfig :: #er_app_config{}, EntryOperation :: atom(), File :: file:io_device(), Loc :: non_neg_integer(), Entry :: #er_log_entry{}) -> {ok, non_neg_integer()} | {error, atom()}.                      
append_entry(AppConfig, EntryOperation, File, Loc, Entry) ->
  Bin = EntryOperation:entry_to_binary(AppConfig, Entry),
  rl_persist_log:write_log(File, Loc, Bin).

-spec write(AppConfig :: #er_app_config{}, File :: file:io_device(), FileName :: string(), TempFileName :: string(), Q0 :: queue:queue()) -> {ok, file:io_device(), non_neg_integer()} | {error, atom()}.
write(AppConfig, File, FileName, TempFileName, Q0) ->
  EntryOperation = er_fsm_config:get_log_entry_operation_api(AppConfig),
  ok = rl_persist_log:close_log_file(File),
  ok = rl_persist_log:delete_log_file(TempFileName),
  {ok, TempFile, Loc0} = rl_persist_log:open_log_file(TempFileName, er_fsm_config:get_log_file_header_version(AppConfig), EntryOperation:file_header_byte_size(AppConfig)),
  {ok, _Loc1} = append(AppConfig, TempFile, Loc0, Q0),
  ok = rl_persist_log:close_log_file(TempFile),
  ok = rl_persist_log:delete_log_file(FileName),
  ok = file:rename(TempFileName, FileName),
  rl_persist_log:open_log_file(FileName, er_fsm_config:get_log_file_header_version(AppConfig), EntryOperation:file_header_byte_size(AppConfig)).
  
-spec last_entry(AppConfig :: #er_app_config{}, File :: file:io_device()) -> {atom(), #er_log_entry{}} | {atom(), ?ER_EMPTY}.
last_entry(AppConfig, File) ->
  {Status, _Loc, Q0} = read(AppConfig, File),
  case queue:peek_r(Q0) of 
    empty          ->
      {Status, ?ER_EMPTY};
    {value, Entry} ->
      {Status, Entry}
  end.


    
  