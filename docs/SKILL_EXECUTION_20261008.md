# Twilight skill execution — 2026-10-08

Scope: **skill execution mechanics**, isolated from Astra's map/world-region work.
Branch: `codex/skill-system-20261008`. No changes to `scripts/maps/*`, input routing, or the existing Godot validation workflow.

## Active skill pipeline

`HUD skill button / quickslot -> world._cast_job_skill -> _skill_ready -> effect handler -> _start_skill_cooldown`.

- A cast is rejected without spending MP when the skill is passive, wrong class, unavailable, stunned/feared/silenced, on cooldown, or insufficient MP.
- Skills needing a target reject the cast if no visible target is within range.
- Attack misses and resisted statuses **still expend MP and start cooldown** after a valid attempt.
- Only successful/attempted casts receive per-skill and global cooldowns. Default global cooldown: 0.25 seconds.
- `cooldown`, `global_cooldown`, `range`, `duration`, `hits` and `area_radius` can override defaults in the skill record.
- Effect handlers: damage (crit/hit; multi-hit and AoE), heal, four stat/speed buffs, teleport, invisibility and six target status effects (stun, silence, poison, bleed, hold, fear).
- Legacy combat buttons remain available for compatibility; they use their existing direct action handlers.

## Quickslot and automation

- Skill panel -> Q등록 -> choose one of eight slots for **manual** casting.
- On eligible damage/heal/status skills, the same picker also offers **자동**. This saves an entry `{"kind":"skill","id":"...","auto":true}`.
- **AUTO hunt ON**: registered AUTO damage/status skills are attempted when a target is in sight and in range; selected AUTO heal skills cast when HP is at or below `auto_hp_threshold` (default 65%).
- If an AUTO combat skill is unavailable or cooling down, normal attacks continue.
- **SELF OFF** continues to auto-refresh manually registered active buffs while respecting the same MP/cooldown rules; **SELF ON** disables that auto-buff refresh.
- AUTO combat and SELF buff refresh are independent toggles. Existing saved slots without `auto` remain manual by default.

## Passives

- `activation: "passive"`, `trigger: "always"` (or omitted) contributes permanent attack/defense/HP/speed stats while belonging to the current class.
- Event-driven passives are supported through `trigger: "on_hit" | "on_damaged" | "on_kill"`, `proc_effect: "damage" | "heal" | "atkBuff" | "defBuff" | "hpBuff" | "speedBuff"`, `proc_chance: 0..1`, and `cooldown`.
- Event-driven passives do not register as manual slots, do not spend MP, and do not mistakenly contribute permanent stats.
- Class changes prune ineligible active buffs/slots; saved skill cooldowns are restored on load.
- Current DB marks **40 passives**: 1 original (멘탈 포커스), 13 permanent 집중, 13 on-hit 전투의지, and 13 on-damaged 철벽. Ownership is class-scoped; learn/unlock requirements are still separate work.

## Named skills corrected in this patch

- 쇼크 스턴 -> stun effect, 2 second stun attempt, 10 second cooldown.
- 사일런스 -> silence effect, 3 second silence attempt, 10 second cooldown.
- 인비지블리티 -> 20 second invisibility, broken on attacking; monsters stop targeting until revealed.
- 파이어 볼 -> AoE attack around target (120 px).
- 트리플 애로우 -> three independent hit checks with total base power divided across hits.

## Validation

Existing tests: `tests/passive_skill_smoke_test.gd`, `tests/quickslot_smoke_test.gd`.
New tests: `tests/skill_mechanism_smoke_test.gd` and `tests/skill_element_integration_smoke_test.gd`.

