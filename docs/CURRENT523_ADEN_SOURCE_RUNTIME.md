# Current523 Aden originals and in-game review

Base main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`; feature PR232.
The current523 LineageM originals now have a hash-bound Main API and a real
Godot tile review screen available from the existing settings window. This is
a display integration with explicit hypotheses, not a playable M-equivalent
Aden map. Movement, collision, M world coordinates and regional travel remain
unverified.

## Open it from the game

1. Extract the separately supplied review resources.
2. Open **메뉴 → 설정 → 아덴 원문 검토**.
3. Choose the `aden523-raw` folder containing `aden523.json`, and the
   `aden523-tiles` folder containing `tiles523.json`.
4. Press **아덴 원문 보기**. Select a source from the dropdown; use WASD or drag
   for the inspection camera and the wheel to zoom. The object checkbox is a
   separate, explicitly hypothetical layer display.
5. Press **게임으로 복귀** to restore the existing game and settings screen.

The review suspends the current game, hides its presentation and blocks saves
and loads. Closing restores the original process modes, visibility, field,
renderer and source registry; it does not reposition the actor or migrate a
save. Only the two folder preferences are remembered in a separate settings
file. Invalid folders are reported in the settings panel, without replacing the
live map. The game-save schema and original delivery ledger are unchanged.

A separate review-only startup also works before the old map/data bootstrap:

```sh
godot --path . -- --aden523-review \
  --aden523-pack=/private/aden523-raw \
  --aden523-tiles=/private/aden523-tiles \
  --aden523-member=Map/Aden/80138007.s32
```

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
- Committed resource integrity:723atlases,41442frames,233420026bytes. No source
  original, generated atlas, screenshot or resource ZIP is added by this PR.

The raw manifest SHA256 is
`2ae38fe09eba75653e4db476b70a9e3168cba18d8051cf302b177a1a7634e90a`;
the tile manifest SHA256 is
`bcef2835c28acf1ec61af8ba9ef29753b693952e695beedcb1bce4f4c9ec3989`.
The separate local resource ZIP is399316785bytes,6412entries, full CRC pass,
SHA256`f926e1513c552b60ed5deb6c9b1fddf18a6e59ab4e916575b9dc88206b05f952`.
Its Library upload failed at tools/list HTTP401 before upload preparation.
Durable delivery is not established; the generated packs remain private local
outputs. The existing Library original archives remain reconstruction inputs.

The historical source-dir ledger still requires absent `a1.zip`; that is not a
pass for the old six-archive ledger. The actual supplied523 ZIPs passed separate
SHA256 and full CRC checks. Extra coordinate evidence also hit HTTP401 on its
transfer route; no bypass or native-coordinate assertion follows from it.
Additional989SP2 originals were materialized and CRC-verified, but not activated
by this tile review; their RLE/alpha/action semantics remain separate work.

This follow-up commit uses `[skip ci]` at the user's request. No manual remote
CI is launched or retried. Earlier CI success belongs to bb9a6fa4; it is not a
remote result for the later display/UI commit. Local direct validation above
remains separate from skipped remote CI.
