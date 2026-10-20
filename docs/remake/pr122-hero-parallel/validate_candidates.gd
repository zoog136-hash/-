extends SceneTree
## Real Main, in-memory candidate injection only; no default catalog writes.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const SCOPE = preload("res://scripts/animation/transformation_movement_scope.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const ROLES := ["idle", "run", "attack", "hit", "death"]
var textures: Array[ImageTexture] = []
var checks: int = 0
var captures: int = 0
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("HERO_VALIDATION_FAIL " + message)
		failed = true
	checks += 1

func _fingerprint(world: Node) -> String:
	return JSON.stringify([world.hp, world.gold, world.inventory, world.equipped_items,
		world.equipped_catalog, world._normal_attack_interval(), world._current_weapon_type(),
		world.player.position, world.player.get_node("CollisionShape2D").transform,
		world.player.class_sprite.sprite_frames.resource_path, world.player.move_speed,
		world.player.attack_speed_multiplier, world.player.equipment_move_speed_multiplier])

func _settings(profile: Resource) -> Dictionary:
	var result: Dictionary = {}
	for field: String in ["frames_path", "layout", "motion_style", "movement_fps", "reference_speed", "pixel_scale", "native_width_ratio", "movement_cadence_width_ratio", "embedded_shadow", "authored_motion_weight", "hit_recoil", "death_duration", "body_kind", "floating", "attack_hit_frame", "action_hit_frames", "attack_animation_speed"]:
		result[field] = profile.get(field)
	result.sprite_offset = [profile.sprite_offset.x, profile.sprite_offset.y]
	result.color_tint = profile.color_tint.to_html()
	if profile.use_profile_hit_ratio: result.attack_hit_ratio = profile.attack_hit_ratio
	return result

func _tick(player: Node, velocity: Vector2 = Vector2.ZERO) -> void:
	player.motion.advance(1.0 / 240.0, velocity)
	player.motion.apply(player.transform_sprite, player.transform_sprite.get_meta("base_scale", Vector2.ONE))

