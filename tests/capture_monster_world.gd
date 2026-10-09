extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const OUTPUT = "user://monster-world-review"
var world: TwilightWorld
var failed: bool = false
var report: Dictionary = {"renderer":"","adapter":"","maps":[],"dense":[],"bosses":[],"gallery":[]}

func _initialize() -> void: call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value: failed = true; push_error(message)

func pause_actors() -> void:
	world.field_population.set_process(false)
	for mob: TwilightMonster in world.monsters_root.get_children(): mob.set_physics_process(false)

func land_near(mob: TwilightMonster) -> void:
	for i: int in range(8):
		var p: Vector2 = mob.global_position+Vector2.from_angle(float(i)*PI/4.)*170.
		if world.field_map.walkable(p) and world.field_map.point_clear(p) and not world.field_map.is_safe(p) and world.field_map.line_clear(p,mob.global_position):
			world.player.global_position = p
			break
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()

func capture(name_value: String, boss: TwilightMonster = null) -> void:
	# AUTO can level up and defer the existing character workspace. Close it
	# before and after the frame so the capture actually shows the battlefield.
	world.hud._hide_aux_panels()
	await process_frame
	world.hud._hide_aux_panels()
	var workspace: Control = world.hud.get("workspace") as Control
	check(not is_instance_valid(workspace) or not workspace.visible,"unobstructed capture "+name_value)
	if is_instance_valid(boss):
		var screen_point: Vector2 = boss.get_global_transform_with_canvas()*Vector2(0,-boss.visual_height*.5)
		check(root.get_visible_rect().has_point(screen_point),"boss body on screen "+name_value)
		check(world.field_population.boss_hud.panel.visible,"boss HP panel visible "+name_value)
		check(world.field_population.boss_hud.title.text.contains(boss.monster_name),"boss HP name matches "+name_value)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image!=null and not image.is_empty(),"render buffer "+name_value)
	if image!=null: check(image.save_png(OUTPUT+"/"+name_value+".png")==OK,"save capture "+name_value)

