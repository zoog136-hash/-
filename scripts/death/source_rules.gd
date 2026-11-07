extends RefCounted
## Reads the pinned, private original archive. No original rows are vendored.
const SHA: String = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const PATH: String = "user://source_rules/death523.zip"
const CommonSource = preload("res://scripts/resources/current523_definition_rows.gd")
const REVIEWED_ITEM_EXEMPTION_LEVEL: int = 30
# Applied only to the pre-existing local item-loss exemption. Experience has
# its own source-table boundary and must not use this scalar as a global gate.
var source_item_exemption_level: int = -1
var fallback_loss_percent: float = 5.0
var fallback_cost_factor: int = 12
var experience: Dictionary = {}
var items: Dictionary = {}
var item_names: Dictionary = {}
var attributes: Array = []
var territories: Dictionary = {}
var certificates: Dictionary = {}
var slot_offers: Dictionary = {}
var item_death_stats: Dictionary = {}
var ready: bool = false
## ItemClass rows/names are read on demand from the shared original reader.
var _lazy: bool = false
const SHARED_TABLES: Array[String] = ["ItemClass","DescData_Korean","ItemBonus","Bonus"]
var problem: String = "원본523 미설치 · TWILIGHT 추정 정책"

func load_default_source() -> bool:
	# UNVERIFIED: reuse the existing exact original parser, without copying or
	# replacing source files. A present default, including an invalid one,
	# remains authoritative and must never be bypassed by another archive.
	if FileAccess.file_exists(PATH): return load_pack(PATH)
	var existing: String = CommonSource.archive_path()
	return load_pack(existing) if not existing.is_empty() else false

