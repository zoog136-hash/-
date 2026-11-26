extends "res://tests/native_symbol_reward_bag_test.gd"
## User report 2026-11-26 "이동 주문서 대부분 사용 안 됨": original fixed-
## destination scrolls whose destination Land declares only in-Land rules
## (BlockLoginEnter, NoSpell, GivenSpellClassID, ...) were refused with
## "원문 지역 조건 보류". The constants always run. With the installed original
## packs and TWILIGHT_ITEM_SCROLL_ARRIVAL=1 (isolated profile) actual Main
## grants real scrolls, uses each with two touches on the original bag slot,
## checks the original destination Land, one debit, the in-Land re-check after
## a level change and a reload.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const EFFECTS = preload("res://scripts/loot/source523_item_effects.gd")
const LABEL_OWNER = preload("res://scripts/ui/renewal_inventory.gd")
const WORLD = preload("res://scripts/world.gd")
## 윈다우드성 던전 이동 주문서 (각인): NoSpell. 보물지도 주문서: BlockLoginEnter.
## 훈민정음 던전 이동 주문서 (이벤트): AlwaysWakeNpc, BlockLoginEnter, GivenSpellClassID.
## 비밀 장소 이동 주문서 (이벤트): + NoHellVirtuePoint, NoReusableSoloLand, NoSpell.
const SCROLLS := [117123, 8381, 165253, 294518]
const IN_LAND := ["BlockLoginEnter","AlwaysWakeNpc","NoSpell","NoBuffGroup","NoHellVirtuePoint","WeaponDisable","GivenSpellClassID","NoReusableSoloLand"]

func constants() -> void:
	var scroll: Array = WORLD.ITEM523_SCROLL_ARRIVAL_WAIVE
	var map: Array = WORLD.ITEM523_TELEPORT_WAIVE
	for name: String in map: check(scroll.has(name), "scroll arrival keeps the teleport waive " + name)
	for name: String in IN_LAND:
		check(scroll.has(name), "in-Land rule does not gate a scroll arrival " + name)
		check(not map.has(name), "map teleport list unchanged " + name)
	for name: String in ["MinLevel","MaxLevel","NoTeleportCome","CloseTime","OpenTime"]:
		check(not scroll.has(name), "entry gate still judged " + name)
	var source: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	var start: int = source.find("func _item523_teleport_land_impl")
	var body: String = source.substr(start, source.find("\n\n", start) - start)
	check(body.count("ITEM523_SCROLL_ARRIVAL_WAIVE") == 2 and not body.contains("ITEM523_TELEPORT_WAIVE"), "the scroll owner passes the arrival list on both paths")
	var controller: String = FileAccess.get_file_as_string("res://scripts/maps/current523_aden_play_controller.gd")
	check(controller.contains("result[\"arrival_waive\"]=waive.duplicate()") and controller.contains("waive=_active_entry_context.get(\"arrival_waive\",[])"), "the in-Land re-check reuses the arrival's own waive")

func slot_for(world: Node, ref: String) -> Dictionary:
	var controller: Node = world.hud.original_main_ui_controller
	if not world.hud.original_inventory_is_open():
		await tap(controller._menu_scene.source_nodes[TOP.INVENTORY].get_meta("source_button")._input_area)
		await frames()
	var view: RefCounted = controller._inventory_view
	var up := InputEventScreenDrag.new()
	up.relative = Vector2(0, 100000)
	view._forward_scroll_input(up)
	await process_frame
	for attempt: int in 30:
		if view._hits.has(ref):
			var button: Control = view._hits[ref].control
			if world.hud.original_inventory_hit_at(button.get_global_transform_with_canvas() * (button.size / 2)).get("reference") == ref: return view._hits[ref]
		var step := InputEventScreenDrag.new()
		step.relative = Vector2(0, -65)
		view._forward_scroll_input(step)
		await process_frame
	return {}

func land(world: Node) -> int:
	return int(world.orim_current_land().get("land_id", -1))

func stock(world: Node, id: int) -> int:
	var count: int = 0
	for uid: String in world.item_instances:
		if int(world.item_instances[uid].get("record", {}).get("source_item_class_id", 0)) == id: count += int(world.item_instances[uid].get(STACK.QUANTITY, 1))
	return count

