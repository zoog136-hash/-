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
var reset_rng := RandomNumberGenerator.new()
var transaction_blocked: bool = false

func _init() -> void:
	reset_rng.randomize()

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
	if enabled and state.has("rng_state"): reset_rng.state = int(state.rng_state)
	transaction_blocked = false

func save_fields() -> Dictionary:
	# With no pack, unknown fields are already retained by the existing writer.
	return {Core.SAVE_KEY:state.duplicate(true)} if enabled else {}

func commit_plan(plan: Dictionary, settlement: Dictionary = {}) -> Dictionary:
	if busy or transaction_blocked or not enabled or not bool(plan.get("ok",false)): return Core.fail("unavailable_plan")
	if bool(plan.get("requires_two_sided_commit",false)): return Core.fail("two_sided_server_commit_unavailable")
	if bool(plan.get("service_confirmation_required",false)) and settlement.get("service_receipt_id") != plan.get("receipt_id"): return Core.fail("service_settlement_unconfirmed")
	if plan.get("before") != state or not core.validate_state(plan.get("after")).is_empty(): return Core.fail("stale_or_invalid_plan")
	var charge: Dictionary = plan.get("charge",{})
	# No local Gem alias or currency for unresolved additional service fees is
	# invented. Paid service outcomes need a separately confirmed settlement.
	if not charge.is_empty() and settlement.get("confirmed_charge") != charge: return Core.fail("payment_unconfirmed")
	if not charge.is_empty() and str(settlement.get("receipt_id","")) != str(plan.get("receipt_id","")): return Core.fail("payment_receipt_mismatch")
	return _commit(plan,{})

func _commit(plan: Dictionary, resources: Dictionary) -> Dictionary:
	if busy or transaction_blocked or plan.get("before") != state or not core.validate_state(plan.get("after")).is_empty(): return Core.fail("stale_or_invalid_plan")
	busy = true
	var backup: String = ""
	var write_path: String = world.save_path()
	if plan.kind == "local_mastery_change" and FileAccess.file_exists(write_path):
		var sha: String = FileAccess.get_sha256(write_path)
		backup = write_path+".pre-mastery-change-"+sha
		if (not FileAccess.file_exists(backup) and DirAccess.copy_absolute(write_path,backup) != OK) or FileAccess.get_sha256(backup) != sha:
			busy = false
			return Core.fail("backup_failed")
	var staged: Dictionary = resources.duplicate(true)
	staged[Core.SAVE_KEY] = plan.after.duplicate(true)
	var error: Error = world._save_game(true,staged)
	# Main may report an activation error after its atomic payload write. Read
	# the actual outcome before treating that operation as an uncommitted failure.
	var committed: bool = error == OK or _durable_matches(staged,write_path)
	if not committed:
		busy = false
		return Core.fail("save_failed_%d" % error)
	state = plan.after.duplicate(true)
	if resources.has("inventory"): world.inventory = resources.inventory.duplicate(true)
	if resources.has("gold"): world.gold = int(resources.gold)
	if state.has("rng_state"): reset_rng.state = int(state.rng_state)
	transaction_blocked = error != OK
	busy = false
	world._refresh_speed_modifiers()
	world._update_hud()
	if is_instance_valid(view): view.refresh()
	if error != OK: return {"ok":false,"committed":true,"reason":"saved_but_activation_failed"}
	return {"ok":true,"backup_path":backup,"kind":plan.kind}

