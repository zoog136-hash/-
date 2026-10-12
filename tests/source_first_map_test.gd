extends SceneTree
## Actual Main.tscn gameplay. Optional private data must be installed locally.
const TRAVEL = preload("res://scripts/maps/source_travel.gd")
var world: TwilightWorld
var failures: Array[String] = []
var checks: Array[String] = []
var evidence: Dictionary = {"map":"l1_4","original_graphics":false,"npc_services":"TWILIGHT","boss_schedule":"TWILIGHT_OFFLINE_OVERRIDE"}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append(label)
	if not ok: failures.append(label); printerr("SOURCE_FIRST_MAP_FAIL: "+label)
func frames(n: int) -> void:
	for i: int in range(n): await physics_frame
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	await frames(3)
	await RenderingServer.frame_post_draw
	var img: Image=root.get_texture().get_image()
	check(img!=null and img.get_width()>=960,"render "+label)
	if img!=null: check(img.save_png("user://first-map/"+label+".png")==OK,"capture "+label)
func relocate(p: Vector2) -> void:
	world.player.set_auto_enabled(false); world.player.clear_click_path(); world.player.velocity=Vector2.ZERO
	world.field_population.configure(world,null); world._clear_monsters()
	world.player.global_position=p
	world.field_population.configure(world,world.field_map)
	world.portal_cooldown=1000
