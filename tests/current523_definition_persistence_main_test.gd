extends "res://tests/current523_generic_portal_main_test.gd"
## Normal installed host + real Settings + no product CLI or environment override.
const PREFS=preload("res://scripts/maps/current523_source_definition_preferences.gd")
const LOCATION=preload("res://scripts/maps/source_map_pack_location.gd")
const EXPECTED_PREF="user://current523-definition-persistence-expected.json"
var defs: String
var alternate: String
var panel: Node
func controls() -> void:
	world.hud.call("open_settings_info",true)
	panel=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel!=null,"actual existing Settings panel")
func connect_ui(path: String) -> void:
	controls();panel._folder_target="definitions";panel._folder_selected(path);panel.definition_connect_button.pressed.emit()
func expect_save_preserved(before: Dictionary,label: String) -> void:
	preserved(before,label)
func write_expected() -> void:
	var expected: Dictionary={"position":[world.player.global_position.x,world.player.global_position.y],"source_position":OPTIONS.read().source_position,"protected":state(),"save_sha":FileAccess.get_sha256(world.save_path()),"definition_directory":world.current523_source_definition_selection().get("directory","")}
	var file:=FileAccess.open(EXPECTED_PREF,FileAccess.WRITE);file.store_string(JSON.stringify(expected,"",true,true));file.close()
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		check(not arg.begins_with("--patch523-world-links"),"no product definition launch argument")
		if arg.begins_with("--source-root="):raw_root=arg.trim_prefix("--source-root=")
		if arg.begins_with("--tile-root="):tile_root=arg.trim_prefix("--tile-root=")
		if arg.begins_with("--source-sha="):source_sha=arg.trim_prefix("--source-sha=")
		if arg.begins_with("--tile-sha="):tile_sha=arg.trim_prefix("--tile-sha=")
		if arg.begins_with("--definitions="):defs=arg.trim_prefix("--definitions=")
		if arg.begins_with("--alternate-definitions="):alternate=arg.trim_prefix("--alternate-definitions=")
		if arg.begins_with("--phase="):phase_name=arg.trim_prefix("--phase=")
	check(OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty() and LOCATION.root_path()==LOCATION.USER,"normal installed user pack without environment override")
	root.size=Vector2i(960,540);root.content_scale_size=Vector2i(960,540)
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world);world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"ordinary actual Main entry")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	await frames()
	if phase_name=="reconnect":await reconnect_definitions();return
	if phase_name=="missing":await missing_definitions();return
	check(not PREFS.read().configured and world.current523_source_definition_status().is_empty(),"fresh normal launch has no implicit definitions")
	controls();check(panel.find_child("Current523SourceDefinitionPath",true,false)!=null,"user-facing definition folder control exists")
	if panel.definition_path_edit==null or panel.definition_connect_button==null:await finish_definitions();return
	connect_ui(defs)
	check(PREFS.read().ok and PREFS.read().directory==defs and world.current523_source_definition_status().definition_manifest_sha256==PREFS.PIN and panel.definition_status.text.contains("연결됨"),"real folder handler/button verifies, connects and remembers genuine definitions")
	panel.raw_path_edit.text=raw_root;panel.tile_path_edit.text=tile_root;panel.source_manifest.text=source_sha;panel.tile_manifest.text=tile_sha;panel.play_profile.select(3);panel._reload_native_lands(1)
	panel.source_entry_enabled.button_pressed=true;panel.source_entry_x.value=32668;panel.source_entry_y.value=32803;panel._update_open_button();panel.play_button.pressed.emit();await frames()
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==1 and panel.source_portal_choice.item_count>0,"ordinary UI entry has genuine Portal list without launch flags")
	if not world.current523_aden_source_active():await finish_definitions();return
	var before: Dictionary=snapshot();var prior: RefCounted=world.get("_current523_source_definition_provider");var pref_sha: String=FileAccess.get_sha256(PREFS.PATH)
	connect_ui("/missing/rejected-definitions")
	check(world.get("_current523_source_definition_provider")==prior and FileAccess.get_sha256(PREFS.PATH)==pref_sha and panel.definition_status.text.contains("연결하지 못했습니다"),"missing replacement preserves active genuine provider and remembered bytes")
	expect_save_preserved(before,"rejected definition folder")
	# Failure injection touches only this isolated profile, never a source pack.
	var path: String=ProjectSettings.globalize_path(PREFS.PATH);var held: String=path+".test-held"
	check(DirAccess.rename_absolute(path,held)==OK and DirAccess.make_dir_absolute(path)==OK,"retain exact preference before write-failure injection")
	connect_ui(alternate)
	check(world.get("_current523_source_definition_provider")==prior,"failed preference commit cannot change provider/generation")
	check(DirAccess.remove_absolute(path)==OK and DirAccess.rename_absolute(held,path)==OK,"restore exact preference before yielding")
	check(FileAccess.get_sha256(PREFS.PATH)==pref_sha,"failed preference commit retains old bytes")
	expect_save_preserved(before,"failed preference transaction")
	var ticket: Dictionary=world.current523_source_portal_navigation_ticket(1101)
	connect_ui(alternate)
	check(PREFS.read().directory==alternate and world.current523_source_definition_status().directory==alternate,"verified replacement remembers exact selected directory")
	check(not world.walk_to_current523_source_portal(1101,ticket),"replacement invalidates old UI requests")
	expect_save_preserved(before,"definition-only replacement")
	connect_ui(defs);world.portal_cooldown=0
	controls();panel._refresh_source_portals()
	for index: int in panel.source_portal_choice.item_count:
		if panel.source_portal_choice.get_item_id(index)==1101:panel.source_portal_choice.select(index)
	panel.source_portal_button.pressed.emit();await frames()
	check(world.field_map.native_land.ID==0 and cell_now()==Vector2i(32477,32855),"normal UI uses genuine manual1101 while retaining its existing own policy")
	check(world._save_game(true)==OK,"save normal UI selection/arrival")
	write_expected();await finish_definitions()
