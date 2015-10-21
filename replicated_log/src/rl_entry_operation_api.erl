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

-module(rl_entry_operation_api).

-behavior(rl_entry_operation).

-export([header_byte_size/1,
         trailer_byte_size/1,
         file_header_byte_size/1,
         magic_byte_size/1,
         latest_version/1,
         entry_to_binary/2,
         binary_to_entry/3,
         entry_header/2]).

-include("er_fsm.hrl").

-define(SHA_BYTE_SIZE,         20).
-define(CRC_BIT_SIZE,          32).
-define(DATA_BIT_SIZE,         32).
-define(TYPE_BIT_SIZE,         8).
-define(TERM_BIT_SIZE,         64).
-define(INDEX_BIT_SIZE,        64).
-define(FILE_HEADER_BYTE_SIZE, 1).

-spec header_byte_size(AppConfig :: #er_app_config{}) -> non_neg_integer().
header_byte_size(_AppConfig) ->
  ?SHA_BYTE_SIZE+compute_bytes(?TYPE_BIT_SIZE+?TERM_BIT_SIZE+?INDEX_BIT_SIZE+?DATA_BIT_SIZE).

-spec trailer_byte_size(AppConfig :: #er_app_config{}) -> non_neg_integer().
trailer_byte_size(AppConfig) ->
  compute_bytes(?CRC_BIT_SIZE)+magic_byte_size(AppConfig).

-spec file_header_byte_size(AppConfig :: #er_app_config{}) -> non_neg_integer().
file_header_byte_size(_AppConfig) ->
  ?FILE_HEADER_BYTE_SIZE.

-spec magic_byte_size(AppConfig :: #er_app_config{}) -> non_neg_integer().
magic_byte_size(AppConfig) ->
  byte_size(er_fsm_config:get_log_entry_trailer_magic(AppConfig)).

-spec latest_version(AppConfig :: #er_app_config{}) -> non_neg_integer().
latest_version(AppConfig) ->
  er_fsm_config:get_log_file_header_version(AppConfig).

-spec entry_to_binary(AppConfig :: #er_app_config{}, Entry :: #er_log_entry{}) -> binary().
entry_to_binary(AppConfig, #er_log_entry{term=Term, index=Index, entry=#er_cmd_entry{type=Type, id=Id, cmd=Cmd}}) ->
  Bin = term_to_binary({Id, Cmd}),
  BinSize = byte_size(Bin),
  Magic = er_fsm_config:get_log_entry_trailer_magic(AppConfig),
  MagicSize = byte_size(Magic),

  {Sha, Crc} = compute_hash_crc(Type, Term, Index, BinSize, Bin, Magic),

  <<Sha:?SHA_BYTE_SIZE/binary, 
    Type:?TYPE_BIT_SIZE, 
    Term:?TERM_BIT_SIZE, 
    Index:?INDEX_BIT_SIZE, 
    BinSize:?DATA_BIT_SIZE, 
    Bin:BinSize/binary, 
    Crc:?CRC_BIT_SIZE, 
    Magic:MagicSize/binary>>.

-spec binary_to_entry(AppConfig :: #er_app_config{}, Bin1 :: binary(), Bin2 :: binary()) -> {ok, #er_log_entry{}} | ?ER_BAD_ENTRY.
binary_to_entry(_AppConfig, 
                <<Sha:?SHA_BYTE_SIZE/binary, 
                  Type:?TYPE_BIT_SIZE, 
                  Term:?TERM_BIT_SIZE,
                  Index:?INDEX_BIT_SIZE,
                  BinSize:?DATA_BIT_SIZE>>,
                Bin2) ->
  <<Bin:BinSize/binary, Crc:?CRC_BIT_SIZE, Magic/binary>> = Bin2,

  case compute_hash_crc(Type, Term, Index, BinSize, Bin, Magic) of 
    {Sha, Crc} -> 
      {Id, Cmd} = binary_to_term(Bin),             
                  {ok, #er_log_entry{term=Term, index=Index, entry=#er_cmd_entry{type=Type, id=Id, cmd=Cmd}}};
    _Other     -> 
      ?ER_BAD_ENTRY
  end;
binary_to_entry(_AppConfig, _Bin1, _Bin2) ->
  ?ER_BAD_ENTRY.

-spec entry_header(AppConfig :: #er_app_config{}, Bin :: binary()) -> {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()} | ?ER_BAD_ENTRY.
entry_header(_AppConfig,
             <<_Sha:?SHA_BYTE_SIZE/binary,
               Type:?TYPE_BIT_SIZE,
               Term:?TERM_BIT_SIZE,
               Index:?INDEX_BIT_SIZE,
               BinSize:?DATA_BIT_SIZE>>) ->
  {Type, Term, Index, BinSize};
entry_header(_, _) ->
  ?ER_BAD_ENTRY.
    
-spec compute_bytes(BitSize :: non_neg_integer()) -> non_neg_integer().
compute_bytes(BitSize) ->
  BitSize div 8.

-spec compute_hash_crc(Type :: non_neg_integer(), Term :: non_neg_integer(), Index :: non_neg_integer(), BinSize :: non_neg_integer(), Bin :: binary(), Magic :: binary()) -> {binary(), integer()}.
compute_hash_crc(Type, Term, Index, BinSize, Bin, Magic) ->
  B1 = <<Type:?TYPE_BIT_SIZE, Term:?TERM_BIT_SIZE, Index:?INDEX_BIT_SIZE, BinSize:?DATA_BIT_SIZE, Bin:BinSize/binary>>,
  Sha = crypto:hash(sha, B1),
  Crc = erlang:crc32(Magic),
  {Sha, Crc}.  
