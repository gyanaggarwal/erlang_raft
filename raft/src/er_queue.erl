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
%
%     rear                                   front
%     --------------------------------------------
%     |                                          |
%     --------------------------------------------
%     insert                        insert_reverse
%     take_lifo                          take_fifo
%     peek_lifo                          peek_fifo
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(er_queue).

-export([new/0,
         is_queue/1,
         is_empty/1,
         len/1,
         insert/2, 
         insert_reverse/2,
         take_lifo/1,
         take_fifo/1,
         peek_lifo/1,
         peek_fifo/1,
         to_list/1,
         split/2]).

-spec new() -> queue:queue().
new() ->
  queue:new().

-spec is_queue(Q0 :: queue:queue()) -> boolean().
is_queue(Q0) ->
  queue:is_queue(Q0).

-spec is_empty(Q0 :: queue:queue()) -> boolean().
is_empty(Q0) ->
  queue:is_empty(Q0).

-spec len(Q0 :: queue:queue()) -> non_neg_integer().
len(Q0) ->
  case is_queue(Q0) of
    true  ->
      queue:len(Q0);
    false ->
      0
  end.

-spec insert(Item :: term(), Q0 :: queue:queue()) -> queue:queue().
insert(Item, Q0) ->
  queue:in(Item, Q0).

-spec insert_reverse(Item :: term(), Q0 :: queue:queue()) -> queue:queue().
insert_reverse(Item, Q0) ->
  queue:in_r(Item, Q0).

-spec take_lifo(Q0 :: queue:queue()) -> {{value, term()} | empty, queue:queue()}.
take_lifo(Q0) ->
  queue:out_r(Q0).

-spec take_fifo(Q0 :: queue:queue()) ->	{{value, term()} | empty, queue:queue()}.
take_fifo(Q0) ->
  queue:out(Q0).

-spec peek_lifo(Q0 :: queue:queue()) ->	{value, term()} | empty.
peek_lifo(Q0) ->
  queue:peek_r(Q0).

-spec peek_fifo(Q0 :: queue:queue()) ->	{value, term()} | empty.
peek_fifo(Q0) ->
  queue:peek(Q0).

-spec split(N :: non_neg_integer(), Q0 :: queue:queue()) -> {queue:queue(), queue:queue()}.
split(N, Q0) ->
  queue:split(N, Q0).

-spec to_list(Q0 :: queue:queue()) -> list().
to_list(Q0) ->
  queue:to_list(Q0).