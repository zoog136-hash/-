extends SceneTree
## Screenshots of Main.tscn, not a substitute mockup. Use an isolated XDG_DATA_HOME.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const ASSETS = preload("res://addons/twilight_l1j/twilight_runtime_assets.gd")
const SHOPS = preload("res://addons/twilight_l1j/twilight_reviewed_shops.gd")
const OUTPUT: String = "user://l1j-runtime-review"
var world: TwilightWorld
var captures: int = 0
var failed: bool = false

func _initialize() -> void: call_deferred("_run")

func capture(name_value: String) -> void:
	for i: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	if pixels == null or pixels.is_empty() or pixels.save_png(OUTPUT + "/" + name_value + ".png") != OK:
		failed = true
		push_error("L1J runtime render missing " + name_value)
	else:
		captures += 1
		print("L1J_RUNTIME_CAPTURE ", name_value)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	if not CLASS_QA.enter_game(world):
		push_error("Rendered gameplay class confirmation failed")
		quit(1)
		return
	world.set_process(false)
	world.save_timer = -10000
	world.field_population.set_process(false)
	world._clear_monsters()
	world._clear_drops()
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550,4300)))
	world.player.set_physics_process(false)
	world.player.camera.zoom = Vector2.ONE
	world.player.camera.position = Vector2(0,-110)
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSETS.PATH))
	for index: int in range(bindings.monsters.size()):
		var binding: Dictionary = bindings.monsters[index]
		for value: Dictionary in world.monster_db:
			if str(value.name) != str(binding.game_name): continue
			var actor: TwilightMonster = world.MONSTER_SCENE.instantiate()
			world.monsters_root.add_child(actor)
			actor.global_position = world.player.global_position + Vector2(float(index-2)*110+55,-120)
			actor.setup(value.duplicate(true),world.player,world,world._monster_texture(value))
			actor.set_physics_process(false)
			break
	for index: int in range(bindings.items.size()):
		var binding: Dictionary = bindings.items[index]
		world._grant_playtest_catalog_variant(str(binding.game_source_id),1)
		world._spawn_ground_drop(str(binding.game_name),world.player.global_position+Vector2(float(index-2)*105,40))
	await capture("01-bound-art-field")
	world.hud.open_catalog("아이템")
	world.hud.catalog_search.text = "수정 단검"
	world.hud._refresh_catalog_list("수정 단검")
	for index: int in range(world.hud.catalog_results.size()):
		if str(world.hud.catalog_results[index].get("sourceId","")) == "423":
			world.hud.catalog_list.select(index)
			world.hud._on_catalog_item_selected(index)
			break
	await capture("02-bound-icon-catalog")
	world.hud.catalog_panel.hide()
	world.hud.refresh_inventory(world.inventory)
	world.hud.toggle_inventory()
	await capture("03-bound-icons-inventory")
	world.hud.inventory_panel.hide()
	var profiles: Array = SHOPS.profiles(world.catalog_db.get("아이템", []))
	var expected: int = 3
	if not profiles.is_empty():
		expected = 5
		world.gold = 200000
		world._update_hud()
		world.hud.open_shop()
		var selector: OptionButton = world.hud.workspace.find_child("ShopVendor",true,false)
		selector.select(1)
		selector.item_selected.emit(1)
		await capture("04-reviewed-npc-offer")
		selector.get_parent().call("_buy")
		await capture("05-reviewed-npc-purchase")
	print("L1J_RUNTIME_RENDER_OK captures=",captures," directory=",ProjectSettings.globalize_path(OUTPUT),
		" synthetic=",bool(bindings.get("synthetic_fixture_only",false)))
	world.queue_free()
	await process_frame
	quit(1 if failed or captures != expected else 0)
