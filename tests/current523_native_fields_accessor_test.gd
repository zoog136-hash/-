extends SceneTree
## NATIVE_FIELDS.field()/has_field() answer exactly as full(record).get()/has()
## for lazy, edited, template-less and ordinary records; template values are
## copies. Synthetic templates; needs no 523 tables.
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
var checks: int = 0
var failures: Array[String] = []

class Store extends RefCounted:
	var records: Dictionary = {}
	func record(id: String) -> Variant: return records.get(id)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b

func run() -> void:
	var store := Store.new()
	var template: Dictionary = {"name":"검 · 원본#7","source_item_class_id":7,"source_display_name":"검","source_class_ids":[1,2],
		"source_condition_pending":[],"source_level_limit_min":10,"source_delete_time_raw":202611110500,"source_weight":1.5,"slot":"weapon","grade":"고급"}
	store.records["7"] = template
	FIELDS.bind(store)
	var lazy: Dictionary = FIELDS.slim(template)
	check(not lazy.has("source_display_name") and not lazy.has("source_class_ids") and lazy.get(FIELDS.MARK) == true, "moved keys leave the light record")
	var edited: Dictionary = lazy.duplicate(true); edited["source_display_name"] = "다른 검"; edited["extra"] = 3
	var orphan: Dictionary = {"source_item_class_id":8,"name":"x",FIELDS.MARK:true}
	var plain: Dictionary = template.duplicate(true); plain[FIELDS.MARK] = false
	var keys: Array = template.keys() + ["extra","missing",FIELDS.MARK,"source_category_name"]
	for record: Dictionary in [lazy, edited, orphan, plain, {}]:
		var whole: Dictionary = FIELDS.full(record)
		for key: Variant in keys:
			check(same(FIELDS.field(record, key, "default"), whole.get(key, "default")), "field %s of %s" % [key, record.get("name","{}")])
			check(FIELDS.has_field(record, key) == whole.has(key), "has_field %s of %s" % [key, record.get("name","{}")])
	var ids: Variant = FIELDS.field(lazy, "source_class_ids")
	(ids as Array).append(9)
	check(template.source_class_ids == [1,2], "template values are returned as copies")
	check(FIELDS.field(null, "source_display_name", "d") == "d" and not FIELDS.has_field(null, "source_display_name"), "non-records answer the default")
	FIELDS.bind(null)
	print("CURRENT523_NATIVE_FIELDS_ACCESSOR_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
