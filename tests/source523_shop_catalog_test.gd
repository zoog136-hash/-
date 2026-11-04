extends SceneTree
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
var checks: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fixture() -> Dictionary:
	# Synthetic contract data. Actual original-row equality is a separate test.
	var tables: Dictionary = {}
	for table: String in Catalog.REQUIRED_TABLES: tables[table] = []
	tables.Currency = [{"ID":812,"Name":"fixture currency","DescID":0}, {"ID":3034,"Name":"consume-only fixture","DescID":0}]
	tables.CurrencyUnitClass = [
		{"ID":1,"CurrencyID":812,"UnitID":4,"ClassID":65291,"ForGive":true,"ConsumePriority":0},
		{"ID":2,"CurrencyID":812,"UnitID":4,"ClassID":3581,"ForGive":false,"ConsumePriority":1},
		{"ID":3,"CurrencyID":3034,"UnitID":4,"ClassID":366464,"ForGive":false,"ConsumePriority":0}]
	tables.MarketPurchase_Korean = [{"ID":1001,"MarketPaymentID":1,"DescID":1,"DescriptionDescID":1,"EffectiveFromId":2,"EffectiveToId":1,"OnSale":true}]
	tables.MarketPayment_Korean = [{"ID":1,"UnitID":201,"ClassID":812,"Amount":100,"MarketPaymentTypeID":4,"ClassChangeDiscount":false}]
	tables.MarketProduct = [{"ID":1,"UnitID":4,"ClassID":8941,"Amount":2000}]
	tables.MarketPurchaseProduct = [{"MarketPurchaseID":1001,"MarketProductID":1}]
	tables.MarketProductAdditional = [{"MarketProductID":1,"UnitID":10622,"ClassID":8832,"Amount":1}]
	tables.MarketPurchaseRestriction = [
		{"MarketPurchaseId":1001,"MarketRestrictionTypeId":3,"ValueUnitId":1,"Value":1,"DurationUnitId":61,"DurationValue":1},
		{"MarketPurchaseId":1001,"MarketRestrictionTypeId":7,"ValueUnitId":1,"Value":50,"DurationUnitId":61,"DurationValue":1}]
	tables.MarketDisplay = [{"ID":1,"PurchaseID":1001,"DisplayIndex":1}]
	tables.MarketPurchaseServerLimitGroup = [{"MarketPurchaseID":1001,"ServerLimitSetID":274}]
	tables.ServerLimit = [{"ID":1,"ServerLimitSetID":274,"WorldNo":1,"ServiceRegionCode":"KR"}]
	tables.DateTimes_Korean = [{"ID":2,"Year":2016,"Month":1,"Day":1,"Hour":0,"Minute":0}, {"ID":1,"Year":2099,"Month":12,"Day":31,"Hour":23,"Minute":59}]
	tables.ItemClass = [{"ID":8941,"Name":"fixture item","DescID":1,"Cost":100}]
	tables.DescData_Korean = [{"ID":1,"Description":"synthetic fixture"}]
	tables.MarketPurchaseGroup = [{"PurchaseGroupID":5,"PurchaseID":1001,"Index":18},{"PurchaseGroupID":5,"PurchaseID":1001,"Index":11}]
	var merchant: Dictionary = {}
	for field: String in Catalog.FIELDS.MerchantGoods:
		merchant[field] = false if field in Catalog.BOOLEAN_FIELDS else 0
	merchant.merge({"ID":21712,"MerchantsID":1,"ItemClassID":8941,"Amount":1,"Percentage":1275000000,"LimitCount":5,"LimitMinClanLevel":7},true)
	tables.MerchantGoods = [merchant]
	var provenance: Dictionary = {}
	for table: String in tables: provenance[table] = {"packed_rows":tables[table].size()}
	return {"schema":Catalog.SCHEMA,"patch":523,"source_zip_sha256":Catalog.SOURCE_SHA256,"tables":tables,"provenance":provenance}

