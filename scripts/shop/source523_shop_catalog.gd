extends RefCounted
## Optional source commerce catalog. It never changes wallets, saves or clocks.
const Definitions = preload("res://scripts/resources/current523_definition_rows.gd")
const ItemData = preload("res://scripts/resources/current523_item_data.gd")
const SCHEMA: String = "twilight.source523.shop.v1"
const SOURCE_SHA256: String = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const REQUIRED_TABLES: Array[String] = [
	"MerchantGoods", "MarketPurchase_Korean", "MarketPayment_Korean", "MarketPurchaseProduct",
	"MarketProduct", "MarketProductAdditional", "MarketBonusForPurchase", "MarketPurchaseRestriction",
	"MarketDisplay", "MarketDisplayCategoryType", "MarketPurchaseGroup", "MarketPurchaseServerLimitGroup",
	"Currency", "CurrencyUnitClass", "CurrencyDiscountRate", "CurrencyCode", "Unit", "ServerLimit",
	"DateTimes_Korean", "CumulativePurchase", "CumulativePurchaseStep", "ItemClass", "IntangibleItemClass",
	"Class", "BuffCard", "Reward", "RewardType", "DescData_Korean"]
const MAX_PACK_BYTES: int = 128 * 1024 * 1024
const MAX_EXACT_INTEGER: int = 9007199254740991
const FIELDS: Dictionary = {
	"MarketPurchase_Korean":["ID", "MarketPaymentID", "DescID", "DescriptionDescID", "EffectiveFromId", "EffectiveToId", "OnSale"],
	"MarketPayment_Korean":["ID", "UnitID", "ClassID", "Amount", "MarketPaymentTypeID", "ClassChangeDiscount"],
	"MerchantGoods":["ID", "MerchantsID", "ItemClassID", "Amount", "Enchant", "Percentage", "LimitCount", "LimitCountPerAccount", "LimitServerCount", "LimitCountRefreshTypeID", "LimitMinLevel", "LimitMaxLevel", "ClanLevelMin", "LimitMinClanLevel", "AvailableSiegeTime", "LimitNotInSiegeTime", "DaysAfterClanJoin", "LimitDaysAfterClanJoin", "LimitBuffCardID", "LimitRepeatedBuyCardID", "LimitStartTime", "LimitEndTime", "LimitStartHour", "LimitEndHour"],
	"MarketProduct":["ID", "UnitID", "ClassID", "Amount"],
	"MarketProductAdditional":["MarketProductID", "UnitID", "ClassID", "Amount"],
	"MarketPurchaseProduct":["MarketPurchaseID", "MarketProductID"],
	"MarketBonusForPurchase":["MarketPurchaseID", "MarketProductID"],
	"MarketPurchaseRestriction":["MarketPurchaseId", "MarketRestrictionTypeId", "ValueUnitId", "Value", "DurationUnitId", "DurationValue"],
	"MarketPurchaseServerLimitGroup":["MarketPurchaseID", "ServerLimitSetID"],
	"MarketDisplay":["ID", "PurchaseID", "DisplayIndex"],
	"MarketPurchaseGroup":["PurchaseGroupID", "PurchaseID", "Index"],
	"ServerLimit":["ID", "ServerLimitSetID", "WorldNo", "ServiceRegionCode"],
	"DateTimes_Korean":["ID", "Year", "Month", "Day", "Hour", "Minute"],
	"Currency":["ID", "Name", "DescID"],
	"CurrencyUnitClass":["ID", "CurrencyID", "UnitID", "ClassID", "ForGive", "ConsumePriority"],
	"CurrencyDiscountRate":["ID", "CurrencyDiscountID", "CurrencyID", "Rate"],
	"Unit":["ID", "Name"], "DescData_Korean":["ID", "Description"],
	"ItemClass":["ID", "Name", "DescID", "Cost"], "IntangibleItemClass":["ID", "Name"],
	"CumulativePurchase":["ID", "Name", "StartTimeID", "EndTimeID", "DailyRewardID", "ServerLimitsetID"],
	"CumulativePurchaseStep":["ID", "CumulativePurchaseID", "Step", "RewardID"]}
