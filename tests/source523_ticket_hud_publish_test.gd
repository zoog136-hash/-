extends SceneTree
## Redeem through use_ticket with only the original/private quote and durable
## commit boundaries substituted. Use the real HUD batch and lineage bag grid.
const Tickets = preload("res://scripts/shop/source523_inventory_tickets.gd")
const HUD = preload("res://scripts/ui/renewal_hud.gd")
const Bag = preload("res://scripts/ui/renewal_inventory.gd")
const CARD = {"name":"Fixture card","grade":"고급","source_card_id":101,"sourceId":"m523:1:101"}
const ITEM = "Fixture ticket"
const FIXTURE_DECK = "변신"

class ProbeHUD extends HUD:
	var reveal_count: int = 0
	var on_reveal: Callable
	func is_card_reveal_busy() -> bool: return false
	func set_card_draw_fusion_result(_category: String, _text: String) -> void: pass
	func present_card_reveal(category: String, outcome: Dictionary, fusion: bool) -> void:
		reveal_count += 1
		on_reveal.call(category, outcome, fusion)

class WorldStub extends RefCounted:
	var hud := ProbeHUD.new()
	var inventory: Dictionary = {ITEM:2}
	var item_instances: Dictionary = {"9":{"name":ITEM,"source_native_stack_quantity":2}}
	var catalog_db: Dictionary = {FIXTURE_DECK:[CARD]}
	var card_draw_fusion = Tickets.CardEngine.new()
	var gold: int = 1
	var next_item_instance_id: int = 10
	var publishes: int = 0
	var live_cards_at_publish: Dictionary
	func _update_hud() -> void:
		publishes += 1
		live_cards_at_publish = card_draw_fusion.export_state()
		hud.lineage_inventory_ui.set_character_state({"item_instances":item_instances})
		hud.lineage_inventory_ui.set_inventory(inventory)

class RuntimeStub extends RefCounted:
	const LIMIT: int = 1000
	var world := WorldStub.new()
	var state: Dictionary = {}
	var _busy: bool = false
	var reject_commit: bool = true
	var committed_cards: Dictionary
	func _start() -> Dictionary:
		_busy = true
		return {"ok":true}
	func export_state() -> Dictionary: return state.duplicate(true)
	func _commit(next: Dictionary, inventory: Dictionary, _gold: int, instances: Dictionary, _id: int, extra: Dictionary) -> Dictionary:
		_busy = false
		if reject_commit: return {"ok":false}
		state = next
		committed_cards = extra.card_draw_fusion
		world.item_instances = instances
		world.inventory = inventory
		return {"ok":true}

class FixtureTicket extends Tickets:
	func _quote(_name: String, _selection: Dictionary, _internal: bool, _materialize: bool) -> Dictionary:
		var id: String = CardEngine.card_id(CARD)
		return {"ok":true,"category":FIXTURE_DECK,"grants":[{"count":1,"pool_id":1}],
			"pools":{"1":[{"weight":1000000,"entry":{"id":id,"record":CARD}}]},"source_item_id":17}
	func _native_debit(name: String) -> Dictionary:
		var remaining: int = int(runtime.world.inventory[name]) - 1
		return {"ok":true,"overrides":{"inventory":{name:remaining} if remaining > 0 else {},
			"item_instances":{"9":{"name":name,"source_native_stack_quantity":remaining}} if remaining > 0 else {},
			"consumable_state":{}}}

var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr(label)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var runtime := RuntimeStub.new()
	var world := runtime.world
	var holder := Control.new()
	root.add_child(holder)
	var contents := Control.new()
	holder.add_child(contents)
	var bag := Bag.new()
	contents.add_child(bag)
	world.hud.lineage_inventory_ui = bag
	world._update_hud()
	bag.show_inventory()
	bag._select_item(ITEM + "@@@9")
	var baseline: int = bag.inventory_list_rebuilds
	var tickets := FixtureTicket.new()
	tickets.owner_ref = weakref(runtime)
	tickets.loaded_sha = "fixture"
	world.card_draw_fusion.configure(world.catalog_db)
	var draw_rng: int = tickets.random.state
	var unrelated_rng: int = world.card_draw_fusion.rng.state
	var before: Dictionary = world.card_draw_fusion.export_state()
	var card_id: String = Tickets.CardEngine.card_id(CARD)
	check(not tickets.use_ticket(ITEM).ok and world.hud.reveal_count == 0 and bag.inventory_list_rebuilds == baseline and world.publishes == 1,
		"failed save publishes neither HUD nor reveal")
	check(world.card_draw_fusion.export_state() == before and tickets.random.state == draw_rng and world.inventory == {ITEM:2},
		"failed save keeps exact cards, RNG and stack")
	runtime.reject_commit = false
	world.hud.on_reveal = func(category: String, outcome: Dictionary, fusion: bool) -> void:
		var use: int = int(runtime.state.ticket_redemption.uses)
		check(category == FIXTURE_DECK and not fusion and outcome.results[0].id == card_id,
			"reveal uses the committed draw result")
		check(runtime.committed_cards == world.live_cards_at_publish and runtime.committed_cards == world.card_draw_fusion.export_state()
			and int(runtime.state.ticket_redemption.rng_state) == tickets.random.state,
			"save, live card state/RNG and synchronous world publication precede reveal")
		check(bag.inventory_list_rebuilds == baseline + use and world.publishes == 1 + use and bag.inventory == world.inventory,
			"exactly one final bag grid rebuild before each reveal")
		if use == 1:
			check(bag.sorted_references == [ITEM + "@@@9"] and bag._bag_display_amount(ITEM + "@@@9") == 1 and bag.selected_item == ITEM + "@@@9",
				"partially spent physical stack displays final count and retains selection")
		else:
			check(bag.sorted_references.is_empty() and bag.selected_item.is_empty(),
				"last physical ticket removes row and selection before reveal")
	check(tickets.use_ticket(ITEM).ok and tickets.use_ticket(ITEM).ok and world.hud.reveal_count == 2,
		"consecutive committed transactions both reveal exactly once")
	check(world.card_draw_fusion.owned[FIXTURE_DECK].has(card_id) and world.card_draw_fusion.spare[FIXTURE_DECK].get(card_id) == 1
		and world.card_draw_fusion.rng.state == unrelated_rng,
		"first acquisition and duplicate credit do not alter the generic draw stream")
	world.hud.free()
	holder.queue_free()
	await process_frame
	print("SOURCE523_TICKET_HUD_PUBLISH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