func save_pack(data: Dictionary, path: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return FileAccess.get_sha256(path)

func _run() -> void:
	var data: Dictionary = fixture()
	var path: String = "user://source523-shop-synthetic.json"
	var sha: String = save_pack(data, path)
	var catalog := Catalog.new()
	check(not catalog.available(), "unselected source must be absent")
	check(not catalog.load_pack(path, ""), "unanchored source must fail")
	check(catalog.load_pack(path, sha), "synthetic pack loads for contract tests")
	check(catalog.available(), "catalog installed")
	check(catalog.payment_quote(1001, 1000).total == 100000, "checked payment amount")
	check(not catalog.payment_quote(1001, 0).ok and not catalog.payment_quote(1001, 1001).ok, "quantity boundaries")
	check(not catalog.payment_quote(1001, 1).can_purchase, "quote does not authorize purchase")
	check(not Catalog._checked_product([9007199254740991, 2]).ok, "overflow must not wrap")
	check(catalog.merchant_offer(21712).raw_price_product.value == 127500000000, "64-bit raw intermediate")
	check(not catalog.merchant_offer(21712).can_purchase, "raw merchant product is not a final price")
	check(catalog.merchant_offer(21712).goods.ClanLevelMin == 0 and catalog.merchant_offer(21712).goods.LimitMinClanLevel == 7, "distinct clan constraints")
	check(catalog.currency(812).sources.size() == 2 and catalog.currency(812).for_give.size() == 1, "give and consume source separation")
	check(catalog.currency(3034).for_give.is_empty(), "no fabricated canonical grant")
	check(catalog.market_offer(1001).products[0].product.definition.Amount == 2000, "bundle amount preserved")
	check(catalog.market_offer(1001).products[0].product.additional[0].ClassID == 8832, "class mask preserved as a condition")
	check(catalog.market_offer(1001).bonuses.is_empty(), "additional condition is not a reward")
	check(catalog.market_offer(1001).restrictions.size() == 2, "account/clan limits both retained")
	check(catalog.market_offer(1001).effective_from.Year < catalog.market_offer(1001).effective_to.Year, "date values are not sorted by ID")
	check(catalog.purchase_group(5)[0].Index == 11, "group ordering follows Index")
	check(not catalog.activation(1001).can_purchase, "no assumed clock/server activation")
	check(catalog.activation(1001).reasons.size() > catalog.activation(1001,{"world_no":1,"region":"KR"}).reasons.size(), "server context separate from time")
	check(not catalog.activation(1001,{"world_no":1,"region":"KR"}).can_purchase, "server match cannot bypass time/restrictions")
	var changed: Array = catalog.rows("MarketPayment_Korean")
	changed[0].Amount = 1
	check(catalog.payment_quote(1001, 1).total == 100, "query result cannot change authority")
	check(not catalog.load_pack(path, "0".repeat(64)) and catalog.loaded_sha256 == sha, "failed hash replacement retains registry")
	var invalid: Dictionary = data.duplicate(true)
	invalid.tables.erase("Currency")
	check(not catalog.load_pack(path, save_pack(invalid, path)) and catalog.payment_quote(1001, 1).total == 100, "missing table retains registry")
	invalid = data.duplicate(true)
	invalid.tables.MarketPayment_Korean[0].Amount = 1.5
	check(not catalog.load_pack(path, save_pack(invalid, path)), "fractional amount rejected")
	invalid = data.duplicate(true)
	invalid.provenance.Currency.packed_rows = 2.5
	check(not catalog.load_pack(path, save_pack(invalid, path)), "fractional row count rejected")
	invalid = data.duplicate(true)
	invalid.tables.MarketProduct.append(invalid.tables.MarketProduct[0].duplicate(true))
	invalid.provenance.MarketProduct.packed_rows = 2
	check(not catalog.load_pack(path, save_pack(invalid, path)), "duplicate identity rejected")
	DirAccess.remove_absolute(path)
	# Optional real-source integration is explicitly distinguished from fixtures.
	var original_path: String = ""
	var original_sha: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source523-shop-pack="): original_path = argument.trim_prefix("--source523-shop-pack=")
		if argument.begins_with("--source523-shop-sha256="): original_sha = argument.trim_prefix("--source523-shop-sha256=")
	if not original_path.is_empty():
		var original := Catalog.new()
		check(original.load_pack(original_path, original_sha), "actual original pack loads")
		if original.available():
			check(original.rows("MarketPurchase_Korean").size() == 6819, "actual market count")
			check(original.rows("MerchantGoods").size() == 4328, "actual merchant count")
			check(original.rows("MarketPurchaseRestriction").size() == 9215, "actual restriction count")
			check(not original.payment_quote(961, 1).ok, "actual store placeholder zero is not a free purchase")
			check(original.merchant_offer(21712).raw_price_product.value == 127500000000, "actual oversized arithmetic")
			check(original.merchant_offer(17751).goods.LimitMinClanLevel == 7, "actual distinct clan condition")
			check(original.currency(3034).for_give.is_empty(), "actual consume-only source")
			check(original.product(86582).definition.UnitID == 35 and original.product(86582).definition.Amount == 10, "actual product amount is not overwritten by its title")
			check(original.purchase_group(55653)[0].Index < original.purchase_group(55653)[-1].Index, "actual group indexing")
		print("Actual source integration was executed; fixture checks are separate.")
	else:
		print("Actual source integration NOT RUN; synthetic contract test only.")
	print("Source523 shop catalog: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
