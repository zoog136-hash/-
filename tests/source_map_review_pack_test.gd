extends SceneTree
const PACK = preload("res://scripts/maps/source_map_review_pack.gd")
var checks: int = 0
var failed: bool = false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failed = true; printerr("MAP84 FAIL: ",message)

func _initialize() -> void:
	var path: String = OS.get_environment("TWILIGHT_MAP84_REVIEW_PACK")
	var pack = PACK.new()
	check(pack.open_pack(path), "pack open: "+pack.problem)
	if pack.index.is_empty(): quit(1); return
	check(pack.gameplay_entries().is_empty(), "unverified maps cannot enter game")
	var selected: int = 0
	var variants: int = 0
	var unselected: int = 0
	for mid: String in pack.index.maps:
		var row: Dictionary = pack.load_map(mid)
		check(not row.is_empty(), "full manifest and every actual WebP hash: "+mid)
		if row.is_empty(): continue
		check(not row.playable and row.monster_spawns.is_empty(), "play/spawn gate "+mid)
		if row.source_map_id == null:
			variants += 1
			check(row.collision == null and row.routes.is_empty() and row.doors.is_empty(), "variant cannot inherit base geometry "+mid)
		elif row.collision != null:
			selected += 1
			check(row.collision.version == "360" and not row.collision.playable, "selected collision stays raw "+mid)
			check(FileAccess.get_sha256(path+"/"+str(row.collision.file)) == row.collision.sha256, "selected grid hash "+mid)
		else: unselected += 1
		for chunk: Dictionary in row.chunks:
			var b: Array = chunk.world_bounds
			for p: Vector2 in [Vector2(b[0],b[1]),Vector2(b[2],b[3]),Vector2(b[0]+31,b[1]+17)]:
				check(PACK.canvas_to_source(row,PACK.source_to_canvas(row,p)).distance_to(p) < 0.001, "projection roundtrip "+mid)
		check(pack.save_migration_status(mid) != "approved", "no implicit save migration "+mid)
	check(selected == 31 and variants == 5 and unselected == 48, "31/48/5 exact partition")
	for id: String in PACK.PROTECTED:
		check(not pack.index.maps.has(id) and pack.save_migration_status(id) == "unchanged_protected", "protected "+id)
	check(pack.save_migration_status("domination_summit").begins_with("blocked"), "111 to 200 may not reuse save pixels")
	check(pack.save_migration_status("yahee_temple") == "unchanged_existing", "no guessed temple alias")
	check(pack.load_map("source_639").is_empty(), "deleted source not restored")
	# Real metadata copies in an isolated test directory: reject corruption before
	# trying to load textures, and never touch the immutable input pack or saves.
	var tamper: String = "user://map84-tamper-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tamper+"/maps")
	for name: String in ["index.json","runtime_safety.json","maps/domination_summit.json"]:
		check(DirAccess.copy_absolute(path+"/"+name,tamper+"/"+name) == OK,"copy real test metadata")
	var bad = PACK.new()
	check(bad.open_pack(tamper),"authenticated index copy")
	check(bad.load_map("domination_summit").is_empty() and bad.problem.contains("chunk missing"),"missing fullres must not fall back to overview")
	var handle := FileAccess.open(tamper+"/maps/domination_summit.json",FileAccess.WRITE)
	handle.store_string("{}"); handle.close()
	check(bad.load_map("domination_summit").is_empty() and bad.problem == "Map manifest changed","changed manifest rejected")
	handle = FileAccess.open(tamper+"/index.json",FileAccess.WRITE)
	handle.store_string("{}"); handle.close()
	check(not bad.open_pack(tamper) and bad.index.is_empty(),"changed index rejected and stale state cleared")
	for name: String in ["index.json","runtime_safety.json","maps/domination_summit.json"]: DirAccess.remove_absolute(tamper+"/"+name)
	DirAccess.remove_absolute(tamper+"/maps"); DirAccess.remove_absolute(tamper)
	check(not pack.open_pack(path+"-missing") and pack.index.is_empty(), "missing pack clears stale registry")
	print("SOURCE_MAP_REVIEW_PACK_", "FAILED" if failed else "OK", " checks=",checks," maps=84 playable=0")
	quit(1 if failed else 0)
