extends RefCounted
## World bridge. Quotes are read-only; transactions persist staged copies first.
const Common = preload("res://scripts/equipment523/common.gd")
const SmithSmelt = preload("res://scripts/equipment523/smith_smelt.gd")
const Alchemy = preload("res://scripts/equipment523/alchemy.gd")
const SetInvoke = preload("res://scripts/equipment523/set_invoke.gd")
const PackStore = preload("res://scripts/equipment523/pack_store.gd")
const POLICY_PATH: String = "res://data/equipment523/policy.json"
var store = PackStore.new()
var policy: Dictionary = {}
var pending: Dictionary = {}
var save_blocked: bool = false
var problem: String = ""
var _busy: bool = false
var next_expiry_unix: int = 0

func startup(_world: Node) -> Dictionary:
	pending.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH)) if FileAccess.file_exists(POLICY_PATH) else {}
	policy = parsed if parsed is Dictionary else {}
	return store.startup()

func after_load(world: Node) -> void:
	# The caller invokes this only after a successful save reload.
	pending.clear()
	save_blocked = false
	problem = ""
	next_expiry_unix = 0
	if world.has_method("_invalidate_equipment_static"): world.call("_invalidate_equipment_static")

func tick(world: Node, _delta: float) -> void:
	if next_expiry_unix > 0 and _now() >= next_expiry_unix:
		next_expiry_unix = 0
		if world.has_method("_invalidate_equipment_static"): world.call("_invalidate_equipment_static")

func install(world: Node, path: String, sha: String) -> Dictionary:
	if _busy or save_blocked: return Common.fail("저장 상태 확인 후 규칙 팩을 변경하세요.")
	var result: Dictionary = store.install(path,sha)
	if result.get("ok",false):
		pending.clear()
		if world.has_method("_invalidate_equipment_static"): world.call("_invalidate_equipment_static")
	return result

func snapshot(world: Node) -> Dictionary:
	var entries: Array = _entries(world)
	var active: Array = _equipped(world)
	var sets: Dictionary = SetInvoke.equipped(store.pack,active,policy,_now()) if not store.pack.is_empty() else {"details":[]}
	var state_exists: bool = false
	var receipt_count: int = 0
	for value: Variant in world.item_instances.values():
		if value is Dictionary and value.has("equipment523"): state_exists = true
		if value is Dictionary and value.has("quest_reward_receipt"): receipt_count += 1
	var status: String = problem if not problem.is_empty() else store.status
	if store.pack.is_empty() and state_exists: status += " · 저장된 가공 기록은 보존하며 팩이 없으면 효과를 적용하지 않습니다."
	if receipt_count > 0: status += " · 원본 퀘스트 보상 %d개는 사용 영수증 연결 전 재료로 소비할 수 없습니다." % receipt_count
	var unproven: int = 0
	for info: Dictionary in entries:
		for kind: String in ["elemental_smith","bless_reinforcement","smelt","spirit_smelt"]:
			var effect: Variant = info.get("state",{}).get(kind,{})
			if effect is Dictionary and not effect.is_empty() and (not effect.has("material_source_id") or str(effect.get("target_id","")) != str(info.instance_id)): unproven += 1
		var invoke: Variant = info.get("state",{}).get("invoke_replacement",{})
		if invoke is Dictionary and not invoke.is_empty() and (not SetInvoke.valid_state(invoke) or str(invoke.get("target_id","")) != str(info.instance_id)): unproven += 1
	if unproven > 0: status += " · 추적 근거가 불완전한 이전 가공 기록 %d건은 보존하며 효과를 보류합니다." % unproven
	return {"pack_ready":not store.pack.is_empty() and not save_blocked,"pack_sha256":store.sha256,"status":status,
		"targets":entries,"policy_notes":str(policy.get("notes","")),"set_details":sets.get("details",[]),"invoke_slots":[]}

func quote(world: Node, action: Dictionary) -> Dictionary:
	var value: Dictionary = _quote(world,action)
	if value.get("ok",false):
		pending = {"action":action.duplicate(true),"fingerprint":_fingerprint(world),"quote":value.duplicate(true)}
	else: pending.clear()
	return value.duplicate(true)

