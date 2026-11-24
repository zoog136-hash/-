# Source companion frame-plan rebuild

The Android 523.843 capture is evidence of steady rendering work, not evidence that companion rendering caused the capture's longest frame gaps. World measures the doll, relic and secondary slots under `companion`; their calls enter the same `preview.cached` timing bucket used by player and NPC rendering. The player buckets `player.visual`, `player.source` and `preview.cached` can nest, too. These values must not be added as disjoint costs.

A raw-reference preview builds a node-based draw plan the first time it sees a pose (and again after eviction). During that synchronous build, it verifies every selected body/effect layer, including hidden ones. Previously it ran another full pin/member/frame validation before binding even a texture the same preview already owned. Now only that repeated check is skipped. New/shared texture acquisitions, independent layer plans, later compositing fallback, integrity rejection and warm-plan rechecking retain their existing rules. No change to frame timing, direction, clock, transforms, source pixels, layer order, follower smoothing, first visible phase, memory caps or asset verification interval.

## Regression and benchmark

- Linux Godot headless. The real preview and bank scripts consume a synthetic pinned SP2 bank. Eight directions × three poses cycle against the production 16-plan companion cap; actors begin measured runs with local textures populated. 240 advances per run. No new pixel decoding in either arm.
- Same checkout/input and test runner, alternating baseline/current in A/B/B/A/A/B order, independent XDG profiles. Median of three: **764.4 → 498.7 µs per advance**, and **1,400 → 700** exact layer validations. Grand totals on an actual phone or official source client are not measured by this test. Actors that keep a warm draw plan do not take the changed branch.
- The baseline fails the new repeated-validation assertion (8 vs 4 checks on an evicted pose), while the current code passes. It verifies the evicted/rebuilt pose's draw output and source provenance against the original per-layer path. A raw member deleted after eviction still rejects immediately despite an already-owned texture. The normal warmed plan still performs its existing pin/member recheck.

On the final implementation, frame-plan/draw-output tests (1,049 checks), source timing (7), companion placement/following (136/91), attachment projection/instance identity/retry (25/31/32), plan caps (7) and source asset sharing (62) passed headless. No GPU framebuffer or Android render test was run.
