#!/bin/bash

cd /Users/gyanendraaggarwal/erlang/code/erlang_raft

#erl -sname $1 -pa /Users/gyanendraaggarwal/erlang/code/erlang_raft/raft/ebin -pa /Users/gyanendraaggarwal/erlang/code/erlang_raft/replicated_log/ebin -pa /Users/erlang/code/erlang_raft/state_machine/ebin -config /Users/gyanendraaggarwal/erlang/code/erlang_raft/sys

erl -sname $1 -pa ./raft/ebin -pa ./replicated_log/ebin -pa ./state_machine/ebin -pa ./raft_test/ebin -config ./sys
