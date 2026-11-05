extends RefCounted

const Common = preload("res://scripts/equipment523/common.gd")
const PROBABILITY_SCALE: int = 10000000

# All operations reroll their complete namespace. Quotes do not mutate inventory.
static func quote(pack: Dictionary, action: Dictionary, context: Dictionary) -> Dictionary:
	var kind: String = str(action.get("kind", ""))
	var target: Dictionary = context.get("target", {})
	var materials: Array = context.get("materials", [])
	if target.is_empty() or materials.size() != 1:
		return _error("장비와 소모품 한 개를 선택하세요.")
	if bool(target.get("locked", false)):
		return _error("잠긴 장비는 세공할 수 없습니다.")
	var material: Dictionary = materials[0]
	var material_id: int = int(material.get("source_id", 0))
	var source_id: int = int(target.get("source_id", 0))
	var target_raw: Dictionary = Common.item(pack, source_id).get("raw", {})
	var material_raw: Dictionary = Common.item(pack, material_id).get("raw", {})
	if target_raw.is_empty() or material_raw.is_empty():
		return _error("원문 아이템 정보가 없습니다.")
	var policy: Dictionary = context.get("policy", {})
	var costs_policy: Dictionary = policy.get("costs", {})
	var cost: Dictionary = costs_policy.get(kind, {})
	if not cost.has("gold_cost") or not cost.has("material_amount"):
		return _error("원문 실행 비용이 확정되지 않아 명시적인 로컬 비용 정책이 필요합니다.")
	if kind == "elemental_smith" and int(cost.material_amount) != 1:
		return _error("속성 세공은 원문 규칙대로 주문서 한 장을 사용합니다.")
	if int(cost.gold_cost) < 0 or int(cost.material_amount) < 1:
		return _error("비용 정책이 올바르지 않습니다.")
	var q: Dictionary
	match kind:
		"elemental_smith":
			q = _elemental(pack, target, material, target_raw)
		"bless_reinforcement":
			q = _bless(pack, target, material, target_raw, material_raw, policy)
		"smelt", "spirit_smelt":
			q = _smelt(pack, target, material, kind, policy)
		_:
			return _error("지원하지 않는 세공 작업입니다.")
	if not bool(q.get("ok", false)):
		return q
	q["kind"] = kind
	q["source_id"] = source_id
	q["material_source_id"] = material_id
	q["material_bless_code"] = int(material.get("bless_code", 1))
	q["target_id"] = str(action.get("target_id", target.get("instance_id", "")))
	q["costs"] = [{"source_id": material_id, "amount": int(cost.material_amount)}]
	q["gold_cost"] = int(cost.gold_cost)
	q["source_sha256"] = str(pack.get("source_sha256", ""))
	q["cost_policy"] = cost.duplicate(true)
	q["detail"] = "기존 효과 전체를 초기화하고 슬롯별로 다시 추첨합니다. 비용은 명시된 로컬 정책입니다."
	if kind == "spirit_smelt":
		var expiry: Dictionary = _installed_expiry(pack, material_id, context, policy)
		if not bool(expiry.get("ok", false)):
			return expiry
		q["expires_unix"] = int(expiry.get("expires_unix", 0))
		q["expiry_provenance"] = expiry.get("raw", [])
	return q

static func _elemental(pack: Dictionary, target: Dictionary, material: Dictionary, raw: Dictionary) -> Dictionary:
	var material_id: int = int(material.source_id)
	if _value(pack, material_id, "ScrollElementalSmith", 0) != 1:
		return _error("속성 세공 주문서가 아닙니다.")
	var element: int = int(target.get("element_type", 0))
	var level: int = int(target.get("element_level", 0))
	if level < 3 or element < 1 or element > 4:
		return _error("3단 이상 속성 강화된 무기가 필요합니다.")
	if _value(pack, material_id, "ScrollElementalType", 0) != element:
		return _error("무기 속성과 주문서 속성이 다릅니다.")
	var group: int = _value(pack, int(target.source_id), "EnchantEquipGroupID", 0)
	for row in Common.rows(pack, "ElementalSmithAbleLevel"):
		if int(row.get("ItemEnchantEquipGroupID", 0)) == group and level < int(row.get("AbleElementalLevel", 3)):
			return _error("이 무기의 속성 세공 조건을 충족하지 않습니다.")
	var entry: Dictionary = _match_equipment(pack, "ElementalSmith", target, raw, false)
	if entry.is_empty():
		return _error("속성 세공 대상 무기가 아닙니다.")
	var slots: Array = []
	for row in Common.rows(pack, "ElementalSmithProbability"):
		if int(row.get("ElementalSmithID", 0)) != int(entry.ID) or int(row.get("ItemBlessCodeID", 0)) != int(material.get("bless_code", 1)):
			continue
		var pool: Array = []
		for candidate in Common.rows(pack, "ElementalSmithBonus"):
			if int(candidate.get("ElementalSmithProbGroupID", 0)) == int(row.ElementalSmithProbGroupID) and int(candidate.get("ElementalTypeID", 0)) in [0, element]:
				pool.append(candidate)
		var check: Dictionary = _pool_check(pack, pool, "Probability")
		if not check.ok:
			return check
		slots.append({"slot": int(row.SlotNumber), "pool": pool, "weight": "Probability", "raw": row})
	if slots.size() != 2:
		return _error("두 속성 세공 슬롯의 원문 확률이 없습니다.")
	return {"ok": true, "slots": slots, "element_type": element, "element_level": level, "raw": entry}