const BOOLEAN_FIELDS: Array[String] = ["OnSale", "ClassChangeDiscount", "LimitCountPerAccount", "AvailableSiegeTime", "LimitNotInSiegeTime", "ForGive"]
const STRING_FIELDS: Array[String] = ["Name", "Description", "ServiceRegionCode"]
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BAKE_NAME := "source523_shop_input"
static var _session: RefCounted
var _tables: Dictionary = {}
var _indices: Dictionary = {}
var _links: Dictionary = {}
## Original-path tables served by the shared definitions reader.
var _shared: Dictionary = {}
const SHARED_ROW_THRESHOLD: int = 20000
var loaded_sha256: String = ""
var model_input_identity: Dictionary = {}
var error: String = ""

static func _pack_arguments() -> Dictionary:
	var result: Dictionary = {"explicit":false,"path":"","sha256":""}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source523-shop-pack"):
			result.explicit = true
			if argument.begins_with("--source523-shop-pack="): result.path = argument.trim_prefix("--source523-shop-pack=")
		if argument.begins_with("--source523-shop-sha256"):
			result.explicit = true
			if argument.begins_with("--source523-shop-sha256="): result.sha256 = argument.trim_prefix("--source523-shop-sha256=")
	return result

static func session() -> RefCounted:
	if _session == null:
		_session = load("res://scripts/shop/source523_shop_catalog.gd").new()
		var arguments: Dictionary = _pack_arguments()
		if arguments.explicit: _session.load_pack(arguments.path,arguments.sha256)
		else: _session.load_original()
	return _session

## Drops the session model; the next session() reads it again (from the
## device's packed definitions, not by re-parsing the original).
static func release() -> void:
	_session = null

func available() -> bool:
	return not _tables.is_empty()

func load_pack(path: String, expected_sha256: String) -> bool:
	# Invalid replacements leave the previous registry intact.
	if expected_sha256.length() != 64 or not expected_sha256.is_valid_hex_number(false):
		return _fail("원본 상점 팩 SHA256이 필요합니다")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_PACK_BYTES:
		return _fail("원본 상점 팩을 읽을 수 없습니다")
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	var actual: String = hash_context.finish().hex_encode()
	if actual != expected_sha256.to_lower(): return _fail("원본 상점 팩 해시가 다릅니다")
	return _load_payload(bytes,actual,{"kind":"twilight.source523.shop-pack-input.v1","payload_sha256":actual,"payload_bytes":bytes.size(),"declared_source_zip_sha256":SOURCE_SHA256})

