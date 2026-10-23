extends SceneTree
## Minimal real SpriteFrames six-pose playback; source quality approval stays HOLD.
## godot --headless --fixed-fps 60 --path ROOT --script res://docs/remake/pr122-legendary-parallel/validate_generated_drafts.gd -- --report NEW_REPORT_PATH RECORD_JSON...

var failures: int = 0
var retained: Array[ImageTexture] = []
var results: Array[Dictionary] = []
const DIRECTIONS: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String, errors: Array[String]) -> bool:
	if not ok:
		errors.append(label)
	return ok

func _validate(record_path: String) -> Dictionary:
	var errors: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(record_path))
	if not _check(parsed is Dictionary, "record JSON unavailable", errors):
		return {"record": record_path, "status": "FAIL", "errors": errors}
	var data: Dictionary = parsed
	var role: String = str(data.get("role", ""))
	var direction: String = str(data.get("direction", ""))
	var direction_index: int = DIRECTIONS.find(direction)
	if not _check(direction_index >= 0 and role in ["idle", "run", "attack", "hit", "death"], "role/direction invalid", errors):
		return {"record": record_path, "status": "FAIL", "errors": errors}
	_check(role != "death" or direction == "S", "new death must be S", errors)
	var key: String = str(data.get("key", ""))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var matches: int = 0
	for actor: Dictionary in catalog.get("변신", []):
		if "transform:" + str(actor.get("sourceId", "")) == key:
			matches += 1
			_check(str(actor.get("grade", "")) == "전설" and str(actor.get("name", "")) == str(data.get("name", "")), "catalog identity mismatch", errors)
	_check(matches == 1, "catalog ID must match once", errors)
	var source_path: String = "res://" + str(data.get("source", ""))
	if not _check(FileAccess.file_exists(source_path) and FileAccess.get_sha256(source_path) == str(data.get("source_sha256", "")), "raw PNG SHA mismatch", errors):
		return {"key": key, "record": record_path, "status": "FAIL", "errors": errors}
	var image: Image = Image.load_from_file(source_path)
	if not _check(image != null and not image.is_empty(), "PNG image load failed", errors):
		return {"key": key, "record": record_path, "status": "FAIL", "errors": errors}
	var source_grid: Array = data.get("source_grid", [3, 2])
	_check(source_grid.size() == 2 and int(source_grid[0]) == 3 and int(source_grid[1]) in [1, 2], "source grid invalid", errors)
	_check(image.get_width() >= int(source_grid[0]) and image.get_height() >= int(source_grid[1]), "source grid exceeds PNG dimensions", errors)
	var source_files: Array = data.get("source_files", [{"path": source_path, "sha256": data.get("source_sha256", "")}])
	for source_info: Dictionary in source_files:
		var texture_path: String = str(source_info.get("path", ""))
		if not _check(FileAccess.file_exists(texture_path) and FileAccess.get_sha256(texture_path) == str(source_info.get("sha256", "")), "mixed source PNG SHA mismatch", errors):
			return {"key": key, "record": record_path, "status": "FAIL", "errors": errors}
		var texture_image: Image = Image.load_from_file(texture_path)
		if not _check(texture_image != null and not texture_image.is_empty(), "mixed PNG image load failed", errors):
			return {"key": key, "record": record_path, "status": "FAIL", "errors": errors}
		var texture: ImageTexture = ImageTexture.create_from_image(texture_image)
		retained.append(texture)
		texture.take_over_path(texture_path)
	var resource_path: String = str(data.get("output_spriteframes", ""))
	if not _check(FileAccess.get_sha256(resource_path) == str(data.get("output_spriteframes_sha256", "")), "SpriteFrames SHA mismatch", errors):
		return {"key": key, "record": record_path, "status": "FAIL", "errors": errors}
	var frames: SpriteFrames = load(resource_path) as SpriteFrames
	var anim: StringName = StringName(role + "_" + str(direction_index))
	var looped: bool = role in ["idle", "run"]
	if not _check(frames != null and frames.get_animation_names().size() == 1 and frames.has_animation(anim), "one selected SpriteFrames track required", errors):
		return {"key": key, "record": record_path, "status": "FAIL", "errors": errors}
	if not _check(frames.get_frame_count(anim) == 6 and frames.get_animation_loop(anim) == looped and frames.get_animation_speed(anim) > 0.0, "six-frame count/speed/loop contract", errors):
		return {"key": key, "record": record_path, "status": "FAIL", "errors": errors}
	for phase: int in range(6):
		var atlas: AtlasTexture = frames.get_frame_texture(anim, phase) as AtlasTexture
		_check(atlas != null and atlas.atlas != null and atlas.get_width() > 0 and atlas.get_height() > 0, "AtlasTexture extraction failed at " + str(phase), errors)
		if atlas != null and atlas.atlas != null:
			var selected: Rect2 = atlas.region
			var extent: Vector2 = atlas.atlas.get_size()
			_check(selected.position.x >= 0.0 and selected.position.y >= 0.0 and selected.size.x > 0.0 and selected.size.y > 0.0 and selected.end.x <= extent.x and selected.end.y <= extent.y, "AtlasTexture region leaves original PNG at " + str(phase), errors)
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	root.add_child(sprite)
	sprite.play(anim)
	var reached: Dictionary = {}
	var previous: int = 0
	var wraps: int = 0
	var seconds: float = 6.0 / frames.get_animation_speed(anim)
	for tick: int in range(int(ceil(seconds * 60.0 * (2.0 if looped else 1.0))) + 8):
		reached[sprite.frame] = true
		if previous > sprite.frame:
			wraps += 1
		previous = sprite.frame
		await process_frame
	_check(reached.size() == 6, "actual playback did not reach all six frames", errors)
	if looped:
		_check(wraps >= 1 and sprite.is_playing(), "loop did not wrap while playing", errors)
	else:
		_check(sprite.frame == 5 and not sprite.is_playing(), "once animation did not stop at final frame", errors)
		for tick: int in range(5):
			await process_frame
		_check(sprite.frame == 5 and not sprite.is_playing(), "terminal frame was not held", errors)
	var terminal_frame: int = sprite.frame
	sprite.queue_free()
	return {"key": key, "record": record_path, "direction": direction, "role": role,
		"status": "PASS" if errors.is_empty() else "FAIL", "errors": errors,
		"new_poses": int(data.get("new_poses", 6)), "reused_poses": int(data.get("reused_poses", 0)),
		"frames_reached": reached.size(), "wraps": wraps, "loop": looped,
		"terminal_frame": terminal_frame, "raw_png_sha256": FileAccess.get_sha256(source_path),
		"SpriteFrames_load_and_real_playback": "PASS" if errors.is_empty() else "FAIL",
		"source_visual_status": "HOLD_NOT_REVIEWED", "actual_Main_Player": "NOT_RUN",
		"required_Godot_4_7_2_full_QA": "NOT_RUN", "actor_approvals_added": 0}

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var records: Array[String] = []
	var report_path: String = ""
	var offset: int = 0
	while offset < arguments.size():
		if arguments[offset] == "--report":
			offset += 1
			if offset >= arguments.size():
				push_error("--report requires a new output path")
				quit(1)
				return
			report_path = arguments[offset]
		else:
			records.append(arguments[offset])
		offset += 1
	if records.is_empty() or (not report_path.is_empty() and FileAccess.file_exists(report_path)):
		push_error("Pass record paths and a report path that does not exist")
		quit(1)
		return
	for path: String in records:
		var result: Dictionary = await _validate(path)
		results.append(result)
		if result.get("status", "FAIL") != "PASS":
			failures += 1
		print("LEGENDARY_DRAFT_RESOURCE " + str(result.get("key", "UNKNOWN")) + " status=" + str(result.get("status")) + " final_approval=HOLD")
	var version: String = str(Engine.get_version_info().get("string", "unknown"))
	var report: Dictionary = {"schema": "pr122-legendary-minimal-Godot-validation-v1", "engine_version": version,
		"required_engine": "4.7.2", "required_Godot_4_7_2_full_QA": "NOT_RUN",
		"validation_scope": "six-pose SpriteFrames resource playback only; full game/Main and source quality not run",
		"records": results, "failures": failures, "actor_approvals_added": 0}
	if not report_path.is_empty():
		var output: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		if output == null:
			push_error("Cannot write requested validation report")
			quit(1)
			return
		output.store_string(JSON.stringify(report, "  ") + "\n")
		output.close()
	print("PR122_LEGENDARY_DRAFT_RESULT failures=" + str(failures) + " engine=" + version + " required_4_7_2_full_QA=NOT_RUN")
	quit(0 if failures == 0 else 1)
