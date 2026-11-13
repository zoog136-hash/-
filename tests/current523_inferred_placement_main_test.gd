extends "res://tests/current523_movement_interrupt_main_test.gd"
## Actual held bytes in normal Main. These source entry points are QA, not native admission.
const PLACEMENT=preload("res://scripts/maps/current523_aden_inferred_placement.gd")
const RESULT_PATH="user://current523-inferred-placement-expected.json"
var panel: Node
var definitions: String
func controls() -> void:
	world.hud.call("open_settings_info",true)
	panel=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel!=null,"existing normal Settings panel")
func setup_ui(enabled: bool,point: Vector2i) -> void:
	controls();panel.raw_path_edit.text=raw_root;panel.tile_path_edit.text=tile_root
	panel.source_manifest.text=source_sha;panel.tile_manifest.text=tile_sha
	panel.play_profile.select(3);panel._reload_native_lands(4)
	panel.aden_inferred_placement.button_pressed=enabled
	panel.source_entry_enabled.button_pressed=true;panel.source_entry_x.value=point.x;panel.source_entry_y.value=point.y
	panel._update_open_button()
func preserved_host(before: Dictionary) -> void:
	check(not world.current523_aden_source_active() and world.field_map==before.field and world.field_renderer==before.renderer and world.field_physics==before.physics and world.player.global_position==before.position,"disabled slot failure preserves host field/renderer/physics/actor")
	check(camera_state()==before.camera and FileAccess.get_sha256(OPTIONS.PATH)==before.prefs_sha and FileAccess.get_sha256(world.save_path())==before.save_sha and state()==before.protected,"disabled slot failure preserves host camera/preferences/save/progression")