Run (after import) using Godot 4.7.2:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/skill_mechanism_smoke_test.gd
godot --headless --path . --script res://tests/skill_element_integration_smoke_test.gd
```

The skill-only workflow is `.github/workflows/skill-mechanism-validate.yml`; it does not modify the existing map validation workflow.

## Known limits / follow-up

- The 216 locally expanded skills still share generic formulas and placeholder-style descriptions. Individually authentic mechanics, exact skill rankings, learn/unlock systems, proc percentages and specialized attack animations require a separate content/balance pass.
- Utility `라이트` was removed at user request.
- Invisibility currently prevents PvE monsters from targeting, not multiplayer targeting (this is an offline RPG).

## Mechanics correction — 2026-10-08

- **라이트** is removed from the skill DB (258 -> 257 records) and invalid saved quickslots are pruned.
- **턴 언데드 / 턴 언데드(강화)**: only monsters with `type: "언데드"` / `undead: true` can be targeted. The normal magic hit roll is evaluated and a landed hit deals current HP, instantly defeating the undead even if it is a boss. A miss costs MP and cooldown; a non-undead target is rejected before spending MP. Five obviously undead expanded monster entries had incorrect race types corrected.
- **카운터 배리어**: a 90-second active defense buff (+8) that on a landed melee hit has a 30% chance to reflect 150% of the actual received damage; **(마스터)** (+14) has a 45% chance to reflect 200%. When both are active, the highest proc chance wins; miss / ranged / magic hits cannot trigger a counter.
- **트리플 애로우 and (스피릿)**: three independent hit/crit/damage attempts each; fixed 2-hit metadata for 13 class-specific `연격` skills, 112px AoE for 13 class-specific `폭발` skills.
- **13 class-specific 돌진 skills**: 340px initiation range, 1150px/s dash along navigable route to near the target, followed by a real damage hit. Rejects path/obstacle failures before MP is spent; cancels if the target dies or the user is stunned. Dash movement is managed by world code without editing Astra's map renderer.
- **AUTO attack priority**: checks registered offensive AUTO skills against *their own pixel ranges* **before** the normal weapon range/attack test. Falls back to normal attacks or chases the target while no registered spell can execute.
- **Speed value corrections**: eight generated `가속 7` skills were adjusted from 11.5% to 12% or from 16.5% to 17% to exactly match their descriptions.
- **Validation**: extended the independent skill smoke test with turn-undead, counters, three-hit, route-based charge and ranged AUTO priority checks. The existing full Godot validation workflow is left unchanged.

### Limits of this pass

The new charge and 3-hit mechanics are implemented as local movement / multiple damage rolls. Unique sprite/projectile art, per-frame animation timing and full 257-skill authenticity are separate animation/content work. Charge motion checks walkable map cells and follows navigation paths; it is not a physics-impulse attack.


## Unique mechanics, elemental integration, passive classification — second pass (2026-10-08)

This work uses the project's own data-driven skill names and balancing, **not** a claim of exact official Lineage M balance.

### 257-skill inventory
- **40 passives**: 요정 멘탈 포커스 +13 `집중` permanent combat stats; 13 `전투의지` on-hit 35% chance to gain an 8-second attack buff (12-second internal cooldown); 13 `철벽` on-damaged 35% chance for an 8-second defense buff (15-second internal cooldown). The other **217 remain active**. Class switches invalidate expired class-specific buffs / invalid quickslots.
- **216 local-generated skill records**: every class gains named damage, double-strike, area explosion, judgment finishing blow, defensive buff, timed heal / haste / HP, passive buffs and path-based dash. The 13 `심판` skills now gain 50% damage against targets under 30% HP. These are locally designed variants rather than canonical copies.
- **60 generated orb spells** use one of fire, water, wind, earth, holy, dark, lightning, ice, poison, chaos, temporal. Orb spells use magic accuracy rather than the character's default weapon hit style. Ice and time orbs can slow; poison orbs can apply a timed DoT. All 60 now have concrete element metadata, matching their descriptions.

### Named original skill enhancements
- **더블 브레이크 / 데스티니**: only active while using dual blades/claws. Buffs include attack bonus and independent 28% / 42% bonus strike, dealing 65% / 85% of the originating melee strike. Buff variants use the highest available double proc chance, avoiding repeated procs in the same strike.
- **브레이브 멘탈**: normal melee additional-strike proc chance.
- **스톰 샷**: bow-only buff providing ranged bonus +6, hit +4 and wind-element bonus 12%, not a generic all-weapon attack bonus.
- **트리플 애로우 variants**: require a bow and three arrows per cast; missing weapon or ammunition prevents spending MP. Three separate hit/crit rolls retained.
- **홀리 웨폰**: converts basic physical attacks to holy-element hits while active; bonus holy damage and an additional undead modifier stack with monster holy weakness.
- **인챈트 스테이터스**: STR, DEX and INT +2 for 240 seconds; melee/ranged/magic damage or accuracy calculations use these effective temporary stats.
- **리덕션 아머**: includes physical flat damage reduction beyond defense bonuses.
- **썬더 아머 / 다크 프로텍션**: lightning or dark resistance respectively, plus a thunder counter or magic resistance.
- **콜 라이트닝**: hits the selected enemy and chains to up to two nearby enemies; chain hit power falls off by 25% per jump.
- **콘 오브 콜드 / 아이스 스파이크**: ice damage and chance to slow a monster's movement for 3.5 seconds (automatically restores normal speed).
- **어스 재일**: earth damage + on-hit 30% chance to hold for two seconds.
- **풀 힐**: restores the player's HP to maximum on a valid cast; **네이쳐스 블레싱** heals self with a 20% increased coefficient because there are no co-op player allies in this offline client.
- **턴 언데드(강화)**: gains 15 percentage point spell accuracy over normal version, capped at 99%. Both instant-kill only on landed magic hits against undead.
- **텔레포트**: now picks a walkable spot without live monsters within 155px, rejecting unavailable destinations before charging MP. This is a local danger-avoidance heuristic, not an official town-only safe-zone guarantee.

### Element damage and resistance
- A shared `scripts/elemental_rules.gd` handles clamped typed damage bonuses and resistance percentages.
- 163 monsters load `element_resistance` from DB records. The DB has race-based starter traits (e.g. undead weak to holy, dragons resist fire and are weaker to water/ice) plus fire-element monster overrides. Any unspecified channel is neutral.
- Outgoing skill and empowered basic-weapon strikes use `_elemental_damage_to_monster` with attacker bonuses and each individual victim's resistance. AoE hits calculate accuracy per victim. Inbound elemental monster attacks account for active skill/equipment/passive resistances.
- **Known limits**: base monster elemental attacks are inferred for a subset of named fire/ice/lightning/dark monsters. Detailed enchantment upgrading, universal combat log elemental tagging, synchronized projectile art and spell animation timing remain later client tasks.

### Verification
- Independent Godot smoke suites check cast costs/cooldowns, movement, resist math, AoE, lightning chains, ice slow expiration, poison DoT, weapon ammunition, class buff triggers and passive effects.
- The branch remains isolated from Astra's map branch, and **nothing in this skill pass merges to main** without explicit instruction.
