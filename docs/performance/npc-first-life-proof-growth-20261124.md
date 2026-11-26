# NPC first-life projection: shared typed-closure ID proofs

523.843 log frame 2775 (NPC 73681, sprite 4576) measured 346.373 ms inside
`setup.projection`, not the whole 380.195 ms actor setup. It does not
identify definition table reads vs closure construction/publication, named
resistance or range. The new markers split those boundaries without
changing admission, stats, loot, visuals, category, spell, or status policy.

First-life growth can encounter the same typed source ID from multiple
spells, e.g. a repeated Bonus, BonusType, Unit, or BonusApplicationType.
Only a globally unique, non-excluded row at its exact source position that
has already passed the existing publication check can be reused. Owner-row
queries do not establish global ID uniqueness and never populate the proof
dictionary. The dictionary lasts only one synchronous growth, is cleared
on success and failure, and is never persisted or shared with the policy
template cache from #860.

No definition-reader/format/producer file was edited: the dedicated store
key is format-stable, but the broader equipment, dungeon, shop, skill,
expedition and quest producer keys include the reader's complete code.
The new path does not invalidate those bakes or eagerly open a table.

An isolated Godot 4.7.2 Linux headless fixture admits two synthetic NPCs
with 24 spells × 12 links each. Eight alternating arms, cold in-memory
relation indexes, medians for both first projections: **113.9 → 38.8 ms**,
1,179 → 42 actual ID proofs per NPC. Full compiled closure, hashed
provenance, admitted source identities and first/repeated actor outputs
matched byte-for-byte; duplicate IDs still rejected, and an exact-source
retry succeeded. Repeated same-NPC timing was noisy and not improved by
this path. This intentionally shared synthetic dependency graph does not
measure the original packed-source first conversion, NPC 73681, or Android.

```sh
godot --headless --path . --script res://tests/current523_npc_first_life_proof_test.gd
```
