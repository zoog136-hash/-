# base508 original map restoration

The separate Albino Basin map now renders from **all ten original S32 chunks
and all 434 original TI2 files**. No pre-rendered reference PNG is used by this
build. Based on main `0cab9b3d39e9330feb1c404d8c36b80d3e417b2d`; normal maps,
world/card/monster files, navigation and saves are unchanged.

## Source and output

- Land **48962 → AssetPath `13474/`**; Land IDs are never treated as folder IDs.
- The official archive's normal HTTP Range retry recovered from 503 to 206.
  Its ZIP64 directory identified 25 required DATs. All selected outer DAT CRCs
  and all 444 selected inner file CRCs passed. Extraction ended successfully
  at 2026-11-02 01:00:22 UTC. The full 10 GB archive was not downloaded.
- S32 source bytes roundtrip exactly through the new bounded parser. Floor,
  cover, raw attributes, object groups/layers, 24-bit TileIDs, opacity records,
  declared IDs and uninterpreted tails are preserved.
- TI2 uses standard Brotli followed by original RGB565 palette/RLE blocks.
  The installed standard `libbrotlidec` is used with an 8 MiB output cap.
  No game executable or external viewer executable is run.
- The private output keeps all 444 original source files, lossless geometry,
  per-source hashes, source requests, original portal/NPC evidence, composition
  metadata, overview and 38 lazily loaded native-resolution raster pieces.
  The complete raster is **10,752 × 5,376 RGBA pixels**.

