extends "res://tests/current523_generic_portal_main_test.gd"
## Sequential actual Main/GL coverage. Own QA positioning is not native admission.
## The inherited provider fixture is never instantiated by this test.
var cases_path: String
var cases_pin: String
var progress_path: String
var first_index: int=0
var max_regions: int=577
var attempted: int=0
var passed: int=0
var progress: FileAccess
var sheet: Image
var host_field: RefCounted
var host_position: Vector2
var initial_progress: Dictionary
var original_save_sha: String
var started: int
var selected_indices: Array[int]=[]

func _arg(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix): return a.trim_prefix(prefix)
	return ""

func pcell(a: Array) -> Vector2i: return Vector2i(int(a[0]),int(a[1]))
func wp(a: Array) -> Vector2: return world.field_map.coordinates.to_world(Vector2(pcell(a)))
func value_pair(a: Array,b: Array) -> bool:
	return a.size()==2 and b.size()==2 and int(a[0])==int(b[0]) and int(a[1])==int(b[1])

func walk(point: Vector2) -> bool:
	var route: PackedVector2Array=world.find_world_path(world.player.global_position,point)
	if route.is_empty(): return false
	var before: Vector2=world.player.global_position
	world.hud.workspace.hide()
	world.player.set_manual_click_path(route,point); world.player.set_physics_process(true)
	var deadline: int=Time.get_ticks_msec()+6000
	# The actor's normal arrival tolerance can stop it before the old harness's
	# 3px loop condition. Require a tighter-than-7px result AND the exact target
	# source cell, rather than spending6s after a successful physical arrival.
	while world.player.global_position.distance_to(point)>6.0 and Time.get_ticks_msec()<deadline: await physics_frame
	world.player.set_physics_process(false); world.player.clear_click_path(); world.player.velocity=Vector2.ZERO
	return world.player.global_position.distance_to(point)<=6.0 and world.player.global_position.distance_to(before)>1.0 and world.field_map.world_to_cell(world.player.global_position)==world.field_map.world_to_cell(point)

func position_probe(point: Array) -> bool:
	if not world.current523_aden_source_active() or not world.field_map.point_clear(wp(point),4): return false
	world.player.clear_click_path(); world.player.set_touch_vector(Vector2.ZERO); world.player.velocity=Vector2.ZERO
	world.player.global_position=wp(point)
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	await frames()
	return world.current523_aden_source_active()

func blocked_motion(target: Array) -> bool:
	var field=world.field_map
	var destination: Vector2=wp(target)
	if field.walkable(destination) or not world.find_world_path(world.player.global_position,destination).is_empty(): return false
	var entered: bool=false
	world.player.set_touch_vector(world.player.global_position.direction_to(destination)); world.player.set_physics_process(true)
	for _tick: int in range(20):
		await physics_frame
		if field.world_to_cell(world.player.global_position)+field.coordinates.origin==pcell(target): entered=true
	world.player.set_physics_process(false); world.player.set_touch_vector(Vector2.ZERO); world.player.velocity=Vector2.ZERO
	return not entered

func protected_except_initial_host_lives(before: Dictionary) -> bool:
	var after: Dictionary=state()
	for key: String in before:
		if key!="bosses" and before[key]!=after.get(key): return false
	return returned_bosses(before.bosses,after.bosses).ok

