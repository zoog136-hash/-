# Original NPC values in existing actor consumers

Implementation-only; no additional parsing, tests, game execution or rendering. Existing pass evidence does not validate this change.

Reuses the public PR271f1fc0acf0704e1184c51488f0ca027fb4c4cb103 patch523_npc_catalog projection and selected-attack read contract. Monster.setup calls project_actor_record immediately after its existing BASE508.npc_record resolution. Other local Monster equipment effects, boss/source action/lifecycle/pooling/admission and visual code are preserved.

An existing explicit source actor must retain matching integer NpcClassID, Sprite and DescId against the held pinned original source. TestNPC, explicit dummy declarations and unsupported/unknown categories are not newly projected. Original HP/MP/AC/MR/Exp and native attribute rows feed existing actor/stat/effect consumers. The original actor namespace, encounter identity, spawn-context level, placement and pixels are unchanged. Existing spawn admission still runs before projection; a held/missing/changed source encounter is not created by this data call.

NpcAttack row/owned lookup stays bounded by the already installed compiled graph. selected_attack_row requires equality of ID/NpcClassID/SpellID/NextAttack/MotionType/WeaponType/AttackType/ChangeTarget/Range/Prob/FixedDelayTime/dice fields and IsSpell/IsAbsoluteAtk against compiled selection and actual original row. A missing/different original row retains the compiled row. It never interprets a new probability denominator, phase clock or AI ID. Other typed definitions use the same published data contract and existing runtime effect handlers; unknown semantics are not activated by a reference result.

No new spawn, attack, loot table, map, image, Sprite, source probability or save conversion is introduced. The current source item/floor/quest/crafting/shop ownership and atomic save owners remain separate. No new global source or actor percentage is claimed.
