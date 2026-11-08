# Offline base508 map restoration

These tools consume local validated Land tables, original map/tile inventories,
and separately retained original files. Generated art and resource packs stay
outside public Git. No tool activates maps in the default game or changes saves.

## Complete 523 client maps and tiles (all maps)

`client523_map_inventory.py` and `client523_tile_inventory.py` build the existing
pack builders' inputs straight from the client's `Map*.dat` / `Tile*.dat`, each
checked against the 523 `files_info.json` SHA-1. Outputs stay outside Git.

```sh
python tools/map_restore/client523_map_inventory.py --files-info files_info.json.523 \
  --map-dat-dir PRIVATE/Client/Data --land-table PRIVATE/content/Land.json --output PRIVATE_MAPS
chmod -R go-rwx PRIVATE_MAPS/source   # hardlink mode requires private sources
python tools/map_restore/build_current523_source_pack.py --source-dir PRIVATE_MAPS/source \
  --land-table PRIVATE/content/Land.json --inventory PRIVATE_MAPS/map523_inventory.json \
  --expected-inventory-sha256 <printed sha> --output PRIVATE_MAPS/pack --storage-mode hardlink
python tools/map_restore/client523_tile_inventory.py --files-info files_info.json.523 \
  --tile-dat-dir PRIVATE/Client/Data --output PRIVATE_TILES
python tools/map_restore/build_current523_tile_pack.py --source-dir PRIVATE_TILES/source \
  --inventory PRIVATE_TILES/tile523_inventory.json --expected-inventory-sha256 <printed sha> \
  --output PRIVATE_TILES/pack --atlas-storage runtime_ti2 --tile-ids <decodable ids>
```

Land scope follows the user's decision of 2026-11-09 to implement every map: all
1,065 Lands are selected with no content exclusion, recorded as policy provenance
(the earlier pinned handoff excluded 68 siege/clan/ziggurat/arena Lands).

Results on the complete client (2026-11-09): 94 Map DATs, 8,311 members; 7,518
belong to 619 Land AssetPaths (7,505 S32 ready, 13 SEG unsupported; 613 assets
ready, 6 partial) and 793 sit under 57 roots no Land declares (e.g. `Map/99998`).
`tests/current523_source_field_test.gd` (Godot 4.7.2 headless, now scope-aware)
passes all 51,361 checks with this pack: every one of the 1,065 Lands configures
and 7,504 of 7,505 available originals are placed. Tiles: 29 DATs, 8,513 TI2; 8,511 packed with runtime TI2 storage,
2 rejected by the existing decoder (4690 writes outside the 24x24 canvas, 5668
truncated).

## Composition and evidence

- `build_base508_universe.py` separates source availability, referenced Land
  contexts, unreferenced AssetPaths, visual output, and explicit host evidence.
- `import_base508_batches.py` validates transfer ZIP/member hashes and original
  inventory size/CRC, preserving existing identical inputs and rejecting conflicts.
- `restore_base508_universe.py` resumes one visual artifact per AssetPath with
  three bounded workers and one shared content-addressed WAL tile cache. Original
  source parsing is serialized per cache miss. Existing completed packs are reused.
- `compose_base508_streamed.py` retains original layer/sequence order and emits
  at most 1024px exact lossless WebP chunks without allocating a full-map canvas.
  `verify_base508_pack.py` independently reassembles the full row-major RGBA hash.
- S32 takes precedence over a same-origin SEG variant. Original SEG bytes and
  normalized geometry remain separate. Legacy TIL decoding never replaces TI2.

The full runner takes `--manifest`, `--requirements`, `--analysis`, `--structure`,
`--tables`, `--source`, and a private `--out` directory. Python requires Pillow
with lossless WebP support and Brotli support for the original tile codec.
Godot review tools use the existing pack API and `TWILIGHT_BASE508_UNIVERSE`.

## Failures and review-only output

Unknown terrain/height bits remain unknown and blocked. Original coordinates,
attributes, TileIDs, layers, portal regions and NPC flags are preserved; canvas
scaling is never used to infer collision or source coordinates.

`--isolate-unresolved-chunks` withholds entire visual chunks with unsupported
original references, preserves their raw geometry, and emits `partial-map.json`.
Such output is not a complete map and cannot automatically register in the game.
Unreferenced directories receive `asset.json` and no fabricated LandID.

