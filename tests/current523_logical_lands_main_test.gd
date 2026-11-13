extends "res://tests/current523_all_regions_main_test.gd"
## Only remaining logical identities; existing577 geometry proof is reused.
const PRODUCTION=preload("res://scripts/maps/current523_source_portal_provider.gd")
const OWNER=preload("res://scripts/maps/patch523_world_links.gd")
var panel: Node
var previous_field: RefCounted
var previous_ticket: Dictionary={}
var previous_portal_id: int=-1
var checked_ids: Array[int]=[]

func selected_entry(row: Dictionary) -> bool:
	var index: int=-1
	for n: int in panel.native_land_choice.item_count:
		if panel.native_land_choice.get_item_id(n)==int(row.land.ID):index=n;break
	check(index>=0,"actual Settings lists logical Land "+str(row.land.ID))
	if index<0:return false
	panel.native_land_choice.select(index);panel.native_land_choice.item_selected.emit(index)
	check(not panel.source_entry_enabled.button_pressed,"changing logical identity clears implicit old cursor")
	panel.source_entry_enabled.button_pressed=true
	panel.source_entry_x.value=row.entry.source_cell[0];panel.source_entry_y.value=row.entry.source_cell[1]
	panel._update_open_button()
	check(not panel.play_button.disabled,"actual Settings QA entry is available")
	panel.play_button.pressed.emit()
	return world.current523_aden_source_active()

func verify_context(row: Dictionary) -> Dictionary:
	var provider: RefCounted=world.get("_current523_source_definition_provider")
	check(provider!=null and provider.get_script()==PRODUCTION,"genuine provider for selected logical identity")
	if provider==null:return {}
	var owner: RefCounted=provider._definition(int(row.land.ID),row.asset_path)
	check(owner!=null and owner.get_script()==OWNER and owner.land==row.land,"owning shard follows logical Land rather than physical root")
	if owner==null:return {}
	var counts: Dictionary={}
	for table: String in row.conditions:
		var selected: Array=[]
		for raw: Dictionary in owner.context_rows(table):
			if int(raw.get("LandID",raw.get("LandId",-1)))==int(row.land.ID):selected.append(raw)
		check(selected==row.conditions[table],"complete raw logical conditions: "+table)
		counts[table]=selected.size()
	var evidence: Array=provider.portal_evidence_for_land(int(row.land.ID),row.asset_path)
	check(evidence==row.expected_portals,"all own Portal declarations stay distinct from shared-root siblings")
	check(world.current523_aden_source_portal_context(313).is_empty(),"foreign logical Portal313 is not inherited by sharing geometry")
	var evaluation: Dictionary=provider._attribute_evaluation(owner,int(row.land.ID),pcell(row.entry.source_cell))
	for key: String in ["holds","declared_inactive"]:
		for item: Dictionary in evaluation[key]:check(int(item.row.LandID)==int(row.land.ID),"attribute evaluation contains only selected logical identity")
	for portal: Dictionary in evidence:
		var context: Dictionary=world.current523_aden_source_portal_context(int(portal.ID))
		check(not context.is_empty() and context.Portal==portal and context.SourceLand==row.land and not context.native_definition_contract.activation_known and not context.native_definition_contract.travel_enabled,"exact genuine Portal context retains source and unknown activation")
	check(panel.source_portal_choice.item_count==evidence.size(),"actual UI contains exactly this logical Land's portals")
	return {"condition_counts":counts,"portal_IDs":evidence.map(func(p):return int(p.ID)),"attribute_holds":evaluation.holds,"inactive_restrictions":evaluation.declared_inactive,"owner_shard_SHA256":row.owner_shard_sha256}

