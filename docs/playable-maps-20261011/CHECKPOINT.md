# PR84 bounded resume — one Aden stone cottage completed (2026-10-11)

This entry supersedes the stale next-step text below. Start from the current
`feature/twilight-reference-expansion-20261011` remote HEAD, not a historical SHA.
Remote base for this unit: `35578da7e8a9a7ea3ea31c1bf65f471f85c39a9a`.
Previous local `85ad235` and that remote commit had the same tree
`24a594d40fbcff051f19401f9e838e76f8e799b6`. Recent commits, actual renderer code,
logs and screenshot hashes confirm the courtyard unit was already completed.

Completed in the commit containing this entry: one original stone/slate cottage
at existing Aden house position `(1630,3610)`. No other building or paving change.
New PNG `assets/maps/aden/stone_cottage_v1.png` is 2,044,387 bytes; SHA-256
`f80b3b96533d104b97777953b154d0711e6c387e415adb6be0078de0a2212f2b`.
Evidence and exact preserved-file hashes: `aden-building-v1/`.

Actual Godot 4.7.2 Linux software OpenGL: 40 checks PASS, zero failures;
project import/game boot PASS; UI fidelity 75 assertions PASS; 723-sheet integrity PASS.
Same-camera before/after captures and roof fade/style/streaming captures are stored.
Full unrelated suite and physical Windows/Android devices were not rerun.

The accessible earlier checkout was clean and is preserved. No separate prepared
stone-cottage image was located in the checked paths; new art was generated.
Do not claim all prior unsaved results were recovered. Uploaded original packs
were not required or reprocessed. Original map restoration remains 0/25.

This is the requested stopping point after commit/push: one building unit only.
Remaining: further architectural variety, other regions and device verification.
No main merge, deletion, reset, history rewrite or forced push is authorized.

---

# PR84 resumed — Aden riverbank unit saved (2026-10-11)

Current map: `aden_world`. Completed: ground texture continuity and wet riverbanks,
visible shallow bed, gradual water depth and softened land shoulders.
Remote saved shoreline SHA: `209d2b876a2525b2ea5d7f675eb6ea7cbffcae26`.
Verified tree: `7f044b281fc51f189eaa7fdcfe9d8da0c76d69c8`, identical to local
`4d440cfef1a8c39284a716d756f993666f84866a`. Earlier ground unit: `67017f1`.

Actual Godot Linux software OpenGL after shoreline changes: 25 gameplay checks
PASS and 23 additional outline/triangle/bridge/capture checks PASS. No failures
in this unit. Three original river polygons and both bridge footprints preserved.
Evidence: `aden-shoreline-v3/`; same-camera north-bridge before image reused from
`aden-polish-v3/after/03-bridge.png`. Source map, gameplay and atlas hashes preserved.
Resource integrity: 723 sheets PASS. Windows/Android devices remain untested.

Remaining: village paving has a conspicuously regular hard elliptical perimeter;
architecture detail and other regions still need work. Original restoration 0/25.
Next concrete action, now continuing: soften and weather the existing three Aden
courtyard edges in the ground shader, reuse the current paving texture and exact
courtyard placement; render village/ruins views and verify movement and style toggle.
No approval hold, no main merge, no modifications to other feature PRs.

---

# PR84 resumed — Aden ground seams saved (2026-10-11)

Current map: `aden_world`. Completed: removed diagonal/horizontal hard joins in
existing authored ground textures with continuous sampling scoped to Aden.
Remote saved implementation + evidence SHA: `67017f1fd2f9927668e8548489563822c58ddec0`.
Verified remote tree: `c74488897e7cb941982f9ef21c47d655f0ee14ff`, identical to local
`92135283bc0e75367e28aa508af10042a9483c7d`. Resume from current PR84 head.

Actual Godot 4.7.2 Linux software OpenGL: 25 Main-scene checks PASS (movement,
river physics, route clearance, canopy fading, NPC shop, minimap, isolated save/load,
Oman portal/return and streaming); four GPU wrap-boundary comparisons PASS.
Initial probe had three invalid measurements because its camera ignored rotation;
fixed camera and targeted rerun PASS. Initial and corrected logs both tracked.
Evidence: `aden-polish-v3/` (before/after PNGs, logs, SHA manifests, validation summary).
Atlas and gameplay/map JSON/code hashes remain equal to parent `28b9978`.

