# Current523 source maps in the existing game

This is the whole-map continuation of PR232. The immutable Aden-only packs and
[earlier installation evidence](CURRENT523_ADEN_SOURCE_RUNTIME.md) remain valid
for their stated scope. This document does not claim complete original-game
restoration or verified native collision, portal activation, actor-foot placement,
alpha, combat, NPC placement, or every-cell play coverage.

## Exact input scope and local outputs

The authenticated whole-map handoff ZIP has SHA256
`ef9728b3ff364a3930668f80ab8c6edae93c86d036b7c0772760c25305e86366`.
Its CRC and payload identity were checked and `HANDOFF_PR232_KO.txt` and the
priority rows read. It is a source-location/declaration index, not 6,570 received
original packets.

| Layer | Full scope | Received and built current scope |
| --- | --- | --- |
| Native logical Land rows | 1,065, including68 excluded Lands | All original declarations retained;997 ordinary Lands classified |
| Literal native AssetPaths |619 total;577 ordinary physical roots | Every ordinary root has its exact original S32 inputs |
| Ordinary original members |6,570:6,558 S32 and12 SEG | All6,570 original byte identities received;795,660,419 original bytes |
| Placed S32 |6,558 original S32 |6,557 candidate placements; one literal nine-character Aden name retained unplaced |
| Required TI2 |7,557, derived from every actual ordinary S32 floor/cover/object reference | All7,557 received, strictly decoded and included; no missing tile/frame reference |

The complete source pack is `current523-normal-source-pack-all6570-v5/` under
`/workspace/aden-validation/`:6,571 files /312,374,868 stored bytes.
`source523.json`:17,260,837 bytes, SHA256
`6b71f4adb533b7acae6a7327e83af1b1322001a0f67c417bb3fae1bec35d96ca`.
Original map inventory SHA256:
`95d3dac855d422c866ecbc4cf21612802944c246d099278870ed87dee2b1cd39`.
All6,558 S32 use lossless gzip with independent stored/original identity checks;
12 SEG are preserved as unsupported alternatives, each with a same-stem S32.

The full required tile pack is `current523-all7557-ti2-runtime-pack-v2/`:
7,558 files /282,369,476 bytes. `tilepack523.json`:21,156,382 bytes, SHA256
`8a954372eed28e360dc3c7c77f361fba1e0fcc7ee1daa7ffa204f6a679e28482`.
It retains261,213,094 original TI2 bytes and renders coverage atlases on demand,
without storing several gigabytes of derived PNGs. TI2 physical block counts are
preserved:5282 has60,5293 has108,7211 has107. Unused atlas storage slots are
transparent padding and are never accepted as original frames.

Current input qualification compares exact original SHA256/size/ZIP CRC with the
523 member index.293 unchanged TI2 members were obtained from a retained DAT
whose whole hash differs from the current selected DAT. Both DAT hashes and the
independent current member proof are retained; those old containers are not
reported as current whole-DAT downloads. The remaining7,264 TI2 have matching
selected-DAT provenance.30 otherwise missing S32 and286 TI2 were recovered from
only the exact named normal-resource DATs and checked against current container
and member hashes. No engine/APK was read. Archive selection is per container;
523 does not imply every container changed after508.

These immutable packs are currently **LOCAL_ONLY**. The earlier Aden-only Drive
application pack and separate original backups remain intact. Their successful
download does not certify this new whole-map pack. Game consumption uses explicit
private folders and manifest pins; Drive storage is not automatic installation.
Original resources and derived atlases never enter the public Git repository.

## Build and use

`build_current523_source_pack.py --help` describes the caller-pinned original
inventory, complete native Land table, and optional verified whole-map handoff
normalization. It rejects unsafe paths, a wrong current member identity,
misdeclared local availability, symlinks and existing output directories. A file
from a retained508 container qualifies as current523 only when its exact bytes
match the current selection proof; a base508 label alone is insufficient.

The normal source pipeline retains every expected ordinary member. Missing,
malformed and unsupported members remain explicit and never become zero-filled
walkable cells. The generic reader validates the supplied manifest SHA, original
whole-file SHA, section layout and section SHA before a chunk can participate.
The old fixed Aden reader is not relaxed or relabelled as a generic reader.

```sh
python3 tools/map_restore/build_current523_source_pack.py \
  --source-dir /private/current523_sources \
  --land-table /private/current523-tables/Land.json \
  --inventory /private/normalized-current-inventory.json \
  --expected-inventory-sha256 <verified-inventory-sha256> \
  --output /private/source-pack --storage-mode hardlink

python3 tools/map_restore/build_current523_tile_pack.py \
  --source-dir /private/current523_sources \
  --inventory /private/verified-ti2-inventory.json \
  --expected-inventory-sha256 <verified-inventory-sha256> \
  --output /private/tile-pack --atlas-storage runtime_ti2
```

