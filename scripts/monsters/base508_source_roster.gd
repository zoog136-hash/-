extends RefCounted
## New source identities use class + exact view/territory, never a legacy ID/name.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const FULL = preload("res://scripts/monsters/base508_authoritative_catalog.gd")
const PATH = "res://data/lineagem_base508/monster_batch02/runtime_registry.json"
const CONTEXT = preload("res://scripts/monsters/base508_monster_context.gd")
const BINDINGS = preload("res://scripts/monsters/base508_monster_bindings.gd")
const PACK = preload("res://scripts/monsters/base508_monster_pack_cache.gd")
const BOSS_COMBAT = preload("res://scripts/monsters/base508_boss_combat.gd")
const HOST_ACTIONS = preload("res://scripts/monsters/base508_boss_host_adoptions.gd")
static var _data: Dictionary = {}
static var _by_npc: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if value is Dictionary and value.get("source_snapshot", "") == "base508":
			_data = value
			for row: Dictionary in value.get("source_id_records", []): _by_npc[int(row.npc_id)] = row
	return _data
static func _current_record(source_key: String,host: Dictionary) -> Dictionary:
	var ids: Dictionary=FULL.parse_key(source_key)
	if ids.is_empty() or SOURCE.identity().is_empty():return {}
	var raw: Dictionary=SOURCE.row("NpcClass",int(ids.npc_id))
	if raw.get("TestNPC")!=false or not SOURCE.declared_exclusion("NpcClass",raw).is_empty():return {}
	var category: Dictionary=SOURCE.row("NpcCategory",int(raw.get("Category",-1)))
	if category.get("IsAttackable")!=true or category.get("Name")=="Citizen":return {}
	var result: Dictionary=CONTEXT.record(int(ids.npc_id),int(ids.view_id),int(ids.link_id),host)
	if result.is_empty():return {}
	result["sourceId"]=source_key;result["source_m_catalog_key"]=source_key
	# Empty old visual path is deliberate: it cannot select the old actor pack.
	result["source_m_asset_manifest_path"]=""
	result["source_m_host_placement"]="Existing explicit host region; current original source tuple"
	result["source_m_current523_final"]=true
	return result

static func record(source_key: String, _manifest_path: String="",compatibility: Dictionary={}) -> Dictionary:
	var host: Dictionary={"atk":8,"speed":70.0,"attack_interval":1.25,"attack_range":58.0,"collision_radius":19.0,"grade":"일반"}
	host.merge(compatibility,true)
	# Exact host fallback provenance only; explicit caller stats keep ownership.
	host.erase("source_m_ordinary_host_atk_default")
	if not compatibility.has("atk") and not compatibility.has("attack") and not compatibility.has("공격력"):
		host["source_m_ordinary_host_atk_default"]={"kind":"twilight_host_default","producer":"base508_source_roster.record","value":8}
	return _current_record(source_key,host)

static func for_spawn(source_key: String,host_map_id: String,_manifest_path: String="",allow_contextual: bool=false) -> Dictionary:
	if host_map_id.is_empty():return {}
	# A host region requests this exact key; this never chooses a location,
	# population, respawn period, source attack or a different visual identity.
	var result: Dictionary=record(source_key,"",{"source_m_allow_contextual":allow_contextual})
	if result.is_empty():return {}
	result["catalog_only"]=false;result["source_m_runtime_host_map"]=host_map_id
	return result
static func primary_keys() -> Array:
	var result: Array = []
	for row: Dictionary in data().get("source_id_records", []): result.append(str(row.key))
	return result

