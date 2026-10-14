extends RefCounted

# Authoritative inventory <-> floor transfer. No await or user callback may run
# between ownership changes. Physical equipment is never recreated by name.
static func drop(world: Node, reference: String, requested_position: Vector2) -> bool:
	if reference.is_empty() or not requested_position.is_finite(): return false
	var parsed: Dictionary = world._parse_enhancement_target(reference)
	var item_name: String = str(parsed.name)
	var id: String = str(parsed.id)
	if int(world.inventory.get(item_name,0)) < 1: return false
	if world._item_locked(item_name,id):
		world.hud.show_message("잠긴 아이템은 내려놓을 수 없습니다")
		return false
	var physical: Dictionary = {}
	var item: Dictionary = world._find_catalog_item_record(item_name)
	if not id.is_empty():
		if not world.item_instances.has(id): return false
		physical = (world.item_instances[id] as Dictionary).duplicate(true)
		if str(physical.get("name","")) != item_name: return false
		if world._is_instance_equipped(id):
			world.hud.show_message("장착을 해제한 뒤 내려놓으세요")
			return false
		if physical.get("record") is Dictionary and not physical.record.is_empty(): item = physical.record
	elif not world._enhancement_kind_for_record(item).is_empty():
		# Name-only equipment requests must never select an arbitrary instance.
		return false
	if item.is_empty(): return false
	if not bool(item.get("droppable",item.get("drop_allowed",true))) or bool(item.get("quest_item",false)):
		world.hud.show_message("내려놓을 수 없는 아이템입니다")
		return false
	var player_position: Vector2 = world.player.global_position
	var offset: Vector2 = (requested_position-player_position).limit_length(96.0)
	var origin: Vector2 = player_position+offset
	if not world._is_walkable_world(origin) or not world._has_line_of_sight_world(player_position,origin): origin = player_position
	var payload: Dictionary = {"player_dropped":true,"item_record":item.duplicate(true)}
	if not physical.is_empty(): payload["physical_item"] = {"id":id,"data":physical}
	var view: Button = world.ground_loot.spawn(item_name,origin,1,"",payload)
	if view == null: return false # Inventory is untouched if no floor slot exists.
	world.inventory[item_name] = int(world.inventory[item_name])-1
	if not id.is_empty(): world.item_instances.erase(id)
	world._update_hud()
	world._save_game(true)
	world.hud.show_message("%s 1개를 바닥에 내려놓았습니다" % item_name)
	return true

static func payload_valid(record: Dictionary) -> bool:
	if not record.has("physical_item"): return true
	if not record.physical_item is Dictionary: return false
	var physical: Dictionary = record.physical_item
	return not str(physical.get("id","")).is_empty() and physical.get("data") is Dictionary and str(physical.data.get("name","")) == str(record.get("item_name","")) and int(record.get("quantity",0)) == 1

static func can_collect(world: Node, record: Dictionary) -> bool:
	if not payload_valid(record): return false
	return not record.has("physical_item") or not world.item_instances.has(str(record.physical_item.id))

static func restore_physical(world: Node, record: Dictionary) -> void:
	if not record.has("physical_item"): return
	var id: String = str(record.physical_item.id)
	world.item_instances[id] = (record.physical_item.data as Dictionary).duplicate(true)
	if id.is_valid_int(): world.next_item_instance_id = maxi(world.next_item_instance_id,int(id)+1)