The source builder's hardlink mode is explicit, limited to private immutable
originals, and checks source/destination hashes without changing shared file
permissions or contents. Tile reuse also checks source identity and freshly
decoded coverage pixels. Link failures do not silently copy or publish a partial
pack. Prior versions remain intact.

In the existing game, open settings and the original-map controls. Select
**전체 맵 카탈로그 · 논리 Land 선택**. Supply the generic source and tile directories
and their exact manifest hashes, then use **카탈로그 확인 · 지역 목록 읽기**.
The list shows classified ordinary logical Lands and raw available/expected
counts. A listed declaration is not proof of installed terrain or tile coverage.

Choose the logical Land and an explicit original cell using **원문 좌표로 입장**.
Coordinates from another Land are never inherited implicitly. Without an explicit
entry, only a saved cursor for the same logical Land, source root and manifest
can be reused. The field and arrival frame must validate before replacing the
current field. Missing tile coverage, invalid placement or blocked entry preserves
the existing map and position. **기존 지도로 복귀** restores the initial host field.
This setup consumes existing private folders; it is not a new whole-map installer
or a claim that the older Aden ZIP includes these additional regions.

## Identity, coordinates and own movement

Logical identity is native `Land.ID` plus the exact `AssetPath`. Numeric physical
folders are not implicitly Land IDs. Land47443's literal `13341` is retained with
an explicit `Map/13341/` physical binding. Native Lands0 and12156 share `0/` but
remain separate logical fields, cursors and declaration namespaces. `TalkingIsland_pc`
is a native M row name; the source packets were qualified as M, not PC resources.
The nine mixed ordinary/excluded roots retain per-logical-Land admission policy.

The eight-hex filename placement and 24/-12,24/12 display bases are explicit
coordinate hypotheses. The nine-character Aden original remains losslessly
registered but unplaced. Native integer source cells and fractional saved actor
components are distinct: `to_world(integer_cell)` centers once;
`components_to_world(already_centered_components)` does not center again.

The default own allowlist is `[0,4,8,12,32]`, configurable in settings. Both raw
u16 halves must be allowed and both raw u32 floor references must exist.
`0xffff` attributes, `0xffffffff` floor sentinels, missing/corrupt/unplaced chunks,
unknown cells and diagonal corner cutting are refused. Raw words and all original
packet bytes are preserved. This is TWILIGHT's explicitly labelled interpretation,
not a recovered native M passability bit. Existing A3 navigation grids, old map
geometry, NPCs and monster positions do not supply the new field's geography.
Raw chunk caches are bounded to48 and persistent tile atlases to32.

Black and white stored pixels are preserved. Candidate RGB565/24x24 coverage
atlases distinguish stored and unstored pixels; native layer blend/alpha and
actor-foot alignment remain unverified.

## Native portal definition boundary

PR230 owns native Portal/Territory/Land definitions and their verification.
PR232 adds no second native definition catalog or compiler. The optional bridge
accepts a caller-owned verified provider through:

```gdscript
world.bind_current523_source_portal_provider(provider, verified_manifest_sha256)
```

The expected existing definition pack SHA256 is
`2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90`.
The trusted PR230 caller must verify that pack before binding. Passing that string
does not authenticate an arbitrary provider. Required adapter methods are:

```gdscript
portal_evidence_for_land(native_land_id, exact_asset_path) # raw Portal rows
portal_context_for_land(native_land_id, exact_asset_path, portal_id)
# copied full rows: Portal, SourceLand, TargetTerritory, TargetLand
```

The generic portal list/action remains unavailable without this genuine runtime binding. The
existing same-Aden portal contract remains separate. Definition presence is not
endpoint readiness or native activation proof. The explicit generic button is
labelled **TWILIGHT 자체 수동 이동 · 원작 활성 조건 미확정**.

The pure planner checks exact joins, complete native Land rows, both fields'
manifest/per-asset inventories, actual endpoint member/SHA/attributes/floors,
ordinary logical scope and the actor's exact declared source cell. Only singleton
Territories qualify. Rectangles/inverted bounds, unknown rules, missing fields
and blocked cells are held without selecting a center, nearby cell or replacement
coordinate. No reverse edge, trigger radius, cost or LandTeleport rule is inferred.

Cross-field travel prepares a fresh hidden renderer/field/disabled physics,
validates the arrival frame and writes the target Land/cursor atomically before
publishing runtime references. Failures retain the previous field, renderer,
position and preference bytes. All successful hops retain the original host
snapshot for return and existing save compatibility. A missing native rule is
not silently called native behavior.

Portal1101 is a clear directed candidate under the default own policy:
Land1 `(32668,32803)` to Territory173094's exact point Land0 `(32477,32855)`.
Both original endpoint pairs are `[0,0]`. Portal523's declared807/808 endpoints
both contain `[0,1]`; the default own policy rejects them. Declaration coordinates
are preserved rather than changed to force travel.

## Execution evidence and limits

