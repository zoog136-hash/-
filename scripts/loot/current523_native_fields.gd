extends RefCounted
## Item template access for registered native records (Lineage M style).
##
## Registered native records keep their light identity fields in the catalog;
## the heavy, read-mostly fields below stay in the baked item template and are
## read back by ItemClass ID when a record is actually used or shown. full()
## returns exactly the record registration produced: template key order, the
## record's own current values for every key it holds (later edits such as
## grade sync win), the template's values for the heavy fields it left out.
## Records without the marker (non-native, saved, edited) are returned as is.

## Heavy or rarely read registration fields. Readers go through full().
## The second group is read only by a few item checks and detail views; each
## key costs ~2.4 MB resident across the 30,310 registered records.
const HEAVY: Array[String] = ["source_use_spec","source_original_item","source_unhandled_bonuses","source_mapped_bonuses",
	"source_acquisition_policy","source_catalog_eligible","source_category_is_activatable","source_equip_slots","source_icon_id",
	"source_sprite_animation_id","source_unhandled_bonus_ids","source_weapon_type_name","source_effect_scope",
	"source_is_deletable","source_is_droppable","source_is_trash","source_label_status","source_max_level_limit_max",
	"source_max_level_limit_min","source_weight_unit","source_is_storable","source_effect_status","source_equipment_status",
	"source_unresolved_class_ids","source_is_tradable","source_is_consumable","source_category_id","source_class_names",
	# Third group: identity/condition fields read only on use, equip, craft
	# checks, detail views and messages, never per frame. Readers use field()/
	# has_field() (one key) or full(). Identity keys (source_item_class_id,
	# source_m_native_item, source_snapshot, source_definition_archive,
	# source_bless_raw), per-frame UI keys (source_sprite_id, source_grade_id)
	# and generic inventory keys (droppable, storable) stay resident.
	"source_image_status","source_condition_pending","source_weight","source_class_ids","source_equip_slot_ids",
	"source_level_limit_min","source_level_limit_max","source_delete_time_raw","source_is_stackable","tradable",
	"deletable","source_display_name","source_category_name"]
const MARK := "twilight_lazy_native_fields"
const CACHE_LIMIT := 128

static var _store: Object = null
static var _cache: Dictionary = {}
static var _order: Array[String] = []

static func bind(store: Object) -> void:
	_store = store
	_cache.clear()
	_order.clear()

static func lazy(record: Variant) -> bool:
	return record is Dictionary and (record as Dictionary).get(MARK) == true

## The light catalog form of a full registered record.
static func slim(record: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in record:
		if not key in HEAVY: result[key] = record[key]
	result[MARK] = true
	return result

static func full(record: Variant) -> Variant:
	if not lazy(record): return record
	var template: Dictionary = _template(str(int((record as Dictionary).get("source_item_class_id", 0))))
	if template.is_empty():
		var bare: Dictionary = (record as Dictionary).duplicate(false)
		bare.erase(MARK)
		return bare
	var result: Dictionary = {}
	for key: Variant in template:
		if (record as Dictionary).has(key): result[key] = record[key]
		elif key in HEAVY: result[key] = _copy(template[key])
	for key: Variant in record:
		if key != MARK and not result.has(key): result[key] = record[key]
	return result

## One key of full(record), without building the whole record: the record's
## own value when it holds the key, the template's value for a heavy key it
## left out, otherwise `default`. Same value (and copy semantics) as
## full(record).get(key, default).
static func field(record: Variant, key: String, default: Variant = null) -> Variant:
	if not record is Dictionary: return default
	var own: Dictionary = record
	if own.has(key): return own[key] if key != MARK or own.get(MARK) != true else default
	if own.get(MARK) != true or not key in HEAVY: return default
	var template: Dictionary = _template(str(int(own.get("source_item_class_id", 0))))
	return _copy(template[key]) if template.has(key) else default

## full(record).has(key) without building the whole record.
static func has_field(record: Variant, key: String) -> bool:
	if not record is Dictionary: return false
	var own: Dictionary = record
	if own.has(key): return key != MARK or own.get(MARK) != true
	if own.get(MARK) != true or not key in HEAVY: return false
	return _template(str(int(own.get("source_item_class_id", 0)))).has(key)

## full() for every record in an array (other values unchanged).
static func full_all(records: Array) -> Array:
	var result: Array = []
	for record: Variant in records: result.append(full(record))
	return result

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func _template(id: String) -> Dictionary:
	if _cache.has(id): return _cache[id]
	if _store == null: return {}
	var value: Variant = _store.call("record", id)
	var template: Dictionary = value if value is Dictionary else {}
	_cache[id] = template
	_order.append(id)
	if _order.size() > CACHE_LIMIT: _cache.erase(_order.pop_front())
	return template
