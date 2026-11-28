extends SceneTree
## Original 523 아이템 컬렉션 (scripts/collections/item_book523_*.gd) over a
## fixture of the original ItemBook tables (no original files needed):
## tab classification and the left-out rows (혈맹, 다른 서버 전용, growth96's
## Level 96), card alternatives, bag possibility, registration commit /
## refusal / failed save, legacy 장비 컬렉션 links that never edit the legacy
## records, preserved unreadable saves, the window's page/tab rows, and the
## world/menu wiring.
const Source = preload("res://scripts/collections/item_book523_source.gd")
const Runtime = preload("res://scripts/collections/item_book523_runtime.gd")
const WINDOW = preload("res://scripts/ui/original_ui/source_main_item_book_window.gd")
const LEGACY = preload("res://scripts/collections/equipment_collection_runtime.gd")
const ORIGINAL_PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const MENU_TILES = preload("res://scripts/ui/original_ui/source_main_menu_tiles.gd")
var checks: int = 0
var failures: Array[String] = []

class Reader extends RefCounted:
	var tables: Dictionary = {}
	func rows(table: String) -> Array:
		return tables.get(table, [])
	func row(table: String, id: int) -> Dictionary:
		for value: Dictionary in tables.get(table, []):
			if int(value.ID) == id: return value
		return {}
	func related(table: String, field: String, id: int) -> Array:
		var found: Array = []
		for value: Dictionary in tables.get(table, []):
			if int(value.get(field, -1)) == id: found.append(value)
		return found
	func problem() -> String:
		return ""

class Legacy extends RefCounted:
	var progress: Dictionary = {}
	var defs: Array = []
	func definitions() -> Array:
		return defs.duplicate(true)

class FakeHud extends Node:
	var logs: Array = []
	func append_log(text: String) -> void: logs.append(text)
	func refresh_inventory(_items: Dictionary) -> void: pass

class Host extends Node:
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var equipped_items: Dictionary = {}
	var equipment_collections = Legacy.new()
	var item_book523
	var growth96
	var hud
	var saves: Array = []
	var fail_save: bool = false
	func _save_game(_quiet: bool, overrides: Dictionary = {}) -> Error:
		if fail_save: return ERR_CANT_CREATE
		saves.append(overrides.duplicate(true))
		return OK
	func _update_hud() -> void: pass
	var invalidated: int = 0
	func _invalidate_equipment_static() -> void: invalidated += 1

## Registration with a fixture proof (the real proof needs original records).
class TestRuntime extends "res://scripts/collections/item_book523_runtime.gd":
	func _prove(option: Dictionary, expected_uid: String = "") -> Dictionary:
		var found: Array = []
		for uid: Variant in world.item_instances:
			if not expected_uid.is_empty() and uid != expected_uid: continue
			var entry: Dictionary = world.item_instances[uid]
			if int(entry.record.source_item_class_id) == int(option.item_class_id) and int(entry.level) == int(option.enchant) and int(entry.record.get("source_bless_raw", 1)) == int(option.bless):
				found.append({"uid":str(uid),"name":str(entry.name)})
		if found.size() >= int(option.amount): return {"ok":true,"kind":"equipment","items":found.slice(0, int(option.amount)),"option":option}
		return {"ok":false,"reasons":["없음"]}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ITEM_BOOK523_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

