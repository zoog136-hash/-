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
	if npc_id==66603:return _alternate_actor_contract(sprite_id,profile,tracks,catalog)
	if profile.get("source_behavior_family","")=="source_mobile_attack_actor" and not bool(profile.get("host_combat_ready",false)): return _core_actor_contract(npc_id,sprite_id,profile,tracks,catalog)
	if SPELL_CONTEXTS.has(npc_id): return _spell_actor_contract(npc_id,sprite_id,profile,tracks,catalog)
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
	if contract.get("contract","")=="base508_exact_context_core_ready_optional_gaps_v1": return _core_record(record,catalog,contract)
	if contract.get("contract","")=="base508_exact_context_single_spell_host_action_v1": return _spell_record(record,catalog,contract)
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
static func _ordinary_action_allowed(row:Dictionary,action_id:int) -> bool:
	if action_id in [18,30]:return true
	# Exact NpcAttack46582 explicitly routes mermaid Breath to action3.
	# Its existing idle role label is not evidence for arbitrary idle attacks.
	return action_id==3 and int(row.get("NpcClassID",-1))==721 and int(row.get("ID",-1))==46582 and int(row.get("MotionType",-1))==4 and int(row.get("WeaponType",-1))==0
static func _all_directions(track:Dictionary) -> bool:
	var directions:Array=track.get("directions",[])
	if directions.size()!=8 or not track.get("source_omitted_attachment_slots",[]).is_empty(): return false
	for direction:Variant in directions:
		if not direction is Array or direction.is_empty(): return false
	return true
static func _ordinary_actor_contract(nid:int,sprite_id:int,profile:Dictionary,tracks:Dictionary,catalog:Dictionary) -> Dictionary:
	if nid==66603:return _alternate_actor_contract(sprite_id,profile,tracks,catalog)
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
			if candidates.size()==1 and _ordinary_action_allowed(row,int(candidates[0])) and _all_directions(by_action[int(candidates[0])]):
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
	if selected not in [3,18,30]:return {}
	for row:Dictionary in catalog.get("npc_attacks",{}).get(str(nid),[]):
		if int(row.get("ID",-1))!=aid or not _ordinary_source_row(row,nid) or not _ordinary_action_allowed(row,selected):continue
		for action:Dictionary in catalog.get("source_actions",[]):
			if int(action.get("ID",-1))==selected and int(action.get("MotionType",-1))==int(row.MotionType) and int(action.get("WeaponType",-1))==int(row.WeaponType):
				return {"explicit_attack_id":aid,"host_source_action_id":selected,"selection_policy":"explicit_host_adoption_not_native_AI","adoption_contract":contract.get("adoption_contract","")}
	return {}

const SPELL_CONTEXTS={
	51731:{"sprite":2747,"attack":169201,"spell":35831,"effect":2748,"dice":[80,20,10],"effects":[2748]},
	41852:{"sprite":5567,"attack":133292,"spell":30392,"effect":5570,"dice":[100,15,3],"effects":[5570]},
	46813:{"sprite":4104,"attack":153503,"spell":119362,"effect":11769,"dice":[585,5,5],"effects":[11769]},
	726:{"sprite":1603,"attack":66563,"spell":421,"effect":1606,"dice":[20,3,3],"effects":[1606,1607]}
}
static func _spell_row(row:Dictionary,nid:int,catalog:Dictionary) -> bool:
	if not SPELL_CONTEXTS.has(nid):return false
	var spec:Dictionary=SPELL_CONTEXTS[nid]
	if int(row.get("ID",-1))!=int(spec.attack) or int(row.get("NpcClassID",-1))!=nid or not bool(row.get("IsSpell",false)) or int(row.get("SpellID",-1))!=int(spec.spell) or int(row.get("MotionType",-1))!=9 or int(row.get("WeaponType",-1))!=0 or int(row.get("NextAttack",-1))!=0 or bool(row.get("IsAbsoluteAtk",true)):return false
	var spell:Dictionary=catalog.get("spells",{}).get(str(int(spec.spell)),{});var raw:Dictionary=spell.get("source_spell",{});var dice:Dictionary=spell.get("damage_dice",{})
	if int(raw.get("ID",-1))!=int(spec.spell) or bool(raw.get("TestSpell",true)) or int(raw.get("SpellTypeID",-1))!=1 or int(raw.get("EffectSpriteID",-1))!=int(spec.effect) or int(raw.get("EffectSpriteActionNo",-1))!=0:return false
	for field:String in ["CasterEffectSpriteID","CriticalEffectSpriteID","FailEffectSpriteID","SuccessEffectSpriteID","HostileEffectSpriteID","AdditionalEffectSpriteGroupID","CasterEffectSpriteGroupID","TargetScreenEffectID","ScreenEffectAssetId","CastingScreenEffectId"]:
		if int(raw.get(field,0))!=0:return false
	if int(raw.get("EffectExplosionSpriteID",0)) != (1607 if nid==726 else 0):return false
	if spell.get("target_kind",{}).get("Name","")!="Enemy" or spell.get("targetting_type",{}).get("Name","")!="SingleObject" or not spell.get("buffs",[]).is_empty():return false
	return int(dice.get("base",-1))==int(spec.dice[0]) and int(dice.get("dice_count",-1))==int(spec.dice[1]) and int(dice.get("dice_spots",-1))==int(spec.dice[2])
