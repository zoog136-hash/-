# Nonblocking map renderer retirement

The current523 renderer used to join every S32-read and draw-list task from
`_exit_tree()`. Dungeon entry may remove the prior renderer and return may
remove the destination renderer, so an otherwise asynchronous task could
block the game thread at detach.

Detach now drops publication ownership immediately. The existing always-on
map pump retires only completed task handles, up to four per frame and a
cooperative 1 ms reclamation budget. A high-water mark of 32 retired handles
defers new renderer work until retired work drains. This is admission
backpressure, not a hard cap on the already-admitted jobs of live renderers.
Running work is not interrupted. A retired job may finish but cannot publish
into any map. Input refs survive until reaped; a reconfiguration replaces the
overlap table instead of mutating the previous workers' table. Normal
in-renderer refresh/configuration behavior and shutdown joins remain intact.

Scope: S32 and draw lists, not atlas decode/compression retirement, GPU upload,
destination readiness, loading policy, movement, original resources, saves,
or startup. The usual gameplay controller retains/reuses its verified tile
pack. This change is not a fix for all transition or combat stalls.

The attached 523.824 recovered checkpoint contained zero recorded frames and
no samples: it cannot verify a hitch or Android improvement. The regression
uses real engine worker callbacks with synthetic input, holds both for 300 ms,
frees the old renderer, and checks callbacks finish and the new map receives
no stale output. This is a desktop detach measurement, not entry time or a
device benchmark. Recheck entrance/return with the same map and pack on
Android, comparing maximum frame gap and request-to-control time.
