Manual testing
==============

I am assuming that you have cloned the source code along with sys.config file
to your local directory and also compiled all the .erl files into .beam files.
All .beam files need to be corresponding ebin directory.

When you clone the project, it creates a directory erlang_raft and under this
directory all other directories (raft, replicated_log, state_machine) are being
created.

erlang_raft is the root directory, if you wish you can create data directory under
this root directory and modify the data_dir paramenter in sys.config file. If you
do not create data directory, all the raft data (*.repl.log, *meta.dat) files
will be created under root directory.

Delete any raft data that was created during the previous run, you need not do this
in actual run but it is convenient to do so for test runs.

Start 6 terminal Shells and cd all the Shells to erlang_raft root directory.

On first Shell type the following command to create Erlang node:

Note : for windows use werl.

erl -sname er_n1 -pa ./raft/ebin -pa ./replicated_log/ebin -pa ./state_machine/ebin -config ./sys

Once you are in the Erlang shell, type the following command to create a set of local erlang raft servers

Note : a number followed by > denotes Erlang Shell prompt.

1> erlang_raft:start().

You will see that this command will start 7 new processes as given below:

1.  er_sup
2.  er_raft_server
3.  er_peer_server
4.  er_event
5.  rl_server
6.  sm_sup
7.  sm_server

Processes 1 to 5 are part of erlang_raft implementation, the last 2 have been created only for demo 
and testing purpose. In your actual run, you will replace them with your actual state machine.

Repeat this step for next 4 Shells with node name as er_n2, er_n3, er_n4 and er_n5.
At this stage, we do have 5 erlang_raft servers running as stand alone and
so far they have not been clustered. so you will not see any activity on these Erlang shell.
All these nodes are running with status as NOT_IN_CONFIG. When a erlang_raft server is in
NOT_IN_CONFIG status, it does not belong to a erlang_raft cluster and it also does not
timeout. It is just waiting to join the erlang_raft cluster.

Now, let us start the last Erlang shell, this shell acts like a erlang_raft client and
we perform different activities from this 6th Erlang shell.

So type the following command on the 6th shell:

erl -sname er_nz -pa ./raft/ebin

Once you have the Erlang shell (6th) running, create the following Node variable, these node names are based
on my computer and will be different for your computer. So make the right correction when you create them.

1> Ern1 = 'er_n1@Gyanendras-MacBook-Pro'.
2> Ern2	= 'er_n2@Gyanendras-MacBook-Pro'.
3> Ern3	= 'er_n3@Gyanendras-MacBook-Pro'.
4> Ern4	= 'er_n4@Gyanendras-MacBook-Pro'.
5> Ern5 = 'er_n5@Gyanendras-MacBook-Pro'. 

To create an erlang_raft cluster of 3 nodes, type the command on Erlang Shell:

6> erlang_raft:config_entry(Ern1, [Ern1, Ern2, Ern3]).

Here, the first parameter Ern1 is the node where sending our command, this could have been
any node (Ern1, Ern2 or Ern3) that is going to be part of erlang_raft cluster. Second parameter is
a list of nodes that will form the cluster.

Once, you issue this command, you will see some activity on these 3 nodes, they will become FOLLOWER and
timeout for leader election and eventually one of the nodes will become LEADER.

Here, I am assuming the Ern1 has become LEADER for further discussion.

Now let us issue a command to enter our first log entry, type the following command:

7> erlang_raft:log_entry(Ern1, make_ref(), "cmd01").

Here, the first parameter is any active node in the cluster, it need not be LEADER.
Second parameter is unique id for state machine command to check for duplicate entry, 
you can use any suitable id. Third parameter is the actual command (any erlang term)
that you want to issue for your state machine.

Once you issue this, you will more activity in all the 3 nodes.

Issue this command 3 more times, just change the value of last parameter, as given below:

