# Preview only: old screenshots and legacy import logs

**Not approved to merge. This is a non-production preview branch.** GitHub main, all active PRs, and the source branch `maintenance/drive-evidence-20261016` remain untouched. Do not merge until Google Drive has an independently verified full-byte archive of the removed files, and CI/reference checks pass.

Source: `main` commit `e2119c37293a783e93b421ee0055d1318271b071`. Source files can be restored without a force push or history rewrite by checking out these exact paths from that commit.

Scope: five stale general field captures (the current `tests/capture_field.gd` writes fresh outputs under `user://field-review` and does not load these images); two verbose legacy import logs without discovered code/Markdown direct links. Screenshots serving as active map/art evidence are explicitly **not** removed.

| Path | Raw bytes | Git blob SHA-1 |
|---|---:|---|
| `docs/screenshots/01-village.png` | 1987684 | `0f96a86d538e7f9a67998406926304f14af61b36` |
| `docs/screenshots/02-meadow.png` | 2048486 | `7a4ecf1ec493871bf5a2448c05f4eb9363ed7814` |
| `docs/screenshots/03-bridge.png` | 1663929 | `504d1bf5503daafd84de19d4c25991df4835a346` |
| `docs/screenshots/04-ruins.png` | 2019281 | `b6f2d95289d71bfd3fcaca088b2991c82e5fde12` |
| `docs/screenshots/05-forest.png` | 1984213 | `983ae2c315b4e7be2bd4fd5847fc7c76b9645d88` |
| `docs/monster-world-evidence/logs/import.txt` | 550633 | `84faef5574c3a36304f32b04a2f8831390b9e079` |
| `docs/monster-world-evidence/logs/hud-baseline-import.txt` | 550575 | `6ad0ef1b2f72ce7856225afe988212b814d5f145` |

Total candidate bytes: **10,804,801** (about 10.3 MiB). These are **logical worktree bytes**, not guaranteed Git object storage savings.

## Merge gate

1. Complete the original full-byte archive including both `docs/screenshots/` and `docs/monster-world-evidence/logs/`.
2. Upload the original-byte ZIP to the private Google Drive backup folder.
3. Compare every archived file's Git blob SHA and full archive hash; verify Drive download/retrieval.
4. Check `main` diff strictly contains only these seven deletions and narrow safety documentation/ignore rules; no runtime / CI input deleted.
5. Resolve current PRs independently; do not change their base or branch heads; verify Godot and key regressions before proposing merge.

**If any check is missing, keep this preview unmerged.** Do not delete historical branches or Git objects.