static func _spell_actor_contract(nid:int,sprite:int,profile:Dictionary,tracks:Dictionary,catalog:Dictionary) -> Dictionary:
	var spec:Dictionary=SPELL_CONTEXTS[nid]
	if sprite!=int(spec.sprite) or catalog.is_empty() or int(catalog.get("source_npcs",{}).get(str(nid),{}).get("sprite_id",-1))!=sprite:return {}
	if profile.get("contract","")!="base508_source_action_capabilities_v1" or bool(profile.get("host_combat_ready",false)) or profile.get("source_behavior_family","")!="source_motion_without_basic_attack":return {}
	if profile.get("source_kind_preserved","") not in ["source_attackable_monster_actor","source_ui_boss_npc"] or profile.get("source_category",{}).get("Name","")!="Npc" or not bool(profile.get("source_category",{}).get("IsAttackable",false)):return {}
	if int(profile.get("source_sparse_attachment_slot_count",-1))!=0 or not profile.get("unresolved_source_action_ids",[]).is_empty():return {}
	for role:String in ["idle","walk"]:
		var expected:int=3 if role=="idle" else 0
		if not tracks.has(role) or int(tracks[role].get("source_action_id",-1))!=expected or int(profile.get("available_roles",{}).get(role,-1))!=expected or not _all_directions(tracks[role]):return {}
	var available:Dictionary={}
	for track:Dictionary in tracks.values():
		if not track.get("source_omitted_attachment_slots",[]).is_empty():return {}
		available[int(track.get("source_action_id",-1))]=track
	if not available.has(18) or not _all_directions(available[18]):return {}
	var actions:Array=[]
	for action:Dictionary in catalog.get("source_actions",[]):
		if int(action.get("MotionType",-1))==9 and int(action.get("WeaponType",-1))==0 and available.has(int(action.get("ID",-1))):actions.append(int(action.ID))
	if actions!=[18]:return {}
	var selected:Dictionary={};var unadopted:Array=[]
	for row:Dictionary in catalog.get("npc_attacks",{}).get(str(nid),[]):
		if _spell_row(row,nid,catalog):selected=row
		else:unadopted.append(int(row.ID))
	if selected.is_empty():return {}
	var matched:bool=false
	for route:Dictionary in profile.get("native_attack_routes",[]):
		if int(route.get("npc_attack_id",-1))!=int(spec.attack):continue
		var candidates:Array=route.get("candidate_action_ids",[])
		matched=candidates.size()==1 and candidates[0]==18.0 and int(route.get("resolved_action_id",-1))==18 and route.get("source_attack",{})==selected
	if not matched:return {}
	var raw:Dictionary=catalog.spells[str(int(spec.spell))].source_spell
	return {"contract":"base508_exact_context_single_spell_host_action_v1","host_combat_ready":true,"host_stationary":false,"source_npc_id":nid,"source_sprite_id":sprite,"explicit_attack_id":int(spec.attack),"attack_action_id":18,"source_spell_id":int(spec.spell),"source_effect_sprite_id":int(spec.effect),"required_source_effect_sprite_ids":spec.effects.duplicate(),"source_spell_effect_type_id":raw.get("SpellEffectTypeID"),"required_roles":["idle","walk"],"selection_policy":"explicit_host_adoption_not_native_AI","unadopted_attack_ids":unadopted,"adoption_contract":"Explicit single-spell host encounter with exact typed source damage and installed complete original effect references. Host clock/range/point damage are compatibility; raw EffectType retained, not native projectile/speed/impact timing proof."}
static func _effect_path(relative:String,prefix:String) -> bool:
	if not relative.begins_with(prefix) or relative.contains(":") or relative.contains("\\") or relative.begins_with("/"):return false
	for part:String in relative.split("/",true):
		if part in ["",".",".."]:return false
	return true
