extends SceneTree

const AIN_OPTIONS = preload("res://scripts/ainhasad_option_rules.gd")
const EXP_RULES = preload("res://scripts/experience_progression.gd")
const VISIBILITY = preload("res://scripts/card_option_visibility.gd")

var failures: Array[String] = []

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		printerr("AIN_EXP_PROGRESSION_FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Source numeric values must be parsed without fabricating bare-text bonuses.
	_check(is_equal_approx(AIN_OPTIONS.option_percent("축복 소모량 감소 +25%"), 25.0), "doll percentage parsed")
	_check(is_equal_approx(AIN_OPTIONS.option_percent("아인하사드 축복 소모 감소 12.5%"), 12.5), "alternate label parsed")
	_check(AIN_OPTIONS.option_percent("축복 소모량 감소 (조건부)") < 0.0, "unknown mechanism remains unresolved")
	_check(is_equal_approx(AIN_OPTIONS.reduction_percent({"sourceOptions":["축복 소모량 감소 +20%", "축복 소모량 감소 +20%"]}), 20.0), "same-card duplicate cannot stack")
	_check(is_equal_approx(AIN_OPTIONS.reduction_percent({"blessing_consumption_reduction_pct":15, "sourceOptions":["축복 소모량 감소 +20%"]}), 15.0), "typed field wins over source duplicate")
	_check(not VISIBILITY.unresolved("마법인형", "축복 소모량 감소 +25%", {}), "working doll option no longer labeled unimplemented")
	_check(VISIBILITY.unresolved("마법인형", "축복 소모량 감소 (조건부)", {}), "unsupported variant still identified")

	# v2 table: about 3x faster than Lineage M (kills per level, blessing 4x).
	_check(EXP_RULES.CURVE_VERSION == 2, "curve version 2")
	_check(EXP_RULES.table_requirement(35) == 556188, "level 35 entry")
	_check(EXP_RULES.table_requirement(65) == 55741440, "level 65 calibration (11,613 kills at 4,800 EXP)")
	_check(EXP_RULES.table_requirement(85) == 1263140598, "level 85 entry")
	_check(EXP_RULES.table_requirement(86) == 3789421794, "level 86 milestone 3x")
	_check(EXP_RULES.table_requirement(87) == 15157687176, "level 87 milestone 4x")
	_check(EXP_RULES.table_requirement(90) == 970091979266, "level 90 entry")
	_check(EXP_RULES.HOLY_WATER_EXP == 3864874, "holy water keeps 3x Lineage M share")
	_check(EXP_RULES.required_for_level(36, 556188) == EXP_RULES.table_requirement(36), "table drives next-level requirement")
	_check(EXP_RULES.required_for_level(101, 1000) == 1260, "out-of-table legacy fallback")
	_check(is_equal_approx(EXP_RULES.map_exp_multiplier("oman_01"), 5.0) and is_equal_approx(EXP_RULES.map_exp_multiplier("oman_10"), 5.0), "오만의 탑 EXP x5")
	_check(is_equal_approx(EXP_RULES.map_exp_multiplier("domination_summit"), 20.0), "지배의 탑 EXP x20")
	_check(is_equal_approx(EXP_RULES.map_exp_multiplier("escaros_03"), 20.0) and is_equal_approx(EXP_RULES.map_exp_multiplier("escaros_world"), 20.0), "에스카로스 EXP x20")
	_check(is_equal_approx(EXP_RULES.map_exp_multiplier("aden_world"), 1.0) and is_equal_approx(EXP_RULES.map_exp_multiplier("faith_01"), 1.0), "other maps unchanged")
	var half: Dictionary = EXP_RULES.migrate_progress(87, 100, 200, 0)
	_check(int(half["experience"]) == 7578843588 and int(half["exp_need"]) == 15157687176, "legacy 50 percent progress is preserved")
	var from_v1: Dictionary = EXP_RULES.migrate_progress(60, 50, 200, 1)
	_check(int(from_v1["experience"]) == 6465847 and int(from_v1["exp_need"]) == 25863389, "v1 save progress is preserved by fraction")
	var already_migrated: Dictionary = EXP_RULES.migrate_progress(87, 100, 200, EXP_RULES.CURVE_VERSION)
	_check(int(already_migrated["experience"]) == 100 and int(already_migrated["exp_need"]) == 200, "migration is idempotent")
	var no_table: Dictionary = EXP_RULES.migrate_progress(5, 100, 200, 0)
	_check(int(no_table["experience"]) == 100 and int(no_table["exp_need"]) == 200, "untabled old levels are unchanged")

	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	_check(scene != null, "game scene loads")
	if scene == null:
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set("equipped_items", {})
	world.call("_invalidate_equipment_static")
	world.set("equipped_catalog", {"변신": {}, "마법인형": {}, "성물": {}})
	world.call("_invalidate_equipment_static")
	_check(is_zero_approx(float(world.call("_blessing_consumption_reduction_percent"))), "unequipped baseline")
	world.set("equipped_catalog", {
		"변신": {},
		"마법인형": {"name":"__ain_test_doll__", "sourceOptions":["축복 소모량 감소 +25%"]},
		"성물": {}
	})
	world.call("_invalidate_equipment_static")
	world.set("equipped_items", {"weapon":{"name":"__ain_test_weapon__", "atk":0, "blessing_consumption_reduction_pct":20}})
	world.call("_invalidate_equipment_static")
	_check(is_equal_approx(float(world.call("_blessing_consumption_reduction_percent")), 45.0), "equipped doll and weapon stack")
	var ain: TwilightAinhasadService = world.get("ain_service") as TwilightAinhasadService
	_check(ain != null, "existing blessing service present")
	if ain != null:
		ain.blessing = 200
		ain.spend_remainder = 0.0
		_check(ain.consume_for_kill(42000, float(world.call("_blessing_consumption_reduction_percent"))) == 0, "45 percent reduction saves first blessing point")
		_check(ain.consume_for_kill(42000, float(world.call("_blessing_consumption_reduction_percent"))) == 1 and ain.blessing == 199, "reduction accumulates fractional spend")
	world.set("equipped_items", {})
	world.call("_invalidate_equipment_static")
	world.set("equipped_catalog", {"변신": {}, "마법인형": {}, "성물": {}})
	world.call("_invalidate_equipment_static")
	_check(is_zero_approx(float(world.call("_blessing_consumption_reduction_percent"))), "unequip removes reduction")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("AIN_EXP_PROGRESSION_OK: option parsing, runtime reduction, explicit level table, save migration")
		quit(0)
	else:
		print("AIN_EXP_PROGRESSION_FAILED: %d failure(s)" % failures.size())
		quit(1)
