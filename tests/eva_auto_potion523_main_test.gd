extends SceneTree

const EVA = preload("res://scripts/loot/source_eva_auto_potion523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const CATALOG = preload("res://scripts/characters/class_catalog.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const QA = preload("res://tests/qa_class_selection.gd")

var world: Node
var hud: Node
var checks := 0
var failures: Array[String] = []
var staged_write: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("EVA_AUTO_POTION_FAIL ", message)
	return ok


func run() -> void:
	for invalid: Variant in [null, true, "1", -1, 4, 1.25, NAN, INF]:
		check(not EVA.valid_unlocks(invalid), "reject malformed unlock: " + str(invalid))
	for valid: Variant in [0, 1.0, 2, 3.0]:
		check(EVA.valid_unlocks(valid), "accept exact unlock flags: " + str(valid))
	check(EVA.registration_bit(233) == 0 and EVA.registration_bit(245) == 0 and EVA.registration_bit(246) == 0, "other original potion IDs are outside the unlock")
	check(EVA.registration_target(EVA.WHISPER, {}) == 0 and EVA.registration_target(EVA.VOW, {}) == 0, "source proof cannot be omitted")
	check(not STACK.authorizes_eva_auto_potion(null, {EVA.SAVE_KEY:EVA.ALL_BITS}), "direct save override cannot create unlocks")
	if not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty():
		if check(not FileAccess.file_exists(ACCOUNT.DEFAULT_PATH), "fresh isolated save required") \
				and check(SOURCE.identity().get("source_sha256") == SOURCE.SOURCE_SHA, "pinned original content"):
			root.size = Vector2i(1280, 720)
			await exercise()
			if is_instance_valid(world):
				world.queue_free()
				await process_frame
	ACCOUNT.session.clear()
	print("EVA_AUTO_POTION_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)


func start_main(name_value: String = "") -> bool:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.save_timer = -100000
	await process_frame
	if not check(QA.enter_game(world, world.job_class), "actual Main entered"): return false
	if not name_value.is_empty():
		check(world.character_display_name == name_value, "lobby selected " + name_value)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.player.auto_enabled = false
	hud = world.hud
	await process_frame
	return true


func ref_for(item_id: int, bless: int = 1) -> String:
	for uid: String in world.item_instances:
		var row: Dictionary = world.item_instances[uid]
		var record: Dictionary = row.get("record", {})
		if record.get("source_item_class_id") == item_id and record.get("source_bless_raw") == bless:
			return str(row.name) + "@@@" + uid
	return ""


func quantity(reference: String) -> int:
	if not reference.contains("@@@"): return int(world.inventory.get(reference, 0))
	return int(STACK.proof(world, reference.get_slice("@@@", 1)).get("remaining", 0))


func disk() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	if not value is Dictionary: return {}
	ACCOUNT.expand(value)
	return value


func reject_write(_path: String, payload: Dictionary) -> Error:
	staged_write = payload.duplicate(true)
	return ERR_CANT_CREATE


func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 6
	event.pressed = pressed
	event.position = point
	root.push_input(event, true)


func center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)


func bag_use(reference: String) -> bool:
	if not hud.original_inventory_is_open():
		hud.toggle_inventory()
		await process_frame
	if not check(hud.original_inventory_is_open(), "actual original bag opened"): return false
	var bag: Control = hud.lineage_inventory_ui
	var view: RefCounted = hud.original_main_ui_controller._inventory_view
	var slot: Control
	hud.original_inventory_scroll_by(4096.0)
	for attempt: int in range(10):
		slot = view._hits.get(reference, {}).get("control")
		if is_instance_valid(slot) and view.hit_at(center(slot)).get("reference") == reference: break
		slot = null
		hud.original_inventory_scroll_by(-164.0)
		await process_frame
	if not check(is_instance_valid(slot), "visible original bag row for selected reference"):
		return false
	bag.disarm_item_action()
	var point: Vector2 = center(slot)
	touch(point, true)
	touch(point, false)
	if not check(bag.item_action_label(reference) == "사용", "touch arms the original use action"): return false
	touch(point, true)
	touch(point, false)
	await process_frame
	return true


func pull_down(visible: int) -> void:
	var control: Control = hud.original_quickslot_control(visible)
	if not check(is_instance_valid(control), "visible quickslot control"): return
	var point: Vector2 = center(control)
	touch(point, true)
	await process_frame
	for step: int in range(1, 6):
		var event := InputEventScreenDrag.new()
		event.index = 6
		event.position = point + Vector2(0, step * 9)
		event.relative = Vector2(0, 9)
		root.push_input(event, true)
		await process_frame
	touch(point + Vector2(0, 45), false)
	await process_frame


func poll() -> void:
	world.auto_item_clock = 0.0
	world._run_auto_item_quickslots(0.25)


func exercise() -> void:
	if not await start_main(): return
	for item: int in [EVA.WHISPER, EVA.VOW]:
		var rule: Dictionary = EVA.ITEMS[item]
		var def: Dictionary = world.source_item_definition(item)
		check(EVA.registration_target(item, def) == rule.potion, "original persistent source buff and exact potion for " + str(item))
		var native: Dictionary = def.get("native_record", {})
		check(STACK.profile(native).get("kind") == "eva_auto_potion_unlock", "original item has a real owner for " + str(item))
		var changed: Dictionary = def.duplicate(true)
		changed.original_item.LevelLimitMin = 1
		check(EVA.registration_target(item, changed) == 0, "mismatched original admission rule is refused")
	world.inventory = {}
	world.item_instances = {}
	world.equipped_items = world._empty_equipment_slots()
	world.quickslots = []
	world._normalize_quickslots()
	var grants: Array = []
	for id: int in [EVA.WHISPER, EVA.VOW, EVA.ADVANCED_POTION, EVA.GREATER_POTION, 233, 4241, 150973, 154183]:
		grants.append({"item_class_id":id,"amount":2 if EVA.ITEMS.has(id) else 10,"bless_raw":1,"enchant":0})
	var blessed_variant: Dictionary = DROPS.variant_item(world.source_item_definition(EVA.ADVANCED_POTION).get("native_record", {}), 2)
	if not blessed_variant.is_empty():
		grants.append({"item_class_id":EVA.ADVANCED_POTION,"amount":1,"bless_raw":2,"enchant":0})
	if not check(INV.commit(world, grants, {"kind":"qa_eva_immutable_supplier"}), "production supplier issues all original stock: " + hud.message_label.text): return
	var whisper := ref_for(EVA.WHISPER)
	var vow := ref_for(EVA.VOW)
	var advanced := ref_for(EVA.ADVANCED_POTION)
	var greater := ref_for(EVA.GREATER_POTION)
	var regular := ref_for(233)
	if not check(not whisper.is_empty() and not vow.is_empty() and not advanced.is_empty() and not greater.is_empty() and not regular.is_empty(), "exact physical references exist"): return
	var advanced_slot: int = hud.quickslot_index(5)
	var greater_slot: int = hud.quickslot_index(6)
	var regular_slot: int = hud.quickslot_index(7)
	for pair: Array in [[advanced_slot,advanced],[greater_slot,greater],[regular_slot,regular]]:
		hud.quickslot_assignment_requested.emit(pair[0], "item", pair[1])
		check(world.quickslots[pair[0]].get("instance_id") == pair[1].get_slice("@@@", 1), "HUD registers the selected physical potion")
	world.level = 87
	world.set_consumable_auto_settings({"hp_enabled":true,"hp_percent":70})
	check(world._quickslot_auto_allowed(world.quickslots[regular_slot]), "ordinary HP potion already supports AUTO")
	var variants_before := variant_permissions()
	await pull_down(5)
	check(not world.quickslots[advanced_slot].auto and hud.message_label.text.contains("에바의 속삭임"), "pull-down explains locked advanced potion")
	await pull_down(6)
	check(not world.quickslots[greater_slot].auto and hud.message_label.text.contains("에바의 서약"), "pull-down explains locked greater potion")
	world.hp = 1
	world._on_quickslot_pressed(advanced_slot)
	check(quantity(advanced) == 9 and world.hp > 1, "manual potion works while AUTO is restricted")
	world.quickslots[advanced_slot].auto = true
	world.quickslots[greater_slot].auto = true
	if not check(world._save_game(true) == OK and not disk().has(EVA.SAVE_KEY), "pre-Eva flat save with old AUTO flags"): return
	if not await legacy_native_key(vow): return
	world._load_game(true)
	check(world.eva_auto_potion_unlocks == 0 and not world.quickslots[advanced_slot].auto and not world.quickslots[greater_slot].auto \
		and world.quickslots[advanced_slot].id == advanced.get_slice("@@@", 0), "old save clears prior locked flags but retains quickslot registration")
	world.quickslots[advanced_slot].auto = true
	world.quickslots[greater_slot].auto = true
	world.item_use_cooldowns.clear()
	world.hp = 1
	poll()
	check(quantity(advanced) == 9 and quantity(greater) == 10 and world.hp == 1, "stale AUTO flags cannot bypass the live restriction")
	world.quickslots[advanced_slot].auto = false
	world.quickslots[greater_slot].auto = false
	var previous_hash: String = FileAccess.get_sha256(world.save_path())
	await bag_use(whisper)
	check(hud.message_label.text.contains("레벨 조건") and quantity(whisper) == 2 and not disk().has(EVA.SAVE_KEY) \
		and FileAccess.get_sha256(world.save_path()) == previous_hash, "level 87 refuses without charge or write")
	check(world._save_game(true, {EVA.SAVE_KEY:EVA.ALL_BITS}) != OK, "unsealed Main unlock write refused")
	world.level = 88
	var before_rng: int = world.rng.state
	world.equipment_collections.test_save_writer = reject_write
	await bag_use(whisper)
	var uid := whisper.get_slice("@@@", 1)
	check(staged_write.get(EVA.SAVE_KEY) == EVA.ADVANCED_BIT and staged_write.get("inventory", {}).get(whisper.get_slice("@@@", 0)) == 1, "one native debit and the advanced permission stage together")
	check(world.eva_auto_potion_unlocks == 0 and quantity(whisper) == 2 and world.rng.state == before_rng \
		and FileAccess.get_sha256(world.save_path()) == previous_hash, "rejected write preserves ownership, permission, RNG and disk")
	world.equipment_collections.test_save_writer = Callable()
	await bag_use(whisper)
	check(quantity(whisper) == 1 and disk().get(EVA.SAVE_KEY) == EVA.ADVANCED_BIT \
		and world.hp == 1 and world.rng.state == before_rng, "Whisper enables registration without immediate healing")
	check(int(world.consumable_service.export_state().get(STACK.USES, {}).get(uid, {}).get("used_quantity", -1)) == 1, "native debit is journaled")
	previous_hash = FileAccess.get_sha256(world.save_path())
	await bag_use(whisper)
	check(hud.message_label.text.contains("이미") and quantity(whisper) == 1 \
		and FileAccess.get_sha256(world.save_path()) == previous_hash, "duplicate supplies no effect and retains stock")
	hud.toggle_inventory()
	await process_frame
	check(not world.quickslots[advanced_slot].auto, "unlock does not pick or enable a slot")
	await pull_down(5)
	check(world.quickslots[advanced_slot].auto and not world._quickslot_auto_allowed(world.quickslots[greater_slot]), "Whisper permits only the advanced potion")
	check(variant_permissions() == variants_before, "event/clan and alternate blessing state do not inherit permission")
	verify_existing_hp_rule(advanced)

	world.level = 90
	await bag_use(vow)
	check(hud.message_label.text.contains("레벨 조건") and quantity(vow) == 2 and world.eva_auto_potion_unlocks == EVA.ADVANCED_BIT, "Vow rejects level 90")
	world.level = 91
	await bag_use(vow)
	check(quantity(vow) == 1 and disk().get(EVA.SAVE_KEY) == EVA.ALL_BITS, "Vow adds only the greater potion permission and keeps the first")
	hud.toggle_inventory()
	await process_frame
	world.quickslots[advanced_slot].auto = false
	await pull_down(6)
	check(world.quickslots[greater_slot].auto and variant_permissions() == variants_before, "Vow permits exact greater potion only")
	verify_existing_hp_rule(greater)
	# Run the production buff cleanup and death transaction. This item
	# fixture mounts no actor sprite bank for the corpse animation.
	preload("res://scripts/loot/patch523_item_use.gd").clear_on_death(world)
	world.death_recovery.begin_death("에바 검증")
	check(world.death_recovery.blocked() and world.hp == 0 and disk().get(EVA.SAVE_KEY) == EVA.ALL_BITS, "real death owner saves and preserves both source permissions")
	world.queue_free()
	await process_frame
	if not await start_main(): return
	check(world.death_recovery.blocked() and world.eva_auto_potion_unlocks == EVA.ALL_BITS, "fresh Main restores the permissions even while dead")
	# No world map is required to test the authoritative revive/save owner.
	# Supply walkable fixture geometry only if an original map isn't mounted.
	if world.field_map == null:
		var grid := AStarGrid2D.new()
		grid.region = Rect2i(0, 0, 8, 8)
		grid.update()
		world.astar = grid
	var revived: Dictionary = world.death_recovery.resurrect()
	check(revived.get("ok", false) and world.eva_auto_potion_unlocks == EVA.ALL_BITS \
		and disk().get(EVA.SAVE_KEY) == EVA.ALL_BITS, "real resurrection keeps both permissions: " + str(revived.get("message", "")))
	world.player.set_physics_process(false)
	await exercise_roster()


func variant_permissions() -> Dictionary:
	var result: Dictionary = {}
	for id: int in [4241, 150973, 154183]:
		var ref := ref_for(id)
		check(not ref.is_empty(), "distinct original variant is physically present: " + str(id))
		result[id] = world._quickslot_auto_allowed({"kind":"item","id":ref.get_slice("@@@", 0),"instance_id":ref.get_slice("@@@", 1)})
	var variant := ref_for(EVA.ADVANCED_POTION, 2)
	if not variant.is_empty():
		result["blessed_237"] = world._quickslot_auto_allowed({"kind":"item","id":variant.get_slice("@@@", 0),"instance_id":variant.get_slice("@@@", 1)})
	return result


func legacy_native_key(reference: String) -> bool:
	var original := disk()
	var old_key := reference.get_slice("@@@", 0)
	var legacy := original.duplicate(true)
	legacy.item_instances.erase(reference.get_slice("@@@", 1))
	legacy["level"] = 91
	if not check(WRITER.write(world.save_path(), legacy) == OK, "prepare isolated old ID-bearing stock without a receipt"): return false
	world._load_game(true)
	var previous_hash: String = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = reject_write
	await bag_use(old_key)
	check(staged_write.get(EVA.SAVE_KEY) == EVA.GREATER_BIT and staged_write.get("inventory", {}).get(old_key) == 1, "legacy ID-bearing bag stock stages a single exact debit")
	check(world.eva_auto_potion_unlocks == 0 and quantity(old_key) == 2 and ref_for(EVA.VOW).is_empty() \
		and FileAccess.get_sha256(world.save_path()) == previous_hash, "failed legacy use leaves the original bytes and stock, including receipt absence")
	world.equipment_collections.test_save_writer = Callable()
	await bag_use(old_key)
	check(quantity(old_key) == 1 and ref_for(EVA.VOW).is_empty() and disk().get(EVA.SAVE_KEY) == EVA.GREATER_BIT, "successful legacy use is atomic without inventing a physical item")
	hud.toggle_inventory()
	await process_frame
	return check(WRITER.write(world.save_path(), original) == OK, "restore isolated pre-unlock save for the physical-item branch")


func verify_existing_hp_rule(reference: String) -> void:
	var uid := reference.get_slice("@@@", 1)
	var count := quantity(reference)
	world.item_use_cooldowns.clear()
	world.hp = world._effective_max_hp()
	poll()
	check(quantity(reference) == count, "healthy poll does not use a potion")
	world.hp = 1
	world.set_consumable_auto_settings({"hp_enabled":false})
	poll()
	check(quantity(reference) == count and world.hp == 1, "disabled HP option does not use a potion")
	world.set_consumable_auto_settings({"hp_enabled":true,"hp_percent":70})
	world.hp = int(world._effective_max_hp() * 0.8)
	poll()
	check(quantity(reference) == count, "existing 70% threshold still applies")
	world.hp = 1
	world.item_use_cooldowns[world.HP_POTION_COOLDOWN_KEY] = 0.5
	poll()
	check(quantity(reference) == count, "shared cooldown still applies")
	world.item_use_cooldowns.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = world.rng.seed
	rng.state = world.rng.state
	var roll: int = DROPS.healing_amount(STACK.proof(world, uid).record, rng, 0)
	var expected: int = mini(world._effective_max_hp(), 1 + world._source_hp_potion_parameters(roll).heal_amount)
	poll()
	check(quantity(reference) == count - 1 and world.hp == expected and world.item_use_cooldowns.get(world.HP_POTION_COOLDOWN_KEY, 0.0) > 0.0, "AUTO debits one and uses the original normal heal and cooldown")


func exercise_roster() -> void:
	var store = ACCOUNT.new()
	store.path = world.save_path()
	world.queue_free()
	await process_frame
	if not check(store.open().get("legacy", false) and store.migrate_legacy().get("ok", false), "old flat character migrates into a real roster"): return
	var first: String = store.open().get("selected", "")
	var catalog = CATALOG.new()
	if not check(catalog.configure(), "actual source lobby definitions opened"): return
	var created: Dictionary = store.create_character("에바검증둘째", 2, 1, catalog)
	if not check(created.get("ok", false) and store.select_character(created.id).get("ok", false), "lobby selects a new original class character"): return
	if not await start_main("에바검증둘째"): return
	check(world.eva_auto_potion_unlocks == 0 and not disk().get(ACCOUNT.KEY, {}).get("shared", {}).has(EVA.SAVE_KEY), "independent character has no inherited permission")
	var growth: RefCounted = world.growth96
	var whisper_key: String = growth.Source.item_key(EVA.WHISPER)
	var vow_key: String = growth.Source.item_key(EVA.VOW)
	world.level = 88
	world.exp_need = 100
	world.experience = 65
	check(not growth.execute("claim", "124", int(growth.state.revision)).get("ok", false), "88/65% growth claim refused")
	world.experience = 66
	if not check(growth.execute("claim", "124", int(growth.state.revision)).get("ok", false) and quantity(whisper_key) == 1, "actual 88/66% source growth claims Whisper"): return
	# Name-keyed old growth stock without a matching claim cannot grant a
	# permission. The authentic claim above remains untouched.
	world.inventory[vow_key] = 1
	world.level = 91
	hud.refresh_inventory(world.inventory)
	await bag_use(vow_key)
	check(hud.message_label.text.contains("수령 이력") and quantity(vow_key) == 1 and world.eva_auto_potion_unlocks == 0, "unproved growth balance cannot unlock or be charged: " + hud.message_label.text)
	world.inventory.erase(vow_key)
	await bag_use(whisper_key)
	check(quantity(whisper_key) == 0 and growth.state.claims.has("97772") \
		and disk().get(EVA.SAVE_KEY) == EVA.ADVANCED_BIT, "earned Whisper uses the real bag and retains its receipt")
	check(not growth.selected_rewards("423").has("167223"), "current version keeps its existing 91/80 reward policy")
	if not check(growth.execute("policy", "cap0", int(growth.state.revision)).get("ok", false), "supported Version 0 test policy selected"): return
	world.experience = 79
	check(not growth.execute("claim", "423", int(growth.state.revision)).get("ok", false), "91/79% growth claim refused")
	world.experience = 80
	if not check(growth.execute("claim", "423", int(growth.state.revision)).get("ok", false) and quantity(vow_key) == 1, "eligible Version 0 91/80% growth grants original Vow"): return
	hud.refresh_inventory(world.inventory)
	var prior_claims: Dictionary = growth.state.claims.duplicate(true)
	var previous_hash: String = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = reject_write
	await bag_use(vow_key)
	check(staged_write.get(EVA.SAVE_KEY) == EVA.ALL_BITS and not staged_write.get("inventory", {}).has(vow_key) \
		and quantity(vow_key) == 1 and growth.state.claims == prior_claims and world.eva_auto_potion_unlocks == EVA.ADVANCED_BIT \
		and FileAccess.get_sha256(world.save_path()) == previous_hash, "failed earned use retains reward, claim and previous permission")
	world.equipment_collections.test_save_writer = Callable()
	await bag_use(vow_key)
	check(quantity(vow_key) == 0 and growth.state.claims.has("167223") and disk().get(EVA.SAVE_KEY) == EVA.ALL_BITS, "earned Vow uses the real bag and retains its receipt")
	var second: String = created.id
	world.queue_free()
	await process_frame
	if not check(store.open().get("ok", false) and store.select_character(first).get("ok", false), "lobby returns to the original character"): return
	if not await start_main(): return
	check(world.eva_auto_potion_unlocks == EVA.ALL_BITS and world.growth96.state.claims.is_empty(), "first character restores its own unlocks and claim history")
	var malformed := disk()
	for character: Dictionary in malformed[ACCOUNT.KEY].characters:
		if character.id == second:
			character.state[EVA.SAVE_KEY] = 4
	check(ACCOUNT.validate(malformed).contains("회복제"), "dormant malformed flag protects the roster")
	var misplaced := disk()
	misplaced[ACCOUNT.KEY].shared[EVA.SAVE_KEY] = EVA.ADVANCED_BIT
	check(not ACCOUNT.validate(misplaced).is_empty(), "unlock cannot be placed in account-shared state")