func load_original() -> bool:
	# Preserve an installed model and never use the original ZIP to bypass an
	# explicitly supplied pack/digest, including empty or malformed arguments.
	if available(): return true
	if _pack_arguments().explicit: return _fail("명시한 원본 상점 팩 입력을 우회하지 않습니다")
	var identity: Dictionary = Definitions.identity()
	if identity.is_empty() or identity.get("source_sha256") != SOURCE_SHA256:
		return _fail("보유 원본523 상점 입력이 없습니다: "+Definitions.problem())
	# The projection below is a pure function of the verified original and this
	# code; the shop model is released between uses, so reopening reads this
	# device's bake (still fully staged/validated by _stage) instead of
	# scanning and hashing the label tables again.
	var bake_key: String = BAKE.projection_key(BAKE_NAME, Definitions.verified_key())
	var baked: Variant = BAKE.read(BAKE_NAME, bake_key)
	if baked is Dictionary and baked.get("tables") is Dictionary and baked.get("provenance") is Dictionary and baked.get("actual") is String and baked.get("identity") is Dictionary and baked.get("shared") is Dictionary:
		return _stage(baked.tables, baked.provenance, baked.actual, baked.identity, baked.shared, true)
	var tables: Dictionary = {}
	var provenance: Dictionary = {}
	var shared: Dictionary = {}
	var label_ids: Dictionary = {"0":true,"1":true}
	# Same complete-row projection and label closure as build_source523_shop.py.
	# DescData is the sole selected table; its provenance remains the full member.
	# Large tables stay in the shared packed original reader instead of being
	# copied here (and again through a JSON round trip); they are streamed once.
	for table: String in REQUIRED_TABLES:
		var metadata: Dictionary = Definitions.table_metadata(table)
		var member: String = "content/"+table+".json"
		var digest: Variant = metadata.get("sha256")
		if metadata.get("path") != member or metadata.get("version") != 523 or not _integer(metadata.get("bytes")) or not _integer(metadata.get("row_count")) or not digest is String:
			return _fail("원본 상점 표 정체 누락: "+table)
		if int(metadata.bytes)<0 or int(metadata.row_count)<0 or digest.length()!=64 or not digest.is_valid_hex_number(false):
			return _fail("원본 상점 표 정체 오류: "+table)
		var count: int = Definitions.row_count(table)
		if count!=int(metadata.row_count): return _fail("원본 상점 표 행수 불일치: "+table)
		provenance[table] = {"member":member,"bytes":metadata.bytes,"sha256":digest,"source_rows":count,"packed_rows":count}
		if table == "DescData_Korean":
			var ids: Variant = Definitions.column(table,"ID")
			if ids.size() != count: return _fail("원본 상점 라벨 ID 오류")
			# The selected label rows stay in the shared reader; only their
			# positions are kept (rows are read back in the same order).
			var selected := PackedInt32Array()
			for index: int in count:
				if not _integer(ids[index]): return _fail("원본 상점 라벨 ID 오류")
				if label_ids.has(str(int(ids[index]))): selected.append(index)
			tables[table] = []
			shared[table] = selected
			provenance[table].packed_rows = selected.size()
			continue
		var stream: bool = count >= SHARED_ROW_THRESHOLD
		var source_rows: Array[Dictionary] = []
		if not stream: source_rows = Definitions.rows(table)
		for index: int in count:
			var row: Dictionary = Definitions.row_at(table,index) if stream else source_rows[index]
			for key: String in row:
				if key.ends_with("DescID") or key.ends_with("DescId"):
					if not _integer(row[key]): return _fail("원본 상점 라벨 참조 오류: "+table+"."+key)
					label_ids[str(int(row[key]))] = true
		if stream:
			shared[table] = true
			tables[table] = []
		else: tables[table] = source_rows
	var model: Dictionary = {"schema":SCHEMA,"patch":523,"source_zip_sha256":SOURCE_SHA256,"delivery":"PRIVATE_LOCAL_ONLY","tables":tables,"provenance":provenance}
	# This digest identifies the same JSON bytes JSON.stringify(model,"",false,true)
	# produces (not the raw source archive or another compiler's serialization);
	# they are hashed piece by piece so the whole text is never held at once.
	# Existing policy/NPC mismatches remain.
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	var size: int = 0
	var pieces: PackedStringArray = []
	for key: String in model:
		pieces.append(JSON.stringify(key)+":"+("" if key == "tables" else JSON.stringify(model[key],"",false,true)))
	for piece_index: int in pieces.size():
		var head: String = ("{" if piece_index == 0 else ",")+pieces[piece_index]
		size += _hash_text(hash_context,head)
		if pieces[piece_index] != JSON.stringify("tables")+":": continue
		size += _hash_text(hash_context,"{")
		var first_table: bool = true
		for table: String in tables:
			size += _hash_text(hash_context,("" if first_table else ",")+JSON.stringify(table)+":[")
			first_table = false
			var count: int = _row_count(table,tables,shared)
			for index: int in count:
				var row: Dictionary = _row_of(table,index,tables,shared)
				size += _hash_text(hash_context,("" if index == 0 else ",")+JSON.stringify(row,"",false,true))
			size += _hash_text(hash_context,"]")
		size += _hash_text(hash_context,"}")
	size += _hash_text(hash_context,"}")
	if size>MAX_PACK_BYTES: return _fail("원본 상점 팩을 읽을 수 없습니다")
	var actual: String = hash_context.finish().hex_encode()
	var input_identity: Dictionary = {"kind":"twilight.source523.original-shop-input.v1","archive":identity,"payload_sha256":actual,"payload_bytes":size,"projection":"tools/shop/build_source523_shop.py"}
	if not _stage(tables,provenance,actual,input_identity,shared): return false
	BAKE.write(BAKE_NAME, bake_key, {"tables":tables,"provenance":provenance,"actual":actual,"identity":input_identity,"shared":shared})
	return true

static func _hash_text(context: HashingContext, text: String) -> int:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	context.update(bytes)
	return bytes.size()