func finish_placement() -> void:
	print("CURRENT523_INFERRED_PLACEMENT_MAIN_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"phase":phase_name,"observations":observations,"captures":captures,"native_placement_verified":false,"native_m_rules_verified":false}))
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-root="):raw_root=arg.trim_prefix("--source-root=")
		if arg.begins_with("--tile-root="):tile_root=arg.trim_prefix("--tile-root=")
		if arg.begins_with("--source-sha="):source_sha=arg.trim_prefix("--source-sha=")
		if arg.begins_with("--tile-sha="):tile_sha=arg.trim_prefix("--tile-sha=")
		if arg.begins_with("--phase="):phase_name=arg.trim_prefix("--phase=")
		if arg.begins_with("--definitions="):definitions=arg.trim_prefix("--definitions=")
	root.size=Vector2i(960,540);root.content_scale_size=Vector2i(960,540)
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual ordinary Main entry")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	await frames()
	if phase_name=="reconnect":await reconnect_placement();return
	check(world._save_game(true)==OK,"isolated protected baseline")
	var protected: Dictionary=state();var save_sha: String=FileAccess.get_sha256(world.save_path())
	setup_ui(true,Vector2i(33504,32160))
	check(panel.aden_inferred_placement.text.contains("추정") and panel.aden_inferred_placement.text.contains("미확정"),"normal UI clearly labels optional own placement")
	panel.play_button.pressed.emit();await frames()
	check(world.current523_aden_source_active(),"normal UI opens held ninth-character original at inferred slot: "+world.current523_aden_play_problem)
	if not world.current523_aden_source_active():await finish_placement();return
	var field: RefCounted=world.field_map
	check(field.source_origins.size()==677 and field.unplaced_members.is_empty() and field.source_origins[PLACEMENT.MEMBER]==PLACEMENT.ORIGIN,"676 original placements plus one separate inferred member; no truncation")
	check(field.inferred_placements.size()==1 and field.data.map_name.contains("추정 배치"),"active field title and contract disclose inference")
	var off: RefCounted=GENERIC_FIELD.new()
	check(off.configure_verified_catalog(field._raw,source_sha,4,{PLACEMENT.OPTION:false}),"same held catalog supports reversible placement-off")
	check(off.source_origins.size()==676 and off.unplaced_members==[PLACEMENT.MEMBER],"feature-off retains literal original unplaced")
	var unchanged: bool=true
	for member: String in off.source_origins:unchanged=unchanged and field.source_origins.get(member)==off.source_origins[member]
	check(unchanged,"all676 existing origins remain exactly unchanged")
	check(not off._source_chunks.has(PLACEMENT.ORIGIN) and field.source_bounds==off.source_bounds,"inferred origin was vacant and neither bounds nor old coordinate basis changes")
	var info: Dictionary=field.source_cell_info(Vector2i(33504,32160))
	check(info.member==PLACEMENT.MEMBER and info.source_sha256==PLACEMENT.SOURCE_SHA256 and info.raw_pair==[0,0] and info.inferred_placement.native_placement_verified==false,"new cells preserve raw source hash, literal member and explicit host placement")
	check(PLACEMENT.candidate(PLACEMENT.MEMBER,{"sha256":"0".repeat(64),"bytes":147158},true)==null and PLACEMENT.candidate(PLACEMENT.MEMBER,field.source_metadata(PLACEMENT.MEMBER),false)==null,"bad bytes identity or disabled policy cannot resolve inferred origin")
	var metrics: Dictionary=world.field_renderer.frame_metrics()
	check(metrics.ready_placed_sources==677 and metrics.unplaced_sources==0 and metrics.unresolved_refs==0 and metrics.draw_commands>0 and not metrics.native_M_rules_verified,"actual renderer uses same field placement, existing verified tiles and native-unknown label")
	check(world.field_renderer._member_origins[PLACEMENT.MEMBER]==PLACEMENT.ORIGIN and world.field_renderer._overlap.size()==677,"one unique renderer floor owner per origin; no overlapping placed source")
	capture("inferred-aden-center")
	check(await walk(world_point(Vector2i(33500,32160))),"real player physics walks on the new original floor")
	var blocked:=Vector2i(33504,32156)
	check(not field.source_cell_info(blocked).walkable and field.source_cell_info(blocked).raw_pair.has(1),"held source obstacle remains denied by unchanged allowlist")
	world._set_click_destination(world_point(Vector2i(33504,32160)));await ticks(2)
	await stopped_click(world_point(blocked),"inferred-area blocked click")
	var before: Dictionary=snapshot();var valid: Dictionary=panel._play_values();valid.aden_inferred_placement_enabled=false
	check(not world.apply_current523_aden_play_options(valid),"in-place placement change rejected instead of stranding actor")
	preserved(before,"placement toggle requires close")
	# Explicit QA re-entry on the last source row, not an inferred natural portal.
	world.close_current523_aden_play();await frames()
	protected=state();save_sha=FileAccess.get_sha256(world.save_path())
	setup_ui(true,Vector2i(33480,32190));panel.play_button.pressed.emit();await frames()
	check(world.current523_aden_source_active() and cell_now()==Vector2i(33480,32190),"QA source entry near original neighbor seam")
	check(await walk(world_point(Vector2i(33480,32191))),"actual movement reaches final inferred floor row")
	field=world.field_map
	var neighbor: Dictionary=field.source_cell_info(Vector2i(33480,32192))
	check(neighbor.member=="Map/Aden/800b7ff7.s32" and neighbor.raw_pair==[1,1] and not neighbor.walkable,"adjacent original neighbor retains blocked raw words; no fabricated connecting passage")
	world._set_click_destination(world_point(Vector2i(33480,32192)));await ticks(8)
	check(cell_now()==Vector2i(33480,32191) and world.player.click_path.is_empty(),"blocked chunk seam refuses actual click without crossing")
	check(field.source_cell_info(Vector2i(33471,32150)).status=="unregistered_chunk","unsupported lateral neighbor remains absent rather than fabricated")
	var exact: Vector2=world.player.global_position;var camera: Camera2D=world.player.camera
	camera.reset_smoothing();camera.force_update_scroll();world.field_renderer.refresh_visible();await frames()
	check(field.coordinates.components_to_world(field.coordinates.source_components(exact)).distance_to(exact)<0.01,"source/world inverse remains consistent at new seam")
	capture("inferred-aden-original-neighbor-seam")
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"new-area walking/refusals preserve game progress and existing save bytes")
	var touch: Dictionary=gesture();world.close_current523_aden_play();release_gesture(touch)
	check(not world.current523_aden_source_active() and world.player.click_path.is_empty() and world.world_interactions.pointer==-2,"new area return cancels old touch and restores existing host")
	# Turning it off is reversible and cannot borrow old host coordinates into M.
	setup_ui(false,Vector2i(33504,32160));before=snapshot();panel.play_button.pressed.emit();await frames()
	check(not world.current523_aden_source_active(),"disabled inferred slot refuses entry")
	preserved_host(before)
	setup_ui(false,Vector2i(32939,32283));panel.play_button.pressed.emit();await frames()
	check(world.current523_aden_source_active() and world.field_map.source_origins.size()==676 and not OPTIONS.read().aden_inferred_placement_enabled,"placement-off normal UI retains previous Aden field and persisted choice")
	world.close_current523_aden_play();await frames()
	setup_ui(true,Vector2i(33504,32160));panel.play_button.pressed.emit();await frames()
	check(world.current523_aden_source_active() and OPTIONS.read().aden_inferred_placement_enabled,"normal UI re-enables exact held original")
	check(world._save_game(true)==OK,"new placement saves through existing normal checkpoint")
	var expected: Dictionary={"position":[world.player.global_position.x,world.player.global_position.y],"source":OPTIONS.read().source_position,"protected":state(),"save_sha":FileAccess.get_sha256(world.save_path())}
	var file:=FileAccess.open(RESULT_PATH,FileAccess.WRITE);file.store_string(JSON.stringify(expected,"",true,true));file.close()
	observations.append({"placement":PLACEMENT.record(),"center_info":info,"seam_neighbor":neighbor,"renderer":metrics,"off_original_origins":off.source_origins.size()})
	off.close();await finish_placement()
