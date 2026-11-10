extends RefCounted
const Core = preload("res://scripts/mastery/mastery523.gd")
const View = preload("res://scripts/mastery/mastery_view.gd")
const ResetTicket = preload("res://scripts/mastery/mastery_reset_ticket.gd")
var reset_ticket = ResetTicket.new()
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
var balance_config: Dictionary = {}
var balance_error: String = ""

func _init() -> void:
	reset_rng.randomize()
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string("res://data/config/mastery523_balance.json")) != OK or not parser.data is Dictionary:
		balance_error = "숙련 자체 설정을 읽을 수 없습니다"; return
	balance_config = parser.data
	if balance_config.get("schema") != "twilight.mastery523.balance.v1": balance_error = "숙련 자체 설정 버전 오류"; return
	if not balance_config.has("partial_repair_cost"): balance_config.partial_repair_cost = 0
	for field: String in ["normal_hit_points","purchase_day_utc_offset_hours","purchase_day_reset_hour","acquire_currency_id","acquire_cost","partial_repair_cost"]:
		var value: Variant = balance_config.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or absf(float(value)) > 100000000:
			balance_error = "숙련 자체 설정 수치 오류"; return
	if int(balance_config.normal_hit_points) < 0 or int(balance_config.acquire_cost) < 0 or int(balance_config.acquire_currency_id) not in [1,4] or absi(int(balance_config.purchase_day_utc_offset_hours)) > 14 or int(balance_config.purchase_day_reset_hour) not in range(24): balance_error = "숙련 자체 설정 범위 오류"
	if balance_config.get("color_draw_mode") not in ["independent_fields","shared_level"]: balance_error = "숙련 색상 자체 설정 오류"
	if not balance_config.has("point_only_target_options"): balance_config.point_only_target_options = "preserve_existing"
	if balance_config.point_only_target_options not in ["preserve_existing","clear_existing","block_unverified"]: balance_error = "숙련 점수 전용 교체 자체 설정 오류"
	if not balance_config.has("typed_percent_ignore"): balance_config.typed_percent_ignore = "style_amplifier"
	if balance_config.typed_percent_ignore not in ["style_amplifier","display_only"]: balance_error = "숙련 퍼센트 무시 자체 설정 오류"
	if not balance_config.has("partial_repair"): balance_config.partial_repair = "fixed_missing_values_only"
	if balance_config.partial_repair not in ["fixed_missing_values_only","preview_only"] or int(balance_config.partial_repair_cost) < 0: balance_error = "숙련 부분 복구 자체 설정 오류"
	if not balance_config.has("partial_reroll"): balance_config.partial_reroll = "complete_levels_only"
	if balance_config.partial_reroll not in ["complete_levels_only","block_weapon"]: balance_error = "숙련 부분 재설정 자체 설정 오류"
	if not balance_config.has("reset_payment_default"): balance_config.reset_payment_default = "currency"
	if balance_config.reset_payment_default not in ["currency","ticket"]: balance_error = "숙련 지불 선택 자체 설정 오류"

func purchase_period(unix_time: float = -1) -> int:
	var moment: float = Time.get_unix_time_from_system() if unix_time < 0 else unix_time
	return floori((moment+int(balance_config.get("purchase_day_utc_offset_hours",9))*3600-int(balance_config.get("purchase_day_reset_hour",5))*3600)/86400.0)

func acquisition_charge() -> Dictionary:
	return {"CurrencyID":int(balance_config.acquire_currency_id),"Cost":int(balance_config.acquire_cost),"provenance":"CUSTOM_BALANCE"}

func configure(host: Node) -> void:
	world = host
	var path: String = ""
	var sha: String = ""
	var explicit_input := false
	for arg: String in OS.get_cmdline_user_args():
		if arg in ["--mastery523-pack","--mastery523-sha"]: explicit_input = true
		if arg.begins_with("--mastery523-pack="):
			explicit_input = true; path = arg.trim_prefix("--mastery523-pack=")
		if arg.begins_with("--mastery523-sha="):
			explicit_input = true; sha = arg.trim_prefix("--mastery523-sha=")
	if explicit_input:
		enabled = core.load_pack(path,sha)
		problem = "" if enabled else core.problem
	else:
		enabled = core.load_original()
		if enabled: problem = ""
		elif not core.problem.is_empty(): problem = core.problem
	if enabled: install_reset_ticket()

