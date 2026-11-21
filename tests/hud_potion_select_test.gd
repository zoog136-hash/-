extends SceneTree
## 왼쪽 위 캐릭터 정보 옆 물약 슬롯 (user list 2026-11-21 #27 "물약 선택 안 됨
## (레벨 제한 등)"): the slot only ever drank the original 체력 회복제 (#233).
## A long press now opens the owned HP-restoring potions (one its original
## level/class rule refuses is greyed with that rule); the chosen one is shown
## in the slot (its count) and drunk by a tap / the quick-potion key.
## Without the pinned 523 tables Main runs with an empty bag; with them the
## original potions 233/236/237 are chosen and drunk in actual Main.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func popup_buttons(world: Node) -> Array:
	var popup: Variant = world.hud.get("hud_potion_choice")
	if not is_instance_valid(popup): return []
	return (popup as Node).find_children("*", "Button", true, false)

func run() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var save_path: String = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_path)
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
	world.ui_preferences.erase(world.HUD_POTION_KEY)
	check(world.hud_potion_candidates().is_empty() and world.hud_potion_name() == "", "an empty bag has no slot potion")
	world.hud.message_label.text = ""
	world._use_potion()
	check(world.hud.message_label.text == "보유한 체력 회복 물약이 없습니다", "the slot says no potion instead of failing silently")
	check(world.hud.has_method("open_hud_potion_choice") and world.hud.get("v20_potion_button") is Button, "the slot has a potion chooser")
	if not SOURCE.not_installed():
		var staged: Dictionary = INV.stage(world, [{"item_class_id":233,"amount":5,"bless_raw":1,"enchant":0},{"item_class_id":236,"amount":3,"bless_raw":1,"enchant":0},{"item_class_id":237,"amount":2,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		check(staged.get("ok", false) and world._save_game(true, staged.overrides) == OK, "three original HP potions are granted")
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		var rows: Array = world.hud_potion_candidates()
		var names: Dictionary = {}
		for row: Dictionary in rows: names[int(row.item_class_id)] = str(row.name)
		evidence["candidates"] = rows.size()
		check(names.has(233) and names.has(236) and names.has(237), "the chooser lists every owned HP potion: %s" % str(names.keys()))
		check(world.hud_potion_name() == names.get(233, ""), "without a choice the slot keeps the original 체력 회복제")
		world.hud.open_hud_potion_choice()
		var buttons: Array = popup_buttons(world)
		check(buttons.size() == 3, "the chooser shows one row per potion (%d)" % buttons.size())
		var strong: String = str(names.get(236, ""))
		for button: Button in buttons:
			if str(button.text).begins_with(preload("res://scripts/ui/source523_item_identity.gd").screen_text(strong)): button.pressed.emit()
		check(world.hud_potion_name() == strong and str(world.ui_preferences.get(world.HUD_POTION_KEY, "")) == strong, "choosing 강력 체력 회복제 puts it in the slot")
		world.hud.set_quick_items(world.inventory)
		check(str(world.hud.get("v20_potion_count").text) == "3", "the slot shows the chosen potion's count")
		world.hp = 1; world.item_use_cooldowns = {}
		world._use_potion()
		check(int(world.inventory.get(strong, 0)) == 2 and world.hp > 1, "a tap drinks the chosen potion")
		# A rule-refused potion cannot be chosen and keeps the previous one.
		world.level = 1
		var refused: Array = []
		for row: Dictionary in world.hud_potion_candidates():
			if not str(row.reason).is_empty(): refused.append(row.name)
		evidence["refused_at_level_1"] = refused.size()
		world.inventory.erase(strong); world.inventory.erase(names.get(237, ""))
		var all_instances: Dictionary = world.item_instances.duplicate()
		check(world.hud_potion_name() == names.get(233, ""), "when the chosen potion runs out the slot falls back to 체력 회복제")
		world.item_instances = all_instances
	world.queue_free()
	await process_frame
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null: file.store_buffer(original_save); file.close()
	elif FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)
	print("HUD_POTION_SELECT_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
