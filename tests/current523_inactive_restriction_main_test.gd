extends "res://tests/current523_source_portal_walk_main_test.gd"
## Actual source Land47111, genuine definitions, explicit inactive restriction.
const INACTIVE_EXPECTED="user://current523-inactive-restriction-expected.json"

func context_checked() -> Dictionary:
	var context: Dictionary=world.current523_aden_source_portal_context(18111)
	var inactive: Array=context.get("declared_inactive_restrictions",[])
	check(inactive.size()==2 and int(inactive[0].row.ID)==152191 and inactive[0].row.Value==0 and inactive[0].type.UnitID==20 and inactive[0].side=="source" and inactive[1].side=="target","actual typed false restriction is retained at both endpoints")
	var time_held: bool=false; var login_held: bool=false; var false_held: bool=false
	for item: Dictionary in context.get("source_travel_holds",[]):
		time_held=time_held or item.get("table")=="LandTimeLimit"
		login_held=login_held or item.get("type",{}).get("Name")=="BlockLoginEnter"
		false_held=false_held or int(item.get("row",{}).get("ID",-1))==152191
	check(time_held and login_held and not false_held and not context.source_travel_hold.is_empty(),"inactive NoTeleport does not waive time/login/other conditions")
	check(not context.native_definition_contract.activation_known and not context.native_definition_contract.travel_enabled,"native activation remains unverified and disabled")
	return context

func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--source-root="):raw_root=a.trim_prefix("--source-root=")
		if a.begins_with("--tile-root="):tile_root=a.trim_prefix("--tile-root=")
		if a.begins_with("--source-sha="):source_sha=a.trim_prefix("--source-sha=")
		if a.begins_with("--tile-sha="):tile_sha=a.trim_prefix("--tile-sha=")
		if a.begins_with("--phase="):phase_name=a.trim_prefix("--phase=")
	root.size=Vector2i(960,540);root.content_scale_size=Vector2i(960,540)
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"ordinary actual Main entry")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	if phase_name=="reconnect":await reconnect_inactive();return
	check(world._save_game(true)==OK,"baseline save before own QA probes")
	# This probe is an explicitly selected original clear cell, not native admission.
	check(open_generic(47111,Vector2i(32746,32785)),"verified raw clear-cell QA entry")
	if not world.current523_aden_source_active():await finish_inactive();return
	await frames()
	var blocked:=Vector2i(32746,32784)
	var info: Dictionary=world.field_map.source_cell_info(blocked)
	check(not info.walkable and int(info.raw_pair[0])==1 and int(info.raw_pair[1])==0,"original raw[1,0] denied cell unchanged")
	var destination: Vector2=world.field_map.coordinates.to_world(Vector2(blocked))
	check(world.find_world_path(world.player.global_position,destination).is_empty(),"blocked own-policy cell rejects path")
	world.player.set_touch_vector(world.player.global_position.direction_to(destination));world.player.set_physics_process(true)
	var entered: bool=false
	for _tick: int in range(20):
		await physics_frame
		entered=entered or cell_now()==blocked
	world.player.set_physics_process(false);world.player.set_touch_vector(Vector2.ZERO);world.player.velocity=Vector2.ZERO
	check(not entered,"actual physics cannot enter denied cell")
	world.close_current523_aden_play();await frames()
	check(world._save_game(true)==OK,"baseline after ordinary host restoration")
	var protected: Dictionary=state();var save_sha: String=FileAccess.get_sha256(world.save_path());var host_position: Vector2=world.player.global_position
	check(open_generic(47111,Vector2i(32756,32817)),"original clear neighbor of native Portal18111")
	if not world.current523_aden_source_active():await finish_inactive();return
	await frames()
	check(world.get("_current523_source_definition_provider").get_script()==PRODUCTION,"genuine production provider without fixture")
	context_checked()
	var panel: Node=panel_for(18111)
	if panel==null:await finish_inactive();return
	var text: String=panel.source_portal_choice.get_item_text(panel.source_portal_choice.selected)
	check(text.contains("NoTeleport=false") and text.contains("원문 조건 보류"),"actual Settings displays inactive declaration alongside remaining hold")
	var old_ticket: Dictionary=panel.source_portal_choice.get_item_metadata(panel.source_portal_choice.selected)
	check(world.bind_current523_source_portal_provider(world.get("_current523_source_definition_provider"),DEFINITION_PIN),"rebind same genuine provider")
	reject_ticket(18111,old_ticket,"stale preflight generation")
	panel=panel_for(18111);panel.source_portal_walk_button.pressed.emit()
	check(not world.player.click_path.is_empty(),"existing UI queues actual source walk")
	var target: Vector2=world.field_map.coordinates.to_world(Vector2(32756,32818))
	world.player.set_physics_process(true)
	var deadline: int=Time.get_ticks_msec()+6000
	while world.player.global_position.distance_to(target)>6 and Time.get_ticks_msec()<deadline:await physics_frame
	world.player.set_physics_process(false);world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	check(cell_now()==Vector2i(32756,32818) and world.player.global_position.distance_to(target)<=6,"actual physics reaches exact native source")
	world.portal_cooldown=0;world._update_field_triggers();await frames()
	check(world.field_map.native_land.ID==47111 and cell_now()==Vector2i(32756,32818),"walking does not imply automatic activation")
	panel=panel_for(18111);var before: Dictionary=snapshot()
	world.portal_cooldown=0;panel.source_portal_button.pressed.emit();await frames()
	check(world.current523_aden_play_problem.contains("definition_conditions_hold"),"inactive restriction does not authorize held native transition")
	preserved(before,"remaining native restrictions")
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"walk and refused travel preserve progression/save")
	var scroller: Node=panel.get_parent()
	while scroller!=null and not scroller is ScrollContainer: scroller=scroller.get_parent()
	check(scroller is ScrollContainer,"source controls use the real Settings scroller")
	if scroller is ScrollContainer:
		scroller.ensure_control_visible(panel.source_portal_choice)
		await frames()
		check(scroller.get_global_rect().intersects(panel.source_portal_choice.get_global_rect()),"selected declaration is within the actual visible Settings viewport")
	capture("native18111-inactive-restriction-held")
	world.hud.workspace.hide()
	check(world._save_game(true)==OK,"save actual source cursor for new process")
	var expected: Dictionary={"protected":state(),"save_sha":FileAccess.get_sha256(world.save_path()),"position":OPTIONS.read().source_position,"host_position":[host_position.x,host_position.y],"host_map_id":world.active_map_id}
	var file:=FileAccess.open(INACTIVE_EXPECTED,FileAccess.WRITE);file.store_string(JSON.stringify(expected,"",true,true));file.close()
	await finish_inactive()

