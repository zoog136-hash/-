extends "res://tests/current523_source_portal_walk_main_test.gd"
## Actual current523 input while moving; existing original probes, no new rules.
const COORD=preload("res://scripts/maps/world_coordinates.gd")
const QUALITY_EXPECTED="user://current523-movement-interrupt-expected.json"
var reproduce: bool=false
var observations: Array=[]
func ticks(count: int) -> void:
	world.player.set_physics_process(true)
	for _i: int in range(count):await physics_frame
	world.player.set_physics_process(false)
func source_open(id: int,point: Vector2i,budget: int=8192) -> bool:
	return world.open_current523_aden_play(raw_root,tile_root,{"navigation_profile":OPTIONS.GENERIC,"source_manifest_sha256":source_sha,"tile_manifest_sha256":tile_sha,"native_land_id":id,"source_position":[point.x+0.5,point.y+0.5],"path_search_limit":budget})
func world_point(point: Vector2i) -> Vector2:return world.field_map.coordinates.to_world(Vector2(point))
func gesture() -> Dictionary:
	world.hud.workspace.hide()
	var input: Node=world.world_interactions
	input.cancel_gesture()
	for y: int in [160,200,240]:
		for x: int in [320,400,240]:
			var point:=Vector2(x,y)
			if world.hud.blocks_world_input(point):continue
			var press:=InputEventScreenTouch.new();press.index=0;press.position=point;press.pressed=true
			input.begin(press)
			if input.pointer==0:return {"point":point,"map":world.active_map_id}
	check(false,"real world touch can begin");return {}
func release_gesture(info: Dictionary) -> void:
	if info.is_empty():return
	var release:=InputEventScreenTouch.new();release.index=0;release.position=info.point;release.pressed=false
	world.world_interactions._input(release)
func stopped_click(goal: Vector2,label: String) -> void:
	world._set_click_destination(goal)
	var position: Vector2=world.player.global_position
	var remaining: int=world.player.click_path.size()
	check(world.player.click_path.is_empty() and not world.player.manual_navigation and world.player.velocity==Vector2.ZERO,label+" stops the superseded source route immediately")
	await ticks(8)
	check(world.player.global_position==position,label+" does not keep walking to the previous target")
	observations.append({"kind":label,"remaining_path_points_after_click":remaining,"continued_distance":world.player.global_position.distance_to(position)})
	if not reproduce:check(world.hud.message_label.text.contains("확인된 보행 경로"),label+" has visible refusal feedback")
