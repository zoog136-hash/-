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
		# The inventory migration intentionally replaced the old stock potion.
		# Verify the exact published icon bytes and their honest alias provenance.
		var record: Dictionary = {"name":item_name,"type":"소모품","slot":"consumable"}
		var mapped: Dictionary = RESOLVER.describe(record,item_name)
		check(mapped.get("status","") == "inven_visual_alias","production potion uses reviewed Inven artwork: "+item_name)
		check(not str(mapped.get("path","")).is_empty() and icon.texture == load(str(mapped.get("path",""))),"production quickslot uses published resource: "+item_name)
		check(hud.quickslot_captions[index].text == str(world.inventory[item_name]),"production quantity stays connected: "+item_name)
		var provenance: Dictionary = icon.get_meta("item_visual",{})
		check(provenance.get("status","") == "inven_visual_alias" and provenance.get("source_id","") == "","visual alias does not claim publisher item identity: "+item_name)
		check(RESOLVER.describe({"name":item_name,"sourceId":"unknown-publisher-id"},item_name).path == "","explicit unknown source cannot borrow local art: "+item_name)
	check(observed.size() == LOCAL_POTIONS.size(),"all three real starter potion slots were inspected")
	# Current main deliberately removes the misleading ruby -> potion link.
	# Inspect that real production state separately from explicit legacy input.
	var ruby_record: Dictionary = {"name":"드래곤의 루비","type":"축복충전"}
	var ruby_before: String = JSON.stringify(ruby_record)
	var legacy_images: Dictionary = hud.item_image_index.get("아이템",{})
	# The current item loader deliberately removes the misleading ruby->HP
	# potion stock icon. Do not restore a false visual identity in production.
	check(not legacy_images.has("드래곤의 루비"),"production rejects the false ruby-as-HP-potion icon identity")
	var current_ruby: Dictionary = RESOLVER.describe(ruby_record,ruby_record.name,legacy_images)
	check(current_ruby.path == "" and current_ruby.family == "gem" and current_ruby.status == "self_authored_substitute","ruby uses an honestly identified gem symbol without an explicit verified image")
	# Separately retain the resolver's backward-compatible, caller-supplied
	# exact-name link recovery without pretending it is publisher art.
	var explicit_legacy: Dictionary = {"드래곤의 루비":POTION_PATH}
	var ruby: Dictionary = RESOLVER.describe(ruby_record,ruby_record.name,explicit_legacy)
	check(ruby.path == POTION_PATH and ruby.route == "legacy_exact_name_index","explicit legacy ruby index remains recoverable")
	check(ruby.status == "bundled_ui_art" and ruby.source_id == "","explicit ruby placeholder never claims verified original art")
	check(RESOLVER.texture(ruby_record,ruby_record.name,explicit_legacy) == load(POTION_PATH),"explicit ruby link resolves its actual preserved bundled texture")
