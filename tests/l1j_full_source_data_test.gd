extends SceneTree

const ATTRIBUTES = preload("res://addons/twilight_l1j/twilight_map_attributes.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		if failures.size() <= 20: print("L1J_FULL_SOURCE_FAIL: ", label)

func _run() -> void:
	var map_path: String = "res://data/l1j/maps/source_maps.json"
	var s32_path: String = "res://data/l1j/maps/s32_placements.json"
	if not FileAccess.file_exists(map_path) or not FileAccess.file_exists(s32_path):
		print("L1J_FULL_SOURCE_OK optional source archive absent; normal game preserved")
		quit(0)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	var maps: int = 0
	for record: Dictionary in manifest.maps:
		var size := Vector2i(int(record.dimensions[0]), int(record.dimensions[1]))
		var path: String = "res://data/l1j/maps/raw/%d.bin" % int(record.map_id)
		var source: TwilightL1JMapAttributes = ATTRIBUTES.new()
		check(source.load_a3(int(record.map_id), size), "cache load " + str(record.map_id))
		check(FileAccess.get_sha256(path) == str(record.row_major_sha256), "source cache digest " + str(record.map_id))
		check(source.attribute_at(Vector2i(-1, 0)) == -1 and source.attribute_at(size) == -1, "source bounds " + str(record.map_id))
		check(not bool(record.gameplay_collision_applied), "source data falsely marked as playable geometry")
		maps += 1
	var placements: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(s32_path))
	var segments: int = 0
	var unresolved: int = 0
	for record: Dictionary in placements.segments:
		var path: String = str(record.source_file)
		check(path.begins_with("res://data/l1j/maps/client_s32/") and not path.contains(".."), "safe S32 identity")
		var data: PackedByteArray = FileAccess.get_file_as_bytes(path)
		check(not data.is_empty() and FileAccess.get_sha256(path) == str(record.source_sha256), "S32 source digest " + path)
		for name_value: String in record.spans:
			var span: Dictionary = record.spans[name_value]
			check(int(span.offset) >= 0 and int(span.offset) + int(span.bytes) <= data.size(), "S32 source span " + path)
		check(not bool(record.gameplay_applied), "S32 placement falsely marked restored")
		if record.source_origin == null: unresolved += 1
		segments += 1
	for record: Dictionary in placements.failures:
		check(FileAccess.file_exists(str(record.source_file)), "preserved invalid S32 source")
		check(FileAccess.get_sha256(str(record.source_file)) == str(record.source_sha256), "preserved invalid S32 digest")
	check(segments == int(placements.parsed_segments), "complete parsed S32 count")
	check(maps == 1000 and segments + placements.failures.size() == 1847, "entire supplied map inventory")
	print("L1J_FULL_SOURCE_OK " if failures.is_empty() else "L1J_FULL_SOURCE_FAIL ",
		"caches=", maps, " parsed_segments=", segments, " rejected_source_segments=", placements.failures.size(), " unresolved_coordinates=", unresolved)
	quit(0 if failures.is_empty() else 1)
