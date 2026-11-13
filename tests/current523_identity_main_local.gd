extends SceneTree
## Real private inputs, Main and existing UI. Use isolated XDG data, never a personal save.
const PACK = preload("res://scripts/resources/current523_identity_pack.gd")
const BASE = preload("res://scripts/lineagem_base508.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
var world: Node
var capture_prefix: String = ""

func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("CHECK FAILED: ",message)

func _initialize() -> void: call_deferred("run")

func frames(count: int = 2) -> void:
	for index: int in range(count): await process_frame

func confirm() -> bool:
	var button: Button = world.hud.get_node("Root").find_child("ConfirmTransaction",true,false)
	if button == null: return false
	button.pressed.emit()
	await frames()
	return true

func equip_from_menu(source_id: String) -> bool:
	world.hud.open_catalog("변신")
	await frames()
	var found: int = -1
	for index: int in range(world.hud.catalog_filtered_results.size()):
		if str(world.hud.catalog_filtered_results[index].get("sourceId","")) == source_id: found = index
	if found < 0: return false
	world.hud.catalog_page = found / world.hud.catalog_page_size
	world.hud._apply_catalog_page()
	world.hud._select_catalog_index(found % world.hud.catalog_page_size)
	if world.hud.catalog_equip_button.disabled:
		return str(world.equipped_catalog["변신"].get("sourceId","")) == source_id
	world.hud.catalog_equip_button.pressed.emit()
	return await confirm()

func capture(suffix: String) -> void:
	if capture_prefix.is_empty() or DisplayServer.get_name() == "headless": return
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_prefix + suffix + ".png") == OK,"actual GL capture " + suffix)