func reconnect_placement() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RESULT_PATH))
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==4 and world.field_map.inferred_placements.has(PLACEMENT.MEMBER),"new ordinary process restores inferred placement from persisted setting")
	if not world.current523_aden_source_active():await finish_placement();return
	check(world.player.global_position==Vector2(expected.position[0],expected.position[1]) and OPTIONS.read().source_position==expected.source,"reconnect preserves exact new-area cursor without host-coordinate reuse")
	check(state()==expected.protected and FileAccess.get_sha256(world.save_path())==expected.save_sha,"reconnect preserves actual save bytes and protected progression")
	controls();check(panel.aden_inferred_placement.button_pressed,"ordinary Settings displays saved placement choice")
	check(await walk(world_point(Vector2i(33500,32160))),"restored area supports actual physics movement")
	# Narrow shared-renderer/manual-target regression, not another bulk pass.
	world.close_current523_aden_play();await frames();controls()
	panel._folder_target="definitions";panel._folder_selected(definitions);panel.definition_connect_button.pressed.emit()
	check(not world.current523_source_definition_status().is_empty(),"genuine existing PR230 definition pack connects through normal UI")
	panel.raw_path_edit.text=raw_root;panel.tile_path_edit.text=tile_root;panel.source_manifest.text=source_sha;panel.tile_manifest.text=tile_sha
	panel.play_profile.select(3);panel._reload_native_lands(1);panel.aden_inferred_placement.button_pressed=false
	panel.source_entry_enabled.button_pressed=true;panel.source_entry_x.value=32668;panel.source_entry_y.value=32803
	panel._update_open_button();panel.play_button.pressed.emit();await frames()
	check(world.current523_aden_source_active() and world.field_map.native_land.ID==1 and world.field_map.inferred_placements.is_empty() and world.field_renderer.frame_metrics().unresolved_refs==0,"regular Land1 renders unchanged through field-owned origins with placement off")
	if world.current523_aden_source_active() and world.field_map.native_land.ID==1:
		controls();panel._refresh_source_portals()
		for index: int in panel.source_portal_choice.item_count:
			if panel.source_portal_choice.get_item_id(index)==1101:panel.source_portal_choice.select(index)
		# Main processing is frozen in this isolated harness. Prove the existing
		# cooldown guard first, then advance that own clock for the success case.
		world.portal_cooldown=2.0
		panel.source_portal_button.pressed.emit()
		check(world.field_map.native_land.ID==1 and world.current523_aden_play_problem.contains("현재 이동 상태"),"manual travel retains its existing positive-cooldown refusal")
		world.portal_cooldown=0.0
		panel.source_portal_button.pressed.emit();await frames()
		observations.append({"manual1101_land":world.field_map.native_land.ID,"problem":world.current523_aden_play_problem,"placement_enabled":world.field_map.policy.aden_inferred_placement_enabled,"source_cell":cell_now()})
		check(world.field_map.native_land.ID==0 and cell_now()==Vector2i(32477,32855) and not world.field_map.policy.aden_inferred_placement_enabled and not OPTIONS.read().aden_inferred_placement_enabled,"genuine normal manual1101 target preserves placement-off context and exact original destination")
	await finish_placement()
