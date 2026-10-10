extends RefCounted
# Serverless local warehouse. Enhancement, element and custom record state
# travel WITH the original physical instance ID, never with just its item name.
const MAX_TRANSFER: int = 9999
var stacks: Dictionary = {}
var instances: Dictionary = {}

static func fail(reason: String) -> Dictionary:
	return {"ok":false, "reason":reason}

static func equipped_id(equipped: Dictionary, instance_id: String) -> bool:
	for value: Variant in equipped.values():
		if value is Dictionary and str((value as Dictionary).get("instance_id", "")) == instance_id:
			return true
	return false

func snapshot() -> Dictionary:
	return {"stacks":stacks.duplicate(true), "instances":instances.duplicate(true)}

func restore(raw: Variant) -> void:
	stacks.clear()
	instances.clear()
	if not (raw is Dictionary):
		return
	var data: Dictionary = raw as Dictionary
	var loaded_stacks: Variant = data.get("stacks", {})
	var loaded_instances: Variant = data.get("instances", {})
	if loaded_stacks is Dictionary:
		for name: Variant in (loaded_stacks as Dictionary).keys():
			var count: int = int((loaded_stacks as Dictionary)[name])
			if count > 0 and count <= 1000000 and not str(name).is_empty():
				stacks[str(name)] = count
	if loaded_instances is Dictionary:
		for raw_id: Variant in (loaded_instances as Dictionary).keys():
			var id: String = str(raw_id)
			var value: Variant = (loaded_instances as Dictionary)[raw_id]
			if not id.is_empty() and value is Dictionary:
				var item: Dictionary = value as Dictionary
				var name: String = str(item.get("name", ""))
				if int(stacks.get(name,0)) > 0:
					instances[id] = item.duplicate(true)

func store(item_name: String, quantity: int, specific_id: String, inventory: Dictionary, physical: Dictionary, equipped: Dictionary, is_equipment: bool) -> Dictionary:
	if item_name.is_empty() or quantity < 1 or quantity > MAX_TRANSFER:
		return fail("보관 수량이 유효하지 않습니다")
	if int(inventory.get(item_name,0)) < quantity:
		return fail("인벤토리에 아이템이 부족합니다")
	var move_ids: Array[String] = []
	if is_equipment:
		for raw_id: Variant in physical.keys():
			var id: String = str(raw_id)
			if specific_id != "" and id != specific_id:
				continue
			var value: Variant = physical[raw_id]
			if not (value is Dictionary) or str((value as Dictionary).get("name", "")) != item_name:
				continue
			if equipped_id(equipped,id):
				continue
			if instances.has(id):
				continue
			move_ids.append(id)
		move_ids.sort()
		if specific_id != "" and quantity != 1:
			return fail("개별 장비는 한 개씩 지정해 보관합니다")
		if move_ids.size() < quantity:
			return fail("장착 중인 장비 또는 존재하지 않는 장비는 보관할 수 없습니다")
	for index: int in range(quantity if is_equipment else 0):
		var id: String = move_ids[index]
		instances[id] = (physical[id] as Dictionary).duplicate(true)
		physical.erase(id)
	inventory[item_name] = int(inventory.get(item_name,0)) - quantity
	stacks[item_name] = int(stacks.get(item_name,0)) + quantity
	return {"ok":true, "quantity":quantity}

func retrieve(item_name: String, quantity: int, specific_id: String, inventory: Dictionary, physical: Dictionary, is_equipment: bool, carried_weight: int, carrying_capacity: int, unit_weight: int) -> Dictionary:
	if item_name.is_empty() or quantity < 1 or quantity > MAX_TRANSFER:
		return fail("찾는 수량이 유효하지 않습니다")
	if int(stacks.get(item_name,0)) < quantity:
		return fail("창고에 아이템이 부족합니다")
	if unit_weight < 0 or carried_weight < 0 or carrying_capacity < 0 or carried_weight + unit_weight * quantity > carrying_capacity:
		return fail("소지 무게 한도를 초과합니다")
	var move_ids: Array[String] = []
	if is_equipment:
		for raw_id: Variant in instances.keys():
			var id: String = str(raw_id)
			if specific_id != "" and specific_id != id:
				continue
			var value: Variant = instances[raw_id]
			if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name and not physical.has(id):
				move_ids.append(id)
		move_ids.sort()
		if specific_id != "" and quantity != 1:
			return fail("개별 장비는 한 개씩 지정해 찾습니다")
		if move_ids.size() < quantity:
			return fail("창고 장비 개체 데이터가 일치하지 않습니다")
	for index: int in range(quantity if is_equipment else 0):
		var id: String = move_ids[index]
		physical[id] = (instances[id] as Dictionary).duplicate(true)
		instances.erase(id)
	stacks[item_name] = int(stacks.get(item_name,0)) - quantity
	if int(stacks[item_name]) <= 0:
		stacks.erase(item_name)
	inventory[item_name] = int(inventory.get(item_name,0)) + quantity
	return {"ok":true, "quantity":quantity}
