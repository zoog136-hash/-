# L1J visual linkage phase 2 — 2026-10-10

Base: PR #60 at 0e935312. New stacked feature branch: feature/twilight-l1j-visual-binding-phase2-20261010. PR #59 remains unchanged.

Implemented: opt-in routing of external a2 images, explicit TextureRect and Sprite2D icon/portrait binding, AnimatedSprite2D SpriteFrames binding, reversible restore_all, in-memory Godot regression. All flags OFF by default. No save, combat, world, item-stat, sprite identities, or data migration changed.

The separate local bundle holds original image examples from a2(1).zip at assets/l1j/preview/a2/items and assets/l1j/preview/a2/monsters, plus data/l1j/registry/a2_visuals_normalized.json. Preview source IDs: ext:a2:item:34 and ext:a2:monster:ms852. These are graphic IDs only, NOT verified in-game identities.

Source images are NOT added to the public repository. A2 archive lacks an independent license file. Confirm rights before any public redistribution. Actual catalog binding requires verified source-to-TWILIGHT identity matching; automatic mapping is deliberately blocked. SPX action semantics, original TIL atlas, Android physical devices, and full gameplay integration remain unverified.

Godot 4.7.2 CI additionally generates two synthetic PNGs and tests ResourceLoader PNG loads, original TextureRect/Sprite2D display binding, isolated preview screen texture and rollback; these test PNGs are NOT original third-party images.