func _run() -> void:
	check(DisplayServer.get_name()!="headless","actual OpenGL display required")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world),"class confirmation")
	world.save_timer = -10000
	world.hp = 999999
	world.mp = 999999
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	check(report.renderer=="gl_compatibility","Compatibility renderer")
	for id: String in world.maps_by_id:
		world._set_map(id,false)
		pause_actors()
		var mob: TwilightMonster = world.monsters_root.get_child(0)
		land_near(mob)
		mob.motion.face(world.player.global_position-mob.global_position)
		mob.motion.advance(.1,Vector2.RIGHT*mob.move_speed)
		mob.motion.apply(mob.sprite,mob.animation_base_scale)
		if is_instance_valid(mob.species_visual): mob.species_visual.update_pose()
		await capture("map-"+id)
		report.maps.append({"map":id,"species":mob.monster_name,"position":[mob.global_position.x,mob.global_position.y],"population":world.monsters_root.get_child_count()})
		print("MONSTER_MAP_RENDER "+id)
	for id: String in ["aden_world","oman_03","oman_07","oman_10"]:
		world._set_map(id,false)
		pause_actors()
		var region: Dictionary = {}
		for value: Dictionary in world.field_map.data.monster_spawn:
			if str(value.get("mode",""))=="dense": region = value; break
		var a: Array = region.rect
		var center := Vector2(float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5)
		world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(center))
		world.field_population._process(.5)
		pause_actors()
		var members: Array[TwilightMonster] = []
		for slot: Dictionary in world.field_population.slots:
			if str(slot.region.id)==str(region.id) and is_instance_valid(slot.monster): members.append(slot.monster)
		check(members.size()==24,"dense population "+id)
		world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
		world.field_renderer.refresh_visible()
		await capture("dense-"+id)
		# Controlled HP/AC isolates actual AUTO acquisition, navigation, attacks,
		# corpse pooling, ground-loot generation and repeated dense spawning.
		var kills: Array[int] = [0]
		for mob: TwilightMonster in members:
			mob.hp = 30; mob.max_hp = 30; mob.hp_bar.max_value = 30; mob.hp_bar.value = 30
			mob.armor_class = 0; mob.set_physics_process(true)
			mob.died.connect(func(_m: TwilightMonster) -> void: kills[0]+=1)
		world.hp = 999999
		world.str_stat = 200
		world.dex_stat = 200
		world.attack_power = 200
		world.player.set_auto_enabled(true)
		for frame: int in range(360): await physics_frame
		world.player.set_auto_enabled(false)
		world.player.clear_click_path()
		check(kills[0]>0,"actual AUTO dense kills "+id)
		world.field_population._process(float(region.respawn_time)+.5)
		pause_actors()
		var restored: int = 0
		for slot: Dictionary in world.field_population.slots:
			if str(slot.region.id)==str(region.id) and is_instance_valid(slot.monster): restored += 1
		check(restored==24,"dense cap restored "+id)
		report.dense.append({"map":id,"max":24,"auto_kills":kills[0],"restored":restored,"controlled_hp":30})
		await capture("dense-auto-"+id)
	for floor: int in range(1,11):
		var id: String = "oman_%02d" % floor
		world._set_map(id,false); pause_actors()
		world.hp = world._effective_max_hp()
		var boss: TwilightMonster
		for slot: Dictionary in world.field_population.slots:
			if str(slot.region.get("mode",""))=="boss": boss = slot.monster; break
		check(is_instance_valid(boss),"boss spawned "+id)
		land_near(boss)
		boss._begin_special()
		boss.motion.advance(.42,Vector2.ZERO)
		boss.motion.apply(boss.sprite,boss.animation_base_scale)
		boss.species_visual.warning_progress = .45
		boss.species_visual.update_pose()
		await capture("boss-"+id,boss)
		var hits: Array[int] = [0]
		boss.player_hit.connect(func(_b: TwilightMonster,_d: int,_k: String) -> void: hits[0]+=1)
		boss.motion.advance(.7,Vector2.ZERO)
		for frame: int in range(40): await physics_frame
		report.bosses.append({"map":id,"name":boss.monster_name,"pattern":boss.ai.special.kind,"skill_hits":hits[0],"on_screen":true,"overlay_closed":true,"hud_name":world.field_population.boss_hud.title.text})
	# Render every catalog entry, including DB-only species, inside a clearly
	# labelled inspection gallery. This is art QA, separate from map screenshots.
	world._set_map("aden_world",false); pause_actors()
	world.field_population.configure(world,null)
	world._clear_monsters()
	world.field_renderer.hide()
	world.hud.hide()
	world.field_minimap.hide()
	world.player.hide()
	world.player.camera.enabled = false
	root.canvas_transform = Transform2D.IDENTITY
	var page_size: int = 28
	for start: int in range(0,world.monster_db.size(),page_size):
		var actors: Array[TwilightMonster] = []
		for index: int in range(start,mini(start+page_size,world.monster_db.size())):
			var record: Dictionary = world.monster_db[index]
			var mob: TwilightMonster = world.MONSTER_SCENE.instantiate()
			world.monsters_root.add_child(mob)
			var local_index: int = index-start
			mob.global_position = Vector2(92.+float(local_index%7)*180.,164.+float(local_index/7)*152.)
			mob.setup(record,world.player,world,world._monster_texture(record))
			mob.set_physics_process(false)
			mob.name_label.add_theme_font_size_override("font_size",13)
			mob.hp_bar.hide()
			actors.append(mob)
		for state: String in ["idle","walk","attack","hit","death"]:
			for index: int in range(actors.size()):
				var mob: TwilightMonster = actors[index]
				var aim := Vector2.from_angle(float(index%8)*PI/4.)
				if state=="walk": mob.motion.advance(.15,aim*mob.move_speed)
				elif state=="attack":
					mob.motion.begin_attack(.65,aim,mob.motion.profile.motion_style)
					mob.motion.advance(.18,Vector2.ZERO)
				elif state=="hit": mob.motion.cancel_attack(); mob.motion.react(); mob.motion.advance(.02,Vector2.ZERO)
				elif state=="death": mob.dead = true; mob.motion.die(); mob.motion.advance(.25,Vector2.ZERO)
				mob.motion.apply(mob.sprite,mob.animation_base_scale)
				if is_instance_valid(mob.species_visual): mob.species_visual.update_pose()
			await capture("catalog-%02d-%s" % [start/page_size+1,state])
		report.gallery.append({"first":start,"count":actors.size(),"states":["idle","walk","attack","hit","death"]})
		world._clear_monsters()
		await process_frame
	var file: FileAccess = FileAccess.open(OUTPUT+"/render-summary.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	world.queue_free()
	await process_frame
	print("MONSTER_WORLD_RENDER_OK" if not failed else "MONSTER_WORLD_RENDER_FAILED")
	quit(1 if failed else 0)
