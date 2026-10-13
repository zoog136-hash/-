extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const POTION_PATH: String = "res://assets/ui/potionRed.png"
const LOCAL_POTIONS: Array[String] = ["HP 물약","강력 HP 물약","축복받은 HP 물약"]
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		print("LOCAL_ITEM_ICON_FAIL: ",description)

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for frame: int in range(8): await process_frame
	check(QA.enter_game(world),"production class selection")
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	var hud: Node = world.hud
	var observed: Array[String] = []
	for index: int in range(hud.quickslot_icons.size()):
		var entry: Dictionary = world.quickslots[hud.quickslot_index(index)]
		var item_name: String = str(entry.get("id",""))
		if entry.get("kind","") != "item" or item_name not in LOCAL_POTIONS: continue
		observed.append(item_name)
		var icon: TextureRect = hud.quickslot_icons[index]
		check(icon.texture == load(POTION_PATH),"production quickslot retains bundled art: "+item_name)
		check(hud.quickslot_captions[index].text == str(world.inventory[item_name]),"production quantity stays connected: "+item_name)
		var provenance: Dictionary = icon.get_meta("item_visual",{})
		check(provenance.get("status","") == "bundled_ui_art" and provenance.get("source_id","") == "","local icon never claims original source art: "+item_name)
		check(RESOLVER.describe({"name":item_name,"sourceId":"unknown-publisher-id"},item_name).path == "","explicit unknown source cannot borrow local art: "+item_name)
	check(observed.size() == LOCAL_POTIONS.size(),"all three real starter potion slots were inspected")
	# world._load_data retains this explicit pre-rework UI index link. It is
	# bundled placeholder art, never evidence of publisher-original ruby art.
	var ruby_record: Dictionary = {"name":"드래곤의 루비","type":"축복충전"}
	var ruby_before: String = JSON.stringify(ruby_record)
	var legacy_images: Dictionary = hud.item_image_index.get("아이템",{})
	check(legacy_images.get("드래곤의 루비","") == POTION_PATH,"production still preserves the explicit legacy ruby icon link")
	var ruby: Dictionary = RESOLVER.describe(ruby_record,ruby_record.name,legacy_images)
	check(ruby.path == POTION_PATH and ruby.route == "legacy_exact_name_index","ruby uses its explicit legacy index rather than the starter-potion name rule")
	check(ruby.status == "bundled_ui_art" and ruby.source_id == "","legacy ruby placeholder never claims verified original art")
	check(RESOLVER.texture(ruby_record,ruby_record.name,legacy_images) == load(POTION_PATH),"legacy ruby resolves the actual preserved bundled texture")
	var unindexed: Dictionary = RESOLVER.describe(ruby_record,ruby_record.name)
	check(unindexed.path == "" and unindexed.family == "gem","ruby without an explicit image link receives its appropriate family symbol")
	check(RESOLVER.describe({"name":ruby_record.name,"sourceId":"unknown-publisher-id"},ruby_record.name,legacy_images).path == "","an explicit unknown ruby ID cannot borrow the name-only index")
	check(JSON.stringify(ruby_record) == ruby_before,"ruby visual lookup preserves the existing item record")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var wrong: Dictionary = catalog["아이템"][0].duplicate(true)
	wrong.name = "HP 물약"
	check(RESOLVER.describe(wrong,wrong.name).path == "","known source ID with a local item name remains rejected")
	var capture_path: String = OS.get_environment("TWILIGHT_UI_CAPTURE_PATH")
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(capture_path) == OK,"focused production HUD capture")
	world.queue_free()
	await process_frame
	print("LOCAL_ITEM_ICON_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty(): print("LOCAL_ITEM_ICON_OK")
	quit(0 if failures.is_empty() else 1)
