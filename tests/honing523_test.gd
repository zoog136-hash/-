extends SceneTree
## 대장간 연마 (ItemHoning 원본 표 + TWILIGHT 근사, scripts/honing/honing523_service.gd).
## Without the original ZIP only the refusal runs. With it: the rule rows, and
## in actual Main a granted +7 진명황의 집행검 is honed (forced failure, then
## success), the damage percent applies while equipped and the save reloads.
const HONING = preload("res://scripts/honing/honing523_service.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const SWORD := 450
const STONE := 258563
const ORB := 362718
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("HONING523_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func table() -> void:
	var rows: Dictionary = {}
	for enchant: int in [6,7,8,9,10]:
		var rule: Dictionary = HONING.entry(SWORD,enchant)
		rows[str(enchant)] = rule.get("probability",rule.get("code",""))
		if enchant==7: evidence["rule7"] = rule
	evidence["probabilities"] = rows
	check(str(rows["6"])=="enchant_low" and int(rows["7"])==70000 and int(rows["8"])==150000 and int(rows["9"])==330000 and int(rows["10"])==330000, "+7/+8/+9 = 7/15/33%% (NC 공식과 같음), +10 = +9 행(근사), +6 거부: %s" % str(rows))
	var rule7: Dictionary = evidence.rule7
	check(rule7.get("ok",false) and rule7.costs.size()==2 and is_equal_approx(float(rule7.damage_percent),5.0) and str(rule7.epithet.name)=="태고의", "비용 2종, 수식어 태고의 · 대미지 +5%")
	check(HONING.entry(STONE,9).get("code")=="not_target", "a non-weapon is not a honing target")

func seed_for(probability: int, success: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for value: int in range(1,100000):
		rng.seed = value
		if (rng.randi_range(0,HONING.SCALE-1)<probability)==success: return value
	return 0

func physical_of(world: Node, item_class_id: int) -> Array:
	var result: Array = []
	for uid: String in world.item_instances:
		var entry: Variant = world.item_instances[uid]
		if entry is Dictionary and entry.get("record") is Dictionary and int(entry.record.get("source_item_class_id",0))==item_class_id and not entry.has(STACK.RECEIPT): result.append(uid)
	result.sort()
	return result

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.inventory = {}; world.item_instances = {}; world.equipped_items = {}
	var staged: Dictionary = SUPPLY.stage(world,[{"item_class_id":SWORD,"amount":1,"bless_raw":1,"enchant":7},{"item_class_id":STONE,"amount":4,"bless_raw":1,"enchant":0},{"item_class_id":ORB,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok",false): check(false, "grant: "+str(staged)); world.queue_free(); await process_frame; return
	check(world._save_game(true,staged.overrides)==OK, "grant save")
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var sword: Array = physical_of(world,SWORD)
	check(sword.size()==1, "one physical +7 진명황의 집행검")
	if sword.is_empty(): world.queue_free(); await process_frame; return
	var uid: String = str(sword[0])
	var q: Dictionary = HONING.quote(world,uid)
	evidence["quote"] = {"ok":q.get("ok"),"reason":q.get("reason",""),"percent":q.get("percent","")}
	check(q.get("ok",false) and str(q.percent)=="7%", "quote: 7%")
	world.rng.seed = seed_for(70000,false)
	var failed: Dictionary = HONING.attempt(world,uid)
	evidence["fail"] = failed
	check(failed.get("ok",false) and not failed.success and world.item_instances.has(uid) and not world.item_instances[uid].has("honing") and int(world.item_instances[uid].level)==7 and int(HONING.REFINE.stacks_of(world,STONE).total)==2 and int(HONING.REFINE.stacks_of(world,ORB).total)==1, "failure: weapon and +7 stay, 연금석 4→2, 구 2→1")
	world.rng.seed = seed_for(70000,true)
	var won: Dictionary = HONING.attempt(world,uid)
	evidence["success"] = won
	check(won.get("ok",false) and won.success and str(world.item_instances[uid].honing.epithet)=="태고의" and int(HONING.REFINE.stacks_of(world,STONE).total)==0, "success: 태고의 recorded, materials spent")
	check(HONING.quote(world,uid).get("code")=="honed", "a honed weapon is refused")
	world.equipped_items["weapon"] = {"instance_id":uid}
	check(is_equal_approx(HONING.damage_percent(world),5.0), "equipped honed weapon: 대미지 +5%")
	world.equipped_items = {}
	check(world._save_game(true)==OK, "save")
	world.item_instances = {}
	world._load_game(true)
	check(world.item_instances.get(uid,{}).get("honing",{}).get("epithet","")=="태고의", "honing survives reload")
	world.queue_free()
	await process_frame

func run() -> void:
	check(SOURCE.identity().is_empty()==(HONING.entry(SWORD,7).get("code")=="source_not_installed"), "without the original ZIP honing is held")
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("HONING523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
