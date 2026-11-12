extends SceneTree
## Opt-in actual Main integration. Test grants use the production source-card
## acquisition interface with explicit fixture provenance; book learning costs,
## original media and device rendering are outside this test's scope.
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const CATALOG = preload("res://scripts/characters/class_catalog.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CHARACTER_MAIN_FAIL ", label)
	return ok

func same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func main_world() -> Node:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer = -100000
	return world

func source_card(world: Node, category: String) -> Dictionary:
	for record: Dictionary in world.catalog_db.get(category, []):
		if record.get("source_snapshot") == "patch523" and int(record.get("source_card_id", 0)) > 0 and world.card_draw_fusion.known_ids.get(category, {}).has(CARDS.card_id(record)):
			return record.duplicate(true)
	return {}

func grant_card(world: Node, category: String, record: Dictionary, label: String) -> bool:
	if not check(not record.is_empty(), label + ": original card record exists"): return false
	var result: Dictionary = world.card_draw_fusion.receive_source_card(category, record, {"origin":"character_account_integration_test", "card_id":int(record.source_card_id), "source_snapshot":"patch523"})
	return check(result.get("ok", false), label + ": production source-card acquisition")

func seed_private_skill(world: Node, label: String) -> String:
	## A controlled learned-state fixture using a real class-specific catalog ID.
	## It tests persistence/ownership only, not a book-acquisition shortcut.
	for record: Dictionary in world.original_skills.catalog.records:
		var id: String = str(record.get("id", ""))
		var source_profile: Dictionary = world.original_skills.catalog.source523.profiles.get(id, {})
		var source_row: Variant = source_profile.get("row", {})
		if not id.is_empty() and str(record.get("class", "")) == world.job_class and source_row is Dictionary and int(source_row.get("ID", 0)) > 0 and not world.original_skills.catalog.learned.has(id):
			world.original_skills.catalog.learned[id] = 1
			check(true, label + ": original-mapped class-specific learned-state fixture")
			return id
	check(false, label + ": real class-specific skill exists")
	return ""

func assign_private_quickslot(world: Node, from_end: int, label: String) -> Array:
	# Register an actually held source item through the same handler as the HUD.
	# Invalid arbitrary dictionaries are intentionally sanitized by World.
	world.quickslots = []
	world._normalize_quickslots()
	var slot: int = world.quickslots.size() - from_end
	for key: Variant in world.inventory:
		var item_name: String = str(key)
		if int(world.inventory[key]) <= 0 or not world._quickslot_item_supported(item_name): continue
		world._on_quickslot_assignment_requested(slot, "item", item_name)
		check(world.quickslots[slot].get("kind") == "item" and world.quickslots[slot].get("id") == item_name and world.ui_preferences.edited_quickslots.get(world.job_class, false), label + ": actual item quickslot registration")
		return world.quickslots.duplicate(true)
	check(false, label + ": held supported item exists for quickslot")
	return []

