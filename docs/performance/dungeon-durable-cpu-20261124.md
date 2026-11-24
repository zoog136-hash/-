# Synchronous dungeon checkpoint and stop: avoid throwaway save copies

Android 523.843 (`7394ec45`) identified a regular special-dungeon checkpoint at
427 ms and another at 495 ms, as well as a 352 ms stop. In these records the account
phase was 93–127 ms and the write phase was 127–205 ms. These are measured scopes
of the captured frames, not proofs of a single cause for the whole hitch.

This keeps the existing save owner and commit-before-publish order. The special
dungeon's 10-second checkpoint, stop and exhaustion, and paid inventory/reward
transactions have the same timing and authority. No asynchronous checkpoint is
introduced. The earlier private-temp prototype lacked a production mutation
epoch and native-map post-durable callback, so the game still does not use it.

1. Account staging copies only the old record metadata, dormant characters and
   retained envelope fields. The old selected character and old shared roots are
   read through their immutable prior envelope until validation and monotonic
   physical-ID allocation complete, but are not deep-copied merely to be
   replaced by freshly detached roots. The serialized shape is unchanged.
2. A save with exactly one staged `source_dungeon_play` root increments a ledger
   revision. Avoid building and retaining a second full *typed* payload solely
   for the repeated-identical-save fast path. Still require the same verified
   on-disk bytes as before, and skip actual I/O if the canonical bytes are
   genuinely identical. Economic overrides keep the default typed cache.
3. The synchronous account cache remembers the payload digest already verified
   by the writer, rather than hashing the file again and risking association of
   the approved envelope with an intervening outside replacement. The next
   staging attempt still checks that the original digest matches the file.

Headless checks (isolated Godot `user://`, no player saves):
`tests/dungeon_durable_cpu_test.gd` benchmarks the actual account/writer
functions with a synthetic v2 account and verifies detached output, historical
physical-ID reservation, external replacement refusal, and byte-identical
results. `tests/dungeon_durable_cpu_main_test.gd` exercises actual Main's
checkpoint and stop with a synthetic dungeon projection, including an injected
write failure. Original-map/device performance is not covered.

On one Linux headless comparison (427,473 bytes; 3,099 selected/dormant item
rows; 12 timed repetitions after warm-up), the measured account + atomic
write/cache phases fell from a 185.8 ms to 146.6 ms median. The high sample
(p95 = maximum for 12 samples) was 198.9 ms vs. 232.3 ms; tail improvement
is not established. Canonical output SHA-256 was identical. The benchmark
excludes the rest of the live save path and is not a device estimate.
