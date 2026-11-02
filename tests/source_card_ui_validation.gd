extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var folder: String = "user://source-card-ui-review"
var private_ui_root: String = ""
var errors: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message);push_error(message)
func capture(label: String) -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"capture "+label)
func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=pressed;root.push_input(event,true)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--private-ui-root="):private_ui_root=arg.trim_prefix("--private-ui-root=")
	if private_ui_root.is_empty() or not ResourceLoader.exists("res://scripts/lineagem_pack_install.gd"):
		push_error("Native runtime branch and explicit --private-ui-root are required");quit(2);return
	folder=ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	var installer: Script=load("res://scripts/lineagem_pack_install.gd")
	installer._session_root=private_ui_root
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world)
	for frame: int in range(10): await process_frame
	check(QA.enter_game(world),"class selection")
	world.save_timer=-10000;world.set_process(false)
	world.field_population.set_process(false);world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
	for category: String in ["변신","마법인형","성물"]:
		world.card_draw_fusion.owned[category]={};world.card_draw_fusion.spare[category]={}
		for index: int in range(2):
			var record: Dictionary=world.catalog_db[category][index]
			var key: String=world.card_draw_fusion.card_id(record)
			world.card_draw_fusion.owned[category][key]=true
			world.card_draw_fusion.spare[category][key]=2
	world._update_hud()
	var hud: Node=world.hud
	# The private map pack is separate from UI assets. Exercise UI input in
	# isolation while leaving the production map/bootstrap guard unchanged.
	hud.process_mode=Node.PROCESS_MODE_ALWAYS
	var state_before: int=hash(world.card_draw_fusion.export_state())
	for category: String in ["변신","마법인형","성물"]:
		hud.open_catalog(category)
		await capture(category+"-list")
		check(hud.catalog_results.size()>2,"list populated "+category)
		check(hud.catalog_list.get_item_metadata(0)==world.card_draw_fusion.card_id(hud.catalog_results[0]),"stable source selection metadata "+category)
		if ResourceLoader.exists("res://scripts/ui/source_card_presentation.gd"):
			var listing: ItemList=hud.catalog_list
			listing.get_v_scroll_bar().value=0
			for frame: int in range(2):await process_frame
			var third: Rect2=listing.get_item_rect(2)
			var point: Vector2=listing.get_global_transform_with_canvas()*third.get_center()
			touch(0,point,true);await process_frame;touch(0,point,false)
			for frame: int in range(2):await process_frame
			check(world.card_draw_fusion.card_id(hud.selected_catalog_record)==world.card_draw_fusion.card_id(hud.catalog_results[2]),"touch selects native source ID "+category)
			check(hud.catalog_equip_button.disabled and hud.catalog_equip_button.text.contains("미보유"),"unowned source card is read-only "+category)
			var old_state: Dictionary=hud.character_state
			hud.character_state=old_state.duplicate(true)
			var other: Dictionary=hud.catalog_results[0].duplicate(true);other.sourceId="m508:999:999999"
			hud.character_state.equipped[category]=other
			hud._select_catalog_index(0)
			check(not hud.catalog_equip_button.disabled,"same-name foreign source ID is not current applied card "+category)
			hud.character_state=old_state
			installer._session_root=private_ui_root+"-missing"
			hud._select_catalog_index(0)
			check(hud.catalog_preview.texture==null and hud.catalog_preview.get_meta("original_card_asset",{}).get("status")=="missing","missing original shows explicit empty state "+category)
			installer._session_root=private_ui_root
		hud._select_catalog_index(0);hud._set_catalog_detail_view(true)
		await capture(category+"-detail")
		hud._set_catalog_detail_view(false);hud.catalog_list.get_v_scroll_bar().value=100
		hud._close_workspace();hud.open_catalog(category)
		check(hud.workspace.visible,"reopen "+category)
		if hud.has_method("open_normal_card_collections"):
			hud.open_normal_card_collections(category)
			await capture(category+"-collections")
		hud.open_settings_info();hud._close_workspace();hud.open_catalog(category)
		check(hud.catalog_category==category,"settings/catalog restore "+category)
	root.size=Vector2i(854,480);DisplayServer.window_set_size(root.size)
	for category: String in ["변신","마법인형","성물"]:
		hud.open_catalog(category);hud._set_catalog_detail_view(false)
		await capture(category+"-compact-list")
		hud._set_catalog_detail_view(true)
		await capture(category+"-compact-detail")
		check(hud.catalog_equip_button.size.y>=40,"compact apply touch target "+category)
	check(hash(world.card_draw_fusion.export_state())==state_before,"UI navigation preserves ownership/spare ledger")
	var file=FileAccess.open(folder+"/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"errors":errors,"engine":Engine.get_version_info(),"test_state":"UI-only HUD PROCESS_MODE_ALWAYS; in-memory ownership fixture; isolated XDG data; no user-save writes", "source_map_test":world.field_map != null and bool(world.field_map.get_meta("base508_source_test", false))},"\t"));file.close()
	print("SOURCE_CARD_UI_CAPTURE "+str(checks)+" errors "+str(errors))
	world.queue_free()
	for frame: int in range(3):await process_frame
	quit(0 if errors.is_empty() else 1)