func reconnect_definitions() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_PREF))
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==0 and world.current523_source_definition_status().directory==defs,"new ordinary process restores saved field and genuine provider without CLI")
	if not world.current523_aden_source_active():await finish_definitions();return
	check(world.player.global_position==Vector2(expected.position[0],expected.position[1]) and state()==expected.protected and FileAccess.get_sha256(world.save_path())==expected.save_sha,"ordinary reopen preserves exact source cursor/progress/save")
	controls();check(panel.definition_status.text.contains("연결됨") and panel.definition_path_edit.text==defs,"normal UI reflects remembered genuine binding")
	var before: Dictionary=snapshot();connect_ui(alternate);expect_save_preserved(before,"normal persisted provider replacement")
	var manifest: String=alternate.path_join("manifest.json");var retained: String=manifest+".held"
	check(DirAccess.rename_absolute(manifest,retained)==OK,"withhold only the isolated alias manifest")
	check(world.current523_source_definition_status().is_empty() and not world._prepare_current523_source_definitions_from_launch(),"changed/missing saved pack is not reported verified or silently replaced")
	expect_save_preserved(before,"active definition file disappearance")
	check(world._save_game(true)==OK,"save cursor without promoting missing definition permission")
	write_expected();await finish_definitions()
func missing_definitions() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_PREF))
	check(not world.current523_aden_source_active() and world.current523_source_definition_status().is_empty() and world.current523_aden_play_problem.contains("manifest"),"ordinary reopen with missing requested definitions stays safely in original host")
	check(FileAccess.get_sha256(world.save_path())==expected.save_sha and OPTIONS.read().source_position==expected.source_position,"failed automatic restore preserves stored progress and M cursor")
	check(PREFS.read().directory==alternate,"missing saved pack does not silently fall back to another directory")
	controls();connect_ui(defs)
	check(PREFS.read().directory==defs and not world.current523_source_definition_status().is_empty(),"user repairs selection with real folder/button")
	panel._load_play_options();panel.source_entry_enabled.button_pressed=false;panel._update_open_button();panel.play_button.pressed.emit();await frames()
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==0 and world.player.global_position==Vector2(expected.position[0],expected.position[1]),"normal UI retries exact saved M cursor without borrowing host coordinates")
	check(FileAccess.get_sha256(world.save_path())==expected.save_sha,"repair/reentry changes no progress save bytes")
	panel.definition_clear_button.pressed.emit()
	check(not PREFS.read().configured and world.current523_source_definition_status().is_empty() and world.current523_aden_source_portals().is_empty() and world.current523_aden_source_active(),"explicit UI disconnect preserves terrain but exposes no unsupported Portal")
	check(panel.definition_status.text.contains("미연결"),"unbound geometry-only state is visibly labelled")
	connect_ui(defs);check(world._save_game(true)==OK,"leave repaired normal selection and source cursor saved")
	await finish_definitions()
func finish_definitions() -> void:
	print("CURRENT523_DEFINITION_PERSISTENCE_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"phase":phase_name,"actual_Main":true,"normal_user_host_pack":true,"product_definition_CLI_used":false,"source_override_environment_used":false,"native_activation_verified":false}))
	if is_instance_valid(world):world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
