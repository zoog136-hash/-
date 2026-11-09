extends SceneTree
## Actual Main player motion on raw M cells under an explicit own interpretation.
const QA = preload("res://tests/qa_class_selection.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const FIELD = preload("res://scripts/maps/current523_aden_source_field.gd")
const EXPECTED = "user://current523-source-main-expected.json"
const PRIOR_RENDERER = preload("res://scripts/maps/current523_aden_play_controller.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node
var raw_root: String
var tile_root: String
var contract: String
var measurements: Array = []
var captures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("ADEN_SOURCE_MAIN_FAIL ",label)

## P3-A: a source session releases the hidden prior renderer and rebuilds an
## equivalent one on return (the same instance when the release flag is off).
func restored_renderer(old: Variant, signature: Dictionary) -> bool:
	var now: Variant = world.field_renderer
	if is_instance_valid(old) and now == old: return true
	return now is Node and is_instance_valid(now) and PRIOR_RENDERER.renderer_signature(now) == signature

func _initialize() -> void: call_deferred("run")

func frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func state() -> Dictionary:
	var value: Dictionary = {}
	for key: String in ["gold","inventory","item_instances","equipped_items","enhancement_levels"]: value[key] = world.get(key)
	value.collections = world.equipment_collections.export_state()
	value.bosses = world.field_population.export_state()
	return JSON.parse_string(JSON.stringify(value,"",true,true))

func capture(name: String) -> void:
	var folder: String = OS.get_environment("ADEN523_CAPTURE_DIR")
	if folder.is_empty(): return
	var picture: Image = root.get_texture().get_image()
	check(picture != null and not picture.is_empty(),"actual source field rendered")
	if picture == null or picture.is_empty(): return
	var path: String = folder.path_join(name+".png")
	check(picture.save_png(path)==OK,"source Main screenshot saved locally")
	captures.append(path)

func source_point(x: int,y: int) -> Vector2:
	return world.field_map.coordinates.to_world(Vector2(x,y))

func walk(point: Vector2) -> bool:
	var route: PackedVector2Array = world.find_world_path(world.player.global_position,point)
	if route.is_empty(): return false
	world.hud.workspace.hide()
	world.player.set_manual_click_path(route,point)
	world.player.set_physics_process(true)
	var deadline: int = Time.get_ticks_msec()+6000
	while world.player.global_position.distance_to(point)>3 and Time.get_ticks_msec()<deadline: await physics_frame
	world.player.set_physics_process(false); world.player.clear_click_path(); world.player.velocity = Vector2.ZERO
	return world.player.global_position.distance_to(point)<7

func enter_at(point: Vector2i) -> bool:
	return world.open_current523_aden_play(raw_root,tile_root,{"navigation_profile":OPTIONS.SOURCE,"allowed_raw_words":OPTIONS.SOURCE_WORDS.duplicate(),"source_position":[point.x+0.5,point.y+0.5],"portal_contract":contract,"aden_inferred_placement_enabled":false})

func run() -> void:
	var phase: String = "entry"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--aden523-pack="): raw_root = argument.trim_prefix("--aden523-pack=")
		if argument.begins_with("--aden523-tiles="): tile_root = argument.trim_prefix("--aden523-tiles=")
		if argument.begins_with("--aden523-portals="): contract = argument.trim_prefix("--aden523-portals=")
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false); world.save_timer = -100000.0
	check(QA.enter_game(world),"actual ordinary Main class entry")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	if phase == "reconnect": await reconnect(); return
	if phase == "regions": await regions(); return
	world.gold = 523071
	check(world._save_game(true)==OK,"baseline actual game save")
	var protected: Dictionary = state()
	var old_field = world.field_map
	var old_renderer = world.field_renderer
	var old_physics = world.field_physics
	var old_position: Vector2 = world.player.global_position
	var save_sha: String = FileAccess.get_sha256(world.save_path())
	world.hud.call("open_settings_info")
	await frames()
	var panel = world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel != null,"source settings are available in actual game")
	if panel == null: await finish(phase); return
	panel.raw_path_edit.text = raw_root; panel.tile_path_edit.text = tile_root
	panel.raw_path_edit.text_changed.emit(raw_root); panel.tile_path_edit.text_changed.emit(tile_root)
	panel.play_profile.select(2); panel.play_profile.item_selected.emit(2)
	panel.aden_inferred_placement.button_pressed=false # Retain historical placement-off baseline.
	panel.source_entry_enabled.button_pressed = true
	panel.source_entry_x.value = 33341; panel.source_entry_y.value = 33168
	panel.source_portal_path.text = contract
	panel.source_words.text = "1"
	panel.play_button.pressed.emit()
	check(not world.current523_aden_source_active() and world.field_map==old_field and world.player.global_position==old_position,"source-blocked entry leaves existing field and actor intact")
	check(FileAccess.get_sha256(world.save_path())==save_sha,"source-blocked entry preserves actual save")
	panel.source_words.text = "0,4,8,12,32"
	panel.play_button.pressed.emit()
	await frames()
	check(world.current523_aden_source_active(),"actual Settings starts S32 source navigation: "+world.current523_aden_play_problem)
	if not world.current523_aden_source_active(): await finish(phase); return
	var source = world.field_map
	check(source.get_script()==FIELD and source!=old_field and world.field_physics!=old_physics,"actual movement field and physics are replaced with own S32 field")
	check(source.chunk_table.is_empty() and source.packs.is_empty() and source.nav_cache.is_empty(),"source play loads no old navigation grid or shards")
	check(source.source_chunk_origins().size()==676 and source.unplaced_source_members().size()==1,"all placed Aden source fields share loader and one literal source stays unplaced")
	check(source.data.monster_spawn.is_empty() and source.data.npc_spawn.is_empty() and not world.monsters_root.visible,"legacy geography and actors are not reused as M geography")
	check(world.field_minimap.field==source and old_physics.collision_layer==0,"source minimap and motion own the active field")
	check(old_physics.process_mode==Node.PROCESS_MODE_DISABLED,"retained old collision streaming does not read legacy terrain while source mode runs")
	check(world._nearest_monster(INF)==null and world._nearest_visible_monster(INF)==null and world._skill_target(INF)==null,"hidden legacy actors cannot become source field combat targets")
	world.consumable_service.call("_use_return","미확인 원문 귀환 주문서")
	check(world.current523_aden_source_active() and state()==protected,"unsupported return scroll preserves inventory and source field")
	check(world.current523_aden_source_portals().size()==93,"actual source portal UI receives all93 declarations")
	check(panel.source_portal_choice.item_count==93,"actual settings lists the source portal contract")
	var info: Dictionary = source.source_cell_info(Vector2i(33341,33168))
	check(info.raw_pair==[0,0] and info.walkable,"actual start decisions expose both original attribute words")
	var metrics: Dictionary = world.current523_aden_play_metrics()
	check(metrics.M_attributes_used and metrics.navigation_owner=="CURRENT523_S32_OWN_ALLOWLIST" and metrics.overlap_chunks==676 and not metrics.native_M_rules_verified,"actual renderer provenance distinguishes source rule from old map")
	capture("source-portal335-start")
	check(await walk(source_point(33342,33168)),"actual player physics walks onto Portal335's declared source cell")
	var before_block: Vector2 = world.player.global_position
	var blocked: Vector2 = source_point(33343,33168)
	check(not source.walkable(blocked) and world.find_world_path(before_block,blocked).is_empty(),"raw pair containing1 rejects blocked goal without snapping")
	world.player.touch_vector = before_block.direction_to(blocked); world.player.set_physics_process(true)
	var crossed: bool = false
	for _tick: int in range(24):
		await physics_frame
		if source.world_to_cell(world.player.global_position)+source.coordinates.origin==Vector2i(33343,33168): crossed=true
	world.player.set_physics_process(false); world.player.touch_vector=Vector2.ZERO; world.player.velocity=Vector2.ZERO
	check(not crossed,"actual movement cannot cross the own source blocked cell")
	check(await walk(source_point(33342,33168)),"actor returns to declared portal source by actual motion")
	world.portal_cooldown=0
	for index: int in range(panel.source_portal_choice.item_count):
		if panel.source_portal_choice.get_item_id(index)==335: panel.source_portal_choice.select(index)
	panel.source_portal_button.pressed.emit()
	await frames()
	check(world.current523_aden_source_active() and source.world_to_cell(world.player.global_position)+source.coordinates.origin==Vector2i(33365,33153),"actual portal button reaches the exact verified Portal335 landing: "+world.current523_aden_play_problem)
	var landed: Vector2 = world.player.global_position
	check(not world.use_current523_aden_source_portal(335) and world.player.global_position==landed,"repeat portal activation preserves landing and does not duplicate a transaction")
	world.portal_cooldown=0
	check(not world.use_current523_aden_source_portal(350) and world.player.global_position==landed,"Portal350 mismatch cannot silently replace its native destination")
	check(not world.use_current523_aden_source_portal(327) and world.player.global_position==landed,"missing other-Land field denies without moving")
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"entry, motion and portal use preserve inventory, currency, bosses and original save bytes")
	check(not world._drop_inventory_reference("unresolved-qa-item",world.player.global_position) and state()==protected,"unsupported source ground-drop transaction refuses without item loss")
	capture("source-portal335-arrival")
	check(world._save_game(true)==OK,"normal progress writer saves while source navigation is active")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(Vector2(disk.position[0],disk.position[1]).distance_to(old_position)<0.1 and disk.original_position.grid_sha256==old_field.definition.source_sha256,"normal save retains its original spatial identity rather than writing S32 cursor into the legacy map")
	check(OPTIONS.read().source_position==source.coordinates.source_components(landed),"source cursor is persisted separately for reconnect")
	var expected: Dictionary = {"state":protected,"source_position":OPTIONS.read().source_position,"save_sha":FileAccess.get_sha256(world.save_path()),"old_position":[old_position.x,old_position.y],"raw_root":raw_root,"tile_root":tile_root,"contract":contract}
	var file:=FileAccess.open(EXPECTED,FileAccess.WRITE); file.store_string(JSON.stringify(expected,"",true,true)); file.close()
	measurements.append({"area":"Portal335 source and landing","source_member":info.member,"own_policy":OPTIONS.SOURCE_WORDS,"native_m_rules_verified":false})
	await finish(phase)

