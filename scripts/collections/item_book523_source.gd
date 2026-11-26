extends RefCounted
## The original 523 아이템 컬렉션 (ItemBook) tables as TWILIGHT collection rows.
## ItemBookCollection -> ItemBookCardForCollection -> ItemBookCard ->
## ItemBookCardForItem -> ItemBookItem (ItemClassID, Enchant, BlessCode,
## Amount); a card is one registration slot and its ItemBookItem rows are the
## alternatives that fill it (e.g. the normal and the blessed copy of one
## item). ItemBookCollectionSlot / ItemBookCollectionSlotBonus are the
## collection's effect lines (one Bonus per slot row).
##
## Scope (user decisions): the 혈맹 tab (MainTabType Clan) is online-only and
## left out; rows limited to another service region/world (ServerLimitSetID
## without a KR world 1 row) are "다른 서버 전용" and left out; the Level 96
## 증표 collections stay with growth96 (scripts/progression/growth96_source.gd)
## so nothing is listed or applied twice. ExpireDateTimeID (기간 컬렉션) has no
## deadline in TWILIGHT (TWILIGHT 근사, like the crafting policy).
## Nothing here reads or writes a save; the reader is the verified original
## definition archive (current523_definition_rows) or a test fixture.
const COMMON_SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BAKE_NAME: String = "item_book523_collections"
const BAKE_CODE: Array[String] = ["res://scripts/collections/item_book523_source.gd"]
## MainTabType -> the ItemBook_All tab button (ItemBookCollectionMainTabType).
const TAB_BUTTONS: Dictionary = {"UnIdentified":"Btn_UnIdentified","Identified":"Btn_Identified","Dungeon":"Btn_Dungeon","Event":"Btn_Event","Level":"Btn_Level","Alchemy":"Btn_Alchemy"}
const EXCLUDED_TABS: Array[String] = ["Clan"]
const GROWTH96_LEVEL: int = 96
const REGION: String = "KR"
const WORLD_NO: int = 1
const APPROX_NO_DEADLINE: String = "기간 컬렉션 · 기한 없음 (TWILIGHT 근사)"
const TABLES: Array[String] = ["ItemBookCollection","ItemBookCollectionMainTabType","ItemBookCardForCollection","ItemBookCardForItem","ItemBookItem","ItemBookCollectionSlot","ItemBookCollectionSlotBonus"]

## Reads the verified original archive (the shared definition reader).
class CommonReader extends RefCounted:
	func rows(table: String) -> Array:
		return COMMON_SOURCE.rows(table)
	func row(table: String, id: int) -> Dictionary:
		return COMMON_SOURCE.row(table, id)
	func related(table: String, field: String, id: int) -> Array:
		return COMMON_SOURCE.related(table, field, id)
	func problem() -> String:
		return COMMON_SOURCE.problem()

var reader: RefCounted
var ready: bool = false
var problem: String = ""
## Collection id (String) -> row; `order` keeps the original display order.
var collections: Dictionary = {}
var order: Array[String] = []
## Card id (String) -> collection id.
var card_owner: Dictionary = {}
var excluded: Dictionary = {"clan":0,"server":0,"growth96":0,"empty":0}
var _item_names: Dictionary = {}
var _server_allowed: Dictionary = {}

static func sid(value: Variant) -> String:
	return str(int(value))

