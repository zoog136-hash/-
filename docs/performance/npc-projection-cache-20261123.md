# Repeated NPC combat input projection

This is separate from #847 (definition relation-index cold work) and #851
(default-off first sprite-page pilot). No original resource was altered or
included. A 523.824 Android report measured 222 ms in `setup.projection`,
inside a 392 ms spawn within a 7.974-second frame. The measured boundary may
include cold source opening/admission, so this work does not explain or fix
that entire frame and does not claim to save 222 ms on Android.

After the unchanged NpcClass checks and current admission, repeated lives may
reuse **only** the verified named special-resistance and uniform attack-range
evidence. Uniform range's slow path loops through the whole selected attack
registry to reject malformed entries and then checks exact owner rows. The
first or unavailable proof still uses that path. The cache does not grant
admission, synthesize missing rows, select duplicate IDs, nor change range
and combat policy. Invalid or not-yet-readable proofs are not memoized. It
stores at most 128 NPCs, clears on registry publication and checks source
identity/read generation, catalog schema, both policy digests, and exact
NPC/admission records. Each actor gets detached evidence and its own
prior values, role, placement and spawn level. This keeps the prior-field
distinction between missing and present-null.

## Local validation and timing

Godot 4.7.2 Linux headless; separate isolated profile. Production projection
with a synthetic, already admitted registry and validated-reader test fixture,
not a measurement of reading an original ZIP or first admission. Eight
alternating cache-off/on/on/off arms; each has one empty-cache call and 30
same-NPC calls; medians are across each mode. Times are illustrative only:

| Selected attack rows | First projection, cache empty (off → on) | Repeated projection (off → on) |
| ---: | ---: | ---: |
| 256 | 0.669 → 0.883 ms | 0.604 → 0.109 ms |
| 12,000 (stress) | 22.584 → 21.083 ms | 22.404 → 0.110 ms |

Both fixture sizes passed 45 checks, including byte-identical complete outputs,
five actor-record variants, no sharing of mutable return state, source reset,
registry republish, policy hash change, ambiguous IDs, range hold/retry and
bounded retention. The 12,000-row case is intentionally large and is not a
typical live registry. No first-admission cost reduction is asserted; the
pinned original 523 definition ZIP and Android were not available locally.

Run the fixture with an isolated Godot user profile and either
`-- --rows=256` or `-- --rows=12000`:

```sh
godot --headless --path . --script res://tests/current523_npc_actor_projection_cache_test.gd -- --rows=256
```
