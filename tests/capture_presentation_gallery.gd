extends SceneTree

## Actual OpenGL, production scenes and art in a controlled review arena.
## Main.tscn live gameplay is captured separately by capture_combat.gd.
const QA = preload("res://tests/boss_presentation_test.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
const ART = preload("res://scripts/monsters/monster_art.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
const OUTPUT = "user://presentation-gallery"
var caption: Label
var captures: int = 0
var film: Image
var rows: int = 0
var pages: int = 0
var index: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")

func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	assert(pixels != null and not pixels.is_empty())
	pixels.convert(Image.FORMAT_RGB8)
	captures += 1
	return pixels

func flush() -> void:
	if rows == 0: return
	assert(film.save_png(OUTPUT + "/boss-page-%02d.png" % pages) == OK)
	pages += 1
	rows = 0

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Presentation gallery requires OpenGL")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("202b30")
	background.size = Vector2(1280,720)
	root.add_child(background)
	var arena := QA.Arena.new()
	root.add_child(arena)
	arena.field_population = QA.Population.new()
	arena.add_child(arena.field_population)
	arena.combat_flights = preload("res://scripts/animation/combat_flights.gd").new()
	arena.add_child(arena.combat_flights)
	arena.combat_vfx = preload("res://scripts/animation/combat_vfx.gd").new()
	arena.add_child(arena.combat_vfx)
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.camera.enabled = false
	caption = Label.new()
	caption.position = Vector2(20,20)
	caption.add_theme_font_override("font", preload("res://assets/fonts/NotoSansKR.ttf"))
	caption.add_theme_font_size_override("font_size", 22)
	root.add_child(caption)
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var records: Array = CATALOG.expand(db["몬스터"])
	var seen: Dictionary = {}
	for record: Dictionary in records:
		if not LOOT.is_boss_record(record): continue
		var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
		root.add_child(mob)
		mob.setup(record, player, arena, ART.texture_for(record))
		mob.set_physics_process(false)
		mob.position = Vector2(460, 400)
		player.position = Vector2(610, 425)
		if rows == 0:
			film = Image.create(1280, 960, false, Image.FORMAT_RGB8)
			film.fill(Color("202b30"))
		var kind: String = str(mob.ai.get("special", {}).get("kind", "basic"))
		if kind == "charge":
			arena.field_map = QA.OpenGround.new()
			player.position = Vector2(310,425)
		for phase: int in range(3):
			caption.text = "%s · %s · %s / production scenes, controlled arena" % [record.name, kind, ["준비", "타격/발동", "사망"][phase]]
			if phase == 0:
				if kind == "basic": mob.motion.begin_attack(.7, player.position - mob.position, mob.motion.profile.motion_style, mob.motion.profile.marker_for(mob.motion.profile.motion_style))
				else: mob._begin_special()
				mob.motion.advance(mob.motion.attack_duration * mob.motion.attack_hit_ratio * .78, Vector2.ZERO)
				mob.species_visual.warning_progress = .78
			elif phase == 1:
				mob.motion.advance(mob.motion.attack_duration * mob.motion.attack_hit_ratio * .22 + .001, Vector2.ZERO)
			else:
				mob.motion.die()
				mob.dead = true
				mob.motion.advance(.28, Vector2.ZERO)
				mob.species_visual.tick(.28)
			mob.motion.apply(mob.sprite, mob.animation_base_scale)
			mob.species_visual.update_pose()
			arena.combat_flights.set_physics_process(false)
			var pixels: Image = await capture()
			# Keep one full-size example of each existing special, plus all-boss pages.
			if not seen.has(kind): assert(pixels.save_png(OUTPUT + "/" + kind + "-%d.png" % phase) == OK)
			pixels.resize(426,240,Image.INTERPOLATE_LANCZOS)
			film.blit_rect(pixels, Rect2i(0,0,426,240), Vector2i(phase * 426, rows * 240))
		index.append({"name":record.name,"kind":kind,"page":pages,"row":rows})
		seen[kind] = true
		rows += 1
		if rows == 4: flush()
		mob.free()
		arena.field_map = null
		arena.combat_flights.clear()
		arena.combat_vfx.clear()
	flush()
	# Real normal body families, walking/attacking/hit in a compact filmstrip.
	seen.clear()
	var examples: Array = []
	for record: Dictionary in records:
		if LOOT.is_boss_record(record): continue
		var body: String = record.visual.body
		if body in ["wolf","spider","iron_golem","skeleton","mage","orc","ghost","dragon"] and not seen.has(body):
			examples.append(record)
			seen[body] = true
	player.hide()
	caption.position = Vector2(440, 258)
	caption.add_theme_font_size_override("font_size", 14)
	var normal: Image = Image.create(1280, examples.size() * 240, false, Image.FORMAT_RGB8)
	for row: int in range(examples.size()):
		var record: Dictionary = examples[row]
		var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
		root.add_child(mob)
		mob.setup(record, player, arena, ART.texture_for(record))
		mob.set_physics_process(false)
		mob.position = Vector2(600,455)
		for phase: int in range(4):
			caption.text = "%s · %s" % [record.name,["대기","이동","공격","피격"][phase]]
			if phase == 1: mob.motion.advance(.18,Vector2.RIGHT * mob.move_speed)
			if phase == 2:
				mob.motion.begin_attack(.7,Vector2.RIGHT,mob.motion.profile.motion_style,mob.motion.profile.marker_for(mob.motion.profile.motion_style))
				mob.motion.advance(.7 * mob.motion.attack_hit_ratio,Vector2.ZERO)
			if phase == 3: mob.motion.react(true,Vector2.LEFT)
			mob.motion.apply(mob.sprite,mob.animation_base_scale)
			mob.species_visual.update_pose()
			var pixels: Image = await capture()
			normal.blit_rect(pixels,Rect2i(440,250,320,240),Vector2i(phase*320,row*240))
		mob.free()
	assert(normal.save_png(OUTPUT + "/normal-bodies.png") == OK)
	FileAccess.open(OUTPUT + "/index.json", FileAccess.WRITE).store_string(JSON.stringify({"bosses":index,"captures":captures,"pages":pages,"renderer":RenderingServer.get_video_adapter_name()},"\t"))
	player.queue_free()
	arena.queue_free()
	await process_frame
	print("PRESENTATION_GALLERY_OK bosses=%d captures=%d" % [index.size(),captures])
	quit()
