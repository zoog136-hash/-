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
const AUTHORITY = preload("res://scripts/monsters/base508_authoritative_catalog.gd")
const ACTOR_PACK = preload("res://scripts/monsters/base508_monster_pack_cache.gd")
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
	if npc_id == 47744: return _stationary_actor_contract(sprite_id,profile,tracks,catalog)
	if not ACTION_CONTEXTS.has(npc_id): return _ordinary_actor_contract(npc_id,sprite_id,profile,tracks,catalog)
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
	if nid == 47744: return _stationary_record(record,catalog,contract)
	if contract.get("contract","")=="base508_exact_context_ordinary_host_action_v1": return _ordinary_record(record,catalog,contract)
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

static func _stationary_row(row:Dictionary,catalog:Dictionary) -> bool:
	if int(row.get("ID",-1))!=236472 or int(row.get("NpcClassID",-1))!=47744 or int(row.get("MotionType",-1))!=2 or int(row.get("WeaponType",-1))!=0 or not bool(row.get("IsSpell",false)) or int(row.get("SpellID",-1))!=54132: return false
	var spell:Dictionary=catalog.get("spells",{}).get("54132",{})
	var dice:Dictionary=spell.get("damage_dice",{})
	return int(spell.get("source_spell",{}).get("ID",-1))==54132 and spell.get("target_kind",{}).get("Name","")=="Enemy" and spell.get("targetting_type",{}).get("Name","")=="SingleObject" and int(dice.get("base",-1))==2300 and int(dice.get("dice_count",-1))==110 and int(dice.get("dice_spots",-1))==100
static func _stationary_actor_contract(sprite_id:int,profile:Dictionary,tracks:Dictionary,catalog:Dictionary) -> Dictionary:
	if sprite_id!=7236 or catalog.is_empty() or profile.get("contract","")!="base508_source_action_capabilities_v1": return {}
	var source:Dictionary=catalog.get("source_npcs",{}).get("47744",{})
	if int(source.get("sprite_id",-1))!=7236 or not bool(source.get("source_ui_boss",false)): return {}
	if not bool(profile.get("source_category",{}).get("IsAttackable",false)) or profile.get("source_category",{}).get("Name","")=="Citizen": return {}
	if int(profile.get("source_sparse_attachment_slot_count",-1))!=0 or not profile.get("unresolved_source_action_ids",[]).is_empty(): return {}
	for role:String in ["idle","attack"]:
		var expected:int=3 if role=="idle" else 1
		if not tracks.has(role) or int(tracks[role].get("source_action_id",-1))!=expected or int(profile.get("available_roles",{}).get(role,-1))!=expected: return {}
	for track:Dictionary in tracks.values():
		if not track.get("source_omitted_attachment_slots",[]).is_empty(): return {}
	var selected:Dictionary={};var unadopted:Array=[]
	for row:Dictionary in catalog.get("npc_attacks",{}).get("47744",[]):
		if int(row.get("ID",-1))==236472:selected=row
		else:unadopted.append(int(row.ID))
	if not _stationary_row(selected,catalog): return {}
	var matched:bool=false
	for route:Dictionary in profile.get("native_attack_routes",[]):
		if int(route.get("npc_attack_id",-1))!=236472: continue
		var candidates:Array=route.get("candidate_action_ids",[])
		if candidates.size()!=1 or candidates[0]!=1.0 or int(route.get("resolved_action_id",-1))!=1 or route.get("source_attack",{})!=selected: return {}
		matched=true
	if not matched:return {}
	return {"contract":"base508_exact_context_stationary_action1_v1","host_combat_ready":true,"host_stationary":true,"source_npc_id":47744,"source_sprite_id":7236,"explicit_attack_id":236472,"attack_action_id":1,"required_roles":["idle","attack"],"selection_policy":"explicit_host_adoption_not_native_AI","unadopted_attack_ids":unadopted,"adoption_contract":"Exact contextual female Zeb adopts source Spell54132 and available authored action1, without manufacturing walk. Stationary host clock/range/selection policy is compatibility; source probability/delay/native AI and geography remain unverified."}
