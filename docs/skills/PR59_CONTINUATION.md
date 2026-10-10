# PR #59 continuation — 2026-10-10

This file records actual recovery and executable validation. PR #59 remains Draft;
do not merge it or commit to main without the user's separate approval.

Prior completed **code** checkpoint (before the recovery below):
`f318161dedbd4fc0c19ef0a0dd25e6a420200abc`, tree
`3be64c50e581193f0855fad6b82f0a44accf6dcf`.
[GitHub CI run 38048993582](https://github.com/zoog136-hash/-/actions/runs/38048993582)
passed **67/67** checks and actual Godot 4.7.2 OpenGL rendering of all **11**
screens. The later `[skip ci]` evidence-only commit changes this report,
version history and evidence JSON; scripts/data/tests/resources stay identical
to this tested code. The previous two code commits are `3264fec3` and `bbc08e9a`,
whose separate 64/64 and 65/65 CI runs also succeeded.

## Recovery boundary

- Started from remote `b69adeb95b1782b34d56d36c2255bd3616f32b97`,
  `feature/original-lineagem-skill-complete-20261010`, committed at
  2026-10-10 13:31:59 KST. The checkout was clean and had no staged changes.
- This session's initial workspace contained only the 13 reference archives.
  Accessible sibling scratch directories, staging directories and temporary
  directories did not contain the previous uncommitted Turn Undead patch,
  upload manifest or unfinished WAV generation. Those artifacts were **not
  recovered**. The patch below was reconstructed from the actual remote code.
- The committed guardian service and `docs/skills/evidence/guardian-local`
  remain preserved. Existing skill, item and save IDs are retained.
- Main was fetched for comparison (observed `df02a89fd4c5b7c2e59772dcfce492e46495d377`).
  At that comparison the branches differed by 5 feature commits / 194 main
  commits. Both branches modified `scripts/world.gd` and `scripts/monster.gd`.
  The first Turn Undead patch did not modify those files or resolve the PR's existing merge
  conflicts. The later integration must preserve main's NPC/crafting/AI work.

## Reconstructed code

- `skill_service.gd`: dedicated `turn_undead` execution. Validate ownership,
  disable state, target, immunity and cost before spending. Queue an actual
  magic attack, launch one projectile at the motion marker, then calculate and
  roll once at impact. Failure causes no HP loss. Success uses the monster's
  normal damage/death signal path; no weapon lifesteal/critical/on-hit proc is
  attached to instant death. Race and immunity are rechecked at impact.
- `skill_catalog.gd`, `skill_rules.gd`: effect classification and explicit AUTO
  support. Passive Ancient enhances the learned base without a separate cast.
  AUTO consults the resolved skill, including learned upgrade values.
- `skill_vfx.gd`: explicit Vector2 types at the two dynamic draw points,
  separate resist visual and authored base/Ancient motifs. The initial remote
  code parsed successfully; these annotations are reconstructed hardening,
  not proof that the two reported previous-session errors were recovered.
- `curation.json`, generator and linked data: stable research IDs
  `lm_e35a5e1482fc0950` and `lm_09370fb0d313977d`; two small authored SVG/WAV
  resources. Previously blocked equipment Turn Undead associations remain
  blocked; adding a skill execution path does not validate an item proc.
- Learning level, MP, cooldown, range, formula bounds, Ancient bonus +0.12
  and default boss exclusion are **CUSTOM_BALANCE**, not original numbers.
  Unverified base rarity is INFERRED. Original prerequisites remain UNKNOWN.

## Original source verification

- [2022-02-09 official patch](https://lineagem.plaync.com/board/update/view?articleId=6202c4b88a33a923b33364dc):
  hero-grade wizard passive enhancing Turn Undead hit probability; acquisition
  via the second-floor Faith Tower boss. Public official article API body was
  read. `publishedAt=2022-02-08T19:30:00.001Z` is separate from the effective
  patch date, 2022-02-09 KST.
- [2024-07-24 official patch](https://lineagem.plaync.com/board/update/view?articleId=66a004b894228647bc4934a5):
  both names occur in an event skill restriction list. Publication is
  `2024-07-23T19:30:00.001Z`. This is presence evidence, not a formula or a
  complete continuity check through 2025-06-17.
- Previously stored 2022-08-24 and 2024-06-19 announcements were fetched again;
  their publication timestamps precede their effective dates in UTC. Their
  existing verified effective dates were preserved.
- Sources/body hashes and timestamps are stored without redistributing full
  article bodies. Original frame-by-frame art/audio matching remains UNKNOWN.

## Tests actually run before the first new code commit

Official engine: `4.7.2.stable.official.ed1daf0bf`, headless Compatibility.
The initial remote checkout import and boot passed. The early sequential
regression run overlapped reconstruction and is not presented as a pristine
baseline or final full-suite result.

The reconstructed patch passed import plus these **8 suites** in isolated
temporary save directories: `original_turn_undead_test`,
`original_skill_system_test`, `original_skill_catalog_runtime_test`,
`original_skill_summon_test`, `quickslot_smoke_test`,
`stage5_save_compatibility_test`, `original_lineagem_effects_smoke_test`, and
`combat_vfx_test`. Result: **9/9**. Data/graph validator: **0 errors**.

Turn Undead: **61 assertions**, including book learning, normal/undead targets,
explicit immunity, no premature HP loss, real projectile impact, failed and
successful roll, cooldown/duplicate cast, actual AUTO slot, changed race,
class-change cancellation and save/load of IDs/slot/AUTO/cooldown.
Both 100,000-trial samples use production `turn_undead_chance()` and
`roll_turn_undead()` rather than an independently copied formula:

| Variant | Expected | Measured | Trials |
| --- | ---: | ---: | ---: |
| Base | 0.386 | 0.38805 | 100,000 |
| Ancient | 0.506 | 0.50701 | 100,000 |

These are local balance results for a specific fixture, not NC probabilities.
The first test attempt incorrectly used the void quickslot callback as a bool;
that test parse error was corrected before the passing rerun. No production
failure is hidden behind that earlier failed attempt.

Current counts: **695 audit assignments / 125 PARTIAL runtime records
(63 active, 62 passive/upgrade), 568 BLOCKED, 2 PVP_EXCLUDED**. UNKNOWN original
fields are still UNKNOWN. No skill is declared COMPLETE.

## Second code checkpoint: audio, stable slots and stale targets

The first reconstructed code is published at
`3264fec3e961a3fbd59c79a8ad6c515e131ad6da`. The local equivalent
`5fa77a9127196bc6a31a65cd7917e0aa92ff0dfd` is preserved by a local tag;
both trees are `ffd5064a083b06ab50ba001500a7089dadae1776`.
Plain Git push had no credentials. Authenticated Git data publication compared
every blob and the full tree, then advanced only the existing feature ref with
an expected-head check and no force. Main and the PR's Draft state are retained.

That exact first GitHub SHA passed [push CI run 38046643647](https://github.com/zoog136-hash/-/actions/runs/38046643647):
**64/64 checks**, actual Godot 4.7.2 OpenGL rendering, eight 1280x720 captures,
one real guardian attack and one damage-triggered shield conversion.

The second checkpoint changes:

- `scripts/skills/skill_audio.gd` and `skill_vfx.gd`: bounded six-voice audio
  pool now plays cast, status, impact and resist phases. Pitch/volume distinguish
  phases; denied casts emit no sound. The audio path runs before the optional
  VFX budget check and clears active voices on combat/map/class cleanup.
  Audio resources are authored approximations, not verified original recordings.
- `skill_service.gd`: save the target's `life_id` at queue time and validate it
  at both release and impact. A respawned NPC cannot receive an attack or an
  instant-death RNG roll belonging to its previous life.
- `scripts/world.gd`: a limited 17-line change stores original skill IDs when
  assigning slots and uses those IDs for manual, combat, heal and buff AUTO
  lookup. Original displayed names are canonicalized separately. The known
  overlap with main remains unresolved; this change does not integrate main's
  NPC/crafting/AI code.
- `tests/capture_original_skills.gd` and CI: require actual paid Turn Undead
  cast, animation-marker release, pending projectile with unchanged HP, and
  real Ancient impact/death. Capture output can be redirected outside the repo.

Tests actually run on this second checkpoint:

- Targeted **8/8** suites passed, including **67** Turn Undead assertions and
  **392** audio assertions covering all 125 WAVs and the six-voice pool.
- Complete isolated-save Godot 4.7.2 suite: **65/65 passed**, with no failed
  checks. This includes import, boot, movement, combat, drops, inventory,
  equipment, NPC/world portals, AUTO, passive skills, class/slot and save tests.
- Production-path probability sample: **200,000** trials with the same
  expected/measured results listed above. Data validator: **0 errors**.
- Actual local OpenGL llvmpipe render: **11** 1280x720 captures, guardian
  hit/shield and Turn Undead `hp=0 mp_spent=20 audio_phase=impact`.
  New learning, projectile and Ancient impact PNGs were visually inspected.
  Unix-socket X11 setup failed; supported local X11 TCP transport succeeded.
  Dummy audio verifies resource playback events, not listening quality.
  The software-render sample ran alongside regression tests; its timing is
  not a hardware FPS claim. CI is configured to retain the new screenshots,
  rather than duplicating multi-megabyte generated images in the Git history.

Machine-readable summaries, text logs and screenshot hashes are in
`docs/skills/evidence/pr59-continuation`.

The exact second code SHA is `bbc08e9a589ce4426ef26fe83282e7d630ea870a`;
[CI run 38047604342](https://github.com/zoog136-hash/-/actions/runs/38047604342)
succeeded with **65/65** checks and all **11** actual OpenGL captures, including
the real Turn Undead death marker. Artifact ID `11668700984`, SHA-256
`1059921f5f5fdd40da03e0ad720e79f1ba90fba3ef5370eb8bcb99c028ec307c`, is recorded
with its expiry in `github-ci-second-artifacts.json`.

## Third code checkpoint: state lifetime, AUTO and visible class

- `scripts/hud.gd:set_character_state()/update_player()` and
  `scripts/hud_v20.gd:update_player()` use the authoritative class name.
  HP/MP-only combat refresh no longer turns every class label into knight.
  The same hardcoded lines were checked in latest main before the minimal edit.
  The existing lightweight combat HUD path remains covered by its regression.
- `scripts/world.gd:_sanitize_quickslots_for_current_job()` now resolves the
  stable skill ID and repairs an old displayed name. The slot's AUTO flag and
  skill ID survive skillbar refresh, rather than only direct click/cast.
- `status_service.gd` and `skill_service.gd`: modifier/mark entries are tied
  to `life_id`, checked during lookup, ticking and reapplication. Actual pooled
  NPC `setup()` resets cannot carry a previous life's MR/AC/DG modifier,
  third-hit mark burst or modifier duration into the new life.
- `status_service.gd:can_affect()` is shared by actual status application and
  AUTO selection. AUTO skips explicit immunity and 100% resistance without
  MP/cooldown/RNG expenditure. Manual status probability and cost semantics
  remain as before; this is not a new original hit formula.
- `original_turn_undead_rewards_test.gd` connects the NPC's real death signal
  to the same world handler as field monsters. Failed and successful real
  paid casts validate XP/Adena/quest/ground loot, no weapon HP absorption,
  duplicate-callback safety, pickup and save/load of reward/skill/slot/cooldown.
  Fixture seeds are selected using the production Turn Undead and loot helpers;
  neither probability table is replaced or copied.

Third-checkpoint focused tests: **10/10**, including **69** Turn Undead checks
and **200,000** trials, **19** pooled-target/AUTO checks, **24** reward checks,
all 13 job changes, combat HUD, audio, catalog, save and quickslot regressions.
Actual local OpenGL rendering again passed **11** captures and guardian/Turn
Undead markers; the final impact image was inspected and visibly retains the
wizard class label. Data validator has **0 errors**.

The local sequential full runner finished **66/66 passed** with no failed checks.
It enumerated its scripts before the new rewards fixture was added; no
production source was changed during that run. The rewards fixture passed
separately with 24 assertions. The subsequent exact-code GitHub run finished
**67/67 PASS** with no failed checks and all 11 actual OpenGL captures. It
included both new state and reward suites. Artifact ID `11669215009` contains
the individual test logs and PNGs (SHA-256
`5897e9608dac858dc78522e7b95958b6cc7f6db784c073666da82ef90b427d1b`,
expiry 2027-01-08). Metadata/check names/render markers are committed in
`github-ci-third.json` and `github-ci-third-artifacts.json`.

Failures are preserved, not counted as passes: the new pre-fix class regression
reported 24 label failures; stable-slot refresh and old-life mark/duration tests
also failed. The first target-state fixture changed the catalog dictionary but
the world casts a deep copy; its intended forced-success setting did not reach
that cast. The two impact assertions initially failed because of this test
fixture error. The fixture was corrected to configure the actual world cast
record, then the production-path test passed. No production status formula was
changed to make that fixture succeed.

Main comparison was refreshed to `1947469b4bd817ffd2b1c9e42ac28c90d154c25b`.
A read-only merge-tree simulation from `bbc08e9a` found one textual conflict in
`scripts/world.gd:_load_game()`: original-skill pre-migration save backup versus
main's warehouse/crafting-log restoration. Any later permitted integration must
retain the backup guard **before** restoring warehouse/crafting state; choosing
only one side loses a system. Monster and HUD changes merged automatically in
that simulation, which is not an engine validation of a merged project. No
merge was performed and main was not changed.

## Next execution

```sh
git fetch origin feature/original-lineagem-skill-complete-20261010
git checkout feature/original-lineagem-skill-complete-20261010
git pull --ff-only
git status --short
git log -4 --oneline
python3 tools/validate_original_skills.py --report test-results/data-validation.json
python3 tools/test_project.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --logs test-results
```

Start from the existing branch, compare local changes before pulling, and keep
an isolated `XDG_DATA_HOME` for manual engine tests. For actual render evidence,
set `TWILIGHT_SKILL_CAPTURE_DIR` outside the repo and run
`--audio-driver Dummy --script res://tests/capture_original_skills.gd` with a
working OpenGL display. Public fetch works here; plain Git push lacks credentials.
This session published through authenticated Git blob/tree/commit/ref APIs,
verifying exact local hashes and the expected remote parent without force.

Next actual paths after the recovery below: `scripts/skills/skill_catalog.gd:learn()/resolve()`
for the remaining ownership/weapon/upgrade audits; `scripts/skills/status_service.gd:apply()`
for the unverified policy when different debuffs coexist; then dated class effects in
`data/skills/research_inventory.json`. All **568 BLOCKED records** are the explicit
unfinished list: **549** need pre-cutoff effect/PvE verification; **19** need historical
rename/rework/continuity verification. The first record is knight `데몬 대시`, stable
ID `lm_bf27d9216c1bd228`; its PvE and historical presence remain UNKNOWN. Check official
dated descriptions before activating it. Original videos, undocumented learning/cost/
formula/prerequisite values and Windows physical playthrough remain unfinished.
The session does not develop automatically after it ends.

## Recovery resumed — 2026-10-11 KST

Remote evidence HEAD `2194242d18e68c19c82d4ffe6917c2197eb73059` and the prior
`f318161d` CI job were verified. No accessible PR59 uncommitted files were found;
the other accessible checkouts contain separate map/resource work and were left
untouched. The cause of the unresponsive session is **UNKNOWN**. The same existing
branch was checked out, without resetting another task or deleting its results.
Sixteen attached ZIP central directories can be opened, including all four newly
split ZIPs. Only the original `a2(1).zip` was not delivered into this workspace;
complete equivalence of its splits was not established. The current code fixes
use the existing checked-in skill data and do not depend on that original ZIP.

The next documented unfinished work was implemented, without adding skill names
or declaring any record COMPLETE:

- `status_service.gd:damage_after_reduction()`, `skill_service.gd:target_damage()`
  and one line in `world.gd:_deal_successful_player_hit()` consume the previously
  ignored `reduction` field of Dark Stun and Thunder Stun. Their existing **-3
  CUSTOM_BALANCE** value is an explicit flat +3 received-damage modifier after
  critical/weapon amplification and before HP absorption. This is an offline
  fallback, not an original NPC defense formula. Normal player hits, original
  damage skills and equipment procs share one application; Turn Undead's exact-HP
  death path bypasses it. Existing lifetime/respawn and cleanup checks still apply.
- `renewal_skills.gd:select_original()` displays per-field original confirmation,
  inference, unknown fallback and TWILIGHT settings beside grade, activation,
  stage, learning level, book and price. Original acquisition is displayed apart
  from the local book shop. This does not unlock unlearned/passive skills.
- New actual-engine suites `original_skill_reduction_test.gd` (35 assertions)
  and `original_skill_provenance_test.gd` (13 assertions) first reproduced **8
  damage failures / 10 UI failures** before the production patch, then passed.

Validation actually finished on this successor to `2194242d`: Godot 4.7.2 full
**69/69 PASS**, focused **8/8 PASS**, data **0 errors**, actual OpenGL **11 PNGs**,
guardian hit/shield and Turn Undead **HP=0 / MP spent=20**. The learning PNG was
visually inspected. Full validation includes 200,000 production-path Turn Undead
trials. Isolated XDG save directories were used. Detailed checks, pre-fix failures
and screenshot hashes are in `evidence/pr59-resume-20261011/verification.json`.
Linux llvmpipe timing and Dummy audio do not prove Windows performance/listening.
The 125 PARTIAL / 568 BLOCKED / 2 PVP_EXCLUDED counts remain unchanged.

Latest observed main is `88d1c68e2a497fb540461a3e1dfa6cba2e1d38f4`. A read-only
merge simulation identified one textual conflict in `_load_game()`, between the
old-save backup guard and warehouse/crafting restoration. Continue by saving this
verified patch on the existing PR, then integrate that main **into this feature
branch only**, preserving the backup guard before both restoration paths. Add a
joint persistence regression and rerun the merged project's complete suite.
Do not merge PR59 into main. All 568 blocked research records, original visual
verification and the remaining condition/upgrade audits are still unfinished.


## Current-world integration on the same feature branch — 2026-10-11 KST

The new reduction/provenance code was published as
`8935ef6c86f7a13b07930bc26add7dfbe66d6cd0`, exact tree
`987ebf7dc2025f0f98c7f8e84d199ef23560463b`. Its [GitHub push CI](https://github.com/zoog136-hash/-/actions/runs/38065103681)
completed **69/69 + actual OpenGL 11 captures SUCCESS**. Every new blob and the
whole tree were compared with local checkpoint `c3f798c`, retained by local tag
`checkpoint/pr59-resume-first-c3f798c`. Authenticated API publication advanced only
the existing feature ref, with an expected-parent check and no force.

Main `88d1c68e2a497fb540461a3e1dfa6cba2e1d38f4` was integrated **into this same feature**.
Main itself and other resource/map checkouts were not modified. The only textual
conflict was `world.gd:_load_game()`. Both sides are preserved: create/check the
pre-original-skills save backup first, then restore warehouse and crafting history.
The main AI/movement/SPX/crafting/shop/drop work and the original skill services
remain in the resulting tree; this is a merge, not a replacement of one side.

New `tests/original_skill_warehouse_migration_test.gd` ran **23 assertions** on real
save/load: learned stable ID, AUTO slot, cooldown, actual paid shield buff, stored
physical ID/enchant/element, crafting history and gold. It also checks the exact
old-save backup, no overwrite on later migration, and complete non-mutation of
warehouse/crafting/character/source-save when the backup destination is unwritable.
That deliberate native copy error is suppressed only inside its expected-failure
fixture. Actual unexpected engine errors remain fatal to the runner.

The initial joint fixture reported four comparisons as failures: JSON reloads
integer literals as floats (5 becomes 5.0). Diagnostic output confirmed the correct
persisted values. The fixture now compares JSON values; no production storage
behavior was altered to make those comparisons pass. The first merged full run
was **91/94**, missing only three L1J positive-path fixture inputs. The existing
main runner creates those synthetic inputs only in CI mode. All destinations were
confirmed absent before enabling that mode, and the original generator refuses
collisions. No private data/art was overwritten, no test was skipped, and no
passing condition was relaxed.

Final merged validation actually completed: **94/94 PASS** with the existing CI
preparation, data **0 errors**, actual OpenGL **11 captures**, guardian hit/shield
and Turn Undead **HP0 / MP20**. The learning screen was directly inspected. Core
movement, AI, 125 skill records, 200,000 production probability trials, inventory,
physical equipment, warehouse, crafting, shop, loot, portals and old/current save
checks are included. Synthetic L1J fixtures test adapters; they are not evidence
of restored original art/maps. Temporary save directories protect player saves.
See `evidence/pr59-resume-20261011/integration-verification.json` and the first
published code's `github-first-ci.json`. Windows physical play and original audio/
video fidelity remain unverified. Skill counts stay **125 PARTIAL / 568 BLOCKED /
2 PVP_EXCLUDED**; this is not complete original skill implementation.

Next recovery: check `git status --short` and save any local changes first, fetch
the existing feature branch, then fast-forward only after comparing its tree. Run
`python3 tools/validate_original_skills.py --report test-results/data-validation.json`.
For a clean checkout without private L1J assets, reproduce the existing CI setup
with `GITHUB_ACTIONS=true python3 tools/test_project.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --logs test-results`.
Do not generate over an installed private pack. Render with an isolated XDG data
directory and `TWILIGHT_SKILL_CAPTURE_DIR` outside committed sources. Continue
`skill_catalog.gd:learn()/resolve()` audits and official dated/PvE verification of
the explicit blocked inventory. Do not activate UNKNOWN effects, add PvP-only
mechanics, merge PR59 into main, or claim unattended development after this session.
