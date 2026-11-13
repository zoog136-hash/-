extends "res://tests/current523_aden_source_main_test.gd"
## Focused real Main/UI/GL binding; QA entry is not native admission.
const SPR=preload("res://scripts/maps/current523_static_spr.gd")
const GENERIC_FIELD=preload("res://scripts/maps/current523_source_field.gd")
const EXPECTED_STATIC="user://current523-static-spr-main-expected.json"
func protected_state() -> Dictionary:
	var result: Dictionary=state()
	# The host simulation clock may advance when its population resumes.
	# Keep every boss phase/HP/deadline and all player progress in the comparison.
	result.bosses.erase("game_seconds")
	return result

func returned_progress_preserved(before: Dictionary, after: Dictionary) -> bool:
	for key: String in before:
		if key!="bosses" and before[key]!=after.get(key): return false
	var old_bosses: Dictionary=before.bosses.bosses
	var current: Dictionary=after.bosses.bosses
	if old_bosses.keys()!=current.keys(): return false
	for key: String in old_bosses:
		var old: Dictionary=old_bosses[key];var live: Dictionary=current[key]
		if old==live: continue
		# Returning resumes the real host population. A due, unspawned boss may
		# enter alive state; that is not discarded progression or a rewritten clock.
		if old.phase!="ready" or live.phase!="alive" or old.hp!=-1 or live.hp<=0: return false
		if old.ready_at!=live.ready_at or old.layout_revision!=live.layout_revision or float(old.ready_at)>Time.get_unix_time_from_system(): return false
	return true