static func _stationary_record(record:Dictionary,catalog:Dictionary,contract:Dictionary) -> Dictionary:
	if contract.get("contract","")!="base508_exact_context_stationary_action1_v1" or not bool(contract.get("host_stationary",false)) or not bool(contract.get("host_combat_ready",false)): return {}
	if not bool(record.get("source_m_host_stationary",false)) or typeof(record.get("speed")) not in [TYPE_INT,TYPE_FLOAT] or float(record.speed)!=0.0: return {}
	if int(record.get("source_m_sprite_id",-1))!=7236 or int(record.get("source_m_spawn_view_id",-1))!=277472 or int(record.get("source_m_territory_link_id",-1))!=136572: return {}
	var original:Dictionary=record.get("source_m_original",{})
	if int(original.get("ID",-1))!=47744 or int(original.get("Sprite",-1))!=7236: return {}
	if int(contract.get("source_npc_id",-1))!=47744 or int(contract.get("source_sprite_id",-1))!=7236 or int(contract.get("explicit_attack_id",-1))!=236472 or int(contract.get("attack_action_id",-1))!=1: return {}
	if int(catalog.get("source_npcs",{}).get("47744",{}).get("sprite_id",-1))!=7236:return {}
	for row:Dictionary in catalog.get("npc_attacks",{}).get("47744",[]):
		if _stationary_row(row,catalog):return {"explicit_attack_id":236472,"host_source_action_id":1,"selection_policy":"explicit_host_adoption_not_native_AI","adoption_contract":contract.get("adoption_contract","")}
	return {}

static func _ordinary_source_row(row:Dictionary,nid:int) -> bool:
	return int(row.get("NpcClassID",-1))==nid and int(row.get("ID",0))>0 and not bool(row.get("IsSpell",true)) and int(row.get("SpellID",-1))==0 and not bool(row.get("IsAbsoluteAtk",true)) and int(row.get("NextAttack",-1))==0 and int(row.get("DiceCount",0))>0 and int(row.get("DiceCount",0))<=1000 and int(row.get("DiceSpots",0))>0 and int(row.get("DiceSpots",0))<=1000000 and int(row.get("DiceBonus",-1))>=0
static func _all_directions(track:Dictionary) -> bool:
	var directions:Array=track.get("directions",[])
	if directions.size()!=8 or not track.get("source_omitted_attachment_slots",[]).is_empty(): return false
	for direction:Variant in directions:
		if not direction is Array or direction.is_empty(): return false
	return true
static func _ordinary_actor_contract(nid:int,sprite_id:int,profile:Dictionary,tracks:Dictionary,catalog:Dictionary) -> Dictionary:
	if catalog.is_empty() or bool(profile.get("host_combat_ready",false)) or profile.get("contract","")!="base508_source_action_capabilities_v1":return {}
	if profile.get("source_behavior_family","")!="source_motion_without_basic_attack" or profile.get("source_kind_preserved","") not in ["source_attackable_monster_actor","source_ui_boss_npc"]:return {}
	if profile.get("source_category",{}).get("Name","")!="Npc" or not bool(profile.get("source_category",{}).get("IsAttackable",false)):return {}
	if int(profile.get("source_sparse_attachment_slot_count",-1))!=0 or not profile.get("unresolved_source_action_ids",[]).is_empty() or profile.get("available_roles",{}).has("attack"):return {}
	var source:Dictionary=catalog.get("source_npcs",{}).get(str(nid),{})
	if int(source.get("sprite_id",-1))!=sprite_id:return {}
	for role:String in ["idle","walk"]:
		var expected:int=3 if role=="idle" else 0
		if not tracks.has(role) or int(tracks[role].get("source_action_id",-1))!=expected or int(profile.get("available_roles",{}).get(role,-1))!=expected or not _all_directions(tracks[role]):return {}
	var by_action:Dictionary={}
	for track:Dictionary in tracks.values():
		if not track.get("source_omitted_attachment_slots",[]).is_empty():return {}
		by_action[int(track.get("source_action_id",-1))]=track
	var selected:Dictionary={};var selected_action:int=-1;var unadopted:Array=[]
	for row:Dictionary in catalog.get("npc_attacks",{}).get(str(nid),[]):
		if selected.is_empty() and _ordinary_source_row(row,nid):
			var candidates:Array=[]
			for action:Dictionary in catalog.get("source_actions",[]):
				var id:int=int(action.get("ID",-1))
				if int(action.get("MotionType",-1))==int(row.MotionType) and int(action.get("WeaponType",-1))==int(row.WeaponType) and by_action.has(id):candidates.append(id)
			if candidates.size()==1 and int(candidates[0]) in [18,30] and _all_directions(by_action[int(candidates[0])]):
				var matched:bool=false
				for route:Dictionary in profile.get("native_attack_routes",[]):
					if int(route.get("npc_attack_id",-1))!=int(row.ID):continue
					var declared:Array=route.get("candidate_action_ids",[])
					matched=declared.size()==1 and int(declared[0])==int(candidates[0]) and int(route.get("resolved_action_id",-1))==int(candidates[0]) and route.get("source_attack",{})==row
				if matched:selected=row;selected_action=int(candidates[0]);continue
		unadopted.append(int(row.ID))
	if selected.is_empty():return {}
	return {"contract":"base508_exact_context_ordinary_host_action_v1","host_combat_ready":true,"host_stationary":false,"source_npc_id":nid,"source_sprite_id":sprite_id,"explicit_attack_id":int(selected.ID),"attack_action_id":selected_action,"required_roles":["idle","walk"],"selection_policy":"explicit_host_adoption_not_native_AI","unadopted_attack_ids":unadopted,"adoption_contract":"Explicit host first supported ordinary source row; typed source dice and unique authored available action retained. Eight stored directions required. Native AI probability/delay/range units and geographic spawn are not asserted."}