func _quote(world: Node, action: Dictionary) -> Dictionary:
	if _busy or save_blocked: return Common.fail(problem if not problem.is_empty() else "가공 거래가 진행 중입니다.")
	var blocked: String = _host_blocker(world)
	if not blocked.is_empty(): return Common.fail(blocked)
	if store.pack.is_empty(): return Common.fail("검증된 523 규칙 팩을 먼저 설치하세요.")
	var kind: String = str(action.get("kind",""))
	if kind not in ["elemental_smith","bless_reinforcement","smelt","spirit_smelt","alchemy","invoke_replacement"]: return Common.fail("지원하지 않는 가공 작업입니다.")
	var by_id: Dictionary = {}
	for info: Dictionary in _entries(world): by_id[str(info.instance_id)] = info
	var target_id: String = str(action.get("target_id",""))
	var target: Dictionary = by_id.get(target_id,{})
	if kind != "alchemy" and (target.is_empty() or bool(target.get("virtual_stack",false))): return Common.fail("원본 ID가 확인된 실제 장비를 선택하세요.")
	if kind != "alchemy" and bool(target.get("record",{}).get("source_original_item",false)):
		return Common.fail("이 원본 장비는 아직 카탈로그에 등록되지 않았습니다. 실제 장착 경로가 준비될 때까지 재료를 보존합니다.")
	if not target.is_empty() and bool(target.get("locked",false)): return Common.fail("대상 장비의 잠금을 해제하세요.")
	if kind in ["smelt","spirit_smelt"] and not target_id.is_empty():
		var legacy: Variant = world.item_instances.get(target_id,{}).get("source_smelt",{})
		if not legacy is Dictionary or not legacy.is_empty() and legacy.get("origin") != "equipment523": return Common.fail("기존 미확인 제련 기록을 보호합니다. 원본 기록을 확인하세요.")
	var materials: Array = []
	var chosen: Dictionary = {}
	for raw_id: Variant in action.get("material_ids",[]):
		var id: String = str(raw_id)
		if id == target_id or chosen.has(id) or not by_id.has(id): return Common.fail("대상과 재료가 같거나 선택한 개체가 중복·누락되었습니다.")
		var info: Dictionary = by_id[id]
		if bool(info.get("quest_reward_receipt",false)): return Common.fail("원본 퀘스트 보상은 사용 영수증 연결 전 재료로 소비할 수 없습니다. 지급 기록과 잔여 수량을 보존합니다.")
		if bool(info.get("locked",false)) or bool(info.get("equipped",false)): return Common.fail("재료의 장착과 잠금을 해제하세요.")
		if kind == "alchemy" and bool(info.get("virtual_stack",false)): return Common.fail("연금 재료는 원본 ID가 확인된 실제 개체를 선택하세요.")
		var expiry: String = _expiry_error(info)
		if not expiry.is_empty(): return Common.fail(expiry)
		chosen[id] = true
		materials.append(info)
	var context: Dictionary = {"target":target,"materials":materials,"policy":policy,"now_unix":_now(),"player_level":int(world.level),"invoke_slot":int(action.get("slot",0))}
	var q: Dictionary
	if kind == "alchemy": q = Alchemy.quote(store.pack,action,context)
	elif kind == "invoke_replacement": q = SetInvoke.quote(store.pack,kind,context)
	else: q = SmithSmelt.quote(store.pack,action,context)
	if not q.get("ok",false): return q
	var gold_cost: int = int(q.get("gold_cost",0))
	if gold_cost < 0 or int(world.gold) < gold_cost: return Common.fail("아데나가 부족합니다.")
	var spent: Dictionary = {}
	for cost: Dictionary in q.get("costs",[]):
		var source_id: int = int(cost.get("source_id",0))
		var amount: int = int(cost.get("amount",0))
		if source_id <= 0 or amount <= 0: return Common.fail("재료 소모 계약이 잘못되었습니다.")
		var candidates: Array = []
		for info: Dictionary in materials:
			if int(info.source_id) == source_id: candidates.append(info)
		if candidates.size() != 1 or int(candidates[0].quantity) < amount: return Common.fail("명시적으로 선택한 재료의 수량이 부족합니다.")
		var physical: String = str(candidates[0].instance_id)
		spent[physical] = int(spent.get(physical,0)) + amount
		if int(spent[physical]) > int(candidates[0].quantity): return Common.fail("같은 재료 수량을 중복 소모할 수 없습니다.")
	for raw_id: Variant in q.get("consume_instance_ids",[]):
		var id: String = str(raw_id)
		if not chosen.has(id) or spent.has(id): return Common.fail("연금 재료 소모 대상이 일치하지 않습니다.")
		spent[id] = 1
	if kind != "alchemy" and materials.size() != spent.size(): return Common.fail("소모 계약과 선택한 재료가 일치하지 않습니다.")
	var output_records: Dictionary = {}
	if kind == "alchemy":
		var registered_outputs: Dictionary = _output_catalog(world)
		for result_id: Variant in q.get("alchemy",{}).get("result_ids",[]):
			var result: Dictionary = Common.find(store.pack,"AlchemyResult",int(result_id))
			var source: int = int(result.get("ItemClassID",0))
			if output_records.has(str(source)): continue
			var registered: Dictionary = _output_record(world,source,registered_outputs)
			if registered.is_empty(): return Common.fail("연금 결과의 원본 식별 정보가 없습니다. 재료를 보존합니다.")
			output_records[str(source)] = registered
		var unregistered: int = 0
		for registered: Dictionary in output_records.values():
			if registered.get("source_original_item",false): unregistered += 1
		if unregistered > 0: q["detail"] = str(q.get("detail","")) + " · 미등록 원본 결과 %d종은 정확한 원본 보상 기록으로 보관하며 실제 장비 효과는 카탈로그 등록 후 적용합니다." % unregistered
	q["_materials"] = materials.duplicate(true)
	q["_spend"] = spent
	q["_target_info"] = target.duplicate(true)
	q["_output_records"] = output_records
	return q

