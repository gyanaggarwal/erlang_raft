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

-module(rl_persist_log).

-export([set_log_file/2, 
         open_log_file/3, 
         close_log_file/1, 
         delete_log_file/1,
         write_log/3, 
         read_log/3, 
         truncate_log/2]).

-include_lib("kernel/include/file.hrl").

-spec set_log_file(string(), string()) -> ok | {error, atom()}.
set_log_file(FileName, TempFileName) ->
  case file:read_file_info(FileName) of
    {ok, _}         ->
      file:delete(TempFileName),
      ok;
    {error, enoent} ->
      file:rename(TempFileName, FileName),
      ok;
    {error, Reason} ->
      {error, Reason}
  end.

-spec open_log_file(string(), non_neg_integer(), non_neg_integer()) -> {ok, file:io_device(), non_neg_integer()} | {error, atom()}.  
open_log_file(FileName, Version, VersionSize) ->
  FileSize0 = case file:read_file_info(FileName) of
                {ok, FileInfo}  -> case FileInfo#file_info.size of
                                     undefined -> 0;
                                     Other     -> Other
                                   end;
                {error, enoent} -> 0
              end,

  {ok, File} = file:open(FileName, [append, read, binary, raw]),

  FileSize1 = case FileSize0 =:= 0 andalso VersionSize > 0 of   
                true  -> file:write(File, <<Version>>),
                         VersionSize;
                false -> FileSize0
              end,

  {ok, File, FileSize1}.

-spec close_log_file(file:io_device()) -> ok | {error, atom()}.  
close_log_file(File) ->
  file:close(File).

-spec delete_log_file(string()) -> ok | {error, atom()}.
delete_log_file(FileName) ->
  case file:delete(FileName) of
    ok              ->
      ok;
    {error, enoent} ->
      ok;
    {error, Reason} ->
      {error, Reason}
  end.

-spec write_log(file:io_device(), non_neg_integer(), binary()) -> {ok, non_neg_integer()} | {error, atom()}.  
write_log(File, Location, Data) ->
  ok = file:write(File, Data), 
  {ok, Location+byte_size(Data)}.
  
-spec read_log(file:io_device(), non_neg_integer(), non_neg_integer()) -> {ok, non_neg_integer(), binary()} | eof | {error, atom()}.  
read_log(File, Location, Size) ->
  case file:pread(File, Location, Size) of
    eof             ->
      eof;
    {error, Reason} ->
      {error, Reason};
    {ok, Data}      ->
      {ok, Location+byte_size(Data), Data}
  end.

 -spec truncate_log(file:io_device(), non_neg_integer()) -> ok | {error, atom()}.
 truncate_log(File, Pos) ->
    {ok, _} = file:position(File, Pos),
    file:truncate(File).

