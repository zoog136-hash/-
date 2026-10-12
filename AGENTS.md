# TWILIGHT — Mandatory agent preflight

When working on this repository, read `TWILIGHT_PROJECT_RULES.md` and `docs/RESOURCE_INTEGRITY_POLICY.md` before changing files. The newest `main` is the source of truth; preserve prior commits, branches and user save data.

- **Never report "all original resources integrated"** because scripts, manifests, fixtures, GitHub CI or fallback art work.
- Before editing run `python3 tools/check_resource_integrity.py --root .`. When uploaded original ZIPs are needed, separately run `--source-dir`; if they are unavailable in this Work environment, stop that original-art step and report the exact blocker. Do not re-request files that are already accessible.
- Commit binary art that this repository is permitted to contain. Prove the real files are tracked, present and SHA-256 matched. Never silently exclude output in `.gitignore` and then report it delivered.
- Original Lineage game art is third-party material: confirm redistribution rights, preserve allowed private packs durably, and verify the actual pack via `--release-dir` instead of leaking originals to a public repository.
- Each Work environment is ephemeral. Record finished commit SHA, verified output paths, SHA and missing assets. If output transfer fails, status is **not delivered** even if local rendering succeeded.
- Changes go via feature branch/PR. Do not merge to main without user approval and passing CI.
