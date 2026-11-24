extends SceneTree
## The production inventory signal drives Main's local (not source-shop) tickets.
## The real save writer and live bag run; the reveal spy observes what they have
## published when the game enters the existing animation.
const HUD = preload("res://scripts/ui/renewal_hud.gd")
const Cards = preload("res://scripts/card_draw_fusion.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const SINGLE := "최상급 성물 뽑기권"
const PACK := "최상급 마법인형 뽑기권 11회 팩"

class RevealHUD extends HUD:
	var on_reveal: Callable
	var track: bool = false
	var events: Array[String] = []
	func set_card_draw_fusion_result(category: String, result_text: String) -> void:
		if track: events.append("result")
		super.set_card_draw_fusion_result(category,result_text)
	func show_message(value: String) -> void:
		if track: events.append("message")
		super.show_message(value)
	func append_log(value: String) -> void:
		if track: events.append("log")
		super.append_log(value)
	func present_card_reveal(category: String, awarded: Dictionary, is_fusion: bool) -> void:
		if track:
			events.append("reveal")
			on_reveal.call(category,awarded,is_fusion)
		super.present_card_reveal(category,awarded,is_fusion)

var checks: int = 0
var failures: Array[String] = []
var timings: Array = []

func check(ok: bool, key: String) -> void:
	checks += 1
	if not ok:
		failures.append(key)
		printerr("NORMAL_CARD_DRAW_FAIL ",key)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	world.get_node("HUD").set_script(RevealHUD)
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"real Main class and HUD ready")
	var hud: RevealHUD = world.hud
	var cards: RefCounted = world.card_draw_fusion
	# The private original pools are unavailable in public CI. Substitute
	# only the deck data at the same boundary where a real build supplies it.
	for deck: String in ["성물","마법인형"]:
		var rows: Array[Dictionary] = []
		for grade: String in Cards.DRAW_ORDER:
			for index: int in range(2):
				var identity: int = 10000 + rows.size()
				rows.append({"sourceId":"normal-draw:%s:%d" % [deck,identity],"source_card_id":identity,
					"name":"%s %s %d" % [deck,grade,index],"type":deck,"grade":grade})
		world.catalog_db[deck] = rows
	cards.configure(world.catalog_db)
	# Force the first single to lock a rare-or-higher card using the unchanged
	# RNG path over a real valid grade table. A fresh hero exercises marker rollback.
	for seed_value: int in range(5000):
		cards.rng.seed = seed_value
		if cards._roll_draw_grade() == "영웅":
			cards.rng.seed = seed_value
			break
	check(cards.can_draw("성물") and cards.can_draw("마법인형"),"both normal decks have the exact configured grades")
	world.inventory[SINGLE] = 2
	world.inventory[PACK] = 1
	check(world._save_game(true) == OK,"write original ticket balances")
	hud.refresh_inventory(world.inventory)
	hud.show_companion_bag()
	await process_frame
	var bag: Control = hud.lineage_inventory_ui
	bag._select_item(SINGLE)
	var by_draw:Array = [[SINGLE,"성물",1,1],[SINGLE,"성물",1,0],[PACK,"마법인형",11,0]]
	var reveals: Array = [0]
	for index: int in range(by_draw.size()):
		var data: Array = by_draw[index]
		var item: String = data[0]
		var deck: String = data[1]
		var item_before: int = world.inventory[item]
		var before: Dictionary = cards.export_state()
		var stream_before: int = cards.rng.state
		var old_sha: String = FileAccess.get_sha256(world.save_path())
		var model := Cards.new()
		model.configure(world.catalog_db)
		model.import_state(before)
		model.rng.state = stream_before
		var expected: Dictionary = model.draw_cards(deck,data[2])
		check(expected.ok,"the reference draw succeeds")
		if index == 0:
			var before_receipts: Array = cards.source_card_receipts
			var before_other_deck: Dictionary = cards.owned["변신"]
			world.source_save_blocked = true
			hud.track = true
			hud.on_reveal = func(_deck: String,_outcome: Dictionary,_fusion: bool) -> void: check(false,"failed save never reveals")
			hud.inventory_item_activated.emit(item)
			hud.track = false
			world.source_save_blocked = false
			check(FileAccess.get_sha256(world.save_path()) == old_sha and world.inventory[item] == item_before
				and cards.export_state() == before and cards.rng.state == stream_before,"rejected save keeps disk, ticket, cards and RNG")
			check(is_same(before_receipts,cards.source_card_receipts) and is_same(before_other_deck,cards.owned["변신"]),"rollback does not rebuild unrelated decks or receipt history")
			check(hud.events == ["message"] and not hud.is_card_reveal_busy(),"only failure feedback, no card result or reveal")
		hud.events.clear()
		hud.track = true
		var full_before: int = int(world.hud_publish_counts.full)
		var bag_before: int = int(bag.inventory_list_rebuilds)
		hud.on_reveal = func(category: String, outcome: Dictionary, fusion: bool) -> void:
			reveals[0] += 1
			var persisted: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
			check(persisted is Dictionary and FileAccess.get_sha256(world.save_path()) != old_sha
				and int(persisted.inventory.get(item,0)) == data[3],"ticket debit is already durable at reveal entry")
			var loaded := Cards.new()
			loaded.configure(world.catalog_db)
			loaded.import_state(persisted.get("card_draw_fusion",{}))
			check(loaded.export_state() == model.export_state() and cards.export_state() == model.export_state()
				and cards.rng.state == model.rng.state,"durable and live cards match original draw and RNG")
			check(category == deck and outcome == expected and not fusion,"same reveal order, IDs, grades and new/duplicate flags")
			check(bag.inventory == world.inventory and int(bag.inventory_list_rebuilds) == bag_before + 1
				and int(world.hud_publish_counts.full) == full_before + 1,"one live bag rebuild and world publication before reveal")
			check(hud.events == ["result","message","log","reveal"],"result and feedback precede reveal in existing order")
		var start: int = Time.get_ticks_usec()
		hud.inventory_item_activated.emit(item)
		timings.append((Time.get_ticks_usec()-start)/1000.0)
		check(hud.is_card_reveal_busy(),"normal ticket mounts the existing reveal overlay")
		var after_rng: int = cards.rng.state
		hud.inventory_item_activated.emit(PACK)
		check(cards.rng.state == after_rng and int(reveals[0]) == index + 1,"re-entry while reveal is active cannot draw again")
		hud.track = false
		var stage: Control = hud.card_reveal_stage
		if is_instance_valid(stage) and stage.has_signal("finished"): stage.finished.emit()
		await process_frame
	check(int(reveals[0]) == 3,"two single tickets plus one 11-card pack reveal exactly three times")
	world.queue_free()
	await process_frame
	print("NORMAL_CARD_DRAW_BUDGET_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pc_full_handler_ms":timings}))
	quit(0 if failures.is_empty() else 1)
