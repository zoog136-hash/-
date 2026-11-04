# Current523 Aden originals, installation and experimental play

> The whole-map continuation and generic pack/UI/runtime scope are recorded in
> [CURRENT523_MAP_SOURCE_RUNTIME.md](CURRENT523_MAP_SOURCE_RUNTIME.md).
> The Aden-only versions and evidence below keep their original scope.


Base main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`; feature PR232.
The current523 LineageM originals have a hash-bound Main API, a resource
installer and a Godot tile review screen in the existing settings window.
The source-field mode now loads the supplied S32 terrain and attributes into
an independent movement field. Its own configurable interpretation replaces
the older TWILIGHT navigation during that mode. The earlier display over old
TWILIGHT navigation remains a separate compatibility experiment. Native M
collision, actor alignment and portal behavior remain unverified; this is not
complete M mainland parity.
M engine/APK/XAPK exploration remains stopped.

## Open it from the game

1. Obtain the separately supplied review resource ZIP. The private Drive handoff
   contains five ordered parts, a SHA256 receipt, and
   `reassemble_current523_review.py`. Download them into one folder and run
   `python3 reassemble_current523_review.py`; it verifies every part and the
   complete ZIP, and refuses to overwrite an existing output.
2. Open **메뉴 → 설정 → 아덴 원문 검토**.
3. Press **원본 ZIP 설치** and select the reconstructed ZIP. After verification,
   installation activates the two resource paths. Alternatively extract it
   yourself and choose the `aden523-raw` folder containing `aden523.json`, and
   the `aden523-tiles` folder containing `tiles523.json`.
4. Press **아덴 원문 보기**. Select a source from the dropdown; use WASD or drag
   for the inspection camera and the wheel to zoom. The object checkbox is a
   separate, explicitly hypothetical layer display.
5. Press **게임으로 복귀** to restore the existing game and settings screen.

The review suspends the current game, hides its presentation and blocks saves
and loads. Closing restores the original process modes, visibility, field,
renderer and source registry; it does not reposition the actor or migrate a
save. Only the two folder preferences are remembered in a separate settings
file, together with the previous selection. Invalid folders are reported in the settings panel, without replacing the
live map. The game-save schema and original delivery ledger are unchanged.

The dedicated current523 installer accepts only the fixed399316785-byte ZIP
and its complete SHA256, before opening it. It checks both pinned manifests,
the exact6412-member inventory, and every payload size/hash. Extraction goes
into a unique private staging directory; every saved file is read and hashed
again before one directory rename publishes the version. Existing versions are
never overwritten or removed; selecting the same version verifies the existing
directory and all its files before reusing it. Unexpected files, links, changed
or incomplete versions are rejected. Free space is checked before extraction.

Hashing, extraction, verification and staging cleanup run in a background file
worker, independent of scene rendering FPS. The main thread exchanges progress,
cancellation and results through a mutex; only the main thread emits UI signals
and updates scene state. Closing joins the worker after cancellation and cleanup.
This follows Godot's [thread handoff guidance](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html)
and [scene-tree thread restrictions](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).
**설치 취소**, closing Settings, or freeing the panel cancels its work and cleans
only that installer's staging files. A cleanup failure reports the retained
staging path. **이전 팩 사용** validates the previous manifests and restores the
prior pair of resource paths. This is selection rollback; it does not migrate
game saves or delete either resource version. Paths publish together through a
separate atomic preferences write. A preferences failure leaves the installed
files available and reports that activation failed. The old base508 installer
and its4096-entry/schema restrictions are unchanged.

A separate review-only startup also works before the old map/data bootstrap:

```sh
godot --path . -- --aden523-review \
  --aden523-pack=/private/aden523-raw \
  --aden523-tiles=/private/aden523-tiles \
  --aden523-member=Map/Aden/80138007.s32
