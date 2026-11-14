extends SceneTree
## The gameplay heartbeat names what holds memory.
##   godot --headless --path <repo> --script res://tests/frame_hitch_probe_alive_test.gd
const PROBE = preload("res://scripts/boot/frame_hitch_probe.gd")
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FRAME_HITCH_PROBE_ALIVE_FAIL: " + label)

func _initialize() -> void:
	var fields: Dictionary = PROBE.alive_fields("aden_world")
	check(fields.get("map") == "aden_world", "the heartbeat names the map")
	for key: String in ["sp2_parsed_mb", "sp2_parsed_n", "sp2_texture_mb", "sp2_texture_n", "nodes", "resources", "tables"]:
		check(fields.has(key) and int(fields[key]) >= 0, "the heartbeat has " + key)
	var line: String = ""
	for key: Variant in fields: line += " %s=%s" % [key, fields[key]]
	var parsed: Dictionary = BOOT_LOG.parse_line("ev=alive t=1" + line)
	check(parsed.get("sp2_texture_mb") == str(fields.sp2_texture_mb), "heartbeat fields survive the log line format")
	check(PROBE.world_fields(null).is_empty(), "no world, no world fields")
	var stub := Node.new()
	check(PROBE.world_fields(stub).is_empty(), "a world without a field or renderer adds nothing")
	stub.free()
	check(fields.has("objects"), "the heartbeat counts objects")
	print("FRAME_HITCH_PROBE_ALIVE_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "fields":fields}))
	quit(0 if failures.is_empty() else 1)
