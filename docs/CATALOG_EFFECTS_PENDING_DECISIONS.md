# TWILIGHT catalog effects, staged PR 2 (2026-10-08)

## Integration boundaries
- Based on the isolated item-option branch `codex/item-options-runtime-20261008` (PR #6), not Astra's map branch.
- Do **not** merge this PR into `main` until its parent PR has been merged and Astra's latest main is checked.
- Only edits `scripts/world.gd`, new catalog interpreter, test, workflow and this document.
- Does **not** touch `scripts/maps/*`, `data/maps/*`, `scripts/monster.gd`, movement/navigation, item drop logic, HUD layout or animation assets.

## Explicit effects supported
1. Transformation **attack speed** from exact `공격 속도 +N%` descriptions, with typed `attackSpeed`/`attack_speed` field overriding the description. The actual normal-attack interval and character attack animation speed already consume this value.
2. Catalog `atk` values now apply to the corresponding **근거리 / 원거리 / 마법 / 만능** style instead of silently granting every kind of physical attack. Where the description explicitly gives `근거리 대미지 +N`, `원거리 대미지 +N`, `마법 대미지 +N` or `근/원거리 대미지 +N`, use that exact number **once**, not on top of the same `atk` field.
3. Explicit `근거리/원거리/마법 명중 +N`, `근거리/원거리/마법 치명타 +N`, and `대미지 리덕션 +N` are handled by the shared interpreter. A vague `계열` description without a number cannot magically create a stat.
4. Existing XP, HP, movement speed and base defense are preserved. Existing saves remain compatible; no catalog JSON migration.
5. Magic dolls still **follow** the character as before. They are not made active combat pets by guesswork.

## Unique/underspecified effects requiring owner decisions
No new numerical effect or proc chance was invented for these descriptions:

| Category | Catalog examples | Missing decision |
| --- | --- | --- |
| 마법인형 | 린드비오르 — 공격속도 계열 보너스 | Exact attack-speed %; clarify existing `speed: 1.08` is move speed or intended attack speed |
| 마법인형 | 안타라스 — 대미지 리덕션 계열 | Flat reduction amount or percent, applicable damage types |
| 마법인형 | 다크 하딘 — PVP 방어 계열; 리즈 — PVE 방어 계열 | Separate PvP/PvE stats and values; offline PvP is not active |
| 마법인형 | 판도라 — 물약 회복 계열 | Flat/percent potion enhancement, stacking rules |
| 마법인형 | 서큐버스퀸 — MP 회복형 | MP per tick, tick interval and trigger (passive vs proc) |
| 마법인형 | 흑장로 — SP 계열; 단테스 — 근거리 명중 계열; 푸른 드레이크 — 원거리 치명타 계열 | Exact numerical bonus for each |
| 마법인형 | 버그베어 — 무게 보너스 | Flat or percent capacity bonus |
| 성물 | 군터의 방패 — 대미지 리덕션 계열 | Flat/percent and affected damage |
| 성물 | 세계수의 꽃잎 — 스킬 계열 보너스 | Affected skills and modifier/cooldown rules |
| 성물 | 타로스의 창 — HP 회복 계열 | Passive regeneration, on-hit heal, potion amplifier or proc parameters |
| 전 범주 | 기타 `계열`, `보너스`, `회복형`, `마법형` 등 | Exact stat/trigger; do not assume official Lineage M mechanics |

## Verification
`tests/catalog_effects_smoke_test.gd` asserts attack speed +170/+190/+4, type-specific damage including no duplicates, relic HP/XP preservation, and explicit unknown-effect boundaries. An independent Godot 4.7.2 validation workflow also runs the parent branch's item, speed, skill, and ground-drop regression tests.
