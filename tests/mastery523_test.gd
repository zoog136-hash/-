extends SceneTree
const Core = preload("res://scripts/mastery/mastery523.gd")
const Runtime = preload("res://scripts/mastery/mastery_runtime.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("MASTERY_FAIL: " + message)

static func fixture() -> Dictionary:
	# Synthetic schema fixture, never presented as original 523 content.
	var tables: Dictionary = {}
	for name: String in ["MasteryWeaponType","MasteryWeaponStep","MasteryWeaponLevelView","MasteryBonusView","MasteryGradeView","MasteryGradeMatchingBonus","MasteryPointPayment","MasteryPointPurchaseView","MasteryResetCost","ClassChangeMasteryLevelCost","ClassChangeMasteryWeaponType","MasteryChangeLevelCost","Bonus","BonusType","UIUnit","Class","WeaponType","Currency","CurrencyUnitClass"]: tables[name] = []
	tables.BonusType = [{"ID":1,"Name":"MeleeDamage","UnitID":1},{"ID":2,"Name":"RangeDamage","UnitID":1}]
	tables.Class = [{"ID":123}]
	tables.MasteryGradeView = [{"ID":1,"GradeID":2,"Probability":1000000}]
	tables.MasteryResetCost = [{"ID":1,"Step":1,"LockSlotCount":0,"CurrencyID":1,"Cost":7,"TicketAmount":0},{"ID":2,"Step":1,"LockSlotCount":1,"CurrencyID":4,"Cost":9,"TicketAmount":1}]
	tables.ClassChangeMasteryLevelCost = [{"ID":1,"MasteryWeaponLevel":2,"CurrencyCost":3}]
	for weapon: int in range(1,16):
		tables.WeaponType.append({"ID":weapon,"Name":"fixture_"+str(weapon)})
		tables.MasteryWeaponType.append({"ID":weapon,"BaseType":weapon,"ActualType":weapon})
		tables.MasteryWeaponStep.append({"ID":weapon,"WeaponTypeID":weapon,"Step":1})
		tables.ClassChangeMasteryWeaponType.append({"ID":weapon,"ToCharacterClass":123,"ToWeaponType":weapon})
		var group: int = 0
		for level: int in range(1,9):
			var level_id: int = weapon*100+level
			tables.MasteryWeaponLevelView.append({"ID":level_id,"WeaponTypeID":weapon,"WeaponStepID":weapon,"Level":level,"CumulativePoint":(weapon+1)*level*1000000})
			for slot: int in range(1,3):
				var count: int = 1 if level == 1 else (2 if level < 6 else 3)
				for variant: int in count:
					group += 1
					var id: int = weapon*1000+group
					var weight: int = 1000000 if count == 1 else ([970000,30000][variant] if count == 2 else [970000,27000,3000][variant])
					tables.MasteryBonusView.append({"ID":id,"MasteryWeaponLevelID":level_id,"BonusID":id,"Slot":slot,"ClassChangeMasteryBonusGroupID":group,"Probability":weight})
					tables.Bonus.append({"ID":id,"BonusTypeID":1 if weapon == 1 else 2,"Value":variant+1})
	return {"schema":"twilight.mastery523.v1","tables":tables}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var core = Core.new()
	var source_path: String = OS.get_environment("TWILIGHT_MASTERY523_PACK")
	if source_path.is_empty():
		check(core.configure(fixture()),"synthetic pack loads")
	else:
		check(core.load_pack(source_path,FileAccess.get_sha256(source_path)),"actual private source pack loads")
	if core.levels.is_empty(): quit(1); return
	check(not core.load_pack("/missing-masterypack","0".repeat(64)),"missing pack rejected")
	check(core.levels.size() == 15,"rejected replacement retains registry")
	var bad: Dictionary = {"schema":"twilight.mastery523.v1","tables":core.tables.duplicate(true)}
	bad.tables.MasteryBonusView[0].Probability = 4
	check(not core.configure(bad),"bad option weights rejected")
	check(core.options.size() == 36,"registry survives malformed replacement")
	# Every group must round-trip through each of the 15 destinations. The
	# BonusID is resolved in destination weapon context, never copied blindly.
	for group: int in core.options:
		for source: int in core.options[group]:
			for target: int in core.options[group]:
				var a: Dictionary = core.options[group][source]
				var b: Dictionary = core.options[group][target]
				check(a.level == b.level and a.Slot == b.Slot and core.bonuses[int(a.BonusID)].Value == core.bonuses[int(b.BonusID)].Value,"group correspondence round trip")
	check(not Core.point_text("9223372036854775808") and not Core.point_text("-1") and not Core.point_text("1.5") and not Core.point_text("01"),"strict lossless point values")
	var state: Dictionary = Core.fresh()
	var weapon: int = int(core.levels.keys()[0])
	var target: int = int(core.levels.keys()[2])
	var target_class: int = 0
	for row: Dictionary in core.tables.ClassChangeMasteryWeaponType:
		if int(row.ToWeaponType) == target: target_class = int(row.ToCharacterClass); break
	var source_group: int = 0
	for group: int in core.options:
		if int(core.options[group][weapon].level) == 2: source_group = group; break
	var grade: int = int(core.tables.MasteryGradeView[0].GradeID)
	var threshold: int = int(core.levels[weapon][1].CumulativePoint)
	state.weapons[str(weapon)] = {"points":str(threshold),"options":[{"group_id":source_group}],"colors":{"2":[grade,grade,grade,grade]},"locks":{"2":[true,false,false,false]}}
	check(core.validate_state(state).is_empty(),"original option/color/lock state validates")
	var low: Dictionary = state.duplicate(true)
	low.weapons[str(weapon)].points = "0"
	check(core.validate_state(low).is_empty() and core.active_options(low,weapon).is_empty(),"above-level owned option retained but inactive")
	check(int(core.reset_quote(state,weapon).LockSlotCount) == 1,"reset quote uses original color locks")
	var incoming: Dictionary = core.record(state,weapon)
	check(not core.plan_reset(state,weapon,incoming,"locked-reset").ok,"unverified locked reset coupling blocked")
	check(not core.plan_class_change(state,weapon,target,target_class,2,"","unknown-points").ok,"unknown server point conversion blocked")
	var changed: Dictionary = core.plan_class_change(state,weapon,target,target_class,2,"1","transfer-a")
	check(changed.ok,"confirmed point outcome permits transfer")
	check(changed.get("service_confirmation_required",false),"zero destination-row fee never makes the whole service free")
	if changed.ok:
		var result: Dictionary = core.record(changed.after,target)
		check(result.points == "1" and result.colors == incoming.colors and result.locks.is_empty(),"transfer preserves colors and confirmed points; clears locks")
		check(result.options == incoming.options and core.active_options(changed.after,target).is_empty(),"transferred high-level option retained without premature effect")
		check(core.record(changed.after,weapon).points == "0" and core.record(changed.after,weapon).options.is_empty(),"source mastery and options cleared")
		check(not core.plan_class_change(changed.after,weapon,target,target_class,2,"1","transfer-a").ok,"transfer replay rejected")
	check(not core.plan_class_change(state,weapon,target,999999,2,"1","bad-class").ok,"invalid class destination rejected")
	var credit: Dictionary = core.plan_points(state,weapon,"2500000000","credit-a")
	check(credit.ok and int(credit.after.weapons[str(weapon)].points) == threshold+2500000000,"point growth exceeds signed32 without truncation")
	check(not core.plan_points(credit.after,weapon,"1","credit-a").ok,"point receipt cannot replay")
	check(not core.plan_points(state,weapon,Core.MAX_POINT_TEXT,"overflow").ok,"signed64 overflow rejected")
	var tie: Dictionary = core.server_choice(incoming,{"points":"900"},0)
	check(tie.origin == "departure" and tie.record == incoming,"server tie selects departure without summing")
	check(core.server_choice(incoming,{"points":"900"},-1).record.points == "900","confirmed higher destination retained")
	check(not core.server_choice(incoming,{},2).ok,"unknown server comparator rejected")
	var server: Dictionary = core.plan_server_import(Core.fresh(),state,{str(weapon):0},"server-a")
	check(server.ok and server.requires_two_sided_commit,"server import requires both durable sides")
	check(server.after.weapons[str(weapon)] == state.weapons[str(weapon)],"server tie copies departure whole record")
	check(server.departure_after.weapons.is_empty(),"server departure retirement is a separate planned result")
	check(not core.plan_server_import(Core.fresh(),state,{},"server-b").ok,"missing per-weapon comparison rejected")
	var corrupt: Dictionary = state.duplicate(true)
	corrupt.weapons[str(weapon)].options.append({"group_id":source_group})
	check(not core.validate_state(corrupt).is_empty(),"duplicate source option slot rejected")
	print("MASTERY523_%s checks=%d failures=%d source=%s" % ["PASS" if failures == 0 else "FAIL",checks,failures,"synthetic" if source_path.is_empty() else "actual523"])
	quit(1 if failures else 0)
