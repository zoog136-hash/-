extends SceneTree
const TexturePixels = preload("res://tests/texture_pixels.gd")

const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
const ANIMATIONS = preload("res://scripts/animation/animation_catalog.gd")
const ART = preload("res://scripts/monsters/monster_art.gd")
const ROLES = ["idle", "walk", "run", "attack", "hit", "death"]
const EXPECTED_SOURCE_IDS = ["45006", "45023", "45060", "45097", "45010", "45015", "45029", "45039", "45040", "45044", "45048", "45055", "45077", "45041", "45192", "45147", "45116", "45083", "45089", "45321", "45154", "45172", "45195", "45214", "45246", "45249", "45322", "45375", "45549", "46042", "46044", "81159", "81368", "46107", "46109", "46115", "45027", "45280", "45213", "45088", "45160", "45235", "45257", "45258", "45279", "45285", "45295", "45296", "45299", "45557", "45726", "45734", "45745", "45750", "45752", "45648", "45651", "45680", "45676", "45677", "45678", "45777", "45504", "45588", "45602", "45612", "45574", "45646", "45539", "45615", "45671", "46048", "95001", "46065", "97097", "46113", "95002", "95004", "95008", "95010", "95014", "95016", "95018", "45413", "45625", "45685", "45675", "45585", "45548", "45215", "45126", "45955", "45956", "45957", "45958", "45959", "45960", "45961", "45962", "46066", "46067", "45166", "45153", "45681", "45682", "45683", "45684", "46025", "46026", "46037", "81163", "97068", "45941", "45943"]
var failures: int = 0
var checks: int = 0