func audit_logical(row: Dictionary,index: int) -> Dictionary:
	var before_failures: int=failures.size();var begun: int=Time.get_ticks_msec()
	var id: int=int(row.land.ID)
	var record: Dictionary={"index":index,"land_id":id,"asset_path":row.asset_path,"physical_representative_land_id":row.representative_land_id,"QA_entry_role":row.QA_entry_role,"native_admission_verified":false,"native_collision_verified":false}
	var protected: Dictionary=state();var save_sha: String=FileAccess.get_sha256(world.save_path())
	if not selected_entry(row):
		check(false,"supported-cell logical entry: "+world.current523_aden_play_problem)
		record.status="ENTRY_FAILED";return record
	await frames()
	if not world.current523_aden_source_active():check(false,"logical frame stays active");record.status="FRAME_SAFE_RETURN";return record
	var field=world.field_map
	check(field.native_land==row.land and field.definition.source_map_id==id and field.data.map_id=="m523_land_"+str(id) and field.source_asset==row.asset_path,"exact logical identity in active field/data/physical namespace")
	check(field!=previous_field and field.chunk_table.is_empty() and field.nav_cache.is_empty() and field.packs.is_empty(),"new logical field owns independent state without old navigation inputs")
	check(panel.native_land_choice.get_selected_id()==id and world.field_minimap.field==field and world.hud.v20_map_name.text.contains("Land"+str(id)),"Settings selection, HUD and minimap follow selected logical identity")
	var raw: Dictionary=field.source_cell_info(pcell(row.entry.source_cell))
	check(raw.source_sha256==row.entry.source_sha256 and value_pair(raw.raw_pair,row.entry.raw_pair),"reused physical QA cell still reads exact original bytes")
	record.definition_context=verify_context(row)
	if not previous_ticket.is_empty():
		var before: Dictionary=snapshot()
		record.stale_prior_actor_position_equal=previous_ticket.actor_position==world.player.global_position
		check(not world.walk_to_current523_source_portal(previous_portal_id,previous_ticket),"prior logical request is refused")
		preserved(before,"prior logical request")
	var ticket: Dictionary={};var portal_id: int=-1
	if not row.expected_portals.is_empty():
		portal_id=int(row.expected_portals[0].ID);ticket=world.current523_source_portal_navigation_ticket(portal_id)
		check(not ticket.is_empty(),"existing logical Portal has a real current-field request")
	check(await walk(wp(row.clear_neighbor.source_cell)),"actual supported-cell logical movement")
	check(await position_probe(row.wall_probe.stand.source_cell),"explicit own QA wall probe")
	check(await blocked_motion(row.wall_probe.blocked.source_cell),"unchanged original own-policy blocked motion")
	check(not field.walkable(wp(row.outside_cell)) and world.find_world_path(world.player.global_position,wp(row.outside_cell)).is_empty(),"outside shared geometry remains refused")
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"logical probes preserve progress and stored save")
	var metrics: Dictionary=world.current523_aden_play_metrics()
	check(metrics.native_land_id==id and metrics.unresolved_refs==0 and metrics.budget_skips==0,"current logical frame remains complete")
	var image: Image=root.get_texture().get_image()
	check(image!=null and not image.is_empty(),"actual logical Main frame readback")
	if image!=null:record.actual_frame_RGBA_SHA256=SOURCE_PACK._hash(image.get_data())
	check(world._save_game(true)==OK,"save selected logical source cursor")
	var saved: Dictionary=OPTIONS.read();var position: Vector2=world.player.global_position
	check(int(saved.native_land_id)==id and field.coordinates.components_to_world(saved.source_position)==position,"saved logical identity and exact world pose")
	var saved_sha: String=FileAccess.get_sha256(world.save_path());var prefs_sha: String=FileAccess.get_sha256(OPTIONS.PATH)
	world.close_current523_aden_play(false)
	check(world.field_map==host_field and world.player.global_position==host_position and protected_except_initial_host_lives(protected),"return from logical identity preserves host/progress")
	var returned: Dictionary=state()
	check(not open_generic(id,pcell(row.wall_probe.blocked.source_cell)),"failed denied-cell entry remains refused for this logical identity")
	check(world.field_map==host_field and world.player.global_position==host_position and FileAccess.get_sha256(world.save_path())==saved_sha and FileAccess.get_sha256(OPTIONS.PATH)==prefs_sha and state()==returned,"failed logical entry preserves host and both durable files")
	world._restore_current523_aden_play();await frames()
	check(world.current523_aden_source_active() and world.field_map.native_land==row.land and world.player.global_position==position,"real reentry restores exact logical identity and pose after failure")
	if world.current523_aden_source_active():
		check(state()==returned and FileAccess.get_sha256(world.save_path())==saved_sha,"logical reentry preserves save/progression")
		if not ticket.is_empty():
			var before: Dictionary=snapshot()
			check(not world.walk_to_current523_source_portal(portal_id,ticket),"old same-logical field request refuses after teardown/reentry")
			preserved(before,"same-logical stale request")
		var provider: RefCounted=world.get("_current523_source_definition_provider")
		check(provider._definition(id,row.asset_path).land==row.land and provider.cache_metrics().cached_native_lands<=4,"reentry retains correct bounded definition cache")
	previous_field=world.field_map
	world.close_current523_aden_play();await frames()
	check(world.field_map==host_field and world.player.global_position==host_position and protected_except_initial_host_lives(returned) and FileAccess.get_sha256(world.save_path())==saved_sha,"restored logical identity safely returns")
	previous_ticket=ticket;previous_portal_id=portal_id
	record.status="PASS" if failures.size()==before_failures else "ASSERTION_FAILURE"
	record.failures=failures.slice(before_failures);record.seconds=(Time.get_ticks_msec()-begun)/1000.0
	record.actual_save_reentry="ACTUAL_METHOD_AFTER_TEARDOWN; NOT_NEW_OS_PROCESS"
	record.save_sha256=saved_sha;record.position=[position.x,position.y]
	return record

