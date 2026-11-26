# Reuse verified 523 S32 sections between movement and rendering

TWILIGHT keeps separate collision and render caches. For generic 523 fields a
cache miss could reopen, verify, and decode the same immutable source twice.
The reference for the approach is the already documented original-client
cache-hit-before-decode behavior, not a claim about the original's collision
implementation or A* scheduling.

- A completed renderer worker offers just the verified floor and attribute
  bytes to the current field, on the main thread. Field instance, exact
  manifest root/pin, asset, member name and digest must match. Failed reads
  never publish. The eight-entry mailbox (384 KiB of payload) does not evict
  live collision data; a collision query moves a result into the existing LRU.
- If navigation already verified the entire chunk first, a worker can project
  that full read-only payload instead of reopening it. A collision-only
  result cannot seed the renderer. Neither consumer waits for unfinished
  work. Simultaneous cold misses can still issue separate reads, preserving
  existing input and rendering behavior. Ordinary readers remain the fallback.
- For uncompressed storage, compare the one computed digest against both
  expected hashes rather than hash identical bytes twice. Gzip, every
  section hash, exact sizes, source pinning and failure guards are kept.

The regression uses authored byte fixtures and production readers/worker/
renderer publication. It checks both consumer orders, exact projected values,
wrong/stale identity, corrupted digest, cache bound, and clearing on close.
The existing route digest and map-worker regressions also run. No private pack,
phone timing or whole-frame 16 ms result is claimed. On phone, compare the two
new share counters against auto.search_route and manual movement in the same map.
