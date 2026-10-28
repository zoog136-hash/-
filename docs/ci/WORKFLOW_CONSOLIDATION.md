# TWILIGHT GitHub Actions consolidation — 2026-10-28

Active workflows: **10** in `.github/workflows`. Previous complete workflow
snapshot: `docs/ci/workflow-archive-20261028/` (**84 original YAML files**,
unchanged Git blob identities; no gameplay assets copied).

The prior 84 workflows frequently created dozens of simultaneous resource
imports, despite one successful run measuring 3,867,700,560 imported bytes and
774 seconds. The archived workflows are **not** executed by GitHub Actions.

## Kept
- `resource-integrity.yml`: tracked source/asset/attribution integrity.
- `ci-consolidated-preflight.yml`: offline CI contracts and focused map,
  inventory, rendering-resource, animation metadata and source verification.
- `godot-validate.yml`: real Godot smoke, world/physics and trusted-main PNG
  importer cache publishing after successful validation.
- `twilight-integration-validate.yml`: full runtime/discovered Godot test suite,
  including UI, combat, maps, shops, monster systems and existing gameplay tests.
- `animation-presentation-validate.yml`: actual eight-direction animation,
  presentation, sprite audits and real captures when related code changes.
- `twilight-android-playtest-apk.yml`: real Android ARM64 export for game changes.
- `l1j-runtime-validate.yml`: L1J integration; Linux on PR, Windows available
  for explicitly requested full manual validation.
- `godot-import-cache-contract.yml`: focused, fast importer/cache contract.
- `main-debug-audit.yml`: **manual only** deeper four-way debug. Ordinary PR
  runtime assertions are already covered by integration.
- `cancel-superseded-pr-ci.yml`: cancel obsolete PR commit runs only.

## Coverage boundaries
Game test scripts remain in `tests/` and the full test runner discovers them.
The consolidated preflight explicitly runs source and map/asset unit checks.
Legacy one-time production/review/recovery jobs whose behavior cannot be safely
automated without their prior context remain archived, **not silently claimed
as completed**. They must be explicitly reviewed before being reintroduced.

Importer caches are untrusted on PRs for publishing: only a successful trusted
`main` Godot run can write the four PNG cache shards. Every PR still performs
its own actual engine import, runtime assertions and failure reporting.
