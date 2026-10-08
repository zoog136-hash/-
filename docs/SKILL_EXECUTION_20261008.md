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
- Current DB still identifies **one** passive (멘탈 포커스); full 258-skill active/passive gameplay classification is a separate data-review task.

## Named skills corrected in this patch

- 쇼크 스턴 -> stun effect, 2 second stun attempt, 10 second cooldown.
- 사일런스 -> silence effect, 3 second silence attempt, 10 second cooldown.
- 인비지블리티 -> 20 second invisibility, broken on attacking; monsters stop targeting until revealed.
- 파이어 볼 -> AoE attack around target (120 px).
- 트리플 애로우 -> three independent hit checks with total base power divided across hits.

## Validation

Existing tests: `tests/passive_skill_smoke_test.gd`, `tests/quickslot_smoke_test.gd`.
New test: `tests/skill_mechanism_smoke_test.gd`.

Run (after import) using Godot 4.7.2:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/skill_mechanism_smoke_test.gd
```

The skill-only workflow is `.github/workflows/skill-mechanism-validate.yml`; it does not modify the existing map validation workflow.

## Known limits / follow-up

- The 216 locally expanded skills still share generic formulas and placeholder-style descriptions. Individually authentic mechanics, exact skill rankings, learn/unlock systems, proc percentages and specialized attack animations require a separate content/balance pass.
- Utility `라이트` has no real field-vision mechanic yet and is deliberately rejected instead of falsely consuming MP for no effect.
- Invisibility currently prevents PvE monsters from targeting, not multiplayer targeting (this is an offline RPG).
