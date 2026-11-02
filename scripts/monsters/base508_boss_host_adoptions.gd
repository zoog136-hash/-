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
	var action_contract: Dictionary = record.get("source_m_host_action_contract",{})
	if not action_contract.is_empty(): return _single_action_record(record,catalog,action_contract)
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

# Exact contextual encounters adopt one ordinary source row. Other native rows
# remain unadopted; availability of action18 does not assert full native AI.
const ACTION_CONTEXTS = {
	66993:{"sprite":20319,"spawn":300203,"territory":140833,"attack":243953},
	67033:{"sprite":20319,"spawn":300213,"territory":140843,"attack":244103}
}
static func actor_contract(npc_id:int,sprite_id:int,profile:Dictionary,tracks:Dictionary,catalog:Dictionary={}) -> Dictionary:
	if not ACTION_CONTEXTS.has(npc_id) or int(ACTION_CONTEXTS[npc_id].sprite)!=sprite_id or catalog.is_empty(): return {}
	if profile.get("contract","")!="base508_source_action_capabilities_v1": return {}
	if not bool(profile.get("source_category",{}).get("IsAttackable",false)) or profile.get("source_category",{}).get("Name","")=="Citizen": return {}
	if int(profile.get("source_sparse_attachment_slot_count",-1))!=0 or not profile.get("unresolved_source_action_ids",[]).is_empty(): return {}
	for role:String in ["idle","walk"]:
		if not tracks.has(role) or not profile.get("available_roles",{}).has(role): return {}
		if int(tracks[role].get("source_action_id",-1))!=int(profile.available_roles[role]): return {}
	var action_track:bool=false
	for track:Dictionary in tracks.values():
		if not track.get("source_omitted_attachment_slots",[]).is_empty(): return {}
		if int(track.get("source_action_id",-1))==18: action_track=true
	var listed_action:bool=false
	for value:Variant in profile.get("available_source_action_ids",[]):
		if value == 18.0: listed_action=true
	if not action_track or not listed_action: return {}
	var context:Dictionary=ACTION_CONTEXTS[npc_id]
	var original:Dictionary=catalog.get("source_npcs",{}).get(str(npc_id),{})
	if int(original.get("sprite_id",-1))!=sprite_id or not bool(original.get("source_ui_boss",false)): return {}
	var selected:Dictionary={};var unadopted:Array=[]
	for row:Dictionary in catalog.get("npc_attacks",{}).get(str(npc_id),[]):
		if int(row.get("ID",-1))==int(context.attack): selected=row
		else: unadopted.append(int(row.ID))
	if not _ordinary_row(selected,npc_id,int(context.attack)): return {}
	var matched:bool=false
	for route:Dictionary in profile.get("native_attack_routes",[]):
		if int(route.get("npc_attack_id",-1))!=int(context.attack): continue
		var candidates:Array=route.get("candidate_action_ids",[])
		if candidates.size()!=1 or candidates[0]!=18.0 or int(route.get("resolved_action_id",-1))!=18: return {}
		if route.get("source_attack",{})!=selected: return {}
		matched=true
	if not matched: return {}
	var actions:Array=[]
	for row:Dictionary in catalog.get("source_actions",[]):
		if int(row.get("MotionType",-1))==9 and int(row.get("WeaponType",-1))==0: actions.append(int(row.ID))
	if actions!=[18]: return {}
	return {"host_combat_ready":true,"source_npc_id":npc_id,"source_sprite_id":sprite_id,"attack_action_id":18,"explicit_attack_id":int(context.attack),"required_roles":["idle","walk"],"selection_policy":"explicit_host_adoption_not_native_AI","unadopted_attack_ids":unadopted,"contract":"base508_exact_context_single_action18_v1","adoption_contract":"Exact contextual source ID adopts its first ordinary source attack using authored action18. IsSpell=false and source dice retained. Other source rows, native probability/delay/AI and original geographic placement are not adopted."}
static func _ordinary_row(row:Dictionary,npc_id:int,attack_id:int) -> bool:
	return int(row.get("ID",-1))==attack_id and int(row.get("NpcClassID",-1))==npc_id and not bool(row.get("IsSpell",true)) and int(row.get("SpellID",-1))==0 and int(row.get("MotionType",-1))==9 and int(row.get("WeaponType",-1))==0 and not bool(row.get("IsAbsoluteAtk",true)) and int(row.get("DiceCount",-1))==5 and int(row.get("DiceSpots",-1))==5 and int(row.get("DiceBonus",-1))==0
static func _single_action_record(record:Dictionary,catalog:Dictionary,contract:Dictionary) -> Dictionary:
	var nid:int=int(record.get("source_m_npc_id",-1))
	if not ACTION_CONTEXTS.has(nid) or contract.get("contract","")!="base508_exact_context_single_action18_v1": return {}
	var context:Dictionary=ACTION_CONTEXTS[nid]
	if int(record.get("source_m_sprite_id",-1))!=int(context.sprite) or int(record.get("source_m_spawn_view_id",-1))!=int(context.spawn) or int(record.get("source_m_territory_link_id",-1))!=int(context.territory): return {}
	var original:Dictionary=record.get("source_m_original",{})
	if int(original.get("ID",-1))!=nid or int(original.get("Sprite",-1))!=int(context.sprite): return {}
	if int(contract.get("source_npc_id",-1))!=nid or int(contract.get("source_sprite_id",-1))!=int(context.sprite) or int(contract.get("explicit_attack_id",-1))!=int(context.attack) or int(contract.get("attack_action_id",-1))!=18 or not bool(contract.get("host_combat_ready",false)): return {}
	var source:Dictionary=catalog.get("source_npcs",{}).get(str(nid),{})
	if int(source.get("sprite_id",-1))!=int(context.sprite): return {}
	for row:Dictionary in catalog.get("npc_attacks",{}).get(str(nid),[]):
		if _ordinary_row(row,nid,int(context.attack)):
			return {"explicit_attack_id":int(context.attack),"selection_policy":"explicit_host_adoption_not_native_AI","adoption_contract":contract.get("adoption_contract","")}
	return {}