static func _bless(pack: Dictionary, target: Dictionary, material: Dictionary, raw: Dictionary, material_raw: Dictionary, policy: Dictionary) -> Dictionary:
	if int(target.get("bless_code", 0)) != 2:
		return _error("축복된 장비만 축복 세공할 수 있습니다.")
	if int(material_raw.get("CategoryID", 0)) != 151 or _value(pack, int(material.source_id), "GuaranteeBlessProb", 0) != 0:
		return _error("일반 축복 부여 주문서가 필요합니다. 장인의 주문서는 사용할 수 없습니다.")
	# Prob2 is zero throughout patch 523; its meaning is not guessed.
	if str(policy.get("bless_probability_column", "")) != "Prob1":
		return _error("축복 확률 열이 미확정입니다. Prob1 사용 정책을 명시하세요.")
	var entry: Dictionary = _match_equipment(pack, "ItemBlessReinforcement", target, raw, true)
	if entry.is_empty() or bool(entry.get("IsTest", false)):
		return _error("원문 축복 세공 대상 장비가 아닙니다.")
	# A probability parent row alone does not enable this equipment. Match the
	# separate grade configuration exactly before looking at its slot pools.
	var grade_configured: bool = false
	for row in Common.rows(pack, "ItemBlessReinforcementGrade"):
		if int(row.get("EquipSlotID", 0)) == int(entry.EquipSlotID) and int(row.get("WeaponTypeID", 0)) == int(entry.WeaponTypeID) and int(row.get("GradeID", 0)) == int(raw.get("GradeID", 0)):
			grade_configured = true
			break
	if not grade_configured:
		return _error("이 장비의 부위·무기 종류·등급에 맞는 축복 세공 등급 설정이 없습니다.")
	var slot_amount: int = 0
	for row in Common.rows(pack, "ItemBlessReinforcementSlotAmount"):
		if int(row.get("EquipSlotID", 0)) == int(entry.EquipSlotID) and int(row.get("GradeID", 0)) == int(raw.get("GradeID", 0)):
			slot_amount = int(row.SlotAmount)
	var slots: Array = []
	for number in range(1, slot_amount + 1):
		var pool: Array = []
		for row in Common.rows(pack, "ItemBlessReinforcementBonus"):
			if int(row.get("ItemBlessReinforcementID", 0)) == int(entry.ID) and int(row.get("SlotNumber", 0)) == number:
				pool.append(row)
		var check: Dictionary = _pool_check(pack, pool, "Prob1")
		if not check.ok:
			return check
		slots.append({"slot": number, "pool": pool, "weight": "Prob1"})
	if slots.is_empty():
		return _error("축복 세공 슬롯 정보가 없습니다.")
	return {"ok": true, "slots": slots, "raw": entry, "probability_policy": "Prob1"}

