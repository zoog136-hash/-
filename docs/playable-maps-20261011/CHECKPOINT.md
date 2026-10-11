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
