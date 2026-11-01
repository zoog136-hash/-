# base508 monster source-context adapter

This change supplies exact NPC → spawn-view → spawn-pack/territory → Land →
SPR joins. It selects four explicitly declared legacy slots by their complete name/type/grade/level/HP signature, source NPC ID and source spawn context, restricted to host Aden and a verified private pack. It does not infer a source identity from a display name.
No existing asset, map, save or combat implementation is deleted or rewritten.

`data/lineagem_base508/monster_contexts.bin` is deterministic gzip-compressed
UTF-8 JSON, stored with `.bin` so the existing Android `*.bin` export filter
includes it. It contains source tables and SPR declarations, not original pixels.
The adapter loads it lazily, with a 64 MiB decompression bound. The source ZIP
SHA-256 is `0a35250d27765fd8d526fb5a3ab2b2ee3628e4379f9d378690be85d5ee8e3bf4`
(`base508_all_content_validated.zip`, 24,423,824 bytes, ZIP CRC verified).
Per-table and per-SPR input hashes are embedded in the metadata.

The adapter depends on PR #217's `scripts/lineagem_base508.gd` and its
`npc_classes.json`. The new files can be cherry-picked onto that work without
replacing its collectible/runtime implementation. This is not a merge of PR #217.

## Source facts preserved

- NPC rows: 9,470; distinct referenced sprite IDs: 2,596.
- Exact SPR declaration/alias joins: 2,596. This counts declarations, not
  decoded/installed/visually verified actors or complete native timing.
- Spawn-view rows: 60,556; territory links: 14,345; territories: 25,233;
  lands: 1,059; representative spawn views: 4,762.
- Native attacks: 23,151; native attributes: 51,837; native spawn schedule
  rows: 1,379. Their original values are retained without guessing host behavior.
- Spawn rows with missing NPC: 0. Territory/land dangling joins: 0.
- Spawn rows without an entry in `NpcSpawnPackTerritory`: **8,248**;
  these cannot obtain a geographic source context through this join.
- Four runtime host replacements: **248→1110, 249→1108, 281→145, 286→152** (NPC→SPR), restricted to `aden_world`. The actual `Monster.setup` selects these source stats and original renderer when the private pack verifies; missing/corrupt packs retain the complete legacy actor.
- Native geographic base508 map-spawn bindings: **0**. Host positions, population and respawn intervals are explicitly retained as compatibility; no native server placement/rate claim.
- Existing files/assets removed or overwritten: **none**. A separate original layer renderer hides the legacy silhouette on verified replacement instances.

`context(npc_id, spawn_view_id, territory_link_id)` verifies all identifier
joins and requires an active row, a positive NpcLevel, an explicitly accepted
ServerLimitSetID (default `[0]`) and a non-TestNPC source row. An accepted join
is still metadata; it does not prove that schedules, coordinates or pixels are
ready for world activation. In particular, `Land.ID=4` has `AssetPath="Aden/"`.
They are not interchangeable numeric map identifiers.

`record(...)` returns `{}` on failure. On success it supplies the exact source
HP/MP/AC/MR/Exp, spawn-context level and source sprite ID. It strips the former
source3 NPC identity, visual/animation overrides, loot and currency fields.
`record()` alone remains `catalog_only=true`, with `requires_verified_monster_pack` status. `base508_monster_bindings.gd` opts only the four declared host slots into the verified pack, and `Monster.setup` commits the replacement only after the renderer validates every original pixel hash.
Compatibility combat parameters are explicitly labeled. No native loot rate,
quantity, spawn density or host map transform is invented. Callers must retain
these gates; a successful source-table join is not an active world replacement.

Example: NPC 90 (slime), view 762, territory link 558 joins level 4 on source
Land 4. The **same** NPC in view 544562/link 200232 has level 1. Applying one
level globally to the NPC, or using MonsterBookLevel, would be wrong.

## Exact first extraction scope

`data/lineagem_base508/monster_resource_requests.json` describes five source
contexts for NPC 90/248/249/281/286, with source IDs, original dependency IDs,
member paths, DAT archive, size and CRC. NPC 256 has no unrestricted Aden
context in this scope and is explicitly not selected. These are source-first
extraction candidates, with **no legacy-record identity/map-coordinate approval**.

The scope is **53 files / 1,337,437 original bytes**. Fifty members are already
addressed by the existing Library package `transformation-001.zip`
(`libfile_5c8d41f57f0081919d30da9b8abb7f2c`); its exact size/SHA are recorded,
so those files should not be requested again. In this worker that one package
was materialized through Library, its 46,450,634 bytes/SHA/whole-ZIP CRC verified,
and only the requested 50 original SP2 files extracted. Every stored frame was
decoded using PR #217's original decoder: **2,080 stored frames**, with the
original bytes, member CRC and SHA retained in `monster_input_verification.json`.
This proves available/decodable inputs for four selected source NPC contexts;
it does not prove native timing or native geographic placement. A separate private runtime pack was then built for the four fully available NPCs: **40 original SP2 inputs, 1,600 exact decoded PNG frames**, five native actions × eight stored directions; body/shadow stay separate and source offsets are preserved. No pixels are committed publicly. The actual game actor selects this pack in `Monster.setup`.