static func _int(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func load_source(source_reader: RefCounted = null) -> bool:
	reader = source_reader if source_reader != null else CommonReader.new()
	ready = false
	problem = ""
	collections.clear()
	order.clear()
	card_owner.clear()
	_item_names.clear()
	_server_allowed.clear()
	excluded = {"clan":0,"server":0,"growth96":0,"empty":0}
	# The verified archive's collection rows never change for one archive:
	# read them back from the bake instead of walking the seven tables
	# (Twm diag 2026-11-26: first 장비 컬렉션 open 1.6 s, ~40,000 row
	# views plus ~75,000 ID conversions).
	var bake_key: String = _bake_key() if source_reader == null else ""
	if not bake_key.is_empty() and _read_bake(bake_key): return true
	if not _build(): return false
	if not bake_key.is_empty(): BAKE.write(BAKE_NAME, bake_key, {"collections":collections,"order":Array(order),"card_owner":card_owner,"excluded":excluded,"server_allowed":_server_allowed})
	return true

func _bake_key() -> String:
	var identity: String = str(COMMON_SOURCE.identity().get("source_sha256", ""))
	if identity.is_empty(): return ""
	return BAKE.key([identity, BAKE.code_key(BAKE_CODE)])

func _read_bake(bake_key: String) -> bool:
	var value: Variant = BAKE.read(BAKE_NAME, bake_key)
	if not value is Dictionary: return false
	for field: String in ["collections","card_owner","excluded","server_allowed"]:
		if not value.get(field) is Dictionary: return false
	if not value.get("order") is Array or (value.order as Array).is_empty(): return false
	for cid: Variant in value.order:
		if not cid is String or not (value.collections as Dictionary).has(cid): return false
	collections = value.collections
	order.assign(value.order)
	card_owner = value.card_owner
	excluded = value.excluded
	_server_allowed = value.server_allowed
	ready = true
	return true

func _build() -> bool:
	var tables: Dictionary = {}
	for table: String in TABLES:
		var rows: Array = reader.rows(table)
		if rows.is_empty():
			problem = "원본 아이템 컬렉션 표를 읽을 수 없습니다: " + table
			return false
		tables[table] = rows
	var tabs: Dictionary = {}
	for row: Dictionary in tables.ItemBookCollectionMainTabType:
		tabs[sid(row.ID)] = str(row.get("Name", ""))
	var items: Dictionary = {}
	for row: Dictionary in tables.ItemBookItem:
		if not _int(row.get("ID")) or not _int(row.get("ItemClassID")) or not _int(row.get("Enchant")) or not _int(row.get("BlessCode")) or not _int(row.get("Amount")):
			problem = "ItemBookItem 형식 오류"
			return false
		items[sid(row.ID)] = row
	var card_items: Dictionary = {}
	for link: Dictionary in tables.ItemBookCardForItem:
		var item: Dictionary = items.get(sid(link.get("ItemBookItemID", 0)), {})
		if item.is_empty(): continue
		var card: String = sid(link.ItemBookCardID)
		if not card_items.has(card): card_items[card] = []
		card_items[card].append({"item_class_id":int(item.ItemClassID),"enchant":int(item.Enchant),"bless":int(item.BlessCode),"amount":int(item.Amount),"book_item_id":int(item.ID)})
	var members: Dictionary = {}
	for link: Dictionary in tables.ItemBookCardForCollection:
		var cid: String = sid(link.ItemBookCollectionID)
		if not members.has(cid): members[cid] = []
		members[cid].append(sid(link.ItemBookCardID))
	var slots: Dictionary = {}
	for slot: Dictionary in tables.ItemBookCollectionSlot:
		slots[sid(slot.ID)] = slot
	var effects: Dictionary = {}
	for link: Dictionary in tables.ItemBookCollectionSlotBonus:
		var slot: Dictionary = slots.get(sid(link.get("ItemBookCollectionSlotID", 0)), {})
		if slot.is_empty() or int(link.get("GameClassID", 0)) != 0: continue
		var cid: String = sid(slot.ItemBookCollectionID)
		if not effects.has(cid): effects[cid] = []
		effects[cid].append({"slot_no":int(slot.SlotNo),"bonus_id":int(link.BonusID)})
	var listed: Array = []
	for raw: Dictionary in tables.ItemBookCollection:
		var cid: String = sid(raw.ID)
		var tab: String = str(tabs.get(sid(raw.get("MainTabType", 0)), ""))
		if tab in EXCLUDED_TABS:
			excluded.clan += 1
			continue
		if not TAB_BUTTONS.has(tab):
			problem = "알 수 없는 컬렉션 탭: " + cid
			return false
		if int(raw.get("Level", 0)) == GROWTH96_LEVEL:
			excluded.growth96 += 1
			continue
		if not server_allowed(int(raw.get("ServerLimitSetID", 0))):
			excluded.server += 1
			continue
		var cards: Array = []
		for card: String in members.get(cid, []):
			var options: Array = card_items.get(card, [])
			if options.is_empty(): continue
			cards.append({"id":card,"items":options})
		if cards.is_empty():
			excluded.empty += 1
			continue
		var lines: Array = effects.get(cid, [])
		lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.slot_no) < int(b.slot_no))
		var row: Dictionary = {"id":cid,"name":_description(int(raw.get("DescID", 0)), "컬렉션 " + cid),"tab":tab,"tab_button":TAB_BUTTONS[tab],
			"grade_id":int(raw.get("GradeID", 0)),"priority":int(raw.get("DisplayPriority", 0)),"level":int(raw.get("Level", 0)),
			"event":bool(raw.get("IsEvent", false)),"alchemy":bool(raw.get("Alchemy", false)),"recommend":bool(raw.get("IsRecommend", false)),
			"cards":cards,"effect_links":lines,"effects":[],"approximations":[]}
		if int(raw.get("ExpireDateTimeID", 0)) != 0: row.approximations.append(APPROX_NO_DEADLINE)
		for card: Dictionary in cards: card_owner[str(card.id)] = cid
		collections[cid] = row
		listed.append(row)
	# Original order: the tab's DisplayPriority, then the table ID.
	listed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.priority) != int(b.priority): return int(a.priority) < int(b.priority)
		return int(a.id) < int(b.id))
	for row: Dictionary in listed: order.append(str(row.id))
	if order.is_empty():
		problem = "연결할 원본 아이템 컬렉션이 없습니다"
		return false
	ready = true
	return true