func commit(world: Node, action: Dictionary) -> Dictionary:
	if pending.is_empty() or pending.get("action") != action: return Common.fail("현재 선택에 대한 비용을 다시 확인하세요.")
	if pending.get("fingerprint") != _fingerprint(world):
		pending.clear()
		return Common.fail("보유 상태나 설정이 변경되었습니다. 비용을 다시 확인하세요.")
	var q: Dictionary = _quote(world,action)
	if not q.get("ok",false):
		pending.clear()
		return q
	_busy = true
	pending.clear()
	var candidate_rng := RandomNumberGenerator.new()
	candidate_rng.state = world.rng.state
	var outcome: Dictionary
	if q.get("kind") == "alchemy": outcome = Alchemy.roll(store.pack,q,candidate_rng)
	elif q.get("kind") == "invoke_replacement": outcome = SetInvoke.roll(store.pack,q,candidate_rng)
	else: outcome = SmithSmelt.roll(store.pack,q,candidate_rng)
	if not outcome.get("ok",false):
		_busy = false
		return outcome
	var inventory: Dictionary = world.inventory.duplicate(true)
	var physical: Dictionary = world.item_instances.duplicate(true)
	var next_id: int = maxi(1,int(world.next_item_instance_id))
	for info: Dictionary in q.get("_materials",[]):
		var amount: int = int(q.get("_spend",{}).get(str(info.instance_id),0))
		if amount <= 0: continue
		var error: String = _consume(inventory,physical,info,amount)
		if not error.is_empty():
			_busy = false
			return Common.fail(error)
	var target_id: String = str(q.get("target_id",""))
	if not target_id.is_empty():
		if not physical.has(target_id) or not physical[target_id].get("equipment523",{}) is Dictionary:
			_busy = false
			return Common.fail("대상 장비 상태가 변경되었습니다.")
		var previous: Dictionary = physical[target_id].get("equipment523",{}).duplicate(true)
		previous.merge(outcome.get("state",{}).duplicate(true),true)
		physical[target_id]["equipment523"] = previous
		# Main's legacy crafting service protects pinned records from being used
		# as pristine +0 ingredients. Preserve that guard for previously name-only
		# equipment as soon as it acquires a per-instance processing state.
		if physical[target_id].get("record",{}).is_empty(): physical[target_id]["record"] = q.get("_target_info",{}).get("record",{}).duplicate(true)
		if q.get("kind") in ["smelt","spirit_smelt"]:
			var legacy: Variant = physical[target_id].get("source_smelt",{})
			if not legacy is Dictionary or (not legacy.is_empty() and legacy.get("origin") != "equipment523"):
				_busy = false
				return Common.fail("기존 미확인 제련 기록을 보호합니다. 해당 장비의 원본 기록을 확인하세요.")
			physical[target_id]["source_smelt"] = {"origin":"equipment523","kind":str(q.kind),"source_sha256":str(store.pack.get("source_sha256",""))}
	if outcome.has("output"):
		var output: Dictionary = outcome.output
		var record: Dictionary = q.get("_output_records",{}).get(str(output.get("source_id","")),{})
		if record.is_empty():
			_busy = false
			return Common.fail("결과 아이템의 등록 정체를 확인할 수 없습니다.")
		var amount: int = int(output.get("amount",0))
		if amount < 1 or amount > 10000:
			_busy = false
			return Common.fail("결과 아이템 수량이 저장 범위를 벗어납니다.")
		var item_name: String = str(record.get("name",""))
		if record.get("source_original_item",false):
			record["source_bless_code_id"] = int(output.get("bless_code",1))
			record["source_reward_id"] = int(outcome.get("result_id",0))
			record["source_reward_quantity"] = amount
			outcome["detail"] = str(outcome.get("detail","")) + " · 미등록 원본 아이템: 실제 장비 효과는 카탈로그 등록 후 적용합니다."
		inventory[item_name] = int(inventory.get(item_name,0)) + amount
		var separate: bool = _is_equipment(world,record)
		for _index: int in range(amount if separate else 1):
			while physical.has(str(next_id)): next_id += 1
			var instance: Dictionary = {"name":item_name,"level":int(output.get("level",0)),"element":"","element_level":0,
				"source_bless_code":int(output.get("bless_code",1)),"bless_state":"blessed" if int(output.get("bless_code",1)) == 2 else "normal",
				"record":record.duplicate(true)}
			instance.record["bless_state"] = instance.bless_state
			instance.record["blessed"] = int(output.get("bless_code",1)) == 2
			if instance.record.has("source_bless_raw"): instance.record["source_bless_raw"] = int(output.get("bless_code",1))
			if not separate and (amount > 1 or record.get("source_original_item",false)): instance["source_reward_quantity"] = amount
			physical[str(next_id)] = instance
			next_id += 1
	if _weight(world,inventory) > int(world.call("_carrying_capacity")):
		_busy = false
		return Common.fail("결과 아이템을 받을 무게 여유가 부족합니다. 재료는 보존됩니다.")
	var staged: Dictionary = {"inventory":inventory,"item_instances":physical,"gold":int(world.gold)-int(q.gold_cost),"next_item_instance_id":next_id}
	var saved: Error = world.call("_save_game",true,staged)
	if saved != OK:
		if _saved_candidate(world,staged):
			save_blocked = true
			problem = "가공 저장 후보는 기록되었지만 활성화가 확정되지 않았습니다. 저장을 다시 불러오세요."
		_busy = false
		return Common.fail(problem if save_blocked else "가공 결과를 저장하지 못했습니다. 보유 상태와 난수는 변경하지 않았습니다.")
	world.inventory = inventory
	world.item_instances = physical
	world.gold = int(staged.gold)
	world.next_item_instance_id = next_id
	world.rng.state = candidate_rng.state
	if world.has_method("_invalidate_equipment_static"): world.call("_invalidate_equipment_static")
	if world.has_method("_refresh_speed_modifiers"): world.call("_refresh_speed_modifiers")
	_busy = false
	return outcome