func _run() -> void:
	_check(Engine.get_version_info().string.begins_with("4.7.2"), "wrong engine")
	_check(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"), "isolated save path required")
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	_check(staging.hero_total_in_498 == 109 and staging.pending_total == 25, "exact roster")
	var target_ids := OS.get_environment("TWILIGHT_HERO_TEST_IDS").split(",", false)
	if target_ids.is_empty(): target_ids = PackedStringArray(["179", "182"])
	var frames_path: String = staging.actors["transform:" + target_ids[0]].frames
	var revision: String = frames_path.get_base_dir().get_file()
	var group: String = frames_path.get_base_dir().get_base_dir().get_file()
	var evidence_suffix := OS.get_environment("TWILIGHT_HERO_EVIDENCE_SUFFIX")
	_check(evidence_suffix.is_empty() or evidence_suffix.is_valid_identifier(), "safe evidence suffix")
	var evidence := "res://docs/remake/pr122-hero-parallel/evidence/" + group + "-" + revision + "-visible-main" + ("-" + evidence_suffix if not evidence_suffix.is_empty() else "") + "/"
	DirAccess.make_dir_recursive_absolute(evidence)
	var image := Image.load_from_file(frames_path.get_base_dir() + "/run.png")
	var live := ImageTexture.create_from_image(image)
	live.take_over_path(frames_path.get_base_dir() + "/run.png")
	textures.append(live)
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(frames_path.get_base_dir() + "/rig-proof.json"))
	var source: SpriteFrames = load(str(proof.source)) if str(proof.source).ends_with(".tres") else null
	var new_art: bool = str(proof.get("schema", "")) == "hero-unique-full-atlas-v1"
	_check(source != null or new_art, "known authoring contract")
	if new_art:
		for path: String in proof.source_hashes:
			_check(FileAccess.get_sha256(path) == str(proof.source_hashes[path]), "immutable new art source SHA")
	_check(proof.frames.size() == 48, "48 actual articulated poses")
	for direction: int in range(8):
		var unique: Dictionary = {}
		for phase: int in range(6):
			var row: Dictionary = proof.frames[direction * 6 + phase]
			var region := image.get_region(Rect2i(phase * 256, direction * 256, 256, 256))
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(region.get_data())
			var value := hash.finish().hex_encode()
			_check(value == row.rgba_sha256 and not unique.has(value), "unique actual RGBA")
			unique[value] = true
			var box := region.get_used_rect()
			_check(box.position.x > 0 and box.position.y > 0 and box.end.x < 256 and box.end.y < 256, "no clipping")
			if not new_art:
				_check(row.support == ("AIR" if phase % 3 == 2 else ("A" if phase < 3 else "B")), "alternating support model")
			for leg: Dictionary in row.get("legs", []):
				var hip := Vector2(leg.hip[0], leg.hip[1])
				var knee := Vector2(leg.knee[0], leg.knee[1])
				var ankle := Vector2(leg.ankle[0], leg.ankle[1])
				var lengths: Array = leg.bone_lengths
				_check(absf(hip.distance_to(knee) - float(lengths[0])) < .02 and absf(knee.distance_to(ankle) - float(lengths[1])) < .02, "source-fitted bone lengths remain fixed")
				if leg.has("source_joints"):
					var original: Dictionary = leg.source_joints
					var source_hip := Vector2(original.hip[0], original.hip[1])
					var source_knee := Vector2(original.knee[0], original.knee[1])
					var source_ankle := Vector2(original.ankle[0], original.ankle[1])
					_check(absf(source_hip.distance_to(source_knee) - float(lengths[0])) < .02 and absf(source_knee.distance_to(source_ankle) - float(lengths[1])) < .02, "bind lengths measured from preserved source joints")
	var world: Node = load("res://Main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	_check(CLASS_QA.enter_game(world), "actual Main class confirmation entered gameplay")
	world.hud._close_workspace()
	await process_frame
	player_camera_update(world)
	world.save_timer = -10000.0
	var player: Node = world.player
	var strikes: Array[int] = []
	player.attack_strike.connect(func(sequence: int) -> void: strikes.append(sequence))
	var results: Array = []
	for sid: String in target_ids:
		var key := "transform:" + sid
		var entry: Dictionary = staging.actors[key]
		_check(entry.frames == frames_path, "one immutable body group per validation run")
		_check(not entry.final_approved and not entry.production_connected, "candidate never auto-approved")
		var row: Dictionary = {}
		for item: Dictionary in world.catalog_db["변신"]:
			if str(item.sourceId) == sid: row = item
		_check(not row.is_empty() and row.grade == "영웅", "correct Main character")
		var before_catalog := JSON.stringify(row)
		var baseline: Resource = CATALOG.for_record("transform", row, row.image_path)
		var profile: Resource = load(entry.native_profile)
		var candidate := row.duplicate(true)
		candidate.animation_profile = _settings(profile)
		var before := _fingerprint(world)
		player.motion.dead = false
		world._apply_transform_visual(candidate)
		_check(player.transform_active and player.motion.profile.profile_id == key, "real Main transformation API")
		_check(not SCOPE.requires_walk(key), "hero walk excluded")
		for field: String in ["attack_hit_ratio", "attack_hit_frame", "attack_animation_speed", "death_duration", "pixel_scale", "native_width_ratio", "reference_speed", "sprite_offset", "color_tint"]:
			_check(profile.get(field) == baseline.get(field), "preserve prior field " + field)
		var sprite: AnimatedSprite2D = player.transform_sprite
		var frames: SpriteFrames = sprite.sprite_frames
		_check(sprite.is_visible_in_tree(), "actual player visible in tree")
		var max_phases: int = 6
		var expected_rendered_phases: int = 0
		for role: String in ROLES:
			for heading: int in range(8):
				var count: int = frames.get_frame_count(role + "_" + str(heading))
				max_phases = maxi(max_phases, count)
				expected_rendered_phases += count
		var rendered := Image.create(max_phases * 160, 8 * 5 * 160, false, Image.FORMAT_RGBA8)
		var rendered_phases: int = 0
		_check(frames.get_animation_names().size() == 40, "five roles x eight directions")
		for direction: int in range(8):
			var aim := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
			_check(not frames.has_animation("walk_" + str(direction)), "no copied walk")
			for role: String in ROLES:
				var track := role + "_" + str(direction)
				_check(frames.has_animation(track), "missing role " + track)
				if new_art:
					_check(frames.get_frame_count(track) == proof.track_sources[track].size(), "complete source action registration")
					for index: int in range(frames.get_frame_count(track)):
						var reference: Dictionary = proof.track_sources[track][index].source_reference
						var texture: AtlasTexture = frames.get_frame_texture(track, index)
						_check(texture.atlas.resource_path == str(reference.atlas), "exact new source texture")
						_check(texture.region == Rect2(reference.region[0], reference.region[1], reference.region[2], reference.region[3]), "exact new source region")
						_check(texture.margin == Rect2(37, 37, 75, 75), "padding only, no width/height scaling")
				elif role != "run":
					_check(frames.get_frame_count(track) == source.get_frame_count(track), "legacy action length")
					for index: int in range(source.get_frame_count(track)):
						_check(frames.get_frame_texture(track, index).region == source.get_frame_texture(track, index).region, "legacy texture region")
						_check(frames.get_frame_texture(track, index).margin == source.get_frame_texture(track, index).margin, "legacy anchors")
						_check(frames.get_frame_texture(track, index).atlas.resource_path == source.get_frame_texture(track, index).atlas.resource_path, "legacy actual texture")
						_check(is_equal_approx(frames.get_frame_duration(track, index), source.get_frame_duration(track, index)), "legacy phase duration")
					_check(is_equal_approx(frames.get_animation_speed(track), source.get_animation_speed(track)), "legacy action fps")
				player.motion.dead = false
				player.motion.advance(3.0, Vector2.ZERO)
				player.motion.face(aim)
				var velocity := Vector2.ZERO
				var strike_start := strikes.size()
				var sequence: int = -1
				match role:
					"run": velocity = aim * profile.reference_speed
					"attack": sequence = player.start_combat_attack(player.global_position + aim, .9, profile.motion_style)
					"hit": player.motion.react(false, -aim)
					"death": player.motion.die()
				var seen: Dictionary = {}
				var rendered_unique: Dictionary = {}
				var released := false
				for tick: int in range(300):
					_tick(player, velocity)
					if str(sprite.animation) == track and not seen.has(sprite.frame):
						seen[sprite.frame] = true
						if DisplayServer.get_name() != "headless":
							await process_frame
							await RenderingServer.frame_post_draw
							var screen := root.get_texture().get_image()
							var center: Vector2 = sprite.get_global_transform_with_canvas().origin
							_check(root.get_visible_rect().has_point(center), "actual character centered inside Main viewport")
							var crop := Rect2i(Vector2i(center) - Vector2i(80, 80), Vector2i(160, 160)).intersection(Rect2i(Vector2i.ZERO, screen.get_size()))
							rendered.blit_rect(screen, crop, Vector2i(sprite.frame * 160, (ROLES.find(role) * 8 + direction) * 160))
							if role == "run":
								var digest := HashingContext.new()
								digest.start(HashingContext.HASH_SHA256)
								digest.update(screen.get_region(crop).get_data())
								rendered_unique[digest.finish().hex_encode()] = true
							rendered_phases += 1
					if role == "attack" and strikes.size() > strike_start and not released:
						_check(strikes.size() == strike_start + 1 and strikes.back() == sequence, "one authoritative strike")
						_check(str(sprite.animation) == track and sprite.frame == profile.attack_hit_frame, "same strike pose and timing")
						released = true
				_check(seen.size() == frames.get_frame_count(track), "all phases actually played " + key + "/" + track)
				if role == "run" and DisplayServer.get_name() != "headless":
					_check(rendered_unique.size() == 6, "six visible distinct Main run poses; no hidden character/overlay")
				_check((strikes.size() == strike_start + 1 and released) if role == "attack" else strikes.size() == strike_start, "no extra strikes")
				var base: Vector2 = sprite.get_meta("base_scale", Vector2.ONE)
				_check(not sprite.flip_h and sprite.scale.is_equal_approx(base), "preserve existing Main scale without extra width distortion")
				_check(is_equal_approx(base.x / base.y, player.TRANSFORM_WIDTH_SCALE), "existing player width policy preserved")
				_check(_fingerprint(world) == before and JSON.stringify(row) == before_catalog, "Main game invariants")
			# Omitted WALK must select dedicated RUN even at low real speed.
			player.motion.dead = false
			player.motion.advance(3.0, Vector2.ZERO)
			_tick(player, aim * profile.reference_speed * .3)
			_check(str(sprite.animation) == "run_" + str(direction), "low-speed dedicated run")
		player.motion.dead = false
		_tick(player)
		if not DisplayServer.get_name() == "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			var path := evidence + "Main-" + sid + ".png"
			_check(root.get_texture().get_image().save_png(path) == OK, "actual Main rendered to file")
			_check(rendered.save_webp(evidence + "Main-all-poses-" + sid + ".webp", false) == OK, "all real Main pose captures saved losslessly")
			_check(rendered_phases == expected_rendered_phases, "every candidate phase actually rendered")
			captures += 1
		results.append({"id": key, "roles": 5, "directions": 8, "rendered_phases": rendered_phases, "status": "TECHNICAL_MAIN_CANDIDATE_PASS", "visual_identity_approval": false})
	player.clear_transform_visual()
	world.queue_free()
	await process_frame
	if failed:
		print("HERO_MAIN_TECHNICAL_FAIL checks=%d" % checks)
		quit(1)
		return
	var result := {"schema": "hero-parallel-validation-v1", "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "checks": checks, "captures": captures, "actors": results, "frames_sha256": FileAccess.get_sha256(frames_path), "run_png_sha256": FileAccess.get_sha256(frames_path.get_base_dir() + "/run.png"), "default_game_connections": 0, "new_final_approvals": 0, "visual_identity_and_contact_quality": "HOLD", "existing_player_width_ratio_preserved": 0.9}
	var suffix := "opengl" if captures > 0 else "headless"
	var file := FileAccess.open(evidence + "validation-" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ") + "\n")
	if suffix == "opengl":
		# Another sequential producer may have advanced an unrelated actor while
		# this renderer ran. Never write a stale copy over those newer entries.
		staging = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
		for sid: String in target_ids:
			if staging.actors["transform:" + sid].frames == frames_path:
				staging.actors["transform:" + sid]["main_validation_report"] = evidence + "validation-opengl.json"
		var ledger := FileAccess.open("res://data/pr122_hero_parallel_staging.json", FileAccess.WRITE)
		ledger.store_string(JSON.stringify(staging, "  ") + "\n")
	print("HERO_MAIN_TECHNICAL_PASS actors=%d directions=8 roles=5 checks=%d captures=%d approvals=0 default_game_connections=0" % [target_ids.size(), checks, captures])
	quit(0)

func player_camera_update(world: Node) -> void:
	world.player.camera.make_current()
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	if world.field_renderer != null: world.field_renderer.refresh_visible()
