extends RefCounted
## Drops acquisition history that no game rule reads (user 2026-11-19:
## "어떤몬스터가 떨어트렸는가 같은 쓸데없이 비용만차지하는데이터들 ... 다 삭제해").
##
## Removed from owned items and their quantity ledgers:
## - source_m_drop_proof (which monster/drop rows a picked-up item came from)
##   on bag/warehouse/floor-owned item records and physical entries;
## - the receipt's copy of the whole original ItemClass row: the receipt is
##   marked like a catalog record (current523_native_fields MARK + ItemClass
##   ID), so full(receipt) still reads source_original_item (MaxStackAmount,
##   IsStorable ...) from the one installed definition;
## - the receipt's copy of the definition archive identity (the item record
##   keeps its own, which profile() checks);
## - a first grant's origin detail (floor id, the drop proof, box/package
##   inputs): only its kind stays. Partition/merge origins are structure and
##   are kept (their nested receipts are trimmed the same way);
## - consumable_state.source_ground_acquisitions (per-floor pickup receipts;
##   the floor entry leaves the same save, so it cannot be picked up twice).
## Everything else (quantity, used/transferred/remaining, bless, enchant,
## element, lock, equip, warehouse/floor placement, IDs) is untouched.
## Functions return the input itself when nothing is removed, else a copy
## that shares every untouched part (no deep copy per save).
##
## On disk only (for_file / loaded_save): an owned item record's heavy
## definition fields (current523_native_fields.HEAVY: the original ItemClass
## row, use spec, bonus lists ...) that are exactly the installed definition
## template's values are left out and the record is marked; loading puts the
## template's values back, so memory holds the same full record as before.
## A record is only shortened when that round trip is exact, and without an
## installed definition a marked record is kept marked (never saved bare).
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const RECEIPT := "source_native_stack_receipt"
const AWAKENING := "source_awakening_supply"
const DROP := "source_m_drop_proof"
const GROUND := "source_ground_acquisitions"
const STRUCTURAL := ["owned_quantity_partition","owned_quantity_merge"]
const RECEIPT_STATES := ["source_native_stack_uses","source_native_stack_partitions","source_native_stack_merges","source_native_ammo_equipped"]