```

## Source-based gameplay

Select **원문 S32 속성 기반 · 자체 통행** in the existing settings panel. The
raw and tile folders come from the installed private pack. Optional entry X/Y
values identify source cells; the runtime places the actor at the explicitly
chosen display cell center. A blocked or missing entry is rejected without
nearest-cell replacement. Without an entry override, it uses the separately
saved source cursor or the current actor's source coordinates. This projection
and actor foot point remain application conventions rather than native M facts.

`current523_aden_source_field.gd` loads every676 canonical filename placement
and retains the ninth-character source as unplaced. Bounds derive from the
source union `(32256,31936,2048,2112)`. It reads two original u16 attribute words
and two u32 floor references for each cell. The default own interpretation
accepts exact words `[0,4,8,12,32]` in both halves and rejects either floor
sentinel `0xffffffff`. Zero is explicitly mapped by this policy; absent chunks,
invalid bytes, `0xffff`, other words and unplaced sources never become zero
floor. The allowlist is editable in Settings and stored separately from raw
inputs. The lower-level API also supports bounded masks. No source value is
rewritten and no M safety/PVP meaning is assigned.

The choice follows original-byte inventory, prior reports and a fresh primary
source check of the public [L1MapViewer editing code](https://github.com/tony1223/L1MapViewer/blob/main/MapForm.cs),
which uses bit0 for its own passability editor. That is PC tool guidance, not M
engine evidence. Existing M-byte analysis found78612 nonreciprocal pairs in
the viewer's directional candidate. This implementation therefore uses an
explicit conservative exact-word policy with symmetric endpoint checks and
both side cells required for diagonals. It reuses DDA/A* algorithms through
these source-field predicates, without loading A3 grids, old geography, doors,
NPC positions or monster placements. A per-field48-chunk LRU bounds raw reads.

On entry, Main replaces its field/physics/minimap and renderer with the S32
field. The prior field is retained only for safe return and save compatibility.
Its renderer and collision streaming are disabled; prior actors/boss HUD are
hidden and paused, and cannot be selected or damaged as source-field actors.
Selections, gestures, charge routes and pending attacks are cleared. This PR
does not invent M spawns or reimplement PR230's population contract. The M
Gate/Obstacle/InteractionCell namespaces and typed occupancy states remain
separate and unexecuted; excluded siege/arena features are not introduced.

Normal progress saves through the existing writer with its original spatial
identity. Only the source cursor goes into the separate atomic play config.
A committed inventory save is never reported failed merely because the cursor
write fails, avoiding caller refunds of already committed transactions.
Source-session restoration suppresses host encounter admission until the own
field is ready; original boss state stays preserved. Returning explicitly
restores the original field, body, camera, actor position and population.
Unsupported return-scroll/ground-drop operations are held with visible reasons
and preserve inventory. These limits must not be described as complete M
combat or floor-item integration.

## Guarded source portals

Download [TWILIGHT_current523_Aden_source_portals_v1.json](https://drive.google.com/file/d/1r3NHS_NeV3iYeT80qn-6haAJA9KM5Sx5/view)
from the application folder and enter its local path in the source portal field.
It is392459bytes, SHA256
`350176c5a55d349ec1b4e0b861b29b48499c9b5c32471c89b3ef86d03ea19767`.
The runtime checks that fixed digest, the three native table identities and
the raw source inventory. The resource was uploaded to the existing owner-only
Drive folder, downloaded through normal authentication and rehashed successfully.

The private compiler preserves all93 native Land4 declarations and89 named raw
records, including exact labels/offsets/bytes. There are31 Aden-internal exact
source matches and30 matching source/destination candidates. The default own
cell policy accepts both endpoints of only **Portal335 and Portal343**;30 is
not an active-portal count. Portal350's mismatch, other-Land inputs, rectangles
without an exact landing and unmatched records remain blocked. Use the explicit
portal button while standing in its exact declared source cell. This supplies
no inferred trigger radius, reverse link, fee or borrowed LandTeleport rule.
The caller checks actor state, cooldown, both actual endpoint members/hashes,
configured clear flags and arrival rendering before completing movement.

PR230's pinned contract documentation at `a1fec5e2` was read without merging
its branch. The controller exposes copied `portal_evidence()` and
`portal_context(id)` data. Main exposes `current523_aden_source_portals()`,
`current523_aden_source_portal_context(id)` and the explicit
`use_current523_aden_source_portal(id)` request. Evidence rows contain exact
`portal`, `target_territory`, `target_land`, `source_position`, optional exact
`landing_position`, member/hash `source_support`/`target_support`,
`activation_candidate`, raw record IDs and blockers. Runtime authorization
requires the actual source field; the resource never pre-authorizes movement.
It does not duplicate PR230's
spawn/condition catalog, host portal navigation or original-data UI.

The newly supplied parent handoff
`M523_PR232_PR230_map_source_crosslinks_20261104.zip` was formally downloaded
from private Drive:389919bytes, SHA256
`7fa773dfa1e040ba6afc9eed917b90f1a6bbca4cd64fbef44b0b85fe3697c71f`,
with ZIP CRC pass. `HANDOFF_KO.txt` and the row-wise evidence preserve the
additional50 global target4/Land4 relations, of which31 are Aden-internal.
The other19 have no corresponding full source member in this consumer's
677-Aden-only input. Their metadata does not substitute for missing fields.
The reproducible parent-crosslink verifier checked all65 ZIP entries by CRC,
all64 manifest payloads, all50 row relations, all113 linked current M rows and
the independent review. It reread31 Aden records at exact offsets in14
SHA-matched source files, reproducing30 candidates and Portal350's mismatch.
The supplied current31/retained50819 provenance distinction and35 numeric
AssetPath counterexamples prohibit a global raw-targetword=LandID conversion.

## Earlier compatibility experiment

In **메뉴 → 설정 → 아덴 원문 검토**, explicitly select
**기존 TWILIGHT 아덴 통행 · 자체 설정** and press **실험 플레이 시작**.
The default is disabled with no navigation profile selected. The persistent
notice names the local navigation assumption and provides **기존 지도로 복귀**.
Each visual correction axis is configurable from -48 to48pixels. It changes
tile presentation without changing player coordinates or collision. Failed
corrections preserve the previous settings bytes and return a visible reason.

The only accepted navigation profile is `TWILIGHT_ADEN_NAVIGATION_V1`, pinned
to the existing Aden source4 grid SHA256
`30229ce7fd95656519ff73a47515ac2ac277983022ebc262b084c134a2b80d53`,
layout2026102904, origin(32448,32064), dimensions1856×1536 and the existing
(24,-12)/(24,12) display basis. The renderer calls the existing coordinate and
field APIs. Its initial display convention has the existing -12pixel foot
difference and a configurable correction; no native M foot origin is asserted.
M raw attributes are never used as a passability mask. Original bytes, M
portal declarations, occupancy bonuses and gate fields remain uninterpreted by
this mode. Siege mechanics are not introduced.

676 candidate filename positions intersect602 existing artwork chunks in596
chunks. This is an artwork join, not596 play-tested regions. The ninth-character
filename remains unplaced. Candidate M floor/cover/object layers are drawn
below existing actors; native foreground occlusion and alpha semantics remain
unverified. Original pixels, including black and white, are preserved.
Existing field, physics, player, combat, actors and travel ownership stay with
Main. Original/source declarations and existing reports take precedence over
estimates; existing tested TWILIGHT APIs supply the explicitly labelled local
navigation choice, rather than an invented M collision rule.

The controller retains the exact prior renderer and restores it on explicit
return, invalid scope, missing/corrupt input or display-budget failure. Ordinary
map transitions close this display before changing the field. Review, resource
installation and path replacement are blocked while experimental play is
active. Its atomic `user://current523_aden_play.cfg` is separate from game saves;
an enabled choice can be restored after normal reconnect. Explicit return
disables it. Transient failure retains the requested choice but falls back to
the existing screen. It does not migrate saves or grant items/currency.

