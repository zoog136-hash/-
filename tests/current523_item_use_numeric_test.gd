extends SceneTree
## Table JSON numbers are floats; `in`, `match` and Array/Dictionary equality
## are type-strict. Integral values are compared as ints (whole()); anything
## else still fails. Without the pinned 523 tables only these rules run.
## With TWILIGHT_PATCH523_CONTENT, --runtime-sample=<n per kind> and
## --runtime-ids=<file of ItemClass IDs>, real boxes, selection boxes and skill
## books from that list are granted, used and saved in actual Main.
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
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
	for owner: Variant in [PROJECTION, STACK]:
		var one: Variant = owner.whole(1.0)
		check(typeof(one) == TYPE_INT and one == 1, "integral float becomes int")
		check(owner.whole(2.0) in [1,2,3] and owner.whole(0.0) in [0,1] and owner.whole(-1.0) in [-1], "integral values match int lists")
		check(owner.whole(1.5) not in [1,2] and typeof(owner.whole(1.5)) == TYPE_FLOAT, "fractional values still fail")
		check(owner.whole("1") not in [1] and owner.whole(null) not in [0] and owner.whole(true) not in [1], "strings, null and bools are unchanged")
		check(owner.whole(3) == 3 and typeof(owner.whole(3)) == TYPE_INT, "ints are unchanged")
		check([owner.whole(1.0)] == [1], "normalized flag lists compare equal")

func eligible_class(spec: Dictionary, classes: Dictionary) -> String:
	var wanted: Array = []
	if spec.get("kind") == "source_skill_book":
		for limit: Dictionary in spec.get("source_learn_limits", []): wanted.append(int(limit.get("ClassID", 0)))
	else:
		for class_id: Variant in spec.get("source_class_domain", classes.keys()): wanted.append(int(class_id))
	for class_id: int in wanted:
		if not classes.has(class_id): continue
		if spec.get("kind") in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward"]:
			for reward: Dictionary in spec.get("rewards", []):
				if reward.get("class_ids", []).is_empty() or class_id in reward.class_ids: return str(classes[class_id])
		else: return str(classes[class_id])
	return ""

func runtime(per_kind: int) -> void:
	# Candidates come from a list (one ItemClass ID per line); scanning every
	# ItemClass definition here would hold all projections in memory.
	var samples: Dictionary = {"guaranteed_bag":[],"source_weighted_bag":[],"mixed_rewards_bag":[],"source_selectable_reward":[],"source_skill_book":[]}
	for line: String in FileAccess.get_file_as_string(argument("--runtime-ids=")).split("\n", false):
		if not line.strip_edges().is_valid_int(): continue
		var record: Dictionary = D.definition_id(line.strip_edges()).get("native_record", {})
		if record.is_empty() or record.get("source_test_item", true): continue
		var spec: Dictionary = FIELDS.full(record).get("source_use_spec", {})
		var kind: String = str(spec.get("kind", ""))
		if samples.has(kind) and spec.get("activation_status") == "unrestricted" and samples[kind].size() < per_kind: samples[kind].append(int(line))
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var classes: Dictionary = {}
	for entry: Dictionary in world.BASE508.cards().get("classes", []): classes[int(entry.source_original.ID)] = str(entry.name)
	for kind: String in samples:
		var outcome: Dictionary = {"sampled":samples[kind].size(),"used":0,"failed":{},"reasons":{}}
		for id: int in samples[kind]:
			var record: Dictionary = world.source_item_record(id)
			var spec: Dictionary = FIELDS.full(record).get("source_use_spec", {})
			var job: String = eligible_class(spec, classes)
			if job.is_empty(): outcome.failed[str(id)] = "no_eligible_class"; continue
			world.job_class = job; world.level = 90
			world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}; world.gold = 0
			var granted: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(world, [{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
			if not granted.get("ok", false): outcome.failed[str(id)] = "grant: " + str(granted.get("error", "")); continue
			var saved: Error = world._save_game(true, granted.overrides)
			if saved != OK: outcome.failed[str(id)] = "grant save: " + error_string(saved); continue
			world.inventory = granted.overrides.inventory; world.item_instances = granted.overrides.item_instances; world.gold = int(granted.overrides.gold)
			var name_value: String = str(record.name)
			var before: Dictionary = world.inventory.duplicate(true)
			var result: Dictionary = STACK.try_use(world, name_value)
			if result.get("requires_original_selection", false):
				var choice: Dictionary = result.choices[0]
				result = STACK.claim_original_selection(world, result.original_item, result.ownership_request, int(choice.source_entity_id))
			var consumed: bool = int(world.inventory.get(name_value, 0)) == int(before.get(name_value, 0)) - 1
			var gained: bool = world.inventory.keys().any(func(key: String) -> bool: return key != name_value and int(world.inventory[key]) > int(before.get(key, 0))) or world.gold > 0
			if kind == "source_skill_book": gained = consumed
			if result.get("ok", false) and consumed and gained: outcome.used += 1
			else:
				var reason: String = str(result.get("reason", result.get("message", "not_consumed")))
				outcome.failed[str(id)] = reason
				outcome.reasons[reason] = int(outcome.reasons.get(reason, 0)) + 1
				# A refused use keeps the item: nothing is half-applied.
				check(int(world.inventory.get(name_value, 0)) == int(before.get(name_value, 0)), "refused " + kind + " keeps the item " + str(id))
		evidence[kind] = outcome
		# Boxes and selection boxes open through the numeric checks once their
		# rewards have an owner; other refusals are reported by reason.
		if kind in ["guaranteed_bag","source_selectable_reward"]: check(outcome.sampled > 0 and outcome.used > 0, "sampled unrestricted " + kind + " opens, saves and rewards")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	var per_kind: int = int(argument("--runtime-sample="))
	if per_kind > 0:
		check(not SOURCE.not_installed(), "pinned 523 tables installed for the runtime sample")
		if not SOURCE.not_installed(): await runtime(per_kind)
	print("CURRENT523_ITEM_USE_NUMERIC_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"runtime":evidence}))
	quit(0 if failures.is_empty() else 1)