`validate_base508_universe_contexts.gd` checks real pack loading and Land context
selection. `render_base508_universe.gd` captures composed overviews in a Godot
viewport; these captures do not prove gameplay performance. The portal-pair tool
provides manual point-destination inspection, not automatic portal activation.

`package_base508_runtime.py` creates an explicit test-mode catalog or a verified
private runtime ZIP without duplicating separately retained raw original files.
A local ZIP is not delivered until its private transfer succeeds. Full game,
original collision/height/portal semantics, and Android validation remain separate.

## Faith Tower source-edge experiment

`review_base508_source_edges.gd` is an explicitly gated experiment on the new
base508 maps (13398/13401/13472/13504). It does not modify production movement
or reuse the old PNG polygons. Set `TWILIGHT_BASE508_UNIVERSE` to the restored
universe directory, `TWILIGHT_BASE508_TABLES` to validated original content
JSON tables, `TWILIGHT_EDGE_ASSET` to one of those AssetPaths and
`TWILIGHT_EDGE_OUTPUT` to a private result path. Run Godot with
`--script res://tools/map_restore/review_base508_source_edges.gd -- --source-edge-experiment`.

The experiment requires the exact Land and Locations identities and verifies
UIMapQuickTeleportOman → ItemBonus → BonusType.TeleportToLocation → Locations.
It starts at that original arrival, without nearest-cell correction. Both raw
halfwords are retained: the candidate zero/open, one/closed edge interpretation
is spatially reciprocal. Unknown values abort; diagonals require both orthogonal
routes. An actual radius-4 CharacterBody sweeps four whole-map routes and samples
closed-edge physics, using the same source-coordinate projection as the art.

Add `--interactive` for WASD and click-path movement with bounded source chunks,
or `--interactive --interactive-smoke` for the short renderer/body check.
`TWILIGHT_EDGE_CAPTURE` optionally selects a private PNG prefix for route captures.
All outputs stay outside Git. No original item is consumed and no save is read.

Passing these checks proves candidate graph/physics consistency, **not original
M movement equivalence**. Original height, actor foot/depth, dynamic occupancy,
entry prerequisites and original-client successful/blocked-step observations
remain unverified. Do not promote this experiment to the default game or claim
that original collision is complete. The earlier small-hall routes cannot serve
as whole-map acceptance evidence.

### Main source-edge compatibility review (Faith 1–4)

On PR217's actual Main runtime, opt in with `--base508-source-test
--base508-source-edge-review --base508-pack=<private-pack>
--base508-tables=<base508-content-tables>`. Exact Land/Asset pairs are
47914/13398, 48274/13401, 48774/13472 and 49324/13504. No old PNG
navigation is reused. Original arrival cells are required without a nearest-cell
fallback. Missing chunks and unreviewed attribute values reject navigation.
The default game and save routing remain unchanged; source-test saves are disabled.

`verify_base508_main_edges.gd` runs actual Main/class selection, a real Player
click movement, four full-map extreme routes using the Player's radius-4 body,
64 closed-boundary probes, coordinate round trips, strict occupancy registration
and removal, and save-file hash preservation. Run in an isolated XDG data root:

```sh
godot --headless --path <PR217-consumer> \
  --script res://tools/map_restore/verify_base508_main_edges.gd -- \
  --base508-source-test --base508-source-edge-review \
  --base508-pack=<private-pack> --base508-tables=<base508-content-tables>
