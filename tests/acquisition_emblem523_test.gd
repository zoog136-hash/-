extends SceneTree
## Original 523 획득처 안내 (ItemAcquisition*, NpcItemDropView, ItemCraftInputSource,
## TooltipMarketDisplayCategory, ItemDropBySpecialDungeonView, ItemCraftOutputView)
## and 혈맹 문장 (Emblem, EmblemSelectionRegion_Korean, EmblemType, AssetView,
## ClanExperience, ClanPolicies). Without the original definition ZIP only the
## fallback runs: nothing is shown, the emblem choice is refused and a saved
## choice is kept. With it the rows are compared with the tables, then in the
## actual Main: the inventory 획득처 button, the emblem choice, save -> reload.
const ACQ = preload("res://scripts/acquisition523/item_acquisition523.gd")
const EMB = preload("res://scripts/emblem523/emblem523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ACQEMB523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func state_rules() -> void:
	var emblem := EMB.new()
	emblem.import_state({})
	check(emblem.emblem_id==0 and emblem.problem.is_empty(), "an empty save has no emblem")
	emblem.import_state({"schema":1,"emblem_id":241})
	check(emblem.emblem_id==241 and emblem.export_state()=={"schema":1,"emblem_id":241}, "a saved emblem is kept as-is")
	emblem.import_state({"schema":2,"emblem_id":241})
	check(emblem.emblem_id==0 and not emblem.problem.is_empty(), "an unknown save schema is refused")
	emblem.import_state({"schema":1,"emblem_id":-4})
	check(emblem.emblem_id==0 and not emblem.problem.is_empty(), "a negative emblem id is refused")

func fallback() -> void:
	if not SOURCE.not_installed(): return
	ACQ.reset_cache(); EMB.reset_cache()
	check(not ACQ.available() and not ACQ.sources(3252).get("ok",true), "without the archive no source rows are shown")
	check(ACQ.summary_lines(ACQ.sources(3252)).is_empty(), "without the archive the detail text gets no source lines")
	check(not EMB.definition().get("ok",true), "without the archive the emblem list is unavailable")
	var emblem := EMB.new()
	emblem.emblem_id = 241
	check(not emblem.choose(null,181).get("ok",true) and emblem.emblem_id==241, "without the archive a choice is refused and the saved one kept")

func table() -> void:
	ACQ.reset_cache()
	var scroll: Dictionary = ACQ.classification(52)
	check(scroll.get("sub_category")=="ScrollEnchant" and scroll.get("category")=="Scroll", "ItemCategory 52 -> ItemAcquisition ScrollEnchant / Scroll")
	check(ACQ.classification(122).get("sub_category")=="EtcCurrency", "ItemCategory 122 (Currency) -> EtcCurrency")
	check(ACQ.classification(1).is_empty(), "a category without an ItemAcquisition row has no classification")
	var coin: Dictionary = ACQ.sources(3252)
	evidence["3252"] = {"mode":coin.get("mode"),"acquirements":coin.get("acquirements"),"drop_rows":coin.get("drop_rows_total"),"monsters":coin.get("drop_monsters"),"crafts":coin.get("crafts_total")}
	check(coin.get("ok",false) and coin.name=="마법인형 제작 코인", "ItemClass 3252 name from DescData_Korean")
	check(coin.get("mode")=="acquirement" and str(coin.acquirements[0].text)=="월드 보스" and coin.acquirements[0].kind=="craft_input_source", "ItemCraftInputSource text first (월드 보스)")
	var monsters: Dictionary = {}
	for row: Dictionary in SOURCE.rows_matching("NpcItemDropView","ItemClassID",{3252:true}): monsters[int(row.NpcClassID)] = true
	check(int(coin.drop_rows_total)>0 and int(coin.drop_monsters)<=monsters.size(), "drop monsters come from NpcItemDropView")
	var dungeon: Dictionary = ACQ.sources(9011)
	evidence["9011"] = {"mode":dungeon.get("mode"),"drops":dungeon.get("drops"),"acquirements":dungeon.get("acquirements")}
	check(dungeon.get("mode")=="drop" and dungeon.drops.size()==1 and dungeon.drops[0].location=="버림받은 자들의 땅", "drop place from NpcSpawnPack/Territories ShowInSourceList")
	check(dungeon.acquirements.size()==1 and dungeon.acquirements[0].destination=="source_dungeons" and str(dungeon.acquirements[0].text).contains("버림받은 자들의 땅"), "ItemDropBySpecialDungeonView -> special dungeon name")
	# GettablePlaceID -> TooltipMarketDisplayCategory -> MarketDisplayCategoryType
	var market_item: int = -1
	for row: Dictionary in SOURCE.rows_matching("ItemClass","GettablePlaceID",{3:true}):
		if row.get("TestItem")!=true: market_item = int(row.ID); break
	var market: Dictionary = ACQ.sources(market_item)
	var shop_rows: Array = (market.get("acquirements",[]) as Array).filter(func(row: Dictionary) -> bool: return row.kind=="market")
	evidence["market"] = {"item":market_item,"rows":shop_rows}
	check(shop_rows.size()==1 and shop_rows[0].text=="상점 · 패키지" and shop_rows[0].destination=="shop", "GettablePlaceID 3 -> MarketDisplayCategoryType Package (패키지)")
	EMB.reset_cache()
	var data: Dictionary = EMB.definition()
	if not check(data.get("ok",false), "emblem rows validate: "+str(data.get("problem",""))): return
	var selectable: int = 0
	for option: Dictionary in data.options: if option.selectable: selectable += 1
	evidence["emblems"] = {"options":data.options.size(),"selectable":selectable,"fee":data.fee,"first":data.options[0]}
	check(data.options.size()==SOURCE.rows("EmblemSelectionRegion_Korean").size() and data.options.size()==298, "298 Korean selection rows")
	check(data.options[0].id==181 and data.options[0].name=="일반 01" and data.options[0].large=="Emblem/Guild_Common_001.png", "first emblem: 일반 01, AssetView Guild_Common_001.png")
	check(selectable==42 and int(data.local_grade)==1, "local choice: Predefined emblems of clan level 1 only")
	check(int(data.fee.value)==0 and int(data.fee.class_id)==26, "EmblemChangeCommission 0 adena")
	var locked: Dictionary = EMB.new().choose(null,2233)
	check(not locked.get("ok",true) and str(locked.error).contains("혈맹"), "a clan-level / special emblem is refused")
	check(not EMB.new().choose(null,999999).get("ok",true), "an emblem outside the Korean list is refused")

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	check(world.get("emblem523")!=null and EMB.validate(world.emblem523.export_state()).is_empty(), "the world owns the emblem state")
	var installed: bool = not SOURCE.not_installed()
	if installed:
		var result: Dictionary = world.emblem523.choose(world,241)
		check(result.get("ok",false) and world.emblem523.emblem_id==241, "choose 일반 03 saves: "+str(result))
	else:
		world.emblem523.emblem_id = 241
		check(world._save_game(true)==OK, "save with an emblem")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://twilight_v20_save.json"))
	check(parsed is Dictionary and int(parsed.get("emblem523",{}).get("schema",0))==1 and int(parsed.get("emblem523",{}).get("emblem_id",0))==241, "the save holds emblem523")
	world.emblem523.emblem_id = 0
	world.emblem523.import_state(parsed.get("emblem523",{}) if parsed is Dictionary else {})
	check(world.emblem523.emblem_id==241, "reload keeps the emblem")
	if installed: check(world.emblem523.equipped().get("name","")=="일반 03", "equipped emblem row after reload")
	# Inventory detail: the 획득처 button and its fallback lines.
	var bag: Variant = world.hud.get("lineage_inventory_ui")
	check(is_instance_valid(bag) and bag.get("acquisition_button") is Button, "inventory detail has the 획득처 button")
	world.queue_free()
	await process_frame

func run() -> void:
	state_rules()
	fallback()
	if not SOURCE.not_installed(): table()
	await runtime()
	print("ACQEMB523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
