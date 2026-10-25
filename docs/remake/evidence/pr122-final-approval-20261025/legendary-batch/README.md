# Legendary whole-batch verification

Source branch `feature/pr122-legendary-parallel-20261023`, remote-confirmed c23aff8b8fa34b822e6d6012cf272f4a804f4b71. Not merged into PR122/main/PR158. No source branch modification, production catalog switch, original-pixel edit or new final approval.

## Fresh whole-corpus checks

All 1319/1320 active selected SpriteFrames were read using the SHA-pinned active revision library. All 1345 referenced PNG paths (1341 distinct Git blobs) were batch-fetched, read, CRC/decode checked, SHA-recorded, and checked for transparency, nonempty selected alpha and source bounds. File-pin/six-region/PNG/bounds/empty errors: **0**. There are **556 frame-edge review flags**, not 556 established defects. Missing slot: **transform:274 / NE / attack**. Draft count remains 1319/1320; these file results are not quality approval.

The initial individual lazy-fetch audit was interrupted solely to replace per-object networking with two aggregate fetches. It was not counted as a completed test. The existing download and queued full audit both finished normally; no second whole download was started.

## Actual Player eligibility and verification

All 821 active registration files were read. **788 are raster-coordinate preservation; 33 are REVIEWED_ANCHORS_AND_SCALE**, all for transform:176. This corrects the earlier blanket implication that all 821 were merely raster origins. The 40 actors lack a shipped native_profile; however 176 has complete reviewed semantic coverage for all 33 required slots. The other **39 actors** do not. No center coordinate was relabeled as a foot.

A read-only QA overlay exports only the complete eligible set from the pinned branch. The actual Main/Player test uses a clearly marked QA-only post-ActorMotion registration adapter to apply those existing exact per-frame scale/anchor records. **33/33 clips, 198/198 phases PASS**, no engine errors; exact reviewed anchors, existing width convention, authoritative attack marker/time, no mirror/warp, death final frame, collision/class/world-state preservation checked. Five game-scale capture pages were viewed. This proves QA connectability with the explicit adapter; it is **not** a claim that unmodified production Player already supports those registrations. Production code/catalog and prior approved assets remain unchanged. Final visual approval stays **0/1320**; captured model/pose variation remains HOLD.

The test inherits a published-boss report object. Its original candidate_injections field incorrectly defaulted to zero; `raw-report.json` is preserved, and `report.json` corrects only that counter to the observed 33 injections. `executed-harness.gd.txt` preserves the exact executed code. The source harness now writes that counter correctly; no gameplay assertion or approval criterion was weakened and replay was not repeated for a report-only correction.

## Remaining causes / next implementation boundary

- 1 absent authored clip: transform:274 NE attack. Requires a valid authored source; image-generation restriction remains in force.
- 39 actors: reviewed anatomical anchor/scale coverage missing. Existing centered-raster records must not be substituted for anatomical feet.
- 1 actor / 33 clips: complete registration and QA Player replay exist, but the adapter is QA-only, default production installation is 0. Full original-source visual approval and a separately validated production adapter/profile are still pending.
- Historical transform:177 NW hit failure captured only phases 3–5. Its six actual selected regions now pass file/alpha checks, but this does not resolve the prior render-timing failure. Existing source harness already pauses for nine warmup frames; do not claim missing warmup was proved to be the cause. The failure is preserved, not relabeled PASS.
- Historical 972-row issue projection is not 972 freshly confirmed bad clips. Prior healthy replays were not repeated. No whole CI was started.

Reproduce the bounded QA with `prepare_pr158_reviewed_legendary_batch.py` and `pr158_reviewed_legendary_batch_main.gd`. The source PNGs remain tracked in the pinned legendary branch; the overlay is temporary and is not a production installation. The plan records every exported source path/SHA and the 39 blocked actors. Captures/logs/reports here are delivered, not just local paths.