8> erlang_raft:log_entry(Ern1, make_ref(), "cmd02").
9> erlang_raft:log_entry(Ern1, make_ref(), "cmd03").
10> erlang_raft:log_entry(Ern1, make_ref(), "cmd04").

At this time, you will see the following for LEADER node:

[er_raft_server] "log_entry.99" status=er_leader, leader_id='er_n1@Gyanendras-MacBook-Pro', log_entry_count=4, 
current_term=1, prev_log_term=1, prev_log_index=4, commit_term=1, commit_index=4, applied_term=1, applied_index=4

Both FOLLOWER nodes will have the following display:

[er_raft_server] "peer_append_entries_op.99" status=er_follower, leader_id='er_n1@Gyanendras-MacBook-Pro', log_entry_count=4, 
current_term=1, prev_log_term=1, prev_log_index=4, commit_term=1, commit_index=3, applied_term=1, applied_index=3

Here LEADER node will always 1 entry ahead of FOLLOWER node because it can commit the latest entry 
if it receive the acceptance for majority of servers (including itself).

Now, bring down one of the FOLLOWER node (say Ern3), go to Erlang shell of Ern3 and type the following command:

2> erlang_raft:stop().

Now, we have only 2 active erlang_raft nodes. This is ok because we can still fulfill the quorum requirement.

Issue 4 more log entries from erlang_raft client shell (6th node) and you will that these 4 entries 
are also accepted. Please check the display on LEADER and FOLLOWER node to ensure that they are
still in sync.

Now, bring back Ern3, go to Ern3 erlang shell the type the following command:

3> erlang_raft:start().

This will start the erlang_raft Node 3, we also know that this node is not current.

Now let us make 2 more log entries from erlang_raft client shell.

You will notice that, at this stage LEADER (Ern1) and FOLLOWER (Ern2) are current with 10 log entries 
but FOLLOWER node (Ern3) may or may not be current depending upon the setting of optimistic_mode
in sys.config file.
If this has been set to true then Ern3 will not become current because LEADER can still fulfill
the quorum requirement just with node Ern2. This is the default setting right now. This leads to
faster normal operation.

If you have set this value to false then Ern3 will become current immediatley after the first log entry.

Let us assume we are testing it with optimistic_mode set to true.

Now, stop the FOLLOWER node Ern2 that is current and make 2 more log entries.
You will notice that FOLLOWER node Ern3 that was not current becomes current immediately after the first entry
because LEADER needs Ern3 to be current to fulfill the quorum requirement.

At this moment we should have 12 entries for both LEADER and FOLLOWER. If you wish, you can check
the file size of replicated log files (er_n1_repl-log, er_n3_repl.log) for Ern1 and Ern3. 
They should be same.

Now let us change our cluster configuration, we are still assuming the Ern1 is still a LEADER
and Ern3 is the only FOLLOWER.

On Erlang client shell, type the following command

> erlang_raft:config_entry(Ern1, [Ern3, Ern4, Ern5]).

We are taking out Ern1 (who is our current LEADER) and adding Ern4, Ern5 which are not current
servers to the cluster.

You will notice that Ern1 (LEADER) make Ern4 and Ern5 current immediately before it goes out of 
cluster and its status becomes NOT_IN_CONFIG.

At this stage, the cluster does not have a LEADER so it goes through a leader election process
and they elect a new LEADER.

Once a new LEADER has been elected make 4 more entries, you can not use Ern1 as a parameter
in your log_entry command because it is not an active node now. So, make a suitable change
and make these 4 entries.

Once you make these 4 entries, you will notice something strange. Every thing looks ok but 
you log_entry_count has reduced. If you check the file size of you replicated files, they have 
also reduced. It is because, it compacts the log files after it reaches a perticular limit as
specified in sys.config (log_retention_size_max). We have set to 15 for demo/testing purpose
but normally this value will be much higher.

Well this should be a happy ending of testing. If you see any discrepancy, please report back.


  



 

  



