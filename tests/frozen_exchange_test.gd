extends SceneTree
const Runtime = preload("res://scripts/shop/source523_shop_runtime.gd")
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var checks: int = 0
var failures: int = 0
const Exchange = preload("res://scripts/exchange/frozen_exchange.gd")
const FrozenCatalog = preload("res://scripts/exchange/frozen_catalog.gd")

class Host extends Node:
	var patch523_owner_state_problem: String = ""
	var inventory: Dictionary = {"다이아":1000}
	var gold: int = 10000
	var level: int = 80
	var item_instances: Dictionary = {}
	var next_item_instance_id: int = 1
	var pending_map_save_record: Dictionary = {}
	var item_db: Array = []
	var catalog_db: Dictionary = {"아이템":[]}
	var item_weight_index: Dictionary = {}
	var source_shop
	func _update_hud() -> void: pass
	var capacity: int = 10000
	var reject_save: bool = false
	var saves: int = 0
	var during_save: Callable
	var locked: String = ""
	var native_supplier_available: bool = true
	var native_supplier_calls: int = 0
	func source_item_record(id: int, _bless: int = 1) -> Dictionary:
		return source_shop._bindings.get("4:%d" % id,{}).get("record",{}).duplicate(true) if native_supplier_available else {}
	func source_item_definition(id: int) -> Dictionary:
		return {"original_item":source_shop.catalog.record("ItemClass",id),"native_record":source_item_record(id)}
	func stage_source_item_grants(grants: Array, _origin: Dictionary) -> Dictionary:
		# Synthetic supplier adapter only. Actual native proofs are tested in Main.
		native_supplier_calls += 1
		var tokens: Array = []
		for grant: Dictionary in grants: tokens.append({"unit_id":4,"class_id":grant.item_class_id,"amount":grant.amount})
		var staged: Dictionary = source_shop._grant(tokens,inventory.duplicate(true),gold,item_instances.duplicate(true),next_item_instance_id)
		if not staged.ok: return {"ok":false,"error":staged.reason}
		return {"ok":true,"overrides":{"inventory":staged.inventory,"gold":staged.gold,"item_instances":staged.instances}}
	var path: String = "user://frozen-exchange-unit.json"
	func _find_catalog_item_record(name: String) -> Dictionary:
		for row: Dictionary in catalog_db["아이템"] + item_db:
			if row.name == name: return row
		return {}
	func _index_item_weights() -> void:
		for row: Dictionary in catalog_db["아이템"] + item_db: item_weight_index[str(row.name)] = int(row.get("weight",3))
	func _enhancement_kind_for_record(record: Dictionary) -> String:
		return "weapon" if record.get("slot") == "weapon" else ""
	func _item_locked(name: String, _id: String) -> bool: return name == locked
	func _carrying_capacity() -> int: return capacity
	func _save_game(_quiet: bool, override: Dictionary = {}) -> Error:
		if during_save.is_valid(): during_save.call()
		if reject_save: return ERR_CANT_CREATE
		var data: Dictionary = {"inventory":inventory,"gold":gold,"item_instances":item_instances,"next_item_instance_id":next_item_instance_id,Runtime.SAVE_KEY:source_shop.export_state()}
		data.merge(override,true)
		var result: Error = Writer.write(path,data)
		if result == OK:
			saves += 1
			pending_map_save_record.clear()
		return result

func _init() -> void: call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func timestamp(text: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(text))

