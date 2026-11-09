extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Selected-item cart automation. World remains the only persistence authority.
const KEY: String = "inventory_automation"
const BUYBACK = preload("res://scripts/shop/local_buyback.gd")
const STORAGE = preload("res://scripts/warehouse/local_warehouse.gd")
const SOURCE_RULES = preload("res://scripts/warehouse/inventory_source523.gd")
const REGISTERED = preload("res://scripts/warehouse/inventory_registered523.gd")
const EQUIPMENT_CATEGORIES = preload("res://scripts/warehouse/equipment_category_selection.gd")
const MAINTENANCE = preload("res://scripts/warehouse/inventory_maintenance.gd")
var registered = REGISTERED.new()
var equipment_categories = EQUIPMENT_CATEGORIES.new()
var source_rules = SOURCE_RULES.new()
var maintenance = MAINTENANCE.new()
var world: Node
var state: Dictionary = {"version":1,"deposit":[],"sell":[]}
var busy: bool = false

func _init() -> void:
	equipment_categories.configure(self)
	maintenance.configure(self)

func configure(host: Node) -> void:
	world = host
	source_rules.load_file(SOURCE_RULES.configured_file())
	maintenance.configure(self)

func refresh_catalog() -> Dictionary:
	if world == null or not world.get("catalog_db") is Dictionary: return {}
	var registration: Dictionary = registered.attach(world.catalog_db,source_rules)
	if int(registration.get("added",0)) > 0 and world.has_method("_index_catalog_item_sources"): world._index_catalog_item_sources()
	return source_rules.registered_status(world.catalog_db.get("아이템",[]))

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if raw.get("version", 1) != 1: return false
	if raw.has("source_only") and not raw.source_only is bool: return false
	var prices: Variant = raw.get("native_prices",{})
	if not prices is Dictionary or prices.size() > 256: return false
	for id: Variant in prices:
		if not id is String or not id.is_valid_int() or int(id) <= 0: return false
		if not SOURCE_RULES._integer(prices[id]) or prices[id] < 0 or prices[id] > 1000000000: return false
	if not MAINTENANCE.valid(raw.get("maintenance",{})): return false
	if not EQUIPMENT_CATEGORIES.valid(raw.get("equipment_category",{})): return false
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
	maintenance.on_restore()

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
	if name == "아데나" or record.is_empty() or bool(record.get("quest_item", false)) or bool(record.get("source_test_item",false)): return true
	var native: Dictionary = source_rules.resolve(record,world.item_instances.get(id,{}) if id != "" else {})
	if not native.is_empty():
		if native.item.virtual or native.item.test_item or native.item.currency: return true
		if mode == "deposit" and not native.item.is_storable: return true
	var custom: Dictionary = world.item_instances.get(id, {}).get("record", {}) if id != "" else {}
	if bool(custom.get("quest_item", false)): return true
	if mode == "deposit":
		var record_full: Dictionary = NATIVE_FIELDS.full(record)
		var custom_full: Dictionary = NATIVE_FIELDS.full(custom)
		return (record.has("IsStorable") and not bool(record.IsStorable)) or (record_full.has("source_is_storable") and not bool(record_full.source_is_storable)) or (custom.has("IsStorable") and not bool(custom.IsStorable)) or (custom_full.has("source_is_storable") and not bool(custom_full.source_is_storable))
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
			var quote: Dictionary = sale_quote(name,1,id,world.inventory,world.item_instances,world.gold)
			if not quote.get("ok", false): return quote
		if state.get("source_only",false):
			var resolved: Dictionary = source_rules.resolve(record,world.item_instances.get(id,{}) if id != "" else {})
			if not source_rules.eligible(resolved,mode): return {"ok":false,"reason":"원본 자동 대상·ID·축복 상태를 확인해주세요"}
			var total: int = 0
			for rule: Dictionary in rules:
				if not source_rules.resolve(world._find_catalog_item_record(str(rule.name))).is_empty(): total += 1
			if mode == "sell" and total >= int(source_rules.document.get("auto_sell_max",40)): return {"ok":false,"reason":"원본 자동 판매 대상은 최대40개입니다"}
		rules.append({"name":name,"id":id,"keep":keep,"identity":_identity(name,id)})
	return save_settings(next)

