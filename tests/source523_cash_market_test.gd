extends SceneTree
## Converted cash-store offers: price table contract (always) and, with the
## private original inputs, real purchase -> claim -> box opening per original
## LuckyBag/SelectReward definitions.
##   TWILIGHT_PATCH523_CONTENT=<original 523 zip> godot --headless --path . \
##     --script res://tests/source523_cash_market_test.gd -- \
##     --source523-shop-pack=<shop523.json> --source523-shop-sha256=<sha>
const Runtime = preload("res://scripts/shop/source523_shop_runtime.gd")
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
const CashMarket = preload("res://scripts/shop/source523_cash_market.gd")
const CashPackages = preload("res://scripts/shop/source523_cash_packages.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const Cards = preload("res://scripts/cards/current523_card_catalog.gd")
const Fusion = preload("res://scripts/card_draw_fusion.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var checks: int = 0
var failures: int = 0

class Hud extends Node:
	var messages: Array = []
	func show_message(text: String) -> void: messages.append(text)
	func refresh_inventory(_inventory: Dictionary) -> void: pass
	func append_log(_text: String) -> void: pass

class Host extends Node:
	var inventory: Dictionary = {"다이아":1000000}
	var gold: int = 0
	var level: int = 80
	var job_class: String = "기사"
	var item_instances: Dictionary = {}
	var next_item_instance_id: int = 1
	var pending_map_save_record: Dictionary = {}
	var patch523_owner_state_problem: String = ""
	var item_db: Array = []
	var catalog_db: Dictionary = {"아이템":[], "변신":[], "마법인형":[], "성물":[]}
	var item_weight_index: Dictionary = {}
	var card_draw_fusion = Fusion.new()
	var hud: Hud = Hud.new()
	var source_shop
	var saves: int = 0
	var path: String = "user://source-cash-market-test.json"
	func _find_catalog_item_record(name: String, _source_id: String = "") -> Dictionary:
		for row: Dictionary in catalog_db["아이템"] + item_db:
			if row.name == name: return row
		return {}
	func _catalog_item_from_source_id(_id: String) -> Dictionary: return {}
	func _index_item_weights() -> void:
		for row: Dictionary in catalog_db["아이템"] + item_db: item_weight_index[str(row.name)] = int(row.get("weight", 3))
	func _enhancement_kind_for_record(record: Dictionary) -> String:
		return "armor" if record.get("slot") in ["armor", "accessory"] else ""
	func _item_locked(_name: String, _id: String = "") -> bool: return false
	func _carrying_capacity() -> int: return 100000000
	func _save_game(_quiet: bool, override: Dictionary = {}) -> Error:
		var data: Dictionary = {"inventory":inventory, "item_instances":item_instances, "next_item_instance_id":next_item_instance_id, "card_draw_fusion":card_draw_fusion.export_state()}
		if source_shop != null: data[Runtime.SAVE_KEY] = source_shop.export_state()
		data.merge(override, true)
		var result: Error = Writer.write(path, data)
		if result == OK: saves += 1
		return result

func _init() -> void: call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _contract() -> void:
	var data: Dictionary = CashMarket.data()
	check(not data.is_empty(), "cash market data loads and every recorded price matches the rate")
	check(int(data.rate.diamonds) == 2000 and int(data.rate.krw) == 55000, "rate is 2000 diamonds = 55,000 KRW")
	check(data.entries.size() == 29, "29 displayed cash offers are listed")
	var expected: Dictionary = {3300:120, 5500:200, 6000:219, 6500:237, 11000:400, 33000:1200, 55000:2000, 110000:4000}
	for krw: int in expected: check(CashMarket.diamonds_for(krw, data.rate) == expected[krw], "conversion %d won" % krw)
	for key: String in data.entries:
		var entry: Dictionary = data.entries[key]
		check(str(entry.origin.get("url", "")).begins_with("https://"), "price origin recorded for " + str(entry.name))
		check(not str(entry.name).ends_with(" 다이아"), "diamond top-ups are excluded")
		var quote: Dictionary = CashMarket.payment_quote(int(key), 2)
		check(quote.ok and int(quote.unit_id) == 201 and int(quote.class_id) == 4 and int(quote.total) == int(entry.diamonds) * 2, "diamond quote for " + str(entry.name))
		for other: Variant in entry.duplicate_store_purchase_ids:
			check(not CashMarket.payment_quote(int(other), 1).ok and CashMarket.duplicate_of(int(other)) == int(key), "store duplicate row is not sold separately")
	check(CashMarket.hidden(951, {"UnitID":37}), "unlisted store row (120 다이아) is hidden")
	check(not CashMarket.hidden(951, {"UnitID":201}), "non-store payments are untouched")

func _pack_arguments() -> Array:
	var path: String = ""
	var sha: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source523-shop-pack="): path = argument.trim_prefix("--source523-shop-pack=")
		if argument.begins_with("--source523-shop-sha256="): sha = argument.trim_prefix("--source523-shop-sha256=")
	return [path, sha]

func _integration() -> void:
	var args: Array = _pack_arguments()
	if str(args[0]).is_empty() or SOURCE.identity().is_empty():
		print("source523_cash_market_test: private inputs absent; integration skipped")
		return
	var catalog: RefCounted = Catalog.new()
	check(catalog.load_pack(str(args[0]), str(args[1])), "shop pack loads")
	var host: Host = Host.new()
	root.add_child(host)
	var built: Dictionary = Cards.build()
	for category: String in ["변신", "마법인형", "성물"]: host.catalog_db[category] = built.catalog[category]
	host.card_draw_fusion.configure(host.catalog_db)
	host.catalog_db["아이템"].append({"name":"다이아", "slot":"currency", "type":"화폐", "stackable":true, "weight":0})
	var runtime = Runtime.new()
	host.source_shop = runtime
	runtime.configure(host)
	runtime.bind_source(catalog)
	var opened: int = 0
	var cards: int = 0
	var gotcha_opened: int = 0
	CashPackages.rng.seed = 523
	for key: String in CashMarket.data().entries:
		var id: int = int(key)
		var entry: Dictionary = CashMarket.entry(id)
		var before: int = int(host.inventory["다이아"])
		var quote: Dictionary = runtime.quote(id, 1)
		check(quote.ok, "quote %s: %s" % [entry.name, quote.get("reason", "")])
		if not quote.ok: continue
		check(int(quote.payment.amount) == int(entry.diamonds), "charged diamonds for " + str(entry.name))
		for token: Dictionary in quote.goods: check(not (int(token.unit_id) == 34 and int(token.class_id) == 2), "no diamonds granted back by " + str(entry.name))
		var bought: Dictionary = runtime.buy(id, 1)
		check(bought.ok and int(host.inventory["다이아"]) == before - int(entry.diamonds), "purchase debits diamonds for " + str(entry.name))
		var order_id: String = ""
		for order: Dictionary in runtime.orders():
			if int(order.offer_id) == id: order_id = str(order.id)
		var claimed: Dictionary = runtime.claim(order_id)
		check(claimed.ok, "claim %s: %s" % [entry.name, claimed.get("reason", "")])
		# Open every box received (nested boxes included) until none remain.
		for guard: int in range(64):
			var box: String = ""
			for name: String in host.inventory:
				if host._find_catalog_item_record(name).get("source") == CashPackages.TAG: box = name; break
			if box.is_empty(): break
			var spec: Dictionary = CashPackages.definition(int(host._find_catalog_item_record(box).source_item_class_id))
			var rewards: Array = []
			if spec.kind == "select":
				var choices: Array = CashPackages.options(spec, CashPackages.current_class(host))
				check(not choices.is_empty(), "select box has options for 기사: " + box)
				if choices.is_empty(): host.inventory.erase(box); continue
				rewards = [choices[0]]
			elif spec.kind == "gotcha":
				rewards = CashPackages.roll_gotcha(spec, CashPackages.rng)
				var count: int = 0
				for draw: Dictionary in spec.draws: count += int(draw.count)
				check(rewards.size() == count, "gotcha draws original count: " + box)
				gotcha_opened += 1
			else:
				var rolled: Dictionary = CashPackages.roll_bag(spec, CashPackages.current_class(host), CashPackages.rng)
				check(rolled.ok, "bag yields rewards for 기사: " + box)
				if not rolled.ok: host.inventory.erase(box); continue
				rewards = rolled.rewards
			var owned_before: int = 0
			for category: String in Fusion.CATEGORIES: owned_before += host.card_draw_fusion.owned[category].size() + host.card_draw_fusion.spare[category].values().reduce(func(a, b): return a + b, 0)
			var result: Dictionary = CashPackages.open(host, box, rewards)
			check(result.ok, "open %s: %s" % [box, result.get("reason", "")])
			if not result.ok: host.inventory.erase(box); continue
			opened += 1
			var owned_after: int = 0
			for category: String in Fusion.CATEGORIES: owned_after += host.card_draw_fusion.owned[category].size() + host.card_draw_fusion.spare[category].values().reduce(func(a, b): return a + b, 0)
			cards += owned_after - owned_before
	check(opened >= 29, "boxes opened: %d" % opened)
	check(gotcha_opened > 0, "original card draw packs opened: %d" % gotcha_opened)
	print("source523_cash_market_test: card draw packs opened %d" % gotcha_opened)
	print("source523_cash_market_test: opened %d boxes, %d cards received" % [opened, cards])
	var waiting: Array = []
	for row: Dictionary in host.catalog_db["아이템"]:
		if row.get("source") == CashPackages.ITEM_TAG: waiting.append("%s#%d" % [row.name, int(row.source_item_class_id)])
	print("source523_cash_market_test: reward items without a TWILIGHT owner (%d): %s" % [waiting.size(), ", ".join(waiting)])
	var unresolved_cards: Array = []
	for id: Variant in CashPackages._definitions:
		for entry: Dictionary in CashPackages._definitions[id].get("entries", []):
			var item_id: int = int(entry.item_class_id)
			if int(entry.get("card_id", 0)) > 0:
				if CashPackages._card_target(host, int(entry.card_id)).is_empty(): unresolved_cards.append("BuffCard#%d" % int(entry.card_id))
			elif not CashPackages.card_reference(item_id).is_empty() and CashPackages.resolve(host, item_id).kind != "card": unresolved_cards.append(CashPackages.label(item_id))
	print("source523_cash_market_test: card items without a matching card (%d): %s" % [unresolved_cards.size(), ", ".join(unresolved_cards)])
	check(unresolved_cards.is_empty(), "every original card reward resolves to a TWILIGHT card")
	host.queue_free()

func _run() -> void:
	_contract()
	_integration()
	print("source523_cash_market_test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