Only these three members are absent from the supplied category-package index:

| Archive | Member | Bytes | CRC32 |
| --- | --- | ---: | --- |
| `Client/Data/Sprite214.dat` | `Sprite/31-0.sp2` | 22,045 | `60a1b63f` |
| `Client/Data/Sprite214.dat` | `Sprite/31-8.sp2` | 24,248 | `ca35a995` |
| `Client/Data/Sprite214.dat` | `Sprite/31-16.sp2` | 4,359 | `a340b8ca` |

All selected ordinary sprites (31/1110/1108/145/152) have source actions with
no explicit FPS in their resolved declarations. Their tokens and `fps=null`
are preserved; this change supplies no fabricated native frame rate. An existing
host compatibility policy is distinct from verified native timing.

The separate `boss_resource_requests.json` fixes the field-boss renewal Curtz
identity as NPC **60303** → sprite **18465** → view **3520** → pack **1398** →
link **1410** → territory **142** → Land **0**, level **83**. It requests only
**32 SP2 / 3,363,655 bytes** from `Client/Data/Sprite194.dat`:
`Sprite/{18465,18466,18467,18468}-{0,8,16,24,32,40,48,56}.sp2`.
Every exact member, byte count and CRC is in that JSON; none is in the supplied
category-package index. Shadow/clothing declarations remain separate source
layers; no blending is guessed. Build this scope with the same request command
plus `--npc-ids 60303 --land-id 0` and its own output path.

The supplied map-analysis ZIP was also materialized and CRC checked. Its
README confirms source Land/resource/territory joins and explicitly leaves
source terrain/collision semantics and UI map conversion unconfirmed. It does
not provide a reviewed transform into the existing TWILIGHT PNG maps.

## Rebuild and validation

```sh
python3 tools/monsters/build_base508_contexts.py \
  --content /path/to/base508/content \
  --spr-root /path/to/full_resource_inventory/motion_text \
  --output data/lineagem_base508/monster_contexts.bin

python3 tools/monsters/build_base508_requests.py \
  --contexts data/lineagem_base508/monster_contexts.bin \
  --npcs /path/to/base508/content/NpcClass.json \
  --inventory /path/to/monster-metadata/source_inventory.json.gz \
  --supplied /path/to/category-metadata/source_manifest.json.gz \
  --transfers /path/to/lineagem-explicit-input-transfer-manifest.json \
  --output data/lineagem_base508/monster_resource_requests.json

godot --headless --path . --script tests/base508_monster_context_test.gd
```

The test checks the real source joins, differing levels for the same NPC,
wrong NPC/pack rejection, zero XP preservation, no caller/save mutation and no
old visual/loot identity leakage. It does not count a metadata record as an
installed original monster or as a rendered in-game replacement.

The legacy `check_resource_integrity.py --source-dir /workspace/library-files`
checks six earlier ZIPs and fails at missing `a1.zip`; that is separate from the
SHA/CRC verification of this task's accessible base508/SPR metadata ZIPs.

The four-slot private pack is installed by putting its contents under
`user://lineagem_base508_monsters/`, or under the existing card pack's `monsters/`
folder. For this worker, `--lineagem-monster-pack=/workspace/base508-monster-pack/manifest.json`
selects the verified private pack. Unknown FPS uses the existing shared **compatible**
policy and remains explicitly labeled `compat_PC_3_81_default_24_not_verified_for_M`;
`--lineagem-source-strict` retains static pending-timing behavior.

Run the common real-actor loading check with:

```sh
godot --headless --path . --script tests/base508_monster_runtime_test.gd -- \
  --lineagem-monster-pack=/path/to/private/manifest.json
```

With `--check-game-actors`, the test additionally checks the real
`scenes/Monster.tscn` factory, native ID/HP/level, legacy silhouette hiding and
zero invented loot. This worker's full actor dependency graph reports missing
pre-existing skill shaders/audio imports from the sparse baseline; that check
is not claimed clean. The common source binding/pixel/five-action loader passes
independently. Wrong-map/signature rejection is covered in both modes.
This is a common headless load check; per-item visual review remains deferred.

Remaining: Curtz's requested 32 SP2 and original attachment composition,
slime's three requested SP2, remaining NPC-specific source selections and source
geographic map transforms. The backup/removal worker must retain assets still
used by other encounters and environments without the new private pack.