func reconnect_inactive() -> void:
	await frames()
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INACTIVE_EXPECTED))
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==47111,"new process restores same original native source field")
	if not world.current523_aden_source_active():await finish_inactive();return
	check(world.field_map.coordinates.source_components(world.player.global_position)==expected.position and state()==expected.protected and FileAccess.get_sha256(world.save_path())==expected.save_sha,"new process preserves cursor/progression/save bytes")
	context_checked()
	var before: Dictionary=snapshot()
	check(not world.use_current523_aden_source_portal(18111),"reconnected false declaration cannot bypass remaining holds")
	preserved(before,"reconnected admission hold")
	world.close_current523_aden_play();await frames()
	check(world.active_map_id==expected.host_map_id and world.player.global_position==Vector2(expected.host_position[0],expected.host_position[1]),"safe return to original host location")
	for key: String in expected.protected:
		if key!="bosses":check(state()[key]==expected.protected[key],"protected progression after return: "+key)
	check(returned_bosses(expected.protected.bosses,state().bosses).ok and FileAccess.get_sha256(world.save_path())==expected.save_sha,"host lives and exact durable save preserved")
	await finish_inactive()

func finish_inactive() -> void:
	print("CURRENT523_INACTIVE_RESTRICTION_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"phase":phase_name,"actual_Main":true,"genuine_PR230_binding":true,"native_automatic_activation_verified":false,"captures":captures}))
	if is_instance_valid(world):world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