static func _effect_file(root:String,relative:String,sha:Variant,prefix:String) -> bool:
	if not _effect_path(relative,prefix) or not sha is String or sha.length()!=64:return false
	for index:int in range(sha.length()):
		if not sha.substr(index,1) in "0123456789abcdef":return false
	var path:String=root.path_join(relative)
	return FileAccess.file_exists(path) and ACTOR_PACK.verify_pixel(path,sha)
static func _installed_spell_effects(manifest_path:String,effect_ids:Array) -> bool:
	var manifest:Dictionary=ACTOR_PACK.manifest(manifest_path);var ref:Variant=manifest.get("boss_vfx")
	if not ref is Dictionary or ref.get("path","")!="boss_vfx/boss_vfx.json":return false
	var root:String=manifest_path.get_base_dir()
	if not _effect_file(root,ref.path,ref.get("sha256"),"boss_vfx/"):return false
	var fx:Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join(ref.path)))
	if not fx is Dictionary or fx.get("source_snapshot","")!="base508" or fx.get("kind","")!="base508_boss_literal_sp2_effects":return false
	var listed:Variant=fx.get("source_files")
	if not listed is Dictionary:return false
	var packets:Dictionary={}
	for entry:Variant in listed.values():
		if not entry is Dictionary or not entry.get("path") is String:return false
		if packets.has(entry.path) and packets[entry.path]!=entry.get("sha256"):return false
		packets[entry.path]=entry.get("sha256")
	for effect_id:Variant in effect_ids:
		var model_ref:Variant=fx.get("models",{}).get(str(int(effect_id)))
		if not model_ref is Dictionary or not bool(model_ref.get("source_pixels_complete",false)) or not model_ref.get("path") is String:return false
		if not _effect_file(root,"boss_vfx/"+model_ref.path,model_ref.get("sha256"),"boss_vfx/effects/"):return false
		var model:Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("boss_vfx/"+model_ref.path)))
		if not model is Dictionary or model.get("source_snapshot","")!="base508" or model.get("source_sprite_id",-1)!=float(effect_id) or not bool(model.get("source_pixels_complete",false)) or not model.get("source_gaps",[]).is_empty():return false
		var track:Variant=model.get("tracks",{}).get("effect")
		if not track is Dictionary or track.get("source_sprite_id",-1)!=float(effect_id) or int(track.get("source_action_id",-1))!=0 or not _all_directions(track):return false
		for frames:Array in track.directions:
			for frame:Variant in frames:
				if not frame is Dictionary or not frame.get("layers") is Array or frame.layers.is_empty() or frame.layers.size()>8:return false
				for layer:Variant in frame.layers:
					if not layer is Dictionary:return false
					var path:Variant=layer.get("path")
					if not path is String or not packets.has(path) or packets[path]!=layer.get("sha256") or layer.get("codec","")!="base508_sp2_v1" or not _effect_file(root,"boss_vfx/"+path,layer.get("sha256"),"boss_vfx/sp2/"):return false
	return true
static func _spell_record(record:Dictionary,catalog:Dictionary,contract:Dictionary) -> Dictionary:
	var nid:int=int(record.get("source_m_npc_id",-1))
	if not SPELL_CONTEXTS.has(nid):return {}
	if not bool(contract.get("host_combat_ready",false)) or bool(contract.get("host_stationary",true)):return {}
	var spec:Dictionary=SPELL_CONTEXTS[nid];var path:String=str(record.get("source_m_asset_manifest_path",""))
	var actor:Dictionary=ACTOR_PACK.actor(path,nid)
	var checked:Dictionary=_spell_actor_contract(nid,int(record.get("source_m_sprite_id",-1)),actor.get("source_actor_profile",{}),actor.get("tracks",{}),catalog)
	if checked.is_empty():return {}
	for field:String in ["source_npc_id","source_sprite_id","explicit_attack_id","attack_action_id","source_spell_id","source_effect_sprite_id"]:
		if int(checked.get(field,-1))!=int(contract.get(field,-2)):return {}
	var original:Dictionary=record.get("source_m_original",{})
	if int(original.get("ID",-1))!=nid or int(original.get("Sprite",-1))!=int(spec.sprite) or bool(original.get("TestNPC",true)) or not AUTHORITY.enemy_eligible(nid,true):return {}
	var authority:Dictionary=AUTHORITY.npc(nid)
	if int(authority.get("sprite_id",-1))!=int(spec.sprite) or bool(authority.get("source_original",{}).get("TestNPC",true)):return {}
	if not AUTHORITY.context_keys(nid).has(AUTHORITY.context_key(nid,int(record.get("source_m_spawn_view_id",-1)),int(record.get("source_m_territory_link_id",-1)))):return {}
	if not _installed_spell_effects(path,spec.effects):return {}
	return {"explicit_attack_id":int(spec.attack),"host_source_action_id":18,"selection_policy":"explicit_host_adoption_not_native_AI","adoption_contract":checked.adoption_contract}

