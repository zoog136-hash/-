extends "res://tests/current523_generic_portal_main_test.gd"
## Actual complete Aden walk under the existing OWN rule, not native collision proof.
const CHECKPOINT="user://current523-long-route-expected.json"
var proof_path: String
var proof: Dictionary
var panel: Node

func controls() -> Node:
	world.hud.call("open_settings_info",true)
	var result=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(result!=null,"existing Settings controls")
	return result

func open_from_ui(budget: int) -> bool:
	panel=controls()
	if panel==null:return false
	panel.play_profile.select(3)
	panel.raw_path_edit.text=raw_root;panel.tile_path_edit.text=tile_root
	panel.source_manifest.text=source_sha;panel.tile_manifest.text=tile_sha
	panel._reload_native_lands(4)
	panel.source_entry_enabled.button_pressed=true
	panel.source_entry_x.value=32939;panel.source_entry_y.value=32283
	panel.source_search_limit.value=budget
	panel.play_button.pressed.emit()
	return world.current523_aden_source_active()

func select_portal(id: int) -> bool:
	panel=controls()
	if panel==null:return false
	panel._refresh_source_portals();panel._update_open_button()
	for index: int in panel.source_portal_choice.item_count:
		if panel.source_portal_choice.get_item_id(index)==id:panel.source_portal_choice.select(index);return true
	check(false,"declared portal absent: "+str(id));return false

func movement() -> Dictionary:
	return {"path":world.player.click_path.duplicate(),"index":world.player.path_index,"manual":world.player.manual_navigation,"position":world.player.global_position}

func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--source-root="):raw_root=a.trim_prefix("--source-root=")
		if a.begins_with("--tile-root="):tile_root=a.trim_prefix("--tile-root=")
		if a.begins_with("--source-sha="):source_sha=a.trim_prefix("--source-sha=")
		if a.begins_with("--tile-sha="):tile_sha=a.trim_prefix("--tile-sha=")
		if a.begins_with("--phase="):phase_name=a.trim_prefix("--phase=")
		if a.begins_with("--route-proof="):proof_path=a.trim_prefix("--route-proof=")
	check(FileAccess.get_sha256(proof_path)=="4000d53e60a48cfd7a87dd6895ba6ea5f2d5b5b3d097ad10a5bced731e469e40","independent pinned original endpoint byte proofs")
	proof=JSON.parse_string(FileAccess.get_file_as_string(proof_path))
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main entry")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	if phase_name=="reconnect":await reconnect_route();return
	check(world._save_game(true)==OK,"isolated original save")
	check(open_from_ui(8192),"actual UI opens default search budget")
	if not world.current523_aden_source_active():await finish_route();return
	await frames()
	check(world.field_map.policy.path_search_limit==8192 and not panel.source_search_limit.editable,"original default retained; live-policy edits disabled")
	for endpoint: Dictionary in proof.endpoints:
		var info: Dictionary=world.field_map.source_cell_info(Vector2i(endpoint.source_cell[0],endpoint.source_cell[1]))
		var raw_pair: Array=[int(endpoint.raw_pair[0]),int(endpoint.raw_pair[1])]
		var floor_pair: Array=[int(endpoint.floor_pair[0]),int(endpoint.floor_pair[1])]
		check(info.source_sha256==endpoint.original_sha256 and info.member==endpoint.member and info.raw_pair==raw_pair and info.floor_pair==floor_pair,"independent original endpoint identity: "+str(endpoint.member))
	check(select_portal(1481),"genuine target Source appears in UI")
	var old_ticket: Dictionary=panel.source_portal_choice.get_item_metadata(panel.source_portal_choice.selected)
	var before: Dictionary=snapshot();var moving: Dictionary=movement()
	panel.source_portal_walk_button.pressed.emit()
	check(world.current523_aden_play_problem.contains("확인된 보행 경로") and movement()==moving,"default budget safely refuses the long route without changing movement")
	preserved(before,"default search budget")
	check(not world.apply_current523_aden_play_options({"path_search_limit":65536}),"live search policy changes require validated reentry")
	preserved(before,"rejected live budget update")
	world.close_current523_aden_play();await frames()
	check(world._save_game(true)==OK,"explicit host baseline after healthy life restoration")
	var protected: Dictionary=state();var save_sha: String=FileAccess.get_sha256(world.save_path())
	check(open_from_ui(65536),"actual UI selects a bounded larger OWN budget")
	if not world.current523_aden_source_active():await finish_route();return
	await frames()
	check(world.field_map.policy.path_search_limit==65536 and OPTIONS.read().path_search_limit==65536,"field and preferences use selected search budget")
	before=snapshot();moving=movement()
	check(not world.walk_to_current523_source_portal(1481,old_ticket) and movement()==moving,"old request from the previous field is stale")
	preserved(before,"old field request")
	check(select_portal(1481),"fresh actual UI navigation request")
	panel.source_portal_walk_button.pressed.emit()
	var route: PackedVector2Array=world.player.click_path.duplicate()
	var prior: Vector2=world.player.global_position
	var target: Vector2=world.field_map.coordinates.to_world(Vector2(33139,33358))
	var segments_clear: bool=not route.is_empty()
	for next: Vector2 in route:
		if not world.field_map.line_clear(prior,next):segments_clear=false;break
		prior=next
	check(route.size()>=1000 and route[-1]==target and segments_clear,"complete long route retains every original OWN collision edge and exact goal")
	var visited_cells: Dictionary={};var visited_members: Dictionary={};var denied: bool=false
	var began: int=Time.get_ticks_msec();var deadline: int=began+450000;var report_at: int=began
	world.player.set_physics_process(true)
	while world.current523_aden_source_active() and world.player.global_position.distance_to(target)>6 and Time.get_ticks_msec()<deadline:
		await physics_frame
		if not world.current523_aden_source_active():break
		var cell: Vector2i=cell_now()
		if not visited_cells.has(cell):
			var info: Dictionary=world.field_map.source_cell_info(cell)
			if not info.walkable:denied=true
			visited_cells[cell]=true;visited_members[info.get("member","")]=true
		if Time.get_ticks_msec()>=report_at:
			print("CURRENT523_LONG_ROUTE_PROGRESS ",JSON.stringify({"seconds":(Time.get_ticks_msec()-began)/1000.0,"path_index":world.player.path_index,"points":route.size(),"source_cell":[cell.x,cell.y],"visited_source_members":visited_members.size()}));report_at=Time.get_ticks_msec()+15000
	world.player.set_physics_process(false);world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==4,"whole walk retains the actual source field")
	if not world.current523_aden_source_active():await finish_route();return
	check(world.player.global_position.distance_to(target)<=6 and cell_now()==Vector2i(33139,33358) and not denied,"entire route physically walked; no denied cell entered")
	world.portal_cooldown=0;world._update_field_triggers();await frames()
	check(world.field_map.native_land.ID==4,"arrival does not infer automatic portal activation")
	measurements.append({"route_points":route.size(),"walk_seconds":(Time.get_ticks_msec()-began)/1000.0,"visited_cells":visited_cells.size(),"visited_original_members":visited_members.size(),"entered_denied_cell":denied,"full_physical_route_completed":world.player.global_position.distance_to(target)<=6})
	capture("Aden-complete-long-source-route")
	var arrival: Vector2=world.player.global_position
	# Explicit QA positioning only, separate from the complete physical route.
	world.player.global_position=world.field_map.coordinates.to_world(Vector2(32316,33595))
	var blocked:=Vector2i(32316,33594)
	var blocked_point: Vector2=world.field_map.coordinates.to_world(Vector2(blocked))
	check(not world.field_map.source_cell_info(blocked).walkable and world.find_world_path(world.player.global_position,blocked_point).is_empty(),"larger search budget never permits a blocked original edge")
	world.player.set_touch_vector(world.player.global_position.direction_to(blocked_point));world.player.set_physics_process(true)
	var entered: bool=false
	for _tick: int in range(20):await physics_frame;entered=entered or cell_now()==blocked
	world.player.set_physics_process(false);world.player.set_touch_vector(Vector2.ZERO);world.player.velocity=Vector2.ZERO
	check(not entered,"actual blocked-edge physics remains enforced")
	world.player.global_position=arrival;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll();world.field_renderer.refresh_visible();await frames()
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"long walking and blocked probe preserve progress and original save bytes")
	check(world._save_game(true)==OK,"actual save retains the larger search choice with separate source cursor")
	var options: Dictionary=OPTIONS.read();var file:=FileAccess.open(CHECKPOINT,FileAccess.WRITE)
	file.store_string(JSON.stringify({"protected":state(),"save_sha":FileAccess.get_sha256(world.save_path()),"source_position":options.source_position,"pixel_position":[arrival.x,arrival.y]},"",true,true));file.close()
	await finish_route()