Latest complete-input checks use the source and tile pins above:

- All997 ordinary logical fields /577 physical roots:55,747 Godot assertions,
  with every available original's SHA and independent raw word/floor probes.
  All6,558 originals are registered;6,557 are placed and one remains unplaced.
  Every logical row is checked, including shared physical roots and high IDs.
- All26,861,568 original S32 cells were independently examined under the current
  own allowlist.7,930,810 cells qualify; every one of577 roots has at least one
  clear cardinal adjacency. This is an own-policy data audit, not native collision
  validation or an actual player visit to every cell.
- All7,557 actual TI2:15,235 Godot checks, every expected Python coverage hash,
  bounded native Brotli decoding, physical last-frame/padding rejection and32-atlas
  LRU checks.4,457,299,968 RGBA bytes were independently compared by hash;
  all actual S32 reference frame indices are within their original physical count.
- Complete gzip/source and runtime-TI2 packs in actual Main:34 checks in142.05s
  for settings997-Land listing, Land1 entry, walking, physical blocked-cell refusal,
  outside-region denial, exact return, failed-switch preservation and save safety.
  A new process restores the same source cursor with8 checks in66.75s.
  The copied geographic contract and explicit safe-region landing policy are
  exercised separately from native arrival/admission semantics.
- Default-off actual Main/core save preservation:35 checks. Tracked resource
  integrity:723 atlases /41,442 frames /233,420,026 bytes, unchanged.
- Python source builder11, TI2 builder21 and core harness8 focused tests pass.
  Source-pack snapshot isolation and matching external-pin checks also pass.

The full logical-field audit shares a verified immutable catalog snapshot rather
than reparsing the same17MB JSON997 times. Every selected field owns separate
registries/caches and still checks original bytes before use. Wrong pins and
clearing one copied catalog cannot clear its parent or sibling. The earlier slow
repeated-parse run was stopped as PARTIAL_NOT_PASS; its log is retained.

Historical actual Godot4.7.2/OpenGL checks on earlier immutable packs:

- Initial generic Land1 UI entry/movement/blocked-cell/return/save:28 checks,
  102.42 seconds; new-process reconnect:8 checks,59.68 seconds. Source v2 and
  exact73-TI2 subset were used; this does not describe the later v4 pack.
- Generic source v3 and3027-TI2 v2: native0/1/2/3/807 entry, walking, raw denied
  cells, distinct original chunk seams, return and unchanged progress/save:
  89 checks,164.26 seconds. Lands808/809/810:55 checks,142.11 seconds;
  Lands811/812/813:55 checks,121.86 seconds. Every run kept the180-second limit.
  All11 physical roots were rendered and moved through, including one two-member
  seam per root. This is not every-cell, every-portal or all577-root coverage.
- Original source v4 field:4,060 checks across all20 available logical Lands and
 905 distinct source files, with original file SHA and three independent raw-pair
 probes per placed chunk. Generic pack57 checks; private builder7 tests.
- Tile v2:3,109 Godot checks across all3027 actual originals/PNG/RGBA records;
 12 Python tests. Actual originals are separated from authored fixture assertions.
- Pure travel planner:80 checks with pinned actual source/handoff input, including
 clear1101 and blocked523; no native activation or Main travel claim from this test.

The first regional test run failed because its helper centered already-centered
coordinates again and compared parsed numeric arrays without normalizing numeric
types. The corrected helper checks the actual source-cell round trip and compares
numeric values; the original failed logs are retained. Production coordinate
conversion did not need changing for this harness error.

Local logs/screenshots and receipts live under `/workspace/aden-validation/`.
`CURRENT523_GENERIC_SOURCE_V4_EVIDENCE.json` and
`current523-unified-ti2-validation-v2.json` separate raw byte verification from
runtime claims. Latest compact receipts are
`current523-all997-fields-verified-snapshot-v5-receipt.json`,
`current523-all7557-runtime-ti2-validation-receipt.json`,
`current523-all6558-own-cell-audit.json` and the `generic-fullpack-v5/` Main logs.
The original acquisition and normal-map TI2 closure are complete. Genuine PR230
provider binding, additional native portal execution, native collision/activation,
unplaced Aden geometry, SEG decoding and every-region actual player coverage
remain separate limits. SEG alternatives do not represent12 missing regions.

The deferred seven-region harness completed43974 before its two-region180s run
timed out; it is not a passed seven-region suite. The local harness/log/capture
are retained. The user's later whole-map-first priority deferred further Totem
integration, including EXP/growth/admission/UI feature work.

Tracked resource integrity remains723 atlases/41,442 frames/233,420,026 bytes.
Code goes to the same draft PR232 with `[skip ci]`; no other branch/main merge,
manual CI dispatch, M engine/APK/XAPK work, or excluded arena/ziggurat/guild/siege
content was introduced. Latest-main overlap and integration conflicts are reported
separately; this continuation does not merge those changes silently.
