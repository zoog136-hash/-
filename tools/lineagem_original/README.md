# Native base508 resource connections

The active catalogs use701 verified source definitions:388 transformations,167 dolls and146 relics. Source names, grades and in-world identities are preserved separately from the former registry. Class/gender and explicit active-option rules select conditional appearances; Halpas has a declared base, and Taco's indirect summon identity preserves application type461/target11 without inventing its gameplay meaning. NPC values remain keyed by exact source NpcClass IDs.

The common2D player/follower/relic path samples decoded source poses and offsets directly. It preserves native token order, zero-time events and separate Walk/Run declarations. The gameplay hit clock remains independent. No limb repair, interpolated frames, canvas resizing or procedural actor motion is added to native poses.

## Required private resources

This branch contains code and source metadata, **not the source pixel/UI pack**. A clean checkout or exported game cannot display the new native appearances until an authorized private pack is installed at `user://lineagem_base508/manifest.json`. No raw SP2, source-derived PNG, capture video or personal backup is committed here. Redistribution rights for the third-party art have not been established; the10GB original archive must not be published with this PR.

The private pack contains relative actor/pixel/UI paths and must be accompanied by its original input provenance. Library/local backup receipts are delivery records, not proof that public Git or an APK contains those files. Existing repository resource-integrity checks concern the previously tracked atlases; they do not approve this source pack.

## Build from authorized local inputs

Use the pinned `requirements.txt` in an isolated Python environment. Inputs are the validated base508 tables, original SPR declarations, and exact original SP2/UI files. Preserve original ZIPs and conflicting bytes; do not substitute nearby file suffixes.

```sh
python tools/lineagem_original/build_verified_registry.py --inputs INPUTS --output data/lineagem_base508
python tools/lineagem_original/build_native_pack.py --inputs INPUTS --registry data/lineagem_base508 --output PRIVATE_PACK
python tools/lineagem_original/attach_native_layers.py --inputs INPUTS --pack PRIVATE_PACK
python tools/lineagem_original/build_connection_report.py --inputs INPUTS --registry data/lineagem_base508 --pack PRIVATE_PACK --report PRIVATE_REPORTS
python tools/lineagem_original/build_native_overlays.py --inputs INPUTS --pack PRIVATE_PACK
python tools/lineagem_original/build_playback_policy.py --inputs INPUTS --pack PRIVATE_PACK --output data/lineagem_base508/playback_policy.json
```

Copy the authorized UI files into `PRIVATE_PACK/ui` with original relative paths. Install the complete pack into the game's user-data location, or use `--lineagem-original-preview=/absolute/path/manifest.json` for an isolated local inspection. The builders support targeted sprite refreshes so new inputs do not require converting the entire pack again.

## Runtime policy and current limits

The default policy is **unverified compatibility playback**, not proven M-client equivalence. Explicit SPR rates take precedence. Missing clocks use separately identified candidates; attr8 additive and attr128 alpha0.5 are declared host approximations. `--lineagem-source-strict` preserves unresolved clocks as static and disables unverified blending. See [COMPATIBILITY.md](COMPATIBILITY.md) for evidence, scope and controls.

At the latest local checkpoint743 sprite records serve701 card definitions.697 default appearances can be selected; four class/gender cards await an explicit declared pair when player gender is unknown.994 available attachment layers can be composited in compatibility mode;188 exact attachment addresses and seven frame-event source effects remain unavailable. Two body-track and two attachment-track address/frame exceptions are retained rather than filled with generated art. Source origin and eight-direction mapping still require visual review.

Godot4.7.2 headless import/loading checked the player route, strict/compatible separation, a source caster effect, a native frame-event overlay, and conditional identity selection. Android execution, per-character visual equivalence and full-game source-pack restoration remain unverified. Existing capture/validation helpers are isolated diagnostics, not evidence that all originals have been delivered.
