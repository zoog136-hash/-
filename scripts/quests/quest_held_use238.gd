extends RefCounted
## Run the unchanged PR238 consumer against an isolated inventory view. Only a
## verified held-stack debit plus the consumer effect is committed to the host.
const OWN = preload("res://scripts/quests/quest_reward_ownership.gd")
const USE = preload("res://scripts/loot/patch523_item_use.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")

class View extends Node:
	const BASE508 = preload("res://scripts/lineagem_base508.gd")
	var host: Node
	var prepared: Dictionary
	var owned: Dictionary
	var canonical: Dictionary
	var inventory: Dictionary
	var item_instances: Dictionary
	var active_item_buffs: Dictionary
	var item_use_cooldowns: Dictionary
	var gold: int
	var hp: int
	var mp: int
	var initial_inventory: Dictionary
	var initial_instances: Dictionary
	var committed: bool=false
	var uncertain: bool=false
	func _get(key: StringName) -> Variant: return host.get(key) if is_instance_valid(host) else null
	func is_player_concealed() -> bool:return host.is_player_concealed()
	func _option_awakening_busy() -> bool:return host._option_awakening_busy()
	func _format_seconds_short(value: float) -> String:return host._format_seconds_short(value)
	func _effective_max_hp() -> int:return host._effective_max_hp()
	func _effective_max_mp() -> int:return host._effective_max_mp()
	func _refresh_speed_modifiers() -> void:host._refresh_speed_modifiers()
	func _update_hud() -> void:host._update_hud()
	func _find_catalog_item_record(name_value: String) -> Dictionary:return host._find_catalog_item_record(name_value)
	func _catalog_item_from_source_id(id: String) -> Dictionary:return host._catalog_item_from_source_id(id)
	func _save_game(_quiet: bool, overrides: Dictionary) -> Error:
		if committed or not OWN.current(host,prepared):return ERR_INVALID_DATA
		for key: String in overrides:
			if key not in ["inventory","item_instances","gold","active_item_buffs","item_use_cooldowns"]:return ERR_INVALID_PARAMETER
		var proposed: Variant=overrides.get("inventory")
		if not proposed is Dictionary:return ERR_INVALID_DATA
		var virtual_key: String=str(canonical.name)
		if int(proposed.get(virtual_key,0))!=int(owned.quantity)-1 or proposed.get(owned.inventory_key)!=initial_inventory.get(owned.inventory_key):return ERR_INVALID_DATA
		if overrides.get("item_instances",initial_instances)!=initial_instances or int(overrides.get("gold",gold))!=host.gold:return ERR_INVALID_DATA
		var payload: Dictionary=prepared.override.duplicate(true)
		var keys: Dictionary={}
		for key: String in initial_inventory:keys[key]=true
		for key: String in proposed:keys[key]=true
		for key: String in keys:
			if key in [virtual_key,str(owned.inventory_key)]:continue
			var delta: int=int(proposed.get(key,0))-int(initial_inventory.get(key,0))
			if delta<0:return ERR_INVALID_DATA
			if delta>0:payload.inventory[key]=int(payload.inventory.get(key,0))+delta
		for key: String in ["active_item_buffs","item_use_cooldowns"]:
			if overrides.has(key):payload[key]=overrides[key].duplicate(true)
		# Persist the proven binding/use without converting or regranting the
		# held inventory. Original grant quantity and receipt remain immutable.
		var receipt: Dictionary=OWN.use_state(host,prepared,D.DATA_SHA)
		if not receipt.ok:return ERR_INVALID_DATA
		var state: Dictionary=receipt.state
		payload["quest_state"]=state
		var path: String=host.save_path()
		var prior: String=FileAccess.get_sha256(path)
		var error: Error=host._save_game(true,payload)
		if error!=OK:
			var durable: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
			var expected: Dictionary=JSON.parse_string(JSON.stringify(payload))
			var confirmed: bool=durable is Dictionary
			if confirmed:
				for key: String in expected:
					if durable.get(key)!=expected[key]:confirmed=false;break
			if not confirmed:
				if FileAccess.get_sha256(path)!=prior:host.quest_service.save_blocked=true;uncertain=true
				return error
			if not host.equipment_collections.accept_load(durable):host.quest_service.save_blocked=true;uncertain=true;return error
		host.inventory=payload.inventory;host.item_instances=payload.item_instances
		if payload.has("active_item_buffs"):host.active_item_buffs=payload.active_item_buffs
		if payload.has("item_use_cooldowns"):host.item_use_cooldowns=payload.item_use_cooldowns
		host.quest_service.import_state(state)
		host.deferred_save.cancel()
		committed=true
		return OK

static func perform(world: Node, prepared: Dictionary, canonical: Dictionary) -> Dictionary:
	if not OWN.current(world,prepared):return {"handled":true,"committed":false,"uncertain":false}
	var view:=View.new()
	view.host=world;view.prepared=prepared;view.owned=prepared.ownership;view.canonical=canonical
	view.inventory=world.inventory.duplicate(true);view.item_instances=world.item_instances.duplicate(true)
	view.inventory[str(canonical.name)]=int(view.owned.quantity)
	view.initial_inventory=view.inventory.duplicate(true);view.initial_instances=view.item_instances.duplicate(true)
	view.active_item_buffs=world.active_item_buffs.duplicate(true);view.item_use_cooldowns=world.item_use_cooldowns.duplicate(true)
	view.gold=world.gold;view.hp=world.hp;view.mp=world.mp
	var handled: bool=USE.try_use(view,canonical)
	var result: Dictionary={"handled":handled,"committed":view.committed,"uncertain":view.uncertain}
	view.free()
	return result
