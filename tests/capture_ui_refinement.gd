extends SceneTree
## Actual Main UI on isolated data; all inventory grants use existing world actions.
const QA=preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var folder: String
var captures: Array=[]
var chosen: String=""
func _initialize() -> void:call_deferred("run")
func capture(label: String) -> void:
	for i: int in range(5):await process_frame
	await RenderingServer.frame_post_draw
	if label.begins_with("inventory-detail"):
		var bag: Node=world.hud.lineage_inventory_ui
		var bounds: Rect2=bag.detail_panel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,bag.detail_panel.size)
		assert(root.get_visible_rect().grow(1).encloses(bounds),"detail stays within viewport")
		for action: Control in [bag.detail_action,bag.lock_button]:
			var rect: Rect2=action.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,action.size)
			assert(bounds.grow(1).encloses(rect),"detail action stays inside popup")
		assert(bag.detail_text.get_content_height()>bag.detail_text.size.y,"long options remain scrollable")
	var pixels: Image=root.get_texture().get_image()
	var path: String=folder+"/"+label+".png"
	assert(pixels.save_png(path)==OK)
	captures.append({"name":label,"width":pixels.get_width(),"height":pixels.get_height(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
func run() -> void:
	folder=OS.get_environment("TWILIGHT_UI_CAPTURE_DIR")
	assert(not folder.is_empty());DirAccess.make_dir_recursive_absolute(folder)
	seed(20261025)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	for i: int in range(8):await process_frame
	assert(QA.enter_game(world))
	world.save_timer=-100000;world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	var equipped: Array[String]=[]
	for raw: Dictionary in world.catalog_db.get("아이템",[]):
		var slot: String=world._equipment_slot_base(raw)
		if slot in ["weapon","body","boots"] and slot not in equipped:
			world._equip_or_acquire_item(raw,true);equipped.append(slot)
		if equipped.size()==3:break
	world._update_hud()
	var hud: Node=world.hud
	var bag: Node=hud.lineage_inventory_ui
	for entry: Dictionary in bag._inventory_entries():
		if bag._is_item_equipped(str(entry.reference)):chosen=str(entry.reference);break
	assert(not chosen.is_empty())
	world._set_item_locked(chosen,true)
	var inventory: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent)
		for i: int in range(3):await process_frame
		hud.workspace.title_dragged=false;hud._fit_hud()
		var suffix: String="-%dx%d" % [extent.x,extent.y]
		hud._close_workspace();hud.toggle_inventory();bag._select_item(chosen)
		await capture("inventory"+suffix)
		bag.open_detail();await capture("inventory-detail"+suffix)
		hud.toggle_menu();await capture("menu"+suffix)
		hud.open_skills();await capture("skills"+suffix)
		hud.open_catalog("변신");await capture("transform"+suffix)
		hud.open_shop();await capture("shop"+suffix)
		hud.open_warehouse();await capture("warehouse"+suffix)
		hud.open_crafting();await capture("crafting"+suffix)
	assert(world.inventory==inventory and world.item_instances==instances)
	FileAccess.open(folder+"/render-results.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"captures":captures,"inventory_unchanged":true,"physical_ids_unchanged":true},"\t"))
	print("UI_REFINEMENT_CAPTURE_RESULT ",JSON.stringify({"captures":captures.size(),"failures":[]}))
	world.queue_free();quit()
