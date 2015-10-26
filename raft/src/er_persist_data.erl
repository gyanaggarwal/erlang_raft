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

-module(er_persist_data).

-export([write_data/3, read_data/2, delete_data/2, copy_data/2]).

-include("er_fsm.hrl").

-spec set_data_file(FileName :: string(), TempFileName :: string()) -> ok.
set_data_file(FileName, TempFileName) ->
  case file:read_file_info(TempFileName) of
    {ok, _} ->
      file:delete(FileName),
      ok = file:rename(TempFileName, FileName);
     _ ->
      ok
  end.

-spec write_data(FileName :: string(), TempFileName :: string(), Data :: binary()) -> ok.
write_data(FileName, TempFileName, Data) ->
  ok = file:write_file(TempFileName, Data),
  set_data_file(FileName, TempFileName).

-spec read_data(FileName :: string(), TempFileName :: string()) -> {ok, binary()} | ?ER_EMPTY.
read_data(FileName, TempFileName) ->
  case set_data_file(FileName, TempFileName) of
    ok ->
      case file:read_file(FileName) of
        {ok, Bin} ->
          {ok, Bin};
        {error, _} ->
          ?ER_EMPTY
      end;
    _ ->
      ?ER_EMPTY
  end.
 
-spec delete_data(FileName :: string(), TempFileName :: string()) -> ok.
delete_data(FileName, TempFileName) ->
  set_data_file(FileName, TempFileName),
  file:delete(FileName).

-spec copy_data(SrcFileName :: string(), TrgFileName :: string()) -> ok | {error, atom()}.
copy_data(SrcFileName, TrgFileName) ->
  file:delete(TrgFileName),
  case file:copy(SrcFileName, TrgFileName) of
    {ok, _}         ->
      ok;
    {error, enoent} ->
      ok;
    {error, Reason} ->
      {error, Reason}
  end.