Remaining: water/land boundaries still meet abruptly, architecture detailing,
original tile restoration (still 0/25), all-map individual gameplay acceptance,
Windows/Android device runs. No claim of Lineage M visual parity; no main merge.
Next concrete action: refine the water/bank transition beside Aden's north bridge,
using only the existing polygon outline. Preserve river collision and bridge width;
capture the same (6180,3000) camera position and validate the crossings in Godot.
This next unit is authorized and is being continued without an approval hold.

---

# Reference expansion checkpoint (supersedes previous approval hold)

User requested “리니지m 사이트 검색해서 확장해봐” after seeing the first authored screenshots. Expansion is authorized. This is a separate branch/PR84 above PR83; PR83 and main remain unchanged.

Remote implementation commit: `9ce4af244027989aecfe5c2c63a3ce129dc9557a`; local equivalent `3cfaa942010a7a0e089e794a83b20b8d0a63c89f`; identical tree `d48d9ed4866d04050bbab7566c881302425b4ad5`. Current HEAD additionally contains evidence and source-pack truncation guards. Resume from the current PR84 head, not an older checkpoint SHA.

Completed: 16 authored terrain materials and 16 transparent environment sprites, production visual profiles on all 25 existing TWILIGHT regions, improved A3 l1_4 ground/NPC presentation. See REFERENCE_EXPANSION.md for references and limits; no proprietary reference images are shipped. Terrain and scenery PNG SHA-256/byte counts are in assets/maps/reference_expansion_v2/asset_manifest.json. Source graphics restoration remains 0/25.

Actual Linux software OpenGL: 25/25 existing maps rendered, 240 checks PASS, 25 unedited 1280×720 screenshots in reference-v2/screenshots/. Separate A3 l1_4: 37 checks PASS, includes clicks/collision/A*/NPC/boss/AUTO/portal/save/reconnect. 24 dungeon gameplay suite: 5679 checks PASS, 5 families AUTO/combat tested; Aden field: 1677 checks PASS; full progression portal suite: 244 checks PASS. Do not claim AUTO was individually tested in all 25 maps from a five-family check.

Whole suite initially 91/95 passed. Three external-adapter fixture tests passed on targeted rerun in an isolated synthetic worktree. The fourth exposed an incomplete local navigation-01.bin (414492 bytes vs referenced end 607508). Rebuilt only that shard from preserved source grids, verified each payload SHA and compression length; original catalog then loaded all 998 enabled entries out of 1000 preserved maps. The cause of the initial truncation is not established. Installer/manifest verification now rejects out-of-bounds payload references, and exporter checks final shard size. Private pack verified: 2016 files / 120986251 bytes. Full suite was not repeated after targeted rechecks; no remaining failed checks in those reruns. Initial failures are retained under reference-v2/regression/.

Remaining: exact original map correspondence and original tile art, richer architecture/shoreline detail beyond this art pass, per-map full AUTO/boss acceptance, Windows/Android device validation. All map topology, collision, NPC/monster/portal coordinate data are preserved by this visual expansion. No merge to main has occurred.

Next: inspect the committed actual screenshots and refine specific regions. Do not rescan the source archives or repeat completed tests without a new issue. Install the private pack using INSTALL.md only if missing; verify_payload_ranges now detects incomplete shards before reporting installation success.

---

# Authored-tile screenshot checkpoint

Latest completed implementation: c0e40c1a55b52f6fe5bc0e3f3bb697d35272d1a3 (remote PR83); local equivalent 60649aa72875f1cd46a2bb76a705adac19daf1fe. The current branch HEAD includes this evidence checkpoint. Latest main verified 2f5ae101; main and the earlier PRs remain untouched.

User changed the art requirement: "타일을 소스들에 맞게 직접 제작해봐". Newly authored replacement graphics are now authorized. No original tile download is required to continue this authored-art path. Original artwork restoration remains 0/25 and must not be incremented for these images.

Current map: l1_4. PLAYABLE with newly authored terrain. Four ground materials and four obstacle sprites in two real PNG atlases (5,892,144 bytes) are tracked and SHA-verified in Git. Source navigation, 48×24 projection, S32-based subtle variation, chunk streaming and all gameplay are preserved. Other maps are explicitly excluded from the new style. Original water/building/object graphics are unresolved; neutral rock represents inaccessible cells, not a claim about their original material.

Validation completed: actual Godot 4.7.2 Linux software OpenGL, 36/36 checks, zero failures. Covers movement, source collision, A*, NPC shop, monster/boss, AUTO movement/damage, actual l1_4→l1_6 portal, minimap/map selector, save/reconnect, missing-pack save preservation, bounded chunks, and no authored-style expansion to destination maps. Existing 723-atlas resource integrity passed. Windows device validation remains unperformed.