func server_allowed(set_id: int) -> bool:
	if set_id == 0: return true
	if _server_allowed.has(set_id): return bool(_server_allowed[set_id])
	var allowed: bool = false
	for limit: Dictionary in reader.related("ServerLimit", "ServerLimitSetID", set_id):
		if str(limit.get("ServiceRegionCode", "")) == REGION and int(limit.get("WorldNo", -1)) == WORLD_NO: allowed = true
	_server_allowed[set_id] = allowed
	return allowed

func _description(desc_id: int, fallback: String) -> String:
	if desc_id <= 0: return fallback
	var text: String = str(reader.row("DescData_Korean", desc_id).get("Description", ""))
	return text if not text.is_empty() else fallback

func collection(cid: String) -> Dictionary:
	return collections.get(cid, {})

func tab_rows(tab_button: String) -> Array:
	var found: Array = []
	for cid: String in order:
		var row: Dictionary = collections[cid]
		if tab_button == "Btn_All" or str(row.tab_button) == tab_button: found.append(row)
	return found

## The original display name of one ItemClass (IdentifiedDescID, else DescID).
func item_name(item_class_id: int) -> String:
	if _item_names.has(item_class_id): return str(_item_names[item_class_id])
	var raw: Dictionary = reader.row("ItemClass", item_class_id)
	var text: String = ""
	if not raw.is_empty():
		text = _description(int(raw.get("IdentifiedDescID", 0)), "")
		if text.is_empty(): text = _description(int(raw.get("DescID", 0)), "")
		if text.is_empty(): text = str(raw.get("Name", ""))
	if text.is_empty(): text = "원본 아이템 #" + str(item_class_id)
	_item_names[item_class_id] = text
	return text

## "+7 축복받은 이름 x2" for one ItemBookItem alternative.
func option_label(option: Dictionary) -> String:
	var text: String = item_name(int(option.item_class_id))
	if int(option.bless) == 2: text = "축복받은 " + text
	elif int(option.bless) == 3: text = "저주받은 " + text
	if int(option.enchant) > 0: text = "+%d %s" % [int(option.enchant), text]
	if int(option.amount) > 1: text += " x" + str(int(option.amount))
	return text

## Collection effect lines (Bonus -> BonusType -> Unit), resolved once.
func effects_of(cid: String) -> Array:
	var row: Dictionary = collections.get(cid, {})
	if row.is_empty(): return []
	if not row.effects.is_empty() or row.effect_links.is_empty(): return row.effects
	var lines: Array = []
	for link: Dictionary in row.effect_links:
		var bonus: Dictionary = reader.row("Bonus", int(link.bonus_id))
		if bonus.is_empty(): continue
		var type: Dictionary = reader.row("BonusType", int(bonus.get("BonusTypeID", 0)))
		var unit: String = str(reader.row("Unit", int(type.get("UnitID", 0))).get("Name", ""))
		var value: float = float(bonus.get("Value", 0))
		# UIUnit.Denominator scales the stored value for display (Percentage
		# 10000 = 1%, Weight 100 = 1); 0 means the value is shown as stored.
		var denominator: float = 0.0
		for ui: Dictionary in reader.related("UIUnit", "UnitID", int(type.get("UnitID", 0))): denominator = float(ui.get("Denominator", 0))
		if denominator <= 0.0 and unit == "Percentage": denominator = 10000.0
		if denominator > 0.0: value = value / denominator
		var label: String = _description(int(type.get("DescID", 0)), str(type.get("Name", "")))
		var number: String = str(int(value)) if value == floorf(value) else String.num(value, 2)
		var percent: bool = unit in ["Percentage","ValuePercent"]
		var display: String = label if unit == "TrueFalse" else "%s %s%s%s" % [label, "+" if value >= 0.0 else "", number, "%" if percent else ""]
		lines.append({"slot_no":int(link.slot_no),"bonus":bonus,"type":str(type.get("Name", "")),"unit":unit,"value":value,
			"application_type":int(bonus.get("BonusApplicationTypeID", 0)),"application_target":int(bonus.get("BonusApplicationTargetID", 0)),
			"display":display})
	row.effects = lines
	return lines

func audit() -> Dictionary:
	var counts: Dictionary = {}
	for cid: String in order:
		var tab: String = str(collections[cid].tab)
		counts[tab] = int(counts.get(tab, 0)) + 1
	return {"collections":order.size(),"tabs":counts,"excluded":excluded.duplicate()}