## Source and display boundaries

The raw API accepts exactly677 Land4/Aden sources. Canonical member/size/SHA256:
`e236f89849bcc6fc618feb13046c077adff59f909ad376b408c9b24fafc3288c`.
The changed523 `800a8000.s32` is210523bytes, SHA256
`ab3b89eb4a9be8b2b5448c60bcf4c7ac6d4164ada21d85f88ffc7f566e9b2b96`.
Every consumed source and seven contiguous raw sections are hashed and scanned
in Godot. Raw32-bit references, opaque tails and labels stay byte-exact; no
external viewer JSON is used to save or repair originals.

The display registers676 eight-hex filenames under the named filename-origin
hypothesis, and retains `800f7ff3e.s32` as an unplaced, single-source local view.
No suffix is removed. The half-storage projection is an explicitly named viewer
hypothesis, checked for its own cross-chunk continuity but not approved as M
engine coordinates. Raw effect u16 values never determine chunk dimensions.
No village, portal destination or passability is inferred from these formulas.

The user-authorized private Drive coordinate packet was independently consumed
and SHA256-verified (`b406f8265b4710d3d75b937f716eab6aece16f3bbfbd5f3e8308d70174530f91`).
Its native M Land/Portal/Territories tables declare93 Land4 portals and4223
Land4 territory rows. Consumer validation rebuilt root-pair joins before
coordinates, checked14 Aden tail records at their original byte offsets in9
hash-matched M files, and reproduced10 exact Portal.SourceX/Y matches plus4
counterexamples. Portal332's matching source does not make its packed target
correct: the candidate target differs from the declared territory by3 cells.
These partial matches do not establish M projection, actor feet, odd-x rules
or collision. The source-field adapter's separate native-row/raw-endpoint and
actual-field checks above govern explicit own movement; no original record
is repaired.

