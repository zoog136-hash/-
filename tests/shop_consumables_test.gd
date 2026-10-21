extends SceneTree

const SHOP = preload("res://scripts/shop/shop_catalog.gd")
const STOCK = preload("res://scripts/shop/consumable_stock.gd")
const RULES = preload("res://scripts/consumable_rules.gd")
const PACK_ITEMS = preload("res://scripts/card_pack_items.gd")
const BUYBACK = preload("res://scripts/shop/local_buyback.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SHOP_CONSUMABLES_FAIL: " + detail)

func _run() -> void:
	var old: Dictionary = {}
	for entry: Array in SHOP.LEGACY_GOODS: old[str(entry[0])] = int(entry[1])
	check(SHOP.GOODS.size() > old.size(), "shop is expanded")
	for record: Dictionary in RULES.records():
		check(SHOP.price_for(str(record.name)) > 0, "rule consumable available: " + str(record.name))
	for item_name: String in PACK_ITEMS.PACKS:
		check(SHOP.price_for(item_name) > 0, "each draw ticket and 11-pack available: " + item_name)
	for item_name: String in ["화살", "총알"]:
		check(SHOP.price_for(item_name) > 0, "ammunition available")
	var records: Array = STOCK.records()
	var by_name: Dictionary = {}
	for record: Dictionary in records:
		var item_name: String = str(record.name)
		by_name[item_name] = record
		if int(record.get("heal", 0)) > 0 and str(record.get("slot", "")) == "consumable":
			check(SHOP.price_for(item_name) > 0, "every active HP tier available: " + item_name)
		if bool(record.get("crafting_material", false)) or bool(record.get("crafting_scroll", false)):
			check(SHOP.price_for(item_name) < 0, "crafting materials stay out: " + item_name)
	var seen: Dictionary = {}
	for entry: Array in SHOP.GOODS:
		var item_name: String = str(entry[0])
		var price: int = int(entry[1])
		check(not seen.has(item_name), "unique offer: " + item_name)
		seen[item_name] = true
		check(str(entry[2]) in ["물약", "소모품", "강화 주문서"], "visible in existing UI filters")
		if old.has(item_name):
			check(price == int(old[item_name]), "legacy price preserved: " + item_name)
		else:
			check(by_name.has(item_name), "new stock has an implemented source")
			var record: Dictionary = by_name.get(item_name, {}) as Dictionary
			check(not STOCK.category_for(record).is_empty(), "new stock is usable")
			check(price > int(BUYBACK.GRADE_BUYBACK.get(str(record.get("grade", "일반")), 0)), "no new buy/sell profit loop")
		var count: int = 1 if item_name == "드래곤의 용옥" else 3
		var quote: Dictionary = SHOP.quote(item_name, count, price * count, 0, 1000, 1)
		check(bool(quote.get("ok", false)) and int(quote.get("total", -1)) == price * count, "authoritative total for " + item_name)
		check(not bool(SHOP.quote(item_name, count, price * count - 1, 0, 1000, 1).get("ok", false)), "funds rechecked")
		check(not bool(SHOP.quote(item_name, count, price * count, 1000, 1000, 1).get("ok", false)), "weight rechecked")
	for item_name: String in RULES.STATUS_CLEANSERS:
		check(SHOP.price_for(item_name) < 0, "deleted cleanser excluded")
	for item_name: String in ["드래곤의 용옥 (각인)", "드래곤의 용옥(각인)", "진명황의 집행검", "철 광석"]:
		check(SHOP.price_for(item_name) < 0, "no alias/restricted purchase bypass: " + item_name)
	var fixture: Array = [
		{"name":"회복 시험", "slot":"consumable", "heal":50, "grade":"일반"},
		{"name":"회복 시험", "slot":"consumable", "heal":50, "grade":"일반"},
		{"name":"버프 시험 물약", "slot":"consumable", "desc":"지속 시간 300초 · 공격 속도 +10"},
		{"name":"영구 장비", "slot":"weapon", "desc":"지속 시간 300초 · 공격 속도 +10"},
		{"name":"제작 시험", "slot":"consumable", "crafting_material":true, "heal":50},
		{"name":"해독제", "slot":"consumable", "heal":50},
		{"name":"미구현 시험", "slot":"consumable"},
		{"name":"퀘스트 시험", "slot":"consumable", "quest_item":true, "heal":50},
		{"name":"드래곤의 용옥 (각인)", "slot":"consumable"}
	]
	var snapshot: Array = fixture.duplicate(true)
	var result: Array = STOCK.build_from_records([], fixture)
	check(result.size() == 2, "fixture includes only healing and timed consumables")
	check(fixture == snapshot, "builder never mutates source records")
	check(STOCK.build_from_records([], fixture) == result, "stable sorted order")
	check(not STOCK._has_duration("지속 시간 0초"), "zero duration is not usable")
	if failures == 0: print("SHOP_CONSUMABLES_OK goods=%d checks=%d" % [SHOP.GOODS.size(), checks])
	quit(0 if failures == 0 else 1)