func install_reset_ticket() -> Dictionary:
	if not reset_ticket.configure(core.operations.get("reset_ticket",{})): return Core.fail("ticket_source_missing")
	return reset_ticket.install(world)

func check_load(data: Dictionary) -> String:
	if not data.has(Core.SAVE_KEY): return ""
	if not enabled:
		# Preserve the entire opaque namespace without activating or normalizing it.
		return ""
	return core.validate_state(data[Core.SAVE_KEY])

func accept_load(data: Dictionary) -> void:
	state = data.get(Core.SAVE_KEY,Core.fresh()).duplicate(true) if data.get(Core.SAVE_KEY,Core.fresh()) is Dictionary else Core.fresh()
	if enabled and state.has("rng_state"): reset_rng.state = int(state.rng_state)
	if enabled and not balance_error.is_empty(): problem = balance_error
	# Anchor old first-period receipts at migration, including a used-up quota.
	# Merely opening a quote never silently refills legacy purchases.
	if enabled and int(state.get("purchase_count",0)) > 0 and not state.has("legacy_purchase_period"):
		state.legacy_purchase_period = purchase_period()
		state.purchase_epoch = purchase_period()
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
	# This adapter accepts an externally settled outcome. Local HUD purchases
	# use execute(), which stages the real inventory debit in the same save.
	if not charge.is_empty() and settlement.get("confirmed_charge") != charge: return Core.fail("payment_unconfirmed")
	if not charge.is_empty() and str(settlement.get("receipt_id","")) != str(plan.get("receipt_id","")): return Core.fail("payment_receipt_mismatch")
	return _commit(plan,{})

func _commit(plan: Dictionary, resources: Dictionary) -> Dictionary:
	if busy or transaction_blocked or plan.get("before") != state or not core.validate_state(plan.get("after")).is_empty(): return Core.fail("stale_or_invalid_plan")
	busy = true
	var backup: String = ""
	var write_path: String = world.save_path()
	if plan.kind in ["local_mastery_change","partial_option_repair"] and FileAccess.file_exists(write_path):
		var sha: String = FileAccess.get_sha256(write_path)
		backup = write_path+(".pre-mastery-change-" if plan.kind == "local_mastery_change" else ".pre-mastery-repair-")+sha
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
	if resources.has("item_instances"): world.item_instances = resources.item_instances.duplicate(true)
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
	if currency == 1814: return reset_ticket.prepare(world,cost)
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

func _reset_payment(charge: Dictionary, payment: String) -> Dictionary:
	if payment == "currency": return {"ok":true,"charge":charge.duplicate(true)}
	if payment != "ticket": return Core.fail("unknown_payment_method")
	if reset_ticket.definition.is_empty(): return Core.fail("ticket_source_missing")
	if int(charge.get("TicketAmount",0)) <= 0: return Core.fail("ticket_not_applicable")
	var selected: Dictionary = charge.duplicate(true)
	selected["original_currency_charge"] = charge.duplicate(true)
	selected["CurrencyID"] = int(reset_ticket.definition.currency.ID)
	selected["Cost"] = int(charge.TicketAmount)
	selected["payment_method"] = "ticket"
	selected["definition_sha256"] = reset_ticket.fingerprint
	return {"ok":true,"charge":selected}