func actual() -> void:
	root.size = Vector2i(2048, 919)
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	if not check(QA.enter_game(world), "normal Main startup"): world.queue_free(); return
	await frames()
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer = -100000
	world.level = 85
	if not check(world.current523_aden_source_active(), "installed original map active"): world.queue_free(); return
	var home: int = land(world)
	var home_cell: Vector2i = Vector2i(EFFECTS._source_cell(world, world.player.global_position))
	var controller: RefCounted = world.call("_aden_play_controller")
	for id: int in SCROLLS:
		var issued: Array = [{"item_class_id":id, "amount":2, "bless_raw":1, "enchant":0}]
		if not check(SUPPLY.commit(world, issued, {"kind":"scroll_arrival_regression"}), "grant original scroll #%d" % id): continue
		var ref: String = ""
		var record: Dictionary = {}
		for uid: String in world.item_instances:
			if int(world.item_instances[uid].get("record", {}).get("source_item_class_id", 0)) == id:
				ref = str(world.item_instances[uid].name) + "@@@" + uid
				record = world.item_instances[uid].record
		var contract: Dictionary = EFFECTS.location_teleport(record)
		if not check(not contract.is_empty() and (contract.usable_classes as Array).is_empty(), "#%d is a fixed-destination scroll usable anywhere" % id): continue
		world.hud.refresh_inventory(world.inventory)
		await frames()
		var hit: Dictionary = await slot_for(world, ref)
		if not check(not hit.is_empty(), "visible original slot #%d" % id): continue
		await tap(hit.control)
		check(world.hud.lineage_inventory_ui.item_action_label(ref) == "사용", "first touch arms 사용 #%d" % id)
		hit = await slot_for(world, ref)
		world.portal_cooldown = 0.0
		await tap(hit.control)
		for tick: int in 900:
			if not world.MAP_LOADING.busy(world): break
			await process_frame
		await frames()
		print("SCROLL_ARRIVAL ", id, " land=", land(world), " msg=", world.hud.message_label.text)
		if not check(land(world) == int(contract.land_id) and stock(world, id) == 1, "#%d arrives on original Land %d and pays one scroll (%s)" % [id, int(contract.land_id), world.hud.message_label.text]): continue
		# A level change re-checks the current Land's entry conditions.
		world.level = 86
		controller.call("_map_time_tick")
		await frames()
		check(world.current523_aden_source_active() and land(world) == int(contract.land_id), "#%d in-Land re-check keeps the player there" % id)
		world.level = 85
		if id == 117123:
			world._load_game(true)
			await frames()
			# Resuming inside a held Land keeps its own rule (start village);
			# either way the arrival was paid exactly once.
			print("SCROLL_ARRIVAL_RELOAD ", land(world))
			check(land(world) in [int(contract.land_id), home] and stock(world, id) == 1, "reload keeps exactly one payment")
		world.portal_cooldown = 0.0
		var back: Dictionary = world.content523_enter_land(home, [home_cell.x, home_cell.y, home_cell.x, home_cell.y], WORLD.ITEM523_SCROLL_ARRIVAL_WAIVE.duplicate())
		check(back.get("ok", false), "return to the start Land")
		if world.hud.original_inventory_is_open(): world.hud.original_main_ui_controller.close_inventory()
	# 흑마법 연구실 (이벤트): the closed event Land's MinLevel 999 still holds.
	if check(SUPPLY.commit(world, [{"item_class_id":123364, "amount":2, "bless_raw":1, "enchant":0}], {"kind":"scroll_arrival_regression"}), "grant closed event scroll"):
		var closed: String = ""
		for uid: String in world.item_instances:
			if int(world.item_instances[uid].get("record", {}).get("source_item_class_id", 0)) == 123364: closed = str(world.item_instances[uid].name) + "@@@" + uid
		world.hud.refresh_inventory(world.inventory)
		await frames()
		var hit: Dictionary = await slot_for(world, closed)
		if check(not hit.is_empty(), "visible closed event scroll"):
			await tap(hit.control)
			hit = await slot_for(world, closed)
			world.portal_cooldown = 0.0
			await tap(hit.control)
			for tick: int in 900:
				if not world.MAP_LOADING.busy(world): break
				await process_frame
			await frames()
			var text: String = world.hud.message_label.text
			print("SCROLL_ARRIVAL_CLOSED ", text)
			check(land(world) == home and stock(world, 123364) == 2 and not text.contains("native_") and not text.is_empty(), "closed event Land keeps the scroll with a player message")
	world.queue_free()
	await frames()

func run() -> void:
	constants()
	if OS.get_environment("TWILIGHT_ITEM_SCROLL_ARRIVAL") == "1": await actual()
	print("ITEM_SCROLL_ARRIVAL_RESULT ", JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