func reconnect() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	var deadline: int = Time.get_ticks_msec()+20000
	while not world.current523_aden_source_active() and Time.get_ticks_msec()<deadline: await process_frame
	check(world.current523_aden_source_active(),"new actual Main process restores the source field")
	if not world.current523_aden_source_active(): await finish("reconnect"); return
	check(world.field_map.coordinates.source_components(world.player.global_position)==expected.source_position,"new process restores exact separately saved source cursor")
	var actual: Dictionary = state()
	var changed: Array[String] = []
	for key: String in actual:
		if actual[key]!=expected.state.get(key): changed.append(key)
	check(changed.is_empty(),"source reconnect preserves progress fields: "+str(changed))
	check(FileAccess.get_sha256(world.save_path())==expected.save_sha,"source reconnect does not rewrite save bytes")
	if not changed.is_empty():
		measurements.append({"changed_keys":changed,"actual_bosses":actual.bosses,"expected_bosses":expected.state.bosses})
	capture("source-reconnect")
	world.close_current523_aden_play()
	check(not world.current523_aden_source_active() and world.player.global_position.distance_to(Vector2(expected.old_position[0],expected.old_position[1]))<0.1,"explicit source return restores original map position")
	check(not OPTIONS.read().enabled,"source return disables automatic entry")
	await finish("reconnect")