func _durable_matches(fields: Dictionary, path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return false
	for key: String in fields:
		if not parser.data.has(key) or parser.data[key] != JSON.parse_string(JSON.stringify(fields[key])): return false
	return true

func _receipt(action: String) -> String:
	action_sequence += 1
	return "%s:%s:%d:%d" % [action,str(Time.get_unix_time_from_system()),Time.get_ticks_usec(),action_sequence]

func _wallet(charge: Dictionary) -> Dictionary:
	var currency: int = int(charge.get("CurrencyID",0))
	var cost: int = int(charge.get("Cost",-1))
	if cost < 0: return Core.fail("unknown_cost")
	var bag: Dictionary = world.inventory.duplicate(true)
	var gold: int = int(world.gold)
	if currency == 1:
		if gold < cost: return Core.fail("insufficient_gold")
		return {"ok":true,"inventory":bag,"gold":gold-cost}
	var name: String = ""
	if currency == 4:
		name = world.CURRENCY_DROP.DIAMOND
	elif currency == 1682:
		var source: Dictionary = core.operations.get("point_purchase",{}).get("material",{})
		if source.is_empty(): return Core.fail("material_source_missing")
		name = str(source.Name).trim_prefix("[재료] ")
		var record: Dictionary = world._find_catalog_item_record(name,str(int(source.ID)))
		if record.get("source") != "inven" or str(record.get("sourceId")) != str(int(source.ID)) or record.get("name") != name or record.get("type") != "재료": return Core.fail("material_identity_unresolved")
	else: return Core.fail("currency_unresolved")
	if world._item_locked(name): return Core.fail("material_locked")
	for physical: Variant in world.item_instances.values():
		if physical is Dictionary and physical.get("name") == name: return Core.fail("physical_material_reconciliation_required")
	var amount: Variant = bag.get(name,0)
	if (not amount is int and not amount is float) or not is_finite(float(amount)) or amount != floorf(float(amount)) or float(amount) >= 9223372036854775807.0: return Core.fail("invalid_material_count")
	if int(amount) < cost: return Core.fail("insufficient_material")
	if int(amount) == cost: bag.erase(name)
	else: bag[name] = int(amount)-cost
	return {"ok":true,"inventory":bag,"gold":gold}

func quote(action: String, weapon: int, target: int = 0, prefix: int = 0) -> Dictionary:
	if not enabled or busy: return Core.fail("pack_unavailable_or_busy")
	if transaction_blocked: return Core.fail("saved_but_activation_failed")
	if world.equipment_collections.save_blocked or world.source_save_blocked: return Core.fail("save_protected")
	var plan: Dictionary
	if action == "purchase":
		plan = core.plan_purchase(state,weapon,_receipt("quote"))
	elif action == "reset":
		plan = core.fixed_reset_availability(state,weapon)
	elif action == "change":
		if world.field_map != null and bool(world.field_map.data.get("world_dungeon",false)): return Core.fail("world_dungeon")
		if bool(state.get("pending_server_selection",false)): return Core.fail("pending_server_selection")
		plan = core.plan_local_change(state,weapon,target,world.BASE508.source_class_id(world.job_class),prefix,_receipt("quote"),int(Time.get_datetime_dict_from_system(true).year))
	else: return Core.fail("unknown_action")
	if not plan.ok: return plan
	var wallet: Dictionary = _wallet(plan.charge)
	if not wallet.ok: wallet["charge"] = plan.charge; return wallet
	return {"ok":true,"charge":plan.charge.duplicate(true),"before":state.duplicate(true)}

func execute(action: String, weapon: int, target: int, prefix: int, expected: Dictionary) -> Dictionary:
	if expected != state: return Core.fail("stale_or_invalid_plan")
	var quoted: Dictionary = quote(action,weapon,target,prefix)
	if not quoted.ok: return quoted
	if world.hud.has_method("is_card_reveal_busy") and world.hud.is_card_reveal_busy(): return Core.fail("pending_card_confirmation")
	var receipt: String = _receipt(action)
	var plan: Dictionary
	if action == "purchase": plan = core.plan_purchase(state,weapon,receipt)
	elif action == "reset":
		var staged_rng := RandomNumberGenerator.new()
		staged_rng.state = reset_rng.state
		plan = core.plan_fixed_reset(state,weapon,staged_rng,receipt)
	else: plan = core.plan_local_change(state,weapon,target,world.BASE508.source_class_id(world.job_class),prefix,receipt,int(Time.get_datetime_dict_from_system(true).year))
	if not plan.ok: return plan
	var wallet: Dictionary = _wallet(plan.charge)
	if not wallet.ok: return wallet
	plan.after.receipts[receipt]["charge"] = plan.charge.duplicate(true)
	return _commit(plan,{"inventory":wallet.inventory,"gold":wallet.gold})

func reason_text(reason: String) -> String:
	return str({"saved_but_activation_failed":"거래 결과는 저장되었습니다. 저장 데이터를 다시 불러온 뒤 계속하세요","save_protected":"저장 보호 중 · 저장 데이터를 확인하세요","insufficient_gold":"아데나 부족","insufficient_material":"재료 또는 다이아 부족","material_locked":"재료가 잠겨 있습니다","purchase_reset_boundary_unverified":"첫 구매 주기 5회 완료 · 초기화 시각 확인 대기","repeat_service_restriction_unverified":"첫 교체 완료 · 반복 구매 조건 확인 대기","variable_value_mapping_unverified":"변동 옵션은 네 슬롯 값 대응 확인 필요","locked_value_mapping_unverified":"잠금 옵션은 네 슬롯 값 대응 확인 필요","owned_options_required":"보유한 옵션과 색상이 필요합니다","operation_source_missing":"실행 정보가 포함된 새 숙련 팩 필요","color_draw_source_missing":"색상 재결정 정보가 포함된 새 팩 필요","target_option_policy_unconfirmed":"옵션 미선택 교체 시 목표 기존 옵션 처리 확인 필요","invalid_transfer":"서로 다른 숙련도를 선택하세요","option_prefix_not_acquired":"획득한 숙련도 범위를 선택하세요","stale_or_invalid_plan":"상태가 바뀌었습니다. 다시 선택하세요","backup_failed":"이전 저장 백업 실패","pending_card_confirmation":"카드 결과 확인을 먼저 완료하세요"}.get(reason,reason))

func balance(currency: int) -> int:
	if currency == 1: return int(world.gold)
	if currency == 4: return int(world.inventory.get(world.CURRENCY_DROP.DIAMOND,0))
	var material: Dictionary = core.operations.get("point_purchase",{}).get("material",{})
	return int(world.inventory.get(str(material.get("Name","")).trim_prefix("[재료] "),0)) if currency == 1682 else 0

func credit_confirmed_points(actual_weapon: int, amount: String, receipt_id: String) -> Dictionary:
	if not enabled: return Core.fail("pack_unavailable")
	return commit_plan(core.plan_points(state,core.normalize_weapon(actual_weapon),amount,receipt_id))

func catalog_bonus(key: String, actual_weapon: int) -> int:
	if not enabled: return 0
	var base: int = core.normalize_weapon(actual_weapon)
	if base == 0: return 0
	# Only exact, existing PvE consumers. PvP effects are retained and displayed,
	# never converted to PvE. Unknown percentage/reduction semantics remain raw.
	var mapping: Dictionary = {"HPPlus":"hpFlat","MPPlus":"mpFlat","MagicResist":"mr","MeleeDamage":"meleeDamage","RangeDamage":"rangedDamage","MagicDamage":"magicDamage","MeleeHit":"meleeHit","RangeHit":"rangedHit","AttackSpeedBonus":"attackSpeed","MeleeCritical":"meleeCritical","RangeCritical":"rangedCritical","MagicCritical":"magicCritical"}
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
