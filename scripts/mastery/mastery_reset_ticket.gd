extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Ticket-specific adapter, not a second general item catalog or ownership source.
var definition: Dictionary = {}
var fingerprint: String = ""

static func canonical(value: Variant) -> Variant:
	# JSON loads numbers as float; hash the same integral source rows as Python.
	if value is float and is_finite(value) and value == floorf(value) and absf(value) < 9007199254740992.0: return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: String in value: result[key] = canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(canonical(entry))
		return result
	return value

func configure(operation: Dictionary) -> bool:
	definition = {}; fingerprint = ""
	var source: Variant = operation.get("definition")
	if not source is Dictionary: return false
	var digest: String = JSON.stringify(canonical(source),"",true).sha256_text()
	if digest != operation.get("definition_sha256",""): return false
	for key: String in ["constant","currency","currency_link","item","category","grade"]:
		if not source.get(key) is Dictionary: return false
	if source.constant.get("Name") != "MasteryResetTicketCurrencyID" or source.constant.get("Value") != "1814" or source.currency.get("ID") != 1814: return false
	if source.currency_link.get("CurrencyID") != 1814 or source.currency_link.get("UnitID") != 4 or source.currency_link.get("ClassID") != 184652 or source.currency_link.get("ForGive") != false: return false
	if source.item.get("ID") != 184652 or source.item.get("TestItem") != false or source.item.get("CategoryID") != source.category.get("ID") or source.item.get("GradeID") != source.grade.get("ID"): return false
	if source.category.get("Name") != "Currency" or source.category.get("IsStackable") != true or source.category.get("IsConsumable") != false or source.category.get("IsActivatable") != false: return false
	if source.get("bonuses") != [] or source.item.get("ServiceRegionCode") != "" or source.item.get("TargettingTypeID") != 1: return false
	for key: String in ["LevelLimitMin","LevelLimitMax","MaxLevelLimitMin","MaxLevelLimitMax"]:
		if source.item.get(key) != 0: return false
	var normal: bool = false
	for row: Dictionary in source.get("bless_codes",[]):
		if row.get("ID") == 1 and row.get("Name") == "Normal": normal = true
	if not normal or str(source.get("label","")).is_empty(): return false
	definition = source.duplicate(true); fingerprint = digest
	return true

func record() -> Dictionary:
	if definition.is_empty(): return {}
	# Same namespace/display convention as the read-only PR238 contract.
	var label: String = str(definition.label)
	var item: Dictionary = definition.item
	return {"name":label+" · 원본#184652","source_display_name":label,"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:184652","source_item_class_id":184652,"source_m_native_item":true,"source_category_id":int(definition.category.ID),"source_category_name":"Currency","source_is_stackable":true,"source_is_consumable":false,"source_bless_raw":1,"source_definition_sha256":fingerprint,"source_original_item":item.duplicate(true),"source_grade_id":int(item.GradeID),"grade":"일반","type":"재화","slot":"currency","stackable":true,"weight":int(item.Weight),"source_grade_name":str(definition.grade.Name),"source_image_status":"original_icon_not_installed","tradable":bool(item.IsTradable),"storable":bool(item.IsStorable),"droppable":bool(item.IsDroppable),"deletable":bool(item.IsDeletable),"desc":"숙련 옵션 변경 지불용 · 원본 티켓 · 지급/획득 경로 별도"}

func exact(value: Dictionary) -> bool:
	value = NATIVE_FIELDS.full(value)
	var target: Dictionary = record()
	if target.is_empty(): return false
	for key: String in ["name","source","source_snapshot","sourceId","source_item_class_id","source_category_id","source_category_name","source_bless_raw","source_definition_sha256","source_original_item"]:
		if value.get(key) != target[key]: return false
	return true

func install(world) -> Dictionary:
	var target: Dictionary = record()
	if target.is_empty(): return {"ok":false,"reason":"ticket_source_missing"}
	for item: Dictionary in world.catalog_db.get("아이템",[]):
		if exact(item): return {"ok":true,"existing":true}
		if item.get("name") == target.name or item.get("sourceId") == target.sourceId: return {"ok":false,"reason":"ticket_catalog_conflict"}
	world.catalog_db["아이템"].append(target)
	world._index_catalog_item_sources()
	world._index_item_weights()
	return {"ok":true}

func owned_ids(world) -> Dictionary:
	var target: Dictionary = record()
	if target.is_empty(): return {"ok":false,"reason":"ticket_source_missing"}
	if not exact(world._find_catalog_item_record(str(target.name),str(target.sourceId))): return {"ok":false,"reason":"ticket_catalog_conflict"}
	var count: Variant = world.inventory.get(target.name,0)
	if not (count is int or count is float) or not is_finite(float(count)) or float(count) != floorf(float(count)) or count < 0 or count > int(definition.item.MaxStackAmount): return {"ok":false,"reason":"invalid_ticket_count"}
	var ids: Array[String] = []
	var physical_count: int = 0
	for id: String in world.item_instances:
		var physical: Variant = world.item_instances[id]
		if not physical is Dictionary or physical.get("name") != target.name: continue
		physical_count += 1
		# Name-only, forged definitions and blessed/cursed instances never qualify.
		if not physical.get("record") is Dictionary or not exact(physical.record): continue
		if physical.get("bless_state","normal") != "normal" or physical.get("level",0) != 0 or world._is_instance_equipped(id): continue
		ids.append(id)
	if physical_count > int(count): return {"ok":false,"reason":"ticket_ownership_count_mismatch"}
	return {"ok":true,"ids":ids,"count":int(count)}

func prepare(world, cost: int) -> Dictionary:
	if cost <= 0: return {"ok":false,"reason":"ticket_not_applicable"}
	var owned: Dictionary = owned_ids(world)
	if not owned.ok: return owned
	var item_name: String = str(record().name)
	if world._item_locked(item_name): return {"ok":false,"reason":"material_locked"}
	var selected: Array[String] = []
	for id: String in owned.ids:
		if not world._item_locked(item_name,id): selected.append(id)
	if selected.size() < cost: return {"ok":false,"reason":"insufficient_verified_tickets"}
	var bag: Dictionary = world.inventory.duplicate(true)
	var physicals: Dictionary = world.item_instances.duplicate(true)
	for index: int in cost: physicals.erase(selected[index])
	if int(owned.count) == cost: bag.erase(item_name)
	else: bag[item_name] = int(owned.count)-cost
	return {"ok":true,"inventory":bag,"item_instances":physicals,"gold":int(world.gold),"consumed_ids":selected.slice(0,cost)}
