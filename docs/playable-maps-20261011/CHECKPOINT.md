# Playable map continuation

Independent branch from main 2f5ae1013da5c7281d3020719d8a723a23adb8cc.
PR81 b1198ad12d5c644bb357694b2d1261fb22a627b7 and preserved local runtime 43137c112759b7301728ccd3a8e40a67037692cf reused; neither branch changed.

Current map: l1_4, A3 mainland. Original tile images: missing. Original 25 TWILIGHT map equivalence: unverified, no field replaced.
Imported existing runtime, bounded chunks, precise source coordinates/edges, NPC and spawn integration, portals and separate save state.
Added explicit local Kurtz boss adaptation and guard against overwriting a source-map save when its data pack is missing.

Validation so far: source pack 2770 files / 161549593 bytes verified locally; 23 source regions passed 201 earlier runtime assertions on integrated main; first-map 21/22 headless checks passed. A* actor detour failed and is under investigation. NOT PLAYABLE-complete yet. No Windows device test.

The source pack remains private/local. Public Git contains code, provenance and installation instructions; not unreviewed source bytes. Existing main resource rules and 723 tracked atlases preserved.
Next: diagnose actual detour movement, GL validation, clean-code fallback regressions, local installer validation, publish independent PR and precise status matrix.