func quote(action: String, weapon: int, target: int = 0, prefix: int = 0, payment: String = "currency") -> Dictionary:
	if not enabled or busy: return Core.fail("pack_unavailable_or_busy")
	if transaction_blocked: return Core.fail("saved_but_activation_failed")
	if not balance_error.is_empty(): return Core.fail(balance_error)
	if world.equipment_collections.save_blocked or world.source_save_blocked: return Core.fail("save_protected")
	var plan: Dictionary
	if action == "purchase":
		plan = core.plan_purchase(state,weapon,_receipt("quote"),purchase_period())
	elif action == "reset":
		plan = core.reroll_availability(state,weapon,str(balance_config.partial_reroll))
	elif action == "repair":
		if balance_config.partial_repair == "preview_only": return Core.fail("repair_preview_only")
		plan = core.plan_partial_repair(state,weapon,_receipt("quote"),{"CurrencyID":1,"Cost":int(balance_config.partial_repair_cost),"provenance":"CUSTOM_BEHAVIOR"})
	elif action == "acquire":
		plan = core.acquire_availability(state,weapon,prefix,acquisition_charge())
	else: return Core.fail("unknown_action")
	if not plan.ok: return plan
	if action == "reset":
		var chosen: Dictionary = _reset_payment(plan.charge,payment)
		if not chosen.ok: return chosen
		plan.charge = chosen.charge
	elif payment != "currency": return Core.fail("unknown_payment_method")
	var wallet: Dictionary = _wallet(plan.charge)
	if not wallet.ok: wallet["charge"] = plan.charge; return wallet
	return {"ok":true,"charge":plan.charge.duplicate(true),"before":state.duplicate(true),"frozen_levels":plan.get("frozen",[]).duplicate()}

func execute(action: String, weapon: int, target: int, prefix: int, expected: Dictionary, payment: String = "currency") -> Dictionary:
	if not _confirmation_matches(expected): return Core.fail("stale_or_invalid_plan")
	var quoted: Dictionary = quote(action,weapon,target,prefix,payment)
	if not quoted.ok: return quoted
	if world.hud.has_method("is_card_reveal_busy") and world.hud.is_card_reveal_busy(): return Core.fail("pending_card_confirmation")
	var receipt: String = _receipt(action)
	var plan: Dictionary
	if action == "purchase": plan = core.plan_purchase(state,weapon,receipt,purchase_period())
	elif action == "repair": plan = core.plan_partial_repair(state,weapon,receipt,{"CurrencyID":1,"Cost":int(balance_config.partial_repair_cost),"provenance":"CUSTOM_BEHAVIOR"})
	elif action in ["reset","acquire"]:
		var staged_rng := RandomNumberGenerator.new()
		staged_rng.state = reset_rng.state
		plan = core.plan_reroll(state,weapon,staged_rng,receipt,str(balance_config.color_draw_mode),str(balance_config.partial_reroll)) if action == "reset" else core.plan_acquire(state,weapon,prefix,staged_rng,receipt,acquisition_charge(),str(balance_config.color_draw_mode))
	else: return Core.fail("unknown_action")
	if not plan.ok: return plan
	if action == "reset": plan.charge = quoted.charge.duplicate(true)
	var wallet: Dictionary = _wallet(plan.charge)
	if not wallet.ok: return wallet
	plan.after.receipts[receipt]["charge"] = plan.charge.duplicate(true)
	if wallet.has("consumed_ids"): plan.after.receipts[receipt]["consumed_ticket_ids"] = wallet.consumed_ids.duplicate()
	var resources: Dictionary = {"inventory":wallet.inventory,"gold":wallet.gold}
	if wallet.has("item_instances"): resources["item_instances"] = wallet.item_instances
	return _commit(plan,resources)

func _confirmation_matches(expected: Dictionary) -> bool:
	# Ordinary hits may add points while a modal is open. Rebuild the plan from
	# current points; any spending, locks, owned options or receipt change is stale.
	if not core.validate_state(expected).is_empty(): return false
	for key: String in expected.weapons:
		if int(core.record(state,int(key)).points) < int(expected.weapons[key].points): return false
	var snapshots: Array = [expected.duplicate(true),state.duplicate(true)]
	for snapshot: Dictionary in snapshots:
		for key: String in snapshot.weapons.keys():
			var entry: Dictionary = snapshot.weapons[key]
			entry.erase("points")
			if entry == {"options":[],"colors":{},"locks":{}}: snapshot.weapons.erase(key)
	return snapshots[0] == snapshots[1]

