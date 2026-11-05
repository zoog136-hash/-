extends RefCounted
## New source identities use class + exact view/territory, never a legacy ID/name.
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
static func record(source_key: String, manifest_path: String = "", compatibility: Dictionary = {}) -> Dictionary:
	data()
	var context: Dictionary = _data.get("contexts", {}).get(source_key, {})
	if context.is_empty(): return _full_record(source_key, manifest_path, compatibility)
	var row: Dictionary = _by_npc.get(int(context.npc_id), {})
	if row.is_empty(): return {}
	var path: String = manifest_path if not manifest_path.is_empty() else BINDINGS.pack_manifest()
	var actor: Dictionary = PACK.actor(path, int(context.npc_id))
	if actor.is_empty() or int(actor.get("sprite_id", -1)) != int(context.sprite_id): return {}
	var available: bool = false
	for permitted: Dictionary in actor.get("source_contexts", [actor]):
		if int(permitted.get("spawn_view_id", -1)) == int(context.spawn_view_id) and int(permitted.get("territory_link_id", -1)) == int(context.territory_link_id): available = true
	if not available: return {}
	var host: Dictionary = {"atk":8,"speed":70.0,"attack_interval":1.25,"attack_range":58.0,"collision_radius":19.0,"grade":"일반","is_boss":bool(row.get("source_ui_boss",false))}
	host.merge(compatibility, true)
	var result: Dictionary = CONTEXT.record(int(context.npc_id), int(context.spawn_view_id), int(context.territory_link_id), host)
	if result.is_empty(): return {}
	result["sourceId"] = source_key
	result["source_m_catalog_key"] = source_key
	result["source_m_asset_manifest_path"] = path
	result["source_m_pixel_status"] = "private_source_model_registered; hash_checked_before_spawn"
	result["source_m_source_ui_boss"] = bool(row.get("source_ui_boss", false))
	result["source_m_host_placement"] = row.host_placement_contract
	return result
static func for_spawn(source_key: String, host_map_id: String, manifest_path: String = "", allow_contextual: bool = false) -> Dictionary:
	data()
	var context: Dictionary = _data.get("contexts", {}).get(source_key, {})
	if context.is_empty():
		var full_record: Dictionary = _full_record(source_key, manifest_path, {"source_m_allow_contextual":allow_contextual})
		if not full_record.is_empty():
			full_record["catalog_only"] = false
			full_record["source_m_runtime_host_map"] = host_map_id
		return full_record
	var row: Dictionary = _by_npc.get(int(context.npc_id), {})
	if not row.get("host_maps", []).has(host_map_id): return {}
	var result: Dictionary = record(source_key, manifest_path)
	if not result.is_empty():
		result["catalog_only"] = false
		result["source_m_runtime_host_map"] = host_map_id
	return result
static func primary_keys() -> Array:
	var result: Array = []
	for row: Dictionary in data().get("source_id_records", []): result.append(str(row.key))
	return result

static func _full_record(source_key: String, manifest_path: String, compatibility: Dictionary) -> Dictionary:
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

static func visual_record(source_key: String, manifest_path: String, allow_contextual: bool=false) -> Dictionary:
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