func regions() -> void:
	# Real consumable in this isolated QA profile; production grants are unchanged.
	world.inventory["귀환 주문서"] = 2
	check(world._save_game(true)==OK,"isolated region QA saves its real consumable baseline")
	var protected: Dictionary = state()
	var old_field = world.field_map
	var old_renderer = world.field_renderer
	var old_view: Dictionary = PRIOR_RENDERER.renderer_signature(old_renderer)
	var old_position: Vector2 = world.player.global_position
	var save_sha: String = FileAccess.get_sha256(world.save_path())
	for source_cell: Vector2i in [Vector2i(34002,32326),Vector2i(33471,32769),Vector2i(32319,33595)]:
		check(enter_at(source_cell),"source entry in separated actual region: "+str(source_cell)+" "+world.current523_aden_play_problem)
		await frames()
		if not world.current523_aden_source_active(): continue
		var field = world.field_map
		var next: Vector2i = source_cell+Vector2i(1,0)
		check(await walk(source_point(next.x,next.y)),"actual source movement in region or across raw chunk seam: "+str(source_cell))
		var before_scroll: Vector2=world.player.global_position
		world.consumable_service.try_use("귀환 주문서")
		check(world.current523_aden_source_active() and world.player.global_position==before_scroll and int(world.inventory.get("귀환 주문서",0))==2,"actual return-scroll use is held without relocation or consumption")
		check(not world._drop_inventory_reference("귀환 주문서",before_scroll) and int(world.inventory.get("귀환 주문서",0))==2,"existing real item cannot be transferred into an unsupported source drop store")
		if source_cell.x%64==63:
			check(field.source_cell_info(source_cell).member!=field.source_cell_info(next).member,"actual motion crossed two distinct original S32 chunks")
		if source_cell==Vector2i(34002,32326):
			world.portal_cooldown=0
			check(world.use_current523_aden_source_portal(343),"second region Portal343 exact endpoint activation")
			check(field.world_to_cell(world.player.global_position)+field.coordinates.origin==Vector2i(34006,32302),"Portal343 arrives in declared native point")
		var outside: Vector2 = field.cell_to_world(Vector2i(-3,10))
		var position: Vector2 = world.player.global_position
		check(not field.walkable(outside) and world.find_world_path(position,outside).is_empty(),"source field boundary rejects missing destination")
		world._set_click_destination(outside); world.player.set_physics_process(true)
		for _tick: int in range(8): await physics_frame
		world.player.set_physics_process(false)
		check(world.player.global_position.distance_to(position)<0.1,"actual boundary click preserves actor position")
		capture("source-region-"+str(source_cell.x))
		measurements.append({"entry":[source_cell.x,source_cell.y],"member":field.source_cell_info(source_cell).member,"metrics":world.current523_aden_play_metrics()})
		world.close_current523_aden_play()
		await frames()
		check(world.field_map==old_field and restored_renderer(old_renderer,old_view) and world.player.global_position==old_position,"region return restores exact original field, an equivalent renderer and position")
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"multiple region entries/seams/portals preserve all protected state and save bytes")
	# Budget failure after a validated source entry must restore the original field.
	check(enter_at(Vector2i(33412,32768)),"source failure-return entry in changed523 chunk")
	if world.current523_aden_source_active():
		var camera: Camera2D=world.player.camera
		var zoom: Vector2=camera.zoom
		var prefs_sha: String=FileAccess.get_sha256(OPTIONS.PATH)
		camera.zoom=Vector2(0.05,0.05); camera.force_update_scroll()
		check(not world.apply_current523_aden_play_options({"offset_y":12}),"unrenderable source view rejects correction")
		check(FileAccess.get_sha256(OPTIONS.PATH)==prefs_sha,"failed source correction leaves preference bytes unchanged")
		camera.zoom=zoom;camera.force_update_scroll()
		await frames()
		check(not world.current523_aden_source_active() and world.field_map==old_field and world.player.global_position==old_position,"source budget failure restores original field and actor")
		world.close_current523_aden_play()
	await finish("regions")

func finish(phase: String) -> void:
	print("CURRENT523_ADEN_SOURCE_MAIN_RESULT "+JSON.stringify({"phase":phase,"checks":checks,"failures":failures,"measurements":measurements,"captures":captures,"native_m_rules_verified":false}))
	if is_instance_valid(world):world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
