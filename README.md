# erlang_raft
Erlang implementation of modified RAFT algorithm : a distributed consensus algorithm
====================================================================================

This a complete implementation of a modified RAFT algorithm in Erlang.
A new state NOT_IN_CONFIG has been added to simplify the implementation
of configuration change. 

Apart from leader election, log replication and configuration change,
it also has log compaction feature which gets invoked automatically
when log size exceeds a pre-defined limit.
If a follower nodes lags a leader node, it can request for leader snapshot 
to become current. This feature has also been implemented.

This implementation can integrate with any state machine as long as 
one can provide an integration module that implements an Erlang behavior.

There is a sys.config file to customize its operation and behavior.

A detailed document is also available to understand its implementation 
and customization.


 