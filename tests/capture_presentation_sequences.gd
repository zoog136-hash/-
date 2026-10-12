extends SceneTree

## Deterministic 30 Hz pose film through the production actors. The ground
## anchors stay fixed for inspecting feet/root motion; Main.tscn captures
## separately exercise actual world movement and AI.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MONSTERS = preload("res://scripts/monsters/monster_catalog.gd")
const ART = preload("res://scripts/monsters/monster_art.gd")
const OUTPUT = "user://presentation-sequences"
const STEP: float = 1.0 / 30.0
var actors: Array[Node2D] = []
var styles: Array[String] = []
var weapons: Array[String] = []

class Arena extends Node:
	var field_map = null
	var field_population = null
	var combat_flights = null
	var combat_vfx = null
	var hp: int = 999999
	func is_player_concealed() -> bool: return false
	func _has_line_of_sight_world(_a: Vector2, _b: Vector2) -> bool: return true
	func show_combat_number(_p: Vector2, _v: String, _c: Color, _critical: bool = false) -> void: pass

class Ground extends Node2D:
	func _draw() -> void:
		for row: int in range(3):
			for col: int in range(4):
				var foot := Vector2(160 + col * 320, 255 + row * 215)
				draw_line(foot - Vector2(60, 0), foot + Vector2(60, 0), Color("637073"), 1.0)
				draw_line(foot - Vector2(0, 5), foot + Vector2(0, 5), Color("a5af9c"), 1.0)

func _initialize() -> void: call_deferred("_run")

func label_at(value: String, point: Vector2, size: int = 18) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_override("font", preload("res://assets/fonts/NotoSansKR.ttf"))
	label.add_theme_font_size_override("font_size", size)
	root.add_child(label)
	return label

func place(actor: Node2D, name_value: String, style: String, weapon: String) -> void:
	var index: int = actors.size()
	actor.position = Vector2(160 + (index % 4) * 320, 255 + (index / 4) * 215)
	actor.set_physics_process(false)
	actors.append(actor)
	styles.append(style)
	weapons.append(weapon)
	label_at(name_value, actor.position + Vector2(-135, -170), 16)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Pose film requires OpenGL")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var background := ColorRect.new()
	background.color = Color("202b30")
	background.size = Vector2(1280,720)
	root.add_child(background)
	root.add_child(Ground.new())
	label_at("TWILIGHT · 30fps sampled poses · fixed ground anchors / local timing", Vector2(20, 12), 22)
	var phase: Label = label_at("", Vector2(20, 45), 18)
	var arena := Arena.new()
	root.add_child(arena)
	var player: TwilightPlayer
	for index: int in range(4):
		player = load("res://scenes/Player.tscn").instantiate()
		root.add_child(player)
		player.camera.enabled = false
		player.set_class_index(index)
		place(player, ["기사 · 한손검", "마법사 · 시전", "궁수 · 활 발사", "암살자 · 단검"][index], ["slash", "magic", "bow", "thrust"][index], ["한손검", "지팡이", "활", "단검"][index])
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	for id: String in ["413", "267", "393", "104"]:
		var record: Dictionary = catalog["변신"].filter(func(r: Dictionary) -> bool: return str(r.sourceId) == id)[0]
		var actor: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
		root.add_child(actor)
		actor.camera.enabled = false
		var profile: TwilightAnimationProfile = CATALOG.for_record("transform", record, record.image_path)
		actor.set_transform_visual(record.image_path, 1.0, profile)
		place(actor, id + " · " + str(record.name), profile.motion_style, "")
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var records: Array = MONSTERS.expand(db["몬스터"])
	for body: String in ["wolf", "iron_golem", "spider", "ghost"]:
		var record: Dictionary = records.filter(func(r: Dictionary) -> bool: return r.visual.body == body)[0]
		var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
		root.add_child(mob)
		mob.setup(record, player, arena, ART.texture_for(record))
		place(mob, str(record.name) + " · " + body, mob.motion.profile.motion_style, "")
	for frame: int in range(180):
		var moving: bool = frame >= 30 and frame < 90
		var running: bool = frame >= 60 and frame < 90
		var direction: Vector2 = Vector2.RIGHT if frame < 60 else Vector2.LEFT
		phase.text = "%0.2fs · %s" % [float(frame) * STEP, "대기" if frame < 30 else "이동 → 방향 전환 / 빠른 이동" if frame < 90 else "정지 → 공격 / 빠른 연속 공격" if frame < 143 else "피격 → 사망"]
		for index: int in range(actors.size()):
			var actor: Node2D = actors[index]
			var motion: TwilightActorMotion = actor.motion
			if frame in [98, 120, 131]:
				motion.begin_attack(.72 if frame == 98 else .36, direction, styles[index], motion.profile.marker_for(styles[index]))
				# The same capture script also runs in the starting-main checkout.
				if "weapon_variant" in motion: motion.set("weapon_variant", weapons[index])
			if frame == 143: motion.react(true)
			if frame == 150:
				motion.die()
				if actor is TwilightMonster: actor.dead = true
			motion.advance(STEP, direction * (300.0 if running else 140.0) if moving else Vector2.ZERO)
			if actor is TwilightPlayer:
				var sprite: AnimatedSprite2D = actor.transform_sprite if actor.transform_active else actor.class_sprite
				motion.apply(sprite, sprite.get_meta("base_scale"))
			else:
				motion.apply(actor.sprite, actor.animation_base_scale)
				if actor.species_visual.has_method("tick"): actor.species_visual.tick(STEP)
				actor.species_visual.update_pose()
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels: Image = root.get_texture().get_image()
		assert(pixels != null and not pixels.is_empty())
		assert(pixels.save_png(OUTPUT + "/frame-%03d.png" % frame) == OK)
		if frame % 60 == 0: print("POSE_SEQUENCE_PROGRESS ", frame, "/180")
	FileAccess.open(OUTPUT + "/index.json", FileAccess.WRITE).store_string(JSON.stringify({"actors":12,"frames":180,"fps":30,"duration_seconds":6,"rendered":true,"renderer":RenderingServer.get_video_adapter_name(),"note":"Controlled fixed-anchor pose film; timings belong to TWILIGHT, not measured Lineage M. No claim of native eight-direction art."}, "\t"))
	for actor: Node2D in actors: actor.queue_free()
	arena.queue_free()
	await process_frame
	print("PRESENTATION_SEQUENCES_OK actors=12 frames=180")
	quit()