func load_pack(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SHA: return false
	var archive := ZIPReader.new()
	if archive.open(path) != OK: return false
	var tables: Dictionary = {}
	# The shared reader holds the same pinned archive bytes. Its large tables
	# (ItemClass, DescData_Korean, ItemBonus, Bonus) are read there instead of
	# parsing ~1 GB of rows again; ItemClass rows and names are indexed lazily.
	var shared: bool = CommonSource.identity().get("source_sha256") == SHA
	for table: String in ["Experience","ItemClass","LandAttribute","Territories","DescData_Korean","UIMarketPurchase","MarketPurchase_Korean","MarketPayment_Korean","MarketPurchaseProduct","MarketProduct","Unit","IntangibleItemClass","Currency","ItemBonus","Bonus","ConstantData"]:
		if shared and table in SHARED_TABLES: continue
		var parser := JSON.new()
		var text: String = archive.read_file("content/"+table+".json").get_string_from_utf8()
		if table == "Experience":
			# JSON numbers become doubles in Godot. Preserve original decimal
			# integers before parsing: adjacent159/160 cumulative values exceed2^53.
			var exact := RegEx.new()
			if exact.compile('"(CumulativeExperience|ExperienceLossOnDie)"\\s*:\\s*([0-9]+)') != OK: archive.close(); return false
			text = exact.sub(text,'"$1":"$2"',true)
		if parser.parse(text) != OK or not parser.data is Dictionary or not parser.data.get("rows") is Array:
			archive.close(); return false
		tables[table] = parser.data.rows
	archive.close()
	if tables.Experience.size() != 160 or (CommonSource.row_count("ItemClass") if shared else tables.ItemClass.size()) != 34743: return false
	var next_exp: Dictionary = {}
	for row: Dictionary in tables.Experience: next_exp[int(row.Level)] = row
	var next_item_exemption: int = read_item_exemption_level(tables.ConstantData,next_exp.size())
	if next_item_exemption < 0: return false
	var descriptions: Dictionary = {}
	var next_items: Dictionary = {}
	var next_names: Dictionary = {}
	if shared:
		for id: String in ["895","198494"]: _shared_item(id,next_items,next_names)
	else:
		for row: Dictionary in tables.DescData_Korean: descriptions[int(row.ID)] = str(row.Description)
		for row: Dictionary in tables.ItemClass:
			var id: String = str(int(row.ID))
			next_items[id] = row
			next_names[id] = [str(descriptions.get(int(row.DescID),"")),str(descriptions.get(int(row.IdentifiedDescID),""))]
	var next_territories: Dictionary = {}
	for row: Dictionary in tables.Territories: next_territories[int(row.ID)] = row
	var next_certificates: Dictionary = {}
	# Permanent native currencies only. Event/dated names are deliberately not
	# collapsed into this wallet contract, even if their display names coincide.
	for id: String in ["895","198494"]:
		if next_items.has(id) and int(next_items[id].CategoryID) == 122 and not bool(next_items[id].TestItem):
			next_certificates[id] = str(next_names[id][1]) if shared else str(descriptions.get(int(next_items[id].IdentifiedDescID),""))
	var indexed: Dictionary = {}
	for table: String in ["MarketPurchase_Korean","MarketPayment_Korean","MarketProduct","Unit","IntangibleItemClass","Currency"]:
		indexed[table] = {}
		for row: Dictionary in tables[table]: indexed[table][int(row.ID)] = row
	var next_offers: Dictionary = {}
	var death_bonuses: Dictionary = {}
	for row: Dictionary in (CommonSource.rows_matching("Bonus","BonusTypeID",{3103:true}) if shared else tables.Bonus):
		if int(row.BonusTypeID) == 3103: death_bonuses[int(row.ID)] = int(row.Value)
	var next_death_stats: Dictionary = {}
	for row: Dictionary in (CommonSource.rows_matching("ItemBonus","BonusID",death_bonuses) if shared else tables.ItemBonus):
		if not bool(row.IsPossession) and death_bonuses.has(int(row.BonusID)):
			var id: String = str(int(row.ItemClassID))
			next_death_stats[id] = int(next_death_stats.get(id,0))+int(death_bonuses[int(row.BonusID)])
	for link: Dictionary in tables.UIMarketPurchase:
		var kind: String = {"ExtensionRestorationExpSlot":"exp","ExtensionRestorationItemSlot":"item"}.get(str(link.Name),"")
		if kind.is_empty(): continue
		var purchase: Dictionary = indexed.MarketPurchase_Korean.get(int(link.MarketPurchaseID),{})
		if purchase.is_empty(): continue
		var payment: Dictionary = indexed.MarketPayment_Korean.get(int(purchase.MarketPaymentID),{})
		if payment.is_empty(): continue
		var unit: String = str(indexed.Unit.get(int(payment.UnitID),{}).get("Name",""))
		var currency: Dictionary = indexed.IntangibleItemClass.get(int(payment.ClassID),{}) if unit == "IntangibleItemClassID" else indexed.Currency.get(int(payment.ClassID),{}) if unit == "CurrencyID" else {}
		if currency.get("Name","") != "Gem" or int(payment.Amount) <= 0: continue
		for product_link: Dictionary in tables.MarketPurchaseProduct:
			if int(product_link.MarketPurchaseID) != int(purchase.ID): continue
			var product: Dictionary = indexed.MarketProduct.get(int(product_link.MarketProductID),{})
			if product.is_empty() or indexed.Unit.get(int(product.UnitID),{}).get("Name","") != "MarketProductBehaviorID" or int(product.Amount) <= 0: continue
			# Behavior implementations are absent from523. The UI's explicit
			# restoration kind maps this purchase onto our persisted local slots.
			next_offers[kind] = {"cost":int(payment.Amount),"amount":int(product.Amount),"purchase_id":int(purchase.ID),"product_id":int(product.ID),"behavior_id":int(product.ClassID)}
	_lazy = shared
	experience = next_exp; items = next_items; item_names = next_names; territories = next_territories
	certificates = next_certificates; slot_offers = next_offers
	item_death_stats = next_death_stats
	source_item_exemption_level = next_item_exemption
	attributes = tables.LandAttribute
	ready = true; problem = "최신523 원본 규칙 · 로컬 투영/추정 정책 별도"
	return true

func install(path: String) -> String:
	var candidate = get_script().new()
	if not candidate.load_pack(path): return "원본523 ZIP의 SHA 또는 정의표가 다릅니다"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir())) != OK: return "규칙 폴더 생성 실패"
	var temporary: String = PATH+".tmp"
	if DirAccess.copy_absolute(path,temporary) != OK or FileAccess.get_sha256(temporary) != SHA: return "규칙 복사 실패 · 이전 팩 보존"
	if DirAccess.rename_absolute(temporary,PATH) != OK: return "규칙 설치 실패 · 이전 팩 보존"
	if not load_pack(): return "규칙 재확인 실패"
	return ""

