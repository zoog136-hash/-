# PR122 — local-only SPX transform candidate trial (142, 411)

This commit adds an explicitly optional *visual comparison* of two transformation IDs with two source SPX actors. It does not approve a character-identity match.

| TWILIGHT transform | Private SPX | Evidence | Decision |
|---|---|---|---|
| transform:142 신화-투사(남) | 21624 | The actual male source frame was not accessible for an accurate side-by-side review in this session. | NOT VERIFIED; default art retained |
| transform:411 신화-투사(여) | 21653 | Private source Main preview shows a pale-haired armored figure, but the 411 TWILIGHT atlas has a prominent red-flaming sword and distinctly different gold/black armor. | VISUAL MISMATCH; default art retained |

Use Settings → **PR122 투사 변신 SPX 비교 · 미승인** in a private install with the complete locally available SPX chain-sword pack. Each ID has a separate disabled-by-default checkbox. A missing pack, missing 8-direction chain tracks, or absent verified foot/canvas metadata disables that option. Disabling it immediately restores the original transformation art.

Only drawing changes in this review mode. Do not change combat, speed, hit timing, collision, class selection, saved gameplay data, or PR122 approval ledger. Completed count remains 399/498; neither candidate is complete.

The public commit includes code and evidence text only. Private SPX/PNG/CSB/OGG, Main video, extracted frames and private archives are excluded. No redistribution or commercial license has been verified. Native visual quality on Android, exact image similarity and private-pack Godot runtime verification remain untested by this public CI.
