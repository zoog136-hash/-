# PR158 non-CI follow-up: eight mythic HOLD repairs and legendary capture timing

User authorization: image edits for confirmed failures only; CI excluded. Originals, the previous 10 repaired clips, approved unique actors and other branches are preserved. No production catalog/normal-monster/UI/map/economy files or workflows changed.

## Mythic whole outstanding visual-HOLD batch

All eight previously reviewed visual HOLDs were inspected at source resolution before editing. Confirmed defects: 133 SE/SW idle used recoil/crouch poses; 141 SW idle/hit faced right; 174 NE/SE/SW idle turned between directions and SE swapped weapon hands; 189 SW attack faced/struck right. These were confirmed failures, not blanket permission to regenerate geometry HOLDs.

**8/8 corrected sheets, 48/48 distinct complete poses** passed unchanged separation, alpha, ownership and boundary criteria. Five rejected initial edits retained wrong directions/hand continuity or loose visible pixels; subsequent prompts changed viewpoint instructions and/or grid/gutters. A later 174 SW candidate lost the blue sword material and was corrected before selection. Image tools authored every edit; no Python pixel editing, mirroring, pose duplication or discarded visible pixels. `generation-attempts.json` pins 17 attempts, eight selected/delivered; rejected files remain local-only and are not deliverables.

All eight selected clips are connected in fresh **staging** SpriteFrames/Profile versions, preserving all prior versions and 87 unrelated tracks on the four affected actors. Actual Main/Player validation: **8/8 clips, 48/48 poses**, authoritative attack marker, direction choice, virtual-foot/collision contracts and state preservation PASS, engine errors zero. Every source sheet and all four actual-Main phase sheets were visually inspected. Current 301 selected mythic source pins/geometry pass with zero errors. This closes the specific eight source defects; **new default production connections 0, new final all-criteria quality approvals 0**. Prior full-quality and absent-source dependencies are not approved by this repair.

## Legendary capture timing batch

The historical 177 NW hit receipt saw only phases 3–5. A reusable, read-only exporter now selects **all 40 legendary NW hit clips** from the pinned c23aff8b active library using the existing selected-metadata audit. It reads existing Git objects, verifies TRES pins and preserves PNG bytes; it does not download/rebuild the whole corpus or modify its branch.

The local capture harness warms all six paused frames **including synchronous viewport readback**, then runs each original one-shot in real time at its authored speed. The previous harness warmed frame submission only. It still requires all six observed phases and terminal frame 5; no slower playback, forced stepping during measurement, relaxed threshold or synthetic missing frame.

Result: **40/40 clips, 240/240 timed phases, 40/40 terminal holds PASS**, engine errors zero. The 177 trace starts at phase 0 at 0.016507 seconds and observes phase 5 at 0.18612 seconds. All five overview pages were inspected; each clip has its original capture and per-frame time trace. This verifies captureability in the current local environment, **not a controlled proof of the historical CI root cause**. This diagnostic loads SpriteFrames directly with one fixed preview scale: it deliberately does not substitute that scale or raster centers for Player anatomical registration. In particular the differently sized 176 source revisions still need their existing per-frame semantic adapter; the preview's size changes must not be reported as a new production regression.

## Remaining dependencies (not completed)

- Mythic: remaining source geometry HOLDs and absent authored slots from the preserved whole-batch inventory; transform:399 still has no authored locomotion sizing reference/native profile. Eight repaired visual HOLDs no longer remain in that particular subset. No full-actor final approval is asserted.
- Legendary: 39/40 actors lack complete reviewed anatomical anchor/scale coverage; 176 has 33/33 registration records and prior Main QA evidence, but guard/authored model continuity remains quality HOLD. No actor is silently installed using raster origins. The prior 274 NE attack supplemental draft remains delivered separately; its native profile/registration is still absent. Pinned source branch remains 1319/1320, plus one separate PR158 supplement; no fictional merge.
- Map initialization: source comparison 637e9e12 to 967faa54 shows no changes in world/map/clearing-helper/locomotion-runner files. The preserved local probe finds 1523 suitable cells in actual NativePngField; the old remote log did not record its field/pack state and fails before candidate injection. Thus it is an unresolved historical environment/arena gate, not proof of an animation bug. The prior isolated-runner missing-map-pack link was already fixed. No guessed wait, weaker clearance, gameplay-map edit or duplicate run was added.
- Boss: previously repaired three five-pose failures and their Main evidence preserved; 37/429 unpublished requested slots still lack valid selected sources. No unconfirmed HOLD was remade.
- Real-device validation and final quality approval remain unverified. CI was neither executed, changed nor monitored in this follow-up.

Reproduce the timed batch with `tools/prepare_pr158_legendary_hit_timing.py --output <new-overlay>`, then `run_pr122_approval_validation.run` against that overlay with `pr158_legendary_hit_timing_batch.gd` (Godot 4.7.2 and Xvfb). For mythic use the delivered explicit repair plan with the existing Main batch harness; installation is non-overwriting and must not be reapplied over existing versions.