func save_settings(next: Dictionary, preserve_maintenance: bool = false) -> Dictionary:
	if busy or not valid(next): return {"ok":false,"reason":"자동 처리 설정이 유효하지 않습니다"}
	sync_category_targets(next)
	if not preserve_maintenance and next.has("maintenance"):
		next.maintenance["armed"] = false
		if next.maintenance.has("automatic"): next.maintenance.automatic["enabled"] = false
	busy = true
	var error: Error = world._save_game(true, {KEY:next})
	busy = false
	if error != OK: return {"ok":false,"reason":"설정 저장 실패 · 이전 설정 보존"}
	state = next
	if not preserve_maintenance: maintenance.reset_session()
	return {"ok":true}

func clear(mode: String) -> Dictionary:
	if busy or mode not in ["deposit", "sell"]: return {"ok":false}
	var next: Dictionary = state.duplicate(true)
	next[mode] = []
	return save_settings(next)

func set_source_only(enabled: bool) -> Dictionary:
	if enabled and source_rules.document.is_empty(): return {"ok":false,"reason":source_rules.problem}
	var next: Dictionary = state.duplicate(true)
	next["source_only"] = enabled
	return save_settings(next)

func set_native_price(id: String, price: int) -> Dictionary:
	var row: Dictionary = source_rules.definition(id)
	if row.is_empty() or not row.merchant_auto or row.virtual or not row.price.is_empty() or price < 0 or price > 1000000000: return {"ok":false,"reason":"확인된 원본 가격은 변경할 수 없습니다"}
	var next: Dictionary = state.duplicate(true)
	if not next.has("native_prices"): next["native_prices"] = {}
	next.native_prices[id] = price
	return save_settings(next)

func sale_quote(name: String, quantity: int, id: String, inventory: Dictionary, physical: Dictionary, wallet: int, enforce_selection: bool = true) -> Dictionary:
	var record: Dictionary = world._find_catalog_item_record(name)
	if bool(record.get("source_test_item",false)): return {"ok":false,"reason":"원본 시험용 아이템은 매입하지 않습니다"}
	var resolved: Dictionary = source_rules.resolve(record,physical.get(id,{}) if id != "" else {})
	if not resolved.is_empty() and (resolved.item.virtual or resolved.item.test_item or resolved.item.currency):
		return {"ok":false,"reason":"원본 범주 선택자·시험용·재화 아이템은 매입하지 않습니다"}
	if not resolved.is_empty() and source_rules.eligible(resolved,"sell"):
		return source_rules.quote(record,name,quantity,id,inventory,physical,world.equipped_items,wallet,state.get("native_prices",{}))
	if enforce_selection and state.get("source_only",false): return {"ok":false,"reason":"원본 자동 판매 대상이 아닙니다"}
	var quote: Dictionary = BUYBACK.quote(name,quantity,id,inventory,world.loot_catalog.get("by_name",{}),physical,world.equipped_items,wallet)
	quote["price_basis"] = "TWILIGHT 기존 매입가"
	return quote

func _stamp(mode: String) -> String:
	var identities: Array = []
	var rules: Array = state.get(mode,[]) if mode in ["deposit","sell"] else []
	for rule: Dictionary in rules: identities.append(_identity(str(rule.name), str(rule.get("id", ""))))
	return JSON.stringify([mode,state,world.inventory,world.item_instances,world.equipped_items,world.ui_preferences.get("item_locks",{}),world.warehouse.snapshot(),world.gold,identities,source_rules.fingerprint()]).sha256_text()