static func _smelt(pack: Dictionary, target: Dictionary, material: Dictionary, kind: String, policy: Dictionary) -> Dictionary:
	var pool_id: int = 0
	var entity: Dictionary = {}
	var spirit: bool = kind == "spirit_smelt"
	if spirit:
		pool_id = _value(pack, int(material.source_id), "SpiritSmelt", 0)
		if pool_id == 0:
			return _error("정령 제련 코어가 아닙니다.")
		var zero_policy: String = str(policy.get("spirit_bless_zero", "exact"))
		if zero_policy not in ["exact", "wildcard"]:
			return _error("BlessCode 0 해석 정책이 올바르지 않습니다.")
		for row in Common.rows(pack, "ItemSpiritSmeltEntity"):
			if int(row.get("ItemClassID", 0)) != int(target.source_id) or int(row.get("ItemSmeltID", 0)) != pool_id:
				continue
			var bless: int = int(row.get("BlessCode", 0))
			if bless == int(target.get("bless_code", 1)) or (bless == 0 and zero_policy == "wildcard"):
				entity = row
	else:
		if int(material.source_id) != 289162:
			return _error("일반 제련에는 생명의 돌(289162)이 필요합니다.")
		for row in Common.rows(pack, "ItemSmeltEntity"):
			if int(row.get("ItemClassID", 0)) == int(target.source_id):
				entity = row
				pool_id = int(row.get("ItemSmeltID", 0))
	if entity.is_empty():
		return _error("선택한 장비·축복 코드에 맞는 원문 제련 대상이 없습니다.")
	var smelt: Dictionary = Common.find(pack, "ItemSmelt", pool_id)
	if smelt.is_empty():
		return _error("제련 풀 정보가 없습니다.")
	var slots: Array = []
	for number in range(1, int(smelt.get("SlotAmount", 0)) + 1):
		var active: bool = not spirit
		var gate: Dictionary = {}
		if spirit:
			for row in Common.rows(pack, "ItemSmeltSlotActive"):
				if int(row.get("ItemSmeltID", 0)) == pool_id and int(row.get("SlotNumber", 0)) == number:
					gate = row
					var level: int = int(target.get("level", 0))
					active = level >= int(row.MinEnchant) and level <= int(row.MaxEnchant)
		if not active:
			continue
		var pool: Array = []
		for row in Common.rows(pack, "ItemSmeltBonus"):
			if int(row.get("ItemSmeltID", 0)) == pool_id and int(row.get("SlotNumber", 0)) == number:
				pool.append(row)
		var check: Dictionary = _pool_check(pack, pool, "Prob")
		if not check.ok:
			return check
		slots.append({"slot": number, "pool": pool, "weight": "Prob", "raw": gate})
	if slots.is_empty():
		return _error("현재 강화 수치에서 활성화된 제련 슬롯이 없습니다.")
	return {"ok": true, "slots": slots, "pool_id": pool_id, "raw": entity, "bless_zero_policy": str(policy.get("spirit_bless_zero", "exact"))}