func audit_region(row: Dictionary,index: int) -> Dictionary:
	var count_before: int=failures.size()
	var begun: int=Time.get_ticks_msec()
	var record: Dictionary={"index":index,"land_id":row.land_id,"name":row.name,"asset_path":row.asset_path,"entry_role":row.entry.role,"native_admission_verified":false,"status":"BEGIN","native_m_rules_verified":false}
	var protected: Dictionary=state()
	var save_before: String=FileAccess.get_sha256(world.save_path())
	if not open_generic(int(row.land_id),pcell(row.entry.cell)):
		record.status="ENTRY_REFUSED"; record.problem=world.current523_aden_play_problem
		check(world.field_map==host_field and world.player.global_position==host_position and FileAccess.get_sha256(world.save_path())==save_before,"refused entry preserves host/save "+str(row.land_id))
		return record
	await frames()
	if not world.current523_aden_source_active(): record.status="FRAME_SAFE_RETURN"; record.problem=world.current523_aden_play_problem; return record
	var field=world.field_map
	check(field.native_land.ID==row.land_id and field.source_asset==row.asset_path and field.source_chunk_origins().size()==int(row.placed_S32),"exact source identity/placed packet count "+str(row.land_id))
	var info: Dictionary=field.source_cell_info(pcell(row.entry.cell))
	check(info.source_sha256==row.entry.entry_cell_info.source_sha256 and value_pair(info.raw_pair,row.entry.entry_cell_info.raw_pair) and value_pair(info.floor_pair,row.entry.entry_cell_info.floor_pair),"independent original entry bytes "+str(row.land_id))
	check(field.chunk_table.is_empty() and field.nav_cache.is_empty() and field.packs.is_empty(),"no old navigation inputs "+str(row.land_id))
	check(world.field_minimap.field==field and world.hud.v20_map_name.text.contains(str(field.data.map_name)),"actual minimap/HUD follows source field "+str(row.land_id))
	check(await walk(wp(row.clear_neighbor.source_cell)),"actual clear-edge walk "+str(row.land_id))
	check(await position_probe(row.wall_probe.stand.source_cell),"verified own QA wall probe positioning "+str(row.land_id))
	if world.current523_aden_source_active():
		check(await blocked_motion(row.wall_probe.blocked.source_cell),"actual blocked physical motion "+str(row.land_id))
	else: record.status="WALL_FRAME_SAFE_RETURN"; record.problem=world.current523_aden_play_problem; return record
	if row.open_seam!=null:
		check(await position_probe(row.open_seam.first.source_cell),"own QA seam positioning "+str(row.land_id))
		if world.current523_aden_source_active():
			check(await walk(wp(row.open_seam.second.source_cell)),"actual cross-source chunk walking "+str(row.land_id))
			record.boundary="CROSSED_ORIGINAL_CHUNK_EDGE"
		else: record.status="SEAM_FRAME_SAFE_RETURN"; record.problem=world.current523_aden_play_problem; return record
	elif row.refused_seam!=null:
		check(await position_probe(row.refused_seam.first.source_cell),"own QA closed-seam positioning "+str(row.land_id))
		if world.current523_aden_source_active(): check(await blocked_motion(row.refused_seam.second.source_cell),"actual refused original chunk edge "+str(row.land_id))
		record.boundary="CLOSED_EDGE_PHYSICAL_REFUSAL"
	elif int(row.adjacent_chunk_pairs)>0:
		check(not field.source_cell_info(pcell(row.closed_seam_sample.first.source_cell)).walkable and not field.source_cell_info(pcell(row.closed_seam_sample.second.source_cell)).walkable,"both original boundary cells refused; no bridge invented "+str(row.land_id))
		record.boundary="NO_OPEN_EDGE_UNDER_OWN_POLICY"
	else: record.boundary="NO_ADJACENT_ORIGINAL_CHUNKS"
	if not world.current523_aden_source_active(): record.status="BOUNDARY_SAFE_RETURN"; return record
	check(not field.walkable(wp(row.outside_cell)) and world.find_world_path(world.player.global_position,wp(row.outside_cell)).is_empty(),"outside original field rejects path "+str(row.land_id))
	var metrics: Dictionary=world.current523_aden_play_metrics()
	check(metrics.unresolved_refs==0 and metrics.budget_skips==0 and metrics.ready_placed_sources==row.placed_S32,"actual frame complete within declared scope "+str(row.land_id))
	record.frame_metrics=metrics
	var frame: Image=root.get_texture().get_image()
	check(frame!=null and not frame.is_empty(),"actual GL frame readback "+str(row.land_id))
	if frame!=null and not frame.is_empty():
		record.frame_sha256=SOURCE_PACK._hash(frame.get_data())
		record.frame_size=[frame.get_width(),frame.get_height()]
		frame.convert(Image.FORMAT_RGBA8)
		frame.resize(160,90,Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(frame,Rect2i(0,0,160,90),Vector2i((attempted%16)*160,(attempted >> 4)*90))
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_before,"motion preserves protected state and save bytes "+str(row.land_id))
	check(world._save_game(true)==OK,"actual source-mode game save "+str(row.land_id))
	var saved: Dictionary=OPTIONS.read()
	record.cursor_before_save=field.coordinates.source_components(world.player.global_position)
	record.cursor_read=saved.source_position.duplicate()
	record.pixel_before_teardown=[world.player.global_position.x,world.player.global_position.y]
	record.walkable_before_teardown=field.walkable(world.player.global_position)
	record.source_cursor_serialization_delta=[record.cursor_before_save[0]-saved.source_position[0],record.cursor_before_save[1]-saved.source_position[1]]
	# ConfigFile's decimal f64 text need not retain insignificant final digits.
	# The gameplay contract is stricter: the exact runtime Vector2 and cell must
	# roundtrip, without an epsilon that could conceal an actual position change.
	check(saved.native_land_id==row.land_id and field.coordinates.components_to_world(saved.source_position)==world.player.global_position,"actual writer preserves exact world pose and native source cell "+str(row.land_id))
	var after_save_sha: String=FileAccess.get_sha256(world.save_path())
	world.close_current523_aden_play(false)
	check(world.field_map==host_field and world.player.global_position==host_position and protected_except_initial_host_lives(protected),"exact host return and protected lives "+str(row.land_id))
	var after_return: Dictionary=state()
	world._restore_current523_aden_play()
	check(world.current523_aden_source_active(),"actual restore entry path after field teardown "+str(row.land_id))
	await frames()
	if world.current523_aden_source_active():
		record.pixel_after_restore=[world.player.global_position.x,world.player.global_position.y]
		record.cursor_after_restore=world.field_map.coordinates.source_components(world.player.global_position)
		record.pixel_restore_distance=world.player.global_position.distance_to(Vector2(record.pixel_before_teardown[0],record.pixel_before_teardown[1]))
		check(world.field_map.native_land.ID==row.land_id and world.player.global_position==Vector2(record.pixel_before_teardown[0],record.pixel_before_teardown[1]) and world.field_map.world_to_cell(world.player.global_position)+world.field_map.coordinates.origin==Vector2i(floori(record.cursor_before_save[0]),floori(record.cursor_before_save[1])),"restored exact source identity, cell and runtime world pose "+str(row.land_id))
		check(state()==after_return and FileAccess.get_sha256(world.save_path())==after_save_sha,"restore preserves progress and stored bytes "+str(row.land_id))
		world.close_current523_aden_play()
	check(world.field_map==host_field and world.player.global_position==host_position and protected_except_initial_host_lives(after_return),"restored field returns safely "+str(row.land_id))
	check(not open_generic(int(row.land_id),pcell(row.wall_probe.blocked.source_cell)),"source denied-cell entry is rejected "+str(row.land_id))
	check(world.field_map==host_field and FileAccess.get_sha256(world.save_path())==after_save_sha,"failed entry preserves final host/save "+str(row.land_id))
	record.status="PASS" if failures.size()==count_before else "ASSERTION_FAILURE"
	record.failures=failures.slice(count_before)
	record.seconds=(Time.get_ticks_msec()-begun)/1000.0
	record.restore_mode="ACTUAL_RESTORE_METHOD_AFTER_TEARDOWN; NOT_NEW_OS_PROCESS"
	record.save_sha256=after_save_sha
	return record