func _load_payload(bytes: PackedByteArray, actual: String, input_identity: Dictionary) -> bool:
	# Both inputs share the existing JSON/schema/table/row/relationship staging.
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK: return _fail("상점 팩 JSON 오류")
	var pack: Variant = parser.data
	if not pack is Dictionary or pack.get("schema") != SCHEMA or pack.get("patch") != 523 or pack.get("source_zip_sha256") != SOURCE_SHA256:
		return _fail("검증된 523 상점 팩 형식이 아닙니다")
	var tables: Variant = pack.get("tables")
	var provenance: Variant = pack.get("provenance")
	if not tables is Dictionary or not provenance is Dictionary: return _fail("상점 팩 표 누락")
	return _stage(tables,provenance,actual,input_identity)

## `shared` tables are read from the original definitions reader (same rows,
## same order) instead of `tables`; they are validated here like any other.
## `staged`: these exact inputs already passed _stage on this device (a bake
## written only after success); whole shared original tables, which keep no
## index, are then not re-read row by row.
func _stage(tables: Dictionary, provenance: Dictionary, actual: String, input_identity: Dictionary, shared: Dictionary = {}, staged: bool = false) -> bool:
	var indices: Dictionary = {}
	for table: String in REQUIRED_TABLES:
		if not tables.get(table) is Array or not provenance.get(table) is Dictionary:
			return _fail("상점 팩 표 누락: " + table)
		var count: int = _row_count(table,tables,shared)
		if not _integer(provenance[table].get("packed_rows")) or int(provenance[table].get("packed_rows", -1)) != count:
			return _fail("상점 팩 행수 불일치: " + table)
		var indexed: Dictionary = {}
		if staged and shared.get(table) is bool:
			indices[table] = {}
			continue
		for index: int in count:
			var row: Variant = _row_of(table,index,tables,shared)
			if not row is Dictionary: return _fail("상점 팩 행 오류: " + table)
			for field: String in FIELDS.get(table, ["ID"]):
				if field in STRING_FIELDS:
					if not row.get(field) is String: return _fail("상점 팩 문자열 오류: " + table + "." + field)
				elif field in BOOLEAN_FIELDS:
					if not row.get(field) is bool: return _fail("상점 팩 조건 오류: " + table + "." + field)
				elif not _integer(row.get(field)):
					return _fail("상점 팩 정수 오류: " + table + "." + field)
			if not row.has("ID"): continue # Relation tables have composite keys.
			if not _integer(row.ID) or int(row.ID) < 0: return _fail("상점 팩 ID 오류: " + table)
			# Korean payment ID0 contains several system rows. Never select one by overwrite.
			if table == "MarketPayment_Korean" and int(row.ID) == 0: continue
			var key: String = str(int(row.ID))
			if indexed.has(key): return _fail("상점 팩 중복 ID: " + table)
			indexed[key] = true if shared.has(table) else row
		indices[table] = indexed if not shared.has(table) or shared[table] is PackedInt32Array else {}
	var links: Dictionary = {}
	var joins: Dictionary = {"MarketPurchaseProduct":"MarketPurchaseID", "MarketBonusForPurchase":"MarketPurchaseID",
		"MarketProductAdditional":"MarketProductID", "MarketPurchaseRestriction":"MarketPurchaseId",
		"MarketPurchaseServerLimitGroup":"MarketPurchaseID", "MarketDisplay":"PurchaseID",
		"CurrencyUnitClass":"CurrencyID", "ServerLimit":"ServerLimitSetID", "MarketPurchaseGroup":"PurchaseGroupID"}
	for table: String in joins:
		var grouped: Dictionary = {}
		for row: Dictionary in tables[table]:
			if not _integer(row.get(joins[table])): return _fail("상점 팩 연결 ID 오류: " + table)
			var key: String = str(int(row[joins[table]]))
			if not grouped.has(key): grouped[key] = []
			grouped[key].append(row)
		links[table] = grouped
	_tables = tables
	_indices = indices
	_links = links
	_shared = shared.duplicate()
	loaded_sha256 = actual
	model_input_identity = input_identity.duplicate(true)
	error = ""
	return true

func _fail(message: String) -> bool:
	error = message
	return false

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= MAX_EXACT_INTEGER and float(value) == floorf(float(value))

## Rows of a staged table: in `tables`, every row of the shared reader
## (shared[table] == true) or the selected positions (PackedInt32Array).
static func _row_count(table: String, tables: Dictionary, shared: Dictionary) -> int:
	if not shared.has(table): return (tables[table] as Array).size()
	return (shared[table] as PackedInt32Array).size() if shared[table] is PackedInt32Array else Definitions.row_count(table)

