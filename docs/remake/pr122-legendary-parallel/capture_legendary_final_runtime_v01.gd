extends SceneTree
## One final real-render integration pass. No source PNG edits or quality approval.
const LIBRARY: Script = preload("res://docs/remake/pr122-legendary-parallel/legendary_revision_library_v01.gd")
const STAGING: String = "res://data/pr122_legendary_parallel_staging.json"
const DIRECTIONS: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const ROLES: Array[String] = ["idle", "run", "attack", "hit"]
var _library: RefCounted
var _stage: Node2D
var _out: String = ""
var _commit: String = ""
var _rows: Array = []
var _manifest: String = ""
var _errors: Array[String] = []
var _started: String = ""
var _staging_sha: String = ""
var _manifest_sha: String = ""
var _selection_path: String = ""
var _expected_count: int = 1320
var _parallel_clips: int = 8

func _initialize() -> void:
	Engine.max_fps = 60
	_commit = OS.get_environment("LEGENDARY_FINAL_COMMIT")
	_out = OS.get_environment("LEGENDARY_FINAL_OUTPUT")
	_started = Time.get_datetime_string_from_system(true)
	call_deferred("_run")

func _write_report(done: bool) -> void:
	var passed: int = 0
	var blocked: int = 0
	var failed: int = 0
	for row: Dictionary in _rows:
		if row["status"] == "PASS":
			passed += 1
		elif row["status"] == "EXPECTED_BLOCKED":
			blocked += 1
		else:
			failed += 1
	var report: Dictionary = {"schema": "legendary-final-render-integration-v01", "complete": done,
		"commit": _commit, "started_UTC": _started, "updated_UTC": Time.get_datetime_string_from_system(true),
		"staging_sha256": _staging_sha, "manifest": _manifest,
		"manifest_sha256": _manifest_sha, "targeted_recovery_selection": _selection_path,
		"parallel_clips": _parallel_clips, "GPU_warmup_frames": 9,
		"engine": Engine.get_version_info(), "display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"real_render": DisplayServer.get_name() != "headless", "expected_configurations": _expected_count,
		"PASS": passed, "EXPECTED_BLOCKED": blocked, "FAIL": failed, "errors": _errors,
		"source_PNG_mutations": 0, "new_poses_generated": 0, "final_approvals_added": 0, "rows": _rows}
	var f: FileAccess = FileAccess.open(_out.path_join("final-render-integration-v01.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print(JSON.stringify({"checked": _rows.size(), "PASS": passed, "BLOCKED": blocked, "FAIL": failed, "complete": done}))

func _setup_window() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_stage = Node2D.new()
	root.add_child(_stage)
	for index: int in range(8):
		var x: int = (index % 4) * 320
		var y: int = (index / 4) * 360
		var tile := ColorRect.new()
		tile.position = Vector2(x, y)
		tile.size = Vector2(320, 360)
		tile.color = Color(0.15, 0.17, 0.20) if index % 2 == 0 else Color(0.19, 0.21, 0.24)
		_stage.add_child(tile)
		var line := Line2D.new()
		line.add_point(Vector2(x + 12, y + 280))
		line.add_point(Vector2(x + 308, y + 280))
		line.default_color = Color(0.4, 0.5, 0.55)
		line.width = 1.0
		_stage.add_child(line)

func _batch(slots: Array) -> void:
	var live: Array = []
	for index: int in range(slots.size()):
		var slot: Array = slots[index]
		var player: Node2D = _library.instantiate_clip(str(slot[0]), str(slot[1]), str(slot[2]))
		if player == null:
			var expected: bool = slot == ["transform:274", "NE", "attack"] and str(_library.last_error).begins_with("Missing slot:")
			_rows.append({"slot": slot, "status": "EXPECTED_BLOCKED" if expected else "FAIL", "errors": [str(_library.last_error)]})
			continue
		var tile_origin := Vector2((index % 4) * 320, (index / 4) * 360)
		var semantic: bool = player.get_origin_policy() == "REVIEWED_SEMANTIC_ORIGIN"
		var origin: Vector2 = tile_origin + Vector2(160, 280 if semantic else 180)
		_stage.add_child(player)
		player.position = origin
		var sprite: AnimatedSprite2D = player.sprite
		var duration: float = 0.0
		for frame_index: int in range(6):
			duration += sprite.sprite_frames.get_frame_duration(sprite.animation, frame_index) / sprite.sprite_frames.get_animation_speed(sprite.animation)
		var phase_images: Array = [null, null, null, null, null, null]
		live.append({"slot": slot, "player": player, "tile": Rect2i(Vector2i(tile_origin), Vector2i(320, 360)),
			"origin": origin, "seen": {}, "images": phase_images, "errors": [], "duration": duration,
			"previous": -1, "wrapped": false, "finished": false, "finished_at": 0.0,
			"frame_transforms": {}, "last_frame_held": false})
	# Upload/render every selected texture while paused, then let the engine's
	# initial/PNG-loading delta settle. Startup or readback cost must not consume
	# the first attack/hit poses before their first measured render.
	for warm_phase: int in range(6):
		for state: Dictionary in live:
			state["player"].sprite.frame = warm_phase
		await process_frame
		await RenderingServer.frame_post_draw
	for state: Dictionary in live:
		state["player"].sprite.frame = 0
	for warm_tick: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var start_us: int = Time.get_ticks_usec()
	for state: Dictionary in live:
		state["player"].sprite.animation_looped.connect(func() -> void: state["wrapped"] = true)
		state["player"].play_clip()
	var batch_done: bool = false
	while not batch_done:
		await process_frame
		await RenderingServer.frame_post_draw
		var elapsed: float = float(Time.get_ticks_usec() - start_us) / 1000000.0
		var needs_image: bool = false
		for state: Dictionary in live:
			var frame_index: int = state["player"].sprite.frame
			if state["images"][frame_index] == null:
				needs_image = true
		var rendered: Image = root.get_texture().get_image() if needs_image else null
		batch_done = true
		for state: Dictionary in live:
			var player: Node2D = state["player"]
			var sprite: AnimatedSprite2D = player.sprite
			var phase: int = sprite.frame
			if int(state["previous"]) == 5 and phase == 0:
				state["wrapped"] = true
			state["previous"] = phase
			state["seen"][phase] = true
			if state["images"][phase] == null and rendered != null:
				state["images"][phase] = rendered.get_region(state["tile"])
				var anchor: Vector2 = player.frame_anchor_in_parent()
				state["frame_transforms"][str(phase)] = {"scale": [sprite.scale.x, sprite.scale.y], "position": [sprite.position.x, sprite.position.y], "offset": [sprite.offset.x, sprite.offset.y], "anchor": [anchor.x, anchor.y] if anchor.is_finite() else []}
				if not player._registration.is_empty() and not anchor.is_equal_approx(Vector2.ZERO):
					state["errors"].append("Registered origin changed at phase " + str(phase))
			if player.position != state["origin"] or player.scale != Vector2.ONE:
				state["errors"].append("Caller transform changed")
			if not str(player.last_error).is_empty() and not str(player.last_error) in state["errors"]:
				state["errors"].append(str(player.last_error))
			var role: String = str(state["slot"][2])
			var looping: bool = role in ["idle", "run"]
			var finished: bool = bool(state["wrapped"]) if looping else (not sprite.is_playing() and phase == 5)
			if role == "death":
				finished = finished and player.is_terminal_held()
			if finished and not state["finished"]:
				state["finished"] = true
				state["finished_at"] = elapsed
			var settled: bool = state["finished"] and elapsed - float(state["finished_at"]) >= 0.15
			if not looping and settled:
				state["last_frame_held"] = phase == 5 and not sprite.is_playing()
			if not settled and elapsed <= float(state["duration"]) * 3.0 + 5.0:
				batch_done = false
			elif not settled:
				state["errors"].append("Playback timeout")
	for state: Dictionary in live:
		var errors: Array = state["errors"]
		if state["seen"].size() != 6:
			errors.append("Rendered fewer than six distinct animation phases")
		var role: String = str(state["slot"][2])
		if role in ["idle", "run"] and not state["wrapped"]:
			errors.append("Loop never wrapped")
		if role in ["attack", "hit", "death"] and not state["last_frame_held"]:
			errors.append("One-shot did not hold last frame")
		var sheet: Image = Image.create(320 * 6, 360, false, Image.FORMAT_RGBA8)
		for phase: int in range(6):
			if state["images"][phase] != null:
				sheet.blit_rect(state["images"][phase], Rect2i(0, 0, 320, 360), Vector2i(phase * 320, 0))
		var slot: Array = state["slot"]
		var image_path: String = _out.path_join("rendered").path_join(str(slot[0]).replace(":", "_") + "-" + str(slot[1]) + "-" + str(slot[2]) + ".png")
		var save_result: Error = sheet.save_png(image_path)
		if save_result != OK:
			errors.append("Render evidence PNG save failed")
		_rows.append({"slot": slot, "status": "PASS" if errors.is_empty() else "FAIL", "errors": errors,
			"seen_phases": state["seen"].keys(), "loop_observed": state["wrapped"], "terminal_held": state["last_frame_held"],
			"duration_seconds": state["duration"], "first_complete_seconds": state["finished_at"],
			"origin_policy": state["player"].get_origin_policy(), "frame_transforms": state["frame_transforms"],
			"rendered_contact_sheet": image_path, "rendered_contact_sheet_sha256": FileAccess.get_sha256(image_path)})
		state["player"].free()
	_write_report(false)

func _run() -> void:
	if _out.is_empty() or _commit.length() != 40:
		push_error("Set LEGENDARY_FINAL_OUTPUT and exact LEGENDARY_FINAL_COMMIT")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out.path_join("rendered"))
	if DisplayServer.get_name() == "headless":
		_errors.append("Final render requires an actual display server")
	var staging: Variant = JSON.parse_string(FileAccess.get_file_as_string(STAGING))
	if not staging is Dictionary:
		_errors.append("Staging unavailable")
		_write_report(true)
		quit(2)
		return
	_manifest = str(staging.get("corrections", {}).get("active_revision_library", ""))
	_staging_sha = FileAccess.get_sha256(STAGING)
	_manifest_sha = FileAccess.get_sha256(_manifest)
	_library = LIBRARY.new()
	if not _library.configure(STAGING, _manifest):
		_errors.append(str(_library.last_error))
		_write_report(true)
		quit(2)
		return
	_setup_window()
	var slots: Array = []
	for actor: Dictionary in staging["actors"]:
		for direction: String in DIRECTIONS:
			for role: String in ROLES:
				slots.append([str(actor["key"]), direction, role])
		slots.append([str(actor["key"]), "S", "death"])
	_selection_path = OS.get_environment("LEGENDARY_FINAL_SLOT_FILE")
	if not _selection_path.is_empty():
		var selected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_selection_path))
		if not selected is Array or selected.is_empty():
			_errors.append("Targeted recovery requires explicit nonempty slot list")
			_write_report(true)
			quit(2)
			return
		for slot: Variant in selected:
			if not slot in slots:
				_errors.append("Targeted slot is outside the frozen catalog scope")
		if not _errors.is_empty():
			_write_report(true)
			quit(2)
			return
		slots = selected
		_parallel_clips = 1
	_expected_count = slots.size()
	for batch_start: int in range(0, slots.size(), _parallel_clips):
		await _batch(slots.slice(batch_start, mini(batch_start + _parallel_clips, slots.size())))
	if FileAccess.get_sha256(STAGING) != _staging_sha or FileAccess.get_sha256(_manifest) != _manifest_sha:
		_errors.append("Staging/manifest changed during integration; exact snapshot proof failed")
	_write_report(true)
	var failed: bool = not _errors.is_empty()
	for row: Dictionary in _rows:
		failed = failed or row["status"] == "FAIL"
	quit(1 if failed else 0)
