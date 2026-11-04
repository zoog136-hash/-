# Current523 Aden originals, installation and experimental play

Base main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`; feature PR232.
The current523 LineageM originals have a hash-bound Main API, a resource
installer and a Godot tile review screen in the existing settings window.
An optional experimental mode also displays these tiles while the existing
TWILIGHT Aden field runs player movement and collision. Main entry, actual
player motion, blocked-cell rejection, boundary rejection, return, normal save
and a new-process reconnect were exercised. Native M collision, actor alignment
and portal behavior remain unverified; this is not complete M mainland parity.
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

## Optional local gameplay

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
These partial matches do not establish M projection, actor feet, odd-x rules,
collision or executable travel. No portal from this evidence is activated as
an inferred movement rule, and no original record is repaired.

Subsequent parent analysis distinguishes duplicated `sanga in 1/2` records,
including the copy in `80137ff6.s32` matching Portal341/342. It also reports
50 row-wise target4/Land4 matches,42 destination-region matches and30/31 fully
matched Aden-internal records. Portal350 at `80157ff7.s32@154102` has matching
source(34117,32254), but raw target candidate(34278,32224) differs from declared
Territory173424(34275,32222). These additional findings were supplied by the
parent, not independently rerun by this consumer. They do not authorize a
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
CRC and fresh user-folder installation/load passed using the same-SHA local
ZIP. Physically reconstructing a downloaded Drive ZIP and installing that
newly downloaded file as one direct chain has **not** been performed. These
separate checks must not be described as that missing end-to-end chain.

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