static func _row_of(table: String, index: int, tables: Dictionary, shared: Dictionary) -> Dictionary:
	if not shared.has(table): return tables[table][index]
	return Definitions.row_at(table, (shared[table] as PackedInt32Array)[index] if shared[table] is PackedInt32Array else index)

func rows(table: String) -> Array:
	if _shared.get(table) is PackedInt32Array:
		var selected: Array = []
		for index: int in (_shared[table] as PackedInt32Array): selected.append(Definitions.row_at(table,index))
		return selected
	if _shared.has(table): return Definitions.rows(table)
	return _tables.get(table, []).duplicate(true)

func record(table: String, id: int) -> Dictionary:
	if _shared.has(table):
		if _shared[table] is PackedInt32Array and not _indices.get(table,{}).has(str(id)): return {}
		var matches: Array[Dictionary] = Definitions.related(table, "ID", id)
		return matches[0] if matches.size() == 1 and id >= 0 else {}
	return _indices.get(table, {}).get(str(id), {}).duplicate(true)

func _related(table: String, id: int) -> Array:
	return _links.get(table, {}).get(str(id), []).duplicate(true)

func _definition_record(table: String, id: int) -> Dictionary:
	return record(table,id) if available() else Definitions.row(table,id)

func _definition_related(table: String, field: String, id: int) -> Array:
	if not available() or (_shared.has(table) and not _shared[table] is PackedInt32Array and Definitions.integer_field(table,field)): return Definitions.related(table,field,id)
	var result: Array = []
	if _shared.get(table) is PackedInt32Array:
		for row: Dictionary in rows(table):
			if _integer(row.get(field)) and int(row[field]) == id: result.append(row)
		return result
	if _shared.has(table):
		for index: int in Definitions.row_count(table):
			var row: Dictionary = Definitions.row_at(table,index)
			if _integer(row.get(field)) and int(row[field]) == id: result.append(row)
		return result
	for row: Dictionary in _tables.get(table,[]):
		if _integer(row.get(field)) and int(row[field]) == id: result.append(row.duplicate(true))
	return result

func _item_class_unit(unit_id: int) -> bool:
	# ClassID alone does not identify an item namespace.
	return _definition_record("Unit",unit_id).get("Name") == "ItemClassID"

func item_identity(item_id: int) -> Dictionary:
	var original: Dictionary = ItemData.describe(item_id)
	var raw: Variant = original.get("item_class",{})
	if raw is Dictionary and not raw.is_empty():
		original["source_available"] = true
		return original
	# A missing optional original input does not replace an installed shop pack.
	var compiled: Dictionary = record("ItemClass",item_id)
	original["item_class"] = compiled
	original["source_available"] = false
	original["compiled_shop_available"] = not compiled.is_empty()
	original["reference_only"] = true
	original["can_activate"] = false
	if compiled.get("TestItem") is bool and compiled.TestItem:
		original["ok"] = false
		original["excluded"] = true
	return original

func _purchase_reference(id: int) -> Dictionary:
	var purchase: Dictionary = _definition_record("MarketPurchase_Korean",id)
	if purchase.is_empty(): return {}
	var limits: Array = []
	for link: Dictionary in _definition_related("MarketPurchaseServerLimitGroup","MarketPurchaseID",id):
		limits.append({"link":link,"servers":_definition_related("ServerLimit","ServerLimitSetID",int(link.ServerLimitSetID))})
	return {"purchase":purchase,
		"payment":_definition_record("MarketPayment_Korean",int(purchase.MarketPaymentID)),
		"products":_definition_related("MarketPurchaseProduct","MarketPurchaseID",id),
		"bonuses":_definition_related("MarketBonusForPurchase","MarketPurchaseID",id),
		"restrictions":_definition_related("MarketPurchaseRestriction","MarketPurchaseId",id),
		"server_limits":limits,"displays":_definition_related("MarketDisplay","PurchaseID",id),
		"effective_from":_definition_record("DateTimes_Korean",int(purchase.EffectiveFromId)),
		"effective_to":_definition_record("DateTimes_Korean",int(purchase.EffectiveToId)),
		"reference_only":true,"can_purchase":false}