func run() -> void:
	var args: Dictionary={}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	for key: String in ["source-root","source-sha","tile-root","tile-sha","sp2-root","declaration"]:
		if not args.has(key):printerr("Private original input required: "+key);quit(2);return
	raw_root=args["source-root"];tile_root=args["tile-root"]
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"normal class confirmation enters actual Main")
	world.player.set_physics_process(false);world.player.set_process(false);world.field_population.set_process(false)
	if args.get("phase","")=="reconnect":
		await frames()
		var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_STATIC))
		check(world.current523_aden_source_active(),"fresh process restores actual source session")
		if world.current523_aden_source_active():
			check(world.field_map.definition.source_map_id==4,"reconnect retains original Land4 identity")
			check(protected_state()==expected.state,"reconnect preserves items currency collections and bosses")
			check(FileAccess.get_sha256(world.save_path())==expected.save_sha,"reconnect does not rewrite durable save")
			var metrics: Dictionary=world.current523_aden_play_metrics().get("static_spr",{})
			var declaration_identity: String=SPR.GLOBAL_DECLARATIONS.MANIFEST_SHA if DirAccess.dir_exists_absolute(args.declaration) else SPR.DECLARATION_SHA
			check(metrics.get("drawn_records",0)>0 and metrics.get("declaration_SHA256","")==declaration_identity,"fresh process restores verified source image binding and exact declaration")
			capture("static-spr-source-reconnect")
		await finish("static-spr-reconnect");return
	world.gold=523992
	check(world._save_game(true)==OK,"baseline uses actual atomic game save")
	var baseline: Dictionary=protected_state()
	var original_save: String=FileAccess.get_sha256(world.save_path())
	var host_field=world.field_map;var host_position: Vector2=world.player.global_position
	var host_identity: Dictionary=host_field.definition.duplicate(true)
	world.hud.open_settings_info(true);await frames()
	var panel=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel!=null and panel.spr_enabled!=null,"source map settings exposes functional SPR controls")
	if panel==null:await finish("static-spr-entry");return
	panel.raw_path_edit.text=raw_root;panel.tile_path_edit.text=tile_root
	panel.play_profile.select(3);panel.source_manifest.text=args["source-sha"];panel.tile_manifest.text=args["tile-sha"];panel._reload_native_lands(4)
	var probe=GENERIC_FIELD.new()
	check(probe.configure_verified_catalog(panel._native_catalog,args["source-sha"],4),"held native geometry finds QA entry beside original29175 record")
	var landing: Dictionary=probe.choose_source_landing([33276,32208,33288,32220],"OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1")
	check(landing.get("ok",false),"QA entry uses existing clear-cell policy, not invented floor")
	if not landing.get("ok",false):probe.close();await finish("static-spr-entry");return
	panel.source_entry_enabled.button_pressed=true;panel.source_entry_x.value=landing.source_cell.x;panel.source_entry_y.value=landing.source_cell.y
	probe.close()
	panel.spr_enabled.button_pressed=true;panel.spr_root.text="/absent-spr-source";panel.spr_fps.value=12;panel._save_static_spr()
	panel.play_button.pressed.emit();await frames()
	check(not world.current523_aden_source_active() and world.field_map==host_field and world.player.global_position==host_position,"missing SPR rejects source entry and restores current field/position")
	check(FileAccess.get_sha256(world.save_path())==original_save and protected_state()==baseline,"failed image binding preserves actual save and progression")
	panel.spr_root.text=args["sp2-root"];panel.spr_declaration.text=args.declaration;panel._save_static_spr()
	check(FileAccess.get_sha256(world.save_path())==original_save,"SPR preference save never mutates game save")
	panel.play_button.pressed.emit();await frames()
	check(world.current523_aden_source_active(),"normal map UI opens source field with real SP2 bytes: "+world.current523_aden_play_problem)
	if not world.current523_aden_source_active():await finish("static-spr-entry");return
	var renderer=world.field_renderer
	var layer=renderer.get_node_or_null("Current523SourceStaticSPR")
	check(layer!=null,"real Main renderer owns source SPR layer")
	if layer==null:await finish("static-spr-entry");return
	var metrics: Dictionary=world.current523_aden_play_metrics().static_spr
	measurements.append(metrics)
	check(metrics.raw_records>0 and metrics.drawn_records>0 and metrics.malformed_tails==0,"actual visible source records create rendered original textures")
	check(metrics.declared_sequence_records>0 and not metrics.native_M_placement_action_timing_verified,"held declaration drives frame order while own placement/clock remains labelled")
	check(protected_state()==baseline,"source image binding preserves gameplay state")
	renderer.set_process(false);layer.set_process(false);world.player.class_sprite.stop()
	await frames();var shown: PackedByteArray=root.get_texture().get_image().get_data()
	capture("static-spr-source-on")
	layer.hide();await frames();var hidden: PackedByteArray=root.get_texture().get_image().get_data()
	check(shown!=hidden,"real GL framebuffer changes when only original source SPR layer is hidden")
	layer.show();layer.set_process(true);renderer.set_process(true)
	var initial: Array[Dictionary]=layer.displayed_records();await create_timer(0.5).timeout;await frames()
	var animated: Array[Dictionary]=layer.displayed_records();var advanced: bool=false
	for before: Dictionary in initial:
		for after: Dictionary in animated:
			if before.record.source_member==after.record.source_member and before.record.source_byte_offset==after.record.source_byte_offset and before.frame!=after.frame:advanced=true
	check(advanced,"real elapsed own clock animates source records without generated frames")
	var field=world.field_map;var local: Vector2i=field.world_to_cell(world.player.global_position);var moved: bool=false
	for heading: int in 8:
		if field.can_step(local,heading):
			moved=await walk(field.coordinates.cell_to_world(local+field.DIRECTIONS[heading]));break
	check(moved,"actual player physically walks with original source decorations active")
	check(protected_state()==baseline,"walking with source images preserves items/currency/collections/bosses")
	check(world._save_game(true)==OK,"source session saves with source image settings separate")
	var saved: String=FileAccess.get_sha256(world.save_path());world._load_game(true);await frames()
	check(world.current523_aden_source_active() and FileAccess.get_sha256(world.save_path())==saved,"same-process reload retains source entry without save overwrite")
	world.close_current523_aden_play();await frames()
	var changed_keys: Array[String]=[]
	var returned: Dictionary=protected_state()
	for key: String in baseline:
		if baseline[key]!=returned.get(key):changed_keys.append(key)
	measurements.append({"return_map_identity_matches":world.field_map.definition==host_identity,"return_position":[world.player.global_position.x,world.player.global_position.y],"expected_host_position":[host_position.x,host_position.y],"changed_progress_keys":changed_keys})
	check(world.field_map.definition==host_identity and world.player.global_position==host_position,"normal return after reload restores host source identity/position, independent of rebuilt node instance")
	check(returned_progress_preserved(baseline,returned),"return preserves player progress and boss state/deadlines while allowing a due ready boss to spawn")
	check(world.open_current523_aden_play(raw_root,tile_root,OPTIONS.read()),"normal production API reenters held source cursor with image preferences")
	await frames();check(world._save_game(true)==OK,"reentered source session saves for fresh-process proof")
	var output:=FileAccess.open(EXPECTED_STATIC,FileAccess.WRITE);output.store_string(JSON.stringify({"state":protected_state(),"save_sha":FileAccess.get_sha256(world.save_path())},"",true,true));output.close()
	capture("static-spr-source-walk-and-reentry")
	SPR.USAGE.flush(true)
	var usage_text: String=FileAccess.get_file_as_string(SPR.USAGE.PATH)
	var usage: Variant=null if usage_text.is_empty() else JSON.parse_string(usage_text)
	check(usage is Dictionary and usage.get("usage95_verified",true)==false,"actual drawing produces a separate ledger without a fabricated95% claim")
	if usage is Dictionary:
		check(int(usage.fixed_Map_Tile_denominator.Map.files)==8311 and int(usage.fixed_Map_Tile_denominator.Tile.files)==8514,"fixed original Map/Tile denominators include unsupported/excluded originals")
		var categories: Dictionary={};var correctly_partial: bool=true
		for row: Dictionary in usage.members.values():
			categories[str(row.member).get_slice("/",0)]=true
			if row.whole_file_used or row.original_member_bytes_fully_used_proven!=0 or not row.origins.has("AUTOMATED_ACTUAL_MAIN") or row.origins.has("USER_MAIN"):correctly_partial=false
		check(correctly_partial and categories.has("Map") and categories.has("Tile") and categories.has("Sprite"),"real Main draw units are partial observations, separate from user play and decoded bytes")
	await finish("static-spr-entry")