func finish() -> void:
	ACCOUNT.session.clear()
	print("CHARACTER_MAIN_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"scope":"actual Main and owned original523 definitions; non-empty source-card acquisition and shared updates, private controlled learned-state/slots/inventory/gold; no learning cost, original media or device claim"}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	if OS.get_environment("TWILIGHT_CHARACTER_REGRESSION_ISOLATED") != "1" or FileAccess.file_exists(ACCOUNT.DEFAULT_PATH):
		printerr("CHARACTER_MAIN_FAIL explicit fresh isolated XDG profile required; existing player save untouched")
		quit(2)
		return
	ACCOUNT.session.clear()
	var catalog = CATALOG.new()
	if not check(catalog.configure(), "verified original523 catalog configures"): finish(); return
	check(catalog.classes.size() == 13, "13 source-eligible classes")
	var store = ACCOUNT.new()
	if not check(store.open().get("ok", false), "new account opens"): finish(); return
	var created: Dictionary = store.create_character("기사테스트", 1, 1, catalog)
	if not check(created.get("ok", false), "real source knight created"): finish(); return
	var first: String = str(created.id)
	if not check(store.select_character(first).get("ok", false), "first selected"): finish(); return
	var world: Node = main_world()
	check(world.save_path() == store.path, "Main and lobby use the same account path")
	check(world.job_class == "기사" and world.source_gender_id == 1, "Main loads selected class and gender")
	check(world.character_display_name == "기사테스트" and world.hud.character_state.get("character_name") == "기사테스트", "selected first name reaches Main HUD")
	check(world.str_stat == 16, "source InitStatStr applied")
	check(world._save_game(true) == OK, "first real Main atomic account save")
	var records: Dictionary = {}
	for category: String in CARDS.CATEGORIES:
		records[category] = source_card(world, category)
		if not grant_card(world, category, records[category], "first " + category): world.queue_free(); await process_frame; finish(); return
		check(world.card_draw_fusion.total_count(category, CARDS.card_id(records[category])) == 1, "one non-empty account-owned " + category)
	var first_skill: String = seed_private_skill(world, "first")
	world.gold = 4321
	var expected_first_slots: Array = assign_private_quickslot(world, 1, "first")
	world.card_collections.restore_from_owned()
	world._invalidate_equipment_static()
	if not check(world._save_game(true) == OK, "first non-empty shared and private state saves"): world.queue_free(); await process_frame; finish(); return
	var expected_items: Dictionary = world.item_instances.duplicate(true)
	var expected_cards: Dictionary = world.card_draw_fusion.export_state()
	world.queue_free()
	await process_frame
	await process_frame
	if not check(store.open().get("ok", false), "lobby reopens after first Main save"): finish(); return
	var second_record: Dictionary = store.create_character("요정테스트", 2, 2, catalog)
	if not check(second_record.get("ok", false), "second real source character created"): finish(); return
	var second: String = str(second_record.id)
	if not check(store.select_character(second).get("ok", false), "second selected"): finish(); return
	world = main_world()
	check(world.job_class == "요정" and world.source_gender_id == 2, "second Main loads independent identity")
	check(world.character_display_name == "요정테스트" and world.hud.character_state.get("character_name") == "요정테스트", "selected second name reaches Main HUD")
	check(world.dex_stat == 13, "second source InitStatDex applied")
	check(world.gold != 4321, "private gold is not copied")
	check(world.quickslots != expected_first_slots, "private quickslots are not copied")
	check(not world.original_skills.catalog.learned.has(first_skill), "first learned class skill is not shared")
	var overlaps: Array = []
	for uid: Variant in expected_items:
		if world.item_instances.has(uid): overlaps.append(uid)
	check(overlaps.is_empty(), "second inventory does not inherit first physical items")
	check(same(world.card_draw_fusion.export_state(), expected_cards), "second Main restores non-empty account card state")
	for category: String in CARDS.CATEGORIES:
		if not grant_card(world, category, records[category], "second " + category): world.queue_free(); await process_frame; finish(); return
		check(world.card_draw_fusion.total_count(category, CARDS.card_id(records[category])) == 2, "second updates shared duplicate count " + category)
	var second_skill: String = seed_private_skill(world, "second")
	world.gold = 2468
	var expected_second_slots: Array = assign_private_quickslot(world, 2, "second")
	check(expected_second_slots != expected_first_slots, "characters register distinct private quickslot layouts")
	world.card_collections.restore_from_owned()
	world._invalidate_equipment_static()
	if not check(world._save_game(true) == OK, "second shared update and private progress save"): world.queue_free(); await process_frame; finish(); return
	expected_cards = world.card_draw_fusion.export_state()
	world.queue_free()
	await process_frame
	await process_frame
	if not check(store.open().get("ok", false) and store.select_character(first).get("ok", false), "first reselected after second update"): finish(); return
	world = main_world()
	check(world.gold == 4321 and world.job_class == "기사", "first private class and gold restored")
	check(world.character_display_name == "기사테스트" and world.hud.character_state.get("character_name") == "기사테스트", "first name restored on return")
	check(world.quickslots == expected_first_slots and world.quickslots != expected_second_slots, "first valid private slots restored independently")
	check(world.original_skills.catalog.learned.get(first_skill) == 1 and not world.original_skills.catalog.learned.has(second_skill), "learned skills remain private in both directions")
	check(same(world.item_instances, expected_items), "first physical inventory retained")
	check(same(world.card_draw_fusion.export_state(), expected_cards), "first sees newest non-empty shared card update")
	for category: String in CARDS.CATEGORIES:
		check(world.card_draw_fusion.total_count(category, CARDS.card_id(records[category])) == 2, "shared duplicate count remains two on first " + category)
	check(not world.set_source_character_gender(2), "gender cannot change after creation")
	world._on_job_class_selected("마법사")
	check(world.job_class == "기사", "class cannot mutate into another character")
	check(world._save_game(true) == OK, "first reload re-saves whole account")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(ACCOUNT.validate(payload).is_empty(), "real complete account file validates")
	check(payload[ACCOUNT.KEY].get("shared") is Dictionary and same(payload[ACCOUNT.KEY].shared.get("card_draw_fusion"), payload.get("card_draw_fusion")), "canonical account shared state matches selected compatibility view")
	for entry: Dictionary in payload[ACCOUNT.KEY].characters:
		check(not entry.state.has("card_draw_fusion") and entry.state.has("original_skill_state"), "shared cards and individual learned state have distinct account owners")
	world.queue_free()
	await process_frame
	await process_frame
	finish()