class Arena extends Node2D:
	var field_map = null
	var combat_flights = null
	var monster_db: Array = []
	func is_player_concealed() -> bool: return false
	func _has_line_of_sight_world(_a: Vector2, _b: Vector2) -> bool: return true
	func find_world_path(a: Vector2, b: Vector2) -> PackedVector2Array: return PackedVector2Array([a, b])

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("REVIEWED MONSTER FAIL: " + label)

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var base: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))["몬스터"]
	var before: Array = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-script="):
			before = load(arg.trim_prefix("--baseline-script=")).expand(base)
	var all: Array = CATALOG.expand(base)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preserve-script="):
			var prior: Array = load(arg.trim_prefix("--preserve-script=")).expand(base)
			check(prior.size() == 409 and all.slice(0, 409) == prior, "all original 318 and prior 91 records preserved")
	check(all.size() == 456, "318 existing plus 113 retained source and twenty-five reviewed gaps; one appearance HOLD")
	check(CATALOG.spawnable_records(all) == all.slice(0, 318), "random spawn pool exactly preserves old 318 and order")
	if not before.is_empty():
		check(before.size() == 318, "baseline contains 318")
		check(all.slice(0, 318) == before, "every existing field/stat/ID/AI preserved")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG.REVIEWED_PATH))
	check(payload.records.size() == 114, "all 114 bounded inputs retained")
	var actual_ids: Array = payload.records.map(func(r: Dictionary) -> String: return str(r.source_npc_id))
	check(actual_ids == EXPECTED_SOURCE_IDS, "exact approved identities/order; held gremlin excluded")
	var held: Array = payload.records.filter(func(r: Dictionary) -> bool: return str(r.get("appearance_status", "")).begins_with("HOLD_"))
	check(held.size() == 1 and str(held[0].source_npc_id) == "45153", "only the specifically permitted fairy appearance HOLD")
	for excluded: String in ["45025", "97006", "97044", "97094", "81082"]:
		check(not actual_ids.has(excluded), "excluded duplicate/phase not imported: " + excluded)
	for record: Dictionary in payload.records:
		if str(record.get("appearance_status", "")).begins_with("HOLD_"):
			check(not CATALOG.reviewed_record_allowed(record), "held appearance inactive")
			var attempted: Dictionary = record.duplicate(true)
			attempted.import_enabled = true
			check(not CATALOG.reviewed_record_allowed(attempted), "appearance HOLD cannot be bypassed by import flag")
			check(str(record.animation_profile.frames_path).is_empty() and str(record.source_portrait).is_empty(), "no incomplete fairy default art installed")
			check(int(record.source_binding.source_gfxid) == 5684 and int(record.source_binding.body_model_prefix) == 854, "fairy identity and draft source retained separately")
			continue
		if not record.has("source_binding"): continue
		check(CATALOG.reviewed_record_allowed(record), "current-session named identity authorized locally")
		if not str(record.identity_approval).begins_with("APPROVED") :
			var unapproved: Dictionary = record.duplicate(true)
			unapproved.erase("local_application_authorization")
			check(not CATALOG.reviewed_record_allowed(unapproved), "provisional source status alone cannot enable import")
			unapproved = record.duplicate(true)
			unapproved["source_npc_id"] = "45025"
			check(not CATALOG.reviewed_record_allowed(unapproved), "local authorization does not broaden to held identities")
		check(record.source_binding.binding_id == "M" + str(record.source_npc_id), "named binding not selected by shared representative")
		check(int(record.source_binding.source_gfxid) == int(record.source_raw_fields.gfxid), "source gfx retained separately from raw prefix")
		check(int(record.source_animation.resolved_raw_prefix) == int(record.source_binding.explicit_resolved_body_prefix), "explicit raw prefix preserved")
	var ids: Dictionary = {}
	for record: Dictionary in all:
		var key: String = str(record.get("sourceId", record.name))
		check(not ids.has(key), "unique identity " + key)
		ids[key] = true
	# Name/source links already present in an input catalog must take precedence.
	var with_existing: Array = base.duplicate(true)
	with_existing.append(payload.records[0].duplicate(true))
	check(CATALOG.expand(with_existing).size() == 456, "repeated identity not duplicated")
	with_existing = base.duplicate(true)
	with_existing.append({"name":"existing linked identity", "source_id":payload.records[0].source_id})
	check(CATALOG.expand(with_existing).size() == 456, "full source identity prevents alias duplicate")
	var arena := Arena.new()
	root.add_child(arena)
	arena.monster_db = all
	var population: FieldPopulation = load("res://scripts/maps/field_population.gd").new()
	arena.add_child(population)
	var field: PlayableField = load("res://scripts/maps/playable_field.gd").new()
	field.data = {"map_id":"catalog_validation_field","monster_spawn": []}
	population.configure(arena, field)
	check(population.records.size() == 318, "field/source population excludes catalog-only identities")
	population.set_process(false)
	population.queue_free()
	field = null
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	arena.add_child(player)
	player.set_physics_process(false)
	player.hide()
	player.get_node("Camera2D").enabled = false
	var actors: Array[TwilightMonster] = []
	var actor_records: Array[Dictionary] = []
	var render_from: int = 0
	var render_npc: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--render-from="): render_from = int(arg.trim_prefix("--render-from="))
		if arg.begins_with("--render-npc="): render_npc = arg.trim_prefix("--render-npc=")
	check(render_from >= 0 and render_from < payload.records.size(), "explicit GPU batch begins at a registered identity")
	for i: int in range(render_from, payload.records.size()):
		var record: Dictionary = payload.records[i]
		if not CATALOG.reviewed_record_allowed(record): continue
		if not render_npc.is_empty() and str(record.source_npc_id) != render_npc: continue
		var profile = ANIMATIONS.for_record("monster", record)
		check(profile.profile_id == "monster:" + str(record.sourceId), "stable animation ID")
		var frames: SpriteFrames = ANIMATIONS.frames_for_profile(profile, "")
		check(frames != null, "real source frames loaded")
		check(int(record.hp) == int(record.source_raw_fields.hp), "source HP retained")
		check(int(record.lv) == int(record.source_raw_fields.lvl), "source level retained")
		check(not bool(record.source_animation.anchor_is_foot), "unknown foot remains unknown")
		for role: String in ROLES:
			for facing: int in range(8):
				var key: String = role + "_" + str(facing)
				check(frames.has_animation(key), "explicit track " + key)
				check(frames.get_frame_count(key) == record.source_animation.tracks[key].frames.size(), "source sequence length " + key)
				check(frames.get_frame_texture(key, 0) != null, "visible source " + key)
		var actor: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
		arena.add_child(actor)
		actor.setup(record, player, arena, ART.texture_for(record))
		actor.set_physics_process(false)
		check(actor.motion.frame_source == frames, "actual Monster uses reviewed source")
		for role: String in ROLES:
			for facing: int in range(8):
				var key: String = role + "_" + str(facing)
				var count: int = frames.get_frame_count(key)
				var sampled: Dictionary = {}
				var source_poses: Dictionary = {}
				for pose: Dictionary in record.source_animation.tracks[key].frames:
					source_poses[str(pose.blob_sha256) + ":" + str(pose.frame_index)] = true
				for phase: float in [0.0, 0.5, 0.999]:
					actor.motion.state = role
					actor.motion.facing8 = facing
					actor.motion.active = role == "attack"
					actor.motion.dead = role == "death"
					actor.motion.move_ratio = 1.0 if role in ["walk", "run"] else 0.0
					actor.motion.gait = phase * (count - 0.001)
					actor.motion.state_clock = phase * (count - 0.001) / 8.0
					actor.motion.visual_progress = phase
					actor.motion.attack_duration = 0.8
					actor.motion.attack_elapsed = phase * 0.8
					actor.motion.death_clock = phase * actor.motion.profile.death_duration
					actor.motion.hit_clock = (1.0 - phase) * actor.motion.hit_duration if role == "hit" else 0.0
					actor.motion.apply(actor.sprite, actor.animation_base_scale)
					check(actor.motion._resolved_key == key, "time samples keep exact role/facing")
					sampled[actor.sprite.texture.get_instance_id()] = true
				check(source_poses.size() <= 1 or sampled.size() > 1, "source animation advances unless source repeats one pose: " + record.name + " " + key)
		actors.append(actor)
		actor_records.append(record)
	# Render each facing and role through the production Monster/ActorMotion.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var columns: int = 5 if render_from > 0 else 9
	root.size = Vector2i(columns * 360, 200 + ceili(float(actors.size()) / columns) * 290)
	var focused_position: Vector2 = Vector2.ZERO
	if not render_npc.is_empty():
		check(actors.size() == 1, "focused QA selects exactly one active identity")
		if actors.size() != 1: quit(1); return
		var bounds: Array = actor_records[0].source_animation.canvas_original_grid
		var gain: float = maxf(1.0, actors[0].motion.profile.pixel_scale)
		root.size = Vector2i(ceili((float(bounds[2]) - float(bounds[0])) * gain) + 200, ceili((float(bounds[3]) - float(bounds[1])) * gain) + 200)
		focused_position = Vector2(100.0 - float(bounds[0]) * gain, 100.0 - float(bounds[1]) * gain)
		actors[0].name_label.hide()
		actors[0].hp_bar.hide()
	var capture_dir: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): capture_dir = arg.trim_prefix("--captures=")
	for facing: int in range(8):
		if "--focus-once" in OS.get_cmdline_user_args() and facing != 2: continue
		for column: int in range(ROLES.size()):
			if "--focus-once" in OS.get_cmdline_user_args() and ROLES[column] != "idle": continue
			for row: int in range(actors.size()):
				var actor: TwilightMonster = actors[row]
				actor.position = Vector2(180 + (row % columns) * 360, 200 + (row / columns) * 290)
				if not render_npc.is_empty(): actor.position = focused_position
				actor.motion.state = ROLES[column]
				actor.motion.active = ROLES[column] == "attack"
				actor.motion.visual_progress = 0.5
				actor.motion.state_clock = 0.2
				actor.motion.facing8 = facing
				actor.motion.facing4 = 0
				actor.motion.dead = ROLES[column] == "death"
				actor.motion.death_clock = 0.15
				actor.motion.hit_clock = 0.08 if ROLES[column] == "hit" else 0.0
				actor.motion.attack_elapsed = 0.18
				actor.motion.attack_duration = 0.8
				actor.motion.apply(actor.sprite, actor.animation_base_scale)
				check(actor.motion._resolved_key == ROLES[column] + "_" + str(facing), "production role/facing selection")
				check(actor.sprite.texture != null and not actor.sprite.flip_h, "source pose without mirrored substitute")
			await process_frame
			if not capture_dir.is_empty():
				await RenderingServer.frame_post_draw
				var frame: Image = root.get_texture().get_image()
				check(frame != null and frame.get_width() == root.size.x, "GPU viewport readback")
				for actor: TwilightMonster in actors:
					var source: Image = TexturePixels.image_of(actor.sprite.texture)
					if source.get_used_rect().size == Vector2i.ZERO:
						var texture: AtlasTexture = actor.sprite.texture as AtlasTexture
						var legacy_index: int = int(texture.region.position.y / texture.region.size.y) * 16 + int(texture.region.position.x / texture.region.size.x)
						var index: int = int(texture.get_meta("source_frame_index", legacy_index))
						var record: Dictionary = actor_records[actors.find(actor)]
						var documented: Array = record.source_animation.get("transparent_atlas_frames", [])
						check(documented.any(func(value: Variant) -> bool: return int(value) == index), "only documented source-empty poses may be transparent: " + actor.monster_name + " frame " + str(index))
						continue
					var colors: Dictionary = {}
					for y: int in range(source.get_height()):
						for x: int in range(source.get_width()):
							var color: Color = source.get_pixel(x, y)
							if color.a > 0.99 and color.r + color.g + color.b > 0.15:
								colors[color.to_rgba32()] = true
					var matches: Dictionary = {}
					# Flying/large models need their actual transformed visible bounds,
					# rather than a humanoid-sized rectangle around the ground origin.
					var local_body: Rect2 = Rect2(source.get_used_rect())
					local_body.position -= Vector2(source.get_size()) * 0.5
					var body: Rect2 = actor.sprite.get_global_transform() * local_body
					for y: int in range(maxi(0, floori(body.position.y)), mini(frame.get_height(), ceili(body.end.y))):
						for x: int in range(maxi(0, floori(body.position.x)), mini(frame.get_width(), ceili(body.end.x))):
							var pixel: Color = frame.get_pixel(x, y)
							var color: int = pixel.to_rgba32()
							# Hit intentionally uses the existing production red flash.
							var hit_color: bool = ROLES[column] == "hit" and maxf(pixel.r, maxf(pixel.g, pixel.b)) - minf(pixel.r, minf(pixel.g, pixel.b)) > 0.1
							if colors.has(color) or hit_color: matches[color] = true
					check(matches.size() >= 3, "actual source colors visible in GPU readback: " + actor.monster_name + " " + ROLES[column] + " facing " + str(facing))
				check(frame.save_png(capture_dir.path_join("facing_%d_role_%s.png" % [facing, ROLES[column]])) == OK, "capture saved")
	print("REVIEWED_SOURCE_MONSTERS checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