Subsequent parent analysis distinguishes duplicated `sanga in 1/2` records,
including the copy in `80137ff6.s32` matching Portal341/342. It also reports
50 row-wise target4/Land4 matches,42 destination-region matches and30/31 fully
matched Aden-internal records. Portal350 at `80157ff7.s32@154102` has matching
source(34117,32254), but raw target candidate(34278,32224) differs from declared
Territory173424(34275,32222). These additional findings were supplied by the
parent and subsequently independently checked against the newly received
handoff and actual Aden sources by `verify_current523_parent_crosslinks.py`.
They do not authorize a
global target-word interpretation or replacement of declared destinations.

Current original TI2 selection:2866files,97365118bytes. Source inventory:
`b80c592b894b84a265e6f72739af77a78b96b26d6e3ee7ca0a441e0a41c79fab`.
Private coverage atlas RGBA inventory:
`e84e7a7402c500f100dfe916eea4c7e52af18ba0c24a2e290a8e1dce11be0b2f`.
Runtime verifies the original compressed TI2 hash, PNG hash, bounded384×384
header and decoded RGBA hash. Stored pixels use alpha255; unstored pixels use
alpha0. Black and palette index0 are preserved. Viewer alpha flags, SPR effects,
opacity records and actor foreground occlusion are not applied. Geometry24×24,
RGB565 expansion, projection and layer composition remain display hypotheses.

`0xffffffff` stays an uninterpreted sentinel/empty candidate, separately counted
when present; it never becomes a request for Tile65535 or Tile16777215. Other
unresolved references are reported, not replaced. Runtime bounds:48cached raw
chunks,32persistent atlases,256visible atlases,65536draw commands. Any view
exceeding its budget reports the excluded count; this is not complete mainland
rendering or a target-device FPS guarantee.

## Build separate resource packs

Use the current M evidence archives, not exported viewer JSON or old508 files.
Map sources, source summary and Land4 declaration are required:

```sh
python3 tools/map_restore/build_current523_aden_pack.py \
  --source-dir /private/aden-evidence/selected_originals \
  --summary /private/aden-evidence/results/all_Aden_map_structure_summary.json \
  --land-declaration /private/m-only/results/M_only_Land4_assetpath_and_explicit_zone_declarations.json \
  --output /private/aden523-raw
```

The tile builder uses standard libbrotlidec, NumPy2.3.5 and Pillow12.3.0. The
optional reference archive streams the independently recorded733696frames:

```sh
python3 tools/map_restore/current523_tile_review.py \
  --source-dir /private/aden-tile-evidence/selected_originals \
  --source-records /private/aden-evidence/results/Aden_TI2_source_records.json \
  --reference-archive /private/TWILIGHT_aden_tiles_original_evidence.zip \
  --output /private/aden523-tiles
```

Both builders publish an external private directory atomically without replacing
an existing output or writing originals into Git. Source byte/CRC/hash, exact
raw reserialization and output hashes are checked. Tile Brotli must finish with
no trailing input; decoded hashes and raw palette/flag/span/index metadata are
bound separately from the coverage atlas. Every stored pixel must fit without
clipping or duplicate writes.

## Verification and delivery

