extends RefCounted
## Exact native scrolls for changing and removing a weapon's elemental enchant.
const BOOK = preload("res://scripts/crafting/patch523_enhance_source_book.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const RULES = preload("res://scripts/consumable_rules.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const CONVERT_IDS = [2751, 4511, 126472, 175572]
const REMOVE_IDS = [126482, 198031]

static func kind(record: Dictionary) -> String:
	var category: String = str(FIELDS.field(record, "source_category_name"))
	var id: int = int(record.get("source_item_class_id", 0))
	var convert: bool = category == "ScrollElementalConversion" and id in CONVERT_IDS
	var remove: bool = category == "ScrollElementalRemover" and id in REMOVE_IDS
	if not (convert or remove): return ""
	var definition: Dictionary = BOOK.checked_native(record)
	if int(definition.get("original_item", {}).get("ID", 0)) != id or not definition.get("item_bonus", []).is_empty(): return ""
	return "element_convert" if convert else "element_remove"

static func offer(world: Node, uid: String, record: Dictionary) -> Dictionary:
	var scroll: Dictionary = _scroll(world, uid, record)
	if not scroll.get("ok", false): return scroll
	var targets: Array[Dictionary] = []
	for id: String in world.item_instances:
		var entry: Dictionary = _target(world, id)
		if not entry.is_empty(): targets.append(entry)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return {"ok": true, "kind": scroll.kind, "uid": uid, "name": record.name, "record": record,
		"quantity": scroll.proof.remaining, "cost": scroll.cost, "targets": targets}

static func commit(world: Node, uid: String, record: Dictionary, quoted: Dictionary, choice: String) -> Dictionary:
	var scroll: Dictionary = _scroll(world, uid, record)
	if not scroll.get("ok", false): return scroll
	var target_uid: String = str(quoted.get("target_id", ""))
	var target: Dictionary = _target(world, target_uid)
	if target.is_empty() or target.name != quoted.get("name") or target.element != quoted.get("element") or target.element_level != quoted.get("element_level"):
		return _fail("선택한 무기의 속성이나 잠금 상태가 달라졌습니다")
	var convert: bool = scroll.kind == "element_convert"
	if convert and (not RULES.ELEMENT_NAMES.has(choice) or choice == target.element):
		return _fail("기존 속성과 다른 속성을 선택하세요")
	if int(world.gold) < int(scroll.cost): return _fail("아데나가 부족합니다")
	var proof: Dictionary = scroll.proof
	var paid: Dictionary = STACK.stage_debit(world, [{"physical_id": uid, "quantity": 1, "expected_quantity": proof.remaining,
		"expected_remaining": int(proof.remaining) - 1, "source_native_stack_receipt": proof.receipt}])
	if not paid.get("ok", false): return _fail(str(paid.get("reason", "주문서의 소지 수량을 확인하세요")))
	var payload: Dictionary = paid.overrides
	var changed: Dictionary = payload.item_instances[target_uid]
	if changed.get("equipment523", {}).has("elemental_smith"):
		changed["equipment523_retired_elemental_smith"] = changed.equipment523.elemental_smith
		changed.equipment523.erase("elemental_smith")
	changed["element"] = choice if convert else ""
	if not convert: changed["element_level"] = 0
	payload["gold"] = int(world.gold) - int(scroll.cost)
	if STACK.sealed_save(world, payload) != OK: return _fail("속성 변경 저장 실패 · 무기와 주문서를 보존했습니다")
	world.inventory = payload.inventory
	world.item_instances = payload.item_instances
	world.consumable_service.import_state(payload.consumable_state)
	world.gold = payload.gold
	STACK.clear_proof_cache()
	return {"ok": true, "message": "속성 변환 완료" if convert else "속성 제거 완료"}

static func _scroll(world: Node, uid: String, record: Dictionary) -> Dictionary:
	var action: String = kind(record)
	if action.is_empty() or STACK.busy or world.hp <= 0 or not world._patch523_item_allowed() or world._option_awakening_busy() or world.death_recovery.blocked():
		return _fail("현재 속성 주문서를 사용할 수 없습니다")
	var proof: Dictionary = STACK.proof(world, uid)
	var name_value: String = str(record.get("name", ""))
	if proof.is_empty() or proof.record != record or world._item_locked(name_value, uid) or world._item_locked(name_value):
		return _fail("가방에서 잠기지 않은 원본 속성 주문서를 선택하세요")
	var deadline: String = DROPS.deadline_problem(record, int(world.ui_preferences.get("patch523_source_clock_offset_minutes", 540)))
	if not deadline.is_empty(): return _fail(deadline)
	var cost: int = 0
	if action == "element_convert":
		var row: Dictionary = SOURCE.row("ConstantData", 421)
		var value: String = str(row.get("Value", ""))
		if row.get("Name") != "ElementalConvertCost" or row.get("Type") != 1 or not value.is_valid_int() or int(value) <= 0:
			return _fail("원본 속성 변환 수수료를 확인하세요")
		cost = int(value)
	return {"ok": true, "kind": action, "proof": proof, "cost": cost}

static func _target(world: Node, uid: String) -> Dictionary:
	var entry: Dictionary = world.item_instances.get(uid, {})
	var name_value: String = str(entry.get("name", ""))
	var record: Dictionary = entry.get("record", {})
	var level: int = int(entry.get("element_level", 0))
	var element: String = str(entry.get("element", ""))
	if name_value.is_empty() or int(world.inventory.get(name_value, 0)) <= 0 or level <= 0 or not RULES.ELEMENT_NAMES.has(element): return {}
	if world._item_locked(name_value, uid) or world._item_locked(name_value): return {}
	if record.is_empty(): record = world._find_catalog_item_record(name_value)
	if world._enhancement_kind_for_record(record) != "weapon": return {}
	var processing: Variant = entry.get("equipment523", {})
	if not processing is Dictionary or (processing.has("elemental_smith") and not processing.elemental_smith is Dictionary): return {}
	return {"target_id": uid, "name": name_value, "record": record, "element": element, "element_level": level,
		"level": int(entry.get("level", 0)), "smith": processing.has("elemental_smith")}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "reason": message}
