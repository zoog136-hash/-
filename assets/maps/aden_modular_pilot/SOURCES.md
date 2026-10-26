# Newly generated Aden modular pilot

New art generated with image_gen on 2026-10-24; no original Aden image pixels are included in these source or compiled assets. Original map consulted only for layout coordinates. This is not redistributed original Lineage art and does not change the original-resource delivery ledger.

- `source/materials.png`: generated stone/grass/water/dirt atlas, 1254×1254; quadrants reduced to 256px. Its stone is superseded.
- `source/paving.png`: new replacement courtyard paving, 1254×1254, reduced to 512px.
- `source/objects.png`: generated transparent fountain, hedge, flowerbed, wall, gate, tree atlas, 1536×1024; inspected crop bounds, reduced to placement sizes.
- `source/palace.png`: generated transparent palace, 1536×1024; cropped and reduced to 1200px width.

Seven unique object types and four material types are used, with 41 placements. No independent village image is repeated. Materials use mirrored repeats: periodic motifs remain visible and need art refinement. Reversed wall also reverses its baked lighting, a known pilot limitation. All four unmodified generated source files are retained.

`layout.json` pins this pilot to world (69600,16800), extent 3072×2048, at 1 image pixel per world unit. Source-reference coordinate scale is 6; main fountain exactly matches its existing collider center. Other layout anchors are manually traced approximations, not proof of every footprint. Compilation never reads the old PNG, changes navigation, or infers unseen ground.

Run `python3 tools/map_restore/compile_aden_modular_pilot.py`. It reuses existing lossless 512px chunk compilation. `compiled/palace_gardens_3072x2048.png` is the flattened PNG deliverable. Runtime preview loads 24 separate ground chunks on demand and deduplicated foreground sprites for occlusion. `sha256.json` records real PNG files.

See `docs/aden-modular-pilot-20261024/README.md` for actual-game evidence and outstanding work. This remains opt-in review art, not a production map replacement.