Latest source-field follow-up, using the physically downloaded and newly
installed Drive pack:

- Godot real-source field:4819checks passed across all676 placed chunks, with
  whole-file/section digests and three independently read cell pairs per chunk.
  This proves source loading and the own policy, not native movement semantics.
- Pinned portal contract plus actual source field:150checks passed; only335/343
  accepted under the default own policy. Python portal/crosslink/staging/transfer
  guards:28tests passed. The new handoff's all50 relations and113 native rows
  independently match, with31 actual Aden records reread and19 external source
  records left metadata-only.
- Actual Main source entry/movement/Portal335/save:35checks,78.50s. New-process
  source cursor/progression/boss/save preservation:9checks,78.24s. Multiple
  source regions/seams/Portal343/boundary/failure return:38checks,117.24s. All
  retain the original180s per-process limit. Tested entry sources were
  (33341,33168) in`80088006`,(34002,32326) in`80137ff9`,(33471,32769) in
  `800a8000`, and(32319,33595) in`7ff8800c`. Actual seam motion crossed
  `800a8000→800b8000` and`7ff8800c→7ff9800c`. Portal335 arrived at
  (33365,33153);343 at(34006,32302). Failed350/other-Land/repeat use preserved
  position and protected state. Real return-scroll use and drop attempts
  preserved an existing QA stack of2items. Budget failure restored the exact
  old field/position with previous preferences unchanged.
- Initial source entry caught an always-busy dictionary/string conversion in
  the portal caller; the corrected caller passed the actual portal button.
  Initial reconnect equality failed with unchanged save SHA. The follow-up
  suppresses host encounter admission during own-source restore and preserves
  full JSON precision in QA snapshots; final complete equality passes. Failed
  logs remain separate from passing evidence.
- Final default-off direct core:35/20/17/12/48/39/102/8/41/42 checks plus
  identical/deferred-save regressions passed. Main took99.48s within180s;
  synthetic source/portal guards remain explicitly separate from real sources.
  Resource integrity remains723atlases/41442frames/233420026bytes.

The actual player physics, source field, UI and portal adapters ran under
Godot4.7.2/OpenGL/Xvfb/llvmpipe. Population/combat were controlled in the harness;
there is no claim of every cell being play-tested, M NPC placement, native M
collision/alpha/actor feet, full combat, floor-drop integration or other Lands.
All native declarations and original bytes stay preserved; excluded
engine/APK/arena/siege investigations remain stopped.

Run direct guards with Godot4.7.2 and an isolated user profile:

```sh
godot --headless --path . --script res://tests/current523_aden_install_test.gd
godot --headless --path . --script res://tests/current523_aden_preferences_test.gd
```

The installer guard optionally accepts `-- --archive=/private/review-resources.zip`
to exercise real-source hashing, partial extraction cancellation, panel/node
exit, invalid same-size SHA rejection, and preservation of an incomplete prior
version. This focused guard deliberately never installs the full pack. The
separate actual Main test performs installation, cancellation from Settings,
selection rollback, original-tile rendering and return with real save bytes:

```sh
godot --path . --script res://tests/current523_aden_review_ui_test.gd -- \
  --aden523-pack=/private/aden523-raw \
  --aden523-tiles=/private/aden523-tiles \
  --aden523-install-zip=/private/review-resources.zip
```

The ordinary Main route also requires its existing source-map pack. This is a
baseline game dependency, distinct from the optional current523 source review.

- Raw sources: Python17real-source tests and all677 exact roundtrips; final
  guard suite19tests with18passed and the separate real rerun skipped.
- TI2: all2866 strict streams and raw roundtrips;733696 raw records and coverage
  frames matched the independent ledger;130913353 stored pixels retained.
  Fourteen malformed-input/PNG/reference tests passed.
- Godot4.7.2 raw sources:1393checks passed; the earlier Main raw API16checks and
  source-map/save35checks passed separately from display validation. Final
  sequential core checks passed35/20/17plus identical/deferred-save regressions
  without resource/parser/runtime errors. The Main check took87.04s within its
  original180s limit; an earlier concurrent run timed out and is retained as
  failed diagnostic evidence, not counted as a pass.
