extends SceneTree
## Observed +6 normal equipment, isolated fixture coverage and test-funded wallet.
## Negative variants below are synthetic rejection cases, never production data.
const QA = preload("res://tests/qa_class_selection.gd")
const Exchange = preload("res://scripts/exchange/frozen_exchange.gd")
const FrozenCatalog = preload("res://scripts/exchange/frozen_catalog.gd")
const Definitions = preload("res://scripts/resources/current523_definition_rows.gd")
const NativeFields = preload("res://scripts/loot/current523_native_fields.gd")
const NativeItems = preload("res://scripts/loot/patch523_monster_drops.gd")
const SamplePath: String = "res://evidence/exchange/representative-enhanced-20261112/7e058e0c5da70ae1ee00e25786eb7fa7572920d296d0f43260dbbca458ceb1d1.json"
const ReceiptPath: String = "res://evidence/exchange/representative-enhanced-20261112/7e058e0c5da70ae1ee00e25786eb7fa7572920d296d0f43260dbbca458ceb1d1.receipt.json"
const SampleSHA: String = "5df2ec6d34f37949f8ee9b64feec59873b92fe4a571d3df718fd17dd6fa2bc0e"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)

func install_fixture(fixture: Dictionary, path: String) -> void:
	var output := FileAccess.open(path,FileAccess.WRITE)
	output.store_string(JSON.stringify(fixture));output.close()

func expect_locked(world: Node, fixture: Dictionary, changes: Dictionary, tag: String, expected_reason: String = "") -> void:
	var bad: Dictionary = fixture.duplicate(true)
	bad.listings[0].merge(changes,true)
	var path: String = "user://exchange-enhanced-negative-" + tag + ".json"
	install_fixture(bad,path)
	var exchange = Exchange.new();exchange.configure(world,path)
	var id: String = FrozenCatalog.key(bad.listings[0])
	var before: PackedByteArray = FileAccess.get_file_as_bytes(world.save_path())
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	var quote: Dictionary = exchange.quote(id)
	var outcome: Dictionary = exchange.buy(id)
	check(not quote.ok and not outcome.ok and (expected_reason.is_empty() or str(quote.get("reason","")).contains(expected_reason)),tag + " stays locked before native grant")
	check(world.inventory == inventory and world.item_instances == instances and FileAccess.get_file_as_bytes(world.save_path()) == before,tag + " preserves wallet physical items and durable save")

func finish(world: Node) -> void:
	if world != null:
		world.queue_free()
		await process_frame
	print("FROZEN_EXCHANGE_ENHANCED_MAIN_RESULT checks=%d failures=%d observed_enhanced_row_synthetic_coverage_test_wallet" % [checks,failures])
	quit(1 if failures else 0)