func preview(mode: String, base: Dictionary = {}, configuration: Dictionary = {}) -> Dictionary:
	if busy or mode not in ["deposit", "sell"]: return {"ok":false,"reason":"자동 처리 요청이 유효하지 않습니다"}
	var working: Dictionary = state if configuration.is_empty() else configuration
	if not valid(working): return {"ok":false,"reason":"자동 처리 설정이 유효하지 않습니다"}
	var inventory: Dictionary = base.get("inventory",world.inventory).duplicate(true)
	var physical: Dictionary = base.get("item_instances",world.item_instances).duplicate(true)
	var storage = STORAGE.new()
	var stored: Dictionary = base.get("warehouse",world.warehouse.snapshot())
	storage.restore(stored)
	if JSON.stringify(_canonical(storage.snapshot())) != JSON.stringify(_canonical(stored)): return {"ok":false,"reason":"창고 상태를 확인해주세요"}
	var wallet: int = int(base.get("gold",world.gold))
	var cart: Array[Dictionary] = []
	var skipped: Array[String] = []
	var remaining: Array = []
	for rule: Dictionary in working.get(mode, []):
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
		if working.get("source_only",false) and not source_rules.eligible(source_rules.resolve(world._find_catalog_item_record(name),physical.get(id,{}) if id != "" else {}),mode):
			skipped.append(name+" · 원본 대상·축복 상태 불일치")
			continue
		var count: int = 1 if id != "" else maxi(0,available-int(rule.get("keep",0)))
		if id != "" and int(rule.get("keep",0)) > 0: count = 0
		if count == 0: continue
		if count > 1000000: return {"ok":false,"reason":"소지 수량 범위를 확인해주세요"}
		var before: int = wallet
		var price_basis: String = ""
		var left: int = count
		while left > 0:
			var amount: int = mini(left,99 if mode == "sell" else STORAGE.MAX_TRANSFER)
			var result: Dictionary
			if mode == "sell":
				var quote: Dictionary = sale_quote(name,amount,id,inventory,physical,wallet,false)
				if not quote.get("ok",false): return {"ok":false,"reason":name+" · "+str(quote.get("reason","매입 불가"))}
				price_basis = str(quote.get("price_basis",""))
				result = BUYBACK.apply(quote,inventory,physical,wallet)
				if result.get("ok",false): wallet = int(result.wallet)
			else:
				result = storage.store(name,amount,id,inventory,physical,world.equipped_items,id != "")
			if not result.get("ok",false): return {"ok":false,"reason":name+" · "+str(result.get("reason","처리 불가"))}
			if mode == "deposit" and int(storage.stacks.get(name,0)) > 1000000: return {"ok":false,"reason":"창고 저장 수량 한도를 초과합니다"}
			left -= amount
		cart.append({"name":name,"id":id,"quantity":count,"payment":wallet-before,"price_basis":price_basis,"mode":mode})
		if id != "": remaining.pop_back()
	var next: Dictionary = base.get(KEY,working).duplicate(true)
	next[mode] = remaining
	if mode == "sell": sync_category_targets(next)
	return {"ok":true,"mode":mode,"stamp":_stamp(mode),"cart":cart,"skipped":skipped,"payment":wallet-int(base.get("gold",world.gold)),"override":{"inventory":inventory,"item_instances":physical,"warehouse":storage.snapshot(),"gold":wallet,KEY:next}}

static func sync_category_targets(next: Dictionary) -> void:
	if not next.has("equipment_category"): return
	var active: Dictionary = {}
	for rule: Dictionary in next.get("sell",[]):
		if rule.get("category_owner","") == EQUIPMENT_CATEGORIES.MARKER: active[str(rule.get("id",""))] = true
	var retained: Array = []
	for target: Dictionary in next.equipment_category.get("targets",[]):
		if active.has(str(target.id)): retained.append(target)
	next.equipment_category["targets"] = retained

func execute(mode: String, stamp: String) -> Dictionary:
	if busy or mode not in ["deposit", "sell"] or stamp.is_empty() or stamp != _stamp(mode):
		return {"ok":false,"reason":"소지품·설정이 변경되었습니다. 자동 담기를 다시 눌러주세요"}
	var plan: Dictionary = preview(mode)
	if not plan.get("ok",false): return plan
	if plan.cart.is_empty(): return {"ok":false,"reason":"처리할 아이템이 없습니다"}
	return commit_plan(plan)

func commit_plan(plan: Dictionary) -> Dictionary:
	if busy: return {"ok":false,"reason":"거래 처리 중입니다"}
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
	world.hud.append_log("자동 정비 · %d항목 · +%d 아데나" % [plan.cart.size(),int(plan.payment)])
	world.hud.show_message("자동 처리 완료 · %d항목" % plan.cart.size())
	return {"ok":true,"cart":plan.cart,"payment":plan.payment}