func run() -> void:
	started=Time.get_ticks_msec();raw_root=_arg("--source-root=");tile_root=_arg("--tile-root=");source_sha=_arg("--source-sha=");tile_sha=_arg("--tile-sha=")
	cases_path=_arg("--cases=");cases_pin=_arg("--cases-sha=");progress_path=_arg("--progress=")
	first_index=int(_arg("--start="));max_regions=int(_arg("--limit="))
	check(FileAccess.get_sha256(cases_path)==cases_pin and max_regions>0 and first_index>=0 and first_index+max_regions<=420,"bounded new logical case slice and SHA")
	var cases: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(cases_path))
	check(cases.cases.size()==420 and cases.prior_577_play_IDs.size()==577 and cases.source_manifest_sha256==source_sha,"exact previously-unchecked logical scope")
	progress=FileAccess.open(progress_path,FileAccess.WRITE);check(progress!=null,"new local progress sink")
	if not failures.is_empty():finish_logical();return
	root.size=Vector2i(640,360);root.content_scale_size=Vector2i(640,360)
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"ordinary actual Main entry")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	check(world._save_game(true)==OK,"isolated baseline save")
	host_field=world.field_map;host_position=world.player.global_position;initial_progress=state()
	world.hud.call("open_settings_info",true);await frames()
	panel=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel!=null,"actual Settings for logical selection")
	if panel==null:finish_logical();return
	panel.raw_path_edit.text=raw_root;panel.tile_path_edit.text=tile_root;panel.source_manifest.text=source_sha;panel.tile_manifest.text=tile_sha
	panel.play_profile.select(3);panel._reload_native_lands()
	check(panel.native_land_choice.item_count==997,"actual UI includes all997 ordinary logical identities")
	for index: int in range(first_index,first_index+max_regions):
		if Time.get_ticks_msec()-started>1800000:check(false,"bounded logical batch time limit");break
		var row: Dictionary=cases.cases[index]
		check(int(row.land.ID) not in cases.prior_577_play_IDs,"do not repeat completed physical representative")
		print("CURRENT523_LOGICAL_LAND_BEGIN ",index," ",row.land.ID," ",row.asset_path)
		var record: Dictionary=await audit_logical(row,index)
		progress.store_line(JSON.stringify(record));progress.flush();attempted+=1
		if record.status=="PASS":passed+=1;checked_ids.append(int(row.land.ID))
		print("CURRENT523_LOGICAL_LAND_PROGRESS ",JSON.stringify({"index":index,"land_id":row.land.ID,"status":record.status,"passed":passed,"seconds":record.get("seconds",0)}))
		if not failures.is_empty():break
		if attempted%70==0:print("CURRENT523_LOGICAL_BATCH_CHECKPOINT ",JSON.stringify({"actual_checked_IDs":checked_ids,"attempted":attempted,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0}))
	var cache: Dictionary=world.get("_current523_aden_play_controller").input_cache_metrics()
	check(cache.source_catalog_loads==1 and cache.tile_catalog_loads==1 and panel._native_catalog_loads==1,"reuse both runtime and UI immutable catalogs across logical entries")
	var cached: RefCounted=panel._native_catalog
	var protected_snapshot: Dictionary=state();var final_save_sha: String=FileAccess.get_sha256(world.save_path())
	panel.source_manifest.text="0".repeat(64);panel._reload_native_lands()
	check(panel._native_catalog==cached and panel._native_catalog_loads==1 and panel.native_land_choice.item_count==0,"wrong UI pin refuses listing without replacing valid parsed identity")
	panel.source_manifest.text=source_sha;panel.raw_path_edit.text="/missing/rejected-logical-catalog";panel._reload_native_lands()
	check(panel._native_catalog==cached and panel._native_catalog_loads==1 and panel.native_land_choice.item_count==0,"missing UI candidate preserves the valid immutable cache")
	panel.raw_path_edit.text=raw_root;panel._reload_native_lands()
	check(panel.native_land_choice.item_count==997 and panel._native_catalog_loads==1 and world.field_map==host_field and state()==protected_snapshot and FileAccess.get_sha256(world.save_path())==final_save_sha,"valid UI cache recovers without reparse or changing host/save")
	check(protected_except_initial_host_lives(initial_progress),"all logical visits preserve original progress and host lives")
	finish_logical()

func finish_logical() -> void:
	if is_instance_valid(world):world.queue_free()
	print("CURRENT523_LOGICAL_LANDS_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"attempted":attempted,"passed":passed,"actual_checked_logical_IDs":checked_ids,"actual_Main":true,"new_OS_process_per_Land":false,"native_admission_or_collision_verified":false,"first_index":first_index,"requested":max_regions,"seconds":(Time.get_ticks_msec()-started)/1000.0}))
	quit(0 if failures.is_empty() and attempted==max_regions and passed==attempted else 1)
