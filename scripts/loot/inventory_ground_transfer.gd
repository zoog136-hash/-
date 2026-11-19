extends RefCounted

const NATIVE_STACK = preload("res://scripts/loot/current523_native_stack.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")

## Original ItemClass.IsDroppable of a native 523 item (true for other items).
static func source_droppable(item: Dictionary) -> bool:
	if item.get("source_m_native_item") != true: return true
	var original: Variant = NATIVE_FIELDS.full(item).get("source_original_item",{})
	return not (original is Dictionary and original.get("IsDroppable") == false)

## What one drag-out of `reference` may put on the floor, without changing
## anything: {ok, item_name, item_class_id, maximum} or {ok:false, message}.
static func quote(world: Node, reference: String) -> Dictionary:
	var parsed: Dictionary = world._parse_enhancement_target(reference)
	var item_name: String = str(parsed.name)
	var id: String = str(parsed.id)
	if id.is_empty():
		# A name-only slot of physical original stacks: the largest unlocked one.
		var best: int = 0
		for key: String in world.item_instances:
			var entry: Variant = world.item_instances[key]
			if not entry is Dictionary or entry.get("name") != item_name or not entry.has(NATIVE_STACK.RECEIPT) or world._item_locked(item_name,key) or world._is_instance_equipped(key): continue
			var owned: Dictionary = NATIVE_STACK.proof(world,key)
			if not owned.is_empty() and int(owned.remaining) > best:
				best = int(owned.remaining)
				id = key
		if not id.is_empty(): reference = item_name + "@@@" + id
	var held: int = int(world.inventory.get(item_name,0))
	if item_name.is_empty() or held < 1: return {"ok":false,"message":""}
	if world._item_locked(item_name,id) or world._item_locked(item_name): return {"ok":false,"message":"잠긴 아이템은 내려놓을 수 없습니다"}
	if not id.is_empty() and world._is_instance_equipped(id): return {"ok":false,"message":"장착을 해제한 뒤 내려놓으세요"}
	var item: Dictionary = world._find_catalog_item_record(item_name)
	var physical: Variant = world.item_instances.get(id,{}) if not id.is_empty() else {}
	if physical is Dictionary and physical.get("record") is Dictionary and not physical.record.is_empty(): item = physical.record
	if item.is_empty(): return {"ok":false,"message":""}
	if not bool(item.get("droppable",item.get("drop_allowed",true))) or bool(item.get("quest_item",false)) or not source_droppable(item):
		return {"ok":false,"message":"내려놓을 수 없는 아이템입니다"}
	var maximum: int = held
	if not id.is_empty():
		maximum = 1
		var owned: Dictionary = NATIVE_STACK.proof(world,id) if physical is Dictionary and physical.has(NATIVE_STACK.RECEIPT) else {}
		if not owned.is_empty(): maximum = maxi(1,int(owned.remaining))
	else:
		for existing: Variant in world.item_instances.values():
			if existing is Dictionary and existing.get("name")==item_name and (existing.has(NATIVE_STACK.RECEIPT) or existing.has("source_awakening_quantity") or existing.has("source_card_currency_quantity")):
				maximum = 1
				break
		if not world._enhancement_kind_for_record(item).is_empty(): maximum = 1
	return {"ok":true,"item_name":item_name,"item_class_id":int(item.get("source_item_class_id",0)) if item.get("source_m_native_item")==true else 0,"maximum":maximum,"reference":reference}

## Drag-out entry: checks, then the confirmation (with quantity for stacks),
## then drop(). Nothing moves before 확인.
static func request(world: Node, reference: String, requested_position: Vector2) -> Dictionary:
	if reference.is_empty() or not requested_position.is_finite(): return {"ok":false}
	var quoted: Dictionary = quote(world,reference)
	if not quoted.get("ok",false):
		if not str(quoted.get("message","")).is_empty(): world.hud.show_message(str(quoted.message))
		return quoted
	# A record name may carry a " · 원본#<id>" disambiguation suffix.
	var opened: Dictionary = world.hud.confirm_ground_drop(str(quoted.item_name).get_slice(" · 원본#",0),int(quoted.item_class_id),int(quoted.maximum),
		func(count: int) -> bool: return world._drop_inventory_reference(str(quoted.reference),requested_position,count))
	quoted["popup"] = opened
	return quoted

