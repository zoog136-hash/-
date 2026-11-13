extends "res://tests/patch523_rules_cold_bake_test.gd"
## Current-main traversal frozen separately from the older whole-model oracle.
const BEFORE = preload("res://tests/fixtures/equipment_scan_legacy/projection.gd")
func _initialize() -> void:
	var data: Dictionary = fixture(10)
	var records: Array = data.items.duplicate(true)
	for index: int in 6000:
		var row: Dictionary = {"name":"scan-extra-"+str(index),"slot":"consumable"}
		match index%5:
			0: row.source_item_class_id = "bad"
			1: row.source_item_class_id = -1.0
			2: row.source_item_class_id = null
			3: row.source_item_class_id = 0.0
			4: row.source_item_class_id = 999999.0; row.source_bless_raw = 2.0
		records.append(row)
	var current = PROJECTION.new()
	var before = BEFORE.new()
	for projection: Variant in [current,before]:
		projection.source = data.reader
		projection._policy = JSON.parse_string(FileAccess.get_file_as_string(PROJECTION.POLICY_PATH))
		projection._full_native = true
		check(projection._read_source(),"read fixture")
		var handles := PackedInt32Array()
		for record: Dictionary in records: handles.append(projection._records.add(record))
		check(projection._bind_catalog(handles,handles),"bind fixture")
		check(projection._record_cache.size()<=4096,"bounded record cache")
	for field: String in ["_by_name","_by_id","_variants","_currency_keys","_host_materials","_use_conditions"]:
		same("all scan outputs "+field,current.get(field),before.get(field))
	check(current._record_cache.size()<before._record_cache.size(),"noncandidate scans avoid whole record cache")
	for index: int in records.size():
		same("all source records preserved",current._records.fetch(index),before._records.fetch(index))
	print("EQUIPMENT_CATALOG_SCAN_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"records":records.size(),"new_cache":current._record_cache.size(),"old_cache":before._record_cache.size()}))
	quit(0 if failures.is_empty() else 1)