- Actual Main OpenGL/Xvfb/llvmpipe:39checks passed across three original source
  views, wheel/drag, bounded caches, save protection and the unplaced filename.
  Draw counts20621/31523/16270; tested views had zero unresolved references and
  zero budget exclusions. These are TWILIGHT renders, not original M screenshots.
- The existing settings/folder-picker/review/return path passed29checks with
  unchanged save bytes, map, actor position and settings visibility. Errors and
  the corrected-folder result are displayed in the actual UI. Screenshots stay
  in private session evidence.
  The UI stage restores one additional existing portrait from exact HEAD bytes
  because the small core stage intentionally deferred that resource.
- The longer resource installation path exposed additional current source-spawn
  actors appended after the frozen gameplay roster. The core staging selection
  now includes their exact grid/layout-pinned source rows and portrait/animation
  dependencies. The validation stage restored50 existing committed files,
  8968851bytes, without changing production art or spawn behavior. Eight staging
  regression tests and five resource reconstruction guards pass.
- Installer guards:48 fast checks and73 real-archive partial/cancellation checks
  passed. The real guard writes at most2 files before cancellation, checks exit
  join/cleanup, same-size wrong-SHA rejection, intermediate and dangling links,
  reentrant lifecycle callbacks, and preservation of a damaged prior version.
  These are distinct from the complete installation test. Atomic resource path
  preferences passed12 isolated checks, including rollback failure preservation.
- Actual Main installation UI:45 checks passed in153.27s within the unchanged
  180s test limit. It installed all6412files/452418162bytes, verified saved bytes,
  activated resource paths, exercised cancel and Settings-hide cancellation,
  restored the previous pack and returned to the installed selection, opened
  the changed523 source, then returned to the same live map/actor/save bytes.
  The installed view drew31523commands with zero unresolved references or budget
  exclusions. Phase timings:archive SHA2.90s, extraction69.41s, disk rehash5.30s.
  Earlier frame-bound16-step,256-step and initial threaded implementations each
  exceeded180s; their failure logs and owned-stage cleanup receipts are retained.
  The final implementation removes repeated parent-prefix link walks while
  retaining the full stage-ancestor check and a full target check immediately
  before opening each file. Guards and final disk hashing were not relaxed.
- Final direct core checks passed35/20/17/12/48 plus identical-payload and
  deferred-save regressions, without engine/resource/parser errors; actual Main
  took61.18s within its original180s limit. A separate installed-store check
  passed10checks: all6412 existing files were verified and reused with zero
  payload writes, a same-sized modified README was rejected and preserved, and
  saves/preferences stayed byte-identical. That isolated test restored only
  its own README to the original digest afterward.
- Committed resource integrity:723atlases,41442frames,233420026bytes. No source
  original, generated atlas, screenshot or resource ZIP is added by this PR.
- Experimental play guards:27 option checks,102 renderer checks and8 controller
  transaction checks passed. The renderer guard uses synthetic inputs and is
  not native M evidence. Default-off direct core checks passed35/20/17/12/48/
  27/102 plus identical/deferred-save regressions; Main took58.53s. The8-check
  controller guard was added and run separately after the final correction fix.
- Actual Main OpenGL/Xvfb/llvmpipe play:35 entry checks passed in75.65s,
  9 new-process reconnect checks in60.86s, and11 failure/return checks in68.44s,
  all within the unchanged180s per-process limit. In the changed `800a8000.s32`
  Halloween plaza view, player physics moved from(41256,-2184) to
  (41346.58984375,-2229.29321289062). A nearby configured blocked cell(982,741)
  refused actual motion; an outside-field destination was rejected with the
  actor stationary. Visual correction, exact renderer return, normal save,
  reconnect and unchanged inventory/currency/collection/source bytes passed.
  The boundary check rejects an outside destination; it is not a traversal of
  every mainland edge. The final failure test exercises the correction
  transaction fix with an oversized view, unchanged preferences and safe return.
  Population/combat processing was paused in this focused harness, so combat
  and every region/portal were not covered. Screenshots remain local.

