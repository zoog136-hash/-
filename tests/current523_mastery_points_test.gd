extends SceneTree
## Original weapon mastery point items (ItemCategory MasteryPointRecharger)
## give their MasteryWeaponPointAmount Value to the BonusApplicationTargetID
## weapon type (BonusApplicationType 22 WeaponType) through the existing
## mastery owner, with a one-unit physical debit. Without the pinned 523
## tables only the projection rules run. With TWILIGHT_PATCH523_CONTENT and
## --mastery-ids=<file> every listed item is checked; with --runtime two are
## used in actual Main.
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const QA = preload("res://tests/qa_class_selection.gd")
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

func row(name_value: String, unit: String, value: float, type_id: float = 0.0, target: float = 0.0) -> Dictionary:
	return {"ID":1.0,"IsPossession":false,"bonus_type":{"Name":name_value},"unit":{"Name":unit},"bonus":{"BonusApplicationTypeID":type_id,"BonusApplicationTargetID":target,"Value":value}}

func definition(rows: Array, category: String = "MasteryPointRecharger") -> Dictionary:
	return {"original_item":{"ID":9003.0,"TargettingTypeID":1.0,"ServiceRegionCode":""},"category":{"Name":category,"IsConsumable":true},"item_bonus":rows}

func rules() -> void:
	var plain: Dictionary = PROJECTION.source_mastery_points(definition([row("MasteryWeaponPointAmount","Value",500.0,22.0,4.0)]))
	check(plain.get("kind") == "weapon_mastery_points" and plain.get("points") == 500 and plain.get("weapon_type") == 4 and plain.get("activation_status") == "unrestricted", "points and weapon type come from the original row")
	check(PROJECTION.source_mastery_points(definition([row("MasteryWeaponPointAmount","Value",500.0,22.0,4.0),row("DeleteTime","Time",2024010105.0)])).get("activation_status") == "unrestricted", "a dated item follows the item lifetime rule")
	check(PROJECTION.source_mastery_points(definition([row("MasteryWeaponPointAmount","Value",500.0,21.0,4.0)])).get("activation_status") == "blocked", "another application type is not a weapon type target")
	check(PROJECTION.source_mastery_points(definition([row("MasteryWeaponPointAmount","Value",0.0,22.0,4.0)])).get("activation_status") == "blocked", "zero points block")
	check(PROJECTION.source_mastery_points(definition([row("MasteryWeaponPointAmount","Value",5.0,22.0,4.0),row("MasteryWeaponPointAmount","Value",5.0,22.0,3.0)])).get("activation_status") == "blocked", "two point rows are ambiguous")
	check(PROJECTION.source_mastery_points(definition([row("MasteryWeaponPointAmount","Value",5.0,22.0,4.0),row("UsageInterval","Value",1.0)])).get("activation_status") == "blocked", "an unknown bonus blocks")
	check(PROJECTION.source_mastery_points(definition([], "Potion")).is_empty(), "other categories are not mastery items")

func table() -> void:
	var listed: int = 0; var opened: int = 0; var weapons: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(argument("--mastery-ids=")).split("\n", false):
		if not line.strip_edges().is_valid_int(): continue
		listed += 1
		var spec: Dictionary = FIELDS.full(D.definition_id(line.strip_edges()).get("native_record", {})).get("source_use_spec", {})
		if spec.get("kind") == "weapon_mastery_points" and spec.get("activation_status") == "unrestricted":
			opened += 1; weapons[str(spec.weapon_type)] = int(weapons.get(str(spec.weapon_type), 0)) + 1
	evidence["listed"] = listed; evidence["opened"] = opened; evidence["weapon_types"] = weapons
	check(listed > 0 and opened == listed, "every listed original mastery point item projects usable")

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var used: Dictionary = {}; var count: int = 0
	for line: String in FileAccess.get_file_as_string(argument("--mastery-ids=")).split("\n", false):
		if count >= 2 or not line.strip_edges().is_valid_int(): continue
		var id: int = int(line)
		var spec: Dictionary = FIELDS.full(D.definition_id(str(id)).get("native_record", {})).get("source_use_spec", {})
		var weapon: int = int(world.weapon_mastery.core.normalize_weapon(int(spec.get("weapon_type", 0))))
		if weapon <= 0: continue
		count += 1
		world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
		var staged: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(world, [{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		if not staged.get("ok", false) or world._save_game(true, staged.overrides) != OK:
			used[str(id)] = "grant: " + str(staged.get("error", "save")); check(false, "grant " + str(id)); continue
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		var before: int = int(str(world.weapon_mastery.core.record(world.weapon_mastery.state, weapon).points))
		var name_value: String = str(D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1).name)
		var result: Dictionary = STACK.try_use(world, name_value)
		var after: int = int(str(world.weapon_mastery.core.record(world.weapon_mastery.state, weapon).points))
		var ok: bool = result.get("ok", false) and int(world.inventory.get(name_value, 0)) == 0 and world.item_instances.is_empty()
		used[str(id)] = {"ok":ok,"weapon":weapon,"source_points":spec.points,"before":before,"after":after,"reason":str(result.get("reason",""))}
		check(ok and after > before, "the original mastery item debits one unit and raises that weapon's points " + str(id))
	evidence["runtime"] = used
	check(count > 0, "mastery items were used in actual Main")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed() and not argument("--mastery-ids=").is_empty():
		table()
		if "--runtime" in OS.get_cmdline_user_args(): await runtime()
	print("CURRENT523_MASTERY_POINTS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
