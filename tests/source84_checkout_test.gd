extends SceneTree
## Cold checkout proof: no external map root and no user-installed map pack.
const RUN = preload("res://scripts/maps/source_map_runtime.gd")
const LOCATION = preload("res://scripts/maps/source_map_pack_location.gd")
const NPC = preload("res://scripts/npc/source_npc_catalog.gd")
const ACTOR = preload("res://scripts/npc/source_npc_actor.gd")
var errors: int = 0
var checks: int = 0

class Probe extends Node2D:
	var field_map: PlayableField
	var player: Node2D

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors += 1; printerr("SOURCE84_CHECKOUT_FAIL ", label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	check(OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty(), "no external map override")
	for flag: String in ["TWILIGHT_REMAKE_PACK", "TWILIGHT_NATIVE_PNG_PACK", "TWILIGHT_ADEN_FAITH_PNG_PACK", "TWILIGHT_DOMINATION_PNG_PACK", "TWILIGHT_OMAN_PNG_PACK"]:
		check(OS.get_environment(flag).is_empty(), "no external legacy pack override " + flag)
	check(not FileAccess.file_exists(LOCATION.USER + "/index.json"), "no user-installed map pack")
	check(RUN.root_path() == LOCATION.BUNDLED, "tracked bundled root selected")
	if errors: quit(1); return
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/source84_delivery_manifest.json"))
	var decoded: int = 0
	var total: int = 0
	for relative: String in spec.files:
		var path: String = RUN.root_path() + "/" + relative
		check(FileAccess.file_exists(path) and FileAccess.get_sha256(path) == spec.files[relative].sha256, "SHA " + relative)
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null: quit(1); return
		total += file.get_length(); file.close()
		if relative.ends_with(".webp"):
			var bitmap := Image.new()
			check(bitmap.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and not bitmap.is_empty(), "raw WebP decode " + relative)
			decoded += 1
			if decoded % 256 == 0: print("SOURCE84_CHECKOUT_DECODED ", decoded)
	check(total == int(spec.total_bytes) and spec.files.size() == 2140 and decoded == 1920, "complete exact pack")
	var npc_count: int = 0
	for mid: String in RUN.policy():
		var field: RemakePlayableField = RUN.load_field(mid)
		check(field != null, "field path " + mid)
		if field == null: continue
		var start := Vector2(field.data.spawn_position[0], field.data.spawn_position[1])
		check(field.point_clear(start, 4), "entry " + mid)
		for portal: Dictionary in field.data.get("portal", []):
			if str(portal.get("id", "")).ends_with("_verified_return"):
				var p := Vector2(portal.position[0], portal.position[1])
				check(portal.target_map == "aden_world" and field.point_clear(p, 4) and not field.path(start, p).is_empty(), "verified return portal " + mid)
		for spawn: Dictionary in field.data.get("npc_spawn", []):
			if not spawn.has("source_catalog_id"): continue
			var actor: Node2D = ACTOR.new()
			check(actor.configure(spawn), "tracked NPC art and feet " + str(spawn.source_catalog_id))
			actor.free()
			var probe := Probe.new(); probe.field_map = field; probe.player = Node2D.new()
			root.add_child(probe); probe.add_child(probe.player)
			probe.player.position = Vector2(spawn.position[0], spawn.position[1])
			check(field.point_clear(probe.player.position, 6) and NPC.nearby(probe, str(spawn.source_catalog_id)), "real field NPC path/proximity " + str(spawn.source_catalog_id))
			probe.free(); npc_count += 1
		field.close()
	check(npc_count == 6, "all six actual map NPC bindings")
	print("SOURCE84_CHECKOUT_RESULT checks=", checks, " errors=", errors, " files=2140 decoded=", decoded, " fields=", RUN.policy().size(), " npc=", npc_count)
	quit(0 if errors == 0 else 1)
