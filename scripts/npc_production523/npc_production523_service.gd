extends RefCounted
## World transactions for original 523 NPC production (소환 / 조합).
## A summon is one atomic save: the debited currency-item physical stacks
## (current523_native_stack ledger), the unit roster and the transaction RNG
## persist together or not at all. A combination saves the roster and RNG.
const RULES = preload("res://scripts/npc_production523/npc_production523_rules.gd")
const STATE = preload("res://scripts/npc_production523/npc_production523_state.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")

static func _fail(reason: String, code: String = "refused") -> Dictionary:
	return {"ok":false,"reason":reason,"code":code}

static func _owner(world: Node) -> Variant:
	var owner: Variant = world.get("npc_production523")
	return owner if owner!=null and owner.has_method("export_state") else null

## Proven, unlocked physical stacks of one original item, in physical ID order.
static func currency_owned(world: Node, item_class_id: int) -> Dictionary:
	var ids: Array = world.item_instances.keys(); ids.sort()
	var stacks: Array = []; var total: int = 0
	for uid: Variant in ids:
		var owned: Dictionary = STACK.proof(world,str(uid))
		if owned.is_empty() or int(owned.record.get("source_item_class_id",0))!=item_class_id or int(owned.record.get("source_bless_raw",0))!=1: continue
		var name_value: String = str(owned.record.name)
		if world._item_locked(name_value,str(uid)) or world._item_locked(name_value): continue
		stacks.append({"uid":str(uid),"owned":owned}); total += int(owned.remaining)
	return {"stacks":stacks,"total":total}

static func summon_quote(world: Node, summon_id: int) -> Dictionary:
	var owner: Variant = _owner(world)
	if owner==null: return _fail("NPC 생산 저장 소유자 없음","owner")
	if owner.save_blocked: return _fail("NPC 생산 저장 보호 중 · 정상 저장을 다시 불러오세요","save_blocked")
	var entry: Dictionary = RULES.summon(summon_id)
	if not entry.ok: return entry
	var item_class_id: int = int(entry.currency.item_class_id)
	var paid: Dictionary = currency_owned(world,item_class_id)
	if int(paid.total)<int(entry.cost): return _fail("%s이(가) 부족합니다 (%d/%d)" % [str(entry.currency.currency_name),int(paid.total),int(entry.cost)],"currency")
	var requests: Array = []; var remaining: int = int(entry.cost)
	for stack: Dictionary in paid.stacks:
		var owned: Dictionary = stack.owned
		var amount: int = mini(remaining,int(owned.remaining))
		requests.append({"physical_id":stack.uid,"quantity":amount,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-amount,STACK.RECEIPT:owned.receipt.duplicate(true)})
		remaining -= amount
		if remaining==0: break
	return {"ok":true,"entry":entry,"requests":requests,"owned":int(paid.total)}

static func _commit(world: Node, overrides: Dictionary, rng: RandomNumberGenerator) -> bool:
	var before: int = world.rng.state
	world.rng.state = rng.state
	if world._save_game(true,overrides)!=OK:
		world.rng.state = before
		return false
	if overrides.has("inventory"): world.inventory = overrides.inventory
	if overrides.has("item_instances"): world.item_instances = overrides.item_instances
	if overrides.has("consumable_state"): world.consumable_service.import_state(overrides.consumable_state)
	world.npc_production523.accept(overrides[STATE.KEY])
	if world.hud!=null:
		world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	return true

static func summon(world: Node, summon_id: int) -> Dictionary:
	var quote: Dictionary = summon_quote(world,summon_id)
	if not quote.ok: return quote
	var entry: Dictionary = quote.entry
	var debit: Dictionary = STACK.stage_debit(world,quote.requests)
	if not debit.get("ok",false): return _fail(str(debit.get("reason",debit.get("error","재화 차감 준비 실패"))),"debit")
	var rng := RandomNumberGenerator.new()
	rng.state = world.rng.state
	var roll: int = rng.randi_range(0,RULES.SCALE-1)
	var output: Dictionary = RULES.pick(entry.generation.outputs,roll)
	var unit: int = int(output.get("NpcClassID",0))
	var deltas: Dictionary = {str(unit):1} if unit>0 else {}
	var record: Dictionary = {"kind":"summon","summon_id":summon_id,"generation_id":int(entry.generation.generation_id),"cost":int(entry.cost),"currency_item_class_id":int(entry.currency.item_class_id),"roll":roll,"total":int(entry.generation.total),"unit":unit,"output_row_id":int(output.get("ID",0))}
	var overrides: Dictionary = debit.overrides.duplicate()
	overrides[STATE.KEY] = STATE.staged(world.npc_production523.export_state(),deltas,record)
	if not _commit(world,overrides,rng): return _fail("NPC 소환 저장 실패 · 재화·유닛 보존","save")
	var result: Dictionary = record.duplicate(true)
	result["ok"] = true; result["success"] = unit>0
	result["detail"] = ("%s · %s 획득 (%s %d 소모)" % [str(entry.name),RULES.unit_name(unit),str(entry.currency.currency_name),int(entry.cost)]) if unit>0 else ("%s 실패 · %s %d 소모" % [str(entry.name),str(entry.currency.currency_name),int(entry.cost)])
	return result