Format references were reviewed as source only:
[MTil](https://github.com/tony1223/PakViewer/blob/fbad69239e3e3c12ec18dfc7722bed284be093cc/src/Lin.Helper.Core/Tile/MTil.cs),
[L1Til display alpha](https://github.com/tony1223/PakViewer/blob/fbad69239e3e3c12ec18dfc7722bed284be093cc/src/Lin.Helper.Core/Tile/L1Til.cs),
[display projection](https://github.com/tony1223/L1MapViewer/blob/364fcff15ea019e5a9329170aaf7e245404ebba6/Helper/ViewportRenderer.cs).
TI2 display type flags supply half alpha and brightness alpha for cloud/smoke
masks. Raw RGB565 colors remain intact; no invented smoke color is inserted.
The initial opaque-mask render was corrected before delivery. These display
flags do not define terrain collision or prove original M engine equivalence.

## Separate counts

| Item | Result |
| --- | ---: |
| Registry rows / distinct AssetPaths (private metadata, not live activation) | 1,059 / 615 |
| Original S32 / TI2 loaded | 10 / 434 |
| Unique used TileID/subimage pairs decoded | 63,603 |
| Floor half tiles / object parts placed | 81,920 / 268,598 |
| Total source placements / visibly contributing placements | 350,518 / 338,532 |
| Fully transparent source placements | 11,986 |
| Missing tile pairs / fallback tiles | 0 / 0 |
| Actual S32/TI2 maps rendered | 1 |
| Original portal table links / region destinations | 4 / 4 |
| Playable actor portal traversal enabled | 0 |
| NPC spawnpack evidence / original occupancy-true classes | 23 / 15 |
| Confirmed active source occupants / confirmed terrain collision cells | 0 / 0 |
| Unresolved original terrain attribute words | 81,920 |
| Existing navigation files separately preserved | 4 |

The loader resolves original portal coordinates to their original target regions.
The viewer marks source grid anchors and keys 1–4 inspect entire destination
regions with the camera. It never substitutes an actor arrival point for a region.
Activation conditions and actor traversal remain unverified.

Actual NPC instances can register/remove occupancy at confirmed source cells.
Only original boolean `IsOccupyLandTile=true` is accepted; numeric `2` is rejected.
Overlapping instances remain occupied until the last instance leaves. Spawn
regions are not filled as obstacles. EarthObject placements for this target are
zero; unknown Obstacle/Gate/terrain values are not converted into booleans.

Unknown terrain remains blocked for actors. Existing navigation matches latest
main Git blobs and is retained separately, without a guessed source transform.
No collision or height is inferred from PNG dimensions, colors or alpha masks.

## Run

```sh
python3 tools/map_restore/build_base508_pack.py \
  --analysis /private/decoded-map-analysis \
  --structure /private/full-structure-analysis \
  --tables /private/validated-all-content --land 48962 \
  --source /private/extracted-base508 --compose-tiles \
  --preserve data/maps/navigation/albino_01.nav \
  --preserve data/maps/navigation/albino_02.nav \
  --preserve data/maps/navigation/albino_03.nav \
  --preserve data/maps/navigation/albino_04.nav \
  --out /private/new-map-pack
godot --path . res://scenes/maps/base508_review.tscn -- --pack=/private/new-map-pack
```

WASD/arrows pan the review camera; wheel zooms. `--detail` starts at native
pixel zoom; `--portal=20072` inspects that portal's destination region.
`--capture=/absolute/file.png` saves an actual viewport after 90 frames and prints
counts/timings. This is a separate scene and pack, not the existing runtime-pack
installer schema. The old `--png` path remains a separately counted reference mode.
The reusable compositor currently bounds whole-raster allocation to 160M pixels;
larger maps require a tiled offline compositor rather than a larger allocation.

## Evidence and remaining limits

Nine targeted parser, coverage, alpha and chunk-seam tests pass. Real-pack Godot
checks preserve exact portal regions and raw attribute value 5 at the sampled
source half-cell, verify NPC occupancy registration/removal, and reject boolean
coercion of numeric 2. The required 723-atlas/41,442-frame resource audit passes.
All emitted source hashes and reconstructed full-raster pixel SHA are checked.

Actual Godot 4.7.2 Compatibility/OpenGL llvmpipe overview and native-detail captures
are produced. Native detail reaches 30 steady FPS with 33.33 ms p95 in the short
isolated scene; loader time is reported separately. Detail storage is capped at
8 × 1024² RGBA textures. Whole-game and Android testing was deferred as requested.

The pinned existing `13474.png` was compared separately. Normalizing visible
bounds gives alpha IoU 0.7276 and RGB mean absolute error 33.90/255. The reference
has visibly different extent and northeast content; its base508 equivalence is
not established. No source placements or collision coordinates were changed to
force a match. The side-by-side comparison is visual evidence, not a fidelity
certificate. Original engine effect-tail/depth/animation and terrain bit semantics
remain unverified. A complete visual source composition is not a claim that all
615 resources or the game's 25 live maps are restored.

Source resources and screenshots stay out of public Git. Private delivery uses
the user's confirmed zoog136 Drive account; the separate earlier Library upload
helper HTTP 401 was not bypassed or treated as fixed. The small exact extraction
request is independently available as Library item
`libfile_e0fdf413b6948191ba87b85bdad25700`.

## Follow-up collision evidence

`profile_base508_collision.py` joins raw half-cell attributes directly with
original portal and NPC territory coordinates. Albino contains only words
1 (5,120), 4 (14,341) and 5 (62,459). Source cell pairs are (1,1):2,560,
(4,4):6,721, (4,5):434, (5,4):465 and (5,5):30,780. Two portal anchors are
(5,5), two are (5,4). Thus even table portal anchors do not require two words
of 5; they are not proof of directional passage or a simple whole-cell mask.

All 15 target NPC classes and their category explicitly have occupancy=true.
All 24 territory references are regions, not actual instance points. Word 4
occurs in all sampled regions, 5 in 23, and 1 in none. Rectangle sampling uses
closed integer bounds for profiling only. Neither a spawn region nor an image
pixel establishes a live occupied cell. No terrain cells were newly declared
open or blocked. Land rules NoTeleport=1 and MinLevel=75 are retained as source
facts, not interpreted as portal activation conditions.


## Source coordinate and geographic NPC integration

`base508_contract.py` and `base508_contract.gd` share the explicit source-cell
contract. Albino uses `base508_land_48962`, LandID 48962, AssetPath `13474/`,
and coordinate space `LINEAGEM_WORLD_SOURCE_CELLS_V1`. Supplied cell bounds are
[32576,32832,32895,32959]; only supplied 64-cell chunks are accepted. The display
basis is X=[24,-12], Y=[24,12], with source origin [32576,32832] and image
translation [0,3828]. Visual cell center adds [24,12]; original engine actor
foot anchor remains unverified. Neither image scale nor old map aliases define
source coordinates. S32 stores two interleaved u16 half-cell words per cell;
it is incompatible with the existing L1J per-cell directional byte loader.

The loader exposes 95 contextual NPC class-view/territory records from 23 packs,
15 classes and 24 territory references. These are not 95 live NPCs. Regions keep
all original bounds, IDs, contextual levels and raw gates, without a fabricated
center. Runtime occupancy accepts only explicitly confirmed source positions
and matching edition, map key, LandID, AssetPath and coordinate space. Boolean
confirmation must be true; numeric 2 and fractional identifiers are rejected.
`--npc-region=231932` displays the original region in the actual map renderer,
without spawning an actor. Portal source anchors and target regions remain
inspectable; trigger shape, activation, boundary convention and arrival choice
are unresolved.

Two additional original S32 chunks from AssetPaths 0 and 1 were retrieved via
normal official HTTP Range requests, CRC checked and losslessly round-tripped.
They include words 0,1,8,9,65,73, unlike Albino's 1,4,5. Eleven portal source
observations and five distinct target points provide counterexamples to an
Albino-only rule. The pinned public PC decoder treats bit 0 as blocked and
special-cases 65, while its format document lists five exceptions. Neither is
an authoritative M movement/height specification, so these are candidate rules
only. No additional terrain cells were opened. Texture registration against the
old PNG produced correlations below .02 across nine scales; no transform was
accepted and none of the four preserved navigation grids was transferred.

`plan_base508_maps.py` performs reusable source readiness checks without
counting metadata as rendered maps. Current supplied resources: Land48962 has
10/10 S32 and 434/434 TI2; Land0 has 1/64 and 90/619; Land1 has 1/12 and 7/73;
Land22792 has 0/20 and 9/97. Partial maps remain unready. The approved 70,450,588
byte private resource ZIP is unchanged; newer contract code can derive the
contract for that pack without rewriting it. New packs embed a hashed contract.


## Registered legacy movement review

A later local-patch search resolved the failed global registration: the original
PNG was scaled from a proposed 21504x6912 canvas to 19998x6428, while this source
map excludes an additional northern band. The reproducible display transform is
X'=X*(21504/19998), Y'=Y*(6912/6428)-1536. Sixteen independent route patches across
Albino 01/02 have zero integer-pixel residual under a +/-12 pixel local search;
high-pass correlation ranges .445 to .815. This establishes local geographic
registration, not identical artwork or original M movement semantics. The old
NE mushroom region remains outside the accepted map list.

`verify_base508_registration.py` verifies original reference SHA, composed pixel
SHA and all 16 patches, producing a certificate bound to the existing plan and
review hashes. `base508_registered_navigation.gd` retains `NativePngField`'s
original 16px grid, 4px clearance, alpha exclusions, collision shapes, exact
segment checks and corner restrictions in legacy pixel coordinates. It adds an
extra one-display-pixel registration margin and rejects positions outside
supplied source chunks. Optional later polygon additions are omitted, so this
is a conservative subset of the existing reviewed collision. The four preserved
binary navigation files belong to another authored coordinate space and are
still not transplanted.

Use `res://scenes/maps/base508_walk_review.tscn` with `--pack=...`,
`--registration=...`, `--legacy-art-root=...` and optional
`--legacy-map=albino_01` (or albino_02). WASD moves a visible review actor.
`--walk-proof --capture=...` records movement and captures after 150 frames.
This scene does not register a live map, write saves, generate source NPC
instances, activate original portals or change `pack.can_enter`: M terrain
remains unknown and blocked. Portal marker clicks in the original inspection
scene use a 14-screen-pixel UI hitbox, explicitly not a gameplay trigger radius.
The display inverse round-trips source coordinates; half-open supplied-chunk
bounds are checked separately from unknown original territory boundaries.

`compare_base508_hypotheses.py` emits explicit candidate edge rules without
installing any rule. Under the PC bit0-set-blocked candidate, each source portal
has two outgoing cardinal edges (down/left or down/right); inverted bit0 yields
the opposite pair, while bit2-set-blocked isolates all four. Portal anchors do
not distinguish the first two candidates. Height remains unidentified. An
original M trace of one successful and one blocked step, with exact source
cell/direction and dynamic occupancy state, is needed to resolve this ambiguity.
Public primary PC format discussion/code also describes shared cell edges:
https://groups.google.com/g/l1j-en/c/a4_sHMzzVqM . Its S32 attribute offset agrees
structurally, but it predates M and is not used as M ground truth.


| Candidate | Degree 0 cells | Degree 4 cells | Four portal source observations | M status |
|---|---:|---:|---|---|
| bit0 set blocks an owned edge | 33221 | 5960 | two outgoing edges each | unverified |
| bit0 clear blocks an owned edge | 5960 | 32329 | opposite two edges each | unverified |
| bit2 set blocks an owned edge | 38400 | 2268 | no outgoing edge at each | unverified; portal-adjacency counterevidence |

All counts cover the 40,960 supplied cells, with missing neighbors closed. These
are hypotheses rather than a runtime passability count. The private code review
ZIP includes the certificate, machine-readable hypotheses and the exact old
index/two navigation manifests under `handoff/legacy-navigation-reference/`.
That minimal directory suffices for this scene's unchanged legacy collision
checks; new terrain still comes exclusively from the original S32/TI2 pack.

## Main-game integration handoff (opt-in only)

`base508_game_mode.gd`, `base508_game_field.gd` and `base508_game_renderer.gd`
implement the main game's existing PlayableField/NativePngField and FieldRenderer
interfaces. They keep player/monster physics and navigation in the unchanged
legacy pixel space and project the source artwork into that space. The field
exposes `source_to_world`, `world_to_source`, `actor_contract` and
`place_confirmed_source_actor`; projected runtime positions are explicitly not
original spawn records. Supplied chunk checks and exact legacy collision checks
apply before a confirmed actor is placed. Numeric confirmation 2 is rejected.
Default source NPC/monster populations are empty because no actual original
instance points were established. `--base508-legacy-review-population` explicitly
enables existing legacy review populations with an unverified-original-position
label. No original source population is inferred from a region rectangle.

`prepare_base508_world_patch.py` produces seven small world.gd hooks: lightweight
mode import; validated registration after data loading; field selection; renderer
selection; independent test save path; unconditional test-mode save refusal; and
unconditional test-mode load refusal. The patch is prepared and applies cleanly
to pinned main 0cab9b3. It is intentionally not applied to the shared world.gd
here, so parent integration can reconcile other workers' changes. An invalid
explicit test pack stops startup instead of silently opening a different map.

After applying the reviewed patch in the full game checkout, launch its normal
main scene with `--base508-source-test --base508-pack=<source pack>
--base508-registration=<certificate> --base508-legacy-reference=<minimal legacy
reference directory>` and optional `--base508-legacy-map=albino_02`. There is no
default-map replacement. Original Albino portals all have region destinations,
so this adapter supplies four source-coordinate markers and zero automatic
portal transitions. Source trigger and arrival selection remain unresolved.
The existing minimap shows the exact navigation geometry rather than a wrongly
aligned old PNG overview. Terrain height and source object depth/occlusion are
not established. Host field/API and opt-in mode tests pass; the full main-game
bootstrap remains a parent integration check after applying the patch.

## All-map pipeline and outstanding source acquisition

The scope is all 1,059 Land rows, 615 referenced AssetPaths and all 672 original
map directories, including 57 unreferenced directories. No historical deletion
list is applied. `build_base508_universe.py` joins the original tables, complete
structural inventories, ZIP central directory and CRC-checked local files. It
reports S32/SEG, known TI2 dependencies, PNG reference hashes, required DATs,
per-Land portal state, host connection and collision state separately. Eight
local PNG references exist; their base508 equivalence remains unverified.

The global source set contains 8,281 map members, 8,486 TI2 members and one legacy
TIL member. Only 446 source members currently exist locally; the exact deduplicated
request asks for the remaining 16,322 through the parent's shared DAT cache.
There are 123 unique Map/Tile DAT containers, totaling 661,612,071 compressed ZIP
bytes if none is already cached. No mass acquisition is performed by this worker.
Already extracted members do not imply that their containing DAT remains cached.

`batch_base508_maps.py` writes one job per AssetPath and keeps all Land contexts;
it never duplicates art per LandID. Existing Albino art is referenced directly,
not recomposed. Newly built packs contain a hashed shared-Land context table.
The loader can select another original LandID sharing the exact AssetPath while
retaining one geometry/art set and changing its portal/NPC context. A real
partial source fixture verifies Land0 and Land12156 share geometry without
conflating their identities. Unreferenced directories are retained in requests
and classified for raw preservation, without an invented LandID or automatic
playable registration.

`base508_tile_cache.py` is a shared, content-addressed SQLite derived cache for
parsed TI2 and RGBA frames. Keys include the original source SHA and decoder-code
SHA. It uses bounded in-memory LRU entries and non-executable JSON/raw pixels;
subsequent processes reuse exact decoded pixels. Composer and builder accept
`--tile-cache`, and batch jobs share one cache and a hard-linked verified source
tree. The cache reopen test matched the original decoder's pixels exactly.

Current readiness is 1/672 asset jobs; actual S32/TI2 renders remain 1, main-game
connections remain 0 until the prepared hooks are applied. Missing source files,
15 SEG chunks, the legacy TIL decoder, unreferenced asset-only render output and
canvases beyond the current 160-million-pixel composition bound are outstanding
work, not completed maps. Batch failures preserve their output and continue to
other jobs; no missing region is made walkable to improve completion counts.

## PR217 host integration checkpoint

The seven prepared World hooks were applied on top of the current collectible,
awakening and monster changes. No shared UI or collection file was replaced.
The explicit source-test flag selects the validated field/renderer during actual
Main startup; the ordinary startup path remains unchanged. Both ordinary save
load and writes return before normal save access in this mode, including after
leaving the field. This is an opt-in development entry, not an Android map pack
installer or a replacement of every default map.

The consumer re-downloaded the unchanged owner-only map ZIP (70,450,588 bytes,
SHA256 745c11c01c99a6c514f8b8f224a7588b4b2589ae1eff7433dcc06e90c3a41f50),
verified ZIP CRC and exercised Main, the real player and a clearly labelled
runtime Monster fixture. No original spawn point is invented. Map destinations
whose existing required packs are unavailable must preserve the current map;
exiting the test scene keeps the normal-save sentinel unchanged. The minimal
main-game test covers this guarded route, source rendering initialization and
ordinary-save refusal. It does not approve M terrain collision bits, portals,
Android rendering, or all-map visual equivalence.

Current actual source terrain renders: 1. Main-game opt-in source field connected:
1 (Albino Land48962 / AssetPath13474). Original geographic spawns: 0. All remaining
map acquisition/decoding counts above remain pending. The handoff's earlier
"main-game connections0" describes its pre-integration checkpoint.
