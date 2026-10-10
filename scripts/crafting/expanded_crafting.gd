extends RefCounted
# All recipes are original TWILIGHT local-economy recipes. No source DB
# costs or Lineage crafting probabilities are implied.
const DATA_PATH = "res://data/crafting/twilight_recipes.json"
const MAX_BATCH: int = 20
var recipes: Dictionary = {}

func load_recipes() -> void:
	recipes.clear()
	if not FileAccess.file_exists(DATA_PATH):
		return
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (source is Dictionary) or int((source as Dictionary).get("schema_version",0)) != 1:
		return
	for raw: Variant in (source as Dictionary).get("recipes",[]):
		if raw is Dictionary:
			var record: Dictionary = raw as Dictionary
			var id: String = str(record.get("id",""))
			if not id.is_empty() and not recipes.has(id):
				recipes[id] = record.duplicate(true)

static func _error(reason: String) -> Dictionary:
	return {"ok":false, "reason":reason}

static func _item(items: Dictionary, name: String) -> Dictionary:
	var value: Variant = items.get(name,{})
	return value as Dictionary if value is Dictionary else {}

static func _is_equipment(record: Dictionary) -> bool:
	var slot: String = str(record.get("slot",""))
	return slot != "" and slot != "consumable" and slot != "currency"

static func _equipped(equipped: Dictionary,id: String) -> bool:
	for raw: Variant in equipped.values():
		if raw is Dictionary and str((raw as Dictionary).get("instance_id","")) == id:
			return true
	return false

static func _pristine(record: Dictionary) -> bool:
	return int(record.get("level",0)) == 0 and str(record.get("element","")) == "" and int(record.get("element_level",0)) == 0 and (record.get("record",{}) as Dictionary).is_empty()

# Produces an independent, validated snapshot. The caller never supplies price,
# item output or ingredient counts, only a recipe ID and batch size.
func quote(recipe_id: String, count: int, inventory: Dictionary, gold: int, items: Dictionary, physical: Dictionary, equipped: Dictionary, current_weight: int, capacity: int) -> Dictionary:
	if count < 1 or count > MAX_BATCH:
		return _error("제작 수량이 유효하지 않습니다")
	if gold < 0 or current_weight < 0 or capacity < 0:
		return _error("제작 상태가 유효하지 않습니다")
	if not recipes.has(recipe_id):
		return _error("등록되지 않은 제작법입니다")
	var recipe: Dictionary = recipes[recipe_id] as Dictionary
	var result: Variant = recipe.get("result",{})
	if not (result is Dictionary):
		return _error("제작 결과 데이터가 올바르지 않습니다")
	var output: String = str((result as Dictionary).get("item",""))
	var output_count: int = int((result as Dictionary).get("quantity",0))
	if output_count <= 0 or output_count > 99 or _item(items,output).is_empty():
		return _error("제작 결과물이 실제 아이템 DB에 없습니다")
	var output_record: Dictionary = _item(items,output)
	if bool(output_record.get("crafting_scroll",false)):
		return _error("비법서를 장비처럼 제작할 수 없습니다")
	var output_grade: String = str(output_record.get("grade",""))
	if _is_equipment(output_record) and output_grade in ["희귀","영웅","전설","신화","유일"]:
		var scroll_name: String = output_grade + " 제작 비법서"
		var scroll_item: Dictionary = _item(items,scroll_name)
		if not bool(scroll_item.get("crafting_scroll",false)) or str(scroll_item.get("slot","")) != "consumable" or str(scroll_item.get("grade","")) != output_grade:
			return _error("해당 등급 비법서 데이터가 없습니다")
		if str(recipe.get("required_scroll_grade","")) != output_grade:
			return _error("제작 비법서 조건이 누락되었습니다")
		var found: int = 0
		for entry: Variant in recipe.get("materials",[]):
			if entry is Dictionary and str((entry as Dictionary).get("item","")) == scroll_name and int((entry as Dictionary).get("quantity",0)) == 1:
				found += 1
		if found != 1:
			return _error("해당 등급 제작 비법서 1장이 필요합니다")
	var unit_cost: int = int(recipe.get("adena",-1))
	if unit_cost < 0 or unit_cost > 100000000:
		return _error("제작 비용이 올바르지 않습니다")
	var total_cost: int = unit_cost * count
	if gold < total_cost:
		return _error("아데나가 부족합니다")
	var material_rows: Variant = recipe.get("materials",[])
	if not (material_rows is Array) or (material_rows as Array).is_empty():
		return _error("제작 재료 목록이 비어 있습니다")
	var selections: Dictionary = {}
	var costs: Dictionary = {}
	var net_weight: int = current_weight
	for raw: Variant in material_rows:
		if not (raw is Dictionary):
			return _error("제작 재료 데이터가 올바르지 않습니다")
		var entry: Dictionary = raw as Dictionary
		var name: String = str(entry.get("item",""))
		var per_batch: int = int(entry.get("quantity",0))
		if per_batch < 1 or per_batch > 999 or costs.has(name) or _item(items,name).is_empty() or name == output:
			return _error("재료 이름·개수 또는 제작식이 잘못되었습니다")
		var required: int = per_batch * count
		if int(inventory.get(name,0)) < required:
			return _error(name + " 재료가 부족합니다")
		costs[name] = required
		net_weight -= maxi(0,int(_item(items,name).get("weight",3))) * required
		if _is_equipment(_item(items,name)):
			var ids: Array[String] = []
			for raw_id: Variant in physical.keys():
				var id: String = str(raw_id)
				var instance: Variant = physical[raw_id]
				if instance is Dictionary:
					var physical_record: Dictionary = instance as Dictionary
					if str(physical_record.get("name","")) == name and not _equipped(equipped,id) and _pristine(physical_record):
						ids.append(id)
			ids.sort()
			if ids.size() < required:
				return _error(name + " 장착/강화/속성 장비는 제작 재료로 사용할 수 없습니다")
			var chosen: Array[String] = []
			for index: int in range(required):
				chosen.append(ids[index])
			selections[name] = chosen
	var produced: int = output_count * count
	net_weight += maxi(0,int(_item(items,output).get("weight",3))) * produced
	if net_weight > capacity:
		return _error("제작 결과를 보관할 인벤토리 무게가 부족합니다")
	return {"ok":true, "result_name":output,"result_quantity":produced,
		"cost":total_cost,"materials":costs,"consumed_instance_ids":selections,"new_weight":net_weight}

