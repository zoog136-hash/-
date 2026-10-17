# Additive Main temporal evidence

Frozen validator SHA-256: `cc193e2cd41309732ca6735e3bfd20adb672cc229edc73123967e7550f7a768c`.

Actual Main and database actors run the production MotionController across all eight directions and five roles. QA controls inputs and advances every 1/120 simulation second; both simulation and wall timestamps are recorded. Captures follow actual `frame_post_draw` with motion held, and textures are selected by production animation code. This evidence does not measure wall-time performance or establish real AI combat or weapon-caused deaths. Existing gameplay and full CI gates remain separate. Completion increment: **0**.

The headless matrix covers Sword, Revenant and Seeker (119169 checks). The rendered matrix covers Waring, Sword and Revenant (121077 checks): 312 mandatory phase captures, 24 temporal storyboards, and nine unmodified full-viewport representative captures. Both final summaries have no failures. Root independently approved the 24 storyboards; see `root-independent-visual-review.json` for exact source hashes and scope.

Three per-case ZIPs preserve all 312 phase PNGs byte for byte; each stays below 50 MiB. `archive-members.json` records member SHA, native phase token and timestamps. `SHA256SUMS` covers every packaged file except itself and the package manifest. Original JSON reports retain their source absolute paths unchanged; `source-path-map.json` maps durable copies, and archive members map phase PNGs.

`code/` preserves the exact validator and helpers. `rejected-versions/` preserves prior reports, logs and available version snapshots: v1 had invalid diagnostic windows, v2 cut the extended Sword attack in its smaller crop, and the numerically passing ready version exposed Waring/player occlusion. Final clear evidence uses the larger diagnostic window, independently asserts the whole body inside it, and moves the QA player out of the review envelope. No production art, map, actor stats, runtime code or existing quality guards were changed by this validator.
