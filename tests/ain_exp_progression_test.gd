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

	# Explicit table preserves early-game TWILIGHT balance and adds high-level tiers.
	_check(EXP_RULES.table_requirement(35) == 1400, "level 35 entry preserved")
	_check(EXP_RULES.table_requirement(86) == 1801231, "level 86 baseline is unchanged")
	_check(EXP_RULES.table_requirement(87) == 5944062, "level 87 milestone 3.3x")
	_check(EXP_RULES.table_requirement(88) == 23776248, "level 88 milestone 4x")
	_check(EXP_RULES.table_requirement(90) == 570629952, "level 90 milestone 6x")
	_check(EXP_RULES.required_for_level(36, 1400) == 1716, "table contains legacy next-level requirement")
	_check(EXP_RULES.required_for_level(101, 1000) == 1260, "out-of-table legacy fallback")
	var half: Dictionary = EXP_RULES.migrate_progress(87, 100, 200, 0)
	_check(int(half["experience"]) == 2972031 and int(half["exp_need"]) == 5944062, "legacy 50 percent progress is preserved")
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
	world.set("equipped_catalog", {"변신": {}, "마법인형": {}, "성물": {}})
	_check(is_zero_approx(float(world.call("_blessing_consumption_reduction_percent"))), "unequipped baseline")
	world.set("equipped_catalog", {
		"변신": {},
		"마법인형": {"name":"__ain_test_doll__", "sourceOptions":["축복 소모량 감소 +25%"]},
		"성물": {}
	})
	world.set("equipped_items", {"weapon":{"name":"__ain_test_weapon__", "atk":0, "blessing_consumption_reduction_pct":20}})
	_check(is_equal_approx(float(world.call("_blessing_consumption_reduction_percent")), 45.0), "equipped doll and weapon stack")
	var ain: TwilightAinhasadService = world.get("ain_service") as TwilightAinhasadService
	_check(ain != null, "existing blessing service present")
	if ain != null:
		ain.blessing = 200
		ain.spend_remainder = 0.0
		_check(ain.consume_for_kill(42000, float(world.call("_blessing_consumption_reduction_percent"))) == 0, "45 percent reduction saves first blessing point")
		_check(ain.consume_for_kill(42000, float(world.call("_blessing_consumption_reduction_percent"))) == 1 and ain.blessing == 199, "reduction accumulates fractional spend")
	world.set("equipped_items", {})
	world.set("equipped_catalog", {"변신": {}, "마법인형": {}, "성물": {}})
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