func normal_hit(actual_weapon: int) -> bool:
	if not enabled or busy or transaction_blocked or not balance_error.is_empty() or world == null: return false
	if world.equipment_collections.save_blocked or world.source_save_blocked: return false
	var weapon: int = core.normalize_weapon(actual_weapon)
	var amount: int = int(balance_config.normal_hit_points)
	if weapon == 0 or amount <= 0: return false
	var entry: Dictionary = core.record(state,weapon)
	if not Core.point_text(entry.points) or int(entry.points) > int(Core.MAX_POINT_TEXT)-amount: return false
	entry.points = str(int(entry.points)+amount)
	state.weapons[str(weapon)] = entry
	# Same quiet-window persistence as other ordinary combat progress; no
	# per-hit financial receipts or full-save requirement on the attack path.
	world._request_deferred_save()
	if is_instance_valid(view) and view.visible: view.update_progress()
	return true

func reason_text(reason: String) -> String:
	var ticket_errors: Dictionary = {"ticket_source_missing":"티켓 정의가 포함된 새 숙련 팩이 필요합니다","ticket_catalog_conflict":"티켓의 원본 카탈로그 정체가 일치하지 않습니다","ticket_not_applicable":"잠금이 없는 재설정은 원본 아데나 비용을 사용합니다","insufficient_verified_tickets":"정체가 확인된 잠금 해제 티켓 부족 · 이름만 같은 저장은 보존합니다","ticket_ownership_count_mismatch":"티켓 보유 수량과 개체가 일치하지 않습니다","invalid_ticket_count":"티켓 수량 오류","unknown_payment_method":"지불 수단을 다시 선택하세요"}
	if ticket_errors.has(reason): return ticket_errors[reason]
	if reason == "repair_preview_only": return "자체 설정에 따라 부분 복구는 미리보기만 제공합니다"
	if reason == "no_fixed_partial_repair": return "원본 결과가 하나로 확정되는 누락 값이 없습니다. 기존 상태를 보존합니다"
	var resolved: Dictionary = {"daily_purchase_limit":"오늘 숙련치 구매 5회 완료","level_not_reached":"숙련 레벨을 먼저 달성하세요","level_already_or_partly_owned":"이미 보유했거나 일부만 있는 레벨입니다","partial_owned_level":"일부만 남은 보유 옵션은 원래 저장을 보존하며 재설정을 보류합니다","all_fields_locked":"변경할 슬롯을 하나 이상 잠금 해제하세요"}
	if resolved.has(reason): return resolved[reason]
	return str({"saved_but_activation_failed":"거래 결과는 저장되었습니다. 저장 데이터를 다시 불러온 뒤 계속하세요","save_protected":"저장 보호 중 · 저장 데이터를 확인하세요","insufficient_gold":"아데나 부족","insufficient_material":"재료 또는 다이아 부족","material_locked":"재료가 잠겨 있습니다","purchase_reset_boundary_unverified":"첫 구매 주기 5회 완료 · 초기화 시각 확인 대기","repeat_service_restriction_unverified":"첫 교체 완료 · 반복 구매 조건 확인 대기","variable_value_mapping_unverified":"변동 옵션은 네 슬롯 값 대응 확인 필요","locked_value_mapping_unverified":"잠금 옵션은 네 슬롯 값 대응 확인 필요","owned_options_required":"보유한 옵션과 색상이 필요합니다","operation_source_missing":"실행 정보가 포함된 새 숙련 팩 필요","color_draw_source_missing":"색상 재결정 정보가 포함된 새 팩 필요","target_option_policy_unconfirmed":"옵션 미선택 교체 시 목표 기존 옵션 처리 확인 필요","invalid_transfer":"서로 다른 숙련도를 선택하세요","option_prefix_not_acquired":"획득한 숙련도 범위를 선택하세요","stale_or_invalid_plan":"상태가 바뀌었습니다. 다시 선택하세요","backup_failed":"이전 저장 백업 실패","pending_card_confirmation":"카드 결과 확인을 먼저 완료하세요"}.get(reason,reason))