static func _core_actor_contract(nid:int,sprite:int,profile:Dictionary,tracks:Dictionary,catalog:Dictionary) -> Dictionary:
	if catalog.is_empty() or profile.get("contract","")!="base508_source_action_capabilities_v1" or bool(profile.get("host_combat_ready",false)) or profile.get("source_behavior_family","")!="source_mobile_attack_actor":return {}
	if profile.get("source_kind_preserved","") not in ["source_attackable_monster_actor","source_ui_boss_npc"] or profile.get("source_category",{}).get("Name","")!="Npc" or not bool(profile.get("source_category",{}).get("IsAttackable",false)):return {}
	if int(catalog.get("source_npcs",{}).get(str(nid),{}).get("sprite_id",-1))!=sprite:return {}
	for issue:Variant in profile.get("unresolved_source_action_ids",[]):
		if int(issue) in [0,1,3]:return {}
	for role:String in ["idle","walk","attack"]:
		var expected:int={"idle":3,"walk":0,"attack":1}[role]
		if not tracks.has(role) or int(tracks[role].get("source_action_id",-1))!=expected or int(profile.get("available_roles",{}).get(role,-1))!=expected or not _all_directions(tracks[role]):return {}
	var available:Dictionary={};var optional_sparse:Dictionary={}
	for key:String in tracks:
		var track:Dictionary=tracks[key];available[int(track.get("source_action_id",-1))]=track
		if key not in ["idle","walk","attack"] and not track.get("source_omitted_attachment_slots",[]).is_empty():optional_sparse[key]=track.source_omitted_attachment_slots.duplicate(true)
	var selected:Dictionary={};var unadopted:Array=[]
	for row:Dictionary in catalog.get("npc_attacks",{}).get(str(nid),[]):
		if selected.is_empty() and _ordinary_source_row(row,nid):
			var candidates:Array=[]
			for action:Dictionary in catalog.get("source_actions",[]):
				if int(action.get("MotionType",-1))==int(row.MotionType) and int(action.get("WeaponType",-1))==int(row.WeaponType) and available.has(int(action.get("ID",-1))):candidates.append(int(action.ID))
			if candidates==[1]:
				for route:Dictionary in profile.get("native_attack_routes",[]):
					if int(route.get("npc_attack_id",-1))!=int(row.ID):continue
					var declared:Array=route.get("candidate_action_ids",[])
					if declared.size()==1 and declared[0]==1.0 and int(route.get("resolved_action_id",-1))==1 and route.get("source_attack",{})==row:selected=row
				if not selected.is_empty():continue
		unadopted.append(int(row.ID))
	if selected.is_empty():return {}
	return {"contract":"base508_exact_context_core_ready_optional_gaps_v1","host_combat_ready":true,"host_stationary":false,"source_npc_id":nid,"source_sprite_id":sprite,"explicit_attack_id":int(selected.ID),"attack_action_id":1,"required_roles":["idle","walk","attack"],"selection_policy":"explicit_host_adoption_not_native_AI","unadopted_attack_ids":unadopted,"optional_unresolved_source_action_ids":profile.get("unresolved_source_action_ids",[]).duplicate(),"optional_sparse_attachment_slots":optional_sparse,"adoption_contract":"Exact clean idle/walk/basic attack and first supported ordinary source attack. Optional missing death/hit/appearance and sparse attachment slots remain unresolved metadata, without replacement frames. Host clock/range/selection compatibility is not native AI probability/delay/geography proof."}
