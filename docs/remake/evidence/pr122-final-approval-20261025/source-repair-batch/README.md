# PR158 confirmed failure repairs — 2026-10-25

The user explicitly authorized image editing **for failed items only** after the earlier restriction. Existing PNGs, selected resource versions, successful tracks, unique-completed actors and source branches are preserved. All authored edits used the image-generation tool; Python only inspected pixels, copied exact bytes and emitted resource metadata.

## Results and denominators

| Scope | Authored sources / connection | Verification | Remaining |
|---|---|---|---|
| Mythic confirmed FAIL | 7/7 corrected six-pose sheets selected in new staging resource versions | Actual Main/Player 7/7 clips, 42/42 poses, no assertion/engine errors; all source and Main sheets visually inspected | Prior 8 visual HOLD unchanged; other absent/geometry-held requests unchanged |
| Legendary missing 274 NE attack | 1/1 supplemental six-pose draft and SpriteFrames in PR158 | Six actual rendered poses and one-shot final hold PASS | No native Player profile/installation; anatomical registration dependency unchanged. The c23aff8b branch itself still contains 1319/1320; this additional draft is separate, not a fictitious branch merge |
| Boss selected five-pose FAIL | 3/3 corrected six-pose sheets selected in new staging versions | Actual Main/Monster 3/3 clips, 18/18 poses, all three authoritative profile-frame-2 markers, no assertion/engine errors | 37/429 requested clips remain source HOLD; other full-quality review incomplete |

The **10 confirmed failed selected clips** now pass their specific source-defect checks and actual Main replay. New final whole-clip quality approvals and new default production connections remain **0**. A scoped defect repair is not an all-actor final approval. Previous whole-batch failed reports remain historical evidence; do not reinterpret their original exit codes.

Fresh cheap integrity checks after the changes cover all 301 selected mythic clips and all 392 unpublished-boss clips: no texture/profile/RGBA/bounds/empty errors; boss selected five-pose holds are now zero. The 723 baseline atlas / 41442-frame integrity check and eight reconciliation/analysis tests pass. No full CI or previously passing Main batch was repeated. Final-SHA CI links/status are recorded in PR158; queued jobs are not successful results.

## What changed

Mythic: 413 SW RUN, 135 NW IDLE, 141 SW ATTACK, 174 SW RUN, 242 S RUN, 367 N/W RUN. The corrections remove direction reversal, bow-drawing IDLE and weapon-hand switches. Boss: Grim Reaper N ATTACK, Prince Deus N/NW ATTACK now have six individually authored poses with one weapon in the original anatomical hand. No omitted bad source pose was restored, mirrored or cloned to satisfy the six-pose rule.

Generation failures were rejected before selection. Where the first edits kept incorrect hands/directions, the next prompts identified those specific remaining errors. Where rectangular ownership failed, a later layout changed the grid and margins. The original separation, boundary, six-distinct-pose and full-visible-pixel guards were retained. `generation-attempts.json` records attempts and SHA; rejected candidate PNGs are local-only, not claimed as delivered. All eleven selected/new source PNGs are delivered here unchanged from their image-tool output.

Mythic installation retains the existing profile parameters and changes only its SpriteFrames path. Boss installation preserves every unrelated track/resource and the existing attack duration; the authored pose count rises from five to six. Its virtual canvas is derived from the prior reference-height ratio without resampling source pixels. Attack marker indices, controllers, collision/HP, palettes/names/aliases and production catalogs are unchanged. `preservation-proof.json` checks the original files and unrelated records against 15af6bca.

## Reproduction and evidence

- `mythic-repair-plan.json`, `boss-repair-plan.json`: exact selected PNG pins and scope. Install tools are non-overwriting; the selected versions already exist and must not be reapplied.
- `mythic-main/`, `boss-main/`: actual Main reports, logs and every changed clip capture.
- `legendary274-supplement.json`, `legendary-render/`: explicitly standalone draft render, not Main/Player integration.
- `*-after-source-repair.json.gz`: fresh whole-selection byte/pose audits.
- `tests/pr122_approval_mythic_batch_main.gd` and `tests/pr158_unpublished_boss_batch_main.gd` retain their default 300/392 full-batch denominators. An explicit nonempty repair plan checks the exact changed subset and pins; no assertion was relaxed.

Prior partial-locomotion CI clearing failure and historical legendary 177 NW HIT capture-timing failure are not claimed resolved by these source-art changes. Their existing evidence and unresolved status remain intact. PR158 base remains unchanged; this work does not merge or modify another PR.