static func _ordinary_record(record:Dictionary,catalog:Dictionary,contract:Dictionary) -> Dictionary:
	var nid:int=int(record.get("source_m_npc_id",-1));var sprite:int=int(record.get("source_m_sprite_id",-1))
	if not bool(contract.get("host_combat_ready",false)) or bool(contract.get("host_stationary",true)) or int(contract.get("source_npc_id",-1))!=nid or int(contract.get("source_sprite_id",-1))!=sprite:return {}
	var actor:Dictionary=ACTOR_PACK.actor(str(record.get("source_m_asset_manifest_path","")),nid)
	var checked:Dictionary=_ordinary_actor_contract(nid,sprite,actor.get("source_actor_profile",{}),actor.get("tracks",{}),catalog)
	if checked.is_empty() or int(checked.explicit_attack_id)!=int(contract.get("explicit_attack_id",-1)) or int(checked.attack_action_id)!=int(contract.get("attack_action_id",-1)):return {}
	var original:Dictionary=record.get("source_m_original",{})
	if int(original.get("ID",-1))!=nid or int(original.get("Sprite",-1))!=sprite or bool(original.get("TestNPC",true)):return {}
	if not AUTHORITY.enemy_eligible(nid,true):return {}
	var authoritative:Dictionary=AUTHORITY.npc(nid)
	if int(authoritative.get("sprite_id",-1))!=sprite or bool(authoritative.get("source_original",{}).get("TestNPC",true)):return {}
	var key:String=AUTHORITY.context_key(nid,int(record.get("source_m_spawn_view_id",-1)),int(record.get("source_m_territory_link_id",-1)))
	if not AUTHORITY.context_keys(nid).has(key):return {}
	var aid:int=int(contract.get("explicit_attack_id",-1));var selected:int=int(contract.get("attack_action_id",-1))
	if selected not in [18,30]:return {}
	for row:Dictionary in catalog.get("npc_attacks",{}).get(str(nid),[]):
		if int(row.get("ID",-1))!=aid or not _ordinary_source_row(row,nid):continue
		for action:Dictionary in catalog.get("source_actions",[]):
			if int(action.get("ID",-1))==selected and int(action.get("MotionType",-1))==int(row.MotionType) and int(action.get("WeaponType",-1))==int(row.WeaponType):
				return {"explicit_attack_id":aid,"host_source_action_id":selected,"selection_policy":"explicit_host_adoption_not_native_AI","adoption_contract":contract.get("adoption_contract","")}
	return {}
