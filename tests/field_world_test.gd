extends SceneTree

const COORD = preload("res://scripts/maps/world_coordinates.gd")
var failures: Array[String] = []
var checks: int = 0
var world: TwilightWorld

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FIELD FAIL: " + message)

func _run() -> void:
	var started: int = Time.get_ticks_msec()
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await physics_frame
	await process_frame
	world._set_map("aden_world",false)
	world.save_timer = -10000
	await physics_frame
	await physics_frame
	print("FIELD load_ms=",Time.get_ticks_msec()-started)
	var field: PlayableField = world.field_map
	check(field != null and field.bounds.size == Vector2(12288,8192),"map load and actual field extent")
	check(world.maps.size()==25,"preserve 25 existing map IDs")
	check(field.walkable(world.player.global_position) and field.point_clear(world.player.global_position),"player spawn has body clearance")
	check(world.player.global_position.distance_to(Vector2(2420,4100))<40,"authored player spawn")
	check(field.is_safe(Vector2(1600,4100)),"town safe zone")
	check(not field.is_safe(Vector2(3400,4400)),"meadow combat zone")
	check(not field.walkable(Vector2(-10,400)) and not field.walkable(Vector2(60000,400)),"out of bounds rejects")
	check(field.path(Vector2(-100,0),Vector2(2420,4100)).is_empty(),"invalid path start is safe")
	# Collision shapes are the exact same source as the navigational exclusions.
	for shape: Dictionary in field.blockers:
		var point: Vector2 = shape["box"].get_center()
		if str(shape["shape"]) != "polygon":
			check(not field.point_clear(point,0),"collision footprint: "+str(shape["kind"]))
	check(world.field_physics.get_child_count() == field.blockers.size(),"all authored blockers have physics shapes")
	check(field.path(world.player.global_position,Vector2(8150,3460)).size()>2,"navigation reaches ruins across river")
	var crossings: int = 0
	for bridge: Dictionary in field.data["bridges"]:
		var a: Array = bridge["rect"]
		var center := Vector2(float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5)
		var route: PackedVector2Array = field.path(center-Vector2(700,0),center+Vector2(700,0))
		check(route.size()>1,"bridge navigation exists")
		for i: int in range(route.size()-1):
			check(field.line_clear(route[i],route[i+1]),"route does not cut corners or cross water")
		crossings += 1
	check(crossings==2,"two authored crossings")
	# Actual physics query detects river and building, and leaves bridge open.
	var ray := PhysicsRayQueryParameters2D.create(Vector2(5200,4300),Vector2(7000,4300),4)
	check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"river physics ray collision")
	var house: Dictionary = field.blockers.filter(func(s: Dictionary)->bool: return str(s["kind"])=="building")[0]
	var rect: Rect2 = house["box"]
	ray = PhysicsRayQueryParameters2D.create(rect.get_center()+Vector2(0,300),rect.get_center(),4)
	check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"building physics collision")
	# Eight combinations exercise Camera2D zoom, motion, viewport resize and stretch.
	for viewport_size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540),Vector2i(1560,720)]:
		root.size = viewport_size
		for zoom_value: float in [.65,1.1]:
			world.player.camera.zoom = Vector2.ONE*zoom_value
			world.player.global_position = Vector2(3550,5150)
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			await process_frame
			var target := Vector2(3670,5160)
			var screen: Vector2 = COORD.world_to_screen(root,target)
			check(COORD.screen_to_world(root,screen).distance_to(target)<.02,"screen/world coordinate round trip")
			var touch := InputEventScreenTouch.new()
			touch.position = screen
			touch.pressed = true
			world._unhandled_input(touch)
			check(not world.player.click_path.is_empty() and world.player.click_path[-1].distance_to(target)<1,"Android touch destination after zoom")
			world.player.clear_click_path()
	root.size = Vector2i(1280,720)
	world.player.camera.zoom = Vector2.ONE*.78
	var mini_area := Rect2(9,27,204,136)
	for p: Vector2 in [field.bounds.position,field.bounds.end,Vector2(5147.25,6773.5)]:
		check(COORD.minimap_to_world(COORD.world_to_minimap(p,field.bounds,mini_area),field.bounds,mini_area).distance_to(p)<.01,"minimap world round trip")
	var random := RandomNumberGenerator.new()
	random.seed = 441
	for region: Dictionary in field.data["monster_spawn"]:
		check(not field.spawn_cells[str(region["id"])].is_empty(),"nonempty spawn region")
		for i: int in range(24):
			var p: Vector2 = field.sample_spawn(str(region["id"]),random)
			check(field.walkable(p) and field.point_clear(p) and not field.is_safe(p),"spawn validity: "+str(region["id"]))
	var eager_count: int = 0
	for region: Dictionary in field.data.monster_spawn:
		if str(region.get("mode","normal"))!="dense": eager_count += int(region.max_count)
	check(world.monsters_root.get_child_count()==eager_count,"ordinary population; distant dense slots dormant")
	var respawn_slot: Dictionary = world.field_population.slots[0]
	var original_monster: TwilightMonster = respawn_slot["monster"]
	var original_id: int = original_monster.get_instance_id()
	original_monster.take_damage(999999)
	check(world.monsters_root.get_child_count()==eager_count-1,"death reduces population until respawn timer")
	check(float(respawn_slot["remaining"])>0,"authored respawn delay")
	world.field_population._process(float(respawn_slot["remaining"])+.01)
	check(world.monsters_root.get_child_count()==eager_count,"delayed respawn restores region cap")
	check((respawn_slot["monster"] as Node).get_instance_id()!=original_id,"new spawn belongs to released slot")
	for monster: TwilightMonster in world.monsters_root.get_children():
		monster.set_physics_process(false)
	world.field_population.set_process(false)
	# Real movement over physics ticks, not just a path-array assertion.
	world.player.global_position = Vector2(3580,3640)
	var destination := Vector2(3770,3560)
	world._set_click_destination(destination)
	for i: int in range(160):
		await physics_frame
	check(world.player.global_position.distance_to(destination)<12,"player follows click path during physics")
	world.player.global_position = Vector2(3580,3640)
	world.player.set_touch_vector(Vector2.RIGHT)
	for i: int in range(24):
		await physics_frame
	world.player.set_touch_vector(Vector2.ZERO)
	check(world.player.global_position.x>3605,"joystick movement remains functional")
	# Pushing directly into water is stopped by physics even without pathfinding.
	world.player.global_position = Vector2(5490,4300)
	world.player.set_touch_vector(Vector2.RIGHT)
	for i: int in range(130):
		await physics_frame
	world.player.set_touch_vector(Vector2.ZERO)
	check(world.player.global_position.x<5850,"manual movement cannot pass through river")
	# Auto hunt must approach a target and apply existing combat/XP/drop callbacks.
	world._clear_monsters()
	var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(monster)
	monster.global_position = Vector2(3870,3640)
	monster.setup({"name":"아덴 경로 검사","lv":1,"hp":30,"atk":1},world.player,world,null)
	monster.collision_mask = 4
	monster.set_physics_process(false)
	monster.died.connect(world._on_monster_died)
	world.player.global_position = Vector2(3580,3640)
	world.player.clear_click_path()
	world.player.set_auto_enabled(true)
	var old_experience: int = world.experience
	for i: int in range(360):
		await physics_frame
		if not is_instance_valid(monster):
			break
	check(world.player.global_position.x>3700,"auto hunt moves toward target")
	check(world.experience>old_experience,"auto hunt attacks and awards experience")
	world.player.set_auto_enabled(false)
	# Local teleports update camera without re-seeding the current population.
	check(world.use_field_portal("town_waystone"),"local teleport accepted")
	check(world.player.global_position.distance_to(Vector2(8120,3490))<45,"teleport landing")
	check(field.walkable(world.player.global_position),"teleport landing clear")
	check(world.player.click_path.is_empty(),"teleport clears stale path")
	check(world.use_field_portal("oman_gate"),"inter-map portal accepted")
	check(world.active_map_id=="oman_01" and world.field_map!=null,"expanded playable tower loads")
	check(world.field_minimap.bounds.size==world.world_size,"minimap refreshes after transition")
	check(world.player.collision_mask==4,"tower field collision configuration")
	check(world.use_field_portal("aden_return"),"tower has an authored usable return portal")
	check(world.active_map_id=="aden_world" and world.field_map!=null,"portal returns to Aden")
	check(world.monsters_root.get_child_count()==eager_count,"fresh map population after return")
	check(world.field_renderer.visible_props<1000,"streaming limits instantiated props")
	check(world.field_renderer.chunks.size()<25,"streaming limits active chunks")
	# Large foreground foliage must fade while the actor is behind its canopy.
	var occluder: Sprite2D = null
	for candidate: Sprite2D in world.field_renderer.faded:
		if str(candidate.get_meta("prop_kind","")) in ["oak","oak2","pine","birch"]:
			occluder = candidate
			break
	check(occluder != null,"streamed region includes foreground canopy")
	if occluder != null:
		var restore_position: Vector2 = world.player.global_position
		world.player.global_position = occluder.position+Vector2(0,-95)
		world.field_renderer._process(.2)
		check(occluder.modulate.a<.8,"foreground fades over player")
		world.player.global_position = restore_position
	# Current layout saves round-trip; old overview coordinates migrate to spawn.
	world._save_game(true)
	var saved_position: Vector2 = world.player.global_position
	world.player.global_position = world._spawn_position()
	world._load_game(true)
	check(world.player.global_position.distance_to(saved_position)<1,"save/load preserves field position")
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.SAVE_PATH))
	old_save.erase("map_layout_revision")
	old_save["position"] = [5000,5000]
	var save_file: FileAccess = FileAccess.open(world.SAVE_PATH,FileAccess.WRITE)
	save_file.store_string(JSON.stringify(old_save))
	save_file.close()
	world._load_game(true)
	check(world.player.global_position.distance_to(world._spawn_position())<1,"legacy overview save relocates to safe field spawn")
	print("FIELD checks=",checks," visible_props=",world.field_renderer.visible_props," chunks=",world.field_renderer.chunks.size())
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("FIELD_WORLD_OK")
		quit(0)
	else:
		print("FIELD_WORLD_FAILED: ",failures.size())
		quit(1)