Evidence: evidence/authored-first-map-gl.log and evidence/authored-first-map-result.json; actual unedited first-map screenshots in authored-screenshots/01-mainland.png and 04-auto-combat.png. The former diagnostic screenshots remain separately preserved in screenshots/. Full prompts and authored image SHA values are under assets/maps/authored_mainland_v1/.

Next action: present these actual screenshots and wait for the user's explicit OK, as requested, before producing the remaining maps. No screenshot approval has yet been given. Do not repeat source ZIP scans or completed checks without a concrete new issue. Resume from this PR branch HEAD. Do not merge main without authorization.

---

## Previous checkpoint (historical; original-art blocker applies only to original restoration)

# Current playable-map checkpoint

PR #83, independent branch feature/twilight-playable-maps-20261011.
Last verified remote commit before this checkpoint: 335475e55d937e8cfc4cfc5dd8e022cb8ce91086. Local implementation checkpoint: cea799104e89955f5ad24b352eb2c60c784605b4. Use this branch's current HEAD when resuming, not an old workspace.

Current map l1_4: PLAYABLE with temporary navigation terrain, not ORIGINAL_RESTORED. Freshly installed A3 source pack passed 32 software OpenGL checks and five screenshots. Original target-25 edition/ID equivalence is unconfirmed; the exact zero/25 restoration counters and separate source-runtime counters are in status.json and REPORT.md.

Completed: PR81 and saved runtime reuse; source geometry/edges, A*, actual actor movement, streaming, NPC, monsters, explicit local boss, portals, AUTO, minimap, map menu, save/reconnect; float precision fix; missing/corrupt pack save protection. Old 25 maps remain.

Validation: initial full 89/93, four issues rechecked successfully as documented; 23 source maps 201 assertions, first source map 32 OpenGL assertions, legacy 25 maps 9323 assertions, malformed pack 12 assertions. First remote L1J CI failed because its fixture tool encountered existing shipped art. Fixed by separate synthetic subpaths, keeping original-byte protection; synthetic runtime 78 assertions pass. Final CI remains separately inspectable on PR83.

Source pack publication: excluded from public Git because redistribution rights are not established. Uploaded source ZIPs remain the input. Run INSTALL.md to reconstruct locally, or reuse data/l1j/recovered_maps and data/original_maps only after verify_delivery.py passes. Uploaded files SHA all 16 match PR81. No unchanged nested-archive rescans are required.

## User screenshot approval gate (latest instruction)

Complete original tile graphics in the first map, present actual Godot screenshots, and wait for explicit user OK before producing remaining maps. No approval has been given. Do not expand now. Existing gameplay implementation and old screenshots remain unchanged; those diagnostic screenshots are not the requested original-art approval deliverable.

New completed work: retrieved previously missing a2(1).zip (446,375,472 bytes; SHA-256 cfea6e88864987454f63fe8d367e65a7133c0685685045ce40bb20942a6968bd). CRC-read and SHA-compared all 8,033 files against the four uploaded split archives: 8,033 exact matches, zero new files. All 13 nested ZIP hashes match, so existing deep scans were reused. See evidence/a2-complete-archive-check.json. Do not request or rescan these same archives again.

Current original-art blocker: no actual tile bytes. First-map l1_4 spawn (32624,32813), initial nine streamed chunks, requires 333 distinct TIL IDs / 30,149 tile-index images. Mapped images: 0. Their verified source chunk references and exact required TIL IDs are in first-map-tile-requirements.json. This is a missing-input diagnosis, not new gameplay or restoration completion.

Resume: obtain matching client Tile.pak AND Tile.idx, including any referenced companion Tile*.pak shards, or the extracted numeric TIL files listed above. Verify source bytes and edition, decode tile blocks, then implement/verify terrain covers and object layering, run first-map GL gameplay validation, and capture actual screenshots. Ask for screenshot OK only once that concrete result exists. Keep third-party bytes private unless redistribution is authorized. There is no reason to repeat successful gameplay tests until implementation changes.

At 335475e5, resource integrity, Godot, UI, L1J Runtime and Recovery, and other CI jobs had passed; Integration/Monster World/Combat Animation were still running when checked. Windows remains untested. No code/asset changes were made during this missing-art follow-up; only evidence and the user gate were recorded. Main remains 2f5ae101. Do not merge main/other PRs without authorization.
