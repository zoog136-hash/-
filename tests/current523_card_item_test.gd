extends SceneTree
## Original collection card items (ItemCategory BuffCardDrawer with one
## Polymorph / MagicDoll / HolyStuff BuffCardID) grant exactly that card.
## Without the pinned 523 tables only the routing rules run. With
## TWILIGHT_PATCH523_CONTENT, --runtime-ids=<file> and --runtime-sample=<n>,
## listed card items are granted, used and saved in actual Main.
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
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

func definition(deck_id: float, deck_name: String, extra: Array = []) -> Dictionary:
	var link: Dictionary = {"ID":7.0,"IsPossession":false,"bonus_type":{"Name":"BuffCardID"},"unit":{"Name":"BuffCardID"},"bonus":{"ID":8.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":501.0}}
	var card: Dictionary = {"ID":501.0,"BuffCardDeckID":deck_id,"ServerLimitSetID":0.0,"StartDateTimeID":0.0,"EndDateTimeID":0.0}
	return {"item_bonus":[link]+extra,"source_typed_references":[{"item_bonus_id":7.0,"unit":"BuffCardID","id":501,"card":card,"deck":{"ID":deck_id,"Name":deck_name,"CharacterBased":false}}],
		"original_item":{"ID":9001.0,"TargettingTypeID":1.0,"ServiceRegionCode":""},"category":{"Name":"BuffCardDrawer","IsConsumable":true}}

func rules() -> void:
	for pair: Array in [[1.0,"PolymorphCardDeck","변신"],[2.0,"MagicDollCardDeck","마법인형"],[98.0,"HolyStuffCardDeck","성물"]]:
		var spec: Dictionary = PROJECTION.source_fixed_card(definition(pair[0],pair[1]))
		check(spec.get("kind") == "fixed_card" and spec.get("card_kind") == pair[2] and spec.get("card_id") == 501 and spec.get("activation_status") == "unrestricted", "collection card item grants its card: " + str(pair[1]))
	check(PROJECTION.source_fixed_card(definition(41.0,"Spell")).is_empty(), "spell cards stay with the skill book owner")
	check(PROJECTION.source_fixed_card(definition(1.0,"MagicDollCardDeck")).is_empty(), "a deck name that does not match its ID is not projected")
	var swap: Dictionary = {"ID":9.0,"IsPossession":false,"bonus_type":{"Name":"BuffCardCannotSwap"},"unit":{"Name":"TrueFalse"},"bonus":{"ID":10.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":1.0}}
	var locked: Dictionary = PROJECTION.source_fixed_card(definition(2.0,"MagicDollCardDeck",[swap]))
	check(locked.get("buff_card_cannot_swap") == true and locked.get("activation_status") == "unrestricted", "the no-swap flag travels with the granted card")
	var bad: Dictionary = swap.duplicate(true); bad.bonus.Value = 3.0
	check(PROJECTION.source_fixed_card(definition(2.0,"MagicDollCardDeck",[bad])).get("activation_status") == "blocked", "a malformed no-swap flag blocks")
	var server: Dictionary = definition(98.0,"HolyStuffCardDeck"); server.source_typed_references[0].card.ServerLimitSetID = 5.0
	check(PROJECTION.source_fixed_card(server).get("activation_status") == "blocked", "a server-limited card needs its server context")

func runtime(limit: int) -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var outcome: Dictionary = {"sampled":0,"granted":0,"by_kind":{},"reasons":{}}
	for line: String in FileAccess.get_file_as_string(argument("--runtime-ids=")).split("\n", false):
		if not line.strip_edges().is_valid_int() or outcome.sampled >= limit: continue
		var id: int = int(line)
		# The full definition owner; data() lists only some registered items.
		var record: Dictionary = preload("res://scripts/loot/patch523_monster_drops.gd").variant_item(world.source_item_definition(id).get("native_record", {}), 1)
		var spec: Dictionary = FIELDS.full(record).get("source_use_spec", {})
		if spec.get("kind") != "fixed_card" or spec.get("activation_status") != "unrestricted": continue
		outcome.sampled += 1
		world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
		var granted: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(world, [{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		if not granted.get("ok", false) or world._save_game(true, granted.overrides) != OK:
			var why: String = "grant: " + str(granted.get("error", "save"))
			outcome.reasons[why] = int(outcome.reasons.get(why, 0)) + 1; continue
		world.inventory = granted.overrides.inventory; world.item_instances = granted.overrides.item_instances
		var name_value: String = str(record.name)
		var category: String = str(spec.card_kind)
		var card: Dictionary = STACK.card_binding(world, category, int(spec.card_id))
		var identity: String = world.card_draw_fusion.card_id(card) if not card.is_empty() else ""
		var before: int = world.card_draw_fusion.total_count(category, identity) if not identity.is_empty() else 0
		var result: Dictionary = STACK.try_use(world, name_value)
		if is_instance_valid(world.hud.card_reveal_stage): world.hud.card_reveal_stage.close_reveal()
		if result.get("ok", false):
			check(int(world.inventory.get(name_value, 0)) == 0 and world.item_instances.is_empty(), "card item debited through its physical receipt " + str(id))
			check(world.card_draw_fusion.total_count(category, identity) == before + 1, "exactly the original card is credited " + str(id))
			outcome.granted += 1; outcome.by_kind[category] = int(outcome.by_kind.get(category, 0)) + 1
		else:
			check(int(world.inventory.get(name_value, 0)) == 1, "refused card item stays owned " + str(id))
			var reason: String = str(result.get("reason", result.get("message", "")))
			outcome.reasons[reason] = int(outcome.reasons.get(reason, 0)) + 1
		await process_frame
	evidence["runtime"] = outcome
	check(outcome.sampled > 0 and outcome.granted > 0, "sampled card items grant, save and debit")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	var limit: int = int(argument("--runtime-sample="))
	if limit > 0:
		check(not SOURCE.not_installed(), "pinned 523 tables installed for the runtime sample")
		if not SOURCE.not_installed(): await runtime(limit)
	print("CURRENT523_CARD_ITEM_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
