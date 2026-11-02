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