# No await, callback, or UI value can interleave final validation and commit.
# Changes are staged in copies and only committed after every check passes.
func execute(recipe_id: String, count: int, inventory: Dictionary, gold: int, items: Dictionary, physical: Dictionary, equipped: Dictionary, current_weight: int, capacity: int, next_instance_id: int) -> Dictionary:
	var approval: Dictionary = quote(recipe_id,count,inventory,gold,items,physical,equipped,current_weight,capacity)
	if not bool(approval.get("ok",false)):
		return approval
	var staged_inventory: Dictionary = inventory.duplicate(true)
	var staged_physical: Dictionary = physical.duplicate(true)
	for name: String in approval["materials"]:
		staged_inventory[name] = int(staged_inventory.get(name,0)) - int(approval["materials"][name])
		if int(staged_inventory[name]) <= 0:
			staged_inventory.erase(name)
	for raw: Variant in (approval["consumed_instance_ids"] as Dictionary).values():
		for id: String in raw as Array:
			staged_physical.erase(id)
	var output: String = str(approval["result_name"])
	var produced: int = int(approval["result_quantity"])
	staged_inventory[output] = int(staged_inventory.get(output,0)) + produced
	var counter: int = maxi(1,next_instance_id)
	if _is_equipment(_item(items,output)):
		for _index: int in range(produced):
			var unique_id: String = str(counter)
			while staged_physical.has(unique_id):
				counter += 1
				unique_id = str(counter)
			staged_physical[unique_id] = {"name":output,"level":0,"element":"","element_level":0}
			counter += 1
	inventory.clear()
	inventory.merge(staged_inventory,true)
	physical.clear()
	physical.merge(staged_physical,true)
	approval["gold_after"] = gold - int(approval["cost"])
	approval["next_instance_id"] = counter
	return approval
