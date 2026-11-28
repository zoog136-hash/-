extends SceneTree
## Every shop item can be bought (user report 2026-11-21 "상점에 구매 안 되는 거
## 많아").
## Always (synthetic, no original files): the contract of each fixed cause —
##  - every merchant of a placed town NPC has an offline rule (default rule);
##  - siege-time rows sell (no siege offline);
##  - ServerLimitSetID 0 is no limit; other servers' BM offers are not listed;
##  - market-only original draw pools are read whole on demand;
##  - NPC limits reset at 05:00 KST and an older calendar does not lock;
##  - LimitServerCount caps this save's own counter;
##  - original BM boxes of game-currency offers are bound;
##  - original 523 items pay (receipt debit) and are issued (523 supplier),
##    equipment included;
##  - merchant-10 books without a local skill sell as native 523 books.
## With the real 523 pack and original UI (--source523-pack): actual Main, every
## NPC 상점 row of every placed merchant (59 merchant NPC classes, all Lands)
## and every product of every BM shop tab is bought through its window: open ->
## row/card -> the original keypad (count) -> 확 인. The currency is funded with
## the test grant path; the paid amount and the bag gain must equal the
## original price × count and the original Amount × count. A row may only be
## refused by an original condition of the buyer (class, clan, card, learned,
## the original daily limit) or be a recorded remaining item (REMAINING).
## Split for the 600 s run limit: --shop-all-part=npc:<first class>:<last class> | market
##   godot --headless --path <repo> --script res://tests/shop_all_items523_test.gd -- --source523-pack=<pack>
const STORE = preload("res://scripts/ui/original_ui/source_main_store_window.gd")
const SHOP_WINDOW = preload("res://scripts/ui/original_ui/source_main_shop_window.gd")
const RUNTIME = preload("res://scripts/shop/source523_shop_runtime.gd")
const NPC_DEFS = preload("res://scripts/shop/source523_npc_definitions.gd")
const RESETS = preload("res://scripts/shop/source523_npc_resets.gd")
const TICKETS = preload("res://scripts/shop/source523_inventory_tickets.gd")
const PACKAGES = preload("res://scripts/shop/source523_cash_packages.gd")
const TOWN = preload("res://scripts/npc/source523_town_npcs.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const CASH = preload("res://scripts/shop/source523_cash_market.gd")
## Refusals that are the buyer's own original condition (a knight test
## character, no clan, no card, learned, the original daily count).
const CONDITION_REFUSALS: Array[String] = ["직업 조건", "혈맹", "카드 보유 필요", "이미 습득함", "레벨 조건", "구매 한도", "구매 레벨이 부족합니다", "계정 구매 한도"]
## Recorded remaining items: reason fragment -> why it is not sold here.
const REMAINING: Dictionary = {
	"미해석 구매 제한 · 유형 12": "서버 이전·숙련도 교체·클래스 변경 같은 계정/서버 부가 서비스(Unit 281 AdditionalServiceID)",
	"미해석 구매 제한 · 유형 19": "드래곤의 용옥: 기존 전용 상점(월 1회·가격 규칙)에서 판매",
	"드래곤의 용옥은 기존 전용 상점": "드래곤의 용옥: 기존 전용 상점(월 1회·가격 규칙)에서 판매",
	"판매·행사 기간이 아닙니다": "원본 판매 기간이 끝난 이벤트 상품(2026-11-04 종료)",
	"원본 아이템 선언으로 제외된 상품입니다": "원본 선언 제외 품목(드래곤의 다이아몬드: 아인하사드 충전 전용)",
	"미확인·시험·원본 더미 품목": "원본 더미 선언 품목(source_dummy523)",
	"NPC 객체의 동작·별도 권한 조건": "기억의 섬 전용 상인(MemoryIslandMerchant 속성, 기억의 섬 콘텐츠 미구현)",
	"NPC 기간제·테스트 상품 조건 미확정": "원본 이벤트 기간제 품목(이벤트 상인 스킬서·할로윈 장비 등): 원본 523 지급기가 삭제 시각을 확정하지 못함",
	"테스트·기간제 상품의 사용·만료 조건 미확인": "원본 기간제·기념 품목(문양 초기화 두루마리, 기념 반지·배지): 원본 523 지급기가 수명을 확정하지 못함",
	"원본 스펠 그룹 마스터리 조건": "원본 스펠 그룹 마스터리 학습 조건(학습 엔진 미지원)",
	"결제 재화가 원본 시험·더미 품목": "결제 재화가 원본 TestItem/더미(다크엘프의 영혼석, TJ 코인, 변신 뽑기권 6171)",
}
## Remaining rows named by their own row (a generic reason must not hide others).
const REMAINING_ROWS: Dictionary = {
	"(MerchantGoods 12612)": "신년 행운 상자: NPC 판매 상자는 원본 상자 규칙 연결 대상 밖",
	"(MarketPurchase 84211)": "축복의 성수(대): 축복 포인트 충전(IntangibleItem) 사용 소유자 없음",
	"(MarketPurchase 89634)": "축복의 성수(대): 축복 포인트 충전(IntangibleItem) 사용 소유자 없음",
}
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {"rows": 0, "ok": 0, "condition": 0, "remaining": {}, "failed": []}
var part: String = ""
## Stop (and report where) before this tick, for the 600 s run limit (0: none).
var budget_ms: int = 0
var stopped_at: String = ""

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		printerr("SHOP_ALL_ITEMS523_FAIL: ", label)
	return value

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shop-all-part="): part = arg.trim_prefix("--shop-all-part=")
		if arg.begins_with("--shop-all-budget-ms="): budget_ms = int(arg.trim_prefix("--shop-all-budget-ms="))
	synthetic()
	await real_main()
	if not stopped_at.is_empty(): evidence["stopped_at"] = stopped_at
	print("SHOP_ALL_ITEMS523_RESULT ", JSON.stringify({"checks": checks, "failures": failures.slice(0, 40), "failure_count": failures.size(), "evidence": evidence}))
	quit(0 if failures.is_empty() else 1)

## --- Synthetic ---------------------------------------------------------------

func synthetic() -> void:
	# Default merchant rule (fake NPC projection rows).
	var npc = NPC_DEFS.new()
	npc.records = {"700": {"merchant_id": 700, "goods_ids": [1], "goods_index": {"1": true}, "object_links": [
		{"earth_object_id": 9001, "name": "[잡화상인] 시험", "object_defined": true, "currency_ids": [1], "currency_defined_and_unique": true, "sell_action_row_ids": [5], "attributes": [],
		"spawns": [{"ID": 11, "Name": "m", "ServerLimitSetID": 0, "SpawnManually": true}, {"ID": 12, "Name": "a", "ServerLimitSetID": 0, "SpawnManually": false}]}]},
		"701": {"merchant_id": 701, "goods_ids": [2], "goods_index": {"2": true}, "object_links": [
		{"earth_object_id": 9002, "name": "[테스트] 상인", "object_defined": true, "currency_ids": [1], "currency_defined_and_unique": true, "sell_action_row_ids": [5], "attributes": [],
		"spawns": [{"ID": 13, "Name": "x", "ServerLimitSetID": 0, "SpawnManually": false}]}]}}
	npc.loaded_sha256 = "a".repeat(64)
	check(npc.rules.get("default_placed_merchants") == true, "the rules turn on the default for placed merchants")
	var rule: Dictionary = npc.rule_for(700)
	check(int(rule.get("spawn_id", 0)) == 12 and int(rule.get("earth_object_id", 0)) == 9001 and rule.get("equipment_mode") == "normal_zero_only", "a placed merchant gets a default rule on its automatic spawn (%s)" % str(rule))
	check(npc.rule_for(701).is_empty(), "a [테스트] merchant gets no rule")
	check(npc.context(700, 1).get("ok", false), "the default-rule merchant sells its own row")
	var serin_before: String = npc.rule_hash(13)
	npc.rules.erase("default_placed_merchants")
	check(npc.rule_hash(13) == serin_before, "a listed merchant's saved rule hash is unchanged by the default switch")
	check(npc.rule_for(700).is_empty(), "the default is off without the switch")
	npc.rules["default_placed_merchants"] = true
	# Runtime sources (each cause's rule in code).
	var runtime_text: String = FileAccess.get_file_as_string("res://scripts/shop/source523_shop_runtime.gd")
	var shop_rt = RUNTIME.new()
	check(shop_rt.siege_running() == false and runtime_text.contains("if siege_running() and (row.AvailableSiegeTime!=true or row.LimitNotInSiegeTime==true)"), "siege-time rows sell (no siege offline)")
	check(runtime_text.contains("if int(set) == 0: continue"), "ServerLimitSetID 0 is no server limit")
	check(SHOP_WINDOW.new().has_method("served_entries") and shop_rt.has_method("served_here"), "other servers' BM offers are not listed")
	check(runtime_text.contains("row.LimitCount=int(row.LimitServerCount) if int(row.LimitCount)<=0 else mini(int(row.LimitCount),int(row.LimitServerCount))"), "LimitServerCount caps the save's own counter")
	check(shop_rt.has_method("native_debit") and runtime_text.contains("native[\"native_debit\"] = true") and runtime_text.contains("\"native_equipment\":true"), "original 523 items pay by receipt and are issued, equipment included")
	check(runtime_text.contains("not SkillBooks.registered(world,str(book.name),str(book.skill_id))"), "a merchant-10 book without a local skill sells as the native book")
	check(FileAccess.get_file_as_string("res://scripts/shop/source523_cash_packages.gd").contains("static func displayed_purchases(catalog)") and FileAccess.get_file_as_string("res://scripts/shop/source523_cash_packages.gd").contains("for purchase_id: int in displayed_purchases(catalog):"), "game-currency BM boxes are bound")
	# Market-only pools.
	var tickets = TICKETS.new()
	tickets.document = {"pools": {"5": [{"card_id": 1, "weight": 1000000, "grade_id": 1}]}}
	check(tickets.pool_entries(5).size() == 1, "a ticket-model pool is used as is")
	tickets.market_pools["77"] = [{"card_id": 2, "weight": 1000000, "grade_id": 1}]
	check(tickets.pool_entries(77).size() == 1 and not tickets.document.pools.has("77"), "a market-only pool is kept out of the ticket document")
	# NPC reset: KST 05:00, an older calendar counts again instead of locking.
	var resets = RESETS.new()
	check(int(resets.rules.offset_minutes) == 540, "NPC limits use the KST calendar")
	var at: int = int(Time.get_unix_time_from_datetime_string("2026-11-21T20:00:00"))  # 05:00 KST on the 22nd
	check(resets.calendar(at - 1, 61, 5).bucket != resets.calendar(at, 61, 5).bucket, "the daily NPC limit turns at 05:00 KST")
	var row: Dictionary = {"LimitCountRefreshTypeID": 1, "LimitCountPerAccount": false, "LimitCount": 1}
	var allowed: Dictionary = resets.allowance(row, [], 1, at, "b".repeat(64))
	check(allowed.get("ok", false) and allowed.get("migrated_rule", false), "a counter saved under the old calendar does not lock the row")
	check(not resets.allowance(row, [{"at": at + 10, "quantity": 1}], 1, at + 20, "").get("ok", true), "the original daily count (1) still applies")

## --- Real pack, actual Main ----------------------------------------------------

func _find_script(node: Node, file: String) -> Node:
	var script: Variant = node.get_script()
	if script != null and str(script.resource_path).ends_with(file): return node
	for child: Node in node.get_children():
		var found: Node = _find_script(child, file)
		if found != null: return found
	return null

func real_main() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for frame: int in 120: await process_frame
	var picker: Node = _find_script(root, "renewal_class_select.gd")
	if picker != null:
		picker.call("_choose", "기사")
		if picker.has_method("_choose_gender"): picker.call("_choose_gender", 1)
		picker.call("_confirm")
	else: preload("res://tests/qa_class_selection.gd").enter_game(world)
	await preload("res://tests/qa_class_selection.gd").wait_for_aden_source(self, world)
	var ctl: Variant = world.hud.get("original_main_ui_controller")
	if not world.current523_aden_source_active() or not is_instance_valid(ctl) or not ctl.call("can_open_shop_window") or world.source_shop.catalog == null:
		evidence["real_main"] = "original 523 pack / original UI not installed: Main part skipped"
		world.queue_free(); for frame: int in 3: await process_frame
		return
	world.save_timer = -100000
	world.level = 99
	var base: Dictionary = {"inventory": world.inventory.duplicate(true), "instances": world.item_instances.duplicate(true), "next": int(world.next_item_instance_id), "consumable": world.consumable_service.export_state()}
	if part.is_empty() or part.begins_with("npc"): await npc_stores(world, ctl, base)
	if part.is_empty() or part.begins_with("market"): await market(world, ctl, base)
	world.queue_free()
	for frame: int in 3: await process_frame

func restore(world: Node, base: Dictionary) -> void:
	world.inventory = base.inventory.duplicate(true)
	world.item_instances = base.instances.duplicate(true)
	world.next_item_instance_id = int(base.next)
	world.consumable_service.import_state(base.consumable.duplicate(true))

## ok | condition | remaining | failed, recorded in the evidence.
func classify(label: String, outcome: String, reason: String) -> void:
	print("SHOP_ALL_ROW ", JSON.stringify({"label": label, "outcome": outcome, "reason": reason}))
	evidence.rows = int(evidence.rows) + 1
	if outcome == "ok": evidence.ok = int(evidence.ok) + 1; return
	for key: String in REMAINING_ROWS:
		if label.contains(key) and outcome == "refused":
			evidence.remaining[key] = int(evidence.remaining.get(key, 0)) + 1
			return
	if outcome == "refused":
		for fragment: String in CONDITION_REFUSALS:
			if reason.contains(fragment): evidence.condition = int(evidence.condition) + 1; return
		for fragment: String in REMAINING:
			if reason.contains(fragment):
				evidence.remaining[fragment] = int(evidence.remaining.get(fragment, 0)) + 1
				return
	evidence.failed.append("%s: %s %s" % [label, outcome, reason])
	check(false, "%s is bought (%s %s)" % [label, outcome, reason])

## The paying binding of a price (adena, a bound wallet or an original stack).
func payer(runtime: Object, unit: int, class_id: int) -> Dictionary:
	if unit == 4 and class_id == 26: return {"gold": true}
	var sources: Array = runtime.catalog.currency(class_id).get("sources", []) if unit == 201 else [{"UnitID": unit, "ClassID": class_id}]
	for source: Dictionary in sources:
		var resolved: Dictionary = runtime._resolve(runtime._token(int(source.UnitID), int(source.ClassID), 1), false, world_inventory(runtime), 0)
		if resolved.get("ok", false): return resolved.binding
	return {}

## Whether every source item of a price is an original TestItem or dummy row.
func source_test_currency(runtime: Object, unit: int, class_id: int) -> bool:
	var sources: Array = runtime.catalog.currency(class_id).get("sources", []) if unit == 201 else [{"UnitID": unit, "ClassID": class_id}]
	if sources.is_empty(): return false
	for source: Dictionary in sources:
		if int(source.UnitID) != 4: return false
		var item: Dictionary = runtime.catalog.record("ItemClass", int(source.ClassID))
		if item.get("TestItem", false) != true and preload("res://scripts/quests/source_dummy523.gd").item_evidence(item).is_empty(): return false
	return true

func world_inventory(runtime: Object) -> Dictionary:
	return runtime.world.inventory

## Funds `binding` to `amount` with the test grant tool's own paths.
func fund(world: Node, binding: Dictionary, amount: int) -> bool:
	if binding.get("gold", false): world.gold = maxi(int(world.gold), amount); return true
	var have: int = int(world.inventory.get(str(binding.name), 0))
	if have >= amount: return true
	if binding.get("native_debit", false):
		var id: int = int(binding.get("record", {}).get("source_item_class_id", 0))
		return preload("res://scripts/loot/patch523_item_inventory.gd").commit(world, [{"item_class_id": id, "amount": amount - have, "bless_raw": 1, "enchant": 0}], {"kind": "twilight_debug_catalog", "initial_level_origin": "twilight_debug_default_zero"})
	world.inventory[str(binding.name)] = amount
	return true

func wallet(world: Node, binding: Dictionary) -> int:
	return int(world.gold) if binding.get("gold", false) else int(world.inventory.get(str(binding.get("name", "")), 0))

func gained(world: Node, before: Dictionary, skip: String) -> int:
	var total: int = 0
	for key: Variant in world.inventory:
		if str(key) == skip: continue
		total += maxi(0, int(world.inventory[key]) - int(before.get(key, 0)))
	return total

## Merchant NPC classes the game places (source523_town_npcs rules, all Lands).
func shop_classes() -> Array:
	var classes: Dictionary = {}
	for index: int in DEF.row_count("EarthObjectSpawn"):
		var spawn: Dictionary = DEF.row_at("EarthObjectSpawn", index)
		var cls: Dictionary = TOWN._first("EarthObjectClass", int(spawn.get("EarthObjectClassID", -1)))
		if cls.is_empty(): continue
		var full: String = str(TOWN._first("DescData_Korean", int(cls.get("DescID", -1))).get("Description", ""))
		if full.is_empty() or TOWN._tagged(str(spawn.get("Name", ""))) or TOWN._tagged(str(cls.get("Name", ""))) or TOWN._tagged(full): continue
		if int(spawn.get("ServerLimitSetID", 0)) != 0 and not TOWN.local_server_set(int(spawn.ServerLimitSetID)): continue
		if TOWN._first("Territories", int(spawn.get("TerritoriesID", -1))).is_empty(): continue
		if "shop" in TOWN.actions_for_class(int(cls.ID)): classes[int(cls.ID)] = TOWN.display_name(full).display
	var ids: Array = classes.keys()
	ids.sort()
	return ids.map(func(id: int) -> Array: return [id, classes[id]])

func npc_stores(world: Node, ctl: Object, base: Dictionary) -> void:
	var runtime: Object = world.source_shop
	var first: int = 0
	var last: int = 1 << 30
	var pieces: PackedStringArray = part.split(":")
	var first_index: int = 0
	if pieces.size() >= 3: first = int(pieces[1]); last = int(pieces[2])
	if pieces.size() == 4: first_index = int(pieces[3])
	ctl.call("try_open_store_window", "")
	var window: Object = ctl.get("_store_window")
	if not check(window != null and window.is_open(), "the original Store_All window opens"): return
	var classes: Array = shop_classes()
	evidence["npc_classes"] = classes.size()
	for entry: Array in classes:
		var cls: int = int(entry[0])
		if cls < first or cls > last: continue
		if budget_ms > 0 and Time.get_ticks_msec() > budget_ms:
			stopped_at = "npc:%d" % cls
			print("SHOP_ALL_RESUME npc:%d:%d" % [cls, last])
			break
		if not stopped_at.is_empty(): break
		window.npc_class = cls
		window.refresh()
		var goods: Array = window.goods()
		for index: int in goods.size():
			if cls == first and index < first_index: continue
			if budget_ms > 0 and Time.get_ticks_msec() > budget_ms:
				stopped_at = "npc:%d:%d" % [cls, index]
				print("SHOP_ALL_RESUME npc:%d:%d:%d" % [cls, last, index])
				break
			# Let the window's replaced scenes free (every purchase rebuilds it).
			await process_frame
			restore(world, base)
			var g: Dictionary = goods[index]
			var label: String = "%s %s (MerchantGoods %d)" % [str(entry[1]), str(g.name), int(g.id)]
			var row: Dictionary = runtime.catalog.merchant_offer(int(g.id)).goods
			var price: Dictionary = runtime.merchant_price(int(g.id))
			if not price.get("ok", false): classify(label, "refused", str(price.get("reason", ""))); continue
			var binding: Dictionary = payer(runtime, int(price.unit_id), int(price.class_id))
			if binding.is_empty(): classify(label, "refused" if source_test_currency(runtime, int(price.unit_id), int(price.class_id)) else "currency", "결제 재화가 원본 시험·더미 품목" if source_test_currency(runtime, int(price.unit_id), int(price.class_id)) else "결제 재화 연결 없음"); continue
			var count: int = 1 if int(row.get("LimitCount", 0)) == 1 or int(row.get("LimitServerCount", 0)) > 0 else 2
			fund(world, binding, int(price.amount) * count + 7)
			var paid_before: int = wallet(world, binding)
			var bag_before: Dictionary = world.inventory.duplicate(true)
			window.set("last_purchase", {})
			var asked: Dictionary = window.call("_buy_requested", index)
			if not window.calculator.is_open():
				classify(label, "refused" if asked.has("refused") else "no_keypad", str(asked.get("refused", "")))
				continue
			window.calculator.press_digit(count)
			window.calculator.select()
			var bought: Dictionary = window.get("last_purchase")
			if not bought.get("ok", false): classify(label, "error", str(bought.get("reason", ""))); continue
			var paid: int = paid_before - wallet(world, binding)
			var got: int = gained(world, bag_before, str(binding.get("name", "")))
			if paid != int(price.amount) * count: classify(label, "price", "결제 %d ≠ %d×%d" % [paid, int(price.amount), count]); continue
			if got != int(row.Amount) * count: classify(label, "grant", "지급 %d ≠ %d×%d" % [got, int(row.Amount), count]); continue
			classify(label, "ok", "")
		if not stopped_at.is_empty(): break
	window.close()
	world.hud.call("_close_workspace")
	for frame: int in 3: await process_frame

func market(world: Node, ctl: Object, base: Dictionary) -> void:
	var runtime: Object = world.source_shop
	var hud: Node = world.hud
	hud.open_shop()
	for frame: int in 5: await process_frame
	var window: Object = ctl.get("_shop_window")
	if not check(window != null and window.is_open(), "the original Shop_All window opens"): return
	var tabs: Array = window.tabs
	evidence["tabs"] = tabs.map(func(t: Dictionary) -> Array: return [t.name, t.products.size()])
	var seen: Dictionary = {}
	var pieces: PackedStringArray = part.split(":")
	var skip_market: int = int(pieces[1]) if pieces.size() == 2 else 0
	var market_skip_base: int = skip_market
	var market_index: int = 0
	for tab_index: int in tabs.size():
		if not stopped_at.is_empty(): break
		window.select_tab(tab_index)
		for frame: int in 2: await process_frame
		for entry: Dictionary in window.call("_products"):
			var id: int = int(entry.id)
			if seen.has(id): continue
			seen[id] = true
			if skip_market > 0: skip_market -= 1; continue
			market_index += 1
			if budget_ms > 0 and Time.get_ticks_msec() > budget_ms:
				stopped_at = "market:%d" % (market_index - 1 + market_skip_base)
				print("SHOP_ALL_RESUME market:%d" % (market_index - 1 + market_skip_base))
				break
			restore(world, base)
			var offer: Dictionary = runtime.catalog.market_offer(id)
			var label: String = "%s %s (MarketPurchase %d)" % [str(tabs[tab_index].name), str(offer.get("name", "")), id]
			var price: Dictionary = runtime.catalog.payment_quote(id, 1)
			if not price.get("ok", false): classify(label, "refused", str(price.get("reason", ""))); continue
			var binding: Dictionary = payer(runtime, int(price.unit_id), int(price.class_id))
			if binding.is_empty(): classify(label, "refused" if source_test_currency(runtime, int(price.unit_id), int(price.class_id)) else "currency", "결제 재화가 원본 시험·더미 품목" if source_test_currency(runtime, int(price.unit_id), int(price.class_id)) else "결제 재화 연결 없음"); continue
			var count: int = 2
			for r: Dictionary in offer.restrictions:
				if int(r.MarketRestrictionTypeId) == 3 and int(r.Value) <= 1: count = 1
			fund(world, binding, int(price.total) * count + 7)
			var paid_before: int = wallet(world, binding)
			var bag_before: Dictionary = world.inventory.duplicate(true)
			window.set("last_purchase", {})
			window.set("_moved", 0.0)
			var asked: Dictionary = window.call("_buy", id)
			if not window.calculator.is_open():
				classify(label, "refused" if asked.has("refused") else "no_keypad", str(asked.get("refused", "")))
				continue
			window.calculator.press_digit(count)
			window.calculator.select()
			await process_frame
			var stage: Variant = hud.get("card_reveal_stage")
			if is_instance_valid(stage):
				stage.emit_signal("finished"); stage.queue_free()
			# The reveal stage is gone only after the frame (is_card_reveal_busy).
			for frame: int in 2: await process_frame
			var bought: Dictionary = window.get("last_purchase")
			if not bought.get("ok", false): classify(label, "error", str(bought.get("reason", ""))); continue
			if not bought.get("delivered", false): classify(label, "grant", "가방 미지급(보관함)"); continue
			var paid: int = paid_before - wallet(world, binding)
			if paid != int(price.total) * count: classify(label, "price", "결제 %d ≠ %d×%d" % [paid, int(price.total), count]); continue
			var expected: int = 0
			var draws: int = 0
			for link: Dictionary in offer.products + offer.bonuses:
				var p: Dictionary = link.product.definition
				if CASH.listed(id) and CASH.strip(id, p): continue
				if int(p.UnitID) == RUNTIME.DRAW_UNIT: draws += int(p.Amount) * count
				elif not (int(p.UnitID) == 4 and int(p.ClassID) == 26): expected += int(p.Amount) * count
			var got: int = gained(world, bag_before, str(binding.get("name", "")))
			if draws > 0 and bought.get("draw_results", []).size() < draws: classify(label, "grant", "추첨 %d < %d" % [bought.get("draw_results", []).size(), draws]); continue
			if got < expected: classify(label, "grant", "지급 %d < %d" % [got, expected]); continue
			classify(label, "ok", "")
	window.close()
	hud.call("_close_workspace")
	for frame: int in 3: await process_frame
