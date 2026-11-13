extends "res://tests/current523_generic_portal_main_test.gd"
## Actual PR230 loader/pack -> World -> existing Settings action. No TEST provider.
const PRODUCTION=preload("res://scripts/maps/current523_source_portal_provider.gd")
const ORIGINAL_LOADER=preload("res://scripts/maps/patch523_world_links.gd")
const PRODUCTION_EXPECTED="user://current523-production-portal-expected.json"
var definitions: String
var held_path: String
var genuine: bool=false
func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--source-root="):raw_root=a.trim_prefix("--source-root=")
		if a.begins_with("--tile-root="):tile_root=a.trim_prefix("--tile-root=")
		if a.begins_with("--source-sha="):source_sha=a.trim_prefix("--source-sha=")
		if a.begins_with("--tile-sha="):tile_sha=a.trim_prefix("--tile-sha=")
		if a.begins_with("--patch523-world-links="):definitions=a.trim_prefix("--patch523-world-links=")
		if a.begins_with("--held-proof="):held_path=a.trim_prefix("--held-proof=")
		if a.begins_with("--phase="):phase_name=a.trim_prefix("--phase=")
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"ordinary actual Main entry")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	if phase_name=="reconnect":await production_reconnect();return
	world.gold=523230
	check(world._save_game(true)==OK,"protected baseline actual save")
	check(FileAccess.get_sha256(held_path)=="d2e4aab863cedbc9ff0ddeb96bcb138399c3f99da29316349801283218405f38","independent exact original held-route proof")
	var held: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(held_path))
	check(open_generic(int(held.source_land_id),Vector2i(int(held.source_cell[0]),int(held.source_cell[1]))),"launch flags bind actual definitions before optional source map registration")
	if not world.current523_aden_source_active():await finish_production();return
	await frames()
	var provider: RefCounted=world.get("_current523_source_definition_provider")
	genuine=provider!=null and provider.get_script()==PRODUCTION and provider._definition(int(held.source_land_id),str(held.source_asset_path)).get_script()==ORIGINAL_LOADER
	check(genuine and world.current523_source_definition_status().definition_manifest_sha256==DEFINITION_PIN,"actual PR230 owning loader is bound; no fixture provider")
	var context: Dictionary=world.current523_aden_source_portal_context(int(held.portal_id))
	check(context.definition_owner=="PR230_PATCH523_WORLD_LINKS" and not context.source_travel_hold.is_empty() and not context.native_definition_contract.travel_enabled,"native limits are preserved with unresolved activation held")
	var target:=GENERIC_FIELD.new()
	check(target.configure_verified_catalog(world.get("_current523_aden_play_controller").get("_cached_catalog"),source_sha,int(held.target_land_id)),"held target's actual source field is available")
	check(world.field_map.source_cell_info(Vector2i(held.source_cell[0],held.source_cell[1])).walkable and target.source_cell_info(Vector2i(held.target_cell[0],held.target_cell[1])).walkable,"both held-route endpoints are actually clear; definition hold is independent of own collision")
	target.close()
	world.hud.call("open_settings_info",true);await frames()
	var panel=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel!=null,"actual source portal Settings UI")
	if panel==null:await finish_production();return
	panel._refresh_source_portals();panel._update_open_button()
	var selected: bool=false
	for index: int in panel.source_portal_choice.item_count:
		if panel.source_portal_choice.get_item_id(index)==int(held.portal_id):panel.source_portal_choice.select(index);selected=true;check(panel.source_portal_choice.get_item_text(index).contains("원문 조건 보류"),"UI exposes genuine native-condition hold")
	check(selected,"actual native held route is listed")
	var before: Dictionary=snapshot();world.portal_cooldown=0
	panel.source_portal_button.pressed.emit();await frames()
	check(world.current523_aden_play_problem.contains("definition_conditions_hold"),"actual Settings action respects native-condition hold")
	preserved(before,"genuine native-condition hold")
	measurements.append({"portal_id":held.portal_id,"source_land_id":held.source_land_id,"target_land_id":held.target_land_id,"held_original_conditions":held.conditions,"definition_hold":context.source_travel_holds})
	world.hud.workspace.hide();world.close_current523_aden_play();await frames()
	check(world._save_game(true)==OK,"explicit baseline after normal host restoration")
	var protected: Dictionary=state();var save_sha: String=FileAccess.get_sha256(world.save_path());var host=world.field_map;var host_position: Vector2=world.player.global_position
	check(open_generic(1,Vector2i(32668,32803)),"actual native1101 source")
	if not world.current523_aden_source_active():await finish_production();return
	await frames()
	check(not world.bind_current523_source_definition_pack("/missing/replacement-definitions",DEFINITION_PIN) and not world.current523_aden_source_portal_context(1101).is_empty(),"failed production binding update retains valid definitions")
	context=world.current523_aden_source_portal_context(1101)
	check(context.source_travel_hold.is_empty() and not context.native_definition_contract.activation_known,"native data has no applicable held conditions; activation remains unknown")
	world.hud.call("open_settings_info",true);await frames();panel=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel!=null,"actual manual source action UI reopens")
	if panel==null:await finish_production();return
	panel._refresh_source_portals();selected=false
	for index: int in panel.source_portal_choice.item_count:
		if panel.source_portal_choice.get_item_id(index)==1101:panel.source_portal_choice.select(index);selected=true
	check(selected,"genuine native1101 is listed for current source Land")
	world.portal_cooldown=0;panel.source_portal_button.pressed.emit();await frames()
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==0 and cell_now()==Vector2i(32477,32855),"actual Settings manual action crosses Land1 to exact native Land0 destination")
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"genuine definition-backed manual travel preserves progress and save bytes")
	capture("production-native1101-Land0")
	check(world._save_game(true)==OK,"actual save after genuine definition-backed move")
	var options: Dictionary=OPTIONS.read();var file:=FileAccess.open(PRODUCTION_EXPECTED,FileAccess.WRITE)
	# Boss wall-clock values need the same full-precision JSON as the real save.
	file.store_string(JSON.stringify({"protected":state(),"save_sha":FileAccess.get_sha256(world.save_path()),"position":options.source_position,"host_position":[host_position.x,host_position.y],"host_map_id":world.active_map_id},"",true,true));file.close()
	await finish_production()
