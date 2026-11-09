extends SceneTree
## Actual Main: converted cash offers are bought with diamonds, claimed, and the
## boxes opened through the real inventory activation path.
##   TWILIGHT_PATCH523_CONTENT=<original zip> godot --headless --path . \
##     --script res://tests/source523_cash_market_main_test.gd -- \
##     --source523-shop-pack=<shop523.json> --source523-shop-sha256=<sha>
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
const CashMarket = preload("res://scripts/shop/source523_cash_market.gd")
const CashPackages = preload("res://scripts/shop/source523_cash_packages.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: int = 0

func _init() -> void: call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _box(world: Node) -> String:
	for name: String in world.inventory:
		if world._find_catalog_item_record(name).get("source") == CashPackages.TAG: return name
	return ""

func _run() -> void:
	if not Catalog.session().available():
		print("source523_cash_market_main_test: shop pack absent; skipped")
		quit(0)
		return
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	check(QA.enter_game(world), "actual class selection confirmed")
	world.player.set_physics_process(false)
	world.inventory["다이아"] = 1000000
	check(world._save_game(true) == OK, "isolated save written")
	var shop = world.source_shop
	var bought: int = 0
	var opened: int = 0
	var weight_blocked: Array = []
	var cards_before: int = 0
	for category: String in ["변신", "마법인형", "성물"]: cards_before += world.card_draw_fusion.owned[category].size()
	CashPackages.rng.seed = 9
	for key: String in CashMarket.data().entries:
		var id: int = int(key)
		var quote: Dictionary = shop.quote(id, 1)
		check(quote.ok, "Main quote %s: %s" % [CashMarket.entry(id).name, quote.get("reason", "")])
		if not quote.ok: continue
		var before: int = int(world.inventory["다이아"])
		var result: Dictionary = shop.buy(id, 1)
		check(result.ok and int(world.inventory["다이아"]) == before - int(CashMarket.entry(id).diamonds), "Main purchase " + str(CashMarket.entry(id).name))
		for order: Dictionary in shop.orders():
			if int(order.offer_id) == id: check(shop.claim(str(order.id)).ok, "Main claim " + str(CashMarket.entry(id).name))
		bought += 1
		for guard: int in range(64):
			var box: String = _box(world)
			if box.is_empty(): break
			var count: int = int(world.inventory[box])
			var spec: Dictionary = CashPackages.definition(int(world._find_catalog_item_record(box).source_item_class_id))
			if spec.kind == "select":
				var choices: Array = CashPackages.options(spec, CashPackages.current_class(world))
				if choices.is_empty(): world.inventory.erase(box); continue
				var picked: Dictionary = CashPackages.open(world, box, [choices[0]])
				check(picked.ok, "Main select open %s: %s" % [box, picked.get("reason", "")])
			else:
				# Received stacks accumulate in this test; drop owner-less ones (a real
				# player would use/store them) so the weight rule does not stop the run.
				var physical: Dictionary = {}
				for value: Variant in world.item_instances.values(): physical[str(value.get("name", ""))] = true
				for name: String in world.inventory.keys():
					if name != "다이아" and not physical.has(name) and world._find_catalog_item_record(name).get("source") != CashPackages.TAG: world.inventory.erase(name)
				world._on_inventory_item_activated(box)
				if int(world.inventory.get(box, 0)) == count:
					# The existing weight rule may refuse a large stack; the box must stay.
					var rolled: Dictionary = CashPackages.roll_bag(spec, CashPackages.current_class(world), CashPackages.rng)
					var retry: Dictionary = CashPackages.open(world, box, rolled.get("rewards", []))
					var blocked: bool = not retry.ok and str(retry.get("reason", "")).begins_with("무게 한도 초과") and int(world.inventory.get(box, 0)) == count
					check(retry.ok or blocked, "bag %s: %s" % [box, retry.get("reason", "")])
					if blocked:
						weight_blocked.append(box)
						world.inventory.erase(box)
						continue
			check(int(world.inventory.get(box, 0)) == count - 1, "one box consumed: " + box)
			if int(world.inventory.get(box, 0)) != count - 1: world.inventory.erase(box)
			opened += 1
	var cards_after: int = 0
	for category: String in ["변신", "마법인형", "성물"]: cards_after += world.card_draw_fusion.owned[category].size()
	var waiting: Array = []
	for row: Dictionary in world.catalog_db["아이템"]:
		if row.get("source") == CashPackages.ITEM_TAG: waiting.append(str(row.name))
	print("source523_cash_market_main_test: class=%s bought=%d opened=%d new_cards=%d" % [world.job_class, bought, opened, cards_after - cards_before])
	print("source523_cash_market_main_test: kept by existing weight rule (%d): %s" % [weight_blocked.size(), ", ".join(weight_blocked)])
	print("source523_cash_market_main_test: waiting items (%d): %s" % [waiting.size(), ", ".join(waiting)])
	check(bought == 29, "all 29 offers bought in Main")
	check(weight_blocked.is_empty(), "original weights let every box open: %s" % ", ".join(weight_blocked))
	for name: String in ["상급 축복의 가루", "드래곤의 다이아몬드", "명예 주화", "판도라의 컬렉션 조각"]:
		check(int(world.item_weight_index.get(name, -1)) == 0, "original zero weight kept: " + name)
	check(world._save_game(true) == OK, "final save")
	print("source523_cash_market_main_test: %d checks, %d failures" % [checks, failures])
	world.queue_free()
	quit(1 if failures > 0 else 0)
