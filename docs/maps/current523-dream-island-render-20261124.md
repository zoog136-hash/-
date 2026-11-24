# Dream Island: render verified original background tiles

Before this change, the background lookup stopped at metadata. This patch adds
a guarded render path. No replacement art is created or committed.

- Logical Land 22801 with exact asset path `303/` only. The 30 retained S32
  members selected by the 523 manifest were reread and SHA-256 checked.
  Exactly 53,196 floor halves of Tile47 frame 199 and 53,196 of frame 202
  were found with original TI2 flag 0x08. All other floor refs, covers and
  objects keep their draw order and original pixels.
- Both original 523 files were recovered from the verified Image13.dat and
  matched the independently recorded PNG SHA-256 and dimensions. Loading
  needs both exact files through the installed 523 image pack, or a private
  `user://source523_map_bg/` directory holding the same two original files.
  A missing or changed file keeps the existing terrain output; no generated
  fallback image. PCK and Git contain code, not the private originals.
- Only admitted floor rectangles get a sky/cloud draw below the existing
  terrain canvas; the placeholder ref is then skipped in the terrain pass.
  Both are baked in the existing block viewport; no per-frame map traversal,
  network fetch, collision or save change.
- The shader uses the verified five-bit screen formula, a 384 px stagger and
  fixed relative phase. Terrain-space anchoring, the bounded floor mask, and
  frozen phase do **not** establish original camera, clipping or cloud-motion
  parity. No newly invented time rate.

## Verification boundary

The default headless test verifies classification and no-pack behavior.
With `TWILIGHT_DREAM_BACKGROUND_ORIGINALS` pointing at the private sample,
it also verifies the exact two file hashes and their use in one real S32
chunk. A software EGL cross-check used the same shader fragment math and the
two exact PNGs: 6,144 samples at a repeat boundary, zero channel difference
against independent integer composition. This verifies the shader math, not
Godot or Android display. The optional GPU test
(`TWILIGHT_DREAM_BACKGROUND_VISUAL`) exercises the production block viewport
with the real assets and original Tile47 atlas; this executor cannot create
the display socket, so that Godot test and a full in-game capture remain
unverified. Do not report screenshot parity or device deployment.

On the consolidated branch, the real release-selected metadata and PNG members
passed through the ordinary installed image resolver without a private override.
For one original 80007ffd.s32 floor block the production projection, binning and
block bake admitted 842 flagged halves as 44 contiguous horizontal draws with
identical covered spans (13/13 combined checks). The headless block result is
not a framebuffer or a device screenshot. See the [consolidated audit](../performance/astra-unified-20261124.md).