func _product_reference(id: int) -> Dictionary:
	var purchases: Array = []
	for table: String in ["MarketPurchaseProduct","MarketBonusForPurchase"]:
		for link: Dictionary in _definition_related(table,"MarketProductID",id):
			purchases.append({"relation":table,"link":link,"offer":_purchase_reference(int(link.MarketPurchaseID))})
	return {"product":_definition_record("MarketProduct",id),
		"additional":_definition_related("MarketProductAdditional","MarketProductID",id),
		"purchases":purchases,"reference_only":true,"can_purchase":false}

func item_references(item_id: int) -> Dictionary:
	var identity: Dictionary = item_identity(item_id)
	var item: Dictionary = identity.get("item_class",{})
	if item.is_empty():
		return {"item_id":item_id,"identity":identity,"unavailable":true,"reference_only":true,"can_purchase":false}
	var merchants: Array = []
	for goods: Dictionary in _definition_related("MerchantGoods","ItemClassID",item_id):
		merchants.append({"goods":goods,
			"required_buff_card":_definition_record("BuffCard",int(goods.get("LimitBuffCardID",0))),
			"reference_only":true,"can_purchase":false})
	var products: Array = []
	for product_row: Dictionary in _definition_related("MarketProduct","ClassID",item_id):
		if _item_class_unit(int(product_row.UnitID)): products.append(_product_reference(int(product_row.ID)))
	var additional: Array = []
	for link: Dictionary in _definition_related("MarketProductAdditional","ClassID",item_id):
		if _item_class_unit(int(link.UnitID)):
			additional.append({"link":link,"parent":_product_reference(int(link.MarketProductID))})
	var payments: Array = []
	for payment: Dictionary in _definition_related("MarketPayment_Korean","ClassID",item_id):
		if not _item_class_unit(int(payment.UnitID)): continue
		var purchases: Array = []
		for purchase: Dictionary in _definition_related("MarketPurchase_Korean","MarketPaymentID",int(payment.ID)):
			purchases.append(_purchase_reference(int(purchase.ID)))
		payments.append({"payment":payment,"purchases":purchases})
	# These are original references, including unresolved/off-sale conditions.
	# They never activate a merchant, declare a price, or authorize a transaction.
	return {"item_id":item_id,"identity":identity,"merchant_goods":merchants,
		"market_products":products,"market_additional":additional,"market_payments":payments,
		"shop_pack_sha256":loaded_sha256,"reference_only":true,"can_purchase":false,
		"excluded":identity.get("excluded",false)}

func label(id: int) -> String:
	return str(record("DescData_Korean", id).get("Description", ""))

func unit_name(id: int) -> String:
	return str(record("Unit", id).get("Name", str(id)))

func currency(id: int) -> Dictionary:
	var definition: Dictionary = record("Currency", id)
	if definition.is_empty(): return {}
	var sources: Array = _related("CurrencyUnitClass", id)
	var for_give: Array = []
	for source: Dictionary in sources:
		if source.get("ForGive") == true: for_give.append(source.duplicate(true))
	return {"definition":definition, "sources":sources, "for_give":for_give}

func product(id: int) -> Dictionary:
	return {"definition":record("MarketProduct", id), "additional":_related("MarketProductAdditional", id)}

func market_offer(id: int) -> Dictionary:
	var purchase: Dictionary = record("MarketPurchase_Korean", id)
	if purchase.is_empty(): return {}
	var products: Array = []
	var bonuses: Array = []
	for link: Dictionary in _related("MarketPurchaseProduct", id):
		products.append({"link":link, "product":product(int(link.MarketProductID))})
	for link: Dictionary in _related("MarketBonusForPurchase", id):
		bonuses.append({"link":link, "product":product(int(link.MarketProductID))})
	return {"purchase":purchase, "name":label(int(purchase.get("DescID", 0))),
		"description":label(int(purchase.get("DescriptionDescID", 0))),
		"payment":record("MarketPayment_Korean", int(purchase.get("MarketPaymentID", 0))),
		"products":products, "bonuses":bonuses, "restrictions":_related("MarketPurchaseRestriction", id),
		"server_limits":_related("MarketPurchaseServerLimitGroup", id), "displays":_related("MarketDisplay", id),
		"effective_from":record("DateTimes_Korean", int(purchase.get("EffectiveFromId", 0))),
		"effective_to":record("DateTimes_Korean", int(purchase.get("EffectiveToId", 0)))}

