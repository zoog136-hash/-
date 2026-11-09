extends SceneTree
## Original buff items whose BuffBonus rows are EXP, move/attack speed or
## PvE/PvP damage reduction apply them through the existing buff consumers,
## with the values and duration read from the original tables. Percentages are
## the original value over the UIUnit Denominator (10000) and must be whole
## percent points. Without the pinned 523 tables only the flat mapping runs.
## With TWILIGHT_PATCH523_CONTENT and --buff-ids=<file> every listed item is
## checked; with --runtime the examples are used in actual Main.
const PROJECTION = preload("res://scripts/loot/current523_native_item_projection.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const EXAMPLES = {1186:{"xp":10},312143:{},312153:{}}
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

func effect(name_value: String, unit: String, value: float) -> Dictionary:
	return {"link":{"ID":1.0,"CharacterLevel":0.0,"CharacterClass":0.0,"MinSpellLevel":0.0},"bonus":{"ID":2.0,"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":value},"type":{"Name":name_value},"unit":{"ID":99999.0,"Name":unit}}

func definition(effects: Array) -> Dictionary:
	var buff: Dictionary = {"ID":77.0,"BuffGroupID":5.0,"IsGood":true,"IsBuffGroup":true,"IsEraseOnTimeEnd":true,"BuffGroupPriority":1.0,"IsImmuneToDead":false,"IsImmuneToCancellation":false}
	var group: Dictionary = {"ID":5.0,"IsAllowPriority":false,"IsEraseBySpellLevel":false,"IsAllowOverlap":false}
	var rows: Array = []
	for pair: Array in [["BuffClassID","BuffClassID",77.0],["BuffDuration","Seconds",1800.0],["ItemConsumeDelay","MilliSeconds",500.0]]:
		rows.append({"ID":float(rows.size()+10),"IsPossession":false,"bonus_type":{"Name":pair[0]},"unit":{"Name":pair[1]},"bonus":{"ID":float(rows.size()+20),"BonusApplicationTypeID":0.0,"BonusApplicationTargetID":0.0,"Value":pair[2]}})
	return {"item_bonus":rows,"original_item":{"ID":9002.0,"TargettingTypeID":1.0,"ServiceRegionCode":""},"category":{"Name":"Potion","IsConsumable":true},
		"source_typed_references":[{"item_bonus_id":10.0,"id":77,"buff_definition":{"source":SOURCE.identity(),"ok":true,"buff_class":buff,"group":group,"bonuses":effects}}]}

func rules() -> void:
	var flat: Dictionary = PROJECTION.timed_buff(definition([effect("PVEDamageReduction","Value",3.0),effect("PVPDamageReduction","Value",2.0)]))
	check(flat.get("typed_effects") == {"pve_damage_reduction":3,"pvp_damage_reduction":2} and flat.get("activation_status") == "unrestricted" and flat.get("duration_seconds") == 1800, "flat PvE/PvP damage reduction comes from the buff rows")
	var unscaled: Dictionary = PROJECTION.timed_buff(definition([effect("MoveSpeedBonus","Value",250000.0)]))
	check(unscaled.get("activation_status") == "blocked", "a speed effect in another unit stays unsupported")
	if SOURCE.not_installed():
		var unresolved: Dictionary = PROJECTION.timed_buff(definition([effect("ExperienceAdditionPercent","Percentage",100000.0)]))
		check(unresolved.get("activation_status") == "blocked", "a percentage without its original UIUnit scale stays unsupported")

func table() -> void:
	var opened: int = 0; var listed: int = 0; var keys: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(argument("--buff-ids=")).split("\n", false):
		if not line.strip_edges().is_valid_int(): continue
		listed += 1
		var spec: Dictionary = FIELDS.full(D.definition_id(line.strip_edges()).get("native_record", {})).get("source_use_spec", {})
		if spec.get("kind") == "source_timed_buff" and spec.get("activation_status") == "unrestricted" and not spec.get("typed_effects", {}).is_empty():
			opened += 1
			for key: String in spec.typed_effects: keys[key] = int(keys.get(key, 0)) + 1
	evidence["listed"] = listed; evidence["opened"] = opened; evidence["effect_keys"] = keys
	check(listed > 0 and opened == listed, "every listed original buff item projects usable")
	var growth: Dictionary = FIELDS.full(D.definition_id("1186").get("native_record", {})).get("source_use_spec", {})
	check(growth.get("typed_effects") == {"xp":10} and growth.get("duration_seconds") == 1800, "the 10% growth potion is original ExperienceAdditionPercent 100000 for its BuffDuration")
	var cake: Dictionary = FIELDS.full(D.definition_id("312143").get("native_record", {})).get("source_use_spec", {})
	check(cake.get("typed_effects", {}).has("move_speed") and cake.typed_effects.has("attack_speed"), "speed effects reach the existing move/attack speed keys")

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	var used: Dictionary = {}
	for id: int in EXAMPLES:
		world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}; world.active_item_buffs = {}
		var staged: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(world, [{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		if not staged.get("ok", false) or world._save_game(true, staged.overrides) != OK:
			used[str(id)] = "grant: " + str(staged.get("error", "save")); continue
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		var spec: Dictionary = FIELDS.full(D.definition_id(str(id)).get("native_record", {})).get("source_use_spec", {})
		var speed_before: float = world._effective_move_speed_multiplier() if world.has_method("_effective_move_speed_multiplier") else 0.0
		var xp_before: float = world._experience_multiplier()
		var result: Dictionary = STACK.try_use(world, str(D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1).name))
		var ok: bool = result.get("ok", false)
		for key: String in spec.get("typed_effects", {}): ok = ok and world._active_item_buff_total(key) == int(spec.typed_effects[key])
		if spec.get("typed_effects", {}).has("xp"): ok = ok and is_equal_approx(world._experience_multiplier() - xp_before, float(spec.typed_effects.xp) / 100.0)
		used[str(id)] = {"ok":ok,"effects":spec.get("typed_effects", {}),"duration":spec.get("duration_seconds"),"reason":str(result.get("reason",""))}
		check(ok, "using original buff item applies its table values " + str(id))
	evidence["runtime"] = used
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		if not argument("--buff-ids=").is_empty(): table()
		if "--runtime" in OS.get_cmdline_user_args(): await runtime()
	print("CURRENT523_BUFF_EFFECT_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
