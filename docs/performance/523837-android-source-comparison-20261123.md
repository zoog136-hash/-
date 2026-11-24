# 523.837 Android: repeated hitch and original-rule comparison

| Report build | Frames below 4 seconds | 100 ms to below 4 seconds | Rate |
| --- | ---: | ---: | ---: |
| 523.835 (39bbb382) | 4109 | 99 | 2.41% |
| 523.837 (bd9dc3b8) | 2916 | 462 | 15.84% |

The reports contain total frame counts and >=100 ms counters. Subtract two
and three >=4 s frames respectively from both. The worst-12 cutoff in both
reports is below 4 s, so none of those frames are omitted. These are different
play sessions, not a controlled A/B; they show the reported hitch burden but
not the cause of its change. The available 523.837 report has 2919 frames in
total, no 16–99 ms distribution or card-draw marker. 268 ms is the mean of
the final sample, not the session mean.

| Action | Original evidence | TWILIGHT / 523.837 |
| --- | --- | --- |
| Movement and auto hunt | Windows 1.10.22.0 movement-edge evidence: bit 0 and one open side for a diagonal. 523 ListSprAction player Walk rate 36 and delay 16 concern walk timing, not FPS. Android static archive does not establish original A* or frame scheduling. | Five auto.search_route calls: 300, 349, 369, 374, 392 ms. #863 reduces repeated reads with the same-call return and waypoints intact. No separate manual-movement latency was measured. |
| Auto pickup | Original item/bless identities and ItemClass.MaxStackAmount; no evidence of the original client using TWILIGHT's local durable receipt/save algorithm. | One 834 ms auto.pickup had a nested 833 ms loot.pickup including a 278 ms save.check_native_stack. Do not add inclusive durations. Only remove duplicate proof, not stack limits, ownership or persistence guards. |
| In-bag original draw tickets | LinMarketProduct → original product grants → GotChaClassID and weighted entities; BuffCard deck, grade and eligibility. | We validate around a transaction that can finish a pending map save. Retain both validations, materialize drawable copies only once, and read each original card row only once per pass. Ticket debit, RNG and save-before-reveal still apply. No observed card latency claim. |
| Inventory panel | Source layout/identity does not verify timing. | Two ui.inventory_open.native spans of 2145 and 513 ms included stage spans of 2006 and 467 ms. Neither measures card draw. Not changed here. |
| Remaining frame time | Not recoverable from the available original APK analysis. | In eight of nine retained frames under 4 seconds, unclassified time exceeded any named section. Do not call that GPU time or attribute the whole slowdown to routes. |

The new JSON records fixed whole-frame counts over 16, 16.667 and 33 ms
and at or above 4 seconds; old reports do not have these fields. The existing
100-ms counter and worst records are unchanged. In-bag source tickets report
preflight, drawable pool, commit, and reveal-setup method times (not
touch-to-first-pixel). Candidate ownership is fully validated before
transition checks. Only reference-identical shared entries skip the redundant
old-object proof; changed, removed, or separately copied entries keep it.

Android acceptance: same device, pack, baseline save and play actions.
Compare the over-budget counts and time to next attack/first visible card,
not just the longest stall. Exercise manual movement, re-acquisition after a
kill, floor pickup, and cards. Verify ownership and save/reload. No device
performance result yet.

Evidence: docs/MOVE_SPEED_MAP_TRAVEL523.md, docs/ITEM_STACKING523.md,
docs/audit927/source/, tools/lineagem_original/README.md, and movement-edge
analysis cited by 24910639f33ea1db2e01f8d306c6cbe8b201034e. Do not publish
the original binaries, private source packs or raw phone reports.

Second dedup pass: perform one 523 endpoint projection and validation per
route, then pass the validated grid endpoints to the existing DDA. Keep
the regular line check available to other callers. Native ownership checks
select the original archive once on first use, read cached projections
without copying them within the one validator, and reuse proof for floor
entries already checked in the same call. External proof callers still get
their own top-level copy. Card-save export deep-copies the receipt array
once rather than twice; it has the same fields, including an empty array.