static func roll(pack: Dictionary, q: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not bool(q.get("ok", false)):
		return _error(str(q.get("error", "실행할 수 없는 견적입니다.")))
	var selected: Array = []
	var bonus_ids: Array = []
	for slot in q.get("slots", []):
		var chosen: Dictionary = Common.weighted(slot.pool, str(slot.weight), rng)
		if chosen.is_empty():
			return _error("원문 확률 추첨에 실패했습니다.")
		var bonus_id: int = int(chosen.get("BonusID", 0))
		var info: Dictionary = Common.bonus(pack, bonus_id)
		if str(info.get("name", "")) != "None" and not bool(info.get("supported", false)):
			return _error("선택된 효과를 실제 전투에 적용할 수 없습니다.")
		bonus_ids.append(bonus_id)
		selected.append({"slot": int(slot.slot), "bonus_id": bonus_id, "empty": str(info.get("name", "")) == "None", "raw": chosen.duplicate(true)})
	var effect_state: Dictionary = {"bonus_ids": bonus_ids, "slots": selected, "source_sha256": str(q.get("source_sha256", "")), "raw": q.get("raw", {}).duplicate(true), "cost_policy": q.get("cost_policy", {}).duplicate(true)}
	for key in ["source_id", "target_id", "material_source_id", "material_bless_code", "pool_id", "element_type", "element_level", "expires_unix", "expiry_provenance", "bless_zero_policy", "probability_policy"]:
		if q.has(key):
			effect_state[key] = q[key]
	var state: Dictionary = {}
	state[str(q.kind)] = effect_state
	return {"ok": true, "state": state, "detail": "슬롯별 효과를 새로 부여했습니다.", "effects": Common.effect_records(pack, bonus_ids)}

# Saved rows are evidence, never authoritative numeric records. Rebuild the
# current domain quote from source selectors, then accept only exact source rows.
# Old states without material/physical identity stay saved but produce no effects.
# A temporal installation also requires its current explicit expiry policy.
static func active_effects(pack: Dictionary, target: Dictionary, kind: String, state: Dictionary, now: int, policy: Dictionary = {}) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	var stored_value: Variant = state.get(kind, {})
	if not stored_value is Dictionary or target.is_empty():
		return none
	var stored: Dictionary = stored_value
	if str(stored.get("source_sha256", "")) != str(pack.get("source_sha256", "")) or str(pack.get("source_sha256", "")).is_empty():
		return none
	if int(stored.get("source_id", 0)) != int(target.get("source_id", 0)) or str(stored.get("target_id", "")).is_empty() or str(stored.get("target_id", "")) != str(target.get("instance_id", "")):
		return none
	var source_id: int = int(target.get("source_id", 0))
	var material_id: int = int(stored.get("material_source_id", 0))
	var raw: Dictionary = Common.item(pack, source_id).get("raw", {})
	var material_raw: Dictionary = Common.item(pack, material_id).get("raw", {})
	if raw.is_empty() or material_raw.is_empty():
		return none
	var material: Dictionary = {"source_id": material_id, "bless_code": int(stored.get("material_bless_code", 0))}
	var current_policy: Dictionary = policy.duplicate(true)
	if not current_policy.has("bless_probability_column"):
		current_policy["bless_probability_column"] = str(stored.get("probability_policy", ""))
	var current: Dictionary = {}
	match kind:
		"elemental_smith":
			if int(stored.get("element_type", 0)) != int(target.get("element_type", 0)):
				return none
			current = _elemental(pack, target, material, raw)
		"bless_reinforcement":
			current = _bless(pack, target, material, raw, material_raw, current_policy)
		"smelt", "spirit_smelt":
			current = _smelt(pack, target, material, kind, current_policy)
		_:
			return none
	if not bool(current.get("ok", false)) or current.get("raw", {}) != stored.get("raw", {}):
		return none
	if kind in ["smelt", "spirit_smelt"] and int(current.get("pool_id", 0)) != int(stored.get("pool_id", 0)):
		return none
	if kind == "spirit_smelt":
		var expiry: Dictionary = _installed_expiry(pack, material_id, {"now_unix": now}, current_policy)
		if not bool(expiry.get("ok", false)) or int(expiry.get("expires_unix", 0)) != int(stored.get("expires_unix", -1)) or expiry.get("raw", []) != stored.get("expiry_provenance", []):
			return none
	var slots_value: Variant = stored.get("slots", [])
	if not slots_value is Array or slots_value.is_empty():
		return none
	var seen: Dictionary = {}
	var identities: Array = []
	var active_ids: Array = []
	for value: Variant in slots_value:
		if not value is Dictionary:
			return none
		var slot: Dictionary = value
		var number: int = int(slot.get("slot", 0))
		if number < 1 or seen.has(number):
			return none
		seen[number] = true
		var saved_raw: Variant = slot.get("raw", {})
		if not saved_raw is Dictionary:
			return none
		var table: String = "ElementalSmithBonus" if kind == "elemental_smith" else "ItemBlessReinforcementBonus" if kind == "bless_reinforcement" else "ItemSmeltBonus"
		var authoritative: Dictionary = Common.find(pack, table, int(saved_raw.get("ID", 0)))
		var bonus_id: int = int(slot.get("bonus_id", 0))
		if authoritative.is_empty() or authoritative != saved_raw or int(authoritative.get("BonusID", 0)) != bonus_id:
			return none
		identities.append(bonus_id)
		var matched: bool = false
		for active: Dictionary in current.get("slots", []):
			if int(active.get("slot", 0)) != number:
				continue
			for candidate: Dictionary in active.get("pool", []):
				if candidate == authoritative and int(candidate.get(str(active.get("weight", "")), 0)) > 0:
					matched = true
		if matched:
			active_ids.append(bonus_id)
		elif kind == "spirit_smelt":
			# A downgrade can close a previously installed slot. Keep its saved
			# row, but only if it still belongs to this exact source pool/slot.
			if int(authoritative.get("ItemSmeltID", 0)) != int(current.get("pool_id", 0)) or int(authoritative.get("SlotNumber", 0)) != number:
				return none
			var gate_found: bool = false
			for gate: Dictionary in Common.rows(pack, "ItemSmeltSlotActive"):
				if int(gate.get("ItemSmeltID", 0)) == int(current.get("pool_id", 0)) and int(gate.get("SlotNumber", 0)) == number:
					gate_found = true
			if not gate_found:
				return none
		else:
			return none
	# JSON numbers reload as floats. Array/Dictionary equality is type-strict,
	# although an individual integral float compares exactly to its integer ID.
	# Preserve list shape, order and every authoritative ID; reject strings,
	# booleans, fractions and mismatches rather than coercing/truncating them.
	var saved_ids: Variant = stored.get("bonus_ids", [])
	if not saved_ids is Array or saved_ids.size() != identities.size():
		return none
	for index: int in range(identities.size()):
		if typeof(saved_ids[index]) not in [TYPE_INT, TYPE_FLOAT] or saved_ids[index] != identities[index]:
			return none
	return Common.effect_records(pack, active_ids)

static func _pool_check(pack: Dictionary, pool: Array, weight: String) -> Dictionary:
	var total: int = 0
	for row in pool:
		var chance: int = int(row.get(weight, 0))
		if chance < 0:
			return _error("음수 원문 확률이 발견되었습니다.")
		total += chance
		if chance == 0:
			continue
		var info: Dictionary = Common.bonus(pack, int(row.get("BonusID", 0)))
		if info.is_empty() or (str(info.get("name", "")) != "None" and not bool(info.get("supported", false))):
			return _error("이 풀에는 실제 적용이 지원되지 않는 효과가 있습니다: %s" % str(info.get("name", row.get("BonusID", 0))))
	if total != PROBABILITY_SCALE:
		return _error("원문 확률 합계가 10,000,000과 다릅니다(%d). 임의 정규화하지 않습니다." % total)
	return {"ok": true}

static func _match_equipment(pack: Dictionary, table: String, target: Dictionary, raw: Dictionary, needs_slot: bool) -> Dictionary:
	var weapon_type: int = _value(pack, int(target.source_id), "WeaponType", 0)
	var equip_slots: Array = []
	for slot in Common.rows(pack, "ItemEquipSlot"):
		if int(slot.get("ItemClassID", 0)) == int(target.source_id):
			equip_slots.append(int(slot.get("EquipSlotID", 0)))
	for row in Common.rows(pack, table):
		if int(row.get("WeaponTypeID", 0)) != weapon_type or int(row.get("GradeID", 0)) != int(raw.get("GradeID", 0)):
			continue
		if needs_slot and int(row.get("EquipSlotID", 0)) not in equip_slots:
			continue
		return row
	return {}

static func _item_bonus_rows(pack: Dictionary, source_id: int) -> Array:
	var out: Array = []
	for row in Common.rows(pack, "ItemBonus"):
		if int(row.get("ItemClassID", 0)) == source_id:
			var info: Dictionary = Common.bonus(pack, int(row.get("BonusID", 0)))
			if not info.is_empty():
				out.append(info)
	return out

static func _value(pack: Dictionary, source_id: int, name: String, fallback: int) -> int:
	for info in _item_bonus_rows(pack, source_id):
		if str(info.get("name", "")) == name:
			return int(info.get("raw", {}).get("Value", fallback))
	return fallback

static func _installed_expiry(pack: Dictionary, source_id: int, context: Dictionary, policy: Dictionary) -> Dictionary:
	var provenance: Array = []
	var expiry: int = 0
	for info in _item_bonus_rows(pack, source_id):
		if str(info.get("name", "")) != "SmeltExpireDate":
			continue
		var raw: Dictionary = info.get("raw", {})
		provenance.append(raw)
		# Date-shaped Time values and schedule references use separate source keys.
		var overrides: Dictionary = policy.get("smelt_expiry_unix", {})
		var key: String = ""
		if int(raw.get("BonusApplicationTypeID", 0)) == 0 and int(raw.get("BonusApplicationTargetID", 0)) == 0 and int(raw.get("Value", 0)) > 0:
			key = str(int(raw.Value))
		elif int(raw.get("BonusApplicationTypeID", 0)) == 298 and int(raw.get("Value", 0)) == 0 and int(raw.get("BonusApplicationTargetID", 0)) > 0:
			key = str(int(raw.BonusApplicationTargetID))
		else:
			return _error("설치 효과 만료 원문 형식을 해석할 수 없습니다.")
		if not overrides.has(key):
			return _error("설치 효과 만료 일정의 명시적 타임스탬프가 필요합니다.")
		expiry = int(overrides[key])
		if expiry <= int(context.get("now_unix", 0)):
			return _error("설치 효과가 이미 만료되었습니다.")
	return {"ok": true, "expires_unix": expiry, "raw": provenance}

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
