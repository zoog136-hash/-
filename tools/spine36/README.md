# Verified Spine 3.6 mesh sampler

This tool evaluates original 3.6 skeleton data with a separately installed, pinned
Spine C runtime. It emits sampled mesh geometry for TWILIGHT's Godot player. It
creates no image and never changes the original JSON, atlas or PNG files.

A valid Spine Editor license or separate integration permission is required by
[Spine's 3.6 runtime terms](https://github.com/EsotericSoftware/spine-runtimes/blob/654c20e5b0e523040b6366bbd1042510d2645134/LICENSE).
The SDK is **not bundled in this repository**. Keep its notice/license with the
external SDK and generated package. `SPINE_RUNTIME_LICENSE.txt` preserves that
notice. The user confirmed license ownership for this work.

The required SDK commit is `654c20e5b0e523040b6366bbd1042510d2645134`
(`EsotericSoftware/spine-runtimes`, branch 3.6). Install its
`spine-c/spine-c/include`, `spine-c/spine-c/src` and root `LICENSE` without editing
tracked SDK files. The builder checks this commit and a clean tracked SDK tree,
compiles our wrapper with warnings as errors, and links the external C sources.
No fast-math flag is used.

```sh
python3 tools/spine36/bake_mesh.py \
  --pack /absolute/path/to/verified-original-lobby-pack \
  --manifest-sha256 PIN_OF_ORIGINAL_UI_JSON \
  --sdk /absolute/path/to/spine-runtimes-3.6 \
  --output /absolute/path/outside-original-pack \
  --fps 60
```

Use repeated `--body UI/Spine/ExactOriginalName.json` options for a subset. With no
body option all explicit `lobby_spines` entries are evaluated. The output contains
one `.mesh.json` and `.mesh.proof.json` per body, SDK build/license information,
SDK logs and a summary. The output is private third-party-derived material; it is
not a public repository asset. The wrapper rechecks all original file hashes and
the pinned manifest after evaluation.

## Evaluation contract

- Exact source JSON/atlas/page SHA-256 and byte counts accompany the geometry.
- The SDK evaluates weights, linked-mesh deform, IK, transforms, path constraints,
  attachment changes, colors and draw order. Region and mesh UVs come from the
  SDK atlas loader, including rotated regions. Clipping uses the SDK clipper.
- Coordinates use the official SFML convention `spBone_setYDown(1)` for the Godot
  preview. Source UI host offsets/placement are not inferred or applied here.
- `fps=60` is an explicit host sampling choice, not a claim about the original
  application's frame cadence. The exact SDK duration and its last sample are
  retained exactly once. Float32 grid points equal to the duration are deduplicated,
  so timestamps increase strictly. Each animation starts independently from setup pose, without mixing
  a different animation or guessing an original autoplay/loop policy.
- `premultiplied_alpha=false` describes decoded original PNG handling in this
  host. It does not establish the original client's upload/blend policy. Light
  color is skeleton × slot × attachment. Dark RGB follows Cocos 3.6's skeleton ×
  attachment × slot-dark convention without premultiplication; the player derives
  the shader's dark-alpha flag from the host PMA policy. The exported fourth
  dark component is zero for this straight-alpha host; the SDK's `-1` sentinel
  for a six-digit dark RGB value is not a shader alpha input.
- Events are not executed as game callbacks. This is mesh playback, not a replay
  of arbitrary original client logic.

## Unreferenced missing atlas declarations

Two original declarations have missing atlas regions: Knight Male `Face` and Elf
Male `zuobi1`. The original bytes are preserved. The driver proves, per missing
path, that its definitions are not selected by the default setup or any declared
attachment timeline, have no deform/FFD timeline, and are not linked-mesh parents.
Only then does the SDK's documented attachment-loader `NULL`/no-error skip apply.
An active or referenced missing region is a hard error; another class atlas is
never substituted. The proof and exact skipped declarations are recorded in
`source.unreferenced_missing_attachments` and the SDK log.

This proof covers only default setup, declared source animations and the linked
mesh graph used by this player. It does not claim the original client never calls
`setAttachment` externally. The official API contract is in
[AttachmentLoader.h](https://github.com/EsotericSoftware/spine-runtimes/blob/654c20e5b0e523040b6366bbd1042510d2645134/spine-c/spine-c/include/spine/AttachmentLoader.h).

A successful bake proves evaluation/data integrity. It does **not** prove original
rendering, placement, automatic presentation or Android/device performance.

## Exact shared geometry format

`compact_mesh.py` converts validated inline evidence to V1 shared geometry while
preserving the inline files. Top-level `geometries` maps IDs to
`{page,uvs,indices}`. Each batch keeps `positions`, light/dark tints, blend,
slot/attachment provenance, and a `geometry` ID. It does not also carry inline
page/UV/index fields. Deduplication compares exact page strings, Python float
values and index tuples. A binary64 expanded semantic digest before/after
compaction checks all evaluated values and metadata; nothing is quantized.
The final JSON uses ASCII escapes without changing decoded source names.

```sh
python3 tools/spine36/compact_mesh.py \
  --input /absolute/inline/Spine_Knight_Female.mesh.json \
  --output /absolute/compact \
  --pack /absolute/original-pack --manifest-sha256 MANIFEST_PIN
python3 tools/spine36/verify_compact.py \
  --directory /absolute/compact --pack /absolute/original-pack \
  --manifest-sha256 MANIFEST_PIN
```

Repeat `--input` for all 25 inline body files. The final verifier requires the
manifest's exact complete body set, rechecks original file/page/source hashes,
checks strictly increasing clip times and valid tints, finite geometry and triangle
bounds, and compares the on-disk binary64 digest to the inline evidence. Its
`final-summary.json` is the final package data gate. Old intermediate evidence is
kept separate; it is not a substitute for this final gate.

Run pure boundary fixtures with `python3 -m unittest discover -s tools/spine36
-p 'test_*.py'`. They do not establish SDK render or device equivalence.
