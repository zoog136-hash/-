extends "res://tests/current523_aden_source_main_test.gd"
## Actual Main smoke for a caller-pinned generic native Land. Private inputs only.
var source_sha: String
var tile_sha: String
var phase_name: String="entry"
var expected_path: String="user://current523-generic-main-expected.json"

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-root="): raw_root=argument.trim_prefix("--source-root=")
		if argument.begins_with("--tile-root="): tile_root=argument.trim_prefix("--tile-root=")
		if argument.begins_with("--source-sha="): source_sha=argument.trim_prefix("--source-sha=")
		if argument.begins_with("--tile-sha="): tile_sha=argument.trim_prefix("--tile-sha=")
		if argument.begins_with("--phase="): phase_name=argument.trim_prefix("--phase=")
	world=(load("res://Main.tscn") as PackedScene).instantiate(); root.add_child(world)
	print("CURRENT523_GENERIC_MAIN_PROGRESS scene_ready ",Time.get_ticks_msec())
	world.set_process(false); world.save_timer=-100000.0
	check(QA.enter_game(world),"ordinary Main class entry")
	print("CURRENT523_GENERIC_MAIN_PROGRESS ordinary_entry ",Time.get_ticks_msec())
	world.player.set_physics_process(false); world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	if phase_name=="reconnect":
		await frames()
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expected_path))
		check(world.current523_aden_source_active(),"new process restores generic source session")
		if world.current523_aden_source_active():
			check(world.field_map.definition.source_map_id==1 and world.field_map.source_asset=="1/","reconnect retains logical Land identity and literal asset")
			check(state()==saved.protected,"reconnect preserves items currency collections and bosses")
			check(FileAccess.get_sha256(world.save_path())==saved.save_sha,"reconnect preserves existing save bytes")
			check(world.field_map.coordinates.source_components(world.player.global_position)==saved.position,"reconnect restores exact own source cursor")
			capture("generic-land1-reconnect")
		await finish_generic(); return
	world.gold=523081
	check(world._save_game(true)==OK,"baseline Main save")
	var protected: Dictionary=state()
	var old_field=world.field_map
	var old_position: Vector2=world.player.global_position
	var save_sha: String=FileAccess.get_sha256(world.save_path())
	world.hud.call("open_settings_info",true); await frames()
	var panel=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel!=null,"generic map controls open inside actual settings")
	if panel==null: await finish_generic(); return
	panel.raw_path_edit.text=raw_root; panel.tile_path_edit.text=tile_root
	panel.play_profile.select(3); panel.source_manifest.text=source_sha; panel.tile_manifest.text=tile_sha
	panel._reload_native_lands(1)
	check(panel.native_land_choice.item_count==997 and panel.native_land_choice.get_selected_id()==1,"UI lists997 classified normal logical Lands and selects1")
	var list_text: String=""
	for index: int in panel.native_land_choice.item_count:
		if panel.native_land_choice.get_item_id(index) in [0,12156]: list_text+=str(panel.native_land_choice.get_item_id(index))+";"
	check(list_text.contains("0;") and list_text.contains("12156;"),"shared native Asset0 retains separate logical Lands")
	panel.source_entry_enabled.button_pressed=true
	panel.source_entry_x.value=32668; panel.source_entry_y.value=32803
	panel.source_words.text="1"
	panel.play_button.pressed.emit()
	check(not world.current523_aden_source_active() and world.field_map==old_field and world.player.global_position==old_position,"denied generic entry preserves host field and actor")
	check(FileAccess.get_sha256(world.save_path())==save_sha,"failed generic entry preserves actual save")
	panel.source_words.text="0,4,8,12,32"; panel.play_button.pressed.emit(); await frames()
	check(world.current523_aden_source_active(),"UI opens generic Land1: "+world.current523_aden_play_problem)
	if not world.current523_aden_source_active(): await finish_generic(); return
	var source=world.field_map
	check(source.has_meta("current523_generic_field") and source.definition.source_map_id==1 and source.source_asset=="1/","actual field uses native logical1 and exact1/ source")
	check(source.source_chunk_origins().size()==12,"all12Land1 S32 share common movement field")
	var geographic: Dictionary=world.current523_source_geographic_contract()
	check(geographic.geographic_contract=="CURRENT523_S32_OWN_SOURCE_FIELD_V1" and geographic.native_land_id==1 and geographic.native_asset_path=="1/" and geographic.source_manifest_sha256==source_sha and not geographic.native_m_rules_verified,"common geographic contract identifies actual source field")
	geographic.native_land.ID=-1
	check(source.native_land.ID==1,"geographic contract cannot mutate original Land")
	var exact: Dictionary=source.choose_source_landing([32668,32803,32668,32803])
	check(exact.ok and exact.source_cell==Vector2i(32668,32803),"exact landing requires confirmed original cell")
	var area: Dictionary=source.choose_source_landing([32668,32803,32669,32804])
	check(not area.ok and area.reason=="area_target_requires_explicit_own_policy","declared area needs an explicit own landing policy")
	area=source.choose_source_landing([32668,32803,32669,32804],"OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1")
	check(area.ok and not area.native_landing_rule_verified and area.source_cell==Vector2i(32668,32803),"own landing searches only original region and retains provenance")
	check(not source.choose_source_landing([32669,32803,32668,32804]).ok and not source.choose_source_landing([32668,32803,32668,32803],"UNKNOWN").ok,"invalid region and policy reject safely")
	print("CURRENT523_GENERIC_MAIN_PROGRESS source_entered ",Time.get_ticks_msec())
	check(source.chunk_table.is_empty() and source.packs.is_empty() and source.nav_cache.is_empty(),"generic field consumes no legacy navigation shards")
	check(world.field_minimap.field==source and not world.monsters_root.visible,"minimap uses source field and retained legacy actors stay paused")
	check(world.current523_aden_source_portals().is_empty(),"Aden portal catalog is not copied into another native Land")
	check(source.source_cell_info(Vector2i(32668,32803)).raw_pair==[0,0],"nativePortal1101 source cell retains raw attribute pair")
	capture("generic-land1-native1101-source")
	check(await walk(source_point(32667,32803)),"actual player walks on native Land1 source terrain")
	var before_block: Vector2=world.player.global_position
	var blocked: Vector2=source_point(32666,32803)
	check(not source.walkable(blocked) and world.find_world_path(before_block,blocked).is_empty(),"source raw pair1,1 rejects blocked target")
	world.player.touch_vector=before_block.direction_to(blocked); world.player.set_physics_process(true)
	var crossed: bool=false
	for _tick: int in range(24):
		await physics_frame
		if source.world_to_cell(world.player.global_position)+source.coordinates.origin==Vector2i(32666,32803): crossed=true
	world.player.set_physics_process(false); world.player.set_touch_vector(Vector2.ZERO); world.player.velocity=Vector2.ZERO
	check(not crossed,"actual generic movement cannot cross refused source cell")
	check(await walk(source_point(32668,32804)),"player can leave blocked edge along valid source cells")
	var outside: Vector2=source.coordinates.to_world(Vector2(source.source_bounds.end+Vector2i(2,2)))
	check(not source.walkable(outside) and world.find_world_path(world.player.global_position,outside).is_empty(),"unavailable/outside source region refuses path")
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"movement leaves original progress and stored bytes unchanged")
	var metrics: Dictionary=world.current523_aden_play_metrics()
	check(metrics.native_land_id==1 and metrics.ready_placed_sources==12 and metrics.unresolved_refs==0 and not metrics.native_M_rules_verified,"actual native map render exposes coverage and own collision provenance")
	measurements.append(metrics)
	world.close_current523_aden_play()
	check(world.field_map==old_field and world.player.global_position==old_position and state()==protected,"return restores exact previous field position and protected progress")
	var without_cursor: Dictionary={"navigation_profile":OPTIONS.GENERIC,"source_manifest_sha256":source_sha,"tile_manifest_sha256":tile_sha,"native_land_id":0,"allowed_raw_words":OPTIONS.SOURCE_WORDS.duplicate(),"source_position":[],"portal_contract":""}
	check(not world.open_current523_aden_play(raw_root,tile_root,without_cursor),"different logical Land cannot inherit unrelated saved source coordinate")
	check(world.field_map==old_field and state()==protected,"failed logical switch leaves host progress intact")
	without_cursor.native_land_id=1; without_cursor.source_position=[32668.5,32804.5]
	check(world.open_current523_aden_play(raw_root,tile_root,without_cursor),"same native Land supports explicit safe reentry")
	check(world._save_game(true)==OK,"source runtime saves through retained host field")
	var expected: Dictionary={"protected":state(),"save_sha":FileAccess.get_sha256(world.save_path()),"position":world.field_map.coordinates.source_components(world.player.global_position)}
	var output=FileAccess.open(expected_path,FileAccess.WRITE); output.store_string(JSON.stringify(expected,"",true,true)); output.close()
	await finish_generic()

func finish_generic() -> void:
	print("CURRENT523_GENERIC_MAIN_RESULT ",JSON.stringify({"phase":phase_name,"checks":checks,"failures":failures,"metrics":measurements,"captures":captures,"actual_Main":true,"native_collision_verified":false}))
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