func create_catalog(limited_merchant: bool = false) -> RefCounted:
	# Explicit synthetic rules: never counted as restored official server behavior.
	var tables: Dictionary = {}
	for table: String in Catalog.REQUIRED_TABLES: tables[table] = []
	tables.ItemClass = [{"ID":549,"Name":"fixture dragon","DescID":1,"Cost":100},{"ID":8941,"Name":"fixture gear","DescID":2,"Cost":100},{"ID":65291,"Name":"fixture scroll","DescID":3,"Cost":100},{"ID":3581,"Name":"fixture unbound scroll","DescID":4,"Cost":100},{"ID":26,"Name":"fixture gold","DescID":0,"Cost":0}]
	tables.DescData_Korean = [{"ID":1,"Description":"드래곤의 다이아몬드"},{"ID":2,"Description":"테스트 검"},{"ID":3,"Description":"축복 부여 주문서 (각인)"},{"ID":4,"Description":"축복 부여 주문서"}]
	tables.ItemClass.append({"ID":777,"Name":"fixture orb","DescID":5,"Cost":1})
	tables.DescData_Korean.append({"ID":5,"Description":"드래곤의 용옥"})
	tables.IntangibleItemClass = [{"ID":1,"Name":"Mileage"},{"ID":2,"Name":"Gem"}]
	tables.Currency = [{"ID":4,"Name":"Gem","DescID":0},{"ID":812,"Name":"Scroll","DescID":0},{"ID":3034,"Name":"ConsumeOnly","DescID":0}]
	tables.CurrencyUnitClass = [{"ID":1,"CurrencyID":4,"UnitID":34,"ClassID":2,"ForGive":true,"ConsumePriority":0},{"ID":2,"CurrencyID":812,"UnitID":4,"ClassID":65291,"ForGive":true,"ConsumePriority":0},{"ID":3,"CurrencyID":812,"UnitID":4,"ClassID":3581,"ForGive":false,"ConsumePriority":1},{"ID":4,"CurrencyID":3034,"UnitID":4,"ClassID":549,"ForGive":false,"ConsumePriority":0}]
	tables.DateTimes_Korean = [{"ID":1,"Year":2016,"Month":1,"Day":1,"Hour":0,"Minute":0},{"ID":2,"Year":2099,"Month":12,"Day":31,"Hour":23,"Minute":59}]
	tables.MarketPayment_Korean = [{"ID":1,"UnitID":201,"ClassID":4,"Amount":120,"MarketPaymentTypeID":4,"ClassChangeDiscount":false},{"ID":2,"UnitID":4,"ClassID":26,"Amount":100,"MarketPaymentTypeID":4,"ClassChangeDiscount":false}]
	tables.MarketProduct = [{"ID":1,"UnitID":4,"ClassID":549,"Amount":10},{"ID":2,"UnitID":34,"ClassID":1,"Amount":240},{"ID":3,"UnitID":4,"ClassID":8941,"Amount":1}]
	tables.MarketProduct.append({"ID":4,"UnitID":4,"ClassID":777,"Amount":1})
	for id: int in [1001,1002,1003,1004,1005,1006,1007,1008]:
		tables.MarketPurchase_Korean.append({"ID":id,"MarketPaymentID":2 if id==1008 else 1,"DescID":1,"DescriptionDescID":1,"EffectiveFromId":1,"EffectiveToId":2,"OnSale":true})
		tables.MarketPurchaseProduct.append({"MarketPurchaseID":id,"MarketProductID":4 if id==1007 else (3 if id==1006 else 1)})
		tables.MarketDisplay.append({"ID":id,"PurchaseID":id,"DisplayIndex":id})
	tables.MarketBonusForPurchase = [{"MarketPurchaseID":1001,"MarketProductID":2}]
	tables.MarketPurchaseRestriction = [{"MarketPurchaseId":1002,"MarketRestrictionTypeId":3,"ValueUnitId":1,"Value":2,"DurationUnitId":111,"DurationValue":1},{"MarketPurchaseId":1003,"MarketRestrictionTypeId":3,"ValueUnitId":1,"Value":1,"DurationUnitId":81,"DurationValue":1},{"MarketPurchaseId":1004,"MarketRestrictionTypeId":15,"ValueUnitId":1,"Value":1,"DurationUnitId":1,"DurationValue":0}]
	tables.MarketPurchaseServerLimitGroup = [{"MarketPurchaseID":1005,"ServerLimitSetID":274}]
	tables.ServerLimit = [{"ID":1,"ServerLimitSetID":274,"WorldNo":1,"ServiceRegionCode":"KR"}]
	tables.CumulativePurchase = [{"ID":1,"Name":"synthetic event","StartTimeID":1,"EndTimeID":2,"DailyRewardID":1,"ServerLimitsetID":0}]
	tables.CumulativePurchaseStep = [{"ID":1,"CumulativePurchaseID":1,"Step":1,"RewardID":1},{"ID":2,"CumulativePurchaseID":1,"Step":2,"RewardID":1}]
	tables.Reward = [{"ID":1,"RewardTypeID":2,"RewardClassID":549,"Amount":1,"ClanOnly":false,"UseImmediately":false,"CharacterClassID":0}]
	var merchant: Dictionary={}
	for field: String in Catalog.FIELDS.MerchantGoods:merchant[field]=false if field in Catalog.BOOLEAN_FIELDS else 0
	merchant.merge({"ID":1001,"MerchantsID":13,"ItemClassID":549,"Amount":2,"Percentage":118,"DialogActionTypeID":1,"AvailableSiegeTime":true,"MerchantGoodGUID":"fixture-guid","ElementalEnchant":0,"LimitClanMemberRank":false},true)
	if limited_merchant:merchant.merge({"LimitCount":2,"LimitCountPerAccount":false,"LimitCountRefreshTypeID":1},true)
	tables.MerchantGoods=[merchant]
	var provenance: Dictionary = {}
	for table: String in tables: provenance[table] = {"packed_rows":tables[table].size()}
	var pack: Dictionary = {"schema":Catalog.SCHEMA,"patch":523,"source_zip_sha256":Catalog.SOURCE_SHA256,"tables":tables,"provenance":provenance}
	var path: String = "user://frozen-exchange-catalog-fixture.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(pack));file.close()
	var result := Catalog.new()
	check(result.load_pack(path,FileAccess.get_sha256(path)), "synthetic catalog validates")
	return result

