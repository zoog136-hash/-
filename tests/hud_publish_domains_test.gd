extends SceneTree
## HUD publish domains (B08/B09/I08/I09): an HP/MP potion and a wallet
## pickup publish only their vitals/bag instead of the full _update_hud,
## and the result is the same: after the light publish, a full _update_hud
## of the same state leaves the HUD character state and bars unchanged. The
## light publish recalculates no derived stat. Any other domain (or healing
## that erased a buff) is the full publish. Actual Main (fallback world).
##   godot --headless --path <repo> --script res://tests/hud_publish_domains_test.gd
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var samples: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("HUD_PUBLISH_DOMAINS_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("_run")

func _state(world: Node) -> Dictionary:
	var hud: Node = world.hud
	return {"character_state": JSON.stringify(hud.character_state, "", true), "hp_bar": [hud.hp_bar.value, hud.hp_bar.max_value] if hud.get("hp_bar") != null else [], "player": JSON.stringify(hud.get("_player_values"))}

func _diff(a: Dictionary, b: Dictionary) -> Array:
	var keys: Array = []
	var ca: Variant = JSON.parse_string(a.character_state)
	var cb: Variant = JSON.parse_string(b.character_state)
	if ca is Dictionary and cb is Dictionary:
		for key: Variant in ca:
			if JSON.stringify(ca[key], "", true) != JSON.stringify(cb.get(key), "", true): keys.append(key)
		for key: Variant in cb:
			if not ca.has(key): keys.append(key)
	if a.hp_bar != b.hp_bar: keys.append("hp_bar")
	if a.player != b.player: keys.append("player_values")
	return keys

func _percentiles(values: Array) -> Dictionary:
	values.sort()
	return {"p50": values[values.size() / 2], "p95": values[int(values.size() * 0.95)], "p99": values[int(values.size() * 0.99)]}

func _run() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for i: int in 3: await process_frame
	if not check(QA.enter_game(world), "the class confirmation enters the game"):
		_finish(world)
		return
	world.set_process(false)
	# A mid-game bag: catalog items, some with physical instances.
	var added: int = 0
	for record: Variant in world.item_db:
		if added >= 120: break
		if record is Dictionary and not str(record.get("name", "")).is_empty():
			world.inventory[str(record.name)] = 1 + added % 3
			added += 1
	world._update_hud()
	var item: String = str(world.inventory.keys()[0])
	# HP potion: HP rises, one item leaves the bag.
	world.hp = maxi(1, int(world.hud.character_state.get("max_hp", 100)) / 2)
	world.inventory[item] = int(world.inventory[item]) + 1
	var counts: Dictionary = world.hud_publish_counts.duplicate()
	world.publish_hud(world.HUD_VITALS | world.HUD_ITEMS)
	check(int(world.hud_publish_counts.full) == int(counts.full) and int(world.hud_publish_counts.stat_snapshots) == int(counts.stat_snapshots), "the potion publish rebuilds nothing and recalculates no stat")
	check(int(world.hud_publish_counts.vitals) == int(counts.vitals) + 1 and int(world.hud_publish_counts.items) == int(counts.items) + 1, "vitals and bag publishes are counted")
	var light: Dictionary = _state(world)
	world._update_hud()
	var full: Dictionary = _state(world)
	check(int(world.hud_publish_counts.stat_snapshots) > int(counts.stat_snapshots), "the full publish recalculates stats")
	var potion_diff: Array = _diff(light, full)
	check(potion_diff.is_empty(), "potion: the light publish equals the full one (differs: %s)" % str(potion_diff))
	# Wallet pickup: gold only (plus the bag publish the pickup already does).
	world.gold += 1234
	world._refresh_inventory_hud()
	world.publish_hud(world.HUD_VITALS)
	light = _state(world)
	world._update_hud()
	var wallet_diff: Array = _diff(light, _state(world))
	check(wallet_diff.is_empty(), "wallet: the light publish equals the full one (differs: %s)" % str(wallet_diff))
	check(world.hud.character_state.get("gold") == world.gold, "the gold shown is the wallet")
	# Domain decisions.
	var buffs: int = world.player_npc_buff_signature()
	check(world.native_use_hud_domains({"effect_kind": "hp"}, buffs) == world.HUD_VITALS | world.HUD_ITEMS, "an HP potion is vitals and bag")
	check(world.native_use_hud_domains({"effect_kind": "mp"}, buffs) == world.HUD_VITALS | world.HUD_ITEMS, "an MP potion is vitals and bag")
	check(world.native_use_hud_domains({"effect_kind": "buff"}, buffs) == world.HUD_FULL, "a buff item is the full publish")
	check(world.native_use_hud_domains({"effect_kind": "hp"}, buffs + 1) == world.HUD_FULL, "healing that erased a buff is the full publish")
	counts = world.hud_publish_counts.duplicate()
	world.publish_hud(world.HUD_FULL)
	world.publish_hud(world.HUD_VITALS | world.HUD_FULL)
	world.publish_hud(0)
	check(int(world.hud_publish_counts.full) == int(counts.full) + 3, "any other domain is the full publish")
	# Bag weight: the same encumbrance multiplier keeps the speeds; a heavier
	# bag (another multiplier) refreshes them to the full publish's values.
	counts = world.hud_publish_counts.duplicate()
	world.inventory[item] = int(world.inventory[item]) + 1
	world.publish_hud(world.HUD_ITEMS)
	check(int(world.hud_publish_counts.speed_refreshes) == int(counts.speed_refreshes), "an unchanged encumbrance keeps the speeds")
	var heavy: String = ""
	var heaviest: int = 0
	for name: Variant in world.item_weight_index:
		if int(world.item_weight_index[name]) > heaviest and not world._find_catalog_item_record(str(name)).is_empty():
			heaviest = int(world.item_weight_index[name]); heavy = str(name)
	var saved_bag: Dictionary = world.inventory.duplicate(true)
	world.inventory.clear()
	world.publish_hud(world.HUD_ITEMS)
	var before_mul: float = world._inventory_encumbrance_multiplier()
	if not heavy.is_empty():
		world.inventory[heavy] = int(world.inventory.get(heavy, 0)) + maxi(1, (world._carrying_capacity() * 2) / maxi(1, heaviest))
	counts = world.hud_publish_counts.duplicate()
	world.publish_hud(world.HUD_ITEMS)
	var moved_mul: float = world._inventory_encumbrance_multiplier()
	samples["encumbrance"] = [before_mul, moved_mul]
	if check(moved_mul != before_mul, "the test bag reaches another encumbrance multiplier (%s)" % str(samples.encumbrance)):
		check(int(world.hud_publish_counts.speed_refreshes) == int(counts.speed_refreshes) + 1, "a new encumbrance refreshes the speeds")
		var light_speeds: Array = [world.player.equipment_move_speed_multiplier, world.player.attack_speed_multiplier]
		world._update_hud()
		var full_speeds: Array = [world.player.equipment_move_speed_multiplier, world.player.attack_speed_multiplier]
		check(light_speeds == full_speeds, "speeds equal the full publish (%s / %s)" % [str(light_speeds), str(full_speeds)])
	world.inventory = saved_bag
	world._update_hud()
	# Cost of 60 potion publishes, before (full) and after (light).
	var before: Array = []
	var after: Array = []
	for index: int in range(60):
		world.hp = maxi(1, world.hp - 1)
		var started: int = Time.get_ticks_usec()
		world.hud.refresh_inventory(world.inventory)
		world._update_hud()
		before.append(float(Time.get_ticks_usec() - started) / 1000.0)
		started = Time.get_ticks_usec()
		world.hud.refresh_inventory(world.inventory)
		world.publish_hud(world.HUD_VITALS | world.HUD_ITEMS)
		after.append(float(Time.get_ticks_usec() - started) / 1000.0)
	samples["potion_full_ms"] = _percentiles(before)
	samples["potion_light_ms"] = _percentiles(after)
	samples["bag_items"] = world.inventory.size()
	_finish(world)

func _finish(world: Node) -> void:
	print("HUD_PUBLISH_DOMAINS_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "samples": samples}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