```

Local four-floor Main validation reached 16/16 routes through 29,180 body-sweep
steps and blocked 256/256 sampled boundaries. 85,764 source-cell coordinate
round trips passed. Dynamic occupancy uses an explicit confirmed runtime test
instance of an original occupying class; territory rectangles are not NPC
placements. Actual source NPC populations and automatic item/portal activation
are not implemented here. These checks prove our compatibility policy agrees
with its physics, not that M's unknown terrain bits, heights or native foot
anchor have been recovered. Flat original chunks still do not supply actor
foreground occlusion. Runtime 30 FPS on target hardware remains unverified.
The consumer lacks knight base animation sheets and one HUD icon, producing
existing fallback warnings; they are not counted as source actor delivery.

The newly supplied reference ZIP (SHA256
`5d31500922f6e8b5e60b3dee72c341f7beb38163ee0bf664abb2370cf2d18ebc`)
was checked against the current renderer: all 8192 half-tile placements agree
under the same chunk origin. MTil is identical to the previously reviewed
reference. No decoder replacement, original pixel change or map regeneration
was justified; the visual mask remains separate from passability.

Source expansion: Land25/Asset25 (Suryun_dungeon_1) passes actual Main
arrival, click, four extreme routes (4298 physical steps),64 blocked probes,
4788 coordinate round trips, physical occupancy add/remove and exit save hashes.
The arrival is read from Locations rather than a Faith-specific constant.
Land75/Asset75 is now enabled only with explicit original portal-target evidence.
The earlier apparent counterexample was an entry-selection error: Locations333
is merchant Pagor at(32790,32817), not a map entrance. Portal341 targets the
exact point(32763,32902) on Land75. Use
`--base508-entry-portals=<Aden-pack>/portals.json --base508-entry-portal=341`.
No coordinate offset or passability rule was changed. Actual Main passed four
routes/3687 body steps,64 boundaries,5535 coordinate round trips and exit save
hashes. The pack has no occupying NPC class evidence, so dynamic occupancy is
explicitly unavailable there rather than populated with fabricated NPCs.
Locations are now selected by reviewed exact IDs (Faith item chain; Suryun760
is a test location), never by assuming the only row is an entrance. Explicit
portal targets must match the Land and be points; region centers are rejected.
These are opt-in review entries, not automatic portal triggers or server-condition
recovery. Native M passability remains unconfirmed. Height, foreground and automatic portal triggers remain unresolved.

### Explicit-entry review queue

`build_source_entry_queue.py` consumes original BonusType/Bonus/Locations and
original enriched portal tables, plus the independently scanned attribute
inventory. Locations are eligible only through an explicit TeleportToLocation
bonus; other location rows are not entries. Only point portal destinations are
eligible. Source identities and the exact map.json SHA256 bind each queue row.
No output is production movement approval and entry prerequisites are not
consumed or inferred.

Select an entry explicitly with `--base508-entry-catalog=<private-queue.json>
--base508-review-entry=PORTAL_POINT_TARGET:<original-portal-id>` (or
`TELEPORT_TO_LOCATION:<original-bonus-id>`), together with the existing source
review flags. The same shared loader/navigation/physical field supports these
entries without adding hand-authored map colliders. The queue rejects other
attribute profiles; missing explicit entries remain separate blockers.

The current612 referenced pack inventory yields34 graph-review candidates,
23 zero/one-profile packs without explicit entries, and555 unreviewed attribute
profiles. All34 candidates pass four routes within their arrival component;
three (13372/30/31) contain additional disconnected components, which are not
claimed reachable. The full graph and component sizes remain separate.
`verify_source_entry_queue.gd` records failures per original entry and never
moves an entry to a nearby cell. Runtime Main validation remains a separate
stage; graph approval alone does not constitute physical walking approval.

The queue now enumerates every retained Land context, sharing AssetPath pixels:
1055 normal contexts =34 explicit-entry candidates +26 missing-entry contexts
+995 unreviewed attribute contexts. Four partial Land contexts remain outside
normal pack loading. `--base508-land=<original-LandID>` selects the hash-checked
pack context; it never infers LandID from the AssetPath number.

The completed actual-Main batch passed31 of34 candidates:124 full-map extreme
routes,167724 radius-4 physical sweep steps,1984 blocked boundaries and235840
coordinate round trips. Saves were unchanged at every scene exit. Three maps
(13372/30/31) fail whole-map reachability due to separate graph components;
their local arrival-component routes are not full-map approval. NPC occupancy
is explicitly untested where no original occupying class is supplied (75/76/77).
The prior source test location on Land25 remains separately reviewed, not
silently converted into a genuine portal entry.

`run_source_main_queue.py` resumes saved per-Land/Asset results in a single
process with an exclusive lock and atomic checkpoints. It uses an explicit
isolated XDG root and timeout, rejects missing completion receipts, retains
failed results without automatically retrying or changing collision, and
supports the same explicit original entry catalog. Reusing the completed
34-result checkpoint executed zero duplicate Godot jobs. Actual target-device
performance, native height/foreground depth and automatic trigger semantics
remain unverified.

### Component and attribute counterexamples

`audit_source_components.py` checks the existing zero/one graph against every
explicit original entry. Asset30 has four components(1403/1097/1242/1239 cells)
and each has original portal destinations; Asset31 has two(2312/2422),both with
portal destinations. Requiring a single entrance to reach all components was
an invalid acceptance target for these two maps. With `--base508-component-review`,
the actual Main test selects the component of the exact original entry and labels
its coverage accordingly. Six original entries collectively cover these six
components:24 body routes,24535 physical steps and384 blocked boundary samples
passed with unchanged saves. No collision,entry coordinate or graph edge changed.
Asset13372's separate8695-cell component has no explicit entry in this catalog;
its whole-map reachability remains unresolved. The original31 whole-graph passes
remain distinct from these per-entry component passes.

`audit_source_attribute_twins.py` compares source chunk origin,floor,covers,
objects and opacity byte-derived data. It found156 identical visual-geometry
pairs with different attributes,including75 pairs differing only in bit0x04,
36 only in bit0x01 and2 only in bit0x40. Other pairs combine these differences.
Thus identical original pixels/layers cannot independently validate passability.
0x04/0x40 changes do not require a visual-layer change in these examples; this
is not proof that they encode zone types or native height. The supplied PC
reference assigns safe/combat zone labels but leaves bit6 unnamed and contains
an exceptional65-to5 conversion; that rule is not adopted for M. No attribute
masking,unknown-bit clearing or collision transfer is performed by these audits.

The Main queue checkpoint key includes Land,Asset,entry kind/ID and review scope,
so distinct original entrances cannot be silently skipped as the same map run.

Confirmed runtime occupancy can move through `relocate_source_occupant`.
Registration validates the same original map/class/placement contract before
changing either cell ownership or the existing physical polygon. Rejected
updates retain the previous occupancy. It does not infer NPC positions from
territory rectangles or create source populations. Main verification checks
rejected and accepted relocation,old-cell release,new-cell blocking and a real
Player collision against the relocated shape before restoring/removing it.

`verify_source_layer3_layout.py` cross-checks original S32 bytes independently:
L3 offset32768+2+6*N2,8192 preserved16-bit words. Six representative original
chunks(13398/30/1/12179/12146/13042) passed49152 words and49152 projected boundary
segments. Current neighbor-midpoint edges agree with the pinned reference's
attr1 left-to-top and attr2 top-to-right overlay. This validates byte layout
and geometry,not native passability or zone/height interpretation. Reference:
https://github.com/tony1223/L1MapViewer/blob/364fcff15ea019e5a9329170aaf7e245404ebba6/Rendering/OverlayRenderer.cs
No65-to5 zone replacement or new open-edge policy is applied.

`base508_portal_contract.gd` resolves exact source-point/target-point links
between loaded source fields,requires matching original Land IDs and reviewed
foot clearance,and preserves the entire original portal row. Region destinations
are rejected without an original arrival policy. `verify_source_portal_contract.gd`
passed both original point links between Giran castle dungeon1/2. Source fields
now expose their actual original portals as renderer inspection markers.
No automatic trigger is inferred: Portal lacks trigger geometry and activation
predicate. The result explicitly marks these missing native rules and automatic
activation unsupported; it is a coordinate handshake for Main integration,
not an automatic map travel implementation. Original height and foreground
ordering are not encoded by this service.

LandTeleport entry evidence now joins original LandTeleportTerritories to
Territories by explicit table IDs,then preserves the LandTeleport cost,currency,
allow flags and LandTeleportPrerequisite rows. Point destinations alone may be
review entries; region centers are not invented. The normal1055-context catalog
contains12 such point relations,with one in the reviewed attribute profile
(Giran1,relation3484,LandTeleport12484). Its AllowMapTeleport=false and
AllowInterTeleport=false remain intact. Selecting this point in isolated review
mode does not authorize map teleport,spend currency/tickets or satisfy missing
server prerequisites. This addition does not expand the34 ready-map count.
The CN +32 offset observation is not used as a field-layout or activation rule.

Original source NPC registration now rejects explicit numeric IsSpawn=0 before
creating occupancy. A confirmed zero update removes the existing instance's
occupancy and physical shape. IsSpawn1,conditional2 and missing/unknown values
are not removed by this zero-only policy; other original identity,class,
occupancy and confirmed-placement checks still apply. Raw source tables and
backups are retained. Main validation covers zero creation rejection and
existing-instance cleanup while preserving1/2/unknown under the zero-only gate.