# Authoritative inventory <-> floor transfer. No await or user callback may run
# between ownership changes. Physical equipment is never recreated by name.
static func drop(world: Node, reference: String, requested_position: Vector2, count: int = 1) -> bool:
	if reference.is_empty() or not requested_position.is_finite() or count < 1: return false
	var native: Dictionary=NATIVE_STACK.drop(world,reference,requested_position,count)
	if native.get("handled",false):
		world.hud.show_message(str(native.get("message",native.get("reason","원본 바닥 이동 확인 필요"))))
		if native.get("ok",false):world._update_hud()
		return native.get("ok",false)
	var parsed: Dictionary = world._parse_enhancement_target(reference)
	var item_name: String = str(parsed.name)
	var id: String = str(parsed.id)
	if int(world.inventory.get(item_name,0)) < count: return false
	if world._item_locked(item_name,id) or world._item_locked(item_name):
		world.hud.show_message("잠긴 아이템은 내려놓을 수 없습니다")
		return false
	for existing: Variant in world.item_instances.values():
		if existing is Dictionary and existing.get("name")==item_name and existing.has("source_native_stack_receipt"):
			world.hud.show_message("원본 물리 묶음의 선택 수량 이동 연결 대기 · 보유 보존")
			return false
	var physical: Dictionary = {}
	var item: Dictionary = world._find_catalog_item_record(item_name)
	if id.is_empty() and preload("res://scripts/cards/source_awakening_items.gd").stackable_book(item):
		# A stacked source book may have verified instances alongside legacy
		# name-only copies. Transfer one verified instance without fabricating it.
		var verified_count: int=0
		for key: String in world.item_instances:
			var candidate: Dictionary=world.item_instances[key]
			if candidate.get("name","")==item_name and candidate.get("record") is Dictionary and preload("res://scripts/cards/source_awakening_items.gd").recognized(candidate.record) and candidate.record.get("sourceId","")==item.get("sourceId",""):
				verified_count+=1
				if id.is_empty() and not world._item_locked(item_name,key):id=key
		if id.is_empty() and verified_count>=int(world.inventory.get(item_name,0)):
			world.hud.show_message("잠긴 각성서는 내려놓을 수 없습니다")
			return false
	# Name-only legacy copies cannot gain provenance by touching the floor.
	if preload("res://scripts/cards/source_awakening_items.gd").recognized(item) and id.is_empty():return false
	if not id.is_empty():
		if not world.item_instances.has(id): return false
		physical = (world.item_instances[id] as Dictionary).duplicate(true)
		if str(physical.get("name","")) != item_name: return false
		if world._is_instance_equipped(id):
			world.hud.show_message("장착을 해제한 뒤 내려놓으세요")
			return false
		if physical.get("record") is Dictionary and not physical.record.is_empty(): item = physical.record
		elif preload("res://scripts/cards/source_awakening_items.gd").recognized(item):return false
	elif not world._enhancement_kind_for_record(item).is_empty():
		# Name-only equipment requests must never select an arbitrary instance.
		return false
	if item.is_empty(): return false
	if not bool(item.get("droppable",item.get("drop_allowed",true))) or bool(item.get("quest_item",false)) or not source_droppable(item):
		world.hud.show_message("내려놓을 수 없는 아이템입니다")
		return false
	if physical.has("source_native_stack_receipt"):
		# This source quantity owner currently supports use, not floor splitting.
		# Never remove a whole physical stack while decrementing inventory by one.
		world.hud.show_message("원본 물리 묶음의 선택 수량 이동 연결 대기 · 보유 보존")
		return false
	var player_position: Vector2 = world.player.global_position
	var offset: Vector2 = (requested_position-player_position).limit_length(96.0)
	var origin: Vector2 = player_position+offset
	if not world._is_walkable_world(origin) or not world._has_line_of_sight_world(player_position,origin): origin = player_position
	var payload: Dictionary = {"player_dropped":true,"item_record":item.duplicate(true)}
	var source_stack_remainder: Dictionary={}
	var split_id: int=0
	if physical.has("source_awakening_quantity"):
		var amount: Variant=physical.source_awakening_quantity
		if not preload("res://scripts/cards/native_awakening_supply.gd").integer(amount) or int(amount)<1 or int(amount)>int(world.inventory.get(item_name,0)):return false
		if int(amount)>1:
			source_stack_remainder=physical.duplicate(true);source_stack_remainder.source_awakening_quantity=int(amount)-1
			physical.source_awakening_quantity=1
			split_id=preload("res://scripts/cards/native_card_acquisition.gd").next_safe_id(world.item_instances,int(world.next_item_instance_id))
	elif physical.has("source_card_currency_quantity"):
		var source=preload("res://scripts/cards/native_card_acquisition.gd")
		var amount: Variant=physical.source_card_currency_quantity
		if not source.exact(item,source.COIN) or not source.integer(amount) or int(amount)<1 or int(amount)>int(world.inventory.get(item_name,0)):return false
		if int(amount)>1:
			source_stack_remainder=physical.duplicate(true)
			source_stack_remainder.source_card_currency_quantity=int(amount)-1
			physical.source_card_currency_quantity=1
			split_id=source.next_safe_id(world.item_instances,int(world.next_item_instance_id))
	if not physical.is_empty(): payload["physical_item"] = {"id":str(split_id) if split_id>0 else id,"data":physical}
	# Only a name-only stack moves several units as one floor record.
	if count > 1 and (not physical.is_empty() or not id.is_empty()): return false
	var view: Button = world.ground_loot.spawn(item_name,origin,count,"",payload)
	if view == null: return false # Inventory is untouched if no floor slot exists.
	world.inventory[item_name] = int(world.inventory[item_name])-count
	if not source_stack_remainder.is_empty():
		world.item_instances[id]=source_stack_remainder
		world.next_item_instance_id=split_id+1
	elif not id.is_empty(): world.item_instances.erase(id)
	world._update_hud()
	world._save_game(true)
	world.hud.show_message("%s %d개를 바닥에 내려놓았습니다" % [item_name,count])
	return true

static func payload_valid(record: Dictionary) -> bool:
	if not record.has("physical_item"): return true
	if not record.physical_item is Dictionary: return false
	var physical: Dictionary = record.physical_item
	if str(physical.get("id","")).is_empty() or not physical.get("data") is Dictionary or str(physical.data.get("name","")) != str(record.get("item_name","")): return false
	# A physical original stack may lie as one record of its whole remaining
	# quantity; current523_native_stack checks quantity == remaining.
	if physical.data.has(NATIVE_STACK.RECEIPT): return int(record.get("quantity",0)) >= 1
	return int(record.get("quantity",0)) == 1

static func can_collect(world: Node, record: Dictionary) -> bool:
	if not payload_valid(record): return false
	return not record.has("physical_item") or not world.item_instances.has(str(record.physical_item.id))

static func restore_physical(world: Node, record: Dictionary) -> void:
	if not record.has("physical_item"): return
	var id: String = str(record.physical_item.id)
	world.item_instances[id] = (record.physical_item.data as Dictionary).duplicate(true)
	if id.is_valid_int(): world.next_item_instance_id = maxi(world.next_item_instance_id,int(id)+1)
