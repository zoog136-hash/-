extends SceneTree
## Original draw tickets (ItemCategory LinMarketProduct) are owned as physical
## stacks and redeemed by the owned-ticket service from their MarketPurchase ->
## MarketProduct -> GotChaClassID pools. Without the pinned 523 tables only the
## routing rules run. With TWILIGHT_PATCH523_CONTENT and --runtime-ids=<file>,
## the whole model is built and each listed ticket is granted, drawn and saved
## in actual Main (--runtime-sample=<n> limits how many).
const TICKETS = preload("res://scripts/shop/source523_inventory_tickets.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	var native: Dictionary = {"source_m_native_item":true,"source_snapshot":"patch523","source_category_name":"LinMarketProduct","source_item_class_id":122784}
	check(TICKETS.claims(native), "every original draw ticket item is answered by the owned-ticket service")
	check(TICKETS.claims({"source_item_class_id":166744}), "the six first-model tickets stay claimed")
	var other: Dictionary = native.duplicate(); other.source_category_name = "LuckyBag"
	check(not TICKETS.claims(other) and not TICKETS.claims({"source_item_class_id":122784}), "other categories and non-original records are not claimed")
	check(STACK.draw_ticket_profile({"source_category_name":"LinMarketProduct"}).is_empty(), "a ticket profile needs the exact current original record")
	check(TICKETS.SPELL_DECK == 41 and TICKETS.SKILL_BOOKS != "" and not TICKETS.SKILL_BOOKS in ["변신","마법인형","성물"], "skill card pools have their own reward kind")

func runtime(per_list: int) -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var service = world.source_shop.inventory_tickets
	var document: Dictionary = service.document
	check(service.problem.is_empty() and document.get("tickets", {}).size() > 6, "the whole original ticket model loads")
	evidence["model"] = {"tickets":document.get("tickets", {}).size(),"pools":document.get("pools", {}).size(),"unsupported":document.get("unsupported", {}).size(),"policy_sha256":service.loaded_sha}
	for id: int in TICKETS.IDS: check(document.get("tickets", {}).has(str(id)), "first-model ticket stays redeemable " + str(id))
	var outcome: Dictionary = {"sampled":0,"drawn":0,"cards":0,"reasons":{}}
	var count: int = 0
	for line: String in FileAccess.get_file_as_string(argument("--runtime-ids=")).split("\n", false):
		if not line.strip_edges().is_valid_int() or count >= per_list: continue
		var id: int = int(line)
		if not document.tickets.has(str(id)): continue
		count += 1; outcome.sampled += 1
		world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
		var granted: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(world, [{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		if not granted.get("ok", false): outcome.reasons["grant: " + str(granted.get("error", ""))] = int(outcome.reasons.get("grant: " + str(granted.get("error", "")), 0)) + 1; continue
		if world._save_game(true, granted.overrides) != OK: outcome.reasons["grant save"] = int(outcome.reasons.get("grant save", 0)) + 1; continue
		world.inventory = granted.overrides.inventory; world.item_instances = granted.overrides.item_instances
		var name_value: String = str(world.source_item_record(id).name)
		var result: Dictionary = world.source_shop.use_inventory_ticket(name_value)
		if is_instance_valid(world.hud.card_reveal_stage): world.hud.card_reveal_stage.close_reveal()
		if result.get("ok", false):
			if result.get("category") == TICKETS.SKILL_BOOKS:
				# Drawn original skill cards arrive as their skill book stacks.
				var books: int = 0
				for entry: Variant in world.item_instances.values():
					if entry is Dictionary and entry.has(STACK.RECEIPT): books += int(entry.get(STACK.QUANTITY, 0))
				check(int(world.inventory.get(name_value, 0)) == 0 and books == int(result.get("count", 0)), "skill card draw debits the ticket and grants one original skill book per draw " + str(id))
				outcome["skill_books"] = int(outcome.get("skill_books", 0)) + books
			else:
				check(int(world.inventory.get(name_value, 0)) == 0 and world.item_instances.is_empty(), "drawn ticket is debited through its physical receipt " + str(id))
			outcome.drawn += 1; outcome.cards += int(result.get("count", 0))
		else:
			check(int(world.inventory.get(name_value, 0)) == 1, "refused ticket stays owned " + str(id))
			var reason: String = str(result.get("reason", result.get("message", "")))
			outcome.reasons[reason] = int(outcome.reasons.get(reason, 0)) + 1
		await process_frame
	evidence["runtime"] = outcome
	check(outcome.sampled > 0 and outcome.drawn > 0, "sampled original tickets draw, save and grant cards")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	var per_list: int = int(argument("--runtime-sample="))
	if per_list > 0:
		check(not SOURCE.not_installed(), "pinned 523 tables installed for the runtime sample")
		if not SOURCE.not_installed(): await runtime(per_list)
	print("CURRENT523_DRAW_TICKET_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
