extends SceneTree
## ONLY the explicit correction manifest and its dependencies, not the corpus.
var _retained: Array[ImageTexture] = []
var _results: Array[Dictionary] = []
const PLAYER: Script = preload("res://docs/remake/pr122-legendary-parallel/legendary_registered_clip_player_v01.gd")
const DIRECTIONS: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

func _initialize() -> void:
	call_deferred("_run")

func _validate(entry: Dictionary) -> Dictionary:
	var path: String = str(entry["record"])
	var errors: Array[String] = []
	var output: Dictionary = {"slot": entry["slot"], "record": path, "errors": errors}
	if FileAccess.get_sha256(path) != str(entry["record_sha256"]):
		errors.append("record SHA mismatch")
		output["status"] = "FAIL"
		return output
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var slot: Array = entry["slot"]
	if [record.get("key"), record.get("direction"), record.get("role")] != slot:
		errors.append("original actor/direction/role ID mismatch")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var matched: int = 0
	for actor: Dictionary in catalog.get("변신", []):
		if "transform:" + str(actor.get("sourceId", "")) == str(slot[0]):
			matched += 1
			if str(actor.get("grade")) != "전설" or str(actor.get("name")) != str(record.get("name")):
				errors.append("catalog identity mismatch")
	if matched != 1:
		errors.append("catalog ID not unique")
	_retained.clear()
	for source: Dictionary in record.get("source_files", []):
		var source_path: String = str(source["path"])
		if FileAccess.get_sha256(source_path) != str(source["sha256"]):
			errors.append("PNG SHA mismatch: " + source_path)
			continue
		var image: Image = Image.load_from_file(source_path)
		if image == null or image.is_empty():
			errors.append("PNG load failure")
			continue
		var texture: ImageTexture = ImageTexture.create_from_image(image)
		texture.take_over_path(source_path)
		_retained.append(texture)
	var resource_path: String = str(record["output_spriteframes"])
	if FileAccess.get_sha256(resource_path) != str(record["output_spriteframes_sha256"]):
		errors.append("SpriteFrames SHA mismatch")
	var frames: SpriteFrames = ResourceLoader.load(resource_path, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE) as SpriteFrames
	var anim: StringName = StringName(str(slot[2]) + "_" + str(DIRECTIONS.find(str(slot[1]))))
	if frames == null or not frames.has_animation(anim) or frames.get_frame_count(anim) != 6:
		errors.append("six-frame animation unavailable")
		output["status"] = "FAIL"
		return output
	var looped: bool = str(slot[2]) in ["idle", "run"]
	if frames.get_animation_loop(anim) != looped:
		errors.append("loop/once mismatch")
	var weighted: float = 0.0
	for i: int in range(6):
		weighted += frames.get_frame_duration(anim, i)
		var atlas: AtlasTexture = frames.get_frame_texture(anim, i) as AtlasTexture
		if atlas == null or atlas.atlas == null or atlas.region.size.x <= 0.0 or atlas.region.size.y <= 0.0 or atlas.region.position.x < 0.0 or atlas.region.position.y < 0.0 or atlas.region.end.x > atlas.atlas.get_width() or atlas.region.end.y > atlas.atlas.get_height():
			errors.append("invalid AtlasTexture region " + str(i))
	var player: Node2D = PLAYER.new()
	root.add_child(player)
	if not player.configure(path, str(entry.get("registration", ""))):
		errors.append("standalone player configure failed: " + str(player.last_error))
		output["status"] = "FAIL"
		player.queue_free()
		await process_frame
		return output
	var sprite: AnimatedSprite2D = player.sprite
	player.play_clip()
	var reached: Dictionary = {}
	var previous: int = 0
	var wraps: int = 0
	var seconds: float = weighted / frames.get_animation_speed(anim)
	for tick: int in range(int(ceil(seconds * 60.0 * (2.0 if looped else 1.0))) + 8):
		reached[sprite.frame] = true
		if previous > sprite.frame:
			wraps += 1
		previous = sprite.frame
		if not player.frame_anchor_in_parent().is_equal_approx(Vector2.ZERO):
			errors.append("registration origin did not remain at exact baseline position")
		await process_frame
	if reached.size() != 6:
		errors.append("six frames not reached in actual playback")
	if looped and (wraps < 1 or not sprite.is_playing()):
		errors.append("loop failed")
	if not looped:
		for tick: int in range(8):
			await process_frame
		if sprite.frame != 5 or sprite.is_playing():
			errors.append("once/final-frame hold failed")
		if entry.has("expected_terminal_source"):
			var terminal: AtlasTexture = sprite.sprite_frames.get_frame_texture(anim, 5) as AtlasTexture
			var expected_region: Array = entry["expected_terminal_region"]
			var expected := Rect2(float(expected_region[0]), float(expected_region[1]), float(expected_region[2]), float(expected_region[3]))
			if terminal == null or terminal.atlas.resource_path != str(entry["expected_terminal_source"]) or terminal.region != expected:
				errors.append("targeted final lying-corpse source binding was not held")
			output["expected_terminal_baseline_phase"] = entry.get("expected_terminal_baseline_phase", -1)
	output["frames_reached"] = reached.size()
	output["wraps"] = wraps
	output["terminal_frame"] = sprite.frame
	output["status"] = "PASS" if errors.is_empty() else "FAIL"
	output["registration"] = str(entry.get("registration_status", ""))
	output["semantic_scale_registration"] = "HOLD" if str(entry.get("registration_status", "")) == "RASTER_COORDINATE_PRESERVATION" else "REVIEWED_INPUT"
	output["quality_status"] = "HOLD"
	player.queue_free()
	await process_frame
	return output

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]):
		push_error("Supply explicit revision manifest and NEW report path")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var failures: int = 0
	for entry: Dictionary in manifest.get("revisions", []):
		var result: Dictionary = await _validate(entry)
		_results.append(result)
		if result["status"] != "PASS":
			failures += 1
	var report: Dictionary = {"scope": "Only corrected clips and explicitly listed dependent guards",
		"engine": Engine.get_version_info().get("string", ""), "records": _results,
		"failures": failures, "actual_Main_Player": "NOT_RUN", "full_CI": "NOT_RUN", "final_approved": 0}
	var handle: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	if handle == null:
		quit(1)
		return
	handle.store_string(JSON.stringify(report, "  ") + "\n")
	handle.close()
	print(JSON.stringify({"corrected_dependencies": _results.size(), "failures": failures, "engine": report["engine"]}))
	quit(0 if failures == 0 else 1)
