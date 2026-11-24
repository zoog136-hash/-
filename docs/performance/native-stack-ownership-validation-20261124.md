# Native floor ownership work during a gameplay save

The 523.843 Android capture reported `save.check_native_stack` at 65–98 ms
on retained saves, including 78 ms at frame 5154 (pickup 97 ms), 88 ms at
8318 and 98 ms at 6982. Those are full validation sections, not a measurement
of the two substeps changed here. The trace also shows other save stages and
large unexplained post-draw gaps; this does not address those gaps.

* Use synchronous, read-only views of the live native validation inputs
  (consumables, warehouse and floor) in the pre-write check. Keep floor expiry
  in the same place; still make detached proof-cache, transaction and durable
  save snapshots. No worker, save writer, serialized layout, live commit, or
  owner authorization changes.
* Resolve staged floor rows once per check, not once for every previously
  owned floor stack. Candidate validation, native/legacy ownership separation,
  first-match source order, expiry and the pickup/disposal authorization
  still apply. Cost of the lookup phase goes from O(F × P) worst case to
  O(F + P), F floor rows, P live receipted rows. No long-lived floor index.

Run the focused production-validator fixture from an isolated Godot profile:

```sh
godot --headless --path . --script res://tests/native_stack_save_validation_budget_test.gd -- --benchmark
godot --headless --path . --script res://tests/native_stack_save_validation_budget_test.gd -- --main
```

The benchmark runs the real native ownership validation on synthetic rows
with injected decoded proof results; it does not issue real original items
or benchmark an Android frame or the entire save. The standalone regression
checks exact staged pickup authorization, typed IDs, duplicate/tampered
receipts, first matching legacy row, expiry and detached durable snapshots.
`--main` uses the actual Main startup and save writer, verifies writer
failure preserves bytes and the live bag, and checks unchanged staged save
bytes. It requires a fresh user directory (set XDG_DATA_HOME).

Same Godot 4.7.2 Linux headless checkout pair, A/B/B/A/B/A, nine validations
per case per process; median of three process medians. The fixture shapes
are illustrative, **not a count of the phone's rows**.

| Fixture | Live candidate | Staged floor candidate |
| --- | ---: | ---: |
| 32 receipted + 128 other floor rows | 3.69 → 1.24 ms | 2.96 → 1.61 ms |
| Stress: 450 receipted + 900 other floor rows | 266.24 → 10.42 ms | 257.55 → 19.35 ms |

Concurrent cloud load made sub-millisecond and short runs noisy; the raw
stress run medians still ranged from 257.41–267.52 to 7.64–38.97 ms (live)
and 249.75–268.06 to 11.28–33.40 ms (staged). No new art or redistributable
assets are committed; no matched phone retest or user pack was performed.
