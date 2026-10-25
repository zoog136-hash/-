extends SceneTree
## Actual Main -> real monster catalog -> Monster.setup -> ActorMotion/Sprite2D.
## QA image loader reads real source bytes; no imported-image fixtures/candidates.

class NativeImageLoader extends ResourceFormatLoader:
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["png", "webp", "jpg", "jpeg", "svg", "ttf", "otf", "wav", "ogg"])
	func _handles_type(type: StringName) -> bool:
		return type in [&"Texture2D", &"ImageTexture", &"Texture", &"Font", &"FontFile", &"AudioStream", &"AudioStreamWAV", &"AudioStreamOggVorbis"]
	func _get_resource_type(path: String) -> String:
		if path.get_extension().to_lower() in ["ttf", "otf"]: return "FontFile"
		if path.get_extension().to_lower() == "wav": return "AudioStreamWAV"
		if path.get_extension().to_lower() == "ogg": return "AudioStreamOggVorbis"
		return "Texture2D" if path.get_extension().to_lower() in _get_recognized_extensions() else ""
	func _exists(path: String) -> bool:
		return FileAccess.file_exists(path)
	func _load(path: String, _original: String, _subthreads: bool, _cache: int) -> Variant:
		if path.get_extension().to_lower() == "wav": return AudioStreamWAV.load_from_file(path)
		if path.get_extension().to_lower() == "ogg": return AudioStreamOggVorbis.load_from_file(path)
		if path.get_extension().to_lower() in ["ttf", "otf"]:
			var font := FontFile.new()
			font.data = FileAccess.get_file_as_bytes(path)
			return font
		var im := Image.load_from_file(path)
		if im == null or im.is_empty(): return ERR_FILE_CORRUPT
		return ImageTexture.create_from_image(im)

var loader: NativeImageLoader
var report := {"actual_Main": true, "candidate_injections": 0, "cases": [], "errors": [], "walk_resolution_checks": 0}
var output: String

func check(value: bool, message: String) -> bool:
	if not value:
		report.errors.append(message)
		push_error(message)
	return value

func finish(code: int) -> void:
	var f := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t") + "\n")
	print("BOSS_DEFAULT_MAIN_RESULT " + str(code) + " cases=" + str(report.cases.size()) + " errors=" + str(report.errors.size()))
	quit(code)

func _initialize() -> void:
	output = OS.get_environment("BOSS_DEFAULT_MAIN_OUTPUT")
	loader = NativeImageLoader.new()
	ResourceLoader.add_resource_format_loader(loader, true)
	call_deferred("run")

func _walk_resolution() -> void:
	var motion_script = load("res://scripts/animation/actor_motion.gd")
	var profile_script = load("res://scripts/animation/animation_profile.gd")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.set_meta("twilight_native_locomotion_staging", true)
	var im := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	im.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(im)
	for d in range(8):
		frames.add_animation("run_" + str(d))
		frames.add_frame("run_" + str(d), tex)
	for native in [true, false]:
		frames.set_meta("twilight_native_locomotion_staging", native)
		for d in range(8):
			var motion = motion_script.new()
			motion.profile = profile_script.new()
			motion.profile.profile_id = "monster:walk_scope_probe"
			motion.profile.layout = "directional8"
			motion.facing8 = d
			motion.state = "walk"
			motion._resolve_frames(frames)
			check(motion._resolved_key == "run_" + str(d), "Missing new monster WALK must resolve same-facing RUN")
			report.walk_resolution_checks += 1
		frames.add_animation("walk_2")
		frames.add_frame("walk_2", tex)
		var existing = motion_script.new()
		existing.profile = profile_script.new()
		existing.profile.profile_id = "monster:existing_walk_probe"
		existing.profile.layout = "directional8"
		existing.facing8 = 2
		existing.state = "walk"
		existing._resolve_frames(frames)
		check(existing._resolved_key == "walk_2", "Real existing WALK must be preserved")
		frames.remove_animation("walk_2")

func _world_state(world: Node) -> String:
	return JSON.stringify([world.hp, world.gold, world.inventory, world.equipped_items, world.equipped_catalog, world.player.collision_layer, world.player.collision_mask])

