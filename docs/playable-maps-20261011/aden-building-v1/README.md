# Aden stone cottage — one bounded PR84 unit

Resumed from the observed remote PR84 HEAD `35578da7e8a9a7ea3ea31c1bf65f471f85c39a9a`.
The accessible previous local checkout was clean at `85ad235265a4499902123dab2303d80833573179`;
both commits have tree `24a594d40fbcff051f19401f9e838e76f8e799b6`.
Recent commits, courtyard renderer code, two actual Godot logs, four screenshot
SHA-256 values and preserved gameplay hashes agree: courtyard work was completed.
The older CHECKPOINT text was stale. No completed paving work was repeated.

## Change

Only the existing north-village house at `(1630, 3610)` now uses an original
transparent stone-cottage PNG: limestone walls, slate roof, stone chimney and
amber-lit windows. The other three Aden houses keep their existing art.
The renderer retains the original position, scale, sorting, opacity behavior and
collision data. The PNG is loaded only for Aden and reused when chunks return.
No ground shader, map layout, collision, NPC, portal or gameplay file changed.

New asset: `assets/maps/aden/stone_cottage_v1.png`, 1254 × 1254 RGBA,
2,044,387 bytes. SHA and complete imagegen prompt are recorded in
`assets/maps/aden/STONE_COTTAGE_SOURCES.md` and `validation-summary.json`.
The generated image is newly authored; the earlier prepared variant was not
located in the checked paths. Previous checkout and generated files are preserved.
This does not claim recovery of every unsaved file from the previous Work.

## Verification

- Actual Godot 4.7.2 Linux Mesa/llvmpipe OpenGL, Main scene: **40 checks, 0 failures**.
  Includes one-of-four replacement, classic/default appearance, actor roof fading,
  physical building collision, navigation around the footprint, chunk unload/reload,
  map return, click movement, river blocking, NPC shop, minimap, isolated save/load,
  Oman portal/return and bounded streaming.
- Project editor import and isolated game boot: PASS, no script errors.
- Existing UI fidelity regression: **75 assertions PASS**.
- Required resource integrity: **723 existing sheets PASS**.
- Nine gameplay/map/ground/atlas files match the remote resume commit byte-for-byte.
- All included PNG screenshots are unedited Godot viewport captures.
  Compare `before/01-stone-cottage.png` with `after/01-stone-cottage.png`.
  Camera: actor `(1980,3540)`, local camera offset `(-260,-150)` in both.
- Initial before-capture script had an accidental malformed first line; the failed
  log is retained as `building-before-gl.txt`. Corrected baseline and final runs pass.

The entire unrelated game test suite was not rerun. Windows/Android device checks
remain unperformed. This is one authored building improvement, not original-client
restoration or a claim of Lineage M visual parity. Main is not merged.

## Reproduce

Import the project with Godot 4.7.2, then run with an isolated user data directory
and a real OpenGL display:

```bash
godot --headless --path . --editor --quit
python3 tools/run_visual_capture.py --godot /path/to/godot --root . \
  --script res://tests/aden_building_test.gd --data /tmp/aden-building-check \
  --log /tmp/aden-building-check.log
```

On a headless host supply the existing runner's `--xvfb`, `--xlib` and `--fonts`
arguments. The new test skips explicitly on a headless rendering backend.
To reproduce the baseline, use the parent commit's renderer and run the capture
script with `ADEN_BUILDING_PHASE=before`; never reset an existing working checkout.

Stop after this unit is committed and pushed. Resume from the current PR84 branch
HEAD, preserving this stone cottage and the completed courtyard/riverbank work.
Additional building variations, other region improvements and device tests remain.
