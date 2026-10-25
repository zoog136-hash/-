extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_demon_family_staging.json"))
	assert(register.shared_unique_clips == 33 and register.shared_unique_poses == 91)
	assert(register.actors.size() == 1 and register.family_adapters.size() == 3)
	var bindings: Dictionary = register.actors.duplicate()
	for key: String in register.family_adapters:
		var adapter: Dictionary = register.family_adapters[key]
		assert(adapter.new_source_poses == 0 and not adapter.newly_approved)
		var actor: Dictionary = register.actors[adapter.source_actor].duplicate()
		actor.native_profile = adapter.native_profile
		bindings[key] = actor
	var report_actors: Dictionary = {}
	var total_clips: int = 0
	for key: String in bindings:
		var actor: Dictionary = bindings[key]
		var textures: Array[ImageTexture] = []
		var loaded: Dictionary = {}
		for track: Dictionary in actor.tracks:
			if loaded.has(track.texture):
				continue
			var image: Image = Image.load_from_file(ProjectSettings.globalize_path("res://" + str(track.texture)))
			assert(image != null and not image.is_empty())
			var texture := ImageTexture.create_from_image(image)
			texture.take_over_path("res://" + str(track.texture))
			textures.append(texture)
			loaded[track.texture] = true
		var profile: Resource = load(actor.native_profile)
		var frames: SpriteFrames = load(actor.frames) as SpriteFrames
		assert(profile is Profile and profile.profile_id == key)
		assert(frames != null and frames.get_animation_names().size() == 33)
		assert(not actor.production_connected and not actor.detailed_completed)
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
				motion.advance(1.0 / 60.0, aim * 124.0 if track.role == "run" else Vector2.ZERO)
				motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
				assert(str(sprite.animation) == animation, "Wrong role/direction: " + key + ":" + animation)
				assert(not sprite.flip_h and sprite.rotation == 0.0)
				var pose: AtlasTexture = frames.get_frame_texture(animation, sprite.frame) as AtlasTexture
				assert(pose != null and pose.region.position.x >= 0 and pose.region.position.y >= 0)
				assert(pose.region.end.x <= pose.atlas.get_width() and pose.region.end.y <= pose.atlas.get_height())
				assert((sprite.position + Vector2(0, pose.get_height() / 8.0) * sprite.scale).length() < 0.001)
				seen[sprite.frame] = true
			assert(seen.size() == count, "Every source pose must play: " + key + ":" + animation)
			assert(frames.get_animation_loop(animation) == (track.role in ["idle", "run"]))
			if track.role == "attack":
				assert(profile.hit_frame_for("attack") == 1)
			if track.role == "death":
				assert(sprite.frame == count - 1 and motion.dead and motion.begin_attack(0.42, aim) == -1)
			role_counts[track.role] = int(role_counts.get(track.role, 0)) + 1
			checked += 1
			poses += count
		for direction: int in range(8):
			var death = Motion.new()
			death.profile = profile
			death.face(Vector2.RIGHT.rotated(direction * PI / 4.0))
			death.die()
			for tick: int in range(80):
				death.advance(1.0 / 60.0, Vector2(124, 0))
				death.apply(sprite, Vector2.ONE * profile.pixel_scale)
				assert(sprite.animation == &"death_2" and not sprite.flip_h)
			assert(sprite.frame == 2 and death.dead and death.begin_attack(0.4, Vector2.RIGHT) == -1)
		assert(checked == 33 and poses == 91)
		assert(role_counts == {"run": 8, "idle": 8, "attack": 8, "hit": 8, "death": 1})
		report_actors[key] = {"binding_clips": checked, "shared_poses_replayed": poses,
			"new_source_poses": 91 if register.actors.has(key) else 0,
			"source_quality": "HOLD", "default_Main": "NOT_RUN", "new_approvals": 0}
		total_clips += checked
		sprite.queue_free()
		await process_frame
	var report := {"engine": Engine.get_version_info().string, "shared_unique_clips": 33,
		"shared_unique_poses": 91, "candidate_species": 4, "binding_clips_tested": total_clips,
		"PNG_load": "PASS", "SpriteFrames_load": "PASS", "actual_ActorMotion_playback": "PASS",
		"NPC_speed_124_RUN": "PASS", "canvas_foot_anchor_and_regions": "PASS",
		"S_death_8_headings_terminal_hold_per_binding": "PASS", "actors": report_actors,
		"new_walk_sources": 0, "source_identity_hand_direction_support_contact_review": "HOLD",
		"default_Main": "NOT_RUN", "new_approvals": 0}
	var destination: String = OS.get_environment("PR122_DEMON_FAMILY_REPORT")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_DEMON_FAMILY_PLAYBACK_PASS shared_clips=33 unique_poses=91 binding_clips=132 species=4 approvals_added=0")
	quit(0)
