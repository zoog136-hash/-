extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("SOURCE_OPTIMIZATION_UI_FAIL: ",label)
func click(button: Control, scroll: ScrollContainer) -> void:
	# Source loading/selection changes wrapped text and content height. Let the
	# container lay out before asking it to bring the button into view.
	for i: int in range(3): await process_frame
	scroll.ensure_control_visible(button)
	await process_frame
	await process_frame
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size*0.5)
	check(scroll.get_global_rect().has_point(point),"input target is inside scroll clip: " + str(button.name))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func run() -> void:
	check(DisplayServer.get_name()!="headless","actual renderer required")
	var path: String = OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	check(not path.is_empty(),"actual private source required")
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main enters game")
	world.player.set_physics_process(false)
	check(world._save_game(true)==OK,"baseline real save")
	var save_path: String = world.save_path()
	var save_hash: String = FileAccess.get_sha256(save_path)
	var equipment: Dictionary = world.equipped_catalog.duplicate(true)
	var attack: int = world._effective_attack()
	var global_before: Dictionary = world.presentation_global_settings.duplicate(true)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = extent
		world.hud.open_settings_info(true)
		await process_frame
		await process_frame
		var host: Node = world.hud.find_child("RenewalSettings",true,false)
		var source: Node = host.find_child("SourceOptimizationSettings",true,false)
		var scroll: ScrollContainer = host.find_child("SettingsScroll",true,false)
		check(source!=null,"real source settings controls " + str(extent))
		await click(source.choose_button if extent.x==1280 else source.zip_button,scroll)
		check(is_instance_valid(source.directory_dialog) and source.directory_dialog.visible,"actual folder picker opens " + str(extent))
		source.directory_dialog.current_dir = path
		if extent.x==1280: source.directory_dialog.dir_selected.emit(path)
		else: source.directory_dialog.file_selected.emit(OS.get_environment("TWILIGHT_PATCH523_ZIP"))
		source.directory_dialog.hide()
		check(source.regions.item_count==195,"all 195 regions reach actual dropdown " + str(extent))
		for i: int in range(source.regions.item_count):
			check(world.source_optimization.by_id.has(int(source.regions.get_item_metadata(i))),"original row identity in UI %d" % i)
		for id: int in [242488,169682]:
			for i: int in range(source.regions.item_count):
				if int(source.regions.get_item_metadata(i))!=id: continue
				source.regions.select(i)
				source.regions.item_selected.emit(i)
				check(source.definition.text.contains("원본 좌표"),"original numeric bounds visible for source row %d" % id)
				check(source.definition.text.contains("조건 전후 표시값 동일") if id==242488 else source.definition.text.contains("경계 판정 대기"),"actual invariant/point source row is explained %d" % id)
		var index: int = -1
		for i: int in range(source.regions.item_count):
			var row: Dictionary = world.source_optimization.by_id[int(source.regions.get_item_metadata(i))]
			if row.DefaultLowEffectCount and row.DefaultHideMagicDoll and int(row.ConditionTypeId)==0: index=i;break
		check(index>=0,"real unconditional recommendation available")
		source.regions.select(index)
		source.regions.item_selected.emit(index)
		if extent.x==1280:
			await check_failed_store(world,host,source,scroll,save_hash)
			world.queue_free()
			await process_frame
			world = load("res://Main.tscn").instantiate()
			root.add_child(world)
			world.set_process(false)
			world.save_timer = -100000.0
			check(QA.enter_game(world),"actual Main reenters after failed settings write")
			world.player.set_physics_process(false)
			check(world.presentation_settings==global_before,"failed writes do not appear after restart")
			check(world.source_optimization.territories.size()==195,"previous source selection survives rejected write and restart")
			check(FileAccess.get_sha256(save_path)==save_hash,"failed preference writes and reentry preserve game save bytes")
			world.hud.open_settings_info(true)
			await process_frame
			host = world.hud.find_child("RenewalSettings",true,false)
			source = host.find_child("SourceOptimizationSettings",true,false)
			scroll = host.find_child("SettingsScroll",true,false)
			source.regions.select(index)
			source.regions.item_selected.emit(index)
		await click(source.apply_button,scroll)
		check(world.presentation_settings.hide_doll and world.presentation_settings.limit_effect_count,"actual apply button reaches game " + str(extent))
		check(not world.get_node("Companion").visible and world.combat_vfx.impact_visual_limit==24,"real presentation changes immediately")
		check(world.presentation_settings.effect_detail==global_before.effect_detail,"source low count never invents a detail setting")
		check(world.presentation_global_settings==global_before,"source application preserves global preferences")
		check(source.automatic.disabled and not source.automatic.button_pressed,"unverified current PC/M coordinate mapping cannot auto-activate")
		check(source.status.text.contains("적용했습니다"),"application result is visible")
		check(world.equipped_catalog==equipment and world._effective_attack()==attack,"equipment and combat stats preserved")
		check(FileAccess.get_sha256(save_path)==save_hash,"source UI preserves game save bytes")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://source-settings-%dx%d.png" % [extent.x,extent.y])
		if extent.x==1280:
			await click(host.region_override,scroll)
			check(not world.presentation_settings.hide_doll and not world.presentation_settings.limit_effect_count,"real scope-off restores global preferences")
	var old_rows: String = JSON.stringify(world.source_optimization.territories)
	check(not bool(world.load_source_optimization("user://missing-source").ok) and JSON.stringify(world.source_optimization.territories)==old_rows,"failed source selection preserves active pack")
	await check_local_region(world,save_hash)
	await check_effect_candidate(world,save_hash)
	world.queue_free()
	await process_frame
	var reopened: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(reopened)
	reopened.set_process(false)
	reopened.save_timer = -100000.0
	check(QA.enter_game(reopened),"actual Main restarts")
	check(reopened.source_optimization.territories.size()==195 and reopened.presentation_settings.hide_doll,"source folder and selected preferences survive restart")
	check(reopened.local_presentation_regions.has(reopened.active_map_id) and reopened.local_presentation_result.status=="TWILIGHT_local_estimate" and reopened.local_presentation_result.branch=="condition","own region and explicit condition choice survive actual Main restart")
	reopened.hud.open_settings_info(true)
	await process_frame
	var local_view: Node = reopened.hud.find_child("LocalPresentationRegionSettings",true,false)
	check(local_view!=null and local_view.enabled.button_pressed and local_view.branch.selected==1,"reentered UI shows saved own mode and branch")
	var effect_view: Node = reopened.hud.find_child("PresentationEffectSettings",true,false)
	check(reopened.presentation_effect_pack.manifests.size()==2 and reopened.presentation_effect_enabled and reopened.presentation_effect_action==3,"candidate path, enabled choice and source action survive actual Main restart")
	check(effect_view!=null and effect_view.enabled.button_pressed and effect_view.action.selected==1 and not effect_view.play_button.disabled,"reentered actual effect UI matches saved candidate selection")
	check(FileAccess.get_sha256(save_path)==save_hash,"restart preserves game save")
	reopened.queue_free()
	await process_frame
	print("SOURCE_OPTIMIZATION_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"viewports":["1280x720","960x540"],"native_M_coordinate_or_pixel_approval":false}))
	quit(0 if failures.is_empty() else 1)

func check_failed_store(world: TwilightWorld,host: Node,source: Node,scroll: ScrollContainer,save_hash: String) -> void:
	var path: String = ProjectSettings.globalize_path("user://twilight_ui_settings.cfg")
	var backup: String = path + ".failure-test-backup"
	var preferences: Dictionary = world.presentation_settings.duplicate(true)
	var config_before: String = host.config.encode_to_text()
	var settings_hash: String = FileAccess.get_sha256(path)
	var previous_source: Variant = world.source_optimization
	check(DirAccess.rename_absolute(path,backup)==OK,"move isolated test preferences aside")
	check(DirAccess.make_dir_absolute(path)==OK,"real filesystem rejects replacement of a directory")
	await click(source.apply_button,scroll)
	check(source.status.text.contains("저장하지 못했습니다"),"failed source apply is visible in actual UI")
	check(world.presentation_settings==preferences and not host.region_override.button_pressed,"failed apply changes neither runtime nor scope control")
	check(host.config.encode_to_text()==config_before,"failed apply preserves all preference keys in memory")
	await click(source.zip_button,scroll)
	source.directory_dialog.file_selected.emit(OS.get_environment("TWILIGHT_PATCH523_ZIP"))
	source.directory_dialog.hide()
	check(source.status.text.contains("저장하지 못했습니다") and world.source_optimization==previous_source,"failed source-path save preserves active source instance")
	check(host.config.encode_to_text()==config_before,"failed source-path selection is not retained in memory")
	await click(host.region_override,scroll)
	check(not host.region_override.button_pressed and world.presentation_settings==preferences,"failed scope write rolls control back")
	await click(host.hide_doll,scroll)
	check(not host.hide_doll.button_pressed and world.presentation_settings==preferences,"failed global hide write rolls control back")
	await click(host.reduced_motion,scroll)
	check(not host.reduced_motion.button_pressed and world.presentation_settings==preferences,"failed motion preference rolls control back")
	await click(host.impact_intensity,scroll)
	check(host.impact_intensity.value==float(preferences.impact_intensity)*100.0 and world.presentation_settings==preferences,"failed intensity preference rolls slider and runtime back")
	check(host.presentation_status.text.contains("저장하지 못했습니다"),"preference write failure is visible")
	check(FileAccess.get_sha256(world.save_path())==save_hash,"failed settings transactions preserve character save")
	check(DirAccess.remove_absolute(path)==OK and DirAccess.rename_absolute(backup,path)==OK,"restore unchanged isolated preferences file")
	check(FileAccess.get_sha256(path)==settings_hash,"rejected writes preserve previous settings bytes")

func select_source(source: Node,id: int) -> void:
	for i: int in range(source.regions.item_count):
		if int(source.regions.get_item_metadata(i))==id:
			source.regions.select(i)
			source.regions.item_selected.emit(i)
			return
	check(false,"requested actual source row exists %d" % id)

func check_local_region(world: TwilightWorld,save_hash: String) -> void:
	var host: Node = world.hud.find_child("RenewalSettings",true,false)
	var source: Node = host.find_child("SourceOptimizationSettings",true,false)
	var scroll: ScrollContainer = host.find_child("SettingsScroll",true,false)
	var own: Node = source.local_regions
	check(own!=null and own.enabled.disabled,"own region is absent by default")
	var baseline: Dictionary = world.presentation_settings.duplicate(true)
	var global_before: Dictionary = world.presentation_global_settings.duplicate(true)
	var center: Vector2 = world.player.global_position
	select_source(source,53942)
	own.radius.value = 64
	own.branch.select(0)
	await click(own.save_button,scroll)
	check(world.local_presentation_result.status=="TWILIGHT_local_estimate" and not world.presentation_settings.hide_doll and not world.presentation_settings.limit_effect_count,"actual own region overrides a map-wide preference with exact source defaults")
	check(not source.automatic.button_pressed and source.automatic.disabled,"own region never certifies or activates native M coordinates")
	check(own.status.text.contains("TWILIGHT 자체 영역") and own.status.text.contains("64"),"own mode and configurable game radius are visible")
	world.player.global_position = center+Vector2(64,0)
	world._update_source_optimization()
	check(not world.presentation_settings.hide_doll,"own inclusive edge uses configured game-world bounds")
	world.player.global_position = center+Vector2(65,0)
	world._update_source_optimization()
	check(world.local_presentation_result.status=="outside" and world.presentation_settings==baseline,"leaving own region restores prior game-map preference")
	world.player.global_position = center
	world._update_source_optimization()
	var path: String = ProjectSettings.globalize_path("user://twilight_ui_settings.cfg")
	var backup: String = path+".local-failure-backup"
	var old_config: String = host.config.encode_to_text()
	var old_rule: Dictionary = world.local_presentation_regions[world.active_map_id].duplicate(true)
	check(DirAccess.rename_absolute(path,backup)==OK and DirAccess.make_dir_absolute(path)==OK,"real filesystem blocks own-region preference writes")
	own.radius.value = 128
	await click(own.save_button,scroll)
	check(world.local_presentation_regions[world.active_map_id]==old_rule and host.config.encode_to_text()==old_config,"failed own-region save preserves prior rule and config")
	await click(own.enabled,scroll)
	check(own.enabled.button_pressed and world.local_presentation_regions[world.active_map_id]==old_rule,"failed own-region toggle rolls control back")
	await click(own.remove_button,scroll)
	check(world.local_presentation_regions[world.active_map_id]==old_rule and source.status.text.contains("저장하지 못했습니다"),"failed own-region removal remains visible and preserves active rule")
	check(DirAccess.remove_absolute(path)==OK and DirAccess.rename_absolute(backup,path)==OK,"restore original isolated preferences")
	await click(own.enabled,scroll)
	check(world.local_presentation_result.status=="off" and world.presentation_settings==baseline,"own-region off restores prior preferences")
	await click(own.enabled,scroll)
	check(world.local_presentation_result.status=="TWILIGHT_local_estimate" and not world.presentation_settings.hide_doll,"own-region can be enabled again")
	await click(own.remove_button,scroll)
	check(not world.local_presentation_regions.has(world.active_map_id) and world.presentation_settings==baseline,"actual remove button deletes only the own region")
	select_source(source,169682)
	own.radius.value = 64
	await click(own.save_button,scroll)
	check(world.local_presentation_result.status=="TWILIGHT_local_estimate" and world.presentation_settings.hide_doll,"single-point source recommendation works with explicitly independent own bounds")
	select_source(source,53942)
	own.branch.select(1)
	own.radius.value = 64
	await click(own.save_button,scroll)
	check(world.local_presentation_result.branch=="condition" and world.presentation_settings.hide_doll and world.presentation_settings.limit_effect_count,"original conditional display values are usable through explicit own choice")
	check(world.presentation_global_settings==global_before,"own mode never changes global preferences")
	check(FileAccess.get_sha256(world.save_path())==save_hash,"own regions and position probes leave character save bytes unchanged")
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = extent
		for i: int in range(3): await process_frame
		scroll.ensure_control_visible(own.enabled)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://own-region-%dx%d.png" % [extent.x,extent.y])

func check_effect_candidate(world: TwilightWorld,save_hash: String) -> void:
	var path: String = OS.get_environment("TWILIGHT_PRESENTATION_EFFECT_PACK")
	check(not path.is_empty(),"actual private effect candidate input required")
	var host: Node = world.hud.find_child("RenewalSettings",true,false)
	var source: Node = host.find_child("SourceOptimizationSettings",true,false)
	var scroll: ScrollContainer = host.find_child("SettingsScroll",true,false)
	var effect: Node = source.effect_settings
	check(effect!=null and effect.play_button.disabled and not effect.enabled.button_pressed,"candidate rendering is absent/off by default")
	var stats: Array = [world._effective_attack(),world._effective_max_hp(),world.equipped_catalog.duplicate(true)]
	await click(effect.choose_button,scroll)
	check(is_instance_valid(effect.dialog) and effect.dialog.visible,"actual candidate folder chooser opens")
	effect.dialog.dir_selected.emit(path)
	effect.dialog.hide()
	check(world.presentation_effect_pack.manifests.size()==2 and not effect.play_button.disabled,"actual candidate pack hashes and both action pairs reach UI")
	var pack: Variant = world.presentation_effect_pack
	check(not bool(world.load_presentation_effect_pack("user://missing-effects").ok) and world.presentation_effect_pack==pack,"invalid candidate folder preserves prior selection")
	var cfg: String = ProjectSettings.globalize_path("user://twilight_ui_settings.cfg")
	var backup: String = cfg+".effect-failure-backup"
	var old_config: String = host.config.encode_to_text()
	check(DirAccess.rename_absolute(cfg,backup)==OK and DirAccess.make_dir_absolute(cfg)==OK,"real filesystem blocks candidate preference writes")
	effect._load_directory(path)
	check(world.presentation_effect_pack==pack and effect.status.text.contains("저장하지 못했습니다"),"failed candidate-path save preserves active pack")
	await click(effect.enabled,scroll)
	check(not effect.enabled.button_pressed and not world.presentation_effect_enabled,"failed candidate enable rolls UI and runtime back")
	effect.action.select(1)
	effect.action.item_selected.emit(1)
	check(effect.action.selected==0 and world.presentation_effect_action==0 and host.config.encode_to_text()==old_config,"failed candidate action save restores previous action and config")
	check(DirAccess.remove_absolute(cfg)==OK and DirAccess.rename_absolute(backup,cfg)==OK,"restore candidate preference fixture")
	await click(effect.freeze,scroll)
	host.effect_detail.select(0)
	host.effect_detail.item_selected.emit(0)
	await click(effect.play_button,scroll)
	check(effect.last_preview.get("selected")==24941 and effect.last_preview.get("action")==0,"actual preview factory renders full source effect action0")
	check(effect.last_preview.get("attachments",{}).get("source_layer_nodes")==2,"full effect retains both literal clothes attachments")
	check(effect.status.text.contains("자체 해석 미리보기"),"candidate qualification is visible")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://effect-full-candidate.png")
	host.effect_detail.select(1)
	host.effect_detail.item_selected.emit(1)
	await click(effect.play_button,scroll)
	check(effect.last_preview.get("selected")==29044 and effect.last_preview.get("action")==0,"actual low-detail factory selects 29044 from original simplify mapping")
	check(effect.last_preview.get("attachments",{}).get("source_layer_nodes")==1,"small effect retains its exact 29045 attachment")
	var overlay: Node2D = effect.preview._overlay_nodes.back()
	for facing: int in range(8):
		overlay.advance_source(0.0,"idle",facing,0,false)
		check(overlay._layers[0].texture!=null and overlay._effect_nodes[29045].texture!=null,"actual candidate renders body and attachment in all stored direction candidates %d" % facing)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://effect-small-candidate.png")
	await click(effect.enabled,scroll)
	check(world.presentation_effect_enabled,"explicit candidate runtime opt-in saved")
	var service = preload("res://scripts/animation/original_source_preview.gd").new()
	world.add_child(service)
	check(service._playback_mode=="strict" and service.spawn_source_overlay(24941,0,world.player.global_position),"actual runtime factory accepts explicit per-effect candidate without replacing actor mode")
	check(service._playback_mode=="strict" and service._manifest_path.is_empty() and service._manifest_records.is_empty(),"runtime candidate restores strict actor mode, root and records")
	check(service._overlay_nodes.back().get_meta("selected_source_effect")==29044 and not service.spawn_source_overlay(123,0),"runtime candidate is scoped to the exact source effect pair")
	service.clear()
	service.queue_free()
	effect.action.select(1)
	effect.action.item_selected.emit(1)
	await click(effect.play_button,scroll)
	check(effect.last_preview.get("selected")==29044 and effect.last_preview.get("action")==3,"user-selected source action3 reaches the actual compositor")
	await click(source.choose_button,scroll)
	source.directory_dialog.dir_selected.emit(path.path_join("source_settings"))
	source.directory_dialog.hide()
	check(world.source_optimization.directory==path.path_join("source_settings") and world.source_optimization.territories.size()==195,"same received apply pack supplies all four original settings for actual game reload")
	check([world._effective_attack(),world._effective_max_hp(),world.equipped_catalog]==stats and FileAccess.get_sha256(world.save_path())==save_hash,"candidate previews and runtime adapter preserve gameplay stats, equipment and save bytes")
