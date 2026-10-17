# Codex event waits

This adapts upstream SDD's waiting cadence. Its dispatch, review, fix-loop,
completion and receipt requirements remain authoritative.

1. While independent local work remains, do it. Child results arrive as
   events; another status request is unnecessary.
2. When idle, use an interruptible `wait_agent` subscription. Choose the
   longest interval within 300000 ms, the tool limit, any higher-priority
   blocking-call limit, and the next required communication deadline.
   A 60-second platform ceiling therefore uses at most 60000 ms; a platform
   permitting five minutes uses 300000 ms. New input wakes the subscription.
3. On an unchanged timeout, post a brief update only when communication is
   due, then continue the same bounded event wait. A timeout is not a worker
   failure. It does not trigger log reads, skill rereads, worker check-ins,
   or a fresh `list_agents` call.
4. Reconcile silent children once five minutes have elapsed since the last
   dispatch or reconciliation. Use one `list_agents` snapshot and retrieve
   a missing report from a child that actually finished. Measure elapsed
   time, not the number of capped waits. A real tool failure or attention
   event triggers reconciliation immediately. If children remain running,
   resume the bounded wait; do not redispatch unchanged work.
5. Process a new user message or completion before waiting again. A worker's
   DONE message starts the existing task-review gate; only accepted ledger
   completion can check a task off or authorize the next task. Final review,
   terminal validation and the persisted Maxi `done` still precede finishing.