func production_reconnect() -> void:
	await frames()
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PRODUCTION_EXPECTED))
	var provider: RefCounted=world.get("_current523_source_definition_provider")
	genuine=provider!=null and provider.get_script()==PRODUCTION
	check(genuine and world.current523_aden_source_active() and world.field_map.native_land.ID==0,"new process restores source field and actual production definitions")
	if not world.current523_aden_source_active():await finish_production();return
	check(world.field_map.coordinates.source_components(world.player.global_position)==expected.position and state()==expected.protected and FileAccess.get_sha256(world.save_path())==expected.save_sha,"genuine-provider reconnect preserves exact cursor/progress/save")
	check(not world.use_current523_aden_source_portal(1101),"old source-Land action cannot be reused after transition")
	check(world.bind_current523_source_portal_provider(null,"") and world.current523_source_definition_status().is_empty(),"caller-owned unbind clears the genuine-definition status")
	check(world._prepare_current523_source_definitions_from_launch() and not world.current523_source_definition_status().is_empty(),"launch contract restores genuine definitions after caller-owned replacement")
	world.close_current523_aden_play();await frames()
	check(world.active_map_id==expected.host_map_id and world.player.global_position==Vector2(expected.host_position[0],expected.host_position[1]),"genuine-provider session returns initial host position")
	for key: String in expected.protected:
		if key!="bosses":check(state()[key]==expected.protected[key],"protected progression after return: "+key)
	check(returned_bosses(expected.protected.bosses,state().bosses).ok and FileAccess.get_sha256(world.save_path())==expected.save_sha,"original host lives/save preserved on return")
	await finish_production()
func finish_production() -> void:
	print("CURRENT523_PRODUCTION_PORTAL_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"phase":phase_name,"actual_Main":true,"genuine_PR230_binding_verified":genuine,"measurements":measurements,"captures":captures,"native_activation_verified":false}))
	if is_instance_valid(world):world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
