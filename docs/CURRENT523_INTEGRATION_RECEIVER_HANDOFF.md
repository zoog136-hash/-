# Existing integration receiver handoff — unverified local follow-up

Public PR281 baseline: af3ec2b35c533d98f21c6fc7949291c482d86b22. Preserved local tree-equivalent baseline:81de5e6aba4b7fb412e2654d0f7d2ff510a3d25b. Flat receiver local checkpoint:72858520e0d25de467b292112863cf88d92c8ed6. These new changes are not covered by the earlier exact seven-file publication approval and are not published. No tests/compile/game/render/CI or resource installation/update.

## Final-blow data-owner input

Use `source_final_blow_flat` in the existing equipment sum. Source key: exact ItemBonus→BonusType.FinalBlowAdditionalDmg→Unit.Value(ID1); divisor1, damage units. Native `totals` returns flat with chance_pct/amp_pct. The source reader must retain its existing ItemClass/archive/application/possession/mapped-bonus guards and must not count a base or enhancement operand twice. Owner code also maps this field for existing book base/enhancement rows; no complete row-coverage claim is made.

Explicit user policy: sum flat, use `int(raw_flat)` only when positive and finite (truncate toward zero); otherwise0. Reuse the existing ONE final-blow success roll. Success returns amount + flat + existing_round((amount+flat)*max(amp_pct,0)/100). Existing rounding is nearest unless source_final_blow_rounding is floor. Amplification0 still permits positive integer flat; chance0 or no flat/amplification causes no roll. Existing admitted normal/spell scope and after-amplification/growth, before-elemental/undead placement remain. This is user policy, not original server behavior. No card final-blow engine is substituted.

## Actual NPC dialogue

World._set_click_destination calls SOURCE_NPCS.nearest_click_record/records then hud.open_npc_dialogue(source_catalog_id). The existing catalog reads data/npc/source_six.json and the actual dialogue service reads source_six_dialogues/twilight_dialogues with PC/L1J or host keys. The admitted mobile combat Monster.source_m_original is not the selected actor in this dialogue call graph. A real mobile actor→dialogue invocation/ownership relation is absent here, so no global key alias, portrait context provider or mobile NPC ID is fabricated. Existing image `NpcImages.bind_dialogue(hud,context_provider)` still requires that real relation. Combat actors are not turned into talkable NPCs merely because they have an ID.

## Dungeon actual selection

World.source_dungeon_entries(kind,hard) delegates source_dungeons.entries. source_dungeon_view._select reads rows[selected]. Tower/Orim use entry.stage.ID; special uses entry.row.ID; recharger uses entry.item.row.ID. Special entry.row.EntranceAssetID is its source entrance role, not a PartyDungeonTypeID or CompetitionDungeon.ID. No source-authored entrance/popup UI target is established by the existing ItemList/buttons. Do not infer a new party/competition FK, target node or role; existing image/UI owners retain that receiver boundary.

## Player skill distance and gameplay weapon namespace

Existing World._skill_target(max_distance) compares world-position Vector2 distance (pixels), target identity and line of sight. World._queue_player_attack(..., normal=false, max_range) stores that pixel range; the existing impact branch checks distance again. These calls have no positive minimum-distance argument. They do not establish a SpellClass.Range raw-unit conversion, weapon-dependent spell selection or minimum-range semantics.

A separate EXISTING gameplay weapon reader is `patch523_ammo.weapon_type(world._equipped_weapon_record())`: the admitted native record's ItemBonus→BonusType WeaponType relation returns its exact weapon_type row; unsupported/ambiguous/conditional inputs return empty. World._current_attack_range_cells already consumes that row.AttackRange in cell space, and _weapon_cell_distance uses Chebyshev cells. This gameplay row.ID/AttackRange is distinct from Sprite enums. Conversely, `_mastery_actual_weapon_type()` currently calls source_weapon_banks.local_type(_current_weapon_type()), so it must NOT be presented as proof of an original gameplay WeaponType.ID. No new spell conversion or combat policy is activated in this handoff.

Pending spell-stage/potion/emoticon work is excluded; sound excluded. Existing originals, source bank,62ZIP,v30/index and separate resource candidates remain unchanged.