func records(world: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	next_expiry_unix = 0
	if store.pack.is_empty() or save_blocked: return out
	var targets: Array = _equipped(world)
	for info: Dictionary in targets:
		var state: Dictionary = info.get("state",{})
		for kind: String in ["elemental_smith","bless_reinforcement","smelt","spirit_smelt"]:
			var effect: Variant = state.get(kind,{})
			if not effect is Dictionary or effect.get("source_sha256") != store.pack.get("source_sha256"): continue
			var active: Array[Dictionary] = SmithSmelt.active_effects(store.pack,info,kind,state,_now(),policy)
			if active.is_empty(): continue
			var expires: int = int(effect.get("expires_unix",0))
			if expires > 0:
				if expires <= _now(): continue
				if next_expiry_unix == 0 or expires < next_expiry_unix: next_expiry_unix = expires
			out.append_array(active)
	out.append_array(SetInvoke.equipped(store.pack,targets,policy,_now()).get("records",[]))
	return out

func on_hit(world: Node, target: Node, attack_kind: String = "melee", main_target: bool = true, by_spell: bool = false) -> Array:
	if store.pack.is_empty() or save_blocked: return []
	return SetInvoke.on_hit(store.pack,world,_equipped(world),policy,target,attack_kind,main_target,by_spell)

func _source(record: Dictionary) -> int:
	var host_id: String = str(record.get("sourceId",""))
	var name: String = str(record.get("name",""))
	var original: Variant = record.get("source_original_item",false)
	# PR262's older held rewards use a complete ItemClass row and a distinct
	# exact prefix. Compare every source field retained by the rules compiler.
	if original is Dictionary:
		var original_id: int = int(record.get("source_item_class_id",0))
		var source_item: Dictionary = Common.item(store.pack,original_id)
		var raw: Dictionary = source_item.get("raw",{})
		if original_id <= 0 or raw.is_empty() or int(original.get("ID",0)) != original_id: return 0
		if record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or host_id != "m523:item:" + str(original_id): return 0
		if str(original.get("Name","")) == "" or name != "[원본 보상] " + str(original.Name): return 0
		for key: Variant in raw:
			if not original.has(key) or original[key] != raw[key]: return 0
		return original_id
	var binding: Variant = store.pack.get("bindings",{}).get(host_id,{})
	if binding is Dictionary and not binding.is_empty() and binding.get("name") == name: return int(binding.get("source_id",0))
	var id: int = int(record.get("source_item_class_id",0))
	var item: Dictionary = Common.item(store.pack,id)
	if id <= 0 or item.is_empty() or host_id != "m523:item:" + str(id): return 0
	var expected: String = name
	if record.get("source_original_item",false) == true and expected.begins_with("[원본보상]"): expected = expected.trim_prefix("[원본보상]").strip_edges()
	if expected not in item.get("names",[]): return 0
	if not bool(record.get("source_original_item",false)) and not host_id.begins_with("m523:item:"): return 0
	return id

func _info(world: Node, id: String, physical: Dictionary, fallback: Dictionary = {}) -> Dictionary:
	var name: String = str(physical.get("name",""))
	var record: Variant = physical.get("record",{})
	if not record is Dictionary: return {}
	if record.is_empty(): record = fallback
	if record.is_empty() and world.has_method("_find_catalog_item_record"): record = world.call("_find_catalog_item_record",name)
	if not record is Dictionary or record.is_empty() or record.get("name") != name: return {}
	if physical.has("sourceId") and str(physical.sourceId) != str(record.get("sourceId","")): return {}
	var source: int = _source(record)
	if source <= 0 or bool(Common.item(store.pack,source).get("raw",{}).get("TestItem",false)): return {}
	var quantity: int = _quantity(physical)
	if quantity <= 0 or int(world.inventory.get(name,0)) < quantity: return {}
	var state: Variant = physical.get("equipment523",{})
	if not state is Dictionary: return {}
	# Main's ordinary blessing action updates host flags. A historical raw source
	# code must not hide that action or keep a removed host blessing active.
	var blessed: bool = bool(physical.get("blessed",false)) or bool(record.get("blessed",false))
	blessed = blessed or str(physical.get("bless_state","")).to_lower() in ["blessed","축복"] or str(record.get("bless_state","")).to_lower() in ["blessed","축복"] or name.begins_with("축복받은 ")
	var bless: int = int(physical.get("source_bless_code",record.get("source_bless_code_id",1)))
	if physical.has("blessed") or physical.has("bless_state") or record.has("blessed") or record.has("bless_state") or name.begins_with("축복받은 "): bless = 2 if blessed else 1
	if bless not in [1,2]: return {}
	if physical.has("quest_reward_receipt") and int(physical.quest_reward_receipt.bless_code_id) != bless: return {}
	var worn: bool = false
	for equipped: Variant in world.equipped_items.values():
		if equipped is Dictionary and str(equipped.get("instance_id","")) == id: worn = true
	var locked: bool = bool(world.call("_item_locked",name,id)) if world.has_method("_item_locked") else false
	var info: Dictionary = {"source_id":source,"instance_id":id,"name":name,"level":int(physical.get("level",0)),"bless_code":bless,
		"element_type":int({"fire":1,"water":2,"wind":3,"earth":4}.get(str(physical.get("element","")),0)),"element_level":int(physical.get("element_level",0)),
		"state":state.duplicate(true),"record":record.duplicate(true),"equipped":worn,"locked":locked,"quantity":quantity,"amount":quantity,
		"quest_reward_receipt":physical.has("quest_reward_receipt")}
	for key: String in ["expires_unix","expiry_unix"]:
		if physical.has(key): info[key] = physical[key]
		elif record.has(key): info[key] = record[key]
	info["invoke_slots"] = SetInvoke.slot_options(store.pack,info)
	return info

func _quantity(physical: Dictionary) -> int:
	var record: Variant = physical.get("record",{})
	var a: int = _positive_integer(physical.get("source_reward_quantity",1))
	var b: int = _positive_integer(record.get("source_reward_quantity",a)) if record is Dictionary else a
	if a <= 0 or b <= 0: return -1
	if physical.has("source_reward_quantity") and record is Dictionary and record.has("source_reward_quantity") and a != b: return -1
	if physical.has("quest_reward_receipt"):
		# Receipt quantity is the immutable original grant, not the remainder.
		# Only recognizable records remain visible; every receipt is blocked at
		# quote/debit until the quest consumption journal can commit atomically.
		var receipt: Variant = physical.get("quest_reward_receipt")
		if not receipt is Dictionary or not record is Dictionary or receipt.get("schema") != 1: return -1
		if receipt.get("source_sha256") != store.pack.get("source_sha256"): return -1
		var item_id: int = _positive_integer(receipt.get("item_class_id"))
		var reward_id: int = _positive_integer(receipt.get("reward_id"))
		var granted: int = _positive_integer(receipt.get("quantity"))
		var quest_id: String = str(receipt.get("quest_id",""))
		var quest_number: String = quest_id.trim_prefix("m523:quest:")
		if item_id <= 0 or reward_id <= 0 or granted < b or b <= 0 or _source(record) != item_id: return -1
		if not quest_number.is_valid_int() or int(quest_number) <= 0 or quest_id != "m523:quest:" + str(int(quest_number)): return -1
		var receipt_bless: int = _positive_integer(receipt.get("bless_code_id"))
		if receipt_bless not in [1,2]: return -1
		if record.has("source_reward_id") and record.source_reward_id != reward_id: return -1
		if record.has("source_bless_code_id") and record.source_bless_code_id != receipt.bless_code_id: return -1
	return b

func _positive_integer(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or value < 1 or value > 9007199254740991: return 0
	return int(value)

func _equipped(world: Node) -> Array:
	var out: Array = []
	var visited: Dictionary = {}
	for worn: Variant in world.equipped_items.values():
		if not worn is Dictionary: continue
		var id: String = str(worn.get("instance_id",""))
		if id.is_empty() or visited.has(id) or not world.item_instances.get(id) is Dictionary: continue
		visited[id] = true
		var info: Dictionary = _info(world,id,world.item_instances[id],worn)
		if not info.is_empty(): out.append(info)
	return out

func _entries(world: Node) -> Array:
	var out: Array = []
	if store.pack.is_empty(): return out
	var reserved: Dictionary = {}
	var invalid_quantities: Dictionary = {}
	for key: Variant in world.item_instances:
		var physical: Variant = world.item_instances[key]
		if not physical is Dictionary: continue
		var name: String = str(physical.get("name",""))
		var quantity: int = _quantity(physical)
		if quantity <= 0: invalid_quantities[name] = true
		reserved[name] = int(reserved.get(name,0)) + maxi(1,quantity)
	for key: Variant in world.item_instances:
		var physical: Variant = world.item_instances[key]
		if not physical is Dictionary or invalid_quantities.has(str(physical.get("name",""))) or int(reserved.get(str(physical.get("name","")),0)) > int(world.inventory.get(str(physical.get("name","")),0)): continue
		var info: Dictionary = _info(world,str(key),physical)
		if not info.is_empty(): out.append(info)
	var candidates: Dictionary = {}
	var source_names: Dictionary = {}
	for record: Dictionary in _catalog(world):
		var source: int = _source(record)
		var name: String = str(record.get("name",""))
		if source <= 0 or _is_equipment(world,record): continue
		if not candidates.has(name): candidates[name] = {}
		if not candidates[name].has(str(source)): candidates[name][str(source)] = record
		if not source_names.has(str(source)): source_names[str(source)] = {}
		source_names[str(source)][name] = true
	for name: Variant in candidates:
		var definitions: Dictionary = candidates[name]
		if definitions.size() != 1: continue
		var source: String = str(definitions.keys()[0])
		if invalid_quantities.has(str(name)) or source_names.get(source,{}).size() != 1: continue
		var quantity: int = int(world.inventory.get(name,0)) - int(reserved.get(name,0))
		if quantity <= 0: continue
		var record: Dictionary = definitions[source]
		var locked: bool = bool(world.call("_item_locked",str(name),"")) if world.has_method("_item_locked") else false
		out.append({"source_id":int(source),"instance_id":"stack:"+source,"name":str(name),"level":0,"bless_code":2 if str(record.get("bless_state","")) == "blessed" else 1,
			"element_type":0,"element_level":0,"state":{},"record":record.duplicate(true),"equipped":false,"locked":locked,"quantity":quantity,"amount":quantity,"virtual_stack":true,"invoke_slots":[]})
	return out

func _catalog(world: Node) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for source: Variant in [world.catalog_db.get("아이템",[]),world.item_db]:
		if not source is Array: continue
		for record: Variant in source:
			if record is Dictionary: records.append(record)
	return records

func _output_catalog(world: Node) -> Dictionary:
	var result: Dictionary = {"_built":true}
	for record: Dictionary in _catalog(world):
		var id: int = _source(record)
		if id <= 0 or bool(record.get("source_original_item",false)): continue
		var key: String = str(id)
		if result.has(key) and result[key].get("name") != record.get("name"):
			result[key] = {}
		elif not result.has(key): result[key] = record
	return result

func _output_record(world: Node, id: int, indexed: Dictionary = {}) -> Dictionary:
	var candidates: Dictionary = indexed if not indexed.is_empty() else _output_catalog(world)
	var selected: Dictionary = candidates.get(str(id),{})
	if not selected.is_empty(): return selected.duplicate(true)
	var source: Dictionary = Common.item(store.pack,id)
	if source.is_empty() or str(source.get("name","")).is_empty() or bool(source.get("raw",{}).get("TestItem",false)): return {}
	return {"name":"[원본보상]"+str(source.name),"source":"lineagem_current523","source_snapshot":"current523","sourceId":"m523:item:"+str(id),
		"source_item_class_id":id,"source_original_item":true,"source_bless_code_id":1,"source_reward_quantity":1,"source_reward_id":0,
		"desc":"미등록 원본 아이템: 실제 장비 효과는 카탈로그 등록 후 적용합니다."}

func _is_equipment(world: Node, record: Dictionary) -> bool:
	return not str(world.call("_enhancement_kind_for_record",record)).is_empty() if world.has_method("_enhancement_kind_for_record") else str(record.get("slot","")) in ["weapon","body","helmet","gloves","boots","cloak","ring","ring1","ring2","earring","offhand","necklace","belt"]

func _expiry_error(info: Dictionary) -> String:
	for key: String in ["expires_unix","expiry_unix"]:
		if info.has(key) and int(info[key]) > 0 and int(info[key]) <= _now(): return "이미 만료된 재료입니다."
	for row: Dictionary in Common.rows(store.pack,"ItemBonus"):
		if int(row.get("ItemClassID",0)) != int(info.source_id): continue
		var value: Dictionary = Common.bonus(store.pack,int(row.get("BonusID",0)))
		if value.get("name") != "DeleteTime": continue
		var raw: Dictionary = value.get("raw",{})
		# Unit162 Time values are not Unix seconds. Resolve each original value
		# independently; application target zero must never merge all schedules.
		var key: String = ""
		if int(raw.get("BonusApplicationTypeID",-1)) == 0 and int(raw.get("BonusApplicationTargetID",-1)) == 0 and int(raw.get("Value",0)) > 0: key = str(int(raw.Value))
		elif int(raw.get("BonusApplicationTypeID",-1)) == 298 and int(raw.get("Value",-1)) == 0 and int(raw.get("BonusApplicationTargetID",0)) > 0: key = str(int(raw.BonusApplicationTargetID))
		else: return "기간제 재료의 만료 표현을 확인할 수 없습니다. 원본 재료를 보존합니다."
		var schedules: Dictionary = policy.get("material_expiry_unix",{})
		if not schedules.has(key): return "기간제 재료의 만료 일정이 확인되지 않았습니다. 원본 재료를 보존합니다."
		if int(schedules[key]) <= _now(): return "이미 만료된 기간제 재료입니다."
	return ""

func _consume(inventory: Dictionary, physical: Dictionary, info: Dictionary, amount: int) -> String:
	var name: String = str(info.name)
	var id: String = str(info.instance_id)
	if amount < 1 or int(inventory.get(name,0)) < amount or int(info.quantity) < amount: return "보유 재료 수량이 변경되었습니다."
	if not bool(info.get("virtual_stack",false)):
		if not physical.get(id) is Dictionary: return "보유 재료 개체가 변경되었습니다."
		if physical[id].has("quest_reward_receipt"): return "원본 퀘스트 보상은 사용 영수증 연결 전 재료로 소비할 수 없습니다. 지급 기록과 잔여 수량을 보존합니다."
		if _quantity(physical[id]) != int(info.quantity): return "보유 재료 개체가 변경되었습니다."
		var remaining: int = int(info.quantity) - amount
		if remaining == 0: physical.erase(id)
		else:
			var entry: Dictionary = physical[id]
			var record: Dictionary = entry.get("record",{})
			if entry.has("source_reward_quantity"): entry["source_reward_quantity"] = remaining
			if record.has("source_reward_quantity"): record["source_reward_quantity"] = remaining
			if not entry.has("source_reward_quantity") and not record.has("source_reward_quantity"): return "물리 재료 묶음의 수량 계약이 없습니다."
	inventory[name] = int(inventory[name]) - amount
	if int(inventory[name]) == 0: inventory.erase(name)
	return ""

func _fingerprint(world: Node) -> int:
	return hash([world.inventory,world.item_instances,world.gold,world.equipped_items,world.ui_preferences.get("item_locks",{}),world.next_item_instance_id,world.level,world.catalog_db.get("아이템",[]),world.item_db,policy,store.sha256])

func _weight(world: Node, inventory: Dictionary) -> int:
	var result: int = 0
	for name: Variant in inventory: result += int(inventory[name]) * maxi(0,int(world.item_weight_index.get(str(name),0 if str(name) == "아데나" else 3)))
	return result

func _saved_candidate(world: Node, staged: Dictionary) -> bool:
	if not world.has_method("save_path"): return false
	var path: String = str(world.call("save_path"))
	if not FileAccess.file_exists(path): return false
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved is Dictionary: return false
	for key: String in staged:
		if saved.get(key) != JSON.parse_string(JSON.stringify(staged[key])): return false
	return true

static func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _host_blocker(world: Node) -> String:
	for property: Dictionary in world.get_property_list():
		var name: String = str(property.get("name",""))
		if name == "source_save_blocked" and bool(world.get(name)): return "원본 맵 저장 보호 중에는 가공할 수 없습니다."
		if name == "migration_pointer_error" and not str(world.get(name)).is_empty(): return "이전 저장 선택 기록을 먼저 확인하세요."
		if name == "patch523_npc_spells":
			var status: Variant = world.get(name)
			if status != null and status.has_method("blocks") and bool(status.call("blocks","CannotUseItem")): return "현재 상태에서는 아이템을 사용할 수 없습니다."
	return ""