static func _whole(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=1.0 and float(value)<=9007199254740991.0

static func _origin(origin: Variant) -> Variant:
	if not origin is Dictionary or origin.is_empty(): return origin
	var kind: Variant = origin.get("kind")
	if kind in STRUCTURAL:
		if kind == "owned_quantity_partition" and origin.get("parent_receipt") is Dictionary:
			var parent: Dictionary = receipt(origin.parent_receipt)
			if not is_same(parent, origin.parent_receipt):
				var copy: Dictionary = origin.duplicate(false); copy.parent_receipt = parent
				return copy
		return origin
	if origin.size() == 1 and origin.has("kind"): return origin
	return {"kind": kind if kind is String and not (kind as String).is_empty() else "twilight_trimmed_origin"}

## One native stack receipt (any schema), nested parent receipts included.
static func receipt(value: Dictionary) -> Dictionary:
	var result: Dictionary = value
	if value.has("source_original_item") and _whole(value.get("item_class_id")):
		result = value.duplicate(false)
		result.erase("source_original_item")
		result[NATIVE_FIELDS.MARK] = true
		result["source_item_class_id"] = int(value.item_class_id)
	if result.has("source_definition_archive") and (NATIVE_FIELDS.lazy(result) or not result.has("source_original_item")):
		if is_same(result, value): result = value.duplicate(false)
		result.erase("source_definition_archive")
	var origin: Variant = _origin(result.get("origin"))
	if not is_same(origin, result.get("origin")):
		if is_same(result, value): result = value.duplicate(false)
		result.origin = origin
	return result

static func record(value: Dictionary) -> Dictionary:
	if not value.has(DROP): return value
	var result: Dictionary = value.duplicate(false); result.erase(DROP)
	return result

## One physical item entry (bag, warehouse or floor physical data).
static func entry(value: Dictionary) -> Dictionary:
	var result: Dictionary = value
	if value.has(DROP):
		result = value.duplicate(false); result.erase(DROP)
	if value.get("record") is Dictionary:
		var trimmed: Dictionary = record(value.record)
		if not is_same(trimmed, value.record):
			if is_same(result, value): result = value.duplicate(false)
			result.record = trimmed
	if value.get(RECEIPT) is Dictionary:
		var trimmed_receipt: Dictionary = receipt(value[RECEIPT])
		if not is_same(trimmed_receipt, value[RECEIPT]):
			if is_same(result, value): result = value.duplicate(false)
			result[RECEIPT] = trimmed_receipt
	if value.get(AWAKENING) is Dictionary and value[AWAKENING].get("origin") is Dictionary:
		var origin: Variant = _origin(value[AWAKENING].origin)
		if not is_same(origin, value[AWAKENING].origin):
			if is_same(result, value): result = value.duplicate(false)
			var stamp: Dictionary = value[AWAKENING].duplicate(false); stamp.origin = origin
			result[AWAKENING] = stamp
	return result

static func entries(values: Variant) -> Variant:
	if not values is Dictionary: return values
	var result: Dictionary = values
	for uid: Variant in values:
		var item: Variant = values[uid]
		if not item is Dictionary: continue
		var trimmed: Dictionary = entry(item)
		if is_same(trimmed, item): continue
		if is_same(result, values): result = values.duplicate(false)
		result[uid] = trimmed
	return result

static func _rows(rows: Variant, keys: Array) -> Variant:
	if not rows is Dictionary: return rows
	var result: Dictionary = rows
	for id: Variant in rows:
		var row: Variant = rows[id]
		if not row is Dictionary: continue
		var next: Dictionary = row
		for key: String in keys:
			if next.get(key) is Dictionary:
				var trimmed: Dictionary = receipt(next[key])
				if not is_same(trimmed, next[key]):
					if is_same(next, row): next = row.duplicate(false)
					next[key] = trimmed
		if next.get("components") is Array:
			var parts: Array = next.components
			for index: int in parts.size():
				var part: Variant = parts[index]
				if part is Dictionary and part.get("receipt") is Dictionary:
					var trimmed_part: Dictionary = receipt(part.receipt)
					if not is_same(trimmed_part, part.receipt):
						if is_same(parts, next.components):
							if is_same(next, row): next = row.duplicate(false)
							parts = parts.duplicate(false); next.components = parts
						var copy: Dictionary = part.duplicate(false); copy.receipt = trimmed_part
						parts[index] = copy
		if is_same(next, row): continue
		if is_same(result, rows): result = rows.duplicate(false)
		result[id] = next
	return result

static func consumables(state: Variant) -> Variant:
	if not state is Dictionary: return state
	var result: Dictionary = state
	if state.has(GROUND):
		result = state.duplicate(false); result.erase(GROUND)
	var updates: Dictionary = {
		"source_native_stack_uses": _rows(state.get("source_native_stack_uses"), ["receipt"]),
		"source_native_stack_partitions": _rows(state.get("source_native_stack_partitions"), ["parent_receipt","child_receipt"]),
		"source_native_stack_merges": _rows(state.get("source_native_stack_merges"), []),
	}
	var ammo: Variant = state.get("source_native_ammo_equipped")
	if ammo is Dictionary and ammo.get("receipt") is Dictionary:
		var trimmed_ammo: Dictionary = receipt(ammo.receipt)
		if not is_same(trimmed_ammo, ammo.receipt):
			var copy: Dictionary = ammo.duplicate(false); copy.receipt = trimmed_ammo
			updates["source_native_ammo_equipped"] = copy
	for key: String in updates:
		if not state.has(key) or is_same(updates[key], state[key]): continue
		if is_same(result, state): result = state.duplicate(false)
		result[key] = updates[key]
	return result

static func floor_entries(values: Variant) -> Variant:
	if not values is Array: return values
	var result: Array = values
	for index: int in values.size():
		var drop: Variant = values[index]
		if not drop is Dictionary or not drop.get("physical_item") is Dictionary or not drop.physical_item.get("data") is Dictionary: continue
		var data: Dictionary = entry(drop.physical_item.data)
		if is_same(data, drop.physical_item.data): continue
		# A player-dropped owned stack keeps item_record == its physical record.
		var next: Dictionary = drop.duplicate(false)
		var physical: Dictionary = drop.physical_item.duplicate(false); physical.data = data
		next.physical_item = physical
		if drop.get("player_dropped") == true and drop.get("item_record") is Dictionary and data.get("record") is Dictionary: next.item_record = data.record
		if is_same(result, values): result = values.duplicate(false)
		result[index] = next
	return result

## One world payload (flat save body or one character's state).
static func payload(data: Dictionary) -> Dictionary:
	var result: Dictionary = data
	var updates: Dictionary = {}
	if data.has("item_instances"): updates["item_instances"] = entries(data.item_instances)
	if data.has("consumable_state"): updates["consumable_state"] = consumables(data.consumable_state)
	if data.has("ground_drops"): updates["ground_drops"] = floor_entries(data.ground_drops)
	if data.get("warehouse") is Dictionary and data.warehouse.has("instances"):
		var stored: Variant = entries(data.warehouse.instances)
		if not is_same(stored, data.warehouse.instances):
			var warehouse: Dictionary = data.warehouse.duplicate(false); warehouse.instances = stored
			updates["warehouse"] = warehouse
	for key: String in updates:
		if is_same(updates[key], data.get(key)): continue
		if is_same(result, data): result = data.duplicate(false)
		result[key] = updates[key]
	return result

## A parsed save file, in place: flat body, account shared state and every
## character's state, so shared quantity journals and offline characters'
## items keep one identical receipt form.
static func loaded_save(data: Dictionary) -> void:
	_expand_in_place(data)
	var account_value: Variant = data.get("character_account")
	if account_value is Dictionary:
		if account_value.get("shared") is Dictionary: _expand_in_place(account_value.shared)
		if account_value.get("characters") is Array:
			for character: Variant in account_value.characters:
				if character is Dictionary and character.get("state") is Dictionary: _expand_in_place(character.state)
	var flat: Dictionary = payload(data)
	for key: Variant in flat: data[key] = flat[key]
	var account: Variant = data.get("character_account")
	if not account is Dictionary: return
	if account.get("shared") is Dictionary:
		var shared: Dictionary = payload(account.shared)
		for key: Variant in shared: account.shared[key] = shared[key]
	if account.get("characters") is Array:
		for character: Variant in account.characters:
			if character is Dictionary and character.get("state") is Dictionary:
				var state: Dictionary = payload(character.state)
				for key: Variant in state: character.state[key] = state[key]

## A payload as the save file holds it after JSON (for "was this written?"
## comparisons against the durable file).
static func durable(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(for_file(data), "", true, true))
	return parsed if parsed is Dictionary else {}
const SAVED_TEMPLATE := "twilight_saved_template_fields"

static func _record_template(value: Dictionary) -> Dictionary:
	if value.get("source_m_native_item") != true or not _whole(value.get("source_item_class_id")): return {}
	return NATIVE_FIELDS._template(str(int(value.source_item_class_id)))

## The on-disk form of one item record.
static func slim_record(value: Dictionary) -> Dictionary:
	if value.has(SAVED_TEMPLATE) or NATIVE_FIELDS.lazy(value): return value
	var template: Dictionary = _record_template(value)
	if template.is_empty(): return value
	var dropped: Array = []
	for key: String in NATIVE_FIELDS.HEAVY:
		if not template.has(key): continue
		if not value.has(key): return value # would come back on load: keep as is
		if value[key] == template[key]: dropped.append(key)
	if dropped.is_empty(): return value
	var result: Dictionary = value.duplicate(false)
	for key: String in dropped: result.erase(key)
	result[SAVED_TEMPLATE] = true
	return result

## The memory form of a record read from disk (template values put back).
static func expand_record(value: Dictionary) -> Dictionary:
	if not value.has(SAVED_TEMPLATE): return value
	var template: Dictionary = _record_template(value)
	if template.is_empty(): return value
	var result: Dictionary = value.duplicate(false)
	result.erase(SAVED_TEMPLATE)
	for key: String in NATIVE_FIELDS.HEAVY:
		if template.has(key) and not result.has(key):
			var field: Variant = template[key]
			result[key] = field.duplicate(true) if field is Dictionary or field is Array else field
	return result

static func _map_records(entry_value: Dictionary, map: Callable) -> Dictionary:
	if not entry_value.get("record") is Dictionary: return entry_value
	var mapped: Dictionary = map.call(entry_value.record)
	if is_same(mapped, entry_value.record): return entry_value
	var result: Dictionary = entry_value.duplicate(false); result.record = mapped
	return result

static func _records_in(data: Dictionary, map: Callable) -> Dictionary:
	var result: Dictionary = data
	var each: Callable = func(values: Variant) -> Variant:
		if not values is Dictionary: return values
		var out: Dictionary = values
		for uid: Variant in values:
			if not values[uid] is Dictionary: continue
			var mapped: Dictionary = _map_records(values[uid], map)
			if is_same(mapped, values[uid]): continue
			if is_same(out, values): out = values.duplicate(false)
			out[uid] = mapped
		return out
	var instances: Variant = each.call(data.get("item_instances"))
	if data.has("item_instances") and not is_same(instances, data.item_instances):
		result = data.duplicate(false); result.item_instances = instances
	if data.get("warehouse") is Dictionary and data.warehouse.has("instances"):
		var stored: Variant = each.call(data.warehouse.instances)
		if not is_same(stored, data.warehouse.instances):
			if is_same(result, data): result = data.duplicate(false)
			var warehouse: Dictionary = data.warehouse.duplicate(false); warehouse.instances = stored; result.warehouse = warehouse
	if data.get("ground_drops") is Array:
		var floor: Array = data.ground_drops
		for index: int in floor.size():
			var drop: Variant = floor[index]
			if not drop is Dictionary: continue
			var next: Dictionary = drop
			if drop.get("item_record") is Dictionary:
				var item: Dictionary = map.call(drop.item_record)
				if not is_same(item, drop.item_record): next = drop.duplicate(false); next.item_record = item
			if drop.get("physical_item") is Dictionary and drop.physical_item.get("data") is Dictionary:
				var physical_data: Dictionary = _map_records(drop.physical_item.data, map)
				if not is_same(physical_data, drop.physical_item.data):
					if is_same(next, drop): next = drop.duplicate(false)
					var physical: Dictionary = drop.physical_item.duplicate(false); physical.data = physical_data; next.physical_item = physical
			if is_same(next, drop): continue
			if is_same(floor, data.ground_drops):
				floor = floor.duplicate(false)
				if is_same(result, data): result = data.duplicate(false)
				result.ground_drops = floor
			floor[index] = next
	return result

## What a world save writes: trimmed history and template-shortened records.
static func for_file(data: Dictionary) -> Dictionary:
	return _records_in(payload(data), slim_record)

static func _expand_in_place(data: Dictionary) -> void:
	var expanded: Dictionary = _records_in(data, expand_record)
	for key: Variant in expanded: data[key] = expanded[key]