The raw manifest SHA256 is
`2ae38fe09eba75653e4db476b70a9e3168cba18d8051cf302b177a1a7634e90a`;
the tile manifest SHA256 is
`bcef2835c28acf1ec61af8ba9ef29753b693952e695beedcb1bce4f4c9ec3989`.
The separate local resource ZIP is399316785bytes,6412entries, full CRC pass,
SHA256`f926e1513c552b60ed5deb6c9b1fddf18a6e59ab4e916575b9dc88206b05f952`.
The Library upload failed at tools/list HTTP401 before upload preparation and
was not bypassed. Following the user's explicit private Drive instruction, the
unchanged ZIP was uploaded as five sub100MiB parts into the private handoff
folder. All five were fetched through normal Drive authentication and their
download streams rehashed; concatenation reproduces the complete ZIP hash and
size above. Permission metadata showed owner-only access for every part.
The handoff also includes a reconstruction script, part/hash receipt and Korean
instructions. This establishes delivery of this specific private review pack;
it does not change the historical all-originals delivery ledger or assert
native M gameplay. The existing Library originals remain reconstruction inputs.

The existing private project folder now separates
[PR232_01_실제적용팩_523](https://drive.google.com/drive/folders/13CrR_W4xStDNSW0KZ9Z91OgGkSX7-zmO)
from
[PR232_02_원본보존_523](https://drive.google.com/drive/folders/1SFucZ3Lt2OxZUTv8K-0MDIP6Rsz7tHjk).
The application folder contains the five parts of the399316785-byte ZIP above,
the reconstruction script and resource handoff instructions. Drive storage
does not automatically activate a pack. After reconstruction, select the ZIP
in Settings. The installer uses
`user://current523_aden_resources/523-<full-ZIP-SHA256>/aden523-raw` and
`aden523-tiles`; the independent live-play test used byte-identical generated
private pack folders through `--aden523-pack` and `--aden523-tiles`.

Original-only backups are separate and cannot be selected as runtime packs:

| Backup v1/current523 | Bytes | SHA256 | Verified private Drive file |
| --- | ---: | --- | --- |
| `TWILIGHT_current523_Aden_S32_ORIGINALS_BACKUP_v1_20261104.zip` | 31385092 | `fde68ad6caa92ede3eeb1c4dd8cca39b304abae310ac7ef535ba17f082e5007b` | [S32](https://drive.google.com/file/d/1byeN61WZskhpdzrcASK15ol4xSD94isv/view) |
| `TWILIGHT_current523_Aden_TI2_ORIGINALS_BACKUP_v1_20261104.zip` | 97836926 | `cf94af7173e7b1d915d9960c61502d2b7f6b17f7c3295004302acd590e7bd28a` | [TI2](https://drive.google.com/file/d/1EOvXo3DBfN9HkxWnWkkjf-OO6sQIJkby/view) |

Both backups were freshly downloaded through normal authenticated Drive access
into a new consumer folder. Complete SHA256, ZIP CRC and all3543 original member
hashes passed; owner-only permission metadata was verified. For the application
pack, authenticated part streams and concatenated SHA passed, while full ZIP
CRC and fresh user-folder installation/load initially passed using the same-SHA
local ZIP. The later direct chain is now complete: all five parts were formally
downloaded again for this explicit request, physically reassembled in a new
consumer folder, checked by individual/full SHA and ZIP CRC, installed into a
new user folder and loaded through actual Main. All45 UI checks passed in
154.54s with6412 written/rehash-verified payloads and31523 rendered commands.
Source gameplay tests consume those newly installed folders, rather than the
earlier generated pack folders. The task-owned earlier installation and an
identical generated ZIP duplicate were replaced to fit available disk; original
source inputs, saves, downloaded ZIP, backup packs and code history remain.

The historical source-dir ledger still requires absent `a1.zip`; that is not a
pass for the old six-archive ledger. The actual supplied523 ZIPs passed separate
SHA256 and full CRC checks. The coordinate packet's old transfer route also
hit HTTP401; the later copy was explicitly supplied by the user through private
Drive and consumed with normal Drive authentication.
Additional989SP2 originals were materialized and CRC-verified, but not activated
by this tile review; their RLE/alpha/action semantics remain separate work.

This follow-up commit uses `[skip ci]` at the user's request. No manual remote
CI is launched or retried. Earlier CI success belongs to bb9a6fa4; it is not a
remote result for the later display/UI commit. Local direct validation above
remains separate from skipped remote CI.
