extends SceneTree
const FIELD = preload("res://scripts/maps/source_field.gd")
const TRAVEL = preload("res://scripts/maps/source_travel.gd")
var failures: Array[String] = []
var assertions: int = 0
var results: Array = []
var world: TwilightWorld
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message); printerr("ORIGINAL_WORLD_FAIL: "+message)
func frames(count: int) -> void:
	for i: int in range(count): await physics_frame
func _run() -> void:
	if not FileAccess.file_exists("res://data/original_maps/catalog.json"):
		print("ORIGINAL_WORLD_SKIP: private source pack not installed")
		quit(0); return
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(4)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.level = 100
	world.max_hp = 1000000
	world.hp = 1000000
	world.rng.seed = 10112862
	check(world.maps.size()==25,"legacy map IDs preserved")
	check(world.original_maps.size()==998,"all verified nonempty source maps registered")
	var priority: Array[int] = [4]
	for id: int in range(101,112): priority.append(id)
	for id: int in range(12852,12863): priority.append(id)
	for id: int in priority:
		world.player.set_auto_enabled(false)
		var start_ms: int = Time.get_ticks_msec()
		world._set_map("l1_%d" % id,false)
		await frames(2)
		world.portal_cooldown = 1000
		check(world.field_map is OriginalPlayableField,"original loader %d" % id)
		var field: OriginalPlayableField = world.field_map
		var start: Vector2 = world.player.global_position
		check(field.walkable(start),"valid spawn %d" % id)
		var cell: Vector2i = field.world_to_cell(start)
		check(field.cell_to_world(cell).distance_to(start)<0.01,"foot center alignment %d" % id)
		var goal: Vector2 = start
		for dir: Vector2i in field.DIRECTIONS:
			var candidate: Vector2 = field.cell_to_world(cell+dir*3)
			if field.line_clear(start,candidate): goal=candidate; break
		check(goal!=start,"reachable click target %d" % id)
		world._set_click_destination(goal)
		await frames(60)
		check(world.player.global_position.distance_to(goal)<16,"actual click movement %d" % id)
		world.player.clear_click_path()
		world.player.velocity = Vector2.ZERO
		world._save_game(true)
		var saved: Vector2 = world.player.global_position
		world.player.global_position = start
		world._load_game(true)
		check(world.player.global_position.distance_to(saved)<0.01,"source save roundtrip %d" % id)
		world.portal_cooldown=1000
		check(field.nav_cache.size()<=64,"bounded navigation %d" % id)
		check(world.field_renderer.chunks.size()<=9,"bounded draw chunks %d" % id)
		results.append({"map":id,"load_and_movement_ms":Time.get_ticks_msec()-start_ms,"save":world.player.global_position.distance_to(saved)<0.01,"original_art":false})
	# Exact source portal pair in the supplied dungeon table; no fabricated tower stairs.
	var links: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map-runtime-20261011/PORTAL_VALIDATION.json"))
	var tested_link: bool = false
	for link: Dictionary in links:
		if not link.source_valid or not link.target_valid or int(link.from_map)==int(link.to_map): continue
		var source: Vector2 = Vector2(float(link.source[0]),float(link.source[1]))
		if not TRAVEL.enter(world,"l1_%d" % int(link.from_map),source): continue
		for portal: Dictionary in world.field_map.data.portal:
			if str(portal.target_map)!="l1_%d" % int(link.to_map) or Vector2(float(portal.position[0]),float(portal.position[1])).distance_to(world.player.global_position)>1: continue
			tested_link=world.use_field_portal(str(portal.id))
			check(tested_link,"original exact portal transition")
			check((world.field_map as OriginalPlayableField).coordinates.to_source(world.player.global_position).distance_to(Vector2(float(link.target[0])+0.5,float(link.target[1])+0.5))<0.01,"original portal destination unchanged")
			break
		if tested_link: break
	check(tested_link,"at least one verified inter-map portal")
	for id: int in [101,12852]: await hunt(id)
	world._set_map("l1_4",false)
	var interacted: bool = false
	for npc: Dictionary in world.field_map.data.npc_spawn:
		if str(npc.role)!="shop": continue
		var p:=Vector2(float(npc.position[0]),float(npc.position[1]))
		var c: Vector2i=world.field_map.nearest_cell(p)
		if c.x<0: continue
		world.player.global_position=world.field_map.cell_to_world(c)
		world._set_click_destination(p)
		interacted=str(world.hud.active_section)=="shop"
		break
	check(interacted,"source NPC opens existing shop")
	world.hud._close_workspace()
	world._set_map("l1_101",false)
	check(world.return_from_original_map() and world.active_map_id=="l1_4","source return from tower to mainland")
	world._set_map("aden_world",false)
	check(world.field_population==world.legacy_population and world.field_map!=null,"legacy world restored")
	check(assertions>=199,"all gameplay scenarios executed without script abort")
	var report: Dictionary={"assertions":assertions,"failures":failures,"priority_maps":results,"renderer":RenderingServer.get_video_adapter_name()}
	var file:=FileAccess.open("user://original_world_runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ORIGINAL_WORLD_RESULTS "+JSON.stringify(report))
	world.queue_free(); await frames(2)
	if failures.is_empty(): print("ORIGINAL_WORLD_OK: %d assertions, 23 priority maps" % assertions)
	quit(0 if failures.is_empty() else 1)
func hunt(id: int) -> void:
	world._set_map("l1_%d" % id,false)
	var field: OriginalPlayableField=world.field_map
	var region: Dictionary=field.data.monster_spawn[0]
	var box: Rect2i=region.source_rect
	var center: Vector2=field.coordinates.to_world(Vector2(box.position)+Vector2(box.size)*0.5)
	var candidate: Vector2i=field.nearest_cell(center)
	if candidate.x<0: candidate=field.nearest_cell(world.player.global_position)
	world.player.global_position=field.cell_to_world(candidate)
	# Remove old actors before reactivating population at a distant source position.
	world.field_population.configure(world,null)
	world._clear_monsters()
	await frames(1)
	world.field_population.configure(world,field)
	await frames(2)
	var target: TwilightMonster=null
	for monster: TwilightMonster in world.monsters_root.get_children():
		for offset: Vector2i in field.DIRECTIONS:
			var p: Vector2=field.cell_to_world(field.world_to_cell(monster.global_position)+offset*12)
			if field.walkable(p) and not field.is_safe(p) and field.line_clear(p,monster.global_position) and p.distance_to(monster.global_position)>monster.current_attack_range()+60:
				world.player.global_position=p;target=monster;break
		if target!=null: break
	check(target!=null,"source-bound monster available %d" % id)
	if target==null: return
	var before: Vector2=target.global_position
	var old_hp: int=target.hp
	world.player.clear_click_path()
	world.player.velocity=Vector2.ZERO
	target.aggro_remaining=5.0
	await frames(75)
	check(target.global_position.distance_to(before)>5,"monster pursuit uses source grid %d" % id)
	world.player.set_auto_enabled(true)
	world.auto_target=target
	world.selected_monster=target
	await frames(240)
	check(not is_instance_valid(target) or target.dead or target.hp<old_hp,"AUTO deals damage %d" % id)
	check(world.monsters_root.get_child_count()<=96,"source actor cap %d" % id)
	world.player.set_auto_enabled(false)