func run() -> void:
	started=Time.get_ticks_msec()
	raw_root=_arg("--source-root="); tile_root=_arg("--tile-root="); source_sha=_arg("--source-sha="); tile_sha=_arg("--tile-sha=")
	cases_path=_arg("--cases="); cases_pin=_arg("--cases-sha="); progress_path=_arg("--progress=")
	if not _arg("--start=").is_empty(): first_index=int(_arg("--start="))
	if not _arg("--limit=").is_empty(): max_regions=int(_arg("--limit="))
	if not _arg("--indices=").is_empty():
		for item: String in _arg("--indices=").split(",",false):
			check(item.is_valid_int() and int(item)>=0 and int(item)<577 and int(item) not in selected_indices,"bounded unique requested region index")
			selected_indices.append(int(item))
		max_regions=selected_indices.size()
	check(cases_pin.length()==64 and FileAccess.get_sha256(cases_path)==cases_pin,"caller-pinned actual whole-scope QA cases")
	if not failures.is_empty(): finish_bulk(); return
	var all: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(cases_path))
	check(all.cases.size()==577 and all.source_manifest_sha256==source_sha,"all577 physical regions refer to the same original source pack")
	progress=FileAccess.open(progress_path,FileAccess.WRITE)
	check(progress!=null,"explicit bounded local progress sink")
	if progress==null: finish_bulk(); return
	root.size=Vector2i(640,360); root.content_scale_size=Vector2i(640,360)
	sheet=Image.create(2560,ceili(float(mini(max_regions,577))/16)*90,false,Image.FORMAT_RGBA8)
	world=(load("res://Main.tscn") as PackedScene).instantiate(); root.add_child(world)
	world.set_process(false); world.save_timer=-100000.0
	check(QA.enter_game(world),"actual ordinary Main class entry")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	world.gold=523577
	check(world._save_game(true)==OK,"isolated actual baseline save")
	host_field=world.field_map; host_position=world.player.global_position; original_save_sha=FileAccess.get_sha256(world.save_path()); initial_progress=state()
	var indices: Array[int]=selected_indices.duplicate()
	if indices.is_empty():
		for index: int in range(first_index,mini(all.cases.size(),first_index+max_regions)):indices.append(index)
	for index: int in indices:
		if Time.get_ticks_msec()-started>1800000: check(false,"30-minute explicit bulk audit budget reached"); break
		var row: Dictionary=all.cases[index]
		print("CURRENT523_ALL_REGIONS_BEGIN ",index," ",row.land_id," ",row.asset_path)
		var record: Dictionary=await audit_region(row,index)
		progress.store_line(JSON.stringify(record)); progress.flush()
		attempted+=1
		if record.status=="PASS": passed+=1
		print("CURRENT523_ALL_REGIONS_PROGRESS ",JSON.stringify({"index":index,"land_id":row.land_id,"status":record.status,"attempted":attempted,"passed":passed,"seconds":record.get("seconds",0)}))
		if world.current523_aden_source_active(): world.close_current523_aden_play()
	var cache: Dictionary=world.get("_current523_aden_play_controller").input_cache_metrics()
	check(cache.source_catalog_loads==1 and cache.tile_catalog_loads==1 and cache.tile_cache_size<=32,"one parsed verified catalog per immutable source/tile pack; bounded atlas cache")
	check(protected_except_initial_host_lives(initial_progress),"all physical-region probes preserve initial character progress and lives")
	check(sheet.save_png(progress_path+".contact-sheet.png")==OK,"local bounded actual-frame contact sheet")
	finish_bulk()

func finish_bulk() -> void:
	var result: Dictionary={"checks":checks,"failures":failures,"attempted":attempted,"passed":passed,"first_index":first_index,"requested_regions":max_regions,"actual_Main":true,"native_M_rules_verified":false,"native_admission_tested":false,"new_OS_process_per_region":false,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0}
	if is_instance_valid(world): result.input_cache_metrics=world.get("_current523_aden_play_controller").input_cache_metrics(); world.queue_free()
	print("CURRENT523_ALL_REGIONS_MAIN_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() and passed==attempted and attempted==max_regions else 1)