static func _legacy_full_record_for_reference(source_key: String, manifest_path: String, compatibility: Dictionary) -> Dictionary:
	var ids: Dictionary = FULL.parse_key(source_key)
	if ids.is_empty() or not FULL.enemy_eligible(int(ids.npc_id), bool(compatibility.get("source_m_allow_contextual", false))): return {}
	var path: String = manifest_path if not manifest_path.is_empty() else BINDINGS.pack_manifest()
	var actor: Dictionary = PACK.actor(path, int(ids.npc_id))
	if actor.is_empty(): return {}
	var profile: Dictionary=actor.get("source_actor_profile",{})
	var action_contract: Dictionary={}
	if not profile.is_empty():
		if not bool(profile.get("host_combat_ready",false)):
			if not bool(compatibility.get("source_m_allow_contextual",false)): return {}
			# These actors retain their authored action18, never a fabricated
			# basic-attack clip. A pinned combat table and explicit adoption must
			# agree before the ordinary combat factory can expose the record.
			action_contract=HOST_ACTIONS.actor_contract(int(ids.npc_id),int(actor.get("sprite_id",-1)),profile,actor.get("tracks",{}),BOSS_COMBAT.data(path.get_base_dir()))
			if action_contract.is_empty(): return {}
		var required: Array=action_contract.get("required_roles",["idle","walk","attack"])
		for role: String in required:
			if not actor.get("tracks",{}).has(role): return {}
		if not bool(profile.get("source_category",{}).get("IsAttackable",false)) or profile.get("source_category",{}).get("Name","")=="Citizen": return {}
	var host: Dictionary = {"atk":8,"speed":70.0,"attack_interval":1.25,"attack_range":58.0,"collision_radius":19.0,"grade":"일반"}
	host["is_boss"] = bool(FULL.npc(int(ids.npc_id)).get("source_ui_boss", false))
	host.merge(compatibility, true)
	if bool(action_contract.get("host_stationary",false)):
		host["speed"]=0.0
		host["source_m_host_stationary"]=true
	var result: Dictionary = FULL.source_record(source_key, host)
	if result.is_empty() or int(result.get("source_m_sprite_id", -1)) != int(actor.get("sprite_id", -2)): return {}
	result["source_m_asset_manifest_path"] = path
	result["source_m_actor_profile"]=profile.duplicate(true)
	if not action_contract.is_empty():
		result["source_m_host_action_contract"]=action_contract.duplicate(true)
		result["source_m_host_combat_ready"]=true
		if HOST_ACTIONS.for_record(result,"",BOSS_COMBAT.data(path.get_base_dir())).is_empty(): return {}
	result["source_m_host_placement"] = "Explicit host region source-key port; native geography unverified"
	return result

static func _legacy_visual_record_for_reference(source_key: String, manifest_path: String, allow_contextual: bool=false) -> Dictionary:
	var ids: Dictionary=FULL.parse_key(source_key)
	if ids.is_empty(): return {}
	var row: Dictionary=FULL.npc(int(ids.npc_id))
	if row.is_empty() or bool(row.get("source_TestNPC",false)): return {}
	if not allow_contextual and not row.get("literal_context_evidence",[]).is_empty(): return {}
	var actor: Dictionary=PACK.actor(manifest_path,int(ids.npc_id))
	if actor.is_empty(): return {}
	var result: Dictionary=FULL.source_record(source_key,{"atk":0,"speed":0.0,"source_m_visual_only":true,"source_m_host_combat_ready":false})
	if result.is_empty() or int(result.get("source_m_sprite_id",-1))!=int(actor.get("sprite_id",-2)): return {}
	result["source_m_asset_manifest_path"]=manifest_path
	result["source_m_actor_profile"]=actor.get("source_actor_profile",{}).duplicate(true)
	# A literal single-slot source object may be displayed in its one authored
	# direction. No mirrored/copied facing or ordinary combat actor is created.
	if int(actor.get("source_partial_direction_contract",0))==1:
		var slots: Array=actor.get("source_actor_profile",{}).get("source_common_direction_slots",[])
		if slots.size()==1:
			result["source_m_fixed_source_slot"]=int(slots[0])
	return result

static func visual_record(source_key: String,_manifest_path: String,allow_contextual: bool=false) -> Dictionary:
	var ids: Dictionary=FULL.parse_key(source_key)
	if ids.is_empty() or SOURCE.identity().is_empty():return {}
	var raw: Dictionary=SOURCE.row("NpcClass",int(ids.npc_id))
	if raw.get("TestNPC")!=false or not SOURCE.declared_exclusion("NpcClass",raw).is_empty():return {}
	var result: Dictionary=CONTEXT.record(int(ids.npc_id),int(ids.view_id),int(ids.link_id),{"atk":0,"speed":0.0,"source_m_visual_only":true,"source_m_host_combat_ready":false,"source_m_allow_contextual":allow_contextual})
	if result.is_empty():return {}
	result["source_m_asset_manifest_path"]=""
	result["source_m_current523_final"]=true
	return result
