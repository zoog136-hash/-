# PR100 final STOP preservation, 2026-10-15

Read [PR100_FINAL_HANDOFF.md](../../../../PR100_FINAL_HANDOFF.md) before any future work. User stopped production; no new generation, game tests, branch or PR was started as part of final preservation.

Qualified: **392/498 (78.7%)**, remaining **106**, including **18 HOLD**. Main individual121/canonical255. Automation passing for Main32 does not qualify its two actors; final independent actual Main visual review is pending.

- `remaining106.json`: every unresolved target ID/name/classification/status/source SHA/exact resume location.
- `source-archive-inventory.json`: immutable55 authoring package files,984260151 bytes. Original images, prompts, rejected attempts, stop markers and SHA indices remain exact. Restore chains are in the final document; the tomb CAS packages have their own restorers.
- `runtime-evidence/`: all925 previously uncommitted runtime/Main32/import/preflight files,1125428584 source bytes, split lossless tar.zst685662735 bytes. Ordered parts, full SHA and every member SHA are in `pending-runtime-manifest.json`. All925 member bytes were stream-verified before pending folders were parked; no full disk restore of the final helper was claimed.
- `runtime-evidence/restore_pending_bundle.py`: requires Python>=3.9 and zstd. Restore only into a NEW EMPTY evidence directory outside production. Does not import or apply any archived profile. Former absolute output paths need deliberate SHA-based mapping in the future work environment.
- `parking-and-qualified-wiring.json` (inside runtime-evidence): exact HOLD moves and profile hashes. Completed assets moved/replaced0; no reset, clean or force push.
- `remote-observation.json`: historical22:22 observation. Latest391 CI is `final-CI-observation.json` at22:34:40: Android/Godot/resource SUCCESS; Animation CANCELLED40success/1cancel/0failure. No rerun or dispatch after stop. Latest392 full CI NOT RUN; Android real device UNVERIFIED. APK artifacts remain on GitHub with recorded expiry, not duplicated in this package.
- `preservation-manifest.json`: SHA/size for every deliverable under this directory except itself and regenerable __pycache__. Does not include itself to avoid a self-referential hash.

Archive members and indices are evidence, not automatic completion. Keep PR100 open/draft and preserve existing maps/assets. Future proposed branch `feature/twilight-animation-remaining-20261015` is NOT CREATED here.