static func fixture() -> Reader:
	var reader := Reader.new()
	reader.tables = {
		"ItemBookCollectionMainTabType":[{"ID":2,"Name":"UnIdentified"},{"ID":12,"Name":"Identified"},{"ID":22,"Name":"Dungeon"},{"ID":32,"Name":"Level"},{"ID":42,"Name":"Event"},{"ID":58,"Name":"Alchemy"},{"ID":68,"Name":"All"},{"ID":78,"Name":"Clan"}],
		"ItemBookCollection":[
			{"ID":100,"DescID":9100,"GradeID":2,"IsEvent":false,"DisplayPriority":20,"IsRecommend":true,"Level":0,"ServerLimitSetID":0,"MainTabType":12,"Alchemy":false,"ExpireDateTimeID":0},
			{"ID":110,"DescID":9110,"GradeID":2,"IsEvent":false,"DisplayPriority":10,"IsRecommend":false,"Level":0,"ServerLimitSetID":0,"MainTabType":12,"Alchemy":false,"ExpireDateTimeID":0},
			{"ID":120,"DescID":9120,"GradeID":1,"IsEvent":true,"DisplayPriority":1,"IsRecommend":false,"Level":0,"ServerLimitSetID":0,"MainTabType":42,"Alchemy":false,"ExpireDateTimeID":7},
			{"ID":130,"DescID":9130,"GradeID":1,"IsEvent":false,"DisplayPriority":1,"IsRecommend":false,"Level":0,"ServerLimitSetID":0,"MainTabType":78,"Alchemy":false,"ExpireDateTimeID":0},
			{"ID":140,"DescID":9140,"GradeID":1,"IsEvent":false,"DisplayPriority":1,"IsRecommend":false,"Level":0,"ServerLimitSetID":522,"MainTabType":12,"Alchemy":false,"ExpireDateTimeID":0},
			{"ID":150,"DescID":9150,"GradeID":1,"IsEvent":false,"DisplayPriority":1,"IsRecommend":false,"Level":96,"ServerLimitSetID":0,"MainTabType":32,"Alchemy":false,"ExpireDateTimeID":0},
			{"ID":160,"DescID":9160,"GradeID":1,"IsEvent":false,"DisplayPriority":1,"IsRecommend":false,"Level":0,"ServerLimitSetID":512,"MainTabType":22,"Alchemy":false,"ExpireDateTimeID":0}],
		"ItemBookCardForCollection":[{"ID":1,"ItemBookCollectionID":100,"ItemBookCardID":1001},{"ID":2,"ItemBookCollectionID":100,"ItemBookCardID":1002},
			{"ID":3,"ItemBookCollectionID":110,"ItemBookCardID":1101},{"ID":4,"ItemBookCollectionID":120,"ItemBookCardID":1201},{"ID":5,"ItemBookCollectionID":130,"ItemBookCardID":1301},
			{"ID":6,"ItemBookCollectionID":140,"ItemBookCardID":1401},{"ID":7,"ItemBookCollectionID":150,"ItemBookCardID":1501},{"ID":8,"ItemBookCollectionID":160,"ItemBookCardID":1601},
			{"ID":9,"ItemBookCollectionID":110,"ItemBookCardID":1102}],
		"ItemBookCardForItem":[{"ID":1,"ItemBookCardID":1001,"ItemBookItemID":1},{"ID":2,"ItemBookCardID":1001,"ItemBookItemID":2},{"ID":3,"ItemBookCardID":1002,"ItemBookItemID":3},
			{"ID":4,"ItemBookCardID":1101,"ItemBookItemID":4},{"ID":5,"ItemBookCardID":1201,"ItemBookItemID":5},{"ID":6,"ItemBookCardID":1301,"ItemBookItemID":5},
			{"ID":7,"ItemBookCardID":1401,"ItemBookItemID":5},{"ID":8,"ItemBookCardID":1501,"ItemBookItemID":5},{"ID":9,"ItemBookCardID":1601,"ItemBookItemID":5},{"ID":10,"ItemBookCardID":1102,"ItemBookItemID":6}],
		"ItemBookItem":[{"ID":1,"ItemClassID":501,"Enchant":7,"BlessCode":1,"Amount":1,"ElementalType":0,"ElementalEnchant":0},{"ID":2,"ItemClassID":501,"Enchant":7,"BlessCode":2,"Amount":1,"ElementalType":0,"ElementalEnchant":0},
			{"ID":3,"ItemClassID":502,"Enchant":5,"BlessCode":1,"Amount":1,"ElementalType":0,"ElementalEnchant":0},{"ID":4,"ItemClassID":503,"Enchant":7,"BlessCode":1,"Amount":1,"ElementalType":0,"ElementalEnchant":0},
			{"ID":5,"ItemClassID":504,"Enchant":0,"BlessCode":1,"Amount":20,"ElementalType":0,"ElementalEnchant":0},{"ID":6,"ItemClassID":505,"Enchant":7,"BlessCode":1,"Amount":1,"ElementalType":0,"ElementalEnchant":0}],
		"ItemBookCollectionSlot":[{"ID":1,"ItemBookCollectionID":100,"SlotNo":1},{"ID":2,"ItemBookCollectionID":100,"SlotNo":2},{"ID":3,"ItemBookCollectionID":110,"SlotNo":1}],
		"ItemBookCollectionSlotBonus":[{"ID":1,"ItemBookCollectionSlotID":2,"BonusID":71,"GameClassID":0},{"ID":2,"ItemBookCollectionSlotID":1,"BonusID":70,"GameClassID":0},{"ID":3,"ItemBookCollectionSlotID":3,"BonusID":72,"GameClassID":0}],
		"Bonus":[{"ID":70,"BonusTypeID":1,"Value":30,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0},{"ID":71,"BonusTypeID":2,"Value":150,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0},{"ID":72,"BonusTypeID":1,"Value":10,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0}],
		"BonusType":[{"ID":1,"Name":"HPPlus","UnitID":1,"DescID":8001},{"ID":2,"Name":"ExperienceAdditionPercent","UnitID":3,"DescID":8002}],
		"Unit":[{"ID":1,"Name":"Value"},{"ID":3,"Name":"Percentage"}],
		"UIUnit":[{"ID":3,"UnitID":3,"Denominator":100}],
		"ServerLimit":[{"ID":1,"ServerLimitSetID":512,"WorldNo":1,"ServiceRegionCode":"KR"},{"ID":2,"ServerLimitSetID":522,"WorldNo":1,"ServiceRegionCode":"TW"}],
		"ItemClass":[{"ID":501,"Name":"a","IdentifiedDescID":7501,"DescID":0},{"ID":502,"Name":"b","IdentifiedDescID":7502,"DescID":0},{"ID":503,"Name":"c","IdentifiedDescID":7503,"DescID":0},{"ID":504,"Name":"d","IdentifiedDescID":7504,"DescID":0},{"ID":505,"Name":"e","IdentifiedDescID":7505,"DescID":0}],
		"DescData_Korean":[{"ID":9100,"Description":"MP를 위한 투자 Ⅰ"},{"ID":9110,"Description":"(각인) MP를 위한 투자 I"},{"ID":9120,"Description":"이벤트 모음"},{"ID":9130,"Description":"혈맹 모음"},{"ID":9140,"Description":"대만 전용"},{"ID":9150,"Description":"96 증표"},{"ID":9160,"Description":"던전 모음"},
			{"ID":7501,"Description":"마법 망토"},{"ID":7502,"Description":"마법 방어 투구"},{"ID":7503,"Description":"마법 망토 (각인)"},{"ID":7504,"Description":"조각"},{"ID":7505,"Description":"마법 방어 투구 (각인)"},
			{"ID":8001,"Description":"최대 HP"},{"ID":8002,"Description":"경험치 추가"}]}
	return reader

