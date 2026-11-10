extends SceneTree
## Original Einhasad blessing items (ItemCategory EinasadRecharager) charge
## the existing blessing owner with the original amounts: EinasadBlessAbsolute
## over the original unit per blessing point (EinasadLevel 1 cap 1,200,000 /
## the owner's natural cap 200 = 6000), times the ItemConsumeEinasadRate level
## row, capped by EinasadBlessMaxNeturalRechargeValue; Experience times the
## ItemConsumeExpRate row. Without the pinned 523 tables only the blocking
## rules run. With TWILIGHT_PATCH523_CONTENT and --einhasad-ids=<file> every
## listed item is checked; with --runtime two are used in actual Main.
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const DIAMOND: int = 549
const HOLY_WATER: int = 150784
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

func row(name_value: String, unit: String, value: float) -> Dictionary:
	return {"ID":1.0,"IsPossession":false,"bonus_type":{"Name":name_value},"unit":{"Name":unit},"bonus":{"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":value}}

func definition(rows: Array, category: String = "EinasadRecharager") -> Dictionary:
	return {"original_item":{"ID":9004.0,"TargettingTypeID":1.0,"ServiceRegionCode":""},"category":{"Name":category,"IsConsumable":true},"item_bonus":rows}

func rules() -> void:
	var base: Array = [row("EinasadBlessAbsolute","Value",600000.0),row("EinasadBlessMaxNeturalRechargeValue","Value",599994000.0)]
	var no_player: Dictionary = PROJECTION.source_einhasad_charge(definition(base))
	check(no_player.get("kind") == "einhasad_charge" and "einhasad_target_not_player_blessing" in no_player.get("blocked_reasons", []), "only the player's blessing target is charged")
	var level_table: Dictionary = PROJECTION.source_einhasad_charge(definition(base+[row("PlayerEinasadBless","Value",1.0),row("LevelEinasadBlessRecharge","ItemConsumeRateGourpID",31.0)]))
	check(level_table.get("activation_status") == "blocked", "a level-table recharge item stays blocked until its rule has an owner")
	check(not PROJECTION.source_einhasad_charge(definition(base+[row("PlayerEinasadBless","Value",1.0)])).get("blocked_reasons", []).is_empty(), "a charge without its original consume rate group is blocked")
	check(PROJECTION.source_einhasad_charge(definition([], "Potion")).is_empty(), "other categories are not Einhasad items")

func table() -> void:
	check(STACK.einhasad_scale() == 6000, "original Einhasad units per blessing point are 6000")
	check(PROJECTION.consume_rate(12, 84) == 0 and PROJECTION.consume_rate(12, 85) == 100 and PROJECTION.consume_rate(12, 87) == 200 and PROJECTION.consume_rate(12, 89) == 400 and PROJECTION.consume_rate(12, 99) == 400, "the Einhasad rate group gives +100/+200/+400 % from 85/87/89")
	check(PROJECTION.consume_rate(2, 50) == 10500, "the experience rate group gives 105 % between its level rows")
	var listed: int = 0; var opened: int = 0; var reasons: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(argument("--einhasad-ids=")).split("\n", false):
		if not line.strip_edges().is_valid_int(): continue
		listed += 1
		var spec: Dictionary = FIELDS.full(D.definition_id(line.strip_edges()).get("native_record", {})).get("source_use_spec", {})
		if spec.get("kind") == "einhasad_charge" and spec.get("activation_status") == "unrestricted": opened += 1
		else:
			for reason: String in spec.get("blocked_reasons", ["no_spec"]): reasons[reason] = int(reasons.get(reason, 0)) + 1
	evidence["listed"] = listed; evidence["opened"] = opened; evidence["blocked_reasons"] = reasons
	check(listed > 0 and opened > 0, "original Einhasad items project usable")

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var used: Dictionary = {}
	for pair: Array in [[DIAMOND, 50, 100, 0], [HOLY_WATER, 50, 1500, 31920000], [DIAMOND, 89, 500, 0]]:
		var id: int = pair[0]
		world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
		world.level = int(pair[1]); world.ain_service.blessing = 200
		var staged: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(world, [{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		if not staged.get("ok", false) or world._save_game(true, staged.overrides) != OK:
			check(false, "grant " + str(id)); continue
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		var bonus: float = float(world.growth.bonus("blessing_charge:percent")) + float(world.card_collections.bonus("blessing_charge:percent"))
		var expected: int = int(round(float(pair[2]) * (1.0 + bonus / 100.0)))
		var before_exp: int = int(world.experience); var before_level: int = int(world.level)
		var name_value: String = str(D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1).name)
		var result: Dictionary = STACK.try_use(world, name_value)
		var ok: bool = result.get("ok", false) and int(world.ain_service.blessing) == 200 + expected and int(world.inventory.get(name_value, 0)) == 0 and world.item_instances.is_empty()
		if int(pair[3]) > 0: ok = ok and int(result.get("experience_gained", 0)) == int(pair[3]) and (int(world.experience) > before_exp or int(world.level) > before_level)
		used["%d@%d" % [id, int(pair[1])]] = {"ok":ok,"charged":result.get("blessing_charged"),"expected":expected,"experience":result.get("experience_gained"),"reason":str(result.get("reason",""))}
		check(ok, "original Einhasad item charges its table amount " + str(id) + " at level " + str(pair[1]))
	# The original recharge cap: charging stops at EinasadBlessMaxNeturalRechargeValue.
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}; world.level = 50
	world.ain_service.blessing = 99999 - 40
	var capped: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(world, [{"item_class_id":DIAMOND,"amount":1,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if capped.get("ok", false) and world._save_game(true, capped.overrides) == OK:
		world.inventory = capped.overrides.inventory; world.item_instances = capped.overrides.item_instances
		var cap_result: Dictionary = STACK.try_use(world, str(D.variant_item(D.definition_id(str(DIAMOND)).get("native_record", {}), 1).name))
		check(cap_result.get("ok", false) and int(world.ain_service.blessing) == 99999, "charging stops at the original recharge cap")
		used["cap"] = {"charged":cap_result.get("blessing_charged"),"blessing":world.ain_service.blessing}
	evidence["runtime"] = used
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed() and not argument("--einhasad-ids=").is_empty():
		table()
		if "--runtime" in OS.get_cmdline_user_args(): await runtime()
	print("CURRENT523_EINHASAD_CHARGE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
