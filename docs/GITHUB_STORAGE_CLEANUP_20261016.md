# TWILIGHT GitHub storage cleanup — isolated, review-only

Status: **staging only**. Nothing has been deleted from `main` or merged. Do not merge this maintenance branch automatically.

## Safety boundaries

- Source `main` commit: `e2119c37293a783e93b421ee0055d1318271b071`.
- Preserve work on PR #100, #120, #121, #122, including their dependent branches.
- Never modify or prune `assets/`, `data/`, `scripts/`, `scenes/`, `tests/`, `tools/` or their original sources in this cleanup.
- Do not force-push, rewrite Git history, or delete backup/work branches. Old commits, PRs and clone users depend on them.
- `docs/map-remake-20261015/` contains active map baselines; `docs/remake/` contains animation follow-up evidence. Neither is in the deletion scope.
- `.gitignore` additions block **new ad-hoc images in `docs/screenshots`**; Git ignores do not remove existing tracked files.

## Confirmed external archival destination

Private Google Drive destination (folder name): `TWILIGHT_GitHub_검증자료_백업_20261016`. Keep the owner-only link outside the public GitHub repository.

Small GitHub Actions artifact transfer smoke test: completed and verified in the private Drive destination.
- Source artifact ID: `12025895607`.
- Verified Drive file size: `92674` bytes, equal to source artifact size.
- **This is a transfer test, not a backup of the entire GitHub `docs/` folder.**

## Phase 1 snapshot scope (backup before any deletion)

Baseline `main` contents:
- `docs/screenshots/`: 5 tracked files, 9,703,593 bytes.
- `docs/monster-world-evidence/`: 82 tracked files, 26,251,149 bytes.
- `docs/verification/`: 18 tracked files, 13,877,486 bytes.

A short-lived workflow `.github/workflows/twilight-drive-evidence-snapshot-once.yml` runs **only** when its own path is pushed to `maintenance/drive-evidence-20261016`. It archives exactly these tracked roots, embeds file-by-file SHA-256 hashes, and writes a ZIP SHA-256. Workflow artifacts expire after 1 day to minimize storage.

Before proposing any deletion, verify:
1. The workflow finished successfully with `ARCHIVE_OK`.
2. The artifact was transferred to the private Drive folder.
3. The Drive copy has identical size and bytes / archive checksum to the GitHub artifact.
4. Source paths to remove have no runtime or CI dependency, and affected Markdown/manifest links are kept functional.
5. Current main and open PR file paths have not moved since this snapshot.

**No successful archive means no deletion.** First candidate after backup: the five `docs/screenshots/*.png` files if the reference audit remains clean. Keep all source/QA metadata in `docs/monster-world-evidence/` and `docs/verification/` until dependencies are removed and validated.

## Git size reality

The checked-out `main` tree held ~1.36 GiB of files, ~999 MiB under `docs/`. GitHub reported a ~6 GiB repository because history and other Git objects are still retained. Removing tracked media from a new commit does **not** automatically delete old objects or reduce GitHub's reported historical repository size. History rewriting is prohibited while active PRs depend on old commit ancestry.
