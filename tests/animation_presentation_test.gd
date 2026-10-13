extends SceneTree

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MANIFEST = preload("res://scripts/animation/visual_manifest.gd")
const MONSTERS = preload("res://scripts/monsters/monster_catalog.gd")
const ART = preload("res://scripts/monsters/monster_art.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
var failures: Array[String] = []
var checks: int = 0
var released: Array[int] = []
var report: Dictionary = {"transforms":[], "monsters":[], "engine":Engine.get_version_info().string}

class Arena extends Node:
	var field_map = null
	var field_population = null
	var combat_flights = null
	var combat_vfx = null
	var hp: int = 999999
	func is_player_concealed() -> bool: return false
	func _has_line_of_sight_world(_a: Vector2, _b: Vector2) -> bool: return true
	func find_world_path(a: Vector2, b: Vector2) -> PackedVector2Array: return PackedVector2Array([a, b])
	func show_combat_number(_p: Vector2, _v: String, _c: Color, _critical: bool = false) -> void: pass

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("ANIMATION_PRESENTATION FAIL: " + text)

func _run() -> void:
	var actor: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.camera.enabled = false
	actor.attack_strike.connect(func(id: int) -> void: released.append(id))
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	actor.position = Vector2(127, 237)
	actor.auto_enabled = true
	var collider: Transform2D = actor.get_node("CollisionShape2D").transform
	for record: Dictionary in db["변신"]:
		var key: String = "transform:" + str(record.sourceId)
		var start_errors: int = failures.size()
		var profile: TwilightAnimationProfile = CATALOG.for_record("transform", record, record.image_path)
		actor.set_transform_visual(record.image_path, 1.0, profile)
		check(actor.transform_active, "loading " + key)
		var sprite: AnimatedSprite2D = actor.transform_sprite
		var scale_value: Vector2 = sprite.get_meta("base_scale")
		var roles: Dictionary = {}
		for role: String in ["idle", "walk", "run", "hit", "death"]:
			actor.motion.cancel_attack()
			actor.motion.dead = false
			actor.motion.hit_clock = 0.0
			if role == "death": actor.motion.die()
			for direction: int in range(8):
				if role == "hit": actor.motion.react(true, Vector2.RIGHT)
				actor.motion.face(Vector2.from_angle(direction * PI / 4.0))
				var speed: float = 300.0 if role == "run" else 100.0 if role == "walk" else 0.0
				actor.motion.advance(.025, actor.motion.direction * speed)
				actor.motion.apply(sprite, scale_value)
				check(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) != null, key + " " + role)
				check(sprite.transform.is_finite(), "finite pose " + key)
				if role == "hit": check(actor.motion._resolved_role == "hit", "hit frames in every facing " + key)
				if role == "idle": check(not sprite.flip_h or profile.layout == "still", "native facing not mirrored " + key)
			roles[role] = actor.motion._resolved_role
		actor.motion.dead = false
		actor.motion.death_clock = 0.0
		for duration: float in [.12, .72, 1.44]:
			for style: String in ["slash", "thrust", "heavy", "bow", "magic"]:
				released.clear()
				var marker: float = profile.marker_for(style)
				var id: int = actor.start_combat_attack(actor.position + Vector2.RIGHT * 50, duration, style, marker)
				actor.motion.advance(duration * marker * .98, Vector2.ZERO)
				check(released.is_empty(), "no early strike " + key)
				# A transformation swap must keep the exact outgoing attack clock.
				actor.clear_transform_visual()
				actor.set_transform_visual(record.image_path, 1.0, profile)
				actor.motion.advance(duration * marker * .03, Vector2.ZERO)
				actor.motion.apply(sprite, scale_value)
				check(released == [id], "one release across swap " + key)
				check(sprite.frame == profile.attack_hit_frame, "visible hit frame " + key + style)
				roles[style] = actor.motion._resolved_role
				actor.motion.advance(duration * (maxf(.7, marker) - marker) + .001, Vector2.ZERO)
				actor.motion.apply(sprite, scale_value)
				check(actor.motion.active and actor.motion.state == "recovery", "recovery " + key)
				actor.motion.advance(duration, Vector2.ZERO)
				check(released == [id] and not actor.motion.active, "no duplicate strike " + key)
		check(actor.position == Vector2(127, 237) and actor.auto_enabled, "switch preserves movement/AUTO " + key)
		check(actor.get_node("CollisionShape2D").transform == collider, "collider " + key)
		actor.clear_transform_visual()
		check(actor.class_sprite.visible and not actor.transform_sprite.visible, "return to class " + key)
		var authored: Dictionary = MANIFEST.record(key)
		report.transforms.append({"id":key, "name":record.name, "body":profile.body_kind, "roles":roles,
			"resource":profile.frames_path, "origin":authored.get("animation_origin", "fallback"),
			"source_directions":authored.get("directions", 1), "source_still":int(authored.get("directions", 1)) == 1,
			"native_individual_art":false, "errors":failures.slice(start_errors)})
	# Actual transform identity already in the manifest: a native resource wins.
	var native: SpriteFrames = CATALOG.frames("res://assets/sprites/classes/warrior.png", "class5").duplicate(true)
	check(ResourceSaver.save(native, "user://native-animation.tres") == OK, "native fixture saved")
	var sample: Dictionary = db["변신"][0].duplicate(true)
	sample.animation_profile = {"frames_path":"user://native-animation.tres", "layout":"class5"}
	var specific: TwilightAnimationProfile = CATALOG.for_record("transform", sample, sample.image_path)
	check(CATALOG.frames_for_profile(specific, sample.image_path).has_animation("walk_down"), "specific native frames before generated catalog")
	sample.animation_profile.frames_path = "res://missing-native.tres"
	specific = CATALOG.for_record("transform", sample, sample.image_path)
	check(CATALOG.frames_for_profile(specific, sample.image_path).has_meta("twilight_visual_key"), "missing native falls back to catalog")
	var unknown: TwilightAnimationProfile = CATALOG.for_record("transform", {"sourceId":"new-future-id"}, db["변신"][0].image_path)
	check(unknown.body_kind == "humanoid" and CATALOG.first_texture(CATALOG.frames_for_profile(unknown, db["변신"][0].image_path)) != null, "future ID safe fallback")
	# Root motion eases at locomotion stop and has a true opposing windup.
	actor.motion.profile = PROFILE.new()
	actor.motion.advance(.2, Vector2.RIGHT * 210.0)
	actor.motion.advance(.01, Vector2.ZERO)
	check(actor.motion.locomotion_weight > 0.0 and actor.motion.locomotion_weight < 1.0, "bounded stop envelope")
	actor.motion.begin_attack(1.0, Vector2.RIGHT, "thrust", .44)
	actor.motion.advance(.25, Vector2.ZERO)
	actor.motion.apply(actor.class_sprite, Vector2.ONE)
	check(actor.class_sprite.position.x < 0.0, "opposing anticipation")
	actor.motion.advance(.19, Vector2.ZERO)
	actor.motion.apply(actor.class_sprite, Vector2.ONE)
	check(actor.class_sprite.position.x > 0.0, "forward strike")
	for i: int in range(100): actor.motion.react(true, Vector2.LEFT)
	actor.motion.apply(actor.class_sprite, Vector2.ONE)
	check(actor.class_sprite.position.distance_to(actor.motion.profile.sprite_offset) < 12.0, "hit envelope cannot accumulate")
	var arena := Arena.new()
	root.add_child(arena)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var records: Array = MONSTERS.expand(raw["몬스터"])
	for record: Dictionary in records:
		var start_errors: int = failures.size()
		var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
		root.add_child(mob)
		mob.setup(record, actor, arena, ART.texture_for(record))
		mob.set_physics_process(false)
		check(mob.sprite.texture != null, "monster resource " + record.name)
		var source: String = str(MANIFEST.monster_binding(record).get("path", ""))
		var reviewed: Dictionary = preload("res://scripts/animation/presentation_catalog.gd").data.monster_sources.get(source, {})
		if not reviewed.is_empty(): check(mob.motion.profile.body_kind == reviewed.body, "installed art body overrides fallback family " + record.name)
		var foot: Vector2 = mob.position
		var shape: Transform2D = mob.get_node("CollisionShape2D").transform
		var count: Array[int] = [0]
		mob.motion.strike.connect(func(_id: int) -> void: count[0] += 1)
		for direction: int in range(8):
			var aim: Vector2 = Vector2.from_angle(direction * PI / 4.0)
			mob.motion.advance(.1, aim * mob.move_speed)
			mob.motion.apply(mob.sprite, mob.animation_base_scale)
			mob.motion.begin_attack(.5, aim, mob.motion.profile.motion_style, mob.motion.profile.marker_for(mob.motion.profile.motion_style))
			mob.motion.advance(.51, Vector2.ZERO)
			mob.motion.react(direction % 2 == 0, -aim)
			mob.motion.apply(mob.sprite, mob.animation_base_scale)
			check(mob.sprite.transform.is_finite(), "monster finite pose " + record.name)
		check(count[0] == 8, "monster attack markers " + record.name)
		check(mob.position == foot and mob.get_node("CollisionShape2D").transform == shape, "monster visual-only " + record.name)
		mob.motion.die()
		# A native death can still be opaque at its final pose; inspect the
		# fade after the configured sequence, not a fixed legacy deadline.
		mob.motion.advance(maxf(.8, mob.motion.profile.death_duration + .1), Vector2.ZERO)
		mob.motion.apply(mob.sprite, mob.animation_base_scale)
		check(not mob.motion.active and mob.sprite.modulate.a < 1.0, "monster death " + record.name)
		report.monsters.append({"name":record.name,"boss":mob.is_boss,"body":mob.motion.profile.body_kind,
			"native_frames":mob.motion.frame_source != null,"atlas_cell":record.visual,
			"texture":mob.sprite.texture.resource_path,"texture_atlas":mob.sprite.texture.atlas.resource_path if mob.sprite.texture is AtlasTexture else "",
			"source_binding":MANIFEST.monster_binding(record),
			"special":record.get("ai", {}).get("special", {}),"errors":failures.slice(start_errors)})
		mob.free()
	report.failures = failures
	report.checks = checks
	FileAccess.open("user://animation-presentation-coverage.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	arena.queue_free()
	actor.queue_free()
	await process_frame
	print("ANIMATION_PRESENTATION_%s transforms=%d monsters=%d checks=%d" % ["OK" if failures.is_empty() else "FAILED", report.transforms.size(), report.monsters.size(), checks])
	quit(0 if failures.is_empty() else 1)
