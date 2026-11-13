extends "res://tests/current523_generic_portal_main_test.gd"
## Genuine definitions -> existing Settings button -> ordinary player physics.
const PRODUCTION=preload("res://scripts/maps/current523_source_portal_provider.gd")

func movement() -> Dictionary:
	return {"path":world.player.click_path.duplicate(),"index":world.player.path_index,"manual":world.player.manual_navigation,"position":world.player.global_position,"velocity":world.player.velocity}

func reject_ticket(id: int,ticket: Dictionary,label: String) -> void:
	var before: Dictionary=snapshot();var moving: Dictionary=movement()
	check(not world.walk_to_current523_source_portal(id,ticket),label+" rejects")
	preserved(before,label)
	check(movement()==moving,label+" retains queued movement")

func panel_for(id: int) -> Node:
	world.hud.call("open_settings_info",true)
	var panel=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel!=null,"existing Settings source controls")
	if panel==null:return null
	panel._refresh_source_portals();panel._update_open_button()
	for index: int in panel.source_portal_choice.item_count:
		if panel.source_portal_choice.get_item_id(index)==id:panel.source_portal_choice.select(index);return panel
	check(false,"native portal listed: "+str(id));return null

func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--source-root="):raw_root=a.trim_prefix("--source-root=")
		if a.begins_with("--tile-root="):tile_root=a.trim_prefix("--tile-root=")
		if a.begins_with("--source-sha="):source_sha=a.trim_prefix("--source-sha=")
		if a.begins_with("--tile-sha="):tile_sha=a.trim_prefix("--tile-sha=")
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main ordinary entry")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	check(world._save_game(true)==OK,"actual protected baseline save")
	var protected: Dictionary=state();var save_sha: String=FileAccess.get_sha256(world.save_path())
	# This independently checked original neighbor is raw[0,0], not a native
	# admission point. Portal313's declared Source is (32737,32877), Land1.
	check(open_generic(1,Vector2i(32737,32876)),"source Land1 verified neighbor QA entry")
	if not world.current523_aden_source_active():await finish_walk();return
	await frames()
	check(world.get("_current523_source_definition_provider").get_script()==PRODUCTION,"genuine PR230 provider; no TEST provider")
	var context: Dictionary=world.current523_aden_source_portal_context(313)
	check(context.Portal.SourceX==32737 and context.Portal.SourceY==32877 and not context.native_definition_contract.activation_known,"exact native source; native activation remains unknown")
	var panel: Node=panel_for(313)
	if panel==null:await finish_walk();return
	var ticket: Dictionary=panel.source_portal_choice.get_item_metadata(panel.source_portal_choice.selected)
	check(not panel.source_portal_walk_button.disabled and not ticket.is_empty(),"actual walk button has ephemeral current-field request")
	var before: Dictionary=snapshot();var moving: Dictionary=movement()
	world.charge_skill={"test_navigation_guard":true}
	panel.source_portal_walk_button.pressed.emit()
	check(world.current523_aden_play_problem.contains("현재 이동 상태") and movement()==moving,"actual UI refuses active charge without replacing movement")
	preserved(before,"charge guard");world.charge_skill.clear()
	var old_position: Vector2=world.player.global_position
	world.player.global_position+=Vector2(0.125,0)
	reject_ticket(313,ticket,"actor moved after request issuance")
	world.player.global_position=old_position
	var provider: RefCounted=world.get("_current523_source_definition_provider")
	check(world.bind_current523_source_portal_provider(provider,DEFINITION_PIN),"same provider can be explicitly rebound")
	reject_ticket(313,ticket,"definition generation changed without changing the actor")
	panel=panel_for(313)
	ticket=panel.source_portal_choice.get_item_metadata(panel.source_portal_choice.selected)
	var old_field_ticket: Dictionary=ticket.duplicate(true)
	var prefs_sha: String=FileAccess.get_sha256(OPTIONS.PATH)
	panel.source_portal_walk_button.pressed.emit()
	check(not world.player.click_path.is_empty() and world.player.manual_navigation and not world.hud.workspace.visible,"actual Settings action queues a walking path and closes the panel")
	var target: Vector2=world.field_map.coordinates.to_world(Vector2(32737,32877))
	world.player.set_physics_process(true)
	var deadline: int=Time.get_ticks_msec()+6000
	while world.player.global_position.distance_to(target)>6 and Time.get_ticks_msec()<deadline:await physics_frame
	world.player.set_physics_process(false);world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	check(world.player.global_position.distance_to(old_position)>1 and world.player.global_position.distance_to(target)<=6 and cell_now()==Vector2i(32737,32877),"actual player physics reaches the exact declared source cell")
	world.portal_cooldown=0;world._update_field_triggers()
	await frames()
	check(world.field_map.native_land.ID==1 and world.current523_aden_source_active(),"arrival performs no automatic activation or destination transition")
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha and FileAccess.get_sha256(OPTIONS.PATH)==prefs_sha,"walking changes no progression, stored save or source checkpoint")
	reject_ticket(313,world.current523_source_portal_navigation_ticket(313),"already at the declared source cell")
	capture("source-portal313-physical-arrival")
	world.close_current523_aden_play();await frames()
	check(open_generic(1,Vector2i(32737,32876)),"reopen same Land at exactly the previous request position")
	await frames()
	check(world.player.global_position==old_field_ticket.actor_position,"lifecycle rejection is not merely a changed-position rejection")
	reject_ticket(313,old_field_ticket,"old field instance after close/reopen")
	world.close_current523_aden_play();await frames()
	check(open_generic(807,Vector2i(32739,32806)),"actual807 source field")
	await frames()
	context=world.current523_aden_source_portal_context(523)
	var blocked:=Vector2i(int(context.Portal.SourceX),int(context.Portal.SourceY))
	check(not world.field_map.source_cell_info(blocked).walkable,"native523 source cell remains blocked by the unchanged own policy")
	var route: PackedVector2Array=world.find_world_path(world.player.global_position,world.field_map.coordinates.to_world(Vector2(32739,32805)))
	world.player.set_manual_click_path(route,route[route.size()-1])
	reject_ticket(523,world.current523_source_portal_navigation_ticket(523),"blocked source endpoint")
	reject_ticket(523,{},"missing request identity")
	world.close_current523_aden_play();await frames()
	for key: String in protected:
		if key!="bosses":check(state()[key]==protected[key],"protected state after all navigation guards: "+key)
	check(returned_bosses(protected.bosses,state().bosses).ok and FileAccess.get_sha256(world.save_path())==save_sha,"host lives and durable save bytes preserved")
	await finish_walk()

func finish_walk() -> void:
	print("CURRENT523_SOURCE_PORTAL_WALK_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_Main":true,"genuine_PR230_binding":true,"native_automatic_activation_verified":false,"captures":captures}))
	if is_instance_valid(world):world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
