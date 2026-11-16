extends SceneTree
## TWILIGHT 근사 LuckyBag rules (docs/items523_remaining_missing_rules.md 18):
## test/dummy reward rows are dropped, a class probability total other than
## 10,000,000 is drawn over its own total. Without the original ZIP only the
## draw rule runs; with it every LuckyBag is projected and counted, and in
## actual Main one dropped-test box and one renormalized box are opened.
const USE = preload("res://scripts/loot/patch523_item_use.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("LUCKYBAG_APPROX_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func unit() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var spec: Dictionary = {"kind":"source_weighted_bag","rewards":[{"entity_type_id":0,"probability_raw":2000000,"class_ids":[],"item_class_id":1},{"entity_type_id":0,"probability_raw":2000000,"class_ids":[],"item_class_id":2}]}
	check(not USE.select_rewards(spec,1,rng).get("ok",true), "a 4,000,000 total is refused without the approximation flag")
	spec["approx_renormalized"] = true
	var hits: Dictionary = {}
	for _i: int in 400:
		var picked: Dictionary = USE.select_rewards(spec,1,rng)
		if picked.get("ok",false): hits[int(picked.rewards[0].item_class_id)] = int(hits.get(int(picked.rewards[0].item_class_id),0)) + 1
	check(hits.size()==2 and int(hits.get(1,0))>120 and int(hits.get(2,0))>120, "renormalized draw picks both rows ~50/50: "+str(hits))

func spec_of(id: int) -> Dictionary:
	var record: Dictionary = D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)
	return NATIVE_FIELDS.full(record).get("source_use_spec",{}) if not record.is_empty() else {}

func table() -> Dictionary:
	var categories: Dictionary = {}
	for row: Dictionary in SOURCE.rows("ItemCategory"):
		if str(row.get("Name",""))=="LuckyBag": categories[int(row.ID)] = true
	var counts: Dictionary = {"bags":0,"usable":0,"dropped_test":0,"renormalized":0,"blocked":0}
	var picks: Dictionary = {}
	for row: Dictionary in SOURCE.rows_matching("ItemClass","CategoryID",categories):
		if row.get("TestItem")!=false: continue
		var spec: Dictionary = spec_of(int(row.ID))
		if spec.is_empty() or spec.get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"]: continue
		counts.bags += 1
		if spec.get("activation_status")=="unrestricted":
			counts.usable += 1
			if spec.has("approx_dropped_test_rewards"):
				counts.dropped_test += 1
				if not picks.has("dropped") and spec.kind=="guaranteed_bag": picks["dropped"] = int(row.ID)
			if spec.get("approx_renormalized",false):
				counts.renormalized += 1
				if not picks.has("renormalized"): picks["renormalized"] = int(row.ID)
		else: counts.blocked += 1
	evidence["counts"] = counts
	evidence["picks"] = picks
	check(int(counts.dropped_test)>0 and int(counts.renormalized)>0, "approximations open boxes: "+str(counts))
	return picks

func runtime(picks: Dictionary) -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for kind: String in ["dropped","renormalized"]:
		if not picks.has(kind): continue
		world.inventory = {}; world.item_instances = {}
		var id: int = int(picks[kind])
		var staged: Dictionary = SUPPLY.stage(world,[{"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
		if not staged.get("ok",false): check(false,"grant box %d: %s" % [id,str(staged)]); continue
		world._save_game(true,staged.overrides)
		world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
		var name_value: String = ""
		for key: String in world.inventory: name_value = key
		var before: Dictionary = world.inventory.duplicate(true)
		var result: Dictionary = STACK.try_use(world,name_value)
		var received: Array = []
		var test_received: bool = false
		for key: String in world.inventory:
			if not before.has(key): received.append(key)
		for value: Variant in world.item_instances.values():
			if value is Dictionary and value.get("record") is Dictionary and SOURCE.row("ItemClass",int(value.record.get("source_item_class_id",0))).get("TestItem")==true: test_received = true
		evidence[kind] = {"box":id,"name":name_value,"ok":result.get("ok"),"reason":result.get("reason",result.get("message","")),"received":received}
		check(result.get("ok",false) and not world.inventory.has(name_value) and not received.is_empty() and not test_received, "%s box #%d opens and gives non-test rewards: %s" % [kind,id,str(evidence[kind])])
	world.queue_free()
	await process_frame

func run() -> void:
	unit()
	if not SOURCE.not_installed():
		var picks: Dictionary = table()
		await runtime(picks)
	print("LUCKYBAG_APPROX_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
