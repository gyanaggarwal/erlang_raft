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

-module(rl_entry_operation).

-include("er_fsm.hrl").

-callback header_byte_size(AppConfig :: #er_app_config{}) -> non_neg_integer().

-callback trailer_byte_size(AppConfig :: #er_app_config{}) -> non_neg_integer().

-callback file_header_byte_size(AppConfig :: #er_app_config{}) -> non_neg_integer().

-callback magic_byte_size(AppConfig :: #er_app_config{}) -> non_neg_integer().

-callback latest_version(AppConfig :: #er_app_config{}) -> non_neg_integer().

-callback entry_to_binary(AppConfig :: #er_app_config{}, Entry :: #er_log_entry{}) -> binary().

-callback binary_to_entry(AppConfig :: #er_app_config{}, Bin1 :: binary(), Bin2 :: binary()) -> {ok, #er_log_entry{}} | ?ER_BAD_ENTRY.

-callback entry_header(AppConfig :: #er_app_config{}, Bin :: binary()) -> {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()} | ?ER_BAD_ENTRY.
