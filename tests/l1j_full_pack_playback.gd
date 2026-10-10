extends SceneTree
## Run against an installed private resource bundle. It is separate from synthetic CI.
var failures: Array[String] = []
var frame_total: int = 0
var sprite_total: int = 0
var advanced_total: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("L1J_FULL_PACK_FAIL: ", message)

func _run() -> void:
	var records: Array = []
	for part: int in range(1, 5):
		var path: String = "res://data/l1j/spx/part%d.json" % part
		if not FileAccess.file_exists(path):
			check(false, "missing manifest " + path)
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			records.append_array(parsed.get("sprites", []))
	check(records.size() == 1700, "expected 1700 source resources")
	var seen: Dictionary = {}
	var batch: Array[AnimatedSprite2D] = []
	for record: Dictionary in records:
		var id: String = str(record.get("sprite_id", ""))
		check(not seen.has(id), "duplicate " + id)
		seen[id] = true
		var path: String = "res://assets/l1j/candidates/spx_converted/%s/SpriteFrames.tres" % id
		var frames: SpriteFrames = load(path) as SpriteFrames
		check(frames != null, "load " + id)
		if frames == null: continue
		var count: int = frames.get_frame_count("default")
		check(count == int(record.get("frame_count", -1)), "frame count " + id)
		var size: Array = record.get("canvas_size", [0,0])
		for index: int in range(count):
			var texture: Texture2D = frames.get_frame_texture("default", index)
			check(texture != null, "texture " + id)
			if texture != null:
				var pixels: Image = texture.get_image()
				check(pixels != null and pixels.get_size() == Vector2i(int(size[0]), int(size[1])), "PNG pixels " + id)
			frame_total += 1
		var actor := AnimatedSprite2D.new()
		actor.name = "SPX_" + id.replace("-", "_")
		actor.sprite_frames = frames
		actor.speed_scale = 4.0
		actor.set_meta("advanced", false)
		actor.frame_changed.connect(func(): actor.set_meta("advanced", true))
		root.add_child(actor)
		actor.play("default")
		batch.append(actor)
		sprite_total += 1
		if batch.size() == 25 or sprite_total == records.size():
			# AnimatedSprite2D advances on process time, not the physics signal count.
			await process_frame
			await create_timer(0.20).timeout
			for playing: AnimatedSprite2D in batch:
				var single: bool = playing.sprite_frames.get_frame_count("default") == 1
				check(playing.is_playing() and (single or bool(playing.get_meta("advanced"))), "clock playback " + playing.name)
				if single or bool(playing.get_meta("advanced")): advanced_total += 1
				playing.queue_free()
			batch.clear()
			await process_frame
			print("L1J_PLAYBACK_PROGRESS ", sprite_total, "/1700")
	var report: Dictionary = {"sprites":sprite_total, "png_frames":frame_total, "played":advanced_total,
		"engine":Engine.get_version_info().string, "failures":failures}
	var output: FileAccess = FileAccess.open("res://SPX_GODOT_PLAYBACK.json", FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(report, "\t") + "\n")
	print("L1J_FULL_PACK_OK " if failures.is_empty() else "L1J_FULL_PACK_FAIL ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