func setup(catalog) -> Dictionary:
	var host := Host.new()
	for record: Dictionary in [{"name":"드래곤의 다이아몬드","slot":"consumable","weight":3},{"name":"다이아","slot":"currency","weight":0},{"name":"축복 부여 주문서 (각인)","slot":"consumable","weight":3},{"name":"축복 부여 주문서","slot":"consumable","weight":3},{"name":"테스트 검","slot":"weapon","weight":3,"source":"inven","sourceId":"8941"}]: host.catalog_db["아이템"].append(record)
	host.catalog_db["아이템"].append({"name":"드래곤의 용옥","slot":"consumable","weight":3,"source":"inven","sourceId":"777"})
	var runtime := Runtime.new()
	host.source_shop = runtime
	runtime.configure(host)
	runtime.bind_source(catalog)
	# Explicit fixture native identities; the production runtime never installs these.
	for id: int in [549,8941,65291,3581,777]:
		var key: String = "4:%d" % id
		if not runtime._bindings.has(key): continue
		var record: Dictionary = runtime._bindings[key].record.duplicate(true)
		var display: String = str(record.name)
		record.merge({"name":display + " · 원본#" + str(id),"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:" + str(id),"source_m_native_item":true,"source_item_class_id":id,"source_display_name":display},true)
		runtime._bindings[key] = {"name":record.name,"record":record}
	var clock: Dictionary = {"now":timestamp("2026-11-03T12:00:00")}
	runtime.test_clock = func() -> int: return int(clock.now)
	return {"host":host,"runtime":runtime,"clock":clock}


func snapshot_fixture() -> Dictionary:
	# Entirely synthetic contract input, never installed as observed market data.
	return {"schema":"twilight.frozen-exchange.v1","status":"captured","captured_at":"2026-11-12T00:00:00Z","source_url":"https://example.test/fixture","coverage":{"scope":"all_servers","expected_server_ids":["fixture-server"],"completed_server_ids":["fixture-server"],"complete":true},"reset":{"timezone":"Asia/Seoul","hour":5},"price_policy":"frozen_once","listings":[{"listing_id":"synthetic-1","server_id":"fixture-server","item_class_id":549,"item_name":"드래곤의 다이아몬드","bundle_size":3,"bundle_price":7,"initial_bundles":2,"currency_unit_id":34,"currency_class_id":2,"enchant":0,"element":"","element_level":0,"attributes":{"blessed_type":1},"evidence_url":"https://example.test/synthetic-not-observed"}]}