func run() -> void:
	var archive: String = ""
	var restart: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): archive = argument.trim_prefix("--pack=")
		if argument.begins_with("--capture-prefix="): capture_prefix = argument.trim_prefix("--capture-prefix=")
		if argument == "--read-installed": restart = true
	if archive.is_empty() and not restart: printerr("Authorized --pack plus isolated profile required"); quit(2); return
	root.size = Vector2i(1280,720)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	check(bool(PACK.options().enabled) == restart,"opt in default or explicit saved restart state")
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world),"real class selection enters game")
	world.set_process(false)
	world.save_timer = -100000.0
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	var actor: Node = world.player.get_node("Current523IdentityActor")
	if restart:
		await frames()
		check(str(world.equipped_catalog["변신"].get("sourceId","")) == "m508:1:161","fresh process restores original saved equipped identity")
		check(actor.is_player_override_active() and int(actor.status_details().source_sprite_id) == 11334,"fresh process reconnects saved pack and actor")
	world.hud.open_settings_info(true)
	await frames()
	var panel: Node = world.hud.workspace.find_child("Current523IdentitySettings",true,false)
	check(panel != null,"identity controls reachable in real settings")
	if panel == null: finish(); return
	if restart:
		var saved_sha: String = FileAccess.get_sha256(world.save_path())
		check(panel.enabled_toggle.button_pressed and panel.selected_root == PACK.options().root,"fresh settings restore selected root and opt in")
		panel.find_child("Restore523PreviousAppearance",true,false).pressed.emit()
		await frames()
		check(not actor.is_player_override_active() and world.player.class_sprite.visible,"restart previous-display action restores actual current class fallback")
		panel.enabled_toggle.button_pressed = true
		check(panel._apply().ok,"restart UI reapplies preserved exact pack")
		await frames()
		check(actor.is_player_override_active() and int(actor.status_details().source_sprite_id) == 11334,"restart UI reconnects correct actor")
		check(FileAccess.get_sha256(world.save_path()) == saved_sha,"restart toggles preserve original game save bytes")
		world.hud._close_workspace()
		await capture("restart-field")
		world.queue_free()
		await frames()
		finish()
		return
	if not restart:
		panel.picker.file_selected.emit(archive)
		while panel.installer.busy: await process_frame
		check(not panel.choose.disabled and panel.status.text.contains("완료"),"actual UI archive selection installs pinned pack")
		check(not PACK.options().enabled,"installation alone does not activate actor")
		panel.enabled_toggle.button_pressed = true
		panel.zoom_input.value = 0.5
		check(panel._apply().ok,"settings persist opt in with selected installed root")
	check(PACK.manifest_at(str(PACK.options().root)).cards.size() == 26,"all26 exact existing card bindings installed")
	print("IDENTITY_PHASE installed")
	var manifest: Dictionary = PACK.manifest_at(str(PACK.options().root))
	for record: Dictionary in world.catalog_db["변신"]:
		if manifest.cards.has("transform:" + str(record.sourceId)):
			world.card_draw_fusion.owned["변신"][world.card_draw_fusion.card_id(record)] = true
			world.card_draw_fusion.spare["변신"][world.card_draw_fusion.card_id(record)] = 1
	world._update_hud()
	var collection: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
	var gold: int = world.gold
	var inventory: Dictionary = world.inventory.duplicate(true)
	var physics: Array = [world.player.collision_layer,world.player.collision_mask,world.player.move_speed,world.player.attack_speed_multiplier]
	check(await equip_from_menu("m508:1:161"),"existing transformation UI applies exact owned161")
	await frames()
	check(actor.is_player_override_active() and int(actor.status_details().source_sprite_id) == 11334,"real player consumes confirmed11334 layers")
	check(not world.player.class_sprite.visible and actor._layers.size() == 2,"baseline hidden only after both real layers render")
	check(actor.label.text.contains("정체확인") and actor.label.text.contains("추정"),"field display keeps identity/pixel distinction")
	check(world._save_game(true) == OK,"real atomic game save before presentation settings")
	var saved: String = world.save_path()
	var save_sha: String = FileAccess.get_sha256(saved)
	var idle_frame: int = actor.frame_index
	await create_timer(0.23).timeout
	check(actor.frame_index != idle_frame,"real source idle clock advances")
	world.player.motion.state = "walk"
	world.player.motion.facing8 = 5
	await frames()
	check(actor.source_role == "walk" and actor.source_facing == 0,"host movement reaches exact walk and source slot")
	check(is_equal_approx(float(actor.status_details().fps),36.0),"source explicit walk36FPS wins over own fallback12")
	world.player.motion.state = "run"
	await frames()
	check(actor.source_role == "walk" and actor.status_details().run_policy != "","unavailable run11334 is explicit actual WALK policy")
	world.player.motion.state = "idle"
	var strike_counter: Array[int] = [0]
	world.player.attack_strike.connect(func(_sequence: int) -> void: strike_counter[0] += 1)
	var sequence: int = world.player.start_combat_attack(world.player.global_position + Vector2.RIGHT * 20,0.5,"slash")
	await frames()
	check(actor.source_role == "attack" and int(actor.status_details().sequence) == sequence,"existing gameplay attack sequence drives source presentation")
	check(strike_counter[0] == 0,"presentation clock never emits combat strike")
	world.player.cancel_attack()
	world.player.motion.state = "idle"
	world.hud._close_workspace()
	await capture("field")
	world.hud.open_settings_info(true)
	await frames()
	panel = world.hud.workspace.find_child("Current523IdentitySettings",true,false)
	check(panel.enabled_toggle.button_pressed and panel.selected_root == PACK.options().root,"settings reentry restores selected identity pack")
	var scroll: ScrollContainer = world.hud.workspace.find_child("SettingsScroll",true,false)
	if scroll != null: scroll.ensure_control_visible(panel)
	await capture("settings")
	var before: Dictionary = PACK.options()
	var revision: int = PACK.revision
	var config_sha: String = FileAccess.get_sha256(PACK.SETTINGS)
	var preserved: String = PACK.SETTINGS + ".preserved-test"
	check(DirAccess.rename_absolute(PACK.SETTINGS,preserved) == OK,"preserve actual identity configuration before simulated write failure")
	check(DirAccess.make_dir_absolute(PACK.SETTINGS) == OK,"obstruct only isolated configuration destination")
	panel.zoom_input.value = 2.0
	check(not panel._apply().ok and panel.status.text.contains("이전"),"UI reports settings failure")
	check(PACK.options() == before and PACK.revision == revision and actor.is_player_override_active(),"failed save retains prior active pack and actor")
	check(FileAccess.get_sha256(preserved) == config_sha,"failed save preserves original config bytes")
	DirAccess.remove_absolute(PACK.SETTINGS)
	DirAccess.rename_absolute(preserved,PACK.SETTINGS)
	world.hud.open_settings_info(true)
	await frames()
	panel = world.hud.workspace.find_child("Current523IdentitySettings",true,false)
	check(is_equal_approx(panel.zoom_input.value,0.5),"reentry rejects failed pending zoom")
	panel.find_child("Restore523PreviousAppearance",true,false).pressed.emit()
	await frames()
	check(not actor.is_player_override_active() and world.player.class_sprite.visible,"UI previous appearance restores actual baseline when old native pack absent")
	check(str(world.equipped_catalog["변신"].sourceId) == "m508:1:161","previous appearance preserves equipped transformation identity")
	panel.enabled_toggle.button_pressed = true
	check(panel._apply().ok,"identity mode reenabled through UI")
	await frames()
	var member: String = "Sprite/3644-8.sp2"
	var raw_path: String = str(PACK.options().root).path_join(str(manifest.members[member].path))
	var raw_before: PackedByteArray = FileAccess.get_file_as_bytes(raw_path)
	var file := FileAccess.open(raw_path,FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0,1,2]))
	file.close()
	await create_timer(0.6).timeout
	check(not actor.is_player_override_active() and world.player.class_sprite.visible and not actor.problem.is_empty(),"cached-frame corruption safely restores current baseline")
	check(not panel._apply().ok and PACK.options() == before,"corrupt pack cannot replace saved active selection")
	file = FileAccess.open(raw_path,FileAccess.WRITE)
	file.store_buffer(raw_before)
	file.close()
	check(PACK.save_options(before).ok,"restored original bytes permit explicit retry")
	await frames()
	check(actor.is_player_override_active(),"revalidated exact bytes restore actor")
	check(FileAccess.get_sha256(raw_path) == manifest.members[member].sha256,"test restores installed original SP2 exactly")
	print("IDENTITY_PHASE rollback_verified")
	for key: String in manifest.cards:
		check(await equip_from_menu(key.trim_prefix("transform:")),"actual existing menu equips " + key)
		await frames()
		var selection: Dictionary = BASE.select_visual_key(key,world._source_visual_context())
		check(actor.is_player_override_active() and int(actor.status_details().source_sprite_id) == int(selection.get("sprite_id",-2)),"exact selected root consumed " + key)
		for role: String in ["idle","walk","attack","run"]:
			world.player.motion.state = role
			for direction: int in range(8):
				world.player.motion.facing8 = direction
				await frames(1)
				check(actor.is_player_override_active(),"complete real layers " + key + "/" + role + "/" + str(direction))
		world.player.motion.state = "idle"
		world.player.set_source_weapon_visual("한손검")
		await frames()
		check(actor.is_player_override_active() and int(actor.status_details().source_weapon_type) == 1,"actual equipped-weapon consumer selects exact sword bank " + key)
		for role: String in ["idle","walk","attack"]:
			world.player.motion.state = role
			for direction: int in range(8):
				world.player.motion.facing8 = direction
				await frames(1)
				check(actor.is_player_override_active() and int(actor.status_details().source_action_id) == int({"idle":7,"walk":4,"attack":5}[role]),"exact sword role " + key + "/" + role + "/" + str(direction))
		world.player.motion.state = "idle"
		world.player.set_source_weapon_visual("")
	print("IDENTITY_PHASE all26_ui_and_weapon_banks")
	check(world.card_draw_fusion.export_state() == collection,"UI apply/remove never consumes or duplicates cards")
	check(world.gold == gold and world.inventory == inventory,"presentation leaves gold and inventory unchanged")
	check([world.player.collision_layer,world.player.collision_mask,world.player.move_speed,world.player.attack_speed_multiplier] == physics,"presentation leaves player physics and speed unchanged")
	check(FileAccess.get_sha256(saved) == save_sha,"settings success/failure and UI changes preserve preexisting save bytes")
	# Reapply161 so a fresh process must restore both equipped identity and selected pack.
	check(await equip_from_menu("m508:1:161"),"restore restart identity through real card menu")
	world.hud.catalog_clear_button.pressed.emit()
	check(await confirm(),"existing transformation remove confirmation")
	await frames()
	check(not actor.is_player_override_active() and world.player.class_sprite.visible,"actual unequip clears retained identity and restores class")
	world.player.set_source_weapon_visual("sword")
	await frames()
	check(not actor.is_player_override_active(),"equipment update cannot resurrect removed transformation")
	check(await equip_from_menu("m508:1:161"),"real menu reapply for restart")
	check(world._save_game(true) == OK,"save confirmed existing equipped identity for restart")
	world.queue_free()
	await frames()
	finish()

func finish() -> void:
	print("CURRENT523_IDENTITY_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_UI_EXACT26_IDENTITY_ESTIMATED_PIXELS; BASELINE_CLASS_FALLBACK_WITHOUT_OLD_FULL_PACK"}))
	quit(0 if failures.is_empty() else 1)
