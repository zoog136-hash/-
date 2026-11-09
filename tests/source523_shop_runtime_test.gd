extends SceneTree
const Runtime = preload("res://scripts/shop/source523_shop_runtime.gd")
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var checks: int = 0
var failures: int = 0

class Host extends Node:
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
	var capacity: int = 10000
	var reject_save: bool = false
	var saves: int = 0
	var during_save: Callable
	var locked: String = ""
	var path: String = "user://source-shop-runtime-unit.json"
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
	var path: String = "user://source-shop-runtime-fixture.json"
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
	var clock: Dictionary = {"now":timestamp("2026-11-03T12:00:00")}
	runtime.test_clock = func() -> int: return int(clock.now)
	return {"host":host,"runtime":runtime,"clock":clock}

func _run() -> void:
	var catalog = create_catalog()
	var context: Dictionary = setup(catalog)
	var host = context.host
	var runtime = context.runtime
	check(runtime.quote(1001,1).ok, "funded verified offer can be purchased")
	check(not runtime.quote(1007).ok,"source offers cannot bypass existing dragon-orb monthly purchase and price rules")
	check(not runtime.quote(1001,0).ok and not runtime.quote(1001,1001).ok, "invalid batch sizes rejected")
	var bought: Dictionary = runtime.buy(1001,1)
	check(bought.ok and host.inventory["다이아"] == 880, "purchase debits actual currency")
	check(not host.inventory.has("드래곤의 다이아몬드") and runtime.orders().size()==1, "payment creates inbox without granting goods")
	var after_purchase: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.path))
	check(after_purchase.inventory["다이아"]==880 and after_purchase.source_shop.orders[bought.order_id].status=="pending", "payment and pending order are durable together")
	host.reject_save = true
	var before: Dictionary = runtime.export_state()
	var hash_before: String = FileAccess.get_sha256(host.path)
	check(not runtime.claim(bought.order_id).ok and runtime.state==before and FileAccess.get_sha256(host.path)==hash_before, "claim save failure preserves order and disk")
	check(not host.inventory.has("드래곤의 다이아몬드"), "failed save grants nothing")
	host.reject_save = false
	host.capacity = 1
	check(not runtime.claim(bought.order_id).ok and runtime.orders().size()==1, "overweight claim retains paid inbox")
	host.capacity = 10000
	check(runtime.claim(bought.order_id).ok, "claim succeeds after capacity restored")
	check(host.inventory["드래곤의 다이아몬드"]==10 and host.inventory["마일리지"]==240 and host.inventory["다이아"]==880, "goods and bonus granted once without second debit")
	check(not runtime.claim(bought.order_id).ok and host.inventory["드래곤의 다이아몬드"]==10, "duplicate claim rejected")
	var reload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.path))
	runtime.accept_load(reload)
	check(not runtime.claim(bought.order_id).ok, "restart does not resurrect claimed order")
	var bag_before: Dictionary = host.inventory.duplicate(true)
	host.reject_save = true
	check(not runtime.buy(1001,1).ok and host.inventory==bag_before and runtime.orders().is_empty(), "failed purchase save consumes no currency and creates no order")
	host.reject_save = false
	var nested: Dictionary = {}
	host.during_save = func() -> void: nested.assign(runtime.buy(1001,1))
	check(runtime.buy(1001,1).ok and not nested.ok, "reentrant transaction rejected")
	host.during_save = Callable()
	check(runtime.buy(1002,2).ok and not runtime.buy(1002,1).ok, "bundle purchase counts attempts rather than delivered item quantity")
	check(runtime.quote(1003).ok and int(runtime.calendar_offset_minutes)==540 and int(runtime.period_reset_hour["81"])==5, "limited offers open with the default KST 05:00 calendar")
	runtime.calendar_offset_minutes = null
	check(not runtime.quote(1003).ok, "an explicit null calendar keeps limits locked")
	runtime.calendar_offset_minutes = 0
	runtime.period_reset_hour = {"81":0,"61":0,"71":0,"11311":0}
	check(runtime.buy(1003).ok and not runtime.buy(1003).ok, "monthly account cap enforced")
	context.clock.now = timestamp("2026-12-01T00:00:00")
	check(runtime.buy(1003).ok, "explicit calendar month reset permits next purchase")
	context.clock.now = timestamp("2026-11-30T23:59:59")
	check(not runtime.buy(1001).ok, "clock rollback cannot reset purchase allowance")
	context.clock.now = timestamp("2026-12-01T00:00:01")
	check(not runtime.quote(1004).ok and not runtime.quote(1005).ok, "unknown restriction and missing server context cannot be bypassed")
	runtime.server_context = {"world_no":1,"region":"KR"}
	check(runtime.quote(1005).ok, "exact explicit server context matches separate server gate")
	host.gold = 50
	check(not runtime.buy(1008).ok and host.gold==50, "direct item gold payment cannot make wallet negative")
	host.inventory["축복 부여 주문서 (각인)"]=3
	host.inventory["축복 부여 주문서"]=3
	check(not runtime._resolve(runtime._token(201,812,2),false,host.inventory,host.gold).ok, "ambiguous mixed currency priority stays locked")
	host.inventory.erase("축복 부여 주문서")
	check(runtime._resolve(runtime._token(201,812,2),false,host.inventory,host.gold).binding.name=="축복 부여 주문서 (각인)", "one funded currency source resolves without inventing priority")
	check(not runtime._resolve(runtime._token(201,3034,1),true,host.inventory,host.gold).ok, "consume-only currency cannot be issued")
	var corrupt: Dictionary = runtime.export_state()
	corrupt.next_order = 1
	check(not Runtime.validate(corrupt).is_empty(), "order sequence reuse rejected")
	corrupt = runtime.export_state();corrupt.orders[bought.order_id].goods[0].amount = -1
	check(not Runtime.validate(corrupt).is_empty(), "malformed saved grant rejected")
	host.free()
	context = setup(catalog);host=context.host;runtime=context.runtime
	host.inventory["테스트 검"]=1
	host.item_instances={"7":{"name":"테스트 검","level":6}}
	host.next_item_instance_id=8
	bought=runtime.buy(1006)
	check(bought.ok and runtime.claim(bought.order_id).ok, "equipment order can be received")
	check(host.item_instances["7"].level==6 and host.item_instances["8"].level==0 and host.next_item_instance_id==9, "new physical gear ID does not change existing enhancement")
	host.free()
	context=setup(catalog);host=context.host;runtime=context.runtime
	runtime.calendar_offset_minutes=0
	runtime.daily_purchase_ids.assign([1001])
	check(runtime.claim_cumulative(1,0).ok and not runtime.claim_cumulative(1,0).ok, "daily free reward is separate and claimed only once")
	check(not runtime.claim_cumulative(1,1).ok, "step reward requires received daily purchase")
	bought=runtime.buy(1001)
	check(bought.ok and runtime.cumulative_view(1).activated_days==0, "payment alone does not activate cumulative reward")
	check(runtime.claim(bought.order_id).ok and runtime.cumulative_view(1).activated_days==1, "inbox receipt activates exactly one daily step")
	check(runtime.claim_cumulative(1,1).ok and not runtime.claim_cumulative(1,1).ok, "step reward is atomic and non-repeatable")
	bought=runtime.buy(1001);runtime.claim(bought.order_id)
	check(runtime.cumulative_view(1).activated_days==1, "multiple receipts in one day activate once")
	context.clock.now=timestamp("2026-11-04T04:59:59")
	check(runtime.cumulative_view(1).activated_days==1 and not runtime.claim_cumulative(1,0).ok, "Wednesday before 05 stays in previous board/day")
	context.clock.now=timestamp("2026-11-04T05:00:00")
	check(runtime.cumulative_view(1).activated_days==0 and runtime.claim_cumulative(1,0).ok, "Wednesday 05 starts a new board and free reward")
	check(not runtime.claim_cumulative(1,1).ok, "expired board steps cannot be received on new board")
	context.clock.now=timestamp("2026-11-04T04:59:59")
	check(not runtime.claim_cumulative(1,0).ok, "clock rollback cannot repeat previous-day free reward")
	host.free()
	context=setup(catalog);host=context.host;runtime=context.runtime
	var price: Dictionary=runtime.merchant_price(1001)
	check(price.ok and price.amount==236 and str(price.origin).contains("TWILIGHT"),"NPC fallback uses source inputs and labels its configurable formula")
	check(not runtime.quote_merchant(1001).ok,"economic fallback does not authorize unresolved technical availability")
	runtime.calendar_offset_minutes=0
	runtime.daily_purchase_ids.assign([1001])
	runtime.merchant_prices={"1001":{"goods_sha256":runtime.merchant_signature(1001),"time_unrestricted":true}}
	var merchant_buy: Dictionary=runtime.buy_merchant(1001,3)
	check(merchant_buy.ok and host.gold==9292 and runtime.orders()[0].display_name=="드래곤의 다이아몬드","NPC purchase uses authoritative batch price and persistent named inbox")
	check(runtime.claim(merchant_buy.order_id).ok and host.inventory["드래곤의 다이아몬드"]==6 and host.gold==9292,"NPC receipt grants bundle quantity without a second charge")
	check(runtime.cumulative_view(1).activated_days==0,"NPC ID collision cannot activate a market daily purchase reward")
	runtime.merchant_prices["1001"]["amount"]=999
	runtime.merchant_prices["1001"]["unit_id"]=4
	runtime.merchant_prices["1001"]["class_id"]=26
	check(not runtime.quote_merchant(1001).ok,"explicit price without provenance rejected")
	runtime.merchant_prices["1001"]["origin"]="fixture verified original price"
	check(runtime.quote_merchant(1001).payment.amount==999,"explicit researched price overrides fallback")
	runtime.merchant_prices["1001"]["goods_sha256"]="wrong"
	check(not runtime.quote_merchant(1001).ok,"merchant policy cannot be reused for changed source conditions")
	var policy: Dictionary={"schema":"twilight.source523.shop-policy.v1","pack_sha256":catalog.loaded_sha256,"calendar_offset_minutes":0,"merchant_prices":{"1001":{"goods_sha256":runtime.merchant_signature(1001),"time_unrestricted":true}}}
	var policy_path: String="user://source-shop-policy-fixture.json"
	var policy_file:=FileAccess.open(policy_path,FileAccess.WRITE);policy_file.store_string(JSON.stringify(policy));policy_file.close()
	var policy_hash: String=FileAccess.get_sha256(policy_path)
	check(not runtime.load_policy(policy_path,"a".repeat(64)).ok and runtime.load_policy(policy_path,policy_hash).ok,"explicit local policy is hash checked before atomic application")
	check(runtime.buy_merchant(1001).ok and runtime.state.policy_sha256==policy_hash,"transactions bind reset and price policy to durable state")
	runtime.policy_sha256="b".repeat(64)
	check(not runtime.buy_merchant(1001).ok,"changed policy cannot reset a saved allowance")
	var bad_policy: Dictionary=runtime.export_state();bad_policy.policy_sha256=42
	check(not Runtime.validate(bad_policy).is_empty(),"malformed persisted policy hash rejected")
	bad_policy=runtime.export_state();bad_policy.npc_rule_hashes={"13":true}
	check(not Runtime.validate(bad_policy).is_empty(),"malformed per-NPC policy identity rejected before save load")
	bad_policy=runtime.export_state();bad_policy.orders[merchant_buy.order_id].npc_pack_sha256=42
	check(not Runtime.validate(bad_policy).is_empty(),"malformed paid NPC source identity rejected")
	runtime.problem="fixture invalid policy"
	runtime.accept_load({Runtime.SAVE_KEY:runtime.export_state()})
	check(not runtime.quote(1001).ok and runtime.problem=="fixture invalid policy","save reload cannot clear a rejected launch policy")
	runtime.problem=""
	policy.server_context={"world_no":[],"region":12}
	policy_file=FileAccess.open(policy_path,FileAccess.WRITE);policy_file.store_string(JSON.stringify(policy));policy_file.close()
	check(not runtime.load_policy(policy_path,FileAccess.get_sha256(policy_path)).ok,"invalid server policy fails without runtime conversion errors")
	var config: Dictionary=Runtime.Economy.defaults()
	config.percentage_divisor=1000000000
	check(not Runtime.Economy.price({"Cost":850},{"Percentage":100,"Amount":1},config).ok,"unsafe economic denominator rejected")
	price=Runtime.Economy.price({"ID":236,"Cost":850},{"Percentage":100,"Amount":1},Runtime.Economy.defaults())
	check(price.ok and price.amount==850 and not str(price.reference_url).is_empty(),"official historical potion base corroborates original; final policy remains labelled local")
	price=Runtime.Economy.price({"Cost":1},{"Percentage":101,"Amount":1},Runtime.Economy.defaults())
	check(price.ok and price.amount==2,"local NPC rounding is explicit ceiling")
	price=Runtime.Economy.price({"Cost":0},{"Percentage":100,"Amount":1},Runtime.Economy.defaults())
	check(price.ok and price.amount==500 and str(price.origin).contains("기본값"),"only missing original base uses labelled local default")
	host.free()
	# Synthetic limited ordinary-NPC contract. Real ordinary stock has no cap.
	context=setup(create_catalog(true));host=context.host;runtime=context.runtime
	runtime.npc_definitions.loaded_sha256="e".repeat(64)
	runtime.npc_definitions.records={"13":{"goods_index":{"1001":true},"object_links":[{"earth_object_id":27,"object_defined":true,"currency_defined_and_unique":true,"currency_ids":[1],"sell_action_row_ids":[9],"attributes":[],"spawns":[{"ID":4,"ServerLimitSetID":0,"SpawnManually":false}]}]}}
	context.clock.now=timestamp("2026-11-03T04:59:58")
	var limited: Dictionary=runtime.quote_merchant(1001,2)
	check(limited.ok and limited.remaining==2 and str(limited.quota_text).contains("캐릭터 저장"),"character-scoped NPC quota exposes remaining allowance")
	var limited_buy: Dictionary=runtime.buy_merchant(1001,2)
	check(limited_buy.ok and not runtime.quote_merchant(1001).ok,"NPC allowance increments with atomic payment")
	check(runtime.state.npc_reset_rule_hashes.has("merchant:fixture-guid"),"NPC reset identity persists with paid counter")
	runtime.accept_load(JSON.parse_string(FileAccess.get_file_as_string(host.path)))
	check(not runtime.quote_merchant(1001).ok,"restart cannot reset limited NPC purchases")
	context.clock.now=timestamp("2026-11-03T04:59:59")
	check(not runtime.quote_merchant(1001).ok,"NPC daily allowance stays closed before 05")
	context.clock.now=timestamp("2026-11-03T05:00:00")
	check(runtime.buy_merchant(1001).ok,"NPC daily allowance reopens at configured boundary")
	check(int(runtime.calendar_offset_minutes)==540,"NPC reset calendar does not alter ordinary market time")
	context.clock.now=timestamp("2026-11-03T04:59:59")
	check(not runtime.buy_merchant(1001).ok,"clock rollback cannot replay an old NPC allowance")
	context.clock.now=timestamp("2026-11-03T05:00:01")
	runtime.npc_resets.rules.offset_minutes=540
	check(not runtime.quote_merchant(1001).ok,"reset policy changes cannot silently replenish a saved counter")
	check(runtime.claim(limited_buy.order_id).ok,"paid limited-NPC order survives later calendar changes")
	runtime.npc_resets.rules.offset_minutes=0
	check(runtime.npc_resets.calendar(timestamp("2026-11-04T04:59:59"),11311,5).bucket!=runtime.npc_resets.calendar(timestamp("2026-11-04T05:00:00"),11311,5).bucket,"NPC Wednesday reset uses its independent week boundary")
	check(runtime.npc_resets.calendar(timestamp("2026-01-31T23:00:00"),81,5).next==timestamp("2026-02-01T05:00:00"),"NPC monthly reset handles next-month boundary")
	check(runtime.npc_resets.calendar(timestamp("2026-11-03T12:00:00"),111,0).next==0,"own lifetime mapping never replenishes automatically")
	host.free()
	print("Source523 commerce synthetic contracts: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
