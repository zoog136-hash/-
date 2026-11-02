# Card skill awakening follow-up

PR221 retains source growth on skill reroll; paid operations remain disabled.

## Fee and book quantity evidence (not activated rules)

All three source decks — transformation1, doll2, relic98 — repeat these values:

| Source grade | Name | ValueType1 | Type1 row IDs (deck1/2/98) | Book ItemClassID |
|---|---|---:|---|---:|
| 3 | 희귀 | 100000 | 544 / 274 / 1068 | 75184 |
| 4 | 영웅 | 300000 | 554 / 284 / 1078 | 75194 |
| 5 | 전설 | 500000 | 564 / 294 / 1088 | 95624 |
| 32 | 신화 | 1000000 | 574 / 304 / 1098 | 118992 |
| 52 | 유일 | 3000000 | 1063 / 1463 / 1561 | 243043 |

Type3 repeats the same15 values; Type2 repeats rare/hero/legend values in9rows.
The missing ValueType enum prevents assigning initial/reroll/EXP operations to
these rows. Matching historical rare/hero fees is a clue, not current fee proof.
Types5/6 contain100–300/100–120, Type16 is50; no source unit authorizes treating
these as consumed book counts. Named pool bonuses explicitly use Unit10874 and
resolve to group IDs, not quantities. Each of507 book crafting output rows has
Amount1: **one is a produced-book quantity candidate only**, not evidence that
awakening consumes one book. Combat SpellMaterialItemAmount0 is unrelated.

## Source VFX integration and input gap

`skill_awakening_source_vfx.gd` dispatches exact base508 SpellClassID and its
nonzero cast/effect/impact/success fields to PR217's existing
`original_source_preview.notify_source_spell_event`. It does not alias learned
spell names or create substitute art. Points are copied before damage; local
successful-hit placement remains compatibility behavior, not recovered travel
or server timing. Missing compositor/manifest/record is reported unavailable.
Death, player death, unequip and cooldown paths cannot create extra proc events.

UI v10 does not supply these first-priority original screen files:

| Container | Member | Bytes | CRC32 |
|---|---|---:|---|
| Client/Data/UI117.dat | UI/Change/Change_Awaken_Skill.csb | 52292 | 77cf6bf9 |
| Client/Data/UI117.dat | UI/Change/Change_Awaken_SkillExp.csb | 87632 | e939b3dc |

First real fire-bolt resource pair: `Client/Data/Sprite80.dat` →
`Sprite/1583-0.sp2`; `Client/Data/Sprite208.dat` → `Sprite/218-0.sp2`.
The private exact request lists95 SP2 files covering93 of95 referenced SpriteIDs
(6324903 compressed member bytes); IDs1085/10705 have no matching file in the
provided structure registry. This does not prove absence in the original client.
UI atlas dependencies must be read from the CSBs, not guessed from filenames.

The request is delivered privately:
https://drive.google.com/file/d/1d-iXUW6Vx1QWxivUmMNCvND148XmVLkk/view

## Validation

Godot4.6.3:61 service/transaction/source-event checks,45 real World/UI checks.
The latter instantiate the production Monster scene, inflict lethal damage,
run `retire_for_pool`/`setup`, verify clean life_id and per-card cooldown, then
verify a new hit on the reused body. Source-event unit checks use a clearly
labelled mock compositor; they do not prove original pixel playback. Installed
original skill art and screen CSBs remain pending. Existing exit-time resource
warnings remain; no script/parse errors. Android/Godot4.7.2 unverified.
