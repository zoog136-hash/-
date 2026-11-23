# 523.837 repeated hitches: source route cell checks

The Android record captured several auto-acquisition searches of 300–392 ms.
It did not attribute all frame delays to navigation or measure the sub-100 ms
distribution. After excluding at least 4-second frames, the two recordings had
99/4109 and 462/2916 hitches at or above 100 ms; actions were not controlled.

Only the 523 static S32 A* query memoizes cell verdicts inside one search. Both
diagonal policies, neighbour/heap ordering, path endpoints, full search limit,
direct-line fast path and original input verification are preserved. The cache
holds at most 32768 verdicts and never survives the synchronous search. It does
not cache routes and does not change saved state, input, unrelated fields, or
movement collision.

Linux Godot, alternating 9 runs per policy, 128x128 preloaded synthetic S32
fixture with a forced detour. Identical points for each pair:

| Policy | prior median | memo median | cell reads prior → memo |
| --- | --- | --- | --- |
| Client bit 0 | 115.5 ms | 85.8 ms | 16597 → 5026 |
| Own allowlist geometry | 141.8 ms | 89.4 ms | 21578 → 5169 |

This improvement is not a per-frame cap. Cold chunk I/O and large A* searches
can still exceed 33 ms, especially on Android. No card-reveal, asset, startup,
save, or phone performance claim.

## 16 ms follow-up: split automatic acquisition

Original supplied static analysis (Lineage M Windows 1.10.22.0, movement edge
test, integrated by commit `24910639`) supports the bit-0 cell and diagonal
edge predicates. It does not show the Android path-search scheduler, or prove
that the original uses this A* implementation or timing budget. We retain the
verified portion of the rule and schedule TWILIGHT's existing search ourselves.

The acquisition path now spends a cooperative 4 ms slice, at most one slice
per process frame, with a 512 heap-pop backstop. Direct routes stay immediate.
The same frontier resumes for a pending candidate, which is not counted as
unreachable. Player/target cell, target life, field, field reconfiguration,
policy limit and combat generation changes invalidate the applicable work.
The synchronous API, including manual routing, uses the same A* and is not
frame-sliced. Source verification, disk reads, direct-line tests and final
path projection may consume uninterruptible foreground time.

The preloaded synthetic 128x128 forced detour returned identical paths and
bounded the largest step to 4.20/4.38 ms across the two rule fixtures. A
production acquisition callback with synthetic actors/terrain finished after
27 continuation frames and measured a 5.42 ms largest continuation. The 44
checks also cover unreachable paths, caps, moved targets, replaced fields,
and no double pumping within a frame. Spreading work intentionally increases
time until a difficult route is ready on this fixture. It does not prove
16 ms total frames on a phone, real pack behavior, or relief for card draws
and auto-loot.
