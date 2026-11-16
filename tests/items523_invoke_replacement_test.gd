extends SceneTree
## 신화 무기 발동 교체 (ItemInvokeReplacementID) — TWILIGHT 근사 ledger
## (scripts/loot/item_invoke_replacement523.gd). Without the original ZIP only the
## save shape is checked. With it, in actual Main: a granted +7 진명황의 집행검 draws
## each slot once, the drawn invokes join the worn weapon's invokes, and the draw
## survives save/reload (no redraw).
const LEDGER = preload("res://scripts/loot/item_invoke_replacement523.gd")
const COMBAT = preload("res://scripts/crafting/patch523_equipment_combat.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const SWORD := 450
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("INVOKE_REPLACE523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func unit() -> void:
	var ledger = LEDGER.new()
	ledger.import_state({"schema":1,"rolled":{"a":{"1":1334,"2":"x"},"b":5}})
	check(ledger.export_state().rolled == {"a":{"1":1334}}, "import keeps only well-formed draws: "+str(ledger.export_state()))

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.job_class = "기사"; world.level = 90
	world.equipped_items.clear(); world._invalidate_equipment_static()
	world.inventory = {}; world.item_instances = {}
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":SWORD,"amount":1,"bless_raw":1,"enchant":7}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "grant +7 진명황의 집행검: "+str(staged.get("error",""))): world.queue_free(); await process_frame; return
	world._save_game(true,staged.overrides)
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var uid: String = ""
	for key: String in world.item_instances:
		if int(world.item_instances[key].get("record",{}).get("source_item_class_id",-1)) == SWORD: uid = key
	check(world.item_invoke523.replacement_id(world.item_instances[uid].record) == 94, "진명황의 집행검 → ItemInvokeReplacementID 94")
	check(world.item_invoke523.sync() and world.item_invoke523.state.rolled.has(uid), "first sight draws the slots")
	var drawn: Dictionary = world.item_invoke523.state.rolled.get(uid,{}).duplicate()
	evidence["drawn"] = {"slots":drawn,"names":world.item_invoke523.drawn_names(uid)}
	check(drawn.size() == 4 and int(drawn.get("1",0)) == 1334 and int(drawn.get("2",0)) == 1344, "4 slots, fixed slots 1·2 = 카오스 크래시·이레이즈 이뮨 투 함: "+str(evidence.drawn))
	var effects: Array = world.item_invoke523.effects(uid, 7)
	evidence["effects"] = effects.map(func(e: Dictionary) -> Array: return [e.kind, e.probability, e.option_id, e.approx_replacement_slot])
	var chaos: bool = false
	for effect: Dictionary in effects:
		if int(effect.option_id) == 461 and int(effect.probability) == 100000: chaos = true
	check(chaos, "+7 카오스 크래시 row (EnchantLevel 7) = 10% InvokeOption 461: "+str(evidence.effects))
	check(not world.item_invoke523.sync(), "no redraw")
	world._equip_or_acquire_item(world.item_instances[uid].record,false,uid,"weapon")
	world._invalidate_equipment_static()
	var worn: Array = []
	for kind: String in ["attack_source_spell","attack_fixed_damage","attack_weapon_scale"]:
		for effect: Dictionary in COMBAT.active(world, kind):
			if effect.has("approx_replacement_slot"): worn.append([kind, int(effect.option_id), int(effect.probability)])
	evidence["worn"] = worn
	check(world._is_instance_equipped(uid) and not worn.is_empty(), "worn weapon: drawn invokes are active "+str(worn))
	check(world._save_game(true) == OK, "save")
	world.item_invoke523.state = {"schema":1,"rolled":{}}
	world._load_game(true)
	check(world.item_invoke523.state.rolled.get(uid,{}) == drawn, "reload keeps the same draw")
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	unit()
	if not SOURCE.not_installed(): await runtime()
	print("INVOKE_REPLACE523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
