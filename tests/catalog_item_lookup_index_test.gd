extends SceneTree

# The indexed lookups must return exactly what the linear scans returned:
# same record object for catalog/item_db hits, same copy for instance fallbacks,
# {} for removed or unknown names, and correct results after in-place edits.
const LOOKUP = preload("res://scripts/catalog_item_lookup.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func _data_dir() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--data-dir="): return argument.trim_prefix("--data-dir=")
	return "res://data/"

func _linear_first(source: Array, item_name: String) -> Dictionary:
	for value: Variant in source:
		if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name: return value
	return {}

func _same_result(expected: Dictionary, actual: Dictionary, label: String) -> void:
	if expected.is_empty() != actual.is_empty() or (not expected.is_empty() and expected != actual):
		failures.append("%s: expected %s got %s" % [label, str(expected.get("name", "{}")), str(actual.get("name", "{}"))])

func run() -> void:
	var directory: String = _data_dir()
	var catalog: Array = (JSON.parse_string(FileAccess.get_file_as_string(directory + "catalog_v19.json")) as Dictionary).get("아이템", [])
	var item_db: Array = (JSON.parse_string(FileAccess.get_file_as_string(directory + "game_db_v17.json")) as Dictionary).get("아이템", [])
	if catalog.size() < 1000 or item_db.is_empty(): failures.append("catalog data not loaded from " + directory)
	var instances: Dictionary = {
		"9001": {"name":"TEST 고유 장비", "record":{"name":"TEST 고유 장비", "grade":"희귀", "slot":"weapon"}},
		"9002": {"name":str(catalog[0].get("name", "")), "record":{"name":"shadow", "grade":"전설"}}}
	var names: Array[String] = ["", "상태이상 해제 물약", "TEST 고유 장비", "없는 아이템 이름", "TEST 고유 장비 (각인)"]
	for source: Array in [catalog, item_db]:
		for value: Variant in source:
			if value is Dictionary: names.append(str((value as Dictionary).get("name", "")))
	var checked: int = 0
	for item_name: String in names:
		var expected: Dictionary = LOOKUP.find_many([catalog, item_db], instances, [item_name]).get(item_name, {})
		var actual: Dictionary = LOOKUP.find_one([catalog, item_db], instances, item_name)
		_same_result(expected, actual, "find_one " + item_name)
		var expected_first: Dictionary = _linear_first(catalog, item_name)
		var actual_first: Dictionary = LOOKUP.first_by_name(catalog, item_name)
		if not is_same(expected_first, actual_first) and not (expected_first.is_empty() and actual_first.is_empty()):
			failures.append("first_by_name returned a different record for " + item_name)
		checked += 1
	# Catalog hits must be the live record object (callers rely on reference identity).
	var sample_name: String = str(catalog[catalog.size() / 2].get("name", ""))
	if not is_same(LOOKUP.find_one([catalog, item_db], instances, sample_name), _linear_first(catalog, sample_name)):
		failures.append("catalog hit is not the live record")
	# In-place replacement with the same size (what _merge_local_consumables_into_catalog does).
	var position: int = catalog.size() / 3
	var replaced_name: String = str(catalog[position].get("name", ""))
	var replacement: Dictionary = (catalog[position] as Dictionary).duplicate(true)
	replacement["grade"] = "TEST_REPLACED"
	var first_position: int = -1
	for index: int in range(catalog.size()):
		if str(catalog[index].get("name", "")) == replaced_name: first_position = index; break
	catalog[first_position] = replacement
	if not is_same(LOOKUP.first_by_name(catalog, replaced_name), replacement): failures.append("in-place replacement returned a stale record")
	# In-place rename to a brand-new name (same size): the miss fallback must find it.
	var renamed: Dictionary = (catalog[position + 7] as Dictionary).duplicate(true)
	renamed["name"] = "TEST 새 이름"
	catalog[position + 7] = renamed
	if not is_same(LOOKUP.first_by_name(catalog, "TEST 새 이름"), renamed): failures.append("in-place rename was not found")
	_same_result(_linear_first(catalog, str(catalog[position + 8].get("name", ""))), LOOKUP.first_by_name(catalog, str(catalog[position + 8].get("name", ""))), "neighbour after rename")
	# Append and remove change the size; positions shift after remove_at(0).
	var appended: Dictionary = {"name":"TEST 추가", "grade":"일반"}
	catalog.append(appended)
	if not is_same(LOOKUP.first_by_name(catalog, "TEST 추가"), appended): failures.append("appended record not found")
	catalog.remove_at(0)
	for index: int in range(0, catalog.size(), 97):
		var probe: String = str(catalog[index].get("name", ""))
		if not is_same(LOOKUP.first_by_name(catalog, probe), _linear_first(catalog, probe)): failures.append("shifted lookup wrong for " + probe)
	# A brand-new array (catalog reload) must not reuse the old index.
	var reloaded: Array = [{"name":replaced_name, "grade":"TEST_RELOADED"}]
	if str(LOOKUP.first_by_name(reloaded, replaced_name).get("grade", "")) != "TEST_RELOADED": failures.append("reloaded array used a stale index")
	# Timing on the same data (informational; the equivalence checks above decide pass/fail).
	var probes: Array[String] = []
	for index: int in range(150): probes.append(str(catalog[(index * 37 + 11) % catalog.size()].get("name", "")))
	var started: int = Time.get_ticks_usec()
	for probe: String in probes: LOOKUP.find_many([catalog, item_db], instances, [probe])
	var linear_us: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for probe: String in probes: LOOKUP.find_one([catalog, item_db], instances, probe)
	var indexed_us: int = Time.get_ticks_usec() - started
	if indexed_us >= linear_us: failures.append("indexed lookups were not faster (%d us vs %d us)" % [indexed_us, linear_us])
	print("CATALOG_LOOKUP_INDEX_RESULT ", JSON.stringify({"failures":failures, "names_checked":checked,
		"linear_150_us":linear_us, "indexed_150_us":indexed_us, "index_builds":LOOKUP.index_builds}))
	quit(0 if failures.is_empty() else 1)