func purchase_group(id: int) -> Array:
	var result: Array = _related("MarketPurchaseGroup", id)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.Index) < int(b.Index))
	return result

func merchant_offer(id: int) -> Dictionary:
	var goods: Dictionary = record("MerchantGoods", id)
	if goods.is_empty(): return {}
	var item: Dictionary = record("ItemClass", int(goods.get("ItemClassID", 0)))
	var raw_product: Dictionary = _checked_product([item.get("Cost", 0), goods.get("Percentage", 0), goods.get("Amount", 0)])
	# This is an arithmetic diagnostic, never a buy/sell quote or a probability.
	return {"goods":goods, "item":item, "raw_price_product":raw_product,
		"price_status":"UNKNOWN_FORMULA", "can_purchase":false}

static func _checked_product(values: Array) -> Dictionary:
	var result: int = 1
	for value: Variant in values:
		if not _integer(value) or int(value) < 0: return {"ok":false, "reason":"금액 필드 오류"}
		var integer: int = int(value)
		if integer > 0 and result > MAX_EXACT_INTEGER / integer:
			return {"ok":false, "reason":"정확한 금액 범위 초과"}
		result *= integer
	return {"ok":true, "value":result}

func payment_quote(purchase_id: int, quantity: int) -> Dictionary:
	var offer: Dictionary = market_offer(purchase_id)
	if offer.is_empty() or quantity < 1 or quantity > 1000: return {"ok":false, "reason":"상품 또는 수량 오류"}
	var payment: Dictionary = offer.payment
	if payment.is_empty() or int(payment.get("MarketPaymentTypeID", -1)) != 4:
		return {"ok":false, "reason":"외부 결제·무료·쿠폰 경로는 미연결"}
	if payment.get("ClassChangeDiscount") == true:
		return {"ok":false, "reason":"클래스체인지 할인 조건 미확인"}
	var unit: int = int(payment.get("UnitID", 0))
	var class_id: int = int(payment.get("ClassID", 0))
	if unit not in [4, 34, 201]: return {"ok":false, "reason":"미해석 결제 단위"}
	if (unit == 201 and record("Currency", class_id).is_empty()) or (unit == 4 and record("ItemClass", class_id).is_empty()) or (unit == 34 and record("IntangibleItemClass", class_id).is_empty()):
		return {"ok":false, "reason":"결제 대상 연결 누락"}
	var total: Dictionary = _checked_product([payment.get("Amount", -1), quantity])
	if not total.ok: return total
	# Only a source payment amount. It confers no authority to purchase/deliver.
	return {"ok":true, "unit_id":unit, "class_id":class_id, "unit_amount":int(payment.Amount),
		"quantity":quantity, "total":int(total.value), "can_purchase":false}

func activation(purchase_id: int, context: Dictionary = {}) -> Dictionary:
	var offer: Dictionary = market_offer(purchase_id)
	if offer.is_empty(): return {"state":"blocked", "reasons":["상품 없음"]}
	var reasons: Array[String] = []
	if offer.purchase.get("OnSale") != true: reasons.append("판매 중 아님")
	if offer.displays.is_empty(): reasons.append("현재 진열 연결 없음")
	if offer.effective_from.is_empty() or offer.effective_to.is_empty():
		reasons.append("상품 기간 연결 미확인")
	else:
		# No clock/timezone policy is selected here; the source has no timezone.
		reasons.append("상품 기간의 시간 기준·경계 미확인")
	for limit: Dictionary in offer.server_limits:
		var servers: Array = _related("ServerLimit", int(limit.ServerLimitSetID))
		var matched: bool = false
		for server: Dictionary in servers:
			if context.get("world_no", -1) == int(server.WorldNo) and context.get("region", "") == str(server.ServiceRegionCode): matched = true
		if not matched: reasons.append("서버 조건 미충족 또는 미확인 · Set %d" % int(limit.ServerLimitSetID))
	if not offer.restrictions.is_empty(): reasons.append("구매 제한 %d개 · 범위·기간별 판정 미연결" % offer.restrictions.size())
	if not payment_quote(purchase_id, 1).get("ok", false): reasons.append("결제 경로 미연결")
	reasons.append("결제·보관함 수령 경로 검증 필요")
	return {"state":"blocked", "reasons":reasons, "can_purchase":false}

