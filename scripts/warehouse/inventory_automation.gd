extends RefCounted
## Selected-item cart automation. World remains the only persistence authority.
const KEY: String = "inventory_automation"
const BUYBACK = preload("res://scripts/shop/local_buyback.gd")
const STORAGE = preload("res://scripts/warehouse/local_warehouse.gd")
var world: Node
var state: Dictionary = {"version":1,"deposit":[],"sell":[]}
var busy: bool = false

func configure(host: Node) -> void:
	world = host

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if raw.get("version", 1) != 1: return false
	for mode: String in ["deposit", "sell"]:
		var rules: Variant = raw.get(mode, [])
		if not rules is Array or rules.size() > 256: return false
		var seen: Dictionary = {}
		for rule: Variant in rules:
			if not rule is Dictionary: return false
			if not rule.get("name") is String or rule.name.is_empty(): return false
			if not rule.get("id", "") is String or not rule.get("identity") is String: return false
			if rule.identity.length() != 64 or not str(rule.identity).is_valid_hex_number(): return false
			var keep: Variant = rule.get("keep", 0)
			if not (keep is int or keep is float) or not is_finite(float(keep)) or float(keep) != floor(float(keep)) or keep < 0 or keep > 1000000: return false
			var reference: String = str(rule.name) + "@@@" + str(rule.get("id", ""))
			if seen.has(reference): return false
			seen[reference] = true
	return true

func restore(raw: Variant) -> void:
	state = (raw as Dictionary).duplicate(true) if valid(raw) else {"version":1,"deposit":[],"sell":[]}
	state["version"] = 1
	for mode: String in ["deposit", "sell"]:
		if not state.has(mode): state[mode] = []
		for rule: Dictionary in state[mode]: rule["keep"] = int(rule.get("keep",0))

static func _canonical(value: Variant) -> Variant:
	# JSON restores numbers as float. Integral metadata must keep its identity
	# across a legitimate save/load without concealing real equipment changes.
	if value is float and is_finite(value) and absf(value) <= 9007199254740991.0 and value == floor(value): return int(value)
	if value is Array:
		var out: Array = []
		for entry: Variant in value: out.append(_canonical(entry))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value: out[key] = _canonical(value[key])
		return out
	return value

func _identity(name: String, id: String) -> String:
	var record: Dictionary = world._find_catalog_item_record(name)
	var physical: Dictionary = world.item_instances.get(id, {}) if id != "" else {}
	return JSON.stringify(_canonical([record, physical])).sha256_text()

func _protected(name: String, id: String, mode: String = "deposit") -> bool:
	if world._item_locked(name, "") or world._item_locked(name, id): return true
	if id != "" and STORAGE.equipped_id(world.equipped_items, id): return true
	var record: Dictionary = world._find_catalog_item_record(name)
	if name == "아데나" or record.is_empty() or bool(record.get("quest_item", false)): return true
	var custom: Dictionary = world.item_instances.get(id, {}).get("record", {}) if id != "" else {}
	if bool(custom.get("quest_item", false)): return true
	if mode == "deposit":
		return (record.has("IsStorable") and not bool(record.IsStorable)) or (custom.has("IsStorable") and not bool(custom.IsStorable))
	return bool(custom.get("bound",false)) or not bool(custom.get("tradeable",true))

func contains(mode: String, name: String, id: String) -> bool:
	for rule: Dictionary in state.get(mode, []):
		if rule.name == name and rule.get("id", "") == id: return true
	return false

func set_target(mode: String, name: String, id: String, selected: bool, keep: int = 0) -> Dictionary:
	if busy or mode not in ["deposit", "sell"] or keep < 0 or keep > 1000000:
		return {"ok":false,"reason":"자동 처리 설정이 유효하지 않습니다"}
	var next: Dictionary = state.duplicate(true)
	var rules: Array = next[mode]
	for index: int in range(rules.size()-1, -1, -1):
		if rules[index].name == name and rules[index].get("id", "") == id: rules.remove_at(index)
	if selected:
		if rules.size() >= 256 or _protected(name, id, mode) or int(world.inventory.get(name, 0)) <= 0:
			return {"ok":false,"reason":"보호 중이거나 소지하지 않은 아이템입니다"}
		var record: Dictionary = world._find_catalog_item_record(name)
		var gear: bool = str(world._enhancement_kind_for_record(record)) != ""
		if gear != (id != "") or (gear and (not world.item_instances.has(id) or str(world.item_instances[id].get("name", "")) != name)):
			return {"ok":false,"reason":"장비 고유 ID를 확인해주세요"}
		if mode == "sell":
			var quote: Dictionary = BUYBACK.quote(name, 1, id, world.inventory, world.loot_catalog.get("by_name", {}), world.item_instances, world.equipped_items, world.gold)
			if not quote.get("ok", false): return quote
		rules.append({"name":name,"id":id,"keep":keep,"identity":_identity(name,id)})
	busy = true
	var error: Error = world._save_game(true, {KEY:next})
	busy = false
	if error != OK: return {"ok":false,"reason":"설정 저장 실패 · 이전 설정 보존"}
	state = next
	return {"ok":true}

