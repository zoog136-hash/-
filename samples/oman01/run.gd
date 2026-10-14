extends SceneTree
## Runs the existing Main.tscn, combat, NPC and inventory systems in an isolated copy.
## All changes to player stats/spawns below are local test setup, not production balance.
var world: TwilightWorld
var failures: Array[String] = []
var checks: Array[String] = []
var capture_mode: bool = false
var evidence_dir: String = "res://samples/oman01/evidence/"

func _initialize() -> void:
	capture_mode = "--sample-capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame

func check(condition: bool,label: String) -> void:
	checks.append(label)
	if not condition:
		failures.append(label)
		printerr("OMAN_SAMPLE_FAIL "+label)

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	await frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image!=null and image.save_png(evidence_dir+name+".png")==OK,"capture "+name)

func run() -> void:
	if not FileAccess.file_exists(evidence_dir+"source_validation.json"):
		printerr("OMAN_SAMPLE_BLOCKED: run build_sample.py with the exact uploaded a3.zip first. No substitute scene was generated.")
		quit(2)
		return
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(4)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.level = 100
	world.max_hp = 1000000
	world.hp = world.max_hp
	world.rng.seed = 10120261014
	world._on_map_selected("l1_101")
	await frames(4)
	world.hud._close_workspace()
	check(world.active_map_id=="l1_101" and world.field_map is OriginalPlayableField,"existing game enters exact A3 map")
	if not world.field_map is OriginalPlayableField:
		finish()
		return
	var field: OriginalPlayableField = world.field_map
	check(str(field.definition.source_sha256)=="5e0ea64c017c6d09a8df12d4e7aa267f48a4eb150f10cd6429a199d6625e1aca","source hash contract")
	field.data.short_name = "오만 1층 · 리메이크 샘플"
	var source_position: Array = field.definition.sample_encounter_source
	var encounter := Vector2(float(source_position[0]),float(source_position[1]))
	var p: Vector2 = field.coordinates.to_world(encounter)
	field.data.monster_spawn.push_front({"id":"sample_zenith","boss_id":"sample_zenith","mode":"boss","max_count":1,
		"monster_types":["왜곡의 제니스 퀸"],"source_rect":Rect2i(Vector2i(encounter)-Vector2i(6,6),Vector2i(13,13)),
		"rect":[p.x-300,p.y-180,600,360],"respawn_time":180.0,"roaming_radius":100.0,
		"provenance":"LOCAL_SAMPLE_NOT_A3_INACTIVE_CLONE_OR_LIVE_M_SCHEDULE"})
	world.field_population.configure(world,null)
	world._clear_monsters()
	world.field_population.configure(world,field)
	world.portal_cooldown = 1000.0
	var banner := CanvasLayer.new()
	banner.layer = 100
	root.add_child(banner)
	var label := Label.new()
	label.text = "A3 101 · 2D 샘플 / 시각·스폰은 임시 / 리니지M 동일 판본 미확정"
	label.position = Vector2(320,8)
	label.add_theme_font_size_override("font_size",15)
	label.modulate = Color(0.95,0.83,0.56)
	banner.add_child(label)
	if not capture_mode:
		world.hud.show_message("오만 1층 샘플: 기존 게임 조작 사용. 별도 샘플 저장 폴더입니다.")
		return
	await shot("01-entry")
	var start: Vector2 = world.player.global_position
	var cell: Vector2i = field.world_to_cell(start)
	var target: Vector2 = start
	for offset: Vector2i in field.DIRECTIONS:
		var candidate: Vector2 = field.cell_to_world(cell+offset*4)
		if field.line_clear(start,candidate):
			target = candidate
			break
	check(target!=start,"connected movement destination")
	world._set_click_destination(target)
	await frames(120)
	check(world.player.global_position.distance_to(target)<16,"actual character follows click route")
	var blocked: bool = false
	for dy: int in range(-16,17):
		for dx: int in range(-16,17):
			var c: Vector2i = cell+Vector2i(dx,dy)
			if field.value_at(c,true)==0:
				continue
			for direction: int in range(8):
				if field.can_step(c,direction):
					continue
				var a: Vector2 = field.cell_to_world(c)
				var b: Vector2 = field.cell_to_world(c+field.DIRECTIONS[direction])
				world.player.clear_click_path()
				world.player.global_position = a
				world.player.velocity = (b-a)*60.0
				world.player._move_on_map()
				blocked = world.player.global_position.distance_to(a)<0.01
				break
			if blocked:
				break
		if blocked:
			break
	check(blocked,"actual source movement guard rejects closed edge")
	world.player.velocity = Vector2.ZERO
	world.player.global_position = p
	world.player.clear_click_path()
	await frames(30)
	var boss: TwilightMonster = null
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.id)=="sample_zenith" and is_instance_valid(slot.monster):
			boss = slot.monster
			break
	check(boss!=null,"existing Zenith Queen combat record spawns")
	if boss!=null:
		world._select_monster(boss)
		await shot("02-boss")
		var before: int = boss.hp
		world.player.set_auto_enabled(true)
		world.auto_target = boss
		world.selected_monster = boss
		await frames(360)
		check(not is_instance_valid(boss) or boss.dead or boss.hp<before,"existing AUTO causes boss damage")
		await shot("03-combat")
		world.player.set_auto_enabled(false)
	world.field_renderer.set_visual_mode("collision")
	await shot("04-collision")
	check(world.field_renderer.chunks.size()<=9 and field.nav_cache.size()<=64,"bounded visible and navigation chunks")
	finish()

func finish() -> void:
	var result: Dictionary = {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),
		"game_scene":"Main.tscn","edition":"A3 PC topology with TWILIGHT sample art and spawn overrides",
		"status":"PASS" if failures.is_empty() else "FAIL","android_tested":false,"main_merged":false}
	var file: FileAccess = FileAccess.open(evidence_dir+"runtime_results.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(result,"\t"))
		file.close()
	print("OMAN_SAMPLE_RESULTS "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