func representative_fixture() -> Dictionary:
	# Synthetic schema exercise only; never installed as production observations.
	var value: Dictionary = snapshot_fixture()
	value["test_fixture"] = false
	value["coverage"] = {"scope":"representative_server","expected_server_ids":["server:1"],"completed_server_ids":["server:1"],"complete":false,"approximate":true,"selected_categories":[{"id":1,"name":"합성 장비"},{"id":3,"name":"합성 소모품"}],"omitted_categories":[{"id":5,"name":"합성 재료"}],"live_drift_recorded":true,"scope_proof":{"server_id":"server:1","world_id":"world:10001","evidence_url":"https://example.test/synthetic-servers","sha256":"a".repeat(64)},"survey":{"scope":"surveyed_candidates_only","metric":"reported_local_catalog_group_count","selected_server_id":"server:1","candidates":[{"server_id":"server:1","world_id":"world:10001","reported_total":100,"world_reported_total":60,"local_group_count":40,"evidence_url":"https://example.test/synthetic-server-1","sha256":"b".repeat(64),"world_evidence_url":"https://example.test/synthetic-world-1","world_sha256":"c".repeat(64)},{"server_id":"server:2","world_id":"world:10002","reported_total":50,"world_reported_total":20,"local_group_count":30,"evidence_url":"https://example.test/synthetic-server-2","sha256":"d".repeat(64),"world_evidence_url":"https://example.test/synthetic-world-2","world_sha256":"e".repeat(64)}]}}
	value.listings[0].server_id = "server:1"
	var world_row: Dictionary = value.listings[0].duplicate(true)
	world_row.server_id = "world:10001"
	world_row.attributes = {"blessed_type":2,"unmapped_variant":"synthetic-only"}
	value.listings.append(world_row)
	return value

func representative_contracts(source_catalog) -> void:
	var value: Dictionary = representative_fixture()
	var before: Dictionary = value.duplicate(true)
	check(FrozenCatalog.validate(value).is_empty() and value == before,"explicit approximate representative coverage validates without changing observed fields")
	var legacy_partial: Dictionary = snapshot_fixture();legacy_partial.coverage.complete = false
	check(not FrozenCatalog.validate(legacy_partial).is_empty(),"legacy all-server capture still requires complete coverage")
	for field: String in ["approximate","complete","live_drift_recorded"]:
		for invalid: Variant in [0,1,"true",{},null]:
			var broken: Dictionary = value.duplicate(true);broken.coverage[field] = invalid
			check(not FrozenCatalog.validate(broken).is_empty(),"representative boolean metadata rejects arbitrary JSON types: " + field)
	var malformed: Array[Dictionary] = []
	var broken: Dictionary = value.duplicate(true);broken.coverage.approximate = false;malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.complete = true;malformed.append(broken)
	broken = value.duplicate(true);broken.erase("test_fixture");malformed.append(broken)
	broken = value.duplicate(true);broken.test_fixture = true;malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.expected_server_ids = ["server:01"];broken.coverage.completed_server_ids = ["server:01"];malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.completed_server_ids = ["server:2"];malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.selected_categories = [];malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.omitted_categories = [{"id":1,"name":"선택과 중복"}];malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.selected_categories[0].id = true;malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.scope_proof.world_id = "world:10002";malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.scope_proof.sha256 = "x".repeat(64);malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.survey.metric = "actual_total_stock_bundles";malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.survey.candidates[0].reported_total = true;malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.survey.candidates[0].local_group_count = 41;malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.survey.candidates[1].reported_total = 70;broken.coverage.survey.candidates[1].local_group_count = 50;malformed.append(broken)
	broken = value.duplicate(true);broken.coverage.survey.candidates[0].world_evidence_url = "http://example.test";malformed.append(broken)
	broken = value.duplicate(true);broken.listings[0].server_id = "server:2";malformed.append(broken)
	broken = value.duplicate(true);broken.listings[1].server_id = "world:10002";malformed.append(broken)
	for rejected: Dictionary in malformed:
		check(not FrozenCatalog.validate(rejected).is_empty(),"representative scope evidence policy ranking and market mismatch rejected")
	var path: String = "user://representative-exchange-synthetic.json"
	install_fixture(value,path)
	var context: Dictionary = setup(source_catalog)
	var runtime = Exchange.new();runtime.configure(context.host,path)
	var id: String = FrozenCatalog.key(value.listings[0])
	var quote: Dictionary = runtime.quote(id)
	check(runtime.catalog.captured() and quote.ok and quote.total == 7 and quote.quantity == 3,"explicit representative partial snapshot opens exact full-bundle native purchase contract")
	check(not runtime.quote(FrozenCatalog.key(value.listings[1])).ok and runtime.catalog.rows()[1].attributes.has("unmapped_variant"),"representative shared-world unknown variant remains visible and purchase locked")
	check(runtime.buy(id).ok and context.host.inventory.get("다이아") == 993 and runtime.available(value.listings[0]) == 1,"representative purchase preserves frozen price bundle quantity and stock")
	context.host.free()

func install_fixture(value: Dictionary, path: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value));file.close()


class ExchangeHud extends Node:
	func refresh_inventory(_value: Dictionary) -> void: pass

