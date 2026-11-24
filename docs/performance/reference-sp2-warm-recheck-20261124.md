# Reduce repeated warm SP2 actor proof work
Baseline: Android report for 523.843, November 24. Its retained detail
`preview.cached` includes plan verification, building and draw application
(and overlaps player/companion timers). It reached 32 ms over four calls in one
retained frame. The report has no exclusive pin/member cost; it does not show
that these checks take 32 ms, nor explain the post-draw scheduling gaps.

On the non-cooked plan lane, each warm advance used to serialize the bank's
whole action JSON pin set and format every verified member's composite string
key. Now each bank remembers the pin identity until it opens/replaces the bank
or adds/replaces a role pin. A member hit requires the same path, matching
declared content identity and size, and exactly the current verified stamp
record. Each plan precomputes canonical actor names but checks the live dummy
exclusion registry on every advance. Rejected actors still get the original
detailed rejection. Unseen, replaced or missing stamps take the original
verification/rehash path. Expiry and manual invalidation clear both memos;
the existing maximum file-check interval is unchanged. No clock, input, draw
scheduling, save, resource data, decoder or runtime file format changes.

## Matched local measurement
Godot 4.7.2 Linux headless, synthetic SP2 members. Same source view, four
original directions reused in 30 Hz steps, four drawn layer records, five
actually pinned action files; no new plan/texture work inside the timed loop.
Run `godot --headless --path . --script res://tests/reference_sp2_hot_recheck_test.gd -- --bench`.
Before/after swapped only the bank script, six fresh processes in
A/B/B/A/A/B order. Five rounds per process, 14,000 warm checks and 8,000
advances per round.

| Scope | Before, median | After, median |
|---|---:|---:|
| Warm proof checks | 22.96 µs | 6.96 µs |
| Full warm preview advance, including frame selection and application | 62.44 µs | 44.74 µs |

The isolated check used about 70% less time, and the synthetic warm preview advance
about 28% less. These are subpath timings, not device FPS or whole-frame
times; this change does not affect cooked characters or establish 16 ms on
Android. Normal CI runs functional checks (including changed action file and
prepared bank reload, deleted member, independent actor exclusion), not timing
thresholds. The pre-existing composite/animation and bank checks remain.
