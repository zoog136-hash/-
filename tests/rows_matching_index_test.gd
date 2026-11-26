extends SceneTree
## rows_matching() reads the rows of the requested IDs from the relation index
## (in table order) instead of scanning the whole table; only integer keys of
## `ids` can match, as in the scan (ids.has(int(value))).
##   godot --headless --path <repo> --script res://tests/rows_matching_index_test.gd
const D = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ROWS_MATCHING_INDEX_FAIL: " + label)

func _initialize() -> void:
	# Column F of table T, rows 0..4 = [1, 5, 2, 5, 1]: relation keys 1,2,5.
	D._tables["ZzT"] = {"columns": PackedStringArray(["F"]), "data": [PackedFloat64Array([1, 5, 2, 5, 1])], "count": 5}
	D._integer_fields["ZzT:F"] = true
	D._relations["ZzT:F"] = {"keys": PackedInt64Array([1, 2, 5]), "starts": PackedInt32Array([0, 2, 3, 5]), "rows": PackedInt32Array([0, 4, 2, 1, 3])}
	var positions: Variant = D._indexed_positions("ZzT", "F", {5: true, 1: true, 9: true, 2.0: true})
	check(positions is PackedInt32Array and positions == PackedInt32Array([0, 1, 3, 4]), "rows of the integer keys, in table order: " + str(positions))
	check(D._indexed_positions("ZzT", "F", {9: true}) == PackedInt32Array(), "an absent ID matches nothing")
	D._integer_fields["ZzT:G"] = false
	check(D._indexed_positions("ZzT", "G", {1: true}) == null, "a column that is not all-integer keeps the scan")
	D._tables.erase("ZzT"); D._integer_fields.erase("ZzT:F"); D._integer_fields.erase("ZzT:G"); D._relations.erase("ZzT:F")
	# integer_field(): a validated relation index (built only from all-integer
	# columns) answers without checking every row again; no index -> the scan.
	var small: Dictionary = {"count": 2}
	check(D._integer_values("ZzI", "F", small, PackedFloat64Array([1, 5])), "an all-integer column without an index is scanned and is integer")
	check(not D._integer_values("ZzI", "G", small, PackedFloat64Array([1, 2.5])), "a fractional column without an index is not integer")
	D._relations["ZzI:H"] = {"keys": PackedInt64Array([3]), "starts": PackedInt32Array([0, 2]), "rows": PackedInt32Array([0, 1])}
	check(D._integer_values("ZzI", "H", small, PackedFloat64Array([3, 4.5])), "a column with a validated relation index is integer without the row scan")
	D._relations["ZzI:G"] = {"ordered_ids": PackedFloat64Array([1, 2.5])}
	check(not D._integer_values("ZzI", "G", small, PackedFloat64Array([1, 2.5])), "the Bonus.ID ordered-ids form does not stand in for the scan")
	D._relations.erase("ZzI:H"); D._relations.erase("ZzI:G")
	var source: String = FileAccess.get_file_as_string("res://scripts/resources/current523_definition_rows.gd")
	check(source.contains("var indices: Variant = _indexed_positions(table, field, ids)"), "rows_matching uses the relation index")
	var tj: String = FileAccess.get_file_as_string("res://scripts/tj/source523.gd")
	check(tj.contains("DEFINITIONS.approximate_test_items = false") and tj.contains("if held and table in LARGE_TABLES"), "TJ reads its large tables through the held definitions with raw rows")
	print("ROWS_MATCHING_INDEX_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
