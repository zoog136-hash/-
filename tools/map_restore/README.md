# Offline base508 map restoration

These tools consume local validated Land tables, original map/tile inventories,
and separately retained original files. Generated art and resource packs stay
outside public Git. No tool activates maps in the default game or changes saves.

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