func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--source-root="):raw_root=a.trim_prefix("--source-root=")
		if a.begins_with("--tile-root="):tile_root=a.trim_prefix("--tile-root=")
		if a.begins_with("--source-sha="):source_sha=a.trim_prefix("--source-sha=")
		if a.begins_with("--tile-sha="):tile_sha=a.trim_prefix("--tile-sha=")
		if a.begins_with("--phase="):phase_name=a.trim_prefix("--phase=")
		if a=="--reproduce":reproduce=true
	root.size=Vector2i(640,360);root.content_scale_size=Vector2i(640,360)
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main ordinary entry")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	if phase_name=="reconnect":await reconnect_quality();return
	check(world._save_game(true)==OK,"isolated original save")
	check(source_open(4,Vector2i(32939,32283),65536),"held original long-route source")
	if not world.current523_aden_source_active():await finish_quality();return
	await frames()
	var protected: Dictionary=state();var reward_before: Dictionary=reward_state();var save_sha: String=FileAccess.get_sha256(world.save_path());var prefs_sha: String=FileAccess.get_sha256(OPTIONS.PATH)
	var goal: Vector2=world_point(Vector2i(33139,33358))
	world._set_click_destination(goal)
	check(world.player.click_path.size()>=1000 and world.player.manual_navigation,"ordinary click queues the existing complete long path")
	var started: Vector2=world.player.global_position
	await ticks(12);check(world.player.global_position.distance_to(started)>5,"actual physics starts the long route")
	# The long-route start is open floor. Reuse the held actual wall/seam probe,
	# with explicit QA positioning, rather than inventing a nearby blocked cell.
	world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	world.player.global_position=world_point(Vector2i(32316,33595))
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll();world.field_renderer.refresh_visible();await frames()
	goal=world_point(Vector2i(32320,33595));world._set_click_destination(goal)
	check(not world.player.click_path.is_empty() and world.player.click_path[-1]==goal,"actual queued clear route beside the previously verified wall")
	var probe_started: Vector2=world.player.global_position
	await ticks(3)
	check(world.player.global_position.distance_to(probe_started)>1,"actual motion starts beside the held original blocked cell")
	var blocked:=Vector2i(32316,33594)
	check(not world.field_map.walkable(world_point(blocked)),"held actual original blocked cell, no invented obstacle")
	var info: Dictionary=world.field_map.source_cell_info(blocked)
	observations.append({"blocked_cell":[blocked.x,blocked.y],"member":info.get("member"),"original_SHA256":info.get("source_sha256"),"raw_pair":info.get("raw_pair")})
	await stopped_click(world_point(blocked),"blocked destination")
	world._set_click_destination(goal);await ticks(3)
	await stopped_click(world.field_map.cell_to_world(Vector2i(-3,-3)),"outside destination")
	check(state()==protected and reward_state()==reward_before and FileAccess.get_sha256(world.save_path())==save_sha and FileAccess.get_sha256(OPTIONS.PATH)==prefs_sha,"click refusals change no progress, rewards or either saved file")
	var touch: Dictionary=gesture()
	check(not touch.is_empty(),"actual touch is held across source close")
	world.close_current523_aden_play()
	var pending: int=world.world_interactions.pointer
	check(pending==-2,"source close invalidates the old touch before release")
	release_gesture(touch)
	observations.append({"kind":"source_close_touch","pending_pointer_after_close":pending,"host_path_points_after_release":world.player.click_path.size()})
	check(world.player.click_path.is_empty(),"old source touch release cannot start host movement")
	world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	await frames()
	if reproduce:await finish_quality();return
	check(world._save_game(true)==OK,"protected host baseline after natural life initialization")
	protected=state();reward_before=reward_state();save_sha=FileAccess.get_sha256(world.save_path())
	check(source_open(4,Vector2i(32939,32283),65536),"source reentry for repeated commands")
	await frames();world.hud.workspace.hide()
	world._set_click_destination(world_point(Vector2i(33139,33358)))
	var route: PackedVector2Array=world.player.click_path.duplicate()
	check(route.size()>40,"existing raw long-route prefix is available")
	if route.size()<=40:await finish_quality();return
	var a: Vector2=route[20];var b: Vector2=route[35]
	for _i: int in range(3):world._set_click_destination(a);world._set_click_destination(b)
	check(not world.player.click_path.is_empty() and world.player.click_path[-1]==b and world.player.navigation_agent.target_position==b,"rapid valid destinations retain only the latest complete target")
	await ticks(8)
	var next: Vector2=world.player.click_path[world.player.path_index]
	world.player.set_touch_vector(world.player.global_position.direction_to(next));await ticks(2)
	check(world.player.click_path.is_empty() and not world.player.manual_navigation,"ordinary manual input cancels accepted long navigation")
	world.player.set_touch_vector(Vector2.ZERO);await ticks(2)
	var stopped: Vector2=world.player.global_position
	await ticks(8);check(world.player.global_position==stopped,"cancelled route does not resume after manual input release")
	var ticket: Dictionary=world.current523_source_portal_navigation_ticket(1481)
	world._set_click_destination(b)
	var provider: RefCounted=world.get("_current523_source_definition_provider")
	check(world.bind_current523_source_portal_provider(provider,DEFINITION_PIN),"genuine definition generation changes while a valid route is queued")
	reject_ticket(1481,ticket,"old definition during manual navigation")
	world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	# Reuse the already verified original chunk seam, labelled explicit QA positioning.
	world.player.global_position=world_point(Vector2i(32319,33595));world.player.camera.reset_smoothing();world.player.camera.force_update_scroll();world.field_renderer.refresh_visible();await frames()
	var limits: Dictionary=camera_state();var first_member: String=world.field_map.source_cell_info(cell_now()).member
	world._set_click_destination(world_point(Vector2i(32320,33595)))
	var deadline: int=Time.get_ticks_msec()+6000;world.player.set_physics_process(true)
	while cell_now()!=Vector2i(32320,33595) and Time.get_ticks_msec()<deadline:await physics_frame
	world.player.set_physics_process(false);world.player.clear_click_path();world.player.velocity=Vector2.ZERO
	var position: Vector2=world.player.global_position;var components: Array=world.field_map.coordinates.source_components(position)
	check(cell_now()==Vector2i(32320,33595) and world.field_map.source_cell_info(cell_now()).member!=first_member,"actual movement crosses the held original seam")
	check(world.field_map.coordinates.components_to_world(components)==position and camera_state()==limits,"seam source/world roundtrip and camera bounds remain exact")
	var screen: Vector2=COORD.world_to_screen(root,position)
	var camera_error: float=COORD.screen_to_world(root,screen).distance_to(position)
	check(camera_error<0.01,"actual viewport camera projection remains consistent at seam")
	observations.append({"kind":"actual_seam_pose","world_position":[position.x,position.y],"source_components":components,"camera_inverse_world_error":camera_error,"source_world_roundtrip_exact":world.field_map.coordinates.components_to_world(components)==position})
	check(state()==protected and reward_state()==reward_before and FileAccess.get_sha256(world.save_path())==save_sha,"interrupted movement, retargeting and seam preserve progress/rewards/save")
	check(world._save_game(true)==OK,"save interrupted source session at the actual seam pose")
	var options: Dictionary=OPTIONS.read();var checkpoint: Dictionary={"position":[position.x,position.y],"source_position":options.source_position,"protected":state(),"reward":reward_state(),"save_sha":FileAccess.get_sha256(world.save_path())}
	world.close_current523_aden_play(false);await frames()
	var host=world.field_map;var host_position: Vector2=world.player.global_position
	var invalid: Dictionary=options.duplicate(true);invalid.raw_root="/missing/interrupted-source-restore"
	check(OPTIONS.write(invalid)==OK,"isolated malformed restore input")
	world._restore_current523_aden_play();await frames()
	check(not world.current523_aden_source_active() and world.field_map==host and world.player.global_position==host_position and FileAccess.get_sha256(world.save_path())==checkpoint.save_sha,"interrupted restore preserves the current host and durable save")
	check(OPTIONS.write(options)==OK,"restore the original valid cursor unchanged")
	world._restore_current523_aden_play();await frames()
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==4 and world.player.global_position==position,"valid retry restores exact source seam pose")
	world.close_current523_aden_play();await frames()
	check(source_open(1,Vector2i(32668,32803)),"genuine manual1101 source")
	await frames();world.hud.workspace.hide()
	world._set_click_destination(world_point(Vector2i(32668,32804)))
	check(not world.player.click_path.is_empty(),"a valid source walk is queued before candidate rollback")
	touch=gesture();world.portal_cooldown=0
	var queued: Dictionary=movement()
	check(await deny_checkpoint_write(),"staged transition rollback while a walk and touch are pending")
	check(movement()==queued and world.world_interactions.pointer==0,"failed transition preserves the valid queued route and current gesture")
	check(world.use_current523_aden_source_portal(1101) and world.field_map.native_land.ID==0,"existing verified own-manual source transition")
	check(world.world_interactions.pointer==-2,"accepted field transition cancels old touch despite preserved host map ID")
	release_gesture(touch)
	check(world.player.click_path.is_empty(),"old source gesture cannot retarget the destination field")
	check(FileAccess.get_sha256(world.save_path())==checkpoint.save_sha,"manual transition and input guards do not rewrite progress")
	world.close_current523_aden_play();await frames()
	check(world.open_current523_aden_play(raw_root,tile_root,options),"return using the saved actual seam cursor, without centering it")
	await frames();check(world.player.global_position==position,"final session retains the exact physically reached seam pose")
	check(world._save_game(true)==OK,"final actual source save")
	checkpoint.position=[world.player.global_position.x,world.player.global_position.y];checkpoint.source_position=OPTIONS.read().source_position;checkpoint.protected=state();checkpoint.reward=reward_state();checkpoint.save_sha=FileAccess.get_sha256(world.save_path())
	var file:=FileAccess.open(QUALITY_EXPECTED,FileAccess.WRITE);file.store_string(JSON.stringify(checkpoint,"",true,true));file.close()
	await finish_quality()