static func combination_quote(world: Node, combination_id: int) -> Dictionary:
	var owner: Variant = _owner(world)
	if owner==null: return _fail("NPC 생산 저장 소유자 없음","owner")
	if owner.save_blocked: return _fail("NPC 생산 저장 보호 중 · 정상 저장을 다시 불러오세요","save_blocked")
	var entry: Dictionary = RULES.combination(combination_id)
	if not entry.ok: return entry
	var missing: Array = []
	for key: String in entry.inputs:
		var have: int = int(owner.count(int(key)))
		if have<int(entry.inputs[key]): missing.append("%s %d/%d" % [RULES.unit_name(int(key)),have,int(entry.inputs[key])])
	if not missing.is_empty(): return _fail("조합 재료 유닛 부족: " + ", ".join(missing),"units")
	return {"ok":true,"entry":entry}

static func combine(world: Node, combination_id: int) -> Dictionary:
	var quote: Dictionary = combination_quote(world,combination_id)
	if not quote.ok: return quote
	var entry: Dictionary = quote.entry
	var rng := RandomNumberGenerator.new()
	rng.state = world.rng.state
	var roll: int = rng.randi_range(0,RULES.SCALE-1)
	var output: Dictionary = RULES.pick(entry.outputs,roll)
	var unit: int = int(output.get("NpcClassID",0))
	var deltas: Dictionary = {}
	for key: String in entry.inputs: deltas[key] = -int(entry.inputs[key])
	if unit>0: deltas[str(unit)] = int(deltas.get(str(unit),0))+1
	var record: Dictionary = {"kind":"combination","combination_id":combination_id,"consumed":entry.inputs.duplicate(true),"roll":roll,"total":int(entry.total),"unit":unit,"output_row_id":int(output.get("ID",0))}
	var overrides: Dictionary = {STATE.KEY:STATE.staged(world.npc_production523.export_state(),deltas,record)}
	if not _commit(world,overrides,rng): return _fail("NPC 조합 저장 실패 · 유닛 보존","save")
	var result: Dictionary = record.duplicate(true)
	result["ok"] = true; result["success"] = unit>0
	result["detail"] = ("조합 성공 · %s 획득" % RULES.unit_name(unit)) if unit>0 else "조합 실패 · 재료 유닛 소모"
	return result

## Rows for the panel.
static func snapshot(world: Node) -> Dictionary:
	var owner: Variant = _owner(world)
	var units: Dictionary = owner.export_state().units if owner!=null else {}
	var summon_rows: Array = []
	var currency: Dictionary = {}
	for entry: Dictionary in RULES.summons():
		if currency.is_empty(): currency = entry.currency.duplicate(true)
		summon_rows.append({"summon_id":int(entry.summon_id),"name":str(entry.name),"type_name":str(entry.type_name),"cost":int(entry.cost),"chance":RULES.percent_text(int(entry.generation.total)),"outputs":entry.generation.outputs.size()})
	var combination_rows: Array = []
	for entry: Dictionary in RULES.combinations():
		var parts: Array = []; var ready: bool = true
		for key: String in entry.inputs:
			var have: int = int(units.get(key,0))
			parts.append("%s %d/%d" % [RULES.unit_name(int(key)),have,int(entry.inputs[key])])
			if have<int(entry.inputs[key]): ready = false
		var output_names: Array = []
		for row: Dictionary in entry.outputs: output_names.append("%s %s" % [RULES.unit_name(int(row.NpcClassID)),RULES.percent_text(int(row.Probability))])
		combination_rows.append({"combination_id":int(entry.combination_id),"inputs":parts,"outputs":output_names,"ready":ready})
	var unit_rows: Array = []
	var keys: Array = units.keys(); keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(str(a))<int(str(b)))
	for key: Variant in keys: unit_rows.append({"npc_class_id":int(str(key)),"name":RULES.unit_name(int(str(key))),"count":int(units[key])})
	var merges: Array = []
	if RULES.installed():
		for row: Dictionary in RULES.SOURCE.rows("NpcProductionMerge"): merges.append(str(RULES.merge(int(row.ID)).reason))
	var owned: int = int(currency_owned(world,int(currency.item_class_id)).total) if not currency.is_empty() else 0
	return {"installed":RULES.installed(),"contents_enabled":RULES.contents_enabled() if RULES.installed() else null,"currency":currency,"currency_owned":owned,"summons":summon_rows,"combinations":combination_rows,"units":unit_rows,"merges":merges,"save_blocked":owner==null or owner.save_blocked}