func ui_contracts(catalog) -> void:
	var context: Dictionary = setup(catalog)
	var host = context.host
	root.add_child(host)
	var hud := ExchangeHud.new(); host.add_child(hud)
	var fixture: Dictionary = snapshot_fixture()

	for number: int in range(2,83):
		var extra: Dictionary = fixture.listings[0].duplicate(true)
		extra.listing_id = "synthetic-%d" % number
		fixture.listings.append(extra)
	var path: String = "user://frozen-exchange-ui-synthetic.json"
	install_fixture(fixture,path)
	var panel = preload("res://scripts/ui/frozen_exchange_panel.gd").new()
	root.add_child(panel); panel.configure(hud,path)

	check(panel.listing.item_count == panel.PAGE_SIZE and panel.filtered.size() == 82,"all-server UI bounds visible rows without dropping source listings")
	check(panel.categories.item_count == 1 and panel.categories.disabled,"legacy snapshots offer only the all-category view")
	panel._select(0);panel._review();panel.next_page.pressed.emit()
	check(panel.listing.item_count == 2 and not panel.confirm.visible and panel.selected_id.is_empty(),"pagination invalidates stale confirmation and shows final rows")
	panel.previous_page.pressed.emit()
	panel._select(0)
	var before: int = int(host.inventory["다이아"])
	panel._review()
	check(panel.confirm.visible and host.inventory["다이아"] == before,"review shows exact bundle total without charging")
	panel.cancel.pressed.emit()
	check(not panel.confirm.visible and host.inventory["다이아"] == before,"cancel clears pending charge")
	panel._review();panel.bundles.value = 2
	check(not panel.confirm.visible,"quantity change invalidates review")
	panel.bundles.value = 1;panel._review();panel._buy();panel._buy()
	check(host.inventory["다이아"] == before - 7 and host.inventory["드래곤의 다이아몬드 · 원본#549"] == 3,"duplicate confirm UI signals buy only once")
	panel.search.text = "missing";panel._filter()
	check(panel.filtered.is_empty() and panel.review.disabled,"search invalidates selection and payment")
	panel.free()
	var category_fixture: Dictionary = representative_fixture()
	category_fixture.listings[0]["category1_ids"] = [1.0]
	category_fixture.listings[1]["category1_ids"] = [3.0]
	var shared_equipment: Dictionary = category_fixture.listings[0].duplicate(true)
	shared_equipment.server_id = "world:10001"; shared_equipment.listing_id = "synthetic-shared-equipment"
	category_fixture.listings.append(shared_equipment)
	for number: int in range(2,83):
		var extra: Dictionary = category_fixture.listings[1].duplicate(true)
		extra.listing_id = "synthetic-consumable-%d" % number
		category_fixture.listings.append(extra)
	var category_path: String = "user://frozen-exchange-category-ui-synthetic.json"
	install_fixture(category_fixture,category_path)
	var category_panel = preload("res://scripts/ui/frozen_exchange_panel.gd").new()
	root.add_child(category_panel); category_panel.configure(hud,category_path)
	check(category_panel.categories.item_count == 3 and category_panel.categories.get_item_text(1) == "합성 장비" and category_panel.categories.get_item_text(2) == "합성 소모품","category selector uses selected source names and excludes omitted categories")
	category_panel.next_page.pressed.emit()
	category_panel.categories.select(1); category_panel.categories.item_selected.emit(1)
	check(category_panel.filtered.size() == 2 and category_panel.page == 0 and category_panel.selected_id.is_empty() and not category_panel.confirm.visible,"category filter finds equipment behind consumables using JSON numeric IDs and resets page and review")
	category_panel.servers.select(1); category_panel.servers.item_selected.emit(1)
	check(category_panel.filtered.size() == 1 and category_panel.filtered[0].server_id == "server:1","category and server selections intersect")
	category_panel.search.text = "missing"; category_panel._filter()
	check(category_panel.filtered.is_empty() and category_panel.review.disabled,"category server and search selections intersect without enabling payment")
	category_panel.search.text = ""; category_panel.categories.select(0); category_panel.servers.select(0); category_panel._filter()
	check(category_panel.filtered.size() == 84 and category_panel.listing.item_count == category_panel.PAGE_SIZE,"clearing all filters restores every source listing with bounded visible rows")
	category_panel.free();host.free()

