extends SceneTree
## Original 523 items the table fully defines but whose use has no table rule
## (or no TWILIGHT owner yet) are granted as receipted physical "storage"
## stacks: they can be received, kept, saved and reloaded with their exact
## original icon, and using one refuses and keeps it (no invented effect).
## Test-marked / dummy rows, wallets and unresolved lifetimes stay ungranted.
## Synthetic rules always run; with the original definition ZIP the real items
## are granted, used, saved and reloaded in actual Main.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const VIS = preload("res://scripts/ui/item_visual_resolver.gd")
const QA = preload("res://tests/qa_class_selection.gd")
## [시간 충전석][미션] 주말 월드 던전 시간 충전석: LandTimeRecharger, use rule
## (MaxRechargeTime meaning) not in the table -> storage.
const TIME_STONE := 202238
## [재료] 빛나는 비늘: a StackableItem material that no ItemCraftInput row uses -> storage.
const MATERIAL := 722
## [테스트] 버프 아이템 지급 (TestItem false, but a test name marker).
const TEST_MARKED := 122554
## [화폐] 변신 제작 코인: an existing wallet keeps its owner.
const WALLET := 3242
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_STORAGE_ITEMS_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(STACK.storage_profile({}).is_empty(), "a non-native record is never a storage stack")
	check(STACK.storage_profile({"source_m_native_item":true,"slot":"material","source_projection":"other"}).is_empty(), "another projection is not admitted")
	check(STACK.storage_exclusion({"ID":1.0,"Name":"[테스트] 버프 아이템 지급"})=="source_test_name_marker", "'[테스트]' is a test marker")
	check(STACK.storage_exclusion({"ID":1.0,"Name":"[BM] 빛나는 드래곤의 용옥 - test용"})=="source_test_name_marker", "'test용' is a test marker")
	check(STACK.storage_exclusion({"ID":1.0,"Name":"[더미] 아이템"})=="source_dummy_declaration", "'[더미]' is the original dummy declaration")
	check(STACK.storage_exclusion({"ID":1.0,"Name":"[재료] 금빛 훈장"}).is_empty(), "an ordinary name is not excluded")

func record(id: int) -> Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)

func table() -> void:
	for id: int in [TIME_STONE, MATERIAL]:
		var item: Dictionary = record(id)
		evidence["profile_%d" % id] = {"profile":STACK.profile(item).get("kind",""),"supply":STACK.supply_profile(item).get("kind","")}
		check(STACK.profile(item).is_empty() and STACK.supply_profile(item).get("kind")=="storage", "#%d has no use owner and is a storage stack" % id)
	check(STACK.supply_profile(record(TEST_MARKED)).is_empty(), "#%d (test marker) stays ungranted" % TEST_MARKED)
	check(STACK.storage_profile(record(WALLET)).is_empty(), "#%d wallet is not turned into a storage stack" % WALLET)

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}
	var origin: Dictionary = {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":TIME_STONE,"amount":3,"bless_raw":1,"enchant":0},{"item_class_id":MATERIAL,"amount":2,"bless_raw":1,"enchant":0}],origin)
	if not check(staged.get("ok",false), "physical grant: %s" % str(staged.get("error",""))): world.queue_free(); await process_frame; return
	check(world._save_game(true,staged.overrides)==OK, "grant save")
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var stone: String = str(record(TIME_STONE).name); var material: String = str(record(MATERIAL).name)
	check(int(world.inventory.get(stone,0))==3 and int(world.inventory.get(material,0))==2, "3 time stones and 2 materials in the bag")
	var shown: Dictionary = VIS.describe(world._find_catalog_item_record(stone))
	evidence["icon"] = {"route":shown.get("route",""),"status":shown.get("status",""),"texture":shown.get("texture") is Texture2D,"icon_id":int(record(TIME_STONE).get("source_original_item",{}).get("IconID",0)) if record(TIME_STONE).get("source_original_item") is Dictionary else -1}
	check(str(shown.get("status","")) in ["original_linked","original_icon_not_installed"], "the bag shows the item's own original IconID route (%s)" % str(shown.get("status","")))
	world.item_use_cooldowns.clear()
	var used: Dictionary = STACK.try_use(world,stone)
	evidence["use"] = {"ok":used.get("ok"),"reason":used.get("reason","")}
	check(used.get("handled",false) and not used.get("ok",true) and str(used.get("reason","")).contains("보관용") and int(world.inventory.get(stone,0))==3, "using it refuses and keeps all 3 (no invented effect)")
	var refused: Dictionary = INVENTORY.stage(world,[{"item_class_id":TEST_MARKED,"amount":1,"bless_raw":1,"enchant":0}],origin)
	check(not refused.get("ok",true), "a test-marked row is still refused")
	check(world._save_game(true)==OK, "save")
	world.inventory.erase(stone); world.inventory.erase(material); world.item_instances = {}
	world._load_game(true)
	evidence["reload"] = {"stone":int(world.inventory.get(stone,0)),"material":int(world.inventory.get(material,0))}
	check(int(world.inventory.get(stone,0))==3 and int(world.inventory.get(material,0))==2, "both stacks survive reload")
	var owned: int = 0
	for uid: String in world.item_instances:
		if not STACK.proof(world,uid).is_empty(): owned += 1
	check(owned==2, "both reloaded stacks keep their physical receipts (%d)" % owned)
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("ITEMS523_STORAGE_ITEMS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