static func _core_record(record:Dictionary,catalog:Dictionary,contract:Dictionary) -> Dictionary:
	var nid:int=int(record.get("source_m_npc_id",-1));var sprite:int=int(record.get("source_m_sprite_id",-1))
	if not bool(contract.get("host_combat_ready",false)) or bool(contract.get("host_stationary",true)):return {}
	var actor:Dictionary=ACTOR_PACK.actor(str(record.get("source_m_asset_manifest_path","")),nid)
	var checked:Dictionary=_core_actor_contract(nid,sprite,actor.get("source_actor_profile",{}),actor.get("tracks",{}),catalog)
	if checked.is_empty():return {}
	for field:String in ["source_npc_id","source_sprite_id","explicit_attack_id","attack_action_id"]:
		if int(checked.get(field,-1))!=int(contract.get(field,-2)):return {}
	var original:Dictionary=record.get("source_m_original",{})
	if int(original.get("ID",-1))!=nid or int(original.get("Sprite",-1))!=sprite or bool(original.get("TestNPC",true)) or not AUTHORITY.enemy_eligible(nid,true):return {}
	var authority:Dictionary=AUTHORITY.npc(nid)
	if int(authority.get("sprite_id",-1))!=sprite or bool(authority.get("source_original",{}).get("TestNPC",true)):return {}
	if not AUTHORITY.context_keys(nid).has(AUTHORITY.context_key(nid,int(record.get("source_m_spawn_view_id",-1)),int(record.get("source_m_territory_link_id",-1)))):return {}
	return {"explicit_attack_id":int(checked.explicit_attack_id),"host_source_action_id":1,"selection_policy":"explicit_host_adoption_not_native_AI","adoption_contract":checked.adoption_contract}

static func _alternate_actor_contract(sprite:int,profile:Dictionary,tracks:Dictionary,catalog:Dictionary) -> Dictionary:
	# One exact alternate row, not a repair or fallback for missing basic layers.
	if sprite!=20363 or catalog.is_empty() or int(catalog.get("source_npcs",{}).get("66603",{}).get("sprite_id",-1))!=20363:return {}
	if profile.get("contract","")!="base508_source_action_capabilities_v1" or bool(profile.get("host_combat_ready",false)) or profile.get("source_behavior_family","")!="source_mobile_attack_actor" or profile.get("source_kind_preserved","")!="source_attackable_monster_actor":return {}
	if profile.get("source_category",{}).get("Name","")!="Npc" or not bool(profile.get("source_category",{}).get("IsAttackable",false)) or not profile.get("unresolved_source_action_ids",[]).is_empty():return {}
	for role:String in ["idle","walk"]:
		var expected:int=3 if role=="idle" else 0
		if not tracks.has(role) or int(tracks[role].get("source_action_id",-1))!=expected or int(profile.get("available_roles",{}).get(role,-1))!=expected or not _all_directions(tracks[role]):return {}
	var available:Dictionary={}
	for track:Dictionary in tracks.values():available[int(track.get("source_action_id",-1))]=track
	if not available.has(30) or not _all_directions(available[30]) or not available.has(1) or available[1].get("source_omitted_attachment_slots",[]).is_empty():return {}
	var selected:Dictionary={};var unadopted:Array=[]
	for row:Dictionary in catalog.get("npc_attacks",{}).get("66603",[]):
		if int(row.get("ID",-1))==242493 and _ordinary_source_row(row,66603) and int(row.get("MotionType",-1))==31 and int(row.get("WeaponType",-1))==0 and int(row.get("DiceBonus",-1))==21 and int(row.get("DiceCount",-1))==11 and int(row.get("DiceSpots",-1))==10:selected=row
		else:unadopted.append(int(row.ID))
	if selected.is_empty():return {}
	var candidates:Array=[]
	for action:Dictionary in catalog.get("source_actions",[]):
		if int(action.get("MotionType",-1))==31 and int(action.get("WeaponType",-1))==0 and available.has(int(action.get("ID",-1))):candidates.append(int(action.ID))
	if candidates!=[30]:return {}
	var matched:bool=false
	for route:Dictionary in profile.get("native_attack_routes",[]):
		if int(route.get("npc_attack_id",-1))!=242493:continue
		var declared:Array=route.get("candidate_action_ids",[])
		matched=declared.size()==1 and declared[0]==30.0 and int(route.get("resolved_action_id",-1))==30 and route.get("source_attack",{})==selected
	if not matched:return {}
	return {"contract":"base508_exact_context_ordinary_host_action_v1","host_combat_ready":true,"host_stationary":false,"source_npc_id":66603,"source_sprite_id":20363,"explicit_attack_id":242493,"attack_action_id":30,"required_roles":["idle","walk"],"selection_policy":"explicit_host_adoption_not_native_AI","unadopted_attack_ids":unadopted,"unadopted_basic_action_id":1,"unadopted_basic_omitted_attachment_slots":available[1].source_omitted_attachment_slots.duplicate(true),"adoption_contract":"Exact66603 adopts original alternate242493/action30 with complete eight stored directions. Basic242473/action1 retains missing shadow slots; absolute242483 remains unadopted. No basic readiness repair, pixels, native probability/delay or geography is inferred."}
