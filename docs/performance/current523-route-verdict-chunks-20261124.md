# Current523 navigation: reuse verified cell verdicts, not routes

The 523.837 Android record contains five new-target searches of 300–392 ms.
PR #868 only handles repeat pursuit, not these first searches. The Windows
1.10.22.0 movement-edge evidence behind #863 establishes the bit-0 test and
one open orthogonal side on a diagonal, not the original Android pathfinder,
timing or rendering loop.

This change is opt-in for the admitted generic Current523 field using the
client bit-0 rule. A* visits the same nodes in the same order; it retains the
same heap, ties, search cap, direct ray and waypoint sequence. Short direct
and rejected paths do not build a cache. An obstructed search lazily memoizes
the exact verdict for each inspected position in the already validated S32
chunk; both attribute words and both floor sentinels still matter. It never
schedules extra reads, scans a complete chunk, stores a route, changes an
attack decision or uses incomplete renderer data. Explicit own/allowlist
paths, foot movement, and live checks stay on the previous code.

A chunk's verdicts retire with its raw bytes or when its field closes.
Maximum additional packed bytes: 48 * 4096 = 192 KiB per field, plus a small
object per populated array. Source bytes are shared read-only by copy-on-write.
The navigator's local pointer has synchronous-query lifetime only.

The headless fixture alternates previous and modified paths and checks exact
waypoints against the existing 50-case digest, both movement policies,
seams, strict caps, both attribute halves/floor sentinels, negative origins,
repeat reuse and raw-LRU eviction. Linux Godot 4.7.2 representative medians
(nine queries each): 46.35 ms previous, 38.46 ms with no preexisting verdict
bytes, 35.34 ms when reusing verdict bytes for a 127-point detour. The input
S32-shaped fixture bytes were already in memory in all cases. This does not
measure first disk read, actual Android time or a 16 ms full frame.
