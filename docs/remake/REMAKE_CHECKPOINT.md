# TWILIGHT remake checkpoint — 2026-10-13

Status: scoped integration implemented; whole remake incomplete. No user visual approval, no main merge.

- Branch: `feature/twilight-remake-20261013`; open draft PR [#98](https://github.com/zoog136-hash/-/pull/98).
- Independently queried main / baseline: `434b904d957fd2146b6d2e73325693a402028035`.
- Latest production commit: `c79955089704f59edfb01d86a2e0daf128fffb2e`, pushed to the existing PR branch. Prior recording production commit: `b81c8f16e77fd747fd2ec8f5e5a664f587c1a1d6`.
- Existing PRs #96/#97 and other branches preserved; selected runner/item fixes reused with attribution. No reset, force push, deletion of uncommitted work, or merge.
- Engine: official Godot 4.7.2 Linux x86_64, verified official SHA512 and ZIP CRC; Compatibility preserved. No Daybreak capability invoked.

## Completed changes

Shared actor attack timeline and large-delta strike pose; cancellation/death lifecycle; immutable boss attack geometry; pooled-life guards for attacks/projectiles; one-shot reward claims; self-area skill uses the same strike signal; cast speed affects cooldown. Presentation settings reach actual live actors/VFX/projectiles. World input excludes UI/touch events. Item rarity motion respects visibility/reduced motion. Native source-ID icon rejection retained, with three exact local potion icons restored. Canopy/roof occlusion and tall-prop viewport retention improved. Population avoids duplicate live slots/boss keys. Research media excluded from import/export without deleting it.

Call paths: `Main.tscn -> scripts/world.gd -> Player/Monster scenes`; `animation/actor_motion.gd` emits strikes; world queues resolve actual damage/flight contact. `maps/field_population.gd`, DB catalog and boss director retain spawns/drop identities. Ground-loot manager and pickup controller own floor items; world instance enhancement and save writer keep saves. `renewal_hud.gd` connects UI signals to world. Runtime VisualManifest/AnimationCatalog keep bounded caches.

## Verification available

- Pre-edit and current resource integrity: PASS, 723 generated WebP / 41,442 cells / 233,420,026 bytes; originals remain not delivered.
- All-ID runtime audit regenerated after potion fix: classes13, transforms413, dolls166, relics144, normals258 (149 spawn-referenced), bosses60 (28 spawn-referenced), maps25, merged items2576, effects125. All have effective load/fallback paths. No per-ID visual completion or dedicated original motion claimed.
- Genuine matched Main game recordings: 20.033s / 601 frames / 34 assertions each; eight-direction input, native Drake warning/hit, three manual plus nine AUTO attack cycles, unchanged520HP death, naturally earned floor drops, manual potion + AUTO ore pickup. Recording commit predates potion fix; follow-up focused icon test16 and item audit6445 pass.
- Baseline full suite:139 executed,122pass/14fail/3skip. Feature full suite147 executed,130pass/14fail/3skip. Two new result/expectation failures were corrected by tests-only c5e8783 and passed targeted29/16/95checks. Remaining12existing failed tests and feature540s regional timeout unresolved; keep all raw failures.
- New focused tests already passed: actor lifecycle158; boss geometry693/60bosses; world lifecycle21; all maps2264; population9; readability42; item visuals6445; native UI input399; per-instance/save tests have preserved logs.
- Five authorized Drive references have size/SHA256/CRC verification. Two PC Lineage actors21624/21653 provide3512 source frames; ticks/hit offsets independently checked, including41,346 diagnostic assertions. Bodies are research-only; identity/directions/clock/rights unconfirmed. No redistribution into game.

## Processes and evidence

Both full suites and all bounded follow-up engines have finished. No further suites or background resume scheduled. Old zombie children are not running work. One stale source diagnostic was terminated after ownership verification, with cleanup evidence. No automatic future resume promised.

Raw logs: `/workspace/evidence/{baseline,feature}`. Selected delivery evidence: `docs/remake/evidence/`. Production research originals: `/workspace/research`, outside Godot project. Independent clean GitHub clone: `/workspace/twilight-clean`, integrity passed at c799550; cold import208.025s, Main boot15.098s, world lifecycle21 checks passed, all exit0/error-free. Runtime files unchanged by tests-only c5e8783. Test-generated docs/images in working trees remain untouched; uncommitted ledger/docs preserved.

## Completed evidence and remaining action

- Matched recordings are copied into `docs/remake/evidence/production-play`; recording production b81c8f1 and later potion-HUD c799550 kept distinct. Selected4PNG plus movies/JSON delivered; other18PNG remain only local.
- Matched baseline/feature performance run once sequentially after engines finished: frame p50 51.797→55.780ms, p95 81.246→89.223ms; Godot allocator peak385688421→403857607B. Boot draw26.455→23.643s. No60fps/overall improvement claim; process RSS/device/package size unverified.
- Final focused test code c5e8783: UI29/localicons16/L1J95 passed through actual suite parser; final GL potion screenshot17checks passed. Source-ID catalog UI precedence and reviewed ground binding are independently checked.
- Clean GitHub source reproduction passed without /workspace/research or worker import cache; exact runtime source c799550 remains authoritative. See REPRODUCE.md, VALIDATION.md and evidence SHA256SUMS.
- Test-generated docs/images in existing working tree paths are deliberately uncommitted and untouched. No reset/deletion. Only intended ledger/remake docs/evidence and README are staged for delivery.

Next work on same PR:

1. Profile feature world_regions18th map/540s timeout; resolve baseline12failed tests without bypassing assertions or installing fake source completion. Review failure logs before rerunning only changed cases.
2. Fix existing boss/target bar and natural growth-panel/pickup occlusion; obtain real user visual approval. Current quality matrix in VALIDATION.md remains fail/unverified in several areas.
3. Apply only licensed identity-matched articulated2D source frames per ID. Missing dedicated8direction/body/weapon/shadow/actions remain; do not cover all entities with actors21624/21653.
4. Improve measured combat frame time/memory; record process RSS/actual GPU/package size with matched conditions. Current Linux software-render data is not Android performance.
5. Android SDK/4.7.2 templates/device missing; APK build, boot and touch play remain separate unverified steps. Windows device performance and user's actual save-copy regression unverified.
6. Keep original_* not_delivered and the single current-ID ledger authoritative. Do not merge main without required checks and user approval.

Next supported commands:

```sh
git status --short
git log -3 --oneline
# read docs/remake/VALIDATION.md and evidence/feature-comparison.json first
# run only the changed regression case using the official Godot4.7.2 binary
# no full-suite retry without a diagnosed and changed cause
```