static func read_item_exemption_level(rows: Array, maximum_level: int) -> int:
	var matches: int = 0
	var result: int = -1
	for raw: Variant in rows:
		if not raw is Dictionary: return -1
		if raw.get("Name") != "NoDeathPenaltyLevel": continue
		matches += 1
		if typeof(raw.get("ID")) not in [TYPE_INT,TYPE_FLOAT] or raw.ID != 11071: return -1
		if typeof(raw.get("Type")) not in [TYPE_INT,TYPE_FLOAT] or raw.Type != 1: return -1
		if not raw.get("Value") is String: return -1
		var value: String = raw.Value
		if not value.is_valid_int(): return -1
		result = int(value)
		if value != str(result) or result < 0 or result > maximum_level: return -1
	return result if matches == 1 else -1

func item_exemption_level() -> int:
	return source_item_exemption_level if ready and source_item_exemption_level >= 0 else REVIEWED_ITEM_EXEMPTION_LEVEL

func item_exemption_origin() -> String:
	return "SOURCE_CONSTANT_APPLIED_TO_LOCAL_ITEM_POLICY" if ready and source_item_exemption_level >= 0 else "TWILIGHT_REVIEWED_DEFAULT"

## Original ItemClass row by ID string ({} when absent).
func item(id: String) -> Dictionary:
	if _lazy and not items.has(id): _shared_item(id,items,item_names)
	return items.get(id,{})

static func _shared_item(id: String, rows: Dictionary, names: Dictionary) -> void:
	if not id.is_valid_int() or id != str(int(id)): return
	var matches: Array[Dictionary] = CommonSource.related("ItemClass","ID",int(id))
	if matches.is_empty(): return
	var row: Dictionary = matches[-1] # Same as the last-wins full index.
	rows[id] = row
	names[id] = [_description(row.get("DescID")),_description(row.get("IdentifiedDescID"))]

static func _description(id: Variant) -> String:
	if not (id is int or id is float): return ""
	var matches: Array[Dictionary] = CommonSource.related("DescData_Korean","ID",int(id))
	return str(matches[-1].Description) if not matches.is_empty() else ""

func matches_item(record: Dictionary, id: String) -> bool:
	# Inven/community and native IDs are never joined by number alone. Keep
	# blessing/variant words intact; missing or differing names are ineligible.
	return ready and not item(id).is_empty() and str(record.get("sourceId","")) == id and not str(record.get("name","")).is_empty() and item_names.get(id,[]).has(str(record.name))

func row(level: int) -> Dictionary:
	return experience.get(level,{})

func exp_loss(level: int, current: int, need: int) -> int:
	if level < 30: return 0
	var source: Dictionary = row(level)
	if source.is_empty(): return mini(current,maxi(0,int(floor(need*fallback_loss_percent/100.0))))
	var previous: Dictionary = row(level-1)
	var span: int = int(source.CumulativeExperience)-int(previous.get("CumulativeExperience",0))
	if span <= 0 or int(source.ExperienceLossOnDie) > span:
		# Placeholder cumulative progression97+ cannot define a meaningful
		# projection onto the existing local curve. Use the labeled local policy.
		return mini(current,maxi(0,int(floor(need*fallback_loss_percent/100.0))))
	# Fractional projection onto TWILIGHT's existing curve; no level rollback.
	return int(floor(minf(float(current),maxf(0.0,float(need)*int(source.ExperienceLossOnDie)/span))))

func cost(level: int) -> int:
	return maxi(0,int(row(level).get("RestorationCost",level*level*fallback_cost_factor)))

func land_policy(land_id: int, source_position: Vector2) -> Dictionary:
	var out: Dictionary = {"no_exp":false,"no_item":false,"no_penalty":false,"npc_penalty":false,"full_revive":false,"source":false}
	if not ready or land_id < 0: return out
	for raw: Dictionary in attributes:
		if int(raw.LandID) != land_id: continue
		var kind: int = int(raw.LandAttributeTypeID)
		if kind not in [3,4,494,878,1122]: continue
		var territory_id: int = int(raw.TerritoryID)
		if territory_id != 0:
			if not source_position.is_finite() or not territories.has(territory_id): continue
			var t: Dictionary = territories[territory_id]
			if int(t.LandID) != land_id or source_position.x < mini(int(t.StartX),int(t.EndX)) or source_position.x > maxi(int(t.StartX),int(t.EndX)) or source_position.y < mini(int(t.StartY),int(t.EndY)) or source_position.y > maxi(int(t.StartY),int(t.EndY)): continue
		out.source = true
		if kind == 3: out.no_item = bool(raw.Value)
		if kind == 4: out.no_exp = bool(raw.Value)
		if kind == 494: out.npc_penalty = bool(raw.Value)
		if kind == 878: out.full_revive = bool(raw.Value)
		if kind == 1122: out.no_penalty = bool(raw.Value)
	return out
