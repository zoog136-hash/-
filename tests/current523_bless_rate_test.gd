extends SceneTree
## Equipment blessing uses the original 523 BlessSuccessRate table (Rate per
## 1,000,000 by target ItemCategoryID and GradeID; a category row wins over
## the ItemCategoryID 0 row) and original bless scrolls (ItemCategory
## ScrollBless) are used through the existing blessing chooser with a physical
## debit. Without the tables only the placeholder fallback and the scroll
## projection rules run. With TWILIGHT_PATCH523_CONTENT the table lookup is
## checked; with --runtime-weapons=<file of weapon ItemClass IDs> scrolls are
## granted and used on a granted weapon in actual Main.
const BLESSING = preload("res://scripts/equipment_blessing.gd")
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const PLAIN_SCROLL: int = 3581
const GUARANTEED_SCROLL: int = 159983
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void: call_deferred("run")

func scroll(rows: Array, targetting: float = 8.0, category: String = "ScrollBless") -> Dictionary:
	return {"original_item":{"ID":3581.0,"TargettingTypeID":targetting,"ServiceRegionCode":""},"category":{"Name":category,"IsConsumable":true},"item_bonus":rows}

func bonus(name_value: String, unit: String, value: float) -> Dictionary:
	return {"ID":1.0,"IsPossession":false,"bonus_type":{"Name":name_value},"unit":{"Name":unit},"bonus":{"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":value}}

func rules() -> void:
	check(BLESSING.success_chance("일반", {}, true) == 100.0 and BLESSING.roll_succeeds("일반", 99.99, {}, true), "a guaranteed scroll always succeeds")
	var plain: Dictionary = PROJECTION.source_bless_scroll(scroll([]))
	check(plain.get("kind") == "equipment_bless" and plain.get("activation_status") == "unrestricted" and plain.get("guaranteed") == false, "a plain original bless scroll is usable")
	check(PROJECTION.source_bless_scroll(scroll([bonus("GuaranteeBlessProb","TrueFalse",1.0)])).get("guaranteed") == true, "GuaranteeBlessProb marks the scroll certain")
	check(PROJECTION.source_bless_scroll(scroll([bonus("DeleteTime","Time",2021040705.0),bonus("CannotExtendDeleteTime","TrueFalse",1.0)])).get("activation_status") == "unrestricted", "an event scroll's lifetime follows the item lifetime rule")
	check(PROJECTION.source_bless_scroll(scroll([bonus("UsageInterval","Value",1.0)])).get("activation_status") == "blocked", "an unknown scroll bonus blocks")
	check(PROJECTION.source_bless_scroll(scroll([bonus("GuaranteeBlessProb","TrueFalse",2.0)])).get("activation_status") == "blocked", "a malformed guarantee blocks")
	check(PROJECTION.source_bless_scroll(scroll([],1.0)).get("activation_status") == "blocked", "a scroll without an item target blocks")
	check(PROJECTION.source_bless_scroll(scroll([],8.0,"ScrollEnchant")).is_empty(), "other scroll categories are not bless scrolls")
	if SOURCE.not_installed():
		check(BLESSING.source_rate("일반").is_empty() and BLESSING.success_basis("일반") == BLESSING.PLACEHOLDER_BASIS, "without the original the placeholder is labelled as such")

func table() -> void:
	var rows: Dictionary = {}
	for row: Dictionary in SOURCE.rows("BlessSuccessRate"): rows[str(int(row.ItemCategoryID))+":"+str(int(row.GradeID))] = int(row.Rate)
	var checked: int = 0
	for key: String in rows:
		var parts: PackedStringArray = key.split(":")
		var record: Dictionary = {"source_m_native_item":true,"source_grade_id":int(parts[1]),"source_category_id":int(parts[0])}
		check(is_equal_approx(BLESSING.success_chance("", record), float(rows[key]) / 10000.0) and BLESSING.success_basis("", record) == BLESSING.SOURCE_BASIS, "original rate for category/grade " + key)
		checked += 1
	# A category without its own row uses the ItemCategoryID 0 row of its grade.
	var other: Dictionary = {"source_m_native_item":true,"source_grade_id":3,"source_category_id":99999999}
	check(is_equal_approx(BLESSING.success_chance("", other), float(rows.get("0:3", -1)) / 10000.0), "a category without its own row falls back to the general row")
	var holy_low: Dictionary = {"source_m_native_item":true,"source_grade_id":1,"source_category_id":10622}
	check(not rows.has("10622:1") and is_equal_approx(BLESSING.success_chance("", holy_low), float(rows.get("0:1", -1)) / 10000.0), "HolyGrail grade 1 falls back to the general row")
	check(is_equal_approx(BLESSING.success_chance("희귀"), float(rows.get("0:3", -1)) / 10000.0), "a Korean grade label maps through the original Grade row")
	check(BLESSING.success_chance("", {"source_m_native_item":true,"source_grade_id":99999,"source_category_id":0}) == 0.0, "a grade without an original rate cannot be blessed")
	evidence["table_rows_checked"] = checked

