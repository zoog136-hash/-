extends SceneTree
## The original 523 제작 window's 메인 / 한정 / 서버한정 tabs
## (scripts/crafting/craft_tabs523.gd) over a fixture of ItemCraftView /
## ItemCraftRecommend / ItemClass / ItemEquipSlot rows, and the 변신 window's
## 성급 강화 button wiring. No original files needed.
const Tabs = preload("res://scripts/crafting/craft_tabs523.gd")
const PRODUCTION = preload("res://scripts/ui/original_ui/source_main_production_window.gd")
const CHANGE = preload("res://scripts/ui/original_ui/source_main_change_window.gd")
var checks: int = 0
var failures: Array[String] = []

class Reader extends RefCounted:
	var tables: Dictionary = {}
	func rows(table: String) -> Array:
		return tables.get(table, [])
	func row(table: String, id: int) -> Dictionary:
		for value: Dictionary in tables.get(table, []):
			if int(value.get("ID", -1)) == id: return value
		return {}
	func related(table: String, field: String, id: int) -> Array:
		var found: Array = []
		for value: Dictionary in tables.get(table, []):
			if int(value.get(field, -1)) == id: found.append(value)
		return found

class Crafting extends RefCounted:
	var recipes: Dictionary = {}

class Host extends Node:
	var crafting = Crafting.new()
	var equipped_items: Dictionary = {}
	var item_instances: Dictionary = {}
	var job_class: String = "없는 직업"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CRAFT_TABS523_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

static func fixture() -> Reader:
	var reader := Reader.new()
	reader.tables = {
		"ItemCraftView":[{"ItemCraftID":1,"MainCategoryID":1},{"ItemCraftID":2,"MainCategoryID":41},{"ItemCraftID":3,"MainCategoryID":51},{"ItemCraftID":4,"MainCategoryID":41},{"ItemCraftID":5,"MainCategoryID":21}],
		"ItemCraftRecommend":[
			{"ID":10,"ItemCraftRecommendTypeID":1,"ItemCraftID":5,"Priority":3,"Param1Value":0,"Param2Value":0,"Param3Value":0,"IsEnabled":true},
			{"ID":11,"ItemCraftRecommendTypeID":1,"ItemCraftID":4,"Priority":3,"Param1Value":0,"Param2Value":0,"Param3Value":0,"IsEnabled":false},
			{"ID":12,"ItemCraftRecommendTypeID":41,"ItemCraftID":1,"Priority":1,"Param1Value":8,"Param2Value":4,"Param3Value":0,"IsEnabled":true},
			{"ID":13,"ItemCraftRecommendTypeID":41,"ItemCraftID":2,"Priority":1,"Param1Value":8,"Param2Value":5,"Param3Value":0,"IsEnabled":true},
			{"ID":14,"ItemCraftRecommendTypeID":51,"ItemCraftID":3,"Priority":2,"Param1Value":700,"Param2Value":30,"Param3Value":0,"IsEnabled":true},
			{"ID":15,"ItemCraftRecommendTypeID":31,"ItemCraftID":2,"Priority":0,"Param1Value":3,"Param2Value":0,"Param3Value":0,"IsEnabled":true},
			{"ID":16,"ItemCraftRecommendTypeID":1,"ItemCraftID":99,"Priority":0,"Param1Value":0,"Param2Value":0,"Param3Value":0,"IsEnabled":true}],
		"ItemClass":[{"ID":600,"GradeID":4},{"ID":700,"GradeID":1}],
		"ItemEquipSlot":[{"ItemClassID":600,"EquipSlotID":8}]}
	return reader

func _run() -> void:
	var reader := fixture()
	var host := Host.new()
	root.add_child(host)
	host.crafting.recipes = {"patch523:1":{"source_craft_id":1,"category":"무기"},"patch523:2":{"source_craft_id":2,"category":"방어구"},
		"patch523:3":{"source_craft_id":3,"category":"재료"},"patch523:4":{"source_craft_id":4,"category":"물약"},"patch523:5":{"source_craft_id":5,"category":"재료"},"local:x":{"category":"무기"}}
	check(Tabs.registry_ids(host.crafting.recipes).size() == 5, "only recipes with an original craft id take part")
	check(Tabs.by_main_category(host.crafting.recipes, Tabs.LIMITED_ACCOUNT, reader) == ["patch523:2","patch523:4"], "한정 = MainCategoryID 41")
	check(Tabs.by_main_category(host.crafting.recipes, Tabs.LIMITED_SERVER, reader) == ["patch523:3"], "서버한정 = MainCategoryID 51")
	host.equipped_items = {"weapon":{"instance_id":"w"}}
	host.item_instances = {"w":{"record":{"source_item_class_id":600},"level":7},"s":{"record":{"source_item_class_id":700},"source_native_stack_receipt":{},"source_native_stack_quantity":30}}
	var facts: Dictionary = Tabs.context(host, reader)
	check(facts.equipped == [[8,4]] and int(facts.held.get(700, 0)) == 30 and int(facts.held.get(600, 0)) == 1, "character facts: equipped slot/grade and held amounts: " + str(facts))
	check(Tabs.recommended(host.crafting.recipes, facts, reader) == ["patch523:1","patch523:3","patch523:5"], "메인: equipped grade, held amount and fixed rows in Priority order; disabled and missing recipes left out")
	facts.class_id = 3
	check(Tabs.recommended(host.crafting.recipes, facts, reader)[0] == "patch523:2", "a CharacterClass row for the character's class comes by its Priority")
	facts.held[700] = 29
	check(not Tabs.recommended(host.crafting.recipes, facts, reader).has("patch523:3"), "too few held items: not recommended")
	check(PRODUCTION.source_tab_ids(host, "limited", reader) == ["patch523:2","patch523:4"] and PRODUCTION.source_tab_ids(host, "server", reader) == ["patch523:3"] and PRODUCTION.source_tab_ids(host, "equip", reader).is_empty(), "the window's tabs read the same lists")
	check(not PRODUCTION.OFF_TABS.has("Btn_Main") and not PRODUCTION.OFF_TABS.has("Btn_LimitedAccount") and not PRODUCTION.OFF_TABS.has("Btn_LimitedServer") and PRODUCTION.SOURCE_TABS.values() == ["Btn_Main","Btn_LimitedAccount","Btn_LimitedServer"], "메인 / 한정 / 서버한정 are connected tabs")
	check(not CHANGE.star_target(null, "변신", "x") and not CHANGE.star_target(host, "마법인형", "x"), "성급 강화 needs the star-enchant owner's 변신 card")
	var change: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_change_window.gd")
	check(change.contains("hud.call(\"open_halphas_star_enchant\",target,focus)") and change.contains("const TRANSCEND=14884"), "성급 강화 opens the existing star-enchant window")
	host.queue_free()
	print("CRAFT_TABS523_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if not failures.is_empty() else 0)
