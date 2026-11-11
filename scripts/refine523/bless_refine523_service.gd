extends RefCounted
## World transactions for original 523 용해 (축복의 가루) and 질서의 연금.
## Every commit is one atomic save: the targets, the debited 상급 축복의 가루
## physical stacks (current523_native_stack ledger), the Adena cost, the
## granted output and the transaction RNG all persist together or not at all.
const RULES = preload("res://scripts/refine523/bless_refine523_rules.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
## Physical equipment fields every supplier writes. Any other non-empty field
## (equipment523 processing, quest receipts, smelt records, ...) belongs to
## another owner and has no original rule here: such an item is preserved.
const PLAIN_FIELDS: Array[String] = ["name","level","element","element_level","record","bless_state","sourceId","source_m_reward_proof","source_m_drop_proof"]

static func _fail(reason: String, code: String = "refused") -> Dictionary:
	return {"ok":false,"reason":reason,"code":code}

static func _equipped(world: Node, uid: String) -> bool:
	for slot: Variant in world.equipped_items:
		var value: Variant = world.equipped_items[slot]
		if value is Dictionary and str(value.get("instance_id",""))==uid: return true
	return false

## The plain original equipment behind one physical ID, or a refusal.
static func equipment(world: Node, uid: String) -> Dictionary:
	var entry: Variant = world.item_instances.get(uid)
	if not entry is Dictionary or not entry.get("record") is Dictionary or entry.has(STACK.RECEIPT): return _fail("원본 장비 개체가 아닙니다","not_equipment")
	var saved: Dictionary = entry.record
	if saved.get("source_m_native_item")!=true or not D.equipment(saved): return _fail("원본 523 장비만 사용할 수 있습니다","not_native_equipment")
	var record: Dictionary = D.current_owned_record(saved)
	if record.is_empty(): return _fail("현재 원본 정의와 장비 정체가 맞지 않아 보존합니다","stale_record")
	var item_class_id: int = int(record.get("source_item_class_id",0))
	var raw: Dictionary = RULES.item_row(item_class_id)
	if raw.is_empty() or raw.get("TestItem")!=false: return _fail("원본 아이템 정의 확인 실패","item_row_missing")
	for key: Variant in entry:
		if str(key) in PLAIN_FIELDS: continue
		var value: Variant = entry[key]
		if value==null or (value is Dictionary and value.is_empty()) or (value is Array and value.is_empty()) or (value is String and value.is_empty()) or value==false: continue
		return _fail("다른 가공·보상 기록(%s)이 있는 장비는 보존합니다" % str(key),"extra_record")
	var level: Variant = entry.get("level",0)
	if not RULES._integer(level) or int(level)<0: return _fail("강화 수치 형식 확인 실패","level")
	var element_level: Variant = entry.get("element_level",0)
	if not RULES._integer(element_level): return _fail("속성 강화 수치 형식 확인 실패","element_level")
	var name_value: String = str(entry.get("name",""))
	if name_value!=str(record.get("name","")) or int(world.inventory.get(name_value,0))<1: return _fail("가방 소지 수량과 장비 개체가 맞지 않습니다","inventory")
	if _equipped(world,uid): return _fail("착용 중인 장비는 사용할 수 없습니다","equipped")
	if world._item_locked(name_value,uid) or world._item_locked(name_value): return _fail("잠긴 장비는 사용할 수 없습니다","locked")
	var bless: int = int(record.get("source_bless_raw",1))
	var state: String = str(entry.get("bless_state","normal"))
	if state in ["blessed","축복"]: bless = 2
	elif state in ["cursed","저주"]: bless = 3
	return {"ok":true,"uid":uid,"name":name_value,"record":record,"raw":raw,"item_class_id":item_class_id,"enchant":int(level),"element":str(entry.get("element","")),"element_level":int(element_level),"bless":bless}

static func dissolve_quote(world: Node, uids: Array) -> Dictionary:
	if uids.is_empty(): return _fail("용해할 장비를 선택하세요","empty")
	var seen: Dictionary = {}; var items: Array = []; var total: int = 0
	for value: Variant in uids:
		var uid: String = str(value)
		if seen.has(uid): return _fail("같은 장비를 두 번 선택했습니다","duplicate")
		seen[uid] = true
		var info: Dictionary = equipment(world,uid)
		if not info.ok: return info
		var element_level: int = info.element_level if info.element.is_empty() or info.element_level!=0 else 1
		var yielded: Dictionary = RULES.dissolve_yield(info.item_class_id,info.enchant,element_level)
		if not yielded.ok: return yielded
		info["amount"] = int(yielded.amount); info["grade_id"] = int(yielded.grade_id)
		items.append(info); total += int(yielded.amount)
	return {"ok":true,"items":items,"output_item_class_id":RULES.BLESS_POWDER_ITEM,"total":total}

## Supplier stage over an already staged bag (the targets already removed).
static func _grant(world: Node, inventory: Dictionary, instances: Dictionary, gold: int, grants: Array, origin: Dictionary) -> Dictionary:
	var view := STACK.SupplierView.new()
	view.host = world; view.inventory = inventory; view.item_instances = instances; view.gold = gold
	var staged: Dictionary = SUPPLY.stage(view,grants,origin)
	view.free()
	return staged

static func _remove(inventory: Dictionary, instances: Dictionary, info: Dictionary) -> void:
	instances.erase(info.uid)
	var remaining: int = int(inventory.get(info.name,0))-1
	if remaining>0: inventory[info.name] = remaining
	else: inventory.erase(info.name)

static func _apply(world: Node, overrides: Dictionary) -> void:
	world.inventory = overrides.inventory
	world.item_instances = overrides.item_instances
	if overrides.has("gold"): world.gold = int(overrides.gold)
	if overrides.has("consumable_state"): world.consumable_service.import_state(overrides.consumable_state)
	if world.hud!=null:
		world.hud.refresh_inventory(world.inventory)
	world._update_hud()

static func dissolve(world: Node, uids: Array) -> Dictionary:
	var quote: Dictionary = dissolve_quote(world,uids)
	if not quote.ok: return quote
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	var ledger: Array = []
	for info: Dictionary in quote.items:
		_remove(inventory,instances,info)
		ledger.append({"physical_id":info.uid,"item_class_id":info.item_class_id,"enchant":info.enchant,"grade_id":info.grade_id,"amount":info.amount})
	var origin: Dictionary = {"kind":"source523_bless_powder_dissolution","table":"BlessPowderAmount","dissolved":ledger}
	var staged: Dictionary = _grant(world,inventory,instances,int(world.gold),[{"item_class_id":RULES.BLESS_POWDER_ITEM,"amount":int(quote.total),"bless_raw":1,"enchant":0}],origin)
	if not staged.get("ok",false): return _fail(str(staged.get("error","축복의 가루 지급 준비 실패")) + " · 장비 보존","grant")
	if world._save_game(true,staged.overrides)!=OK: return _fail("용해 저장 실패 · 장비 보존","save")
	_apply(world,staged.overrides)
	return {"ok":true,"kind":"dissolve","dissolved":ledger,"output_item_class_id":RULES.BLESS_POWDER_ITEM,"amount":int(quote.total),"detail":"용해 %d개 → 축복의 가루 %d" % [ledger.size(),int(quote.total)]}

## Proven physical 상급 축복의 가루 stacks, in physical ID order.
static func powder_owned(world: Node) -> Dictionary:
	var ids: Array = world.item_instances.keys(); ids.sort()
	var stacks: Array = []; var total: int = 0
	for uid: Variant in ids:
		var owned: Dictionary = STACK.proof(world,str(uid))
		if owned.is_empty() or int(owned.record.get("source_item_class_id",0))!=RULES.ADVANCED_BLESS_POWDER_ITEM or int(owned.record.get("source_bless_raw",0))!=1: continue
		var name_value: String = str(owned.record.name)
		if world._item_locked(name_value,str(uid)) or world._item_locked(name_value): continue
		stacks.append({"uid":str(uid),"owned":owned}); total += int(owned.remaining)
	return {"stacks":stacks,"total":total}

static func refine_quote(world: Node, uid: String, mode: String) -> Dictionary:
	var info: Dictionary = equipment(world,uid)
	if not info.ok: return info
	if info.bless!=1: return _fail("축복·저주 장비의 연금 결과 상태가 원본 표에 없어 보존합니다","bless_state")
	if info.element_level!=0 or not info.element.is_empty(): return _fail("속성 강화 장비의 연금 결과 계승 규칙이 원본 표에 없어 보존합니다","element")
	var entry: Dictionary = RULES.refine_entry(info.item_class_id,info.enchant)
	if not entry.ok: return entry
	var registered: Dictionary = RULES.registration(entry,mode)
	if not registered.ok: return registered
	var powder: Dictionary = powder_owned(world)
	var need: int = int(registered.amount)
	if int(powder.total)<need: return _fail("상급 축복의 가루가 부족합니다 (%d/%d)" % [int(powder.total),need],"powder")
	if int(world.gold)<int(entry.cost): return _fail("아데나가 부족합니다 (%d/%d)" % [int(world.gold),int(entry.cost)],"adena")
	var requests: Array = []; var remaining: int = need
	for stack: Dictionary in powder.stacks:
		var owned: Dictionary = stack.owned
		var amount: int = mini(remaining,int(owned.remaining))
		requests.append({"physical_id":stack.uid,"quantity":amount,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-amount,STACK.RECEIPT:owned.receipt.duplicate(true)})
		remaining -= amount
		if remaining==0: break
	return {"ok":true,"target":info,"entry":entry,"registration":registered,"requests":requests,"cost":int(entry.cost),"percent":RULES.percent_text(int(registered.probability))}

static func refine(world: Node, uid: String, mode: String) -> Dictionary:
	var quote: Dictionary = refine_quote(world,uid,mode)
	if not quote.ok: return quote
	var debit: Dictionary = STACK.stage_debit(world,quote.requests)
	if not debit.get("ok",false): return _fail(str(debit.get("reason",debit.get("error","상급 축복의 가루 차감 준비 실패"))),"debit")
	var overrides: Dictionary = debit.overrides
	var rng := RandomNumberGenerator.new()
	rng.state = world.rng.state
	var roll: int = rng.randi_range(0,RULES.SCALE-1)
	var success: bool = roll<int(quote.registration.probability)
	var gold: int = int(world.gold)-int(quote.cost)
	var inventory: Dictionary = overrides.inventory
	var instances: Dictionary = overrides.item_instances
	var output: Dictionary = {}
	var staged: Dictionary = {"inventory":inventory,"item_instances":instances,"gold":gold,"consumable_state":overrides.consumable_state}
	if success:
		output = RULES.pick_output(quote.entry,rng)
		_remove(inventory,instances,quote.target)
		var origin: Dictionary = {"kind":"source523_refine","table":"RefineOutput","refine_item_group_id":int(quote.entry.group_id),"target_physical_id":uid,"target_item_class_id":int(quote.target.item_class_id),"target_enchant":int(quote.target.enchant),"registered_amount":int(quote.registration.amount),"probability":int(quote.registration.probability),"roll":roll,"output_row_id":int(output.ID)}
		var granted: Dictionary = _grant(world,inventory,instances,gold,[{"item_class_id":int(output.ItemClassID),"amount":1,"bless_raw":1,"enchant":int(output.Enchant)}],origin)
		if not granted.get("ok",false): return _fail(str(granted.get("error","연금 결과 지급 준비 실패")) + " · 재료·장비 보존","grant")
		staged = granted.overrides
		staged["consumable_state"] = overrides.consumable_state
	var before: int = world.rng.state
	world.rng.state = rng.state
	if world._save_game(true,staged)!=OK:
		world.rng.state = before
		return _fail("질서의 연금 저장 실패 · 재료·아데나·장비 보존","save")
	_apply(world,staged)
	var result: Dictionary = {"ok":true,"kind":"refine","success":success,"roll":roll,"probability":int(quote.registration.probability),"registered_amount":int(quote.registration.amount),"cost":int(quote.cost),"target_physical_id":uid}
	if success:
		result["output_item_class_id"] = int(output.ItemClassID); result["output_enchant"] = int(output.Enchant)
		result["detail"] = "질서의 연금 성공 · +%d %s" % [int(output.Enchant),str(D.definition_id(str(int(output.ItemClassID))).get("native_record",{}).get("name",""))]
	else:
		result["detail"] = "질서의 연금 실패 · 대상 장비는 돌아왔습니다"
	return result

## Rows for the panel: dissolvable / refinable owned equipment with reasons.
static func snapshot(world: Node) -> Dictionary:
	var dissolve_rows: Array = []; var refine_rows: Array = []
	var ids: Array = world.item_instances.keys(); ids.sort()
	for value: Variant in ids:
		var uid: String = str(value)
		var entry: Variant = world.item_instances[uid]
		if not entry is Dictionary or entry.has(STACK.RECEIPT) or not entry.get("record") is Dictionary or not D.equipment(entry.record): continue
		var info: Dictionary = equipment(world,uid)
		var label: String = "+%d %s" % [int(entry.get("level",0)),str(entry.get("name",""))]
		if not info.ok:
			dissolve_rows.append({"uid":uid,"label":label,"ok":false,"reason":info.reason})
			continue
		var element_level: int = info.element_level if info.element.is_empty() or info.element_level!=0 else 1
		var yielded: Dictionary = RULES.dissolve_yield(info.item_class_id,info.enchant,element_level)
		dissolve_rows.append({"uid":uid,"label":label,"ok":yielded.ok,"amount":int(yielded.get("amount",0)),"reason":str(yielded.get("reason",""))})
		var entry_rule: Dictionary = RULES.refine_entry(info.item_class_id,info.enchant)
		if entry_rule.ok:
			var output: Dictionary = entry_rule.outputs[0]
			refine_rows.append({"uid":uid,"label":label,"min":int(entry_rule.input.MinAmount),"max":int(entry_rule.input.MaxAmount),"min_percent":RULES.percent_text(int(entry_rule.input.MinProbability)),"max_percent":RULES.percent_text(int(entry_rule.input.MaxProbability)),"cost":int(entry_rule.cost),"output_enchant":int(output.Enchant),"output_name":str(D.definition_id(str(int(output.ItemClassID))).get("native_record",{}).get("name","")),"special_inputs":entry_rule.special_inputs.size()})
	return {"installed":RULES.installed(),"dissolve":dissolve_rows,"refine":refine_rows,"powder":int(powder_owned(world).total),"gold":int(world.gold),"refine_contents_enabled":RULES.refine_contents_enabled() if RULES.installed() else null}
