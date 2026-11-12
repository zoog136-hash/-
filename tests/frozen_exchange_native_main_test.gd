extends SceneTree
## One observed row with synthetic coverage and a test-funded wallet, never production.
const QA = preload("res://tests/qa_class_selection.gd")
const Exchange = preload("res://scripts/exchange/frozen_exchange.gd")
const FrozenCatalog = preload("res://scripts/exchange/frozen_catalog.gd")
const Definitions = preload("res://scripts/resources/current523_definition_rows.gd")
const SamplePath: String = "res://evidence/exchange/research-20261112/normal_111852_world10014_page1.json"
const ReceiptPath: String = "res://evidence/exchange/research-20261112/normal_111852_world10014_page1.receipt.json"
const SampleSHA: String = "a16c6d008eef7e5bd770a2407d5119046c48a57dbeaa0d544a1cf9726cb88bc9"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func run() -> void:
	if OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty():
		push_error("PRIVATE_INPUT_UNAVAILABLE TWILIGHT_PATCH523_CONTENT")
		quit(1); return
	check(Definitions.identity().get("source_sha256") == Definitions.SOURCE_SHA,"exact private original definitions selected")
	check(FileAccess.get_sha256(SamplePath) == SampleSHA,"preserved observed stock response identity")
	if failures: quit(1); return
	var production_bytes: PackedByteArray = FileAccess.get_file_as_bytes(FrozenCatalog.PATH)
	var production: Dictionary = JSON.parse_string(production_bytes.get_string_from_utf8())
	check(FrozenCatalog.validate(production).is_empty(),"production declared scope validates and observed-row test fixture remains separate")
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ReceiptPath))
	check(receipt.get("explicit_blessed_type") == 1 and receipt.get("sha256") == SampleSHA and str(receipt.get("url","")).contains("&blessedType=1&"),"normal blessing proved by explicit official type1 request, not wildcard0 or blessingLevel")
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SamplePath)).contents[0]
	var price: int = int(sample.salePrice)
	var quantity: int = int(sample.quantity)
	var test_funds: int = price * 3
	check(sample.itemId == 111852 and sample.itemName == "진명황의 갑옷" and sample.enchantLevel == 0 and sample.quantity > 0 and sample.salePrice > 0,"observed unmodified normal listing and bundle price")
	var row: Dictionary = {"server_id":"world:10014","listing_id":"observed-stock-row-1-test-only","item_class_id":int(sample.itemId),"item_name":sample.itemName,"bundle_size":int(sample.quantity),"bundle_price":int(sample.salePrice),"initial_bundles":1,"currency_unit_id":34,"currency_class_id":2,"enchant":int(sample.enchantLevel),"element":"","element_level":0,"attributes":{"blessed_type":int(receipt.explicit_blessed_type)},"evidence_url":str(receipt.url)}
	# The complete flag describes a synthetic one-scope contract fixture, never
	# all-server collection. The row and its observation time come from the probe.
	var fixture: Dictionary = {"schema":"twilight.frozen-exchange.v1","status":"captured","captured_at":str(receipt.request_completed_at_utc).substr(0,19) + "Z","source_url":"https://lineagem.plaync.com/price/itemprice/index","test_fixture":"observed_row_synthetic_coverage_test_wallet","coverage":{"scope":"all_servers","expected_server_ids":["world:10014"],"completed_server_ids":["world:10014"],"complete":true},"reset":{"timezone":"Asia/Seoul","hour":5},"price_policy":"frozen_once","listings":[row]}
	var fixture_path: String = "user://exchange-observed-row-test-only.json"
	var fixture_file := FileAccess.open(fixture_path,FileAccess.WRITE)
	fixture_file.store_string(JSON.stringify(fixture));fixture_file.close()
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	check(QA.enter_game(world),"actual Main class selection with original definitions")
	world.player.set_physics_process(false)
	var native: Dictionary = world.source_item_definition(111852).get("native_record",{})
	check(native.get("source_m_native_item",false) and native.get("sourceId") == "m523:item:111852" and native.get("name") == "진명황의 갑옷 · 원본#111852","actual native DTO identity exists")
	var shop = world.source_shop
	check(shop.catalog.record("IntangibleItemClass",2).get("Name") == "Gem" and shop.catalog.label(4716) == "다이아","actual source diamond identity")
	# Isolated test funds only; this is not a real account or a live purchase.
	world.inventory["다이아"] = test_funds
	var before_legacy: int = int(world.inventory.get("진명황의 갑옷",0))
	check(world._save_game(true) == OK,"actual Main baseline save with explicit test wallet")
	var wildcard: Dictionary = fixture.duplicate(true)
	var unknown_sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://evidence/exchange/stock_111852_world10014_enchant0_page1.json")).contents[0]
	wildcard.listings[0].attributes = {}
	wildcard.listings[0].bundle_size = int(unknown_sample.quantity)
	wildcard.listings[0].bundle_price = int(unknown_sample.salePrice)
	wildcard.listings[0].evidence_url = "https://api-goats.plaync.com/lms/v2.0/price/search/item/111852/stock?serverId=10014&enchantLevel=0&blessedType=0&page=1&size=5"
	var wildcard_path: String = "user://exchange-wildcard-row-locked-test.json"
	var wildcard_file := FileAccess.open(wildcard_path,FileAccess.WRITE)
	wildcard_file.store_string(JSON.stringify(wildcard));wildcard_file.close()
	var unproved = Exchange.new();unproved.configure(world,wildcard_path)
	var id: String = FrozenCatalog.key(row)
	check(not unproved.quote(id).ok and int(world.inventory["다이아"]) == test_funds,"preserved wildcard sample stays locked even though blessingLevel is zero")
	var exchange = Exchange.new();exchange.configure(world,fixture_path)
	var path: String = world.save_path()
	var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var quote: Dictionary = exchange.quote(id)
	if not quote.ok: print("NATIVE_EXCHANGE_QUOTE_FAILURE ",quote)
	check(quote.ok and int(quote.get("total",0)) == price and int(quote.get("quantity",0)) == quantity,"actual native supplier stages observed full bundle")
	check(FileAccess.get_file_as_bytes(path) == before and int(world.inventory["다이아"]) == test_funds,"quote preserves save and test wallet")
	if not quote.ok:
		world.queue_free();await process_frame
		print("FROZEN_EXCHANGE_NATIVE_MAIN_RESULT checks=%d failures=%d observed_row_synthetic_coverage_test_wallet" % [checks,failures])
		quit(1);return
	var outcome: Dictionary = exchange.buy(id)
	if not outcome.ok: print("NATIVE_EXCHANGE_PURCHASE_FAILURE ",outcome)
	check(outcome.ok and int(world.inventory["다이아"]) == test_funds - price and exchange.available(row) == 0,"actual atomic debit and full bundle stock depletion")
	if not outcome.ok:
		world.queue_free();await process_frame
		print("FROZEN_EXCHANGE_NATIVE_MAIN_RESULT checks=%d failures=%d observed_row_synthetic_coverage_test_wallet" % [checks,failures])
		quit(1);return
	var native_name: String = str(native.name)
	check(int(world.inventory.get(native_name,0)) == quantity and int(world.inventory.get("진명황의 갑옷",0)) == before_legacy,"only original ItemClass inventory key is granted")
	var physical_id: String = ""
	for value_id: String in world.item_instances:
		var value: Dictionary = world.item_instances[value_id]
		if value.get("name") != native_name: continue
		physical_id = value_id
		check(value.get("record",{}).get("source_item_class_id") == 111852 and value.get("source_m_reward_proof",{}).get("supplier",{}).get("snapshot_sha256") == exchange.catalog.sha256 and value.get("source_m_reward_proof",{}).get("supplier",{}).get("observed_blessed_type") == 1 and value.get("source_m_reward_proof",{}).get("bless") == 1 and value.get("level") == 0,"native physical instance keeps exact source and frozen supplier receipt")
	check(not physical_id.is_empty(),"native equipment physical instance exists")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(saved.inventory.get("다이아",0)) == test_funds - price and int(saved.source_shop.frozen_exchange.consumed.get(id,0)) == 1 and saved.item_instances.has(physical_id),"native item wallet and consumed stock share durable save")
	world._load_game(true)
	check(not world.source_save_blocked and world.patch523_owner_state_problem.is_empty() and int(world.inventory.get(native_name,0)) == quantity and world.item_instances.has(physical_id) and int(world.inventory.get("다이아",0)) == test_funds - price and exchange.available(row) == 0,"actual reload preserves native receipt wallet and depletion")
	var reloaded_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	check(not exchange.buy(id).ok and FileAccess.get_file_as_bytes(path) == reloaded_bytes,"exhausted observed row cannot charge twice")
	check(FileAccess.get_file_as_bytes(FrozenCatalog.PATH) == production_bytes,"isolated observed-row test never changes production data")
	world.queue_free();await process_frame
	print("FROZEN_EXCHANGE_NATIVE_MAIN_RESULT checks=%d failures=%d observed_row_synthetic_coverage_test_wallet" % [checks,failures])
	quit(1 if failures else 0)