func reconnect_quality() -> void:
	await frames();var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(QUALITY_EXPECTED))
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==4 and world.field_map.policy.path_search_limit==65536,"new process restores source identity and existing bound")
	if world.current523_aden_source_active():
		check(world.player.global_position==Vector2(expected.position[0],expected.position[1]) and cell_now()==Vector2i(32320,33595),"new process restores exact interrupted-session pose and cell")
		check(world.player.click_path.is_empty() and world.player.touch_vector==Vector2.ZERO and not world.player.manual_navigation and world.world_interactions.pointer==-2,"no cancelled route or gesture is resurrected")
		check(state()==expected.protected and reward_state()==expected.reward and FileAccess.get_sha256(world.save_path())==expected.save_sha,"reconnect preserves progression, rewards and save bytes")
		world.close_current523_aden_play();await frames()
		for key: String in expected.protected:
			if key!="bosses":check(state()[key]==expected.protected[key],"host return preserves "+key)
		check(returned_bosses(expected.protected.bosses,state().bosses).ok and FileAccess.get_sha256(world.save_path())==expected.save_sha,"safe host return preserves lives and durable save")
	await finish_quality()
func finish_quality() -> void:
	print("CURRENT523_MOVEMENT_INTERRUPT_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"phase":phase_name,"reproduction":reproduce,"actual_Main":true,"observations":observations,"native_rules_verified":false}))
	if is_instance_valid(world):world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