func clear(mode: String) -> Dictionary:
	if busy or mode not in ["deposit", "sell"]: return {"ok":false}
	var next: Dictionary = state.duplicate(true)
	next[mode] = []
	busy = true
	var error: Error = world._save_game(true, {KEY:next})
	busy = false
	if error != OK: return {"ok":false,"reason":"설정 저장 실패"}
	state = next
	return {"ok":true}

func _stamp(mode: String) -> String:
	var identities: Array = []
	for rule: Dictionary in state.get(mode, []): identities.append(_identity(str(rule.name), str(rule.get("id", ""))))
	return JSON.stringify([mode,state,world.inventory,world.item_instances,world.equipped_items,world.ui_preferences.get("item_locks",{}),world.warehouse.snapshot(),world.gold,identities]).sha256_text()

func preview(mode: String) -> Dictionary:
	if busy or mode not in ["deposit", "sell"]: return {"ok":false,"reason":"자동 처리 요청이 유효하지 않습니다"}
	var inventory: Dictionary = world.inventory.duplicate(true)
	var physical: Dictionary = world.item_instances.duplicate(true)
	var storage = STORAGE.new()
	storage.restore(world.warehouse.snapshot())
	if JSON.stringify(_canonical(storage.snapshot())) != JSON.stringify(_canonical(world.warehouse.snapshot())): return {"ok":false,"reason":"창고 상태를 확인해주세요"}
	var wallet: int = world.gold
	var cart: Array[Dictionary] = []
	var skipped: Array[String] = []
	var remaining: Array = []
	for rule: Dictionary in state.get(mode, []):
		var name: String = rule.name
		var id: String = rule.get("id", "")
		var available: int = int(inventory.get(name, 0))
		if available <= 0 or (id != "" and not physical.has(id)):
			# Consumed physical targets must never select a different item of the same name.
			if id == "": remaining.append(rule.duplicate(true))
			continue
		remaining.append(rule.duplicate(true))
		if _protected(name,id,mode) or _identity(name,id) != str(rule.identity):
			skipped.append(name + " · 보호 중 또는 아이템 정보 변경")
			continue
		var count: int = 1 if id != "" else maxi(0,available-int(rule.get("keep",0)))
		if id != "" and int(rule.get("keep",0)) > 0: count = 0
		if count == 0: continue
		if count > 1000000: return {"ok":false,"reason":"소지 수량 범위를 확인해주세요"}
		var before: int = wallet
		var left: int = count
		while left > 0:
			var amount: int = mini(left,99 if mode == "sell" else STORAGE.MAX_TRANSFER)
			var result: Dictionary
			if mode == "sell":
				var quote: Dictionary = BUYBACK.quote(name,amount,id,inventory,world.loot_catalog.get("by_name",{}),physical,world.equipped_items,wallet)
				if not quote.get("ok",false): return {"ok":false,"reason":name+" · "+str(quote.get("reason","매입 불가"))}
				result = BUYBACK.apply(quote,inventory,physical,wallet)
				if result.get("ok",false): wallet = int(result.wallet)
			else:
				result = storage.store(name,amount,id,inventory,physical,world.equipped_items,id != "")
			if not result.get("ok",false): return {"ok":false,"reason":name+" · "+str(result.get("reason","처리 불가"))}
			if mode == "deposit" and int(storage.stacks.get(name,0)) > 1000000: return {"ok":false,"reason":"창고 저장 수량 한도를 초과합니다"}
			left -= amount
		cart.append({"name":name,"id":id,"quantity":count,"payment":wallet-before})
		if id != "": remaining.pop_back()
	var next: Dictionary = state.duplicate(true)
	next[mode] = remaining
	return {"ok":true,"mode":mode,"stamp":_stamp(mode),"cart":cart,"skipped":skipped,"payment":wallet-int(world.gold),"override":{"inventory":inventory,"item_instances":physical,"warehouse":storage.snapshot(),"gold":wallet,KEY:next}}

func execute(mode: String, stamp: String) -> Dictionary:
	if busy or mode not in ["deposit", "sell"] or stamp.is_empty() or stamp != _stamp(mode):
		return {"ok":false,"reason":"소지품·설정이 변경되었습니다. 자동 담기를 다시 눌러주세요"}
	var plan: Dictionary = preview(mode)
	if not plan.get("ok",false): return plan
	if plan.cart.is_empty(): return {"ok":false,"reason":"처리할 아이템이 없습니다"}
	busy = true
	var staged: Dictionary = plan.override
	var error: Error = world._save_game(true,staged)
	if error == OK:
		world.inventory = staged.inventory
		world.item_instances = staged.item_instances
		world.warehouse.restore(staged.warehouse)
		world.gold = int(staged.gold)
		state = staged[KEY]
	busy = false
	if error != OK: return {"ok":false,"reason":"저장 실패 · 아이템·아데나·창고 보존"}
	world._update_hud()
	world.hud.refresh_inventory(world.inventory)
	world.hud.append_log("자동 %s · %d항목%s" % ["보관" if mode == "deposit" else "판매",plan.cart.size()," · +%d 아데나" % int(plan.payment) if mode == "sell" else ""])
	world.hud.show_message("자동 처리 완료 · %d항목" % plan.cart.size())
	return {"ok":true,"cart":plan.cart,"payment":plan.payment}
