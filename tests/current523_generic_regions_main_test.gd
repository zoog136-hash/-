extends "res://tests/current523_aden_source_main_test.gd"
## Actual Main on separate native fields. Cells come from private original proofs.
var source_sha: String
var tile_sha: String
var cases_file: String
var group: int=0

func point_cell(point: Array) -> Vector2i: return Vector2i(int(point[0]),int(point[1]))
func own_point(point: Array) -> Vector2:
	return world.field_map.coordinates.to_world(Vector2(float(point[0]),float(point[1])))
func numeric_pair_equal(actual: Array, expected: Array) -> bool:
	return actual.size()==2 and expected.size()==2 and int(actual[0])==int(expected[0]) and int(actual[1])==int(expected[1])
func open_land(id: int,point: Array) -> bool:
	return world.open_current523_aden_play(raw_root,tile_root,{"navigation_profile":OPTIONS.GENERIC,"source_manifest_sha256":source_sha,"tile_manifest_sha256":tile_sha,"native_land_id":id,"allowed_raw_words":OPTIONS.SOURCE_WORDS.duplicate(),"source_position":[float(point[0])+0.5,float(point[1])+0.5],"portal_contract":""})

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-root="): raw_root=argument.trim_prefix("--source-root=")
		if argument.begins_with("--tile-root="): tile_root=argument.trim_prefix("--tile-root=")
		if argument.begins_with("--source-sha="): source_sha=argument.trim_prefix("--source-sha=")
		if argument.begins_with("--tile-sha="): tile_sha=argument.trim_prefix("--tile-sha=")
		if argument.begins_with("--cases="): cases_file=argument.trim_prefix("--cases=")
		if argument.begins_with("--group="): group=int(argument.trim_prefix("--group="))
	check(FileAccess.get_sha256(cases_file)=="461947362d0e7b2ddc70affd769a010c0bfe9422fa33ab0155e0abd75bd4296f","private native entry/byte evidence pin")
	if not failures.is_empty(): await finish_regions(); return
	var cases: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(cases_file))
	world=(load("res://Main.tscn") as PackedScene).instantiate(); root.add_child(world)
	world.set_process(false); world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main ordinary class entry")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	world.gold=523091
	check(world._save_game(true)==OK,"ordinary baseline save")
	var protected: Dictionary=state()
	var save_sha: String=FileAccess.get_sha256(world.save_path())
	var host=world.field_map
	var host_position: Vector2=world.player.global_position
	var number: int=0
	for row: Dictionary in cases.cases:
		var index: int=number; number+=1
		if (group==0 and index>=5) or (group==1 and (index<5 or index>=8)) or (group==2 and index<8): continue
		var id: int=int(row.land_id)
		var entry: Array=row.selected_native_entry.raw_native_declared_source_cell
		check(open_land(id,entry),"native Land%d entry: %s" % [id,world.current523_aden_play_problem])
		if not world.current523_aden_source_active(): continue
		await frames()
		var source=world.field_map
		check(source.definition.source_map_id==id and source.source_asset==row.asset_path,"exact logical Land and literal AssetPath")
		check(source.world_to_cell(world.player.global_position)+source.coordinates.origin==point_cell(entry),"actual entry stays at declared native source cell")
		check(source.source_chunk_origins().size()==int(row.source_count),"all current originals in selected physical root")
		check(world.hud.v20_map_name.text.contains(str(source.data.map_name)),"actual HUD labels selected source map")
		var actual: Dictionary=source.source_cell_info(point_cell(entry))
		check(numeric_pair_equal(actual.raw_pair,row.selected_native_entry.entry_cell_info.raw_pair) and numeric_pair_equal(actual.floor_pair,row.selected_native_entry.entry_cell_info.floor_pair),"source decision matches independently read native entry bytes")
		check(await walk(own_point(row.adjacent_clear_cell.source_cell)),"actual native Land%d walking" % id)
		var blocked: Vector2=own_point(row.adjacent_blocked_cell.source_cell)
		check(not source.walkable(blocked) and world.find_world_path(world.player.global_position,blocked).is_empty(),"native Land%d original blocked cell rejects path" % id)
		var crossed: bool=false
		world.player.set_touch_vector(world.player.global_position.direction_to(blocked)); world.player.set_physics_process(true)
		for _tick: int in range(20):
			await physics_frame
			if source.world_to_cell(world.player.global_position)+source.coordinates.origin==point_cell(row.adjacent_blocked_cell.source_cell): crossed=true
		world.player.set_physics_process(false); world.player.set_touch_vector(Vector2.ZERO); world.player.velocity=Vector2.ZERO
		check(not crossed,"actual Land%d blocked motion never enters refused cell" % id)
		var metric: Dictionary=world.current523_aden_play_metrics()
		check(metric.unresolved_refs==0 and metric.budget_skips==0 and metric.ready_placed_sources==int(row.source_count),"native Land%d render has no omitted tile refs" % id)
		metric.tested_entry=entry.duplicate(); metric.declared_entry_role=row.selected_native_entry.entrypoint_role
		measurements.append(metric); capture("generic-land%d-source" % id)
		world.close_current523_aden_play()
		check(world.field_map==host and world.player.global_position==host_position and state()==protected,"Land%d return preserves exact host and progression" % id)
		var seam: Dictionary=row.safe_seam_probe
		check(open_land(id,seam.first.source_cell),"Land%d own seam probe entry" % id)
		if world.current523_aden_source_active():
			check(await walk(own_point(seam.second.source_cell)),"actual Land%d crosses two original chunk boundaries" % id)
			check(world.field_map.source_cell_info(point_cell(seam.first.source_cell)).member!=world.field_map.source_cell_info(point_cell(seam.second.source_cell)).member,"seam crosses distinct preserved originals")
			world.close_current523_aden_play()
		check(world.field_map==host and state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"Land%d seam return and save bytes preserved" % id)
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"all regional motion preserves original progress/save")
	await finish_regions()

func finish_regions() -> void:
	print("CURRENT523_GENERIC_REGIONS_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_Main":true,"group":group,"metrics":measurements,"captures":captures,"native_collision_verified":false}))
	if is_instance_valid(world): world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