func run() -> void:
	if OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty():
		push_error("PRIVATE_INPUT_UNAVAILABLE TWILIGHT_PATCH523_CONTENT")
		quit(1);return
	check(Definitions.identity().get("source_sha256") == Definitions.SOURCE_SHA,"exact original 523 definitions selected")
	check(FileAccess.get_sha256(SamplePath) == SampleSHA,"observed enhanced stock raw response identity")
	if failures: await finish(null);return
	var production_bytes: PackedByteArray = FileAccess.get_file_as_bytes(FrozenCatalog.PATH)
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ReceiptPath))
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SamplePath)).contents[0]
	check(receipt.get("http_status") == 200 and receipt.get("sha256") == SampleSHA and str(receipt.get("url","")).contains("&blessedType=1&") and str(receipt.url).contains("&enchantLevel=6&"),"explicit normal-type and exact enhancement official query")
	check(sample.itemId == 111852 and sample.serverId == 10014 and sample.enchantLevel == 6 and sample.itemName == "+6 진명황의 갑옷" and sample.quantity == 1 and sample.salePrice == 22000,"observed enhanced item bundle and price unchanged")
	if failures: await finish(null);return
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false)
	check(QA.enter_game(world),"actual Main enters game with original definitions")
	world.player.set_physics_process(false)
	var native: Dictionary = world.source_item_definition(int(sample.itemId)).get("native_record",{})
	var canonical_name: String = str(NativeFields.field(native,"source_display_name",""))
	check(native.get("source_m_native_item",false) and native.get("sourceId") == "m523:item:111852" and NativeItems.equipment(native) and NativeFields.field(native,"source_equipment_status","") == "mapped" and int(native.get("source_bless_raw",0)) == 1,"exact native normal equipment has a mapped equipment owner")
	check(canonical_name == "진명황의 갑옷" and sample.itemName == "+%d %s" % [int(sample.enchantLevel),canonical_name],"observed enhancement prefix exactly matches original name")
	if failures: await finish(world);return
	var price: int = int(sample.salePrice)
	var quantity: int = int(sample.quantity)
	var enchant: int = int(sample.enchantLevel)
	var row: Dictionary = {"server_id":"world:10014","listing_id":"observed-enhanced-row-test-only","item_class_id":int(sample.itemId),"item_name":canonical_name,"observed_item_name":sample.itemName,"bundle_size":quantity,"bundle_price":price,"initial_bundles":1,"currency_unit_id":34,"currency_class_id":2,"enchant":enchant,"element":"","element_level":0,"attributes":{"blessed_type":1},"evidence_url":str(receipt.url)}
	# This one-scope complete coverage is synthetic and only exists in user://.
	# The observed row's name, quantity, enhancement and price are unmodified.
	var fixture: Dictionary = {"schema":"twilight.frozen-exchange.v1","status":"captured","captured_at":str(receipt.request_completed_at_utc).substr(0,19) + "Z","source_url":"https://lineagem.plaync.com/price/itemprice/index","test_fixture":"observed_enhanced_row_synthetic_coverage_test_wallet","coverage":{"scope":"all_servers","expected_server_ids":["world:10014"],"completed_server_ids":["world:10014"],"complete":true},"reset":{"timezone":"Asia/Seoul","hour":5},"price_policy":"frozen_once","listings":[row]}
	var test_funds: int = price * 3
	world.inventory["다이아"] = test_funds
	check(world._save_game(true) == OK,"isolated actual Main baseline with explicit test funds")
	expect_locked(world,fixture,{"observed_item_name":"+5 " + canonical_name},"wrong-observed-enhancement","강화 매물")
	expect_locked(world,fixture,{"attributes":{"blessed_type":2}},"unproved-blessing")
	expect_locked(world,fixture,{"attributes":{"blessed_type":1,"refinements":["synthetic rejection fixture"]}},"unproved-refinement")
	expect_locked(world,fixture,{"element":"synthetic rejection fixture","element_level":1},"unproved-element")
	var gold_native: Dictionary = world.source_item_definition(26).get("native_record",{})
	var gold_name: String = str(NativeFields.field(gold_native,"source_display_name",""))
	check(not gold_name.is_empty() and not NativeItems.equipment(gold_native),"negative non-equipment case uses an actual source currency")
	expect_locked(world,fixture,{"item_class_id":26,"item_name":gold_name,"observed_item_name":"+6 " + gold_name},"non-equipment-enhancement","강화 매물")
	var fixture_path: String = "user://exchange-observed-enhanced-test-only.json"
	install_fixture(fixture,fixture_path)
	var exchange = Exchange.new();exchange.configure(world,fixture_path)
	var id: String = FrozenCatalog.key(row)
	var path: String = world.save_path()
	var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var quote: Dictionary = exchange.quote(id)
	if not quote.ok: print("ENHANCED_EXCHANGE_QUOTE_FAILURE ",quote)
	check(quote.ok and int(quote.get("total",0)) == price and int(quote.get("quantity",0)) == quantity,"native supplier quotes the entire observed enhanced bundle")
	check(FileAccess.get_file_as_bytes(path) == before and int(world.inventory["다이아"]) == test_funds,"enhanced quote preserves durable save and test funds")
	if not quote.ok: await finish(world);return
	var outcome: Dictionary = exchange.buy(id)
	if not outcome.ok: print("ENHANCED_EXCHANGE_PURCHASE_FAILURE ",outcome)
	check(outcome.ok and int(world.inventory["다이아"]) == test_funds - price and exchange.available(row) == 0,"atomic observed-price debit and one-bundle depletion")
	if not outcome.ok: await finish(world);return
	var physical_id: String = ""
	var native_name: String = str(native.name)
	for value_id: String in world.item_instances:
		var physical: Dictionary = world.item_instances[value_id]
		if physical.get("name") != native_name: continue
		physical_id = value_id
		var proof: Dictionary = physical.get("source_m_reward_proof",{})
		check(int(physical.get("level",-1)) == enchant and int(proof.get("enchant",-1)) == enchant and int(proof.get("bless",0)) == 1 and physical.get("bless_state") == "normal","physical level and native ownership proof preserve observed +6 normal variant")
		check(proof.get("supplier",{}).get("snapshot_sha256") == exchange.catalog.sha256 and int(proof.get("supplier",{}).get("observed_enchant",-1)) == enchant and proof.get("supplier",{}).get("evidence_url") == receipt.url,"supplier proof retains the frozen observation and exact enhancement")
	check(not physical_id.is_empty() and int(world.inventory.get(native_name,0)) == quantity,"original enhanced equipment physical instance and inventory key exist")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.item_instances.has(physical_id) and int(saved.item_instances.get(physical_id,{}).get("level",-1)) == enchant and int(saved.item_instances.get(physical_id,{}).get("source_m_reward_proof",{}).get("enchant",-1)) == enchant and int(saved.inventory.get("다이아",0)) == test_funds - price and int(saved.source_shop.frozen_exchange.consumed.get(id,0)) == 1,"one durable save owns observed level proof wallet and consumed stock")
	world._load_game(true)
	var reloaded: Dictionary = world.item_instances.get(physical_id,{})
	check(not world.source_save_blocked and world.patch523_owner_state_problem.is_empty() and int(reloaded.get("level",-1)) == enchant and int(reloaded.get("source_m_reward_proof",{}).get("enchant",-1)) == enchant and int(world.inventory.get(native_name,0)) == quantity and int(world.inventory.get("다이아",0)) == test_funds - price and exchange.available(row) == 0,"actual reload preserves enhanced ownership proof wallet and depletion")
	var reloaded_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	check(not exchange.buy(id).ok and FileAccess.get_file_as_bytes(path) == reloaded_bytes,"exhausted enhanced row cannot charge twice")
	check(FileAccess.get_file_as_bytes(FrozenCatalog.PATH) == production_bytes,"observed-row test never rewrites production capture")
	await finish(world)