func run() -> void:
	if not FileAccess.file_exists("res://data/original_maps/catalog.json"):
		print("SOURCE_FIRST_MAP_SKIP: private source pack not installed"); quit(0); return
	DirAccess.make_dir_recursive_absolute("user://first-map")
	world=load("res://Main.tscn").instantiate(); root.add_child(world); await frames(4)
	world.hud.complete_class_selection(); world.hud._close_workspace()
	world.level=100; world.max_hp=1000000; world.hp=1000000; world.rng.seed=410112
	world._on_map_selected("l1_4"); await frames(4)
	world.hud._close_workspace()
	check(world.active_map_id=="l1_4" and world.field_map is OriginalPlayableField,"game map entry")
	var field: OriginalPlayableField=world.field_map
	check(field.definition.source_sha256=="c22aa61ed083a3680230c659202503d7afaef30cb41b86d4655e9f843c81a7c4","actual A3 grid")
	check(world.field_minimap.field==field and world.field_minimap.source_overview!=null,"minimap source terrain")
	check(world.field_renderer.get_child_count()>0,"terrain mesh mounted")
	check(world.field_renderer.authored_art_enabled,"authored tiles enabled only for first map")
	var authored_cells: int=0
	var source_pair_cells: int=0
	var props_on_solid: bool=true
	for chunk: Node in world.field_renderer.chunks.values():
		var art: Node=chunk.get_node_or_null("AuthoredTerrain")
		if art==null: continue
		authored_cells+=int(art.cell_count)
		source_pair_cells+=int(art.source_pair_cells)
		for prop: Node in art.get_children():
			if prop.has_meta("source_blocked_cell"):
				props_on_solid=props_on_solid and field.value_at(prop.get_meta("source_blocked_cell"),true)==0
	check(authored_cells>0 and source_pair_cells>0,"textured source geometry and S32 variation mounted")
	check(props_on_solid,"authored obstacles remain on source-blocked cells")
	evidence["terrain_art"]="AUTHORED_REFERENCE_V2"
	check(world.field_renderer.authored_material.get_shader_parameter("atlas").resource_path=="res://assets/maps/reference_expansion_v2/terrain.png","reference expansion atlas mounted")
	evidence["authored_cells"]=authored_cells
	evidence["s32_varied_cells"]=source_pair_cells
	await shot("01-mainland")
	var start: Vector2=world.player.global_position
	var cell: Vector2i=field.world_to_cell(start)
	var goal: Vector2=start
	for offset: Vector2i in field.DIRECTIONS:
		var p: Vector2=field.cell_to_world(cell+offset*4)
		if field.line_clear(start,p): goal=p; break
	check(goal!=start,"reachable movement target")
	var click_position: Vector2=world.get_viewport().get_canvas_transform()*goal
	for pressed: bool in [true,false]:
		var click:=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT;click.position=click_position;click.pressed=pressed
		root.push_input(click,true)
	await frames(90)
	check(world.player.global_position.distance_to(goal)<16,"click movement")
	# Exercise the real actor motion guard across a closed source edge.
	var blocked: bool=false
	for dy: int in range(-20,21):
		for dx: int in range(-20,21):
			var c:=cell+Vector2i(dx,dy)
			if field.value_at(c,true)==0: continue
			for heading: int in range(8):
				if field.can_step(c,heading): continue
				var p: Vector2=field.cell_to_world(c)
				var q: Vector2=field.cell_to_world(c+field.DIRECTIONS[heading])
				world.player.clear_click_path(); world.player.global_position=p
				world.player.velocity=(q-p)*60
				world.player._move_on_map()
				blocked=world.player.global_position.distance_to(p)<0.01
				break
			if blocked: break
		if blocked: break
	check(blocked,"actor collision with blocked edge")
	# Require a non-straight route, rather than only testing adjacent nodes.
	var detour: PackedVector2Array=[]
	var detour_goal: Vector2=start
	for dy: int in range(-12,13,2):
		for dx: int in range(-12,13,2):
			var q: Vector2=field.cell_to_world(cell+Vector2i(dx,dy))
			if not field.walkable(q) or field.line_clear(start,q): continue
			var route: PackedVector2Array=field.path(start,q)
			if route.size()>2: detour=route;detour_goal=q;break
		if not detour.is_empty(): break
	check(detour.size()>2,"A* obstacle detour")
	relocate(start)
	world._set_click_destination(detour_goal); await frames(360)
	print("DETOUR_TRACE ",start," -> ",detour_goal," actual ",world.player.global_position," route ",detour," index ",world.player.path_index," click ",world.player.click_path," ui ",world.hud.active_section)
	check(world.player.global_position.distance_to(detour_goal)<16,"actor follows A* detour")
	# Source-position merchant, with explicitly temporary TWILIGHT shop service.
	var shop: bool=false
	for npc: Dictionary in field.data.npc_spawn:
		if str(npc.role)!="shop": continue
		var p:=Vector2(float(npc.position[0]),float(npc.position[1]))
		var c: Vector2i=field.nearest_cell(p)
		if c.x<0: continue
		relocate(field.cell_to_world(c)); world._set_click_destination(p)
		shop=str(world.hud.active_section)=="shop"
		if shop: break
	check(shop,"NPC shop interaction"); await shot("02-npc-shop"); world.hud._close_workspace()
	# The offline boss uses a source-documented area and existing combat stats.
	var boss_region: Dictionary=field.data.monster_spawn[0]
	var boss_center: Vector2=field.coordinates.to_world(Vector2(32638,32601))
	var near: Vector2i=field.nearest_cell(boss_center)
	check(near.x>=0,"boss area has valid terrain")
	relocate(field.cell_to_world(near)); await frames(5)
	var boss: TwilightMonster=null
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.id)=="offline_kurtz" and is_instance_valid(slot.monster): boss=slot.monster;break
	check(boss!=null,"offline boss spawn")
	if boss!=null:
		boss.hp=1777
		world._save_game(true); world._load_game(true); await frames(4)
		field=world.field_map
		boss=null
		for slot: Dictionary in world.field_population.slots:
			if str(slot.region.id)=="offline_kurtz" and is_instance_valid(slot.monster): boss=slot.monster;break
		check(boss!=null and boss.hp==1777,"boss HP save restoration")
		if boss!=null:
			world.player.global_position=field.cell_to_world(field.nearest_cell(boss.global_position+Vector2(72,0)))
			world._select_monster(boss)
		await shot("03-offline-boss")
	# Find a real source-bound regular monster and engage using existing AUTO.
	var target: TwilightMonster=null
	for region: Dictionary in field.data.monster_spawn:
		if str(region.mode)=="boss": continue
		var box: Rect2i=region.source_rect
		var p: Vector2=field.coordinates.to_world(Vector2(box.position)+Vector2(box.size)*0.5)
		var c: Vector2i=field.nearest_cell(p)
		if c.x<0 or field.is_safe(field.cell_to_world(c)): continue
		relocate(field.cell_to_world(c)); await frames(2)
		for monster: TwilightMonster in world.monsters_root.get_children():
			for offset: Vector2i in field.DIRECTIONS:
				var q: Vector2=field.cell_to_world(field.world_to_cell(monster.global_position)+offset*10)
				if field.walkable(q) and not field.is_safe(q) and field.line_clear(q,monster.global_position):
					world.player.global_position=q;target=monster;break
			if target!=null: break
		if target!=null: break
	check(target!=null,"source monster spawn")
	if target!=null:
		var hp_before: int=target.hp
		var p_before: Vector2=world.player.global_position
		world.player.set_auto_enabled(true); world.auto_target=target; world.selected_monster=target
		await frames(300)
		check(world.player.global_position.distance_to(p_before)>8,"AUTO movement")
		check(not is_instance_valid(target) or target.dead or target.hp<hp_before,"AUTO combat damage")
		await shot("04-auto-combat"); world.player.set_auto_enabled(false)
	# Portal activation uses the actual field trigger during physics frames.
	var portal_ok: bool=false
	for portal: Dictionary in field.data.portal:
		if str(portal.target_map)=="l1_4": continue
		var record: Dictionary=world.maps_by_id.get(str(portal.target_map),{})
		var dest: OriginalPlayableField=TRAVEL.load_field(record)
		if dest==null: continue
		var target_source:=Vector2(float(portal.target_source[0]),float(portal.target_source[1]))
		var valid: bool=dest.walkable(dest.coordinates.to_world(target_source));dest.close()
		var p:=Vector2(float(portal.position[0]),float(portal.position[1]))
		if not valid or not field.walkable(p): continue
		relocate(p);world.portal_cooldown=0
		# Trigger runs in _process and dispatches deferred travel. A busy GL frame
		# can contain several physics ticks before that process/deferred phase.
		var deadline: int=Time.get_ticks_msec()+4000
		while world.active_map_id=="l1_4" and Time.get_ticks_msec()<deadline:
			await process_frame
		portal_ok=world.active_map_id==str(portal.target_map)
		evidence["portal_destination"]=world.active_map_id
		break
	check(portal_ok,"physics portal transition")
	check(not world.field_renderer.authored_art_enabled,"unprofiled A3 destination retains prior renderer")
	world._set_map("l1_4",false);world.portal_cooldown=1000;await frames(3)
	world.hud.toggle_map();await frames(2)
	check(world.hud.region_selection.item_count>0,"world map selector")
	await shot("05-world-map");world.hud._close_workspace()
	world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	world._save_game(true)
	var saved: Vector2=world.player.global_position
	world.queue_free();await frames(3)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(4)
	check(world.active_map_id=="l1_4" and world.player.global_position.distance_to(saved)<0.01,"new scene reconnect position")
	check(world.field_map.nav_cache.size()<=64 and world.field_renderer.chunks.size()<=9,"bounded chunk memory")
	# Simulate an unavailable catalog entry without modifying the private pack.
	var file_before: String=FileAccess.get_sha256(world.SAVE_PATH)
	var record: Dictionary=world.maps_by_id.l1_4
	world.maps_by_id.erase("l1_4");world._load_game(true);world._save_game(true)
	check(world.source_save_blocked and FileAccess.get_sha256(world.SAVE_PATH)==file_before,"missing pack preserves save bytes")
	world.maps_by_id.l1_4=record;world._load_game(true)
	check(not world.source_save_blocked,"save resumes after pack recovery")
	evidence.merge({"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name()})
	var out=FileAccess.open("user://first-map/results.json",FileAccess.WRITE);out.store_string(JSON.stringify(evidence,"\t"));out.close()
	print("SOURCE_FIRST_MAP_RESULTS "+JSON.stringify(evidence))
	world.queue_free();await frames(2)
	if failures.is_empty(): print("SOURCE_FIRST_MAP_OK ",checks.size())
	quit(0 if failures.is_empty() else 1)
