# TWILIGHT CI phase 2: trusted import-cache readers (2026-10-26)

Base main: `d77003ccf34888bc083dc9ecc8467883eb079a72`. Follow-up to merged PR #160.

## Narrowly scoped reuse

Five real-game-data Linux checks restore the **same** Godot 4.7.2 import cache already produced exclusively from trusted `main` by `Godot Validate`:

- TWILIGHT Local Crafting
- TWILIGHT NPC Dialogue Branches
- TWILIGHT Atomic Crafting
- Original Skill Migration Validation
- TWILIGHT Integration Validate

The existing key is `twilight-godot-import-4.7.2-linux-compat-main-v1`; paths are only `.godot/imported` and generated `**/*.import` metadata. Readers use `actions/cache/restore@v4` with `continue-on-error`. They never save, upload, trust PR-created caches, or copy gameplay source/secret files. Cache absence or restore failure leaves the original import and tests running exactly as before.

**No existing checks, commands, tests, validation conditions, warnings, evidence uploads, timeouts, filters, job names, or branch protections are removed or bypassed.** Every source change still flows through Godot's original reimport/parse and all gameplay/render checks. No cache is restored in synthetic fixture, isolated L1J, platform-specific Android export or PR #157/#158 branches by these edits.

## Safety / expected gain

Only main's successful full `Godot Validate` workflow writes the immutable cache, subject to the existing 1.5 GiB cap. Until that trusted main run succeeds and actually publishes this key, these restores are **cache misses** and may add overhead rather than accelerating CI. This patch makes no claim about measured savings or queue times; it does not alter GitHub-hosted runner concurrency or 40+ workflow fan-out.

The original PR #160 workflow contract validator is extended with an exact allowlist and strict insertion/name/key/path/read-only/ordering assertions for just these five readers. The validator still expands existing composite actions, checks 80 original workflows against the pinned baseline, checks that tested steps are unchanged, and rejects all unrelated workflow changes. New unit tests cover tampered keys, moved readers, reduced test commands, and additions outside the allowlist.

## Validation and rollout

1. Run `python3 -m unittest discover -s tools/ci -p 'test_workflow_refactor.py' -v`.
2. Run `python3 tools/ci/validate_workflow_refactor.py --baseline-ref bddfbb9725891dd2dcbdb5f2b774d91c499aa856` with the required git history and PyYAML available.
3. Compare cache hit/miss and end-to-end Godot import durations on representative future PR checks. Revert the **five restore steps** if cache-transfer overhead exceeds the observed import savings; do not skip any tests.
4. Only merge after the relevant checks pass and the branch is conflict free. No automatic full CI dispatch or pre-existing PR mutation is part of this patch.
