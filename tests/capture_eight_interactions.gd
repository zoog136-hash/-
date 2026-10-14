extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const COORD = preload("res://scripts/maps/world_coordinates.gd")
var world: TwilightWorld
var hud: Node
func _initialize() -> void: call_deferred("run")
func frames(n: int = 4) -> void:
	for i: int in range(n): await process_frame
func point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)
func touch(p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p
	e.index = 12
	e.pressed = down
	root.push_input(e,true)
func tap(p: Vector2) -> void:
	touch(p,true)
	touch(p,false)
	await frames()
func shot(file: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_user_data_dir()+"/interaction-review"
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = root.get_texture().get_image()
	if image.save_png(directory+"/"+file+".png") != OK:
		push_error("INTERACTION_CAPTURE_SAVE_FAILED")
	else: print("INTERACTION_CAPTURE ",directory+"/"+file+".png")
func run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	if not QA.enter_game(world): push_error("INTERACTION_CAPTURE_CLASS_FAILED"); quit(1); return
	hud = world.hud
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	world._grant_playtest_catalog_item("낡은 장검",2)
	hud.toggle_inventory()
	await frames()
	var bag: Control = hud.lineage_inventory_ui
	bag.search_line.text = "낡은 장검"
	bag._refresh_inventory_grid()
	await frames()
	await tap(point(bag.slot_buttons.values()[0]))
	if not bag.detail_panel.is_visible_in_tree(): push_error("INTERACTION_CAPTURE_DETAIL_FAILED")
	await shot("01-single-touch-detail")
	hud._close_workspace()
	await frames()
	var i: int = 0
	for actor: Node in world.monsters_root.get_children():
		actor.hide()
		if i < 3 and actor is TwilightMonster:
			actor.show()
			actor.global_position = COORD.screen_to_world(root,Vector2(470+i*115,330))+Vector2(0,28)
			i += 1
	world.world_interactions.clear_selection()
	touch(Vector2(470,330),true)
	var drag := InputEventScreenDrag.new()
	drag.index = 12
	drag.position = Vector2(700,330)
	root.push_input(drag,true)
	touch(Vector2(700,330),false)
	await frames()
	world.player.set_auto_enabled(true)
	if world.world_interactions.listing.item_count >= 3:
		var listing: ItemList = world.world_interactions.listing
		await tap(listing.get_global_transform_with_canvas()*listing.get_item_rect(2).get_center())
	await shot("02-promoted-targets-auto-on")
	world.level = 90
	world.gold = 1000000
	hud.open_npc_teleport()
	await frames()
	var locations: ItemList = hud.workspace.find_child("NpcTeleportDestinations",true,false)
	await tap(locations.get_global_transform_with_canvas()*locations.get_item_rect(2).get_center())
	await shot("03-native-teleport-selection")
	print("INTERACTION_CAPTURE_OK")
	world.queue_free()
	await process_frame
	quit(0)
