# Dungeon tick: distinguish save work from entry

Android 523.824 captured a 698 ms frame with 630.240 ms in `dungeon.play` (the update tick, not the entrance handler). Native-stack check, snapshot, account envelope and write occupied 588.760 ms within it. The old timestamp cannot identify whether this was the special-dungeon checkpoint/stop, Orim checkpoint/timeout, a pending retry, or return work. The new detail spans label those paths; the child spans still overlap their parent and must not be added to it.

This change leaves transaction boundaries intact:
- Unchanged native inventory, physical instances, consumables, warehouse, floor, dormant items and source identity can reuse the existing exact proof for a sole `source_dungeon_play` override. An economic override uses the original transition path.
- Special-dungeon accounting avoids cloning the whole ledger on ticks before a durable checkpoint is needed. At the checkpoint it stages only changed dictionaries before the existing validation and write; failures do not publish the mutation.
- A transaction staging a dungeon snapshot does not separately rebuild the discarded live snapshot during save. The final candidate is still detached and written using the existing checks and atomic writer.

The periodic checkpoint interval, entry cost, paid changes, physical ownership, immediate exhaustion, exit, retry and restore rules are unchanged. This does not move the synchronous account or disk stages to a worker. No Android retest is included.