static func equipment(id: int, enchant: int, bless: int = 1) -> Dictionary:
	return {"name":"장비#%d" % id,"level":enchant,"record":{"source_m_native_item":true,"source_item_class_id":id,"source_bless_raw":bless,"name":"장비#%d" % id}}

func _run() -> void:
	_source()
	_runtime()
	_legacy()
	_window()
	_effects()
	_wiring()
	_bake()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--notice-pack="): _notices(arg.trim_prefix("--notice-pack="))
	print("ITEM_BOOK523_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if not failures.is_empty() else 0)

func _source() -> void:
	var source := Source.new()
	check(source.load_source(fixture()), "the fixture tables load: " + source.problem)
	check(source.order == ["120","160","110","100"], "listed in DisplayPriority then ID order: " + str(source.order))
	check(source.excluded == {"clan":1,"server":1,"growth96":1,"empty":0}, "혈맹, 다른 서버 전용 and growth96's Level 96 rows are left out: " + str(source.excluded))
	check(source.collection("160").tab_button == "Btn_Dungeon", "a KR world-1 server set stays listed")
	check(source.tab_rows("Btn_Identified").size() == 2 and source.tab_rows("Btn_All").size() == 4 and source.tab_rows("Btn_Level").is_empty(), "tabs split by MainTabType")
	var cards: Array = source.collection("100").cards
	check(cards.size() == 2 and (cards[0].items as Array).size() == 2 and int(cards[0].items[1].bless) == 2, "a card keeps its normal and blessed alternatives")
	check(source.collection("120").approximations == [Source.APPROX_NO_DEADLINE], "a 기간 collection has no deadline (TWILIGHT 근사)")
	var effects: Array = source.effects_of("100")
	check(effects.size() == 2 and effects[0].display == "최대 HP +30" and effects[1].display == "경험치 추가 +1.5%", "slot bonuses in SlotNo order with Unit/UIUnit values: " + str(effects.map(func(e: Dictionary) -> String: return str(e.display))))
	check(source.option_label(cards[0].items[1]) == "+7 축복받은 마법 망토" and source.option_label(source.collection("120").cards[0].items[0]) == "조각 x20", "slot labels: enchant, bless and amount")
	var empty := Source.new()
	check(not empty.load_source(Reader.new()) and not empty.problem.is_empty(), "no original tables: not ready, with a reason")

func _host(runtime_script: Script = TestRuntime) -> Host:
	var host := Host.new()
	host.hud = FakeHud.new()
	host.add_child(host.hud)
	root.add_child(host)
	host.item_book523 = runtime_script.new()
	host.item_book523.test_reader = fixture()
	host.item_book523.configure(host)
	return host

func _runtime() -> void:
	var host := _host()
	var book = host.item_book523
	host.item_instances = {"9":equipment(501, 7, 2), "8":equipment(502, 4), "7":equipment(503, 7)}
	host.inventory = {"장비#501":1,"장비#502":1,"장비#503":1}
	host.equipped_items = {"cloak":{"instance_id":"7"}}
	var rows: Array = book.rows("Btn_Identified")
	var invest: Dictionary = rows[1]
	check(rows[0].id == "110" and invest.id == "100" and invest.required == 2 and invest.registered == 0, "rows of a tab")
	check(invest.cards[0].possible and not invest.cards[1].possible, "a blessed +7 copy makes its card possible; a +4 does not fill a +5 card")
	check(not rows[0].cards[0].possible, "an equipped item is not offered")
	var refused: Dictionary = book.quote("100", "1002")
	check(not refused.ok and refused.code == "missing" and str(refused.message).contains("+5 마법 방어 투구"), "missing item: the wanted original item is named")
	var offer: Dictionary = book.quote("100", "1001")
	check(offer.ok and offer.kind == "equipment" and int(offer.option.bless) == 2, "the blessed alternative is quoted")
	var focus: Dictionary = {"item_class_id":501,"uid":"9"}
	check(book.rows("Btn_All",501,"9")[0].cards[0].possible and book.rows("Btn_All",501,"missing")[0].cards[0].possible==false,"only the held focused reference lights the matching slot")
	check(not book.quote("100","1001",{"item_class_id":501,"uid":"missing"}).ok,"a different physical instance cannot fill a focused registration")
	focus["offer"] = book.quote("100","1001",focus)
	host.item_instances["9"].record.source_bless_raw=1
	check(book.execute("100","1001",int(offer.revision),focus).code=="stale" and host.saves.is_empty(),"a changed alternative of the same physical item keeps the original offer unspent")
	host.item_instances["9"].record.source_bless_raw=2
	host.fail_save = true
	var failed: Dictionary = book.execute("100", "1001", int(offer.revision))
	check(not failed.ok and failed.code == "save" and host.item_instances.has("9") and book.state.registered.is_empty(), "a failed save changes nothing")
	host.fail_save = false
	var stale: Dictionary = book.execute("100", "1001", int(offer.revision) + 5)
	check(not stale.ok and stale.code == "stale", "a stale quote is refused")
	var done: Dictionary = book.execute("100", "1001", int(offer.revision))
	check(done.ok and not done.completed and not host.item_instances.has("9") and not host.inventory.has("장비#501"), "registering consumes the bag item")
	var saved: Dictionary = host.saves[-1]
	check(saved.has(Runtime.SAVE_KEY) and saved.has("inventory") and saved.has("item_instances") and not saved.item_instances.has("9"), "bag and registration are one save")
	var record: Dictionary = book.state.registered["100"]["1001"]
	check(int(record.item_class_id) == 501 and int(record.bless) == 2 and record.physical_ids == ["9"], "the registration keeps the original row it used")
	check(not book.quote("100", "1001").ok and book.quote("100", "1001").code == "registered", "a registered card is not registered twice")
	check(book.rows("Btn_Identified")[1].registered == 1 and str(book.detail(book.rows("Btn_Identified")[1]).cards[0].label) == "+7 축복받은 마법 망토", "the row shows the registered alternative")
	host.item_instances["11"] = equipment(502, 5)
	host.inventory["장비#502"] = 2
	var second: Dictionary = book.quote("100", "1002")
	check(book.execute("100", "1002", int(second.revision)).completed and book.complete("100"), "the last card completes the collection")
	# Saves.
	var exported: Dictionary = book.export_state()
	check(Runtime.validate(exported).is_empty(), "the exported state validates")
	var other := _host()
	other.item_book523.import_state(exported)
	check(other.item_book523.complete("100") or (other.item_book523.prepare() and other.item_book523.complete("100")), "a loaded state keeps its registrations")
	other.item_book523.import_state({"schema":99,"registered":[]})
	check(other.item_book523.export_state() == {"schema":99,"registered":[]} and not other.item_book523.quote("100", "1001").ok, "an unreadable save is preserved as it was and blocks registering")
	other.item_book523.import_state(null)
	check(other.item_book523.export_state() == Runtime.fresh(), "no save: a fresh state")
	host.queue_free()
	other.queue_free()

func _legacy() -> void:
	var host := _host()
	var legacy: Legacy = host.equipment_collections
	legacy.defs = [{"id":"eqc_a","name":"MP를 위한 투자 I","source_names":["MP를 위한 투자 I","(각인) MP를 위한 투자 I"],
		"requirements":[{"slot_id":"eqc_a:slot:1","name":"마법 망토","enchant":7,"quantity":1},{"slot_id":"eqc_a:slot:2","name":"마법 방어 투구","enchant":5,"quantity":1}]},
		{"id":"eqc_b","name":"다른 이름","source_names":[],"requirements":[{"slot_id":"eqc_b:slot:1","name":"마법 망토","enchant":7,"quantity":1}]}]
	legacy.progress = {"schema_version":2,"revision":3,"gear":{},"progress":{"eqc_a":{"eqc_a:slot:1":["41","42"],"eqc_a:slot:2":["43"]},"eqc_b":{"eqc_b:slot:1":["44"]}},
		"receipts":{"41":{"original_name":"마법 망토 (각인) · 원본#503","enchant":7},"42":{"original_name":"마법 망토","enchant":7},"43":{"original_name":"마법 방어 투구","enchant":6},"44":{"original_name":"마법 망토","enchant":7}}}
	var before: Dictionary = legacy.progress.duplicate(true)
	var book = host.item_book523
	check(book.prepare(), "the runtime prepares")
	var links: Dictionary = book.state.legacy_links
	check(links.get("110", {}).has("1101") and links["110"]["1101"].legacy_receipt_ids == ["41"], "an engraved legacy item links to the 각인 collection")
	check(links.get("100", {}).has("1001") and links["100"]["1001"].legacy_receipt_ids == ["42"], "a plain legacy item links to the plain collection")
	check(not links.get("100", {}).has("1002"), "a legacy item of another enchant is not linked (kept in the legacy save only)")
	var linked: Array = []
	for cid: String in links:
		for card: String in links[cid]: linked.append_array(links[cid][card].legacy_receipt_ids)
	check(not linked.has("44"), "a legacy collection without a same-named original collection stays legacy-only")
	check(legacy.progress == before, "legacy records are never edited")
	check(book.card_registered("110", "1101") and book.registered_count("100") == 1, "linked cards count as registered")
	var again: int = book.link_legacy()
	check(again == 0, "linking is idempotent")
	check(not book.quote("110", "1101").ok, "a linked card is not registered again")
	host.queue_free()

func _window() -> void:
	var rows: Array = []
	for index: int in range(WINDOW.PAGE*2+5): rows.append({"id":str(index),"complete":index % 2 == 0,"registered":1})
	var first: Dictionary = WINDOW.page_of(rows, 0)
	var last: Dictionary = WINDOW.page_of(rows, 9)
	check(first.pages == 3 and (first.rows as Array).size() == WINDOW.PAGE and last.page == 2 and (last.rows as Array).size() == 5, "pages of PAGE rows, clamped")
	check(WINDOW.page_of([], 0).pages == 1, "an empty tab has one page")
	check(WINDOW.TABS == ["Btn_All","Btn_UnIdentified","Btn_Identified","Btn_Dungeon","Btn_Event","Btn_Level","Btn_Alchemy"] and Source.TAB_BUTTONS.values().all(func(b: String) -> bool: return WINDOW.TABS.has(b)), "every original tab button has a source tab")
	var host := _host()
	var window := WINDOW.new()
	window._hud = weakref(host.hud)
	check(window._book() == host.item_book523 and window._book_ready(), "the window reads world.item_book523")
	check(window._rows_of("Btn_Event").size() == 1 and window._rows_of("Btn_All").size() == 4, "tab rows come from the original tables")
	var spec: Dictionary = window._spec()
	check(spec["ListView_Tab/Btn_Event"].visible and spec["ListView_Tab/Btn_All/On"].visible and spec["ListView_Tab/Btn_Event/Off"].visible, "all tabs show; the selected one is On")
	window._select_tab("Btn_Event")
	check(window.tab == "Btn_Event", "a tab button selects its tab")
	# 사용자 목록 9: no item name under a slot (the original keeps it hidden).
	var slot: Dictionary = WINDOW.slot_spec(false, true, false, 3, Callable())
	check(slot["Panel/Fx_Registration"] == {"exclude":true} and WINDOW.UNUSED_SLOT_NODES.all(func(name: String) -> bool: return slot["CommonSlot/"+name] == {"exclude":true}) and not slot.has("CommonSlot/Sp_IconSample") and not slot.has("CommonSlot/Sp_SlotBg"), "unused hidden slot layers are not built (icon and frame stay)")
	check(slot["Panel/Text_ItemName"] == {"exclude":true} and not slot["Panel/Item_Own"].visible and slot["Panel/Item_Possible"].visible and slot["Panel/Text_Amount"].text == "3", "a slot shows its icon, marks and amount, never the item name")
	check(WINDOW.slot_spec(true, false, false, 1, Callable())["Panel/Item_Own"].visible, "a registered slot shows Item_Own")
	var plain := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var gray: ShaderMaterial = preload("res://scripts/ui/original_ui/source_material.gd").gray_blur(plain)
	check(gray != null and gray.shader.code.contains("luminance") and gray.shader.code.contains("blend_mix") and preload("res://scripts/ui/original_ui/source_material.gd").gray_blur(plain) == gray, "an unregistered icon gets the shared gray blur shader")
	check(not preload("res://scripts/ui/original_ui/source_material.gd").takes_display(gray), "display colour binding leaves the gray icon alone")
	host.queue_free()

func _notices(pack_dir: String) -> void:
	var pack := ORIGINAL_PACK.new()
	check(pack.open(pack_dir,OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")).get("ok",false),"the installed original notice art is verified")
	var host := _host()
	var window := WINDOW.new()
	check(window.configure(pack,host.hud).get("ok",false),"the collection row uses the verified pack")
	var notices: Array[bool]=[]
	for held: bool in [false,true]:
		if held:
			host.item_instances["10"] = equipment(501,7)
			host.inventory["장비#501"] = 1
		var projected: Array=window._rows_of("Btn_Identified").filter(func(row: Dictionary)->bool:return row.id=="100")
		if projected.is_empty():break
		var out: Dictionary={}
		var row: Dictionary=window._collection_row(projected[0])
		var built: Dictionary=window._scene_of(row.member,row.spec,out)
		if not built.get("ok",false):break
		var marker: Dictionary=window._locate(built.scene,out,"Panel_Itembook/Icon_New")
		var node: Node2D=marker.player.source_nodes.get(marker.offset) if marker.get("ok",false) else null
		notices.append(is_instance_valid(node) and node.visible)
		built.scene.free()
	check(notices==[false,true],"only an actionable original collection row displays its authored notice")
	var tiles := MENU_TILES.new()
	tiles.configure(pack)
	var stat_notices: Array[bool]=[]
	for points: int in [0,2]:
		var tile: Dictionary=tiles.tile("character",points)
		if not tile.get("ok",false):break
		var marker: Node2D=tile.scene.source_nodes.get(612)
		stat_notices.append(is_instance_valid(marker) and marker.visible)
		tile.scene.free()
	check(stat_notices==[false,true],"the character tile displays its original notice only when stat points are available")
	window.close()
	host.queue_free()

## 2단계: complete original collections add their effects; a legacy
## collection stops counting once a linked original collection is complete.
func _effects() -> void:
	var host := _host()
	var legacy = LEGACY.new()
	legacy.world = host
	var defs: Dictionary = {"collections":[{"id":"eqc_a","name":"MP를 위한 투자 I","source_names":[],"data_ready":true,"review_reasons":[],
		"effects":[{"key":"max_mp","unit":"flat","value":10,"raw":"최대 MP +10"}],"requirements":[{"slot_id":"eqc_a:slot:1","name":"마법 망토","enchant":7,"quantity":1}]}]}
	check(legacy.core.configure(defs, [{"source_id":"s1","name":"마법 망토","kind":"equipment"}], ["max_mp:flat"]), "legacy fixture configures: " + legacy.core.last_error)
	legacy._rows = legacy.core.definitions()
	legacy.progress = {"schema_version":2,"revision":1,"gear":{},"progress":{"eqc_a":{"eqc_a:slot:1":["41"]}},"requests":{},"favorites":[],"preserved_legacy":{},
		"receipts":{"41":{"instance_id":"41","source_id":"s1","original_name":"마법 망토","canonical_name":"마법 망토","enchant":7,"collection_id":"eqc_a","slot_id":"eqc_a:slot:1"}}}
	host.equipment_collections = legacy
	legacy._rebuild()
	check(legacy.totals == {"max_mp:flat":10.0}, "a complete legacy collection counts before any original record: " + str(legacy.totals))
	var book = host.item_book523
	check(book.effect_totals().totals.is_empty() and book.state.legacy_links.is_empty(), "no original records: nothing loaded, nothing added")
	check(book.prepare() and book.state.legacy_links.get("100", {}).has("1001"), "the legacy item links to the original card")
	legacy._rebuild()
	check(legacy.totals == {"max_mp:flat":10.0} and legacy.suppressed_by_item_book.is_empty(), "the legacy effect stays while the linked original collection is incomplete")
	host.item_instances = {"11":equipment(502, 5)}
	host.inventory = {"장비#502":1}
	var offer: Dictionary = book.quote("100", "1002")
	var done: Dictionary = book.execute("100", "1002", int(offer.revision))
	check(done.completed and host.invalidated > 0, "completing the original collection refreshes the stats")
	check(legacy.suppressed_by_item_book == {"eqc_a":true} and is_equal_approx(float(legacy.totals.get("max_mp:flat", -1)), 0.0), "the linked legacy collection stops counting")
	check(is_equal_approx(float(legacy.totals.get("max_hp:flat", 0)), 30.0) and is_equal_approx(float(legacy.totals.get("experience_bonus:percent", 0)), 1.5), "the original effects count once: " + str(legacy.totals))
	check(Runtime.stat_key({"type":"ElementalResistance","application_type":3,"application_target":1}) == "fire_resistance:percent" and Runtime.stat_key({"type":"PVPDamageReduction","application_type":0,"application_target":0}).is_empty(), "targeted and unsupported bonus types")
	var shown: Dictionary = book.detail(book.rows("Btn_Identified")[1])
	check(not str(shown.effects[0].display).contains("미적용"), "a supported effect is shown plainly")
	var armor: Dictionary = {"type":"ArmorClass","application_type":0,"application_target":0}
	check(Runtime.stat_key(armor) == "ac:flat" and Runtime.NEGATED_KEYS.has("ac:flat"), "물리 방어력 +1 is AC -1 in the World stat")
	host.queue_free()

func _wiring() -> void:
	var world: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world.contains("ITEM_BOOK523.SAVE_KEY: item_book523.export_state(),") and world.contains("item_book523.import_state(data.get(ITEM_BOOK523.SAVE_KEY))") and world.contains("DUNGEON_EXTRAS523.SAVE_KEY,ITEM_BOOK523.SAVE_KEY]"), "world saves, loads and admits the new save key")
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud.contains("if _open_original_feature(\"item_book\"):return\n\tif _hold_original_inventory_window(\"아이템 컬렉션\",") and hud.contains("open_legacy_equipment_collections()"), "장비 컬렉션 requires its selected original pack and retains the unconfigured offline route")
	check(world.contains("item_book523.import_state(data.get(ITEM_BOOK523.SAVE_KEY))\n\t# Original 아이템 컬렉션 effects join the collection stats (no double count).\n\tequipment_collections.refresh_item_book_totals()"), "a load recounts the collection stats")

## Real archive only: the baked collection rows are the rows a fresh walk of
## the seven tables builds, and a second load reads them back from the bake.
func _bake() -> void:
	if str(Source.COMMON_SOURCE.identity().get("source_sha256", "")).is_empty(): return
	var first := Source.new()
	check(first.load_source(), "the real archive loads: " + first.problem)
	var fresh := Source.new()
	fresh.reader = Source.CommonReader.new()
	check(fresh._build(), "the real archive builds without the bake: " + fresh.problem)
	var key: String = first._bake_key()
	check(not key.is_empty() and Source.BAKE.read(Source.BAKE_NAME, key) is Dictionary, "the collection rows are baked")
	var again := Source.new()
	again.reader = Source.CommonReader.new()
	check(again._read_bake(key), "a second load reads the bake")
	for loaded: Source in [first, again]:
		check(loaded.order == fresh.order and loaded.card_owner == fresh.card_owner and loaded.excluded == fresh.excluded and loaded.collections == fresh.collections, "baked rows equal a fresh walk (%d collections)" % fresh.order.size())
	check(again.effects_of(again.order[0]) == fresh.effects_of(fresh.order[0]), "effect lines resolve the same from baked rows")
