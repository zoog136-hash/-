extends RefCounted
const Core = preload("res://scripts/mastery/mastery523.gd")
const View = preload("res://scripts/mastery/mastery_view.gd")
var core = Core.new()
var state: Dictionary = Core.fresh()
var world
var enabled: bool = false
var problem: String = "별도 숙련 원본 팩을 설치하면 사용할 수 있습니다"
var busy: bool = false
var view: Control
var action_sequence: int = 0

func configure(host: Node) -> void:
	world = host
	var path: String = ""
	var sha: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mastery523-pack="): path = arg.trim_prefix("--mastery523-pack=")
		if arg.begins_with("--mastery523-sha="): sha = arg.trim_prefix("--mastery523-sha=")
	if not path.is_empty():
		enabled = core.load_pack(path,sha)
		problem = "" if enabled else core.problem

func check_load(data: Dictionary) -> String:
	if not data.has(Core.SAVE_KEY): return ""
	if not enabled:
		# Preserve the entire opaque namespace without activating or normalizing it.
		return ""
	return core.validate_state(data[Core.SAVE_KEY])

func accept_load(data: Dictionary) -> void:
	state = data.get(Core.SAVE_KEY,Core.fresh()).duplicate(true) if data.get(Core.SAVE_KEY,Core.fresh()) is Dictionary else Core.fresh()

func save_fields() -> Dictionary:
	# With no pack, unknown fields are already retained by the existing writer.
	return {Core.SAVE_KEY:state.duplicate(true)} if enabled else {}

func commit_plan(plan: Dictionary, settlement: Dictionary = {}) -> Dictionary:
	if busy or not enabled or not bool(plan.get("ok",false)): return Core.fail("unavailable_plan")
	if bool(plan.get("requires_two_sided_commit",false)): return Core.fail("two_sided_server_commit_unavailable")
	if bool(plan.get("service_confirmation_required",false)) and settlement.get("service_receipt_id") != plan.get("receipt_id"): return Core.fail("service_settlement_unconfirmed")
	if plan.get("before") != state or not core.validate_state(plan.get("after")).is_empty(): return Core.fail("stale_or_invalid_plan")
	var charge: Dictionary = plan.get("charge",{})
	# No local Gem alias or currency for unresolved additional service fees is
	# invented. Paid service outcomes need a separately confirmed settlement.
	if not charge.is_empty() and settlement.get("confirmed_charge") != charge: return Core.fail("payment_unconfirmed")
	if not charge.is_empty() and str(settlement.get("receipt_id","")) != str(plan.get("receipt_id","")): return Core.fail("payment_receipt_mismatch")
	busy = true
	var old: Dictionary = state
	state = plan.after.duplicate(true)
	var error: Error = world._save_game(true)
	if error != OK:
		state = old
		busy = false
		return Core.fail("save_failed_%d" % error)
	busy = false
	world._update_hud()
	if is_instance_valid(view): view.refresh()
	return {"ok":true}

func credit_confirmed_points(actual_weapon: int, amount: String, receipt_id: String) -> Dictionary:
	if not enabled: return Core.fail("pack_unavailable")
	return commit_plan(core.plan_points(state,core.normalize_weapon(actual_weapon),amount,receipt_id))

func catalog_bonus(key: String, actual_weapon: int) -> int:
	if not enabled: return 0
	var base: int = core.normalize_weapon(actual_weapon)
	if base == 0: return 0
	# Only exact, existing PvE consumers. PvP effects are retained and displayed,
	# never converted to PvE. Unknown percentage/reduction semantics remain raw.
	var mapping: Dictionary = {"HPPlus":"hpFlat","MPPlus":"mpFlat","MagicResist":"mr","MeleeDamage":"meleeDamage","RangeDamage":"rangedDamage","MagicDamage":"magicDamage","MeleeHit":"meleeHit","RangeHit":"rangedHit"}
	var total: int = 0
	for bonus: Dictionary in core.active_options(state,base):
		if str(mapping.get(str(bonus.type_name),"")) == key: total += int(bonus.Value)
	return total

func set_color_lock(weapon: int, level: int, slot: int, locked: bool) -> Dictionary:
	if not enabled: return Core.fail("pack_unavailable")
	action_sequence += 1
	var receipt := "lock:%s:%d:%d" % [str(Time.get_unix_time_from_system()),Time.get_ticks_usec(),action_sequence]
	var result: Dictionary = commit_plan(core.plan_lock(state,weapon,level,slot,locked,receipt))
	world.hud.show_message("숙련 잠금 저장 완료" if result.ok else "숙련 잠금 변경 실패 · " + str(result.get("reason","")))
	return result

func weapon_name(base: int) -> String:
	var names: Dictionary = preload("res://scripts/animation/source_weapon_banks.gd").data().get("local_weapon_type_to_source",{})
	for label: String in names:
		if int(names[label]) == base: return label
	return str(core.find_row("WeaponType",base).get("Name",base))

func currency_name(id: int) -> String:
	var name: String = str(core.find_row("Currency",id).get("Name","확인되지 않은 재화"))
	return str({"Adena":"아데나","Gem":"다이아"}.get(name,name))

func bonus_text(bonus: Dictionary) -> String:
	var type: Dictionary = core.types[int(bonus.BonusTypeID)]
	var names: Dictionary = {"MeleeHit":"근거리 명중","RangeHit":"원거리 명중","MeleeDamage":"근거리 대미지","RangeDamage":"원거리 대미지","MagicDamage":"마법 대미지","HPPlus":"최대 HP","MPPlus":"최대 MP","MagicResist":"마법 방어력","MeleeCritical":"근거리 치명타","RangeCritical":"원거리 치명타","MagicCritical":"마법 치명타","AttackSpeedBonus":"공격 속도","PVPMeleeAdditionDamage":"PvP 근거리 추가 대미지","PVPRangeAdditionDamage":"PvP 원거리 추가 대미지","PVPMagicAdditionDamage":"PvP 마법 추가 대미지","IgnoreMeleeDamageReductionPercent":"근거리 리덕션 무시","IgnoreRangeDamageReductionPercent":"원거리 리덕션 무시","IgnoreMagicDamageReductionPercent":"마법 리덕션 무시","PierceDamageReduction":"대미지 리덕션 무시","PiercePVPDamageReduction":"PvP 대미지 리덕션 무시"}
	var value: String = str(int(bonus.Value))
	for unit: Dictionary in core.tables.UIUnit:
		if int(unit.UnitID) == int(type.UnitID) and int(unit.Denominator) > 0:
			value = str(float(bonus.Value)/float(unit.Denominator))
	if int(type.UnitID) in [3,211]: value += "%"
	return "%s +%s" % [str(names.get(str(type.Name),"확인 중인 효과")),value]

func show_panel() -> void:
	if not is_instance_valid(view):
		view = View.new()
		view.runtime = self
		world.hud.add_child(view)
	view.show()
	view.refresh()