func reconnect_route() -> void:
	await frames()
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CHECKPOINT))
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==4 and world.field_map.policy.path_search_limit==65536,"new process restores source Land and bounded search budget")
	if not world.current523_aden_source_active():await finish_route();return
	check(world.player.global_position==Vector2(expected.pixel_position[0],expected.pixel_position[1]) and cell_now()==Vector2i(33139,33358),"new process restores exact physical arrival")
	check(state()==expected.protected and FileAccess.get_sha256(world.save_path())==expected.save_sha,"new process preserves exact progress and save bytes")
	world.close_current523_aden_play();await frames()
	check(world.open_current523_aden_play(raw_root,tile_root,{"navigation_profile":OPTIONS.GENERIC,"source_manifest_sha256":source_sha,"tile_manifest_sha256":tile_sha,"native_land_id":1,"source_position":[32668.5,32803.5],"path_search_limit":65536}),"existing source travel uses selected larger budget")
	await frames();world.portal_cooldown=0
	check(world.use_current523_aden_source_portal(1101),"genuine manual1101 contract still crosses source fields")
	check(world.field_map.native_land.ID==0 and world.field_map.policy.path_search_limit==65536 and OPTIONS.read().path_search_limit==65536,"source-field transition carries the same complete own policy")
	check(FileAccess.get_sha256(world.save_path())==expected.save_sha,"source transition retains durable game save")
	world.close_current523_aden_play();await frames()
	for key: String in expected.protected:
		if key!="bosses":check(state()[key]==expected.protected[key],"protected state after reconnect/return: "+key)
	check(returned_bosses(expected.protected.bosses,state().bosses).ok,"host lives preserved after reconnect/return")
	await finish_route()

func finish_route() -> void:
	print("CURRENT523_LONG_SOURCE_ROUTE_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"phase":phase_name,"actual_Main":true,"measurements":measurements,"native_collision_verified":false,"native_automatic_activation_verified":false,"captures":captures}))
	if is_instance_valid(world):world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