func balance(currency: int) -> int:
	if currency == 1814:
		var owned: Dictionary = reset_ticket.owned_ids(world)
		return owned.ids.size() if owned.ok else 0
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
	# Reuse TWILIGHT's explicit single-player PvP->PvE and flat-ignore rules.
	# Keep source labels/rows immutable; percentages use a separate typed path.
	var mapping: Dictionary = {"HPPlus":"hpFlat","MPPlus":"mpFlat","MagicResist":"mr","MeleeDamage":"meleeDamage","RangeDamage":"rangedDamage","MagicDamage":"magicDamage","MeleeHit":"meleeHit","RangeHit":"rangedHit","AttackSpeedBonus":"attackSpeed","MeleeCritical":"meleeCritical","RangeCritical":"rangedCritical","MagicCritical":"magicCritical"}
	mapping.merge({"PVPMeleeAdditionDamage":"meleeDamage","PVPRangeAdditionDamage":"rangedDamage","PVPMagicAdditionDamage":"magicDamage","PierceDamageReduction":"damage_reduction_ignore","PiercePVPDamageReduction":"damage_reduction_ignore"})
	var total: int = 0
	# One flat grant per achieved matched level, as in the official level table.
	# Sum those grants in the existing consumers; never deduplicate BonusID
	# across levels or compound a percentage for a flat matching bonus.
	for bonus: Dictionary in core.active_options(state,base)+core.active_matching_bonuses(state,base):
		if str(mapping.get(str(bonus.type_name),"")) != key: continue
		var value: float = float(bonus.Value)
		var type: Dictionary = core.types[int(bonus.BonusTypeID)]
		for unit: Dictionary in core.tables.UIUnit:
			if int(unit.UnitID) == int(type.UnitID) and int(unit.Denominator) > 0:
				value /= float(unit.Denominator)
				break
		total += int(value)
	return total

func damage_amplification(kind: String, actual_weapon: int) -> float:
	if not enabled or balance_config.get("typed_percent_ignore") != "style_amplifier": return 0.0
	var base: int = core.normalize_weapon(actual_weapon)
	if base == 0: return 0.0
	var names: Dictionary = {"melee":"IgnoreMeleeDamageReductionPercent","ranged":"IgnoreRangeDamageReductionPercent","magic":"IgnoreMagicDamageReductionPercent"}
	if not names.has(kind): return 0.0
	var total: float = 0.0
	for bonus: Dictionary in core.active_options(state,base):
		if str(bonus.type_name) != names[kind]: continue
		var type: Dictionary = core.types[int(bonus.BonusTypeID)]
		for unit: Dictionary in core.tables.UIUnit:
			if int(unit.UnitID) == int(type.UnitID) and int(unit.Denominator) > 0:
				total += float(bonus.Value)/float(unit.Denominator)
				break
	return total

func effect_supported(type_name: String) -> bool:
	if type_name.begins_with("Ignore") and type_name.ends_with("DamageReductionPercent"): return balance_config.get("typed_percent_ignore") == "style_amplifier"
	return type_name in ["MeleeHit","RangeHit","MeleeDamage","RangeDamage","MagicDamage","HPPlus","MPPlus","MagicResist","AttackSpeedBonus","MeleeCritical","RangeCritical","MagicCritical","PVPMeleeAdditionDamage","PVPRangeAdditionDamage","PVPMagicAdditionDamage","PierceDamageReduction","PiercePVPDamageReduction"]

func application_note(type_name: String) -> String:
	if type_name in ["PVPMeleeAdditionDamage","PVPRangeAdditionDamage","PVPMagicAdditionDamage"]: return " · PvP→PvE (기존 단독플레이 규칙)"
	if type_name in ["PierceDamageReduction","PiercePVPDamageReduction"]: return " · 추가 피해 적용 (기존 리덕션 무시 규칙)"
	if type_name.begins_with("Ignore") and type_name.ends_with("DamageReductionPercent"): return " · 자체 적용: 같은 공격 종류의 피해 증폭" if effect_supported(type_name) else " · 자체 설정: 표시만"
	return ""

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

func grade_name(id: int) -> String:
	# Grade2..5 colors verified against source Color->ColorTable and NC chart.
	return str({2:"그린",3:"블루",4:"레드",5:"퍼플"}.get(id,str(id)))

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
	if enabled: install_reset_ticket()
	if not is_instance_valid(view):
		view = View.new()
		view.runtime = self
		world.hud.add_child(view)
	view.show()
	view.refresh()
