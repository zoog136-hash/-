# PR122 batch10 — full 498 roster reconciliation and continued source production

Starting PR HEAD: `846b71d14f847a302692064e6a8e9e34b37e3261`.
Observed main: `56f552c800dc031030a05b6e4125ed29a04aba62`.
Isolated worktree: `/workspace/twilight-pr122`, branch
`feature/pr122-all498-20261018`. No reset, force push, new PR, or main merge.

The fixed scope contains 180 hero-plus transforms, 258 normal monsters and
60 bosses, exactly 498 unique IDs. `all498-start-ledger.json` preserves each
binding, source reference, production provenance and SHA, motion track counts,
prior HOLD reason, and the separate Android field. The initial CI snapshot
matches the starting SHA: 31 successful runs, one cancelled and one queued.

The supported historical completion count remains **392**, not 398. All 392
recorded bindings/resources are tracked and byte-matched; all 255 canonical
report hashes match. Runtime connections are **394**. Two locally reviewed
subjects still await complete exact-commit CI. Existing HOLD: 16; not yet authored
or connected: 88; historical remaining: 106. No new approval is granted here.
Historical shared-body coverage is preserved separately from the stricter
per-species approval required in the current directive. `HOLD` in the current
evidence-state column does not delete or replace a historical approved asset.

All 14 locomotion repairs remain required. Thirteen belong to the 498 target
scope; transform:2 is an additional protected quality task. None counts as a
new species. X0.90/Y1.00 and gameplay remain unchanged.

## Authored source candidates

- Doguri N pilot03: six new poses; strict geometry passes, opposite support is
  still insufficient. HOLD.
- Doguri N contact-B pilot01: one independently drawn whole rear contact pose,
  with tail swinging left to expose the right leg chain. Source/model/scale and
  timeline review remain incomplete.
- Doguri N pilot04: six new poses; full source geometry passes. Tail flips too
  abruptly in the second contact and the loading sequence remains HOLD. The
  optional Main fixture does not install this into production.
- Albino deer idle pilot01/pilot02: 16 poses each from the pinned existing
  project atlas. Second layout uses blocks4x2 with wider antler margins. These
  are unfinished authoring inputs, not a completed monster or an original game
  animation extraction. Full walk/attack/hit/death and Main verification remain.

The raw viewer exaggerates RGB in pixels whose alpha is only 1–5/255. Early
fringe suspicion must not be treated as an opaque-alpha failure without actual
compositing; antler/camera/chronology still require visual review. Every raw PNG
is preserved byte-for-byte with its original request, SHA and candid assessment.
The first deer tool transport error produced no image; it is preserved separately.

## Verification and continuation

Required public resources: 723 atlases / 41,442 frames PASS. This is not delivery
of unavailable private originals. Godot official 4.7.2 archive SHA:
`cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`.
The first import had sandbox-local socket errors and is not a clean PASS.
A fresh incremental import with local networking enabled passed. Actual Main
uses Xorg dummy / Mesa llvmpipe OpenGL; Android real device remains `NOT_RUN`.

Reproduce the fixed-scope audit against the matching starting commit:

```bash
python3 tools/audit_pr122_all498.py --root . \
  --ci-json docs/remake/evidence/pr122-remaining106/batch10/ci-846b71d.json \
  --output /tmp/pr122-all498-new-observation.json
```

For later commits obtain a fresh exact-SHA CI snapshot; the auditor rejects
mismatched SHA evidence. Read the latest continuation file before resuming.
Continue actual source authoring; do not stop because an unrelated CI run or
one actor is HOLD. Do not install the currently rejected Doguri sequence.
