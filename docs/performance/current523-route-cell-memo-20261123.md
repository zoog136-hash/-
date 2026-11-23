# 523.837 source-movement route work, without frame slicing

## Source and scope

LineageM Windows 1.10.22.0 movement-edge analysis (reported at RVA
`0x01CC95C0` in `24910639f33ea1db2e01f8d306c6cbe8b201034e`) established
the attribute bit-0 rejection and the diagonal rule: at least one orthogonal
side must be open. This is prior evidence for the edge predicate only, not
evidence for a full route planner, Android scheduling, or a client time budget.
TWILIGHT's paired S32 attributes, missing-floor guard and own allowlist mode
remain intact. No third-party binaries, data, or images are included.

The Android 523.837 log contains repeated `auto.search_route` samples around
300–392 ms. It does not measure the sub-100 ms frame distribution or attribute
all stutter to routes. Base: `bd9dc3b8`. Alternative to draft #862, not a
follow-on to it: auto target order, route call count and same-call completion
remain unchanged. No frame continuation, new timers, startup or save changes.

## Implementation

- Check both client halfwords together using bit 0, and retain both floor checks.
  Diagnostic status strings and explicit own allowlist behavior are unchanged.
- Cache static 523 cell verdicts only for the synchronous A* query, with a cap
  of 32,768. Never cache a route or carry terrain results between queries.
- Store the A* heap keys once per entry and keep parent/cost in one record.
  Tie ordering, waypoint reconstruction, node caps, direct ray, and dynamic
  collision remain unchanged. The heap improvement is shared.

## Verification

The Linux Godot 4.7.2 preloaded 128×128 synthetic fixture checks exact path
sequences against main via a digest over 50 scenarios, including short routes,
forced detours and search caps. The client truth table independently checks both
raw halfwords and both floor sentinels. No original map pack was used.

In one representative before/after pair (median of nine queries each), the
127-point forced detour took 115.4 → 48.8 ms and called the source-cell evaluator
16,597 → 5,026 times. A repeat while local CI was running varied in absolute
times and retained the same 70% drop in calls and identical path. These figures
do not establish a 16 ms whole-frame budget: cold reads and difficult A* can
still miss it. Accept only after a matched Android comparison of frames over
16 ms, path acquisition-to-first-attack latency and movement response. Card draw
and loot are outside this route patch.