func instance_of(world: Node, name_value: String) -> String:
	for id: String in world.item_instances:
		var entry: Variant = world.item_instances[id]
		if entry is Dictionary and entry.get("name") == name_value and not entry.has(STACK.RECEIPT): return id
	return ""

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var supply: Script = preload("res://scripts/loot/patch523_item_inventory.gd")
	var origin: Dictionary = {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}
	var weapons: Array = []
	for line: String in FileAccess.get_file_as_string(argument("--runtime-weapons=")).split("\n", false):
		if line.strip_edges().is_valid_int(): weapons.append(int(line))
	var outcome: Dictionary = {"tried":0,"blessed":0,"failed_rolls":0}
	var plain_name: String = str(D.variant_item(world.source_item_definition(PLAIN_SCROLL).get("native_record", {}), 1).get("name", ""))
	var sure_name: String = str(D.variant_item(world.source_item_definition(GUARANTEED_SCROLL).get("native_record", {}), 1).get("name", ""))
	for weapon_id: int in weapons:
		if outcome.blessed >= 2: break
		world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
		var staged: Dictionary = supply.stage(world, [{"item_class_id":PLAIN_SCROLL,"amount":2,"bless_raw":1,"enchant":0},{"item_class_id":GUARANTEED_SCROLL,"amount":1,"bless_raw":1,"enchant":0},{"item_class_id":weapon_id,"amount":2,"bless_raw":1,"enchant":0}], origin)
		if not staged.get("ok", false): continue
		if world._save_game(true, staged.overrides) != OK: continue
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		var weapon_name: String = str(D.variant_item(world.source_item_definition(weapon_id).get("native_record", {}), 1).get("name", ""))
		var target: String = instance_of(world, weapon_name)
		var record: Dictionary = world.item_instances.get(target, {}).get("record", {})
		var prepared: Dictionary = world.PATCH523_ENHANCE.prepare(world.patch523_equipment, record, 1)
		if target.is_empty() or BLESSING.bonus_for(str(record.get("grade","")), str(world._enhancement_kind_for_record(prepared)), prepared).is_empty(): continue
		outcome.tried += 1
		var used: Dictionary = STACK.try_use(world, plain_name)
		check(used.get("handled", false) and used.get("silent", false) and int(world.inventory.get(plain_name, 0)) == 2, "using an original bless scroll opens the chooser without consuming it")
		var chance: float = BLESSING.success_chance(str(record.get("grade","")), prepared)
		check(chance == BLESSING.success_chance("", {"source_m_native_item":true,"source_grade_id":int(record.get("source_grade_id",0)),"source_category_id":int(record.get("source_category_id",0))}), "the target's own category and grade pick the rate " + str(weapon_id))
		evidence["rate_" + str(weapon_id)] = chance
		if chance < 99.99:
			var failed: bool = world.consumable_service.apply_bless_scroll(plain_name, weapon_name + "@@@" + target, 99.99)
			check(not failed and int(world.inventory.get(plain_name, 0)) == 1 and not BLESSING.is_blessed(world.item_instances[target], world.item_instances[target].get("record", {})), "a failed roll debits one physical scroll and keeps the weapon " + str(weapon_id))
			outcome.failed_rolls += 1
		var blessed: bool = world.consumable_service.apply_bless_scroll(plain_name, weapon_name + "@@@" + target, 0.0)
		check(blessed and BLESSING.is_blessed(world.item_instances[target], world.item_instances[target].get("record", {})), "a successful roll blesses the chosen physical weapon " + str(weapon_id))
		var second: String = ""
		for id: String in world.item_instances:
			if id != target and world.item_instances[id] is Dictionary and world.item_instances[id].get("name") == weapon_name and not world.item_instances[id].has(STACK.RECEIPT): second = id
		var sure: bool = world.consumable_service.apply_bless_scroll(sure_name, weapon_name + "@@@" + second, 99.99)
		check(sure and int(world.inventory.get(sure_name, 0)) == 0, "the guaranteed scroll succeeds even on the worst roll and is debited " + str(weapon_id))
		if blessed and sure: outcome.blessed += 1
	evidence["runtime"] = outcome
	check(outcome.tried > 0 and outcome.blessed > 0, "original bless scrolls bless granted weapons in actual Main")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		table()
		if not argument("--runtime-weapons=").is_empty(): await runtime()
	print("CURRENT523_BLESS_RATE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
