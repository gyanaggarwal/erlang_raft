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

-module(er_persist_data_api).

-export([write_data/3, 
         write_config/2,
         write_vote/2, 
         read_data/2,
         read_config/1,
         read_vote/1,
         delete_config/1,
         delete_vote/1,
         copy_data/2]).

-include("er_fsm.hrl").

-spec write_data(FileName :: string(), TempFileName :: string(), Data :: term()) -> ok.
write_data(FileName, TempFileName, Data) ->
  er_persist_data:write_data(FileName, TempFileName, term_to_binary(Data)).

-spec read_data(FileName :: string(), TempFileName :: string()) -> {ok, term()} | ?ER_EMPTY.
read_data(FileName, TempFileName) ->
  case er_persist_data:read_data(FileName, TempFileName) of
    {ok, Bin} ->
      {ok, binary_to_term(Bin)};
    ?ER_EMPTY ->
      ?ER_EMPTY
  end.

-spec write_config(AppConfig :: #er_app_config{}, Data :: term()) -> ok.
write_config(AppConfig, Data) ->
  FileName = er_fsm_config:get_file_config(AppConfig),
  write_data(FileName#er_file_name.file_name, FileName#er_file_name.temp_file_name, Data).

-spec read_config(AppConfig :: #er_app_config{}) -> {ok, term()} | ?ER_EMPTY.
read_config(AppConfig) ->
  FileName = er_fsm_config:get_file_config(AppConfig),
  read_data(FileName#er_file_name.file_name, FileName#er_file_name.temp_file_name).

-spec delete_config(AppConfig :: #er_app_config{}) -> ok.
delete_config(AppConfig) ->
  FileName = er_fsm_config:get_file_config(AppConfig),
  er_persist_data:delete_data(FileName#er_file_name.file_name, FileName#er_file_name.temp_file_name).

-spec write_vote(AppConfig :: #er_app_config{}, Data :: term()) -> ok.
write_vote(AppConfig, Data) ->
  FileName = er_fsm_config:get_file_metadata(AppConfig),
  write_data(FileName#er_file_name.file_name, FileName#er_file_name.temp_file_name, Data).

-spec read_vote(AppConfig :: #er_app_config{}) -> {ok, term()} | ?ER_EMPTY.
read_vote(AppConfig) ->
  FileName = er_fsm_config:get_file_metadata(AppConfig),
  read_data(FileName#er_file_name.file_name, FileName#er_file_name.temp_file_name).

-spec delete_vote(AppConfig :: #er_app_config{}) -> ok.
delete_vote(AppConfig) ->
  FileName = er_fsm_config:get_file_metadata(AppConfig),
  er_persist_data:delete_data(FileName#er_file_name.file_name, FileName#er_file_name.temp_file_name).

-spec copy_data(AppConfig :: #er_app_config{}, {BkupFlag :: ?CREATE_BKUP | ?RESTORE_BKUP, DeleteRaftData :: true | false, FileVersion :: string()}) -> ok.
copy_data(AppConfig, {BkupFlag, DeleteRaftData, FileVersion}) ->
  DataDir = er_fsm_config:get_data_dir(AppConfig),
  FileMetadata = er_fsm_config:get_file_metadata(AppConfig),
  NodeName = er_util:get_node_name(),
  FileName1 = FileMetadata#er_file_name.file_name,
  FileName2 = er_util:get_version_file_name(NodeName, DataDir, FileVersion, FileMetadata#er_file_name.file_suffix),
  {SrcFileName, TrgFileName} = case BkupFlag of
                                 ?CREATE_BKUP  ->             
                                   {FileName1, FileName2};
                                 ?RESTORE_BKUP ->
                                   {FileName2, FileName1}
                               end, 
  ok = er_persist_data:copy_data(SrcFileName, TrgFileName),
  case DeleteRaftData of
    true  ->
      file:delete(SrcFileName);
    false ->
      ok
  end.  

