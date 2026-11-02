extends RefCounted
## Deliberate host encounter adoption. These IDs do not assert native AI phases,
## original selection probability, source-cell range, or original cooldown units.
const NPC_ID: int = 60303
const SPRITE_ID: int = 18465
const SPAWN_VIEW_ID: int = 3520
const TERRITORY_LINK_ID: int = 1410
const LEGACY_SLOT: int = 12
const ATTACK_ID: int = 208733
const SPELL_ID: int = 184
static func for_record(record: Dictionary, host_map_id: String, catalog: Dictionary) -> Dictionary:
	if host_map_id != "aden_world" or int(record.get("source_m_bound_legacy_slot",-1)) != LEGACY_SLOT: return {}
	if int(record.get("source_m_npc_id",-1)) != NPC_ID or int(record.get("source_m_sprite_id",-1)) != SPRITE_ID: return {}
	if int(record.get("source_m_spawn_view_id",-1)) != SPAWN_VIEW_ID or int(record.get("source_m_territory_link_id",-1)) != TERRITORY_LINK_ID: return {}
	var original: Dictionary = record.get("source_m_original",{})
	if int(original.get("ID",-1)) != NPC_ID or int(original.get("Sprite",-1)) != SPRITE_ID: return {}
	for row: Dictionary in catalog.get("npc_attacks",{}).get(str(NPC_ID),[]):
		if int(row.get("ID",-1)) == ATTACK_ID and int(row.get("NpcClassID",-1)) == NPC_ID and int(row.get("SpellID",-1)) == SPELL_ID and bool(row.get("IsSpell",false)) and int(row.get("MotionType",-1)) == 9 and int(row.get("WeaponType",-1)) == 0:
			var spell: Dictionary = catalog.get("spells",{}).get(str(SPELL_ID),{}).get("source_spell",{})
			if int(spell.get("ID",-1)) != SPELL_ID: return {}
			return {"explicit_attack_id":ATTACK_ID,"selection_policy":"explicit_host_adoption_not_native_AI","adoption_contract":"Exact guarded host slot adopts this native NPC attack. Host cooldown/range/strike clock remain compatibility; source Prob is not interpreted as native probability."}
	return {}
