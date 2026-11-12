extends SceneTree
## Original 523 축복 포인트 충전 (ItemCategory IntangibleItemRecharger with
## IntangibleItemClass "BlessPoint" and IntangibleItemAmount) in the actual
## game: one physical unit adds the original amount to the existing symbol
## (문양) blessing points. Synthetic rows always run; with the original
## definition ZIP the real items are granted, used, saved and reloaded in Main.
const P = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
## 축복의 성수(대) "사용 시 축복 포인트 1000 획득" (no delete time): the symbol
## (문양) owner already registers it as its own material and keeps doing so.
const LARGE := 117304
## [이벤트] 축복의 성수(대) with a DeleteTime row: the symbol owner refuses it,
## the physical-stack owner uses it (existing lifetime rule).
const EVENT := 168024
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEMS523_BLESS_POINTS_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func bonus_row(id: int, name: String, unit: String, value: float) -> Dictionary:
	return {"ID":float(id),"IsPossession":false,"bonus_type":{"Name":name},"unit":{"Name":unit},"bonus":{"ID":float(id+1),"Value":value,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0}}

func fixture(class_id: float, amount: float) -> Dictionary:
	return {"original_item":{"ID":7000.0,"TargettingTypeID":1.0,"ServiceRegionCode":"","CanUseWhenInvisible":true},"category":{"Name":"IntangibleItemRecharger","IsConsumable":true},
		"item_bonus":[bonus_row(10,"IntangibleItemClassID","IntangibleItemClassID",class_id),bonus_row(20,"IntangibleItemAmount","Value",amount)]}

func intangible(id: int) -> Dictionary:
	return {14:{"ID":14.0,"Name":"BlessPoint"},2:{"ID":2.0,"Name":"Gem"}}.get(id,{})

func rules() -> void:
	check(P.described_bless_points("사용 시 축복 포인트 1000 획득") == [1000], "'축복 포인트 1000'")
	check(P.described_bless_points("축복포인트 1,000을 충전") == [1000], "'축복포인트 1,000' (no space, comma)")
	check(P.described_bless_points("축복 100") == [], "no '포인트': nothing")
	var spec: Dictionary = P.source_bless_points(fixture(14.0,1000.0),"사용 시 축복 포인트 1000 획득",intangible)
	evidence["fixture"] = spec
	check(spec.get("kind")=="source_bless_points" and spec.get("activation_status")=="unrestricted" and spec.get("points")==1000, "BlessPoint 1000 with a matching description is usable")
	check("description_bless_point_amount_mismatch" in P.source_bless_points(fixture(14.0,1000.0),"사용 시 축복 포인트 100 획득",intangible).get("blocked_reasons",[]), "a description stating another amount keeps the item")
	check("unsupported_intangible_item_class:2" in P.source_bless_points(fixture(2.0,1000.0),"축복 포인트 1000",intangible).get("blocked_reasons",[]), "IntangibleItemClass 2 (Gem) is not connected")
	var extra: Dictionary = fixture(14.0,10.0)
	extra.item_bonus.append(bonus_row(30,"UsageInterval","Seconds",60.0))
	check("unsupported_item_bonus:UsageInterval" in P.source_bless_points(extra,"축복 포인트 10",intangible).get("blocked_reasons",[]), "another row keeps the item")
	var other: Dictionary = fixture(14.0,10.0); other.category.Name = "Potion"
	check(P.source_bless_points(other,"축복 포인트 10",intangible).is_empty(), "only IntangibleItemRecharger is read")

func record(id: int) -> Dictionary:
	return D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)

func table() -> void:
	var spec: Dictionary = FIELDS.full(record(LARGE)).get("source_use_spec",{})
	evidence["large"] = {"kind":spec.get("kind"),"status":spec.get("activation_status"),"reasons":spec.get("blocked_reasons"),"points":spec.get("points")}
	check(spec.get("kind")=="source_bless_points" and spec.get("activation_status")=="unrestricted" and spec.get("points")==1000 and STACK.profile(record(LARGE)).get("kind")=="bless_points", "#117304: BlessPoint 1000 → bless_points profile")
	var categories: Dictionary = {}
	for category: Dictionary in SOURCE.rows("ItemCategory"):
		if str(category.get("Name",""))=="IntangibleItemRecharger": categories[int(category.ID)] = true
	var claimed: int = 0; var held: Dictionary = {}
	for row: Dictionary in SOURCE.rows_matching("ItemClass","CategoryID",categories):
		if row.get("TestItem")!=false: continue
		if STACK.profile(record(int(row.ID))).get("kind")=="bless_points": claimed += 1
		else: held[int(row.ID)] = FIELDS.full(record(int(row.ID))).get("source_use_spec",{}).get("blocked_reasons",[])
	evidence["family"] = {"claimed":claimed,"held":held}
	check(claimed==101 and held.size()==1, "101 BlessPoint items are usable, the Gem one is kept (%d, held %s)" % [claimed,str(held)])

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}
	var legacy: Dictionary = world._catalog_item_from_source_id("m523:item:%d" % LARGE)
	check(world.growth.source523.material({"name":legacy.get("name",""),"record":legacy}), "#117304 stays the symbol owner's material (catalog unchanged)")
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":EVENT,"amount":3,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "physical grant: %s" % str(staged.get("error",""))): world.queue_free(); await process_frame; return
	check(world._save_game(true,staged.overrides)==OK, "grant save")
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var name: String = str(record(EVENT).name)
	var before: int = int(world.growth.state.points)
	world.item_use_cooldowns.clear()
	var used: Dictionary = STACK.try_use(world,name)
	evidence["use"] = {"ok":used.get("ok"),"reason":used.get("reason",used.get("message","")),"before":before,"after":int(world.growth.state.points),"count":int(world.inventory.get(name,0))}
	check(used.get("ok",false) and int(world.growth.state.points)==before+1000 and int(world.inventory.get(name,0))==2, "one used: blessing points +1000, 3 → 2")
	world.item_use_cooldowns.clear()
	check(STACK.try_use(world,name).get("ok",false) and int(world.growth.state.points)==before+2000, "a second one: +2000 in all")
	var expected: Dictionary = {"points":int(world.growth.state.points),"count":int(world.inventory.get(name,0))}
	check(world._save_game(true)==OK, "save")
	world.growth.state.points = 0; world.inventory.erase(name)
	world._load_game(true)
	var reloaded: Dictionary = {"points":int(world.growth.state.points),"count":int(world.inventory.get(name,0))}
	evidence["reload"] = {"expected":expected,"reloaded":reloaded}
	check(reloaded==expected and expected.count==1, "points and the last unit survive reload")
	world.item_use_cooldowns.clear()
	check(STACK.try_use(world,name).get("ok",false) and int(world.inventory.get(name,0))==0 and int(world.growth.state.points)==before+3000, "the reloaded last unit is usable")
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("ITEMS523_BLESS_POINTS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
