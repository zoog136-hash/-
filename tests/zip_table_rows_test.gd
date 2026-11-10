extends SceneTree
## zip_table_rows.gd reads a table window by window and must keep exactly the
## rows (same values, same order) a whole-document JSON parse gives, report
## whole-table duplicates/missing keys, and fall back to a whole parse for any
## other layout.
const ROWS = preload("res://scripts/resources/zip_table_rows.gd")
const PATH := "user://zip_table_rows_fixture.zip"
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 20: failures.append(label)

## The pack's layout: 2-space "rows", 4-space row objects, 6-space fields.
func _pretty(rows: Array, nl: String, bom: bool) -> PackedByteArray:
	var parts: PackedStringArray = []
	for row: Dictionary in rows:
		var fields: PackedStringArray = []
		for key: String in row: fields.append("      " + JSON.stringify(key) + ": " + JSON.stringify(row[key]))
		parts.append("    {" + nl + ("," + nl).join(fields) + nl + "    }")
	var text: String = "{" + nl + "  \"rows\": [" + nl + ("," + nl).join(parts) + nl + "  ]" + nl + "}"
	var bytes: PackedByteArray = text.to_utf8_buffer()
	if bom: bytes = PackedByteArray([0xef, 0xbb, 0xbf]) + bytes
	return bytes

func _rows(count: int, duplicate_at: int = -1, missing_at: int = -1) -> Array:
	var rows: Array = []
	for index: int in count:
		var row: Dictionary = {"ID": index * 3 + 1, "Name": "행 %d · 설명 \"따옴표\" 와 줄\n바꿈" % index, "Value": index * 0.5, "Flag": index % 2 == 0, "BonusID": 1000 + index % 97}
		if index == duplicate_at: row.ID = 1
		if index == missing_at: row.erase("ID")
		rows.append(row)
	return rows

func _write(entries: Dictionary) -> ZIPReader:
	var packer := ZIPPacker.new()
	packer.open(PATH)
	for name: String in entries:
		packer.start_file("content/" + name + ".json")
		packer.write_file(entries[name])
		packer.close_file()
	packer.close()
	var reader := ZIPReader.new()
	reader.open(PATH)
	return reader

func _whole(archive: ZIPReader, table: String) -> Array:
	return JSON.parse_string(archive.read_file("content/" + table + ".json").get_string_from_utf8().trim_prefix("﻿")).rows

func _initialize() -> void:
	# About 3 MB: several 1 MB windows.
	var big: Array = _rows(16000)
	var archive: ZIPReader = _write({"Lf": _pretty(big, "\n", false), "Crlf": _pretty(big, "\r\n", true),
		"Compact": JSON.stringify({"rows": big}).to_utf8_buffer(), "Dup": _pretty(_rows(3000, 2500), "\r\n", false),
		"Missing": _pretty(_rows(3000, -1, 1200), "\n", false), "Empty": "{\n  \"rows\": []\n}".to_utf8_buffer()})
	var wanted: Dictionary = {}
	for index: int in range(0, 16000, 37): wanted[index * 3 + 1] = true
	wanted[999999] = true
	for table: String in ["Lf", "Crlf", "Compact"]:
		var whole: Array = _whole(archive, table)
		check(whole.size() == 16000, table + ": the fixture parses whole")
		var expected: Array = whole.filter(func(row: Dictionary) -> bool: return wanted.has(int(row.ID)))
		var scanned: Dictionary = ROWS.scan(archive, table, "ID", wanted, "BonusID")
		check(scanned.ok and scanned.rows == expected, table + ": the kept rows equal the whole-parse rows")
		check(int(scanned.count) == whole.size() and not scanned.duplicate and not scanned.missing, table + ": whole-table counts")
		var bonus_ids := PackedInt64Array()
		for row: Dictionary in whole: bonus_ids.append(int(row.BonusID))
		check(scanned.values == bonus_ids, table + ": collected column equals every row's value")
		check(ROWS.scan(archive, table, "ID", {}, "", true).rows == whole, table + ": keep_all equals the whole parse")
		check(ROWS.scan(archive, table, "ID", {}).rows.is_empty(), table + ": nothing wanted keeps nothing")
	check(ROWS.scan(archive, "Dup").duplicate, "a repeated ID anywhere is reported")
	check(ROWS.scan(archive, "Missing").missing, "a row without the key is reported")
	var empty: Dictionary = ROWS.scan(archive, "Empty", "ID", {}, "", true)
	check(empty.ok and int(empty.count) == 0 and empty.rows.is_empty(), "an empty table")
	check(not ROWS.scan(archive, "Absent").ok, "an absent table is not ok")
	archive.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("ZIP_TABLE_ROWS_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
