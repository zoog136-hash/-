extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for actor_key: String in ["monster:로머", "monster:에스카로스 치프"]:
		await _check_actor(actor_key)
	quit(0)

func _check_actor(actor_key: String) -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_orc_family_staging.json"))
	var actor: Dictionary
	if register.actors.has(actor_key):
		actor = register.actors[actor_key]
	else:
		var adapter: Dictionary = register.family_adapters[actor_key]
		actor = register.actors[adapter.source_actor].duplicate(true)
		actor.native_profile = adapter.native_profile
	var textures: Array[ImageTexture] = []
	var loaded: Dictionary = {}
	for track: Dictionary in actor.tracks:
		if loaded.has(track.texture): continue
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path("res://" + str(track.texture)))
		assert(image != null and not image.is_empty())
		var texture := ImageTexture.create_from_image(image)
		texture.take_over_path("res://" + str(track.texture))
		textures.append(texture)
		loaded[track.texture] = true
	var profile: Resource = load(actor.native_profile)
	var frames: SpriteFrames = load(actor.frames) as SpriteFrames
	assert(profile is Profile and profile.profile_id == actor_key)
	assert(frames != null and frames.get_animation_names().size() == 33)
	assert(actor.missing_required_tracks.is_empty() and not actor.production_connected and not actor.detailed_completed)
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
	var checked: int = 0
	var poses: int = 0
	var role_counts: Dictionary = {}
	for track: Dictionary in actor.tracks:
		var animation: String = track.animation
		var count: int = track.geometry.frames.size()
		assert(frames.get_frame_count(animation) == count)
		var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
		var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
		var motion = Motion.new()
		motion.profile = profile
		motion.face(aim)
		motion.advance(0.1, Vector2.ZERO)
		motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
		var ticks: int = 180
		match str(track.role):
			"attack":
				motion.begin_attack(0.42, aim, "slash")
				ticks = 24
			"hit":
				motion.react(false, -aim)
				ticks = 12
			"death":
				motion.die()
				ticks = 80
		var seen: Dictionary = {}
		for tick: int in range(ticks):
			var velocity: Vector2 = aim * 124.0 if track.role == "run" else Vector2.ZERO
			motion.advance(1.0 / 60.0, velocity)
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
			assert(str(sprite.animation) == animation, "Role/direction must use its real track: " + animation)
			assert(not sprite.flip_h and sprite.rotation == 0.0)
			var pose: AtlasTexture = frames.get_frame_texture(animation, sprite.frame) as AtlasTexture
			assert(pose != null and pose.region.position.x >= 0 and pose.region.position.y >= 0)
			assert(pose.region.end.x <= pose.atlas.get_width() and pose.region.end.y <= pose.atlas.get_height())
			assert((sprite.position + Vector2(0, pose.get_height() / 8.0) * sprite.scale).length() < 0.001)
			seen[sprite.frame] = true
		assert(seen.size() == count, "Every actual pose must play: " + animation)
		assert(frames.get_animation_loop(animation) == (track.role in ["idle", "run"]))
		if track.role == "attack": assert(profile.hit_frame_for("attack") == 1)
		if track.role == "death":
			assert(sprite.frame == count - 1 and motion.dead and motion.begin_attack(0.42, aim) == -1)
		role_counts[track.role] = int(role_counts.get(track.role, 0)) + 1
		checked += 1
		poses += count
	# Only one real death source is authored; the runtime resolves S for all headings.
	for direction: int in range(8):
		var motion = Motion.new()
		motion.profile = profile
		motion.face(Vector2.RIGHT.rotated(direction * PI / 4.0))
		motion.die()
		for tick: int in range(80):
			motion.advance(1.0 / 60.0, Vector2(124, 0))
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
			assert(sprite.animation == &"death_2" and not sprite.flip_h)
		assert(sprite.frame == 2 and motion.dead and motion.begin_attack(0.4, Vector2.RIGHT) == -1)
	assert(checked == 33 and poses == 91)
	assert(role_counts == {"run": 8, "idle": 8, "attack": 8, "hit": 8, "death": 1})
	var report := {"engine": Engine.get_version_info().string, "actor": actor_key, "clips": checked, "poses": poses,
		"roles": role_counts, "PNG_load": "PASS", "SpriteFrames_load": "PASS", "actual_ActorMotion_playback": "PASS",
		"NPC_speed_124_RUN": "PASS", "canvas_foot_anchor_and_regions": "PASS", "S_death_all_headings_terminal_hold": "PASS",
		"new_walk_sources": 0, "source_identity_contact_support_visual_review": "HOLD", "default_Main": "NOT_RUN", "new_approvals": 0}
	var destination: String = OS.get_environment("PR122_ORC_REPORT_PREFIX")
	if not destination.is_empty():
		var file := FileAccess.open(destination + ("-romer.json" if actor_key == "monster:로머" else "-escaros-chief.json"), FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_ORC_PLAYBACK_PASS actor=%s clips=33 poses=91 actual_NPC_speed=124 S_death=8_headings approvals_added=0" % actor_key + "")
	sprite.queue_free()
	await process_frame
