# Current playable-map checkpoint

PR #83, independent branch feature/twilight-playable-maps-20261011.
Last verified remote commit before this checkpoint: 67dac0688cb756b79bc48da8959dcefb77a7dd40. Local implementation checkpoint: faff1b1b. Use this branch's current HEAD when resuming, not an old workspace.

Current map l1_4: PLAYABLE with temporary navigation terrain, not ORIGINAL_RESTORED. Freshly installed A3 source pack passed 32 software OpenGL checks and five screenshots. Original target-25 edition/ID equivalence is unconfirmed; the exact zero/25 restoration counters and separate source-runtime counters are in status.json and REPORT.md.

Completed: PR81 and saved runtime reuse; source geometry/edges, A*, actual actor movement, streaming, NPC, monsters, explicit local boss, portals, AUTO, minimap, map menu, save/reconnect; float precision fix; missing/corrupt pack save protection. Old 25 maps remain.

Validation: initial full 89/93, four issues rechecked successfully as documented; 23 source maps 201 assertions, first source map 32 OpenGL assertions, legacy 25 maps 9323 assertions, malformed pack 12 assertions. First remote L1J CI failed because its fixture tool encountered existing shipped art. Fixed by separate synthetic subpaths, keeping original-byte protection; synthetic runtime 78 assertions pass. Final CI remains separately inspectable on PR83.

Source pack publication: excluded from public Git because redistribution rights are not established. Uploaded source ZIPs remain the input. Run INSTALL.md to reconstruct locally, or reuse data/l1j/recovered_maps and data/original_maps only after verify_delivery.py passes. Uploaded files SHA all 16 match PR81. No unchanged nested-archive rescans are required.

Next: verify final PR CI, then obtain exact source-edition correspondence for the 25 target IDs and actual tile imagery. Resume only missing gameplay cases on candidate maps; do not turn all 998 catalog entries into completion claims. Do not merge main/other PRs without authorization.