func run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280,720)
	_walk_resolution()
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_boss_runtime_connections.json"))
	var plan := {"actors": []}
	for row: Dictionary in ledger.connections:
		plan.actors.append({"key": row.id, "frames": row.frames})
	var scene = load("res://Main.tscn")
	if not check(scene != null, "Actual Main.tscn loads"): finish(1); return
	var world = scene.instantiate()
	if not check(world.has_method("_monster_texture"), "Actual Main script and its real dependencies compile"): finish(1); return
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.save_timer = -10000.0
	# Dismiss only the fresh isolated-save picker through its existing HUD API.
	# Character creation is outside this animation check; no catalog is injected.
	if bool(world.hud.get("class_picker_initial")): world.hud.complete_class_selection()
	world.player.camera.make_current()
	world.player.camera.force_update_scroll()
	var before := _world_state(world)
	var monster_scene = load("res://scenes/Monster.tscn")
	for expected: Dictionary in plan.actors:
		var record: Dictionary = {}
		for value: Dictionary in world.monster_db:
			if "monster:" + str(value.get("name", "")) == expected.key:
				record = value.duplicate(true)
		if not check(not record.is_empty(), "Real monster DB contains " + str(expected.key)): continue
		var row := {"key": expected.key, "frames": expected.frames, "directions": [], "captures": [], "required_requests": 0, "seen_clips": {}, "attack_release_events": 0}
		for d in range(8):
			# A fresh actual Monster for each irreversible south/shared death.
			var actor = monster_scene.instantiate()
			world.monsters_root.add_child(actor)
			actor.position = world.player.position + Vector2(170,60)
			actor.setup(record, world.player, world, world._monster_texture(record))
			actor.set_physics_process(false)
			check(actor.motion.profile.frames_path == expected.frames, "Default catalog selects reviewed frames " + str(expected.key))
			check(actor.motion.frame_source.resource_path == expected.frames, "Actual Monster owns default SpriteFrames")
			check(actor.max_hp == int(record.hp), "Boss HP preserved")
			check(is_equal_approx(actor.attack_interval, float(record.get("attack_interval",1.25))), "Boss attack clock preserved")
			check(actor.sprite.material == null, "No portrait shader warps authored poses")
			check(actor.motion.profile.color_tint == Color.WHITE, "Dedicated boss retains authored colors")
			var aim := Vector2.RIGHT.rotated(d * PI / 4.0)
			actor.motion.face(aim)
			var strikes: Array = []
			actor.motion.strike.connect(func(sequence: int) -> void: strikes.append(sequence))
			for role in ["idle","walk","run","attack","hit","death"]:
				actor.motion.cancel_attack()
				actor.motion.hit_clock = 0.0
				actor.motion.state = role
				if role == "attack": actor.motion.begin_attack(minf(.68,actor.attack_interval*.75), aim, actor.motion.profile.motion_style, actor.motion.profile.marker_for(actor.motion.profile.motion_style))
				elif role == "hit": actor.motion.react(false, -aim)
				elif role == "death": actor.motion.die()
				actor.motion.invalidate_pose()
				actor.motion._resolve_frames(actor.motion.frame_source)
				var clip: String = actor.motion._resolved_key
				var required: String = ("run" if role == "walk" else role) + "_" + str(2 if role == "death" else d)
				check(clip == required, "Exact default role/view " + str(expected.key) + " " + role + " " + str(d))
				check(actor.motion.frame_source.has_animation(clip), "Required clip exists")
				var count: int = actor.motion.frame_source.get_frame_count(clip)
				var seen: Dictionary = {}
				strikes.clear()
				var capture_tick: int = int(ceil(actor.motion.attack_duration * actor.motion.attack_hit_ratio * 120.0)) - 1 if role == "attack" else 80
				# Exercise existing engine controller time across the whole action.
				for tick in range(145):
					var velocity: Vector2 = aim * actor.base_move_speed * (.35 if role == "walk" else 1.0) if role in ["walk","run"] else Vector2.ZERO
					actor.motion.advance(1.0/120.0,velocity)
					if role == "idle": actor.motion.state = "idle"
					actor.motion.apply(actor.sprite, actor.animation_base_scale)
					if actor.motion._resolved_key == clip:
						var frame = actor.sprite.texture
						if frame != null: seen[frame.get_instance_id()] = true
					check(actor.sprite.texture != null and not actor.sprite.flip_h, "Whole authored Sprite2D pose, no mirror")
					if tick == capture_tick and d in [0,4,6] and role in ["idle","run","attack"]:
						await RenderingServer.frame_post_draw
						var path: String = output.path_join(str(plan.actors.find(expected)) + "-" + role + "-" + str(d) + ".png")
						check(root.get_texture().get_image().save_png(path) == OK, "Visible actual Main viewport capture")
						row.captures.append(path)
				row.required_requests += 1
				check(seen.size() == count, "Every actual authored pose sampled " + str(expected.key) + " " + role + " " + str(d) + " seen=" + str(seen.size()) + "/" + str(count))
				if role == "attack":
					check(strikes.size() == 1, "Exactly one existing combat release event per attack")
					row.attack_release_events += strikes.size()
				row.seen_clips[clip] = count
			row.directions.append(d)
			actor.queue_free()
			await process_frame
		report.cases.append(row)
	check(_world_state(world) == before, "Animation QA preserves player inventory, HP, gold and equipment")
	world.queue_free()
	await process_frame
	await process_frame
	ResourceLoader.remove_resource_format_loader(loader)
	finish(0 if report.errors.is_empty() else 1)
