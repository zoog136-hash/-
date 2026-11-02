# TWILIGHT — Mandatory agent preflight

When working on this repository, read `TWILIGHT_PROJECT_RULES.md` and `docs/RESOURCE_INTEGRITY_POLICY.md` before changing files. The newest `main` is the source of truth; preserve prior commits, branches and user save data.

- **Never report "all original resources integrated"** because scripts, manifests, fixtures, GitHub CI or fallback art work.
- Before editing run `python3 tools/check_resource_integrity.py --root .`. When uploaded original ZIPs are needed, separately run `--source-dir`; if they are unavailable in this Work environment, stop that original-art step and report the exact blocker. Do not re-request files that are already accessible.
- Commit binary art that this repository is permitted to contain. Prove the real files are tracked, present and SHA-256 matched. Never silently exclude output in `.gitignore` and then report it delivered.
- Original Lineage game art is third-party material: confirm redistribution rights, preserve allowed private packs durably, and verify the actual pack via `--release-dir` instead of leaking originals to a public repository.
- Each Work environment is ephemeral. Record finished commit SHA, verified output paths, SHA and missing assets. If output transfer fails, status is **not delivered** even if local rendering succeeded.
- Changes go via feature branch/PR. Do not merge to main without user approval and passing required CI.
- Transition gate approved 2026-11-02: required CI is `Core runtime, save preservation and resource paths` plus `Verify committed assets, manifest SHA, and delivery status`. The core gate must load actual Main/current source-map classes, preserve save bytes/progression/collection and boss state, reject missing packs safely, and fail on parsing/runtime/resource errors. Do not skip these failures or call fallback art an original-resource delivery.
- Historical Native PNG map contracts, detailed authored-animation checks and full visual/gameplay suites remain intact as explicit `workflow_dispatch` audits after integration. Their cancelled/unrun status is not a passing result or visual approval. Do not silently delete assertions, invent original assets, or change branch protection to evade a gate. If remote protection requires different checks, report the configuration mismatch rather than bypass it.
