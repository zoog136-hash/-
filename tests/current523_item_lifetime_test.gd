extends SceneTree
## Original item lifetime (ItemBonus DeleteTime / CannotExtendDeleteTime).
## A resolvable DeleteTime is the item's deadline (source_delete_time_raw),
## enforced by the existing deadline check under its policy: with
## rotate_ended_dates (offline default) a passed date no longer blocks,
## without it the client's expiry applies. Only an unresolvable lifetime still
## blocks use. CannotExtendDeleteTime is recorded; the game has no extension.
## Needs no 523 tables: rows are synthetic in the original's shape.
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func bonus(name_value: String, unit: String, value: Variant, type_id: int = 0, target: Variant = 0, possession: bool = false) -> Dictionary:
	return {"ID":1,"IsPossession":possession,"bonus_type":{"Name":name_value},"unit":{"Name":unit},"bonus":{"BonusApplicationTypeID":type_id,"BonusApplicationTargetID":target,"Value":value}}

func reasons(rows: Array) -> Array:
	var raw: Dictionary = {"TargettingTypeID":1,"ServiceRegionCode":""}
	var delay: Dictionary = bonus("ItemConsumeDelay","MilliSeconds",1000.0)
	return PROJECTION.consume_metadata([delay]+rows,raw,{"IsConsumable":true},{"ItemConsumeDelay":"MilliSeconds"}).blocked_reasons

func run() -> void:
	# Table JSON numbers are floats; the direct form is yyyymmddhh.
	check(PROJECTION.delete_time_stamp(bonus("DeleteTime","Time",2022071305.0)) == 202207130500, "direct DeleteTime yyyymmddhh resolves to its deadline")
	check(PROJECTION.delete_time_stamp(bonus("DeleteTime","Value",2022071305.0)) == 0, "a DeleteTime in another unit stays unresolved")
	check(PROJECTION.delete_time_stamp(bonus("DeleteTime","Time",2022071305.0,0,0,true)) == 0, "a possession DeleteTime stays unresolved")
	check(PROJECTION.delete_time_stamp(bonus("DeleteTime","Time",20220713.0)) == 0, "a truncated date stays unresolved")
	check(PROJECTION.delete_time_stamp(bonus("DeleteTime","Time",2022133105.0)) == 0, "an impossible date stays unresolved")
	check(reasons([bonus("DeleteTime","Time",2022071305.0)]).is_empty(), "a resolved lifetime no longer blocks use")
	check(reasons([bonus("DeleteTime","Time",20220713.0)]) == ["source_item_lifetime_unresolved"], "an unresolved lifetime still blocks use")
	check(reasons([bonus("CannotExtendDeleteTime","TrueFalse",1.0)]).is_empty() and reasons([bonus("CannotExtendDeleteTime","TrueFalse",0.0)]).is_empty(), "cannot-extend flag is recorded, not a use gate")
	check(not reasons([bonus("CannotExtendDeleteTime","TrueFalse",2.0)]).is_empty() and not reasons([bonus("CannotExtendDeleteTime","Value",1.0)]).is_empty(), "a malformed cannot-extend flag still blocks")
	# Deadline policy on the projected record.
	var previous: bool = D.rotate_ended_dates
	var passed: Dictionary = {"source_delete_time_raw":202207130500}
	var ahead: Dictionary = {"source_delete_time_raw":299912310500}
	var later_start: Dictionary = {"source_start_time_raw":299912310500}
	D.rotate_ended_dates = false
	check(not D.deadline_problem(passed,540).is_empty() and D.deadline_problem(ahead,540).is_empty(), "source dates: a passed deadline expires the item, a future one does not")
	D.rotate_ended_dates = true
	check(D.deadline_problem(passed,540).is_empty(), "offline rotation: a passed deadline no longer blocks")
	check(not D.deadline_problem(later_start,540).is_empty(), "a start date still ahead blocks under either policy")
	check(not D.deadline_problem({"source_delete_time_unresolved":true},540).is_empty(), "an unresolved lifetime blocks under either policy")
	D.rotate_ended_dates = previous
	print("CURRENT523_ITEM_LIFETIME_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
