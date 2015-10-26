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

-module(rl_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("er_fsm.hrl").

-define(SERVER, ?MODULE).

-spec start_link(AppConfig :: #er_app_config{}) -> {ok, pid()}.
start_link(AppConfig) ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [AppConfig], []).

-spec init(list()) -> {ok, #er_replicated_log{}}.
init([AppConfig]) ->
  FileName = er_fsm_config:get_file_replicated_log(AppConfig),
  ok = rl_persist_log:set_log_file(FileName#er_file_name.file_name, FileName#er_file_name.temp_file_name),
  {ok, File, _} = rl_log_operation_api:open(AppConfig, FileName#er_file_name.file_name),
  {ok, #er_replicated_log{file=File, app_config=AppConfig}}.

handle_call({read, Status}, _From, #er_replicated_log{file=File, app_config=AppConfig}=State) ->
  {CurrStatus, _Loc, Q0} = rl_log_operation_api:read(AppConfig, File),
  NewStatus = new_status(Status, CurrStatus),  
  {reply, {ok, Q0, NewStatus}, State#er_replicated_log{status=NewStatus}};
handle_call({append, {Q0, Status}}, _From, #er_replicated_log{file=File, app_config=AppConfig, status=?ER_STABLE}=State) ->
  {Reply, NewStatus} = case rl_log_operation_api:append(AppConfig, File, 0, Q0) of
                         {error, Reason} ->
                            Status1 = new_status(Status, error),
                            {{error, Reason, Status1}, Status1};
                         {ok, _Loc}      ->
                            Status1 = new_status(Status, ?ER_STABLE),
                            {{ok, Status1}, Status1}
                       end,
  {reply, Reply, State#er_replicated_log{status=NewStatus}};
handle_call({append, {_Q0, _Status}}, _From, #er_replicated_log{status=CurrStatus}=State) ->
  {reply, {error, CurrStatus, CurrStatus}, State};
handle_call({write, {Q0, Status}}, _From, #er_replicated_log{file=File, app_config=AppConfig}=State) ->
  FileName = er_fsm_config:get_file_replicated_log(AppConfig),
  {Reply, NewFile, NewStatus} = case rl_log_operation_api:write(AppConfig, File, FileName#er_file_name.file_name, FileName#er_file_name.temp_file_name, Q0) of
                                  {error, Reason}   ->
                                    Status1 = new_status(Status, error),
                                    {{error, Reason, Status1}, File, Status1};
                                  {ok, File1, _Loc} ->
                                    {{ok, ?ER_STABLE}, File1, ?ER_STABLE}
                                end,
  {reply, Reply, State#er_replicated_log{file=NewFile, status=NewStatus}};
handle_call({last_entry, Status}, _From, #er_replicated_log{file=File, app_config=AppConfig}=State) ->
  {Reply, NewStatus} = case rl_log_operation_api:last_entry(AppConfig, File) of
                         {error, Reason}         ->
                           Status1 = new_status(Status, error),
                           {{error, Reason, Status1}, Status1};
                         {CurrStatus, Entry}     ->
                           Status1 = new_status(Status, CurrStatus),
                           {{ok, Entry, Status1}, Status1}
                       end,
  {reply, Reply, State#er_replicated_log{status=NewStatus}};
handle_call({copy, {BkupFlag, DeleteRaftData, FileVersion}}, _From, #er_replicated_log{file=File, app_config=AppConfig}=State) ->
  RLFileName = er_fsm_config:get_file_replicated_log(AppConfig),
  DataDir = er_fsm_config:get_data_dir(AppConfig),
  NodeName = er_util:get_node_name(),
  FileName2 = er_util:get_version_file_name(NodeName, DataDir, FileVersion, RLFileName#er_file_name.file_suffix),
  {SrcFileName, TrgFileName} = case BkupFlag of
                                 ?CREATE_BKUP  ->
                                   {RLFileName#er_file_name.file_name, FileName2};
                                 ?RESTORE_BKUP ->
                                   {FileName2, RLFileName#er_file_name.file_name}
                               end,
  {ok, NewFile, _} = rl_log_operation_api:copy(AppConfig, BkupFlag, SrcFileName, TrgFileName, File, DeleteRaftData),
  {reply, ok, State#er_replicated_log{file=NewFile}}.
  
handle_cast(_, State) ->
  {noreply, State}.

handle_info(_, State) ->
  {noreply, State}.

terminate(_Reason, #er_replicated_log{file=File, app_config=AppConfig}) ->
  rl_log_operation_api:close(AppConfig, File).

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

new_status(_Status, error) ->
  error;
new_status(?ER_STABLE, _CurrStatus) ->
  ?ER_STABLE;
new_status(_Status, CurrStatus) ->
  CurrStatus.