func _run() -> void:
	var context: Dictionary = setup(create_catalog())
	var host = context.host
	var shop = context.runtime
	var fixture: Dictionary = snapshot_fixture()
	var path: String = "user://frozen-exchange-synthetic.json"
	install_fixture(fixture,path)
	var exchange = Exchange.new();exchange.configure(host,path)
	check(exchange.catalog.captured(),"synthetic snapshot passes catalog contract")
	check(Exchange.day_at(timestamp("2026-11-11T19:59:59")) + 1 == Exchange.day_at(timestamp("2026-11-11T20:00:00")),"05:00 KST exact UTC reset boundary")
	check(Exchange.day_at(timestamp("2026-11-11T19:59:59")) == Exchange.day_at(timestamp("2026-11-11T00:00:00")),"device-independent KST bucket before reset")
	context.clock.now = timestamp("2026-11-11T19:59:59")
	var row: Dictionary = fixture.listings[0]
	var id: String = FrozenCatalog.key(row)
	for attributes: Dictionary in [{},{"blessed_type":0},{"blessed_type":2},{"blessed_type":3},{"blessed_type":1,"unmapped":true}]:
		var unknown: Dictionary = fixture.duplicate(true);unknown.listings[0].attributes = attributes
		install_fixture(unknown,"user://frozen-exchange-unproved-blessing.json")
		var locked_exchange = Exchange.new();locked_exchange.configure(host,"user://frozen-exchange-unproved-blessing.json")
		check(not locked_exchange.quote(id).ok,"wildcard missing blessed cursed and unknown blessing attributes stay locked")
	# Arbitrary JSON attribute values must fail closed without a Variant
	# comparison error, a native grant, or any wallet/stock/disk mutation.
	var invalid_type_wallet: Dictionary = host.inventory.duplicate(true)
	var invalid_type_stock: Dictionary = shop.export_state()
	var invalid_type_instances: Dictionary = host.item_instances.duplicate(true)
	var invalid_type_save: Error = host._save_game(true)
	var invalid_type_bytes: PackedByteArray = FileAccess.get_file_as_bytes(host.path) if invalid_type_save == OK else PackedByteArray()
	var invalid_type_grants: int = host.native_supplier_calls
	for bad_type: Variant in [true,false,"1",{},null]:
		var invalid: Dictionary = fixture.duplicate(true)
		invalid.listings[0].attributes = {"blessed_type":bad_type}
		var invalid_path: String = "user://frozen-exchange-invalid-blessing-type.json"
		install_fixture(invalid,invalid_path)
		var invalid_exchange = Exchange.new();invalid_exchange.configure(host,invalid_path)
		var refused_quote: bool = not invalid_exchange.quote(id).ok
		var refused_buy: bool = not invalid_exchange.buy(id).ok
		check(invalid_type_save == OK and refused_quote and refused_buy and host.inventory == invalid_type_wallet and shop.export_state() == invalid_type_stock and host.item_instances == invalid_type_instances and host.native_supplier_calls == invalid_type_grants and FileAccess.get_file_as_bytes(host.path) == invalid_type_bytes,"invalid blessing JSON type stays locked and preserves wallet stock native instances and save: " + JSON.stringify(bad_type))
	host.native_supplier_available = false
	check(not exchange.quote(id).ok and not host.inventory.has("드래곤의 다이아몬드"),"missing native supplier cannot fall back to legacy shop binding")
	host.native_supplier_available = true
	var quote: Dictionary = exchange.quote(id,2)
	if not quote.ok: print("EXCHANGE_QUOTE_FAILURE ",quote)
	check(quote.ok and quote.total == 14 and quote.quantity == 6,"bundle price and quantity multiply without averaging or splitting")
	check(exchange.buy(id,2).ok and host.inventory["다이아"] == 986 and host.inventory["드래곤의 다이아몬드 · 원본#549"] == 6,"real shop binding debits and grants exact full bundles")
	check(exchange.available(row) == 0 and not exchange.buy(id).ok,"exhausted initial stock cannot be bought twice")
	if not FileAccess.file_exists(host.path): quit(1); return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.path))
	check(saved.source_shop.frozen_exchange.consumed[id] == 2 and saved.inventory["다이아"] == 986,"stock and wallet share durable atomic save")
	shop.accept_load(saved)
	check(exchange.available(row) == 0,"restart preserves same-day depletion")
	context.clock.now += 1
	check(exchange.available(row) == 2,"05:00 KST restores exactly initial bundles without changing price")
	check(exchange.quote(id).total == 7 and exchange.buy(id).ok,"after reset fixed captured price remains unchanged")
	context.clock.now -= 1
	check(not exchange.buy(id).ok,"clock reversal cannot replay prior daily stock")
	context.clock.now += 2
	host.reject_save = true
	var inventory_before: Dictionary = host.inventory.duplicate(true)
	var stock_before: Dictionary = shop.export_state()
	var disk_hash: String = FileAccess.get_sha256(host.path)
	check(not exchange.buy(id).ok and host.inventory == inventory_before and shop.export_state() == stock_before and FileAccess.get_sha256(host.path) == disk_hash,"save failure preserves wallet stock inventory and disk")
	check(shop.save_blocked and not exchange.buy(id).ok,"ambiguous save outcome locks retries until reload")
	host.reject_save = false;shop.accept_load(JSON.parse_string(FileAccess.get_file_as_string(host.path)))
	var nested: Dictionary = {}
	host.during_save = func() -> void: nested.assign(exchange.buy(id))
	check(exchange.buy(id).ok and not nested.ok,"reentrant exchange purchase shares existing transaction lock")
	host.during_save = Callable()
	context.clock.now += 86400
	host.capacity = 1
	check(not exchange.buy(id).ok,"overweight order neither charges diamonds nor consumes stock")
	host.capacity = 10000
	for bad: int in [0,-1,1001]: check(not exchange.buy(id,bad).ok,"invalid bundle count rejected %d" % bad)
	fixture.listings[0].enchant = 7;install_fixture(fixture,path)
	var changed = Exchange.new();changed.configure(host,path)
	check(not changed.buy(id).ok,"changed snapshot identity cannot silently reset existing stock")
	shop.state.erase(Exchange.STATE_KEY)
	check(not changed.buy(id).ok,"enhanced listing stays locked instead of granting a plain item")
	fixture.listings[0].enchant = 0;fixture.listings[0].attributes = {"refinement":"synthetic"};install_fixture(fixture,path);changed.configure(host,path)
	check(not changed.buy(id).ok,"unknown refinements stay locked")
	fixture.listings[0].attributes = {"blessed_type":1};fixture.listings[0].item_name = "wrong";install_fixture(fixture,path);changed.configure(host,path)
	check(not changed.buy(id).ok,"API item identifier cannot masquerade as another static ItemClass")

	fixture.listings[0].item_name = "드래곤의 다이아몬드";install_fixture(fixture,path);changed.configure(host,path)
	for original: Dictionary in shop.catalog._tables.get("ItemClass",[]):
		if original.ID == 549: original.Name = "기간 상품"
	check(not changed.buy(id).ok,"period and deletion semantics cannot bypass native shop exclusion")
	for original: Dictionary in shop.catalog._tables.get("ItemClass",[]):
		if original.ID == 549: original.Name = "fixture dragon"
	check(not FrozenCatalog.https("https:///") and not FrozenCatalog.https("https://name:secret@example.test") and not FrozenCatalog.https("https://example.test/a b"),"URL validation rejects malformed or credential-bearing source links")
	var missing_timestamp: Dictionary = snapshot_fixture();missing_timestamp.erase("captured_at")
	check(not FrozenCatalog.validate(missing_timestamp).is_empty(),"missing timestamp rejected")
	check(not FrozenCatalog.validate({}).is_empty(),"malformed catalog rejected")
	var production: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FrozenCatalog.PATH))
	check(FrozenCatalog.validate(production).is_empty(),"production snapshot validates its explicit capture scope")
	var blank = Exchange.new();blank.configure(host)
	if production.status == "not_captured":
		check(not blank.buy(id).ok and blank.catalog.rows().is_empty(),"production not-captured state exposes no fake listing")
	else:
		check(blank.catalog.captured() and blank.catalog.rows().size() == production.listings.size() and (production.coverage.scope != "representative_server" or production.get("test_fixture") == false),"production representative observations stay separate from synthetic fixtures")
	var malformed: Dictionary = Exchange.fresh_state();malformed.consumed[id] = 1
	check(not Exchange.validate_state(malformed).is_empty(),"stock without snapshot identity rejected")
	host.free()
	ui_contracts(create_catalog())
	representative_contracts(create_catalog())
	print("FROZEN_EXCHANGE_RESULT checks=%d failures=%d synthetic_contract_only" % [checks,failures])
	quit(1 if failures else 0)
