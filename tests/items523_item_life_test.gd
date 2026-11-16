extends SceneTree
## TWILIGHT 근사 획득 후 수명(ItemBonus Life) 장부 (scripts/loot/item_life523.gd,
## docs/items523_remaining_missing_rules.md 19). With the original pack: a
## granted Life item is stamped, survives save/load with its time, and is
## removed (and saved) once acquisition + Life has passed.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const EFFECTS = preload("res://scripts/loot/source523_item_effects.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const QA = preload("res://tests/qa_class_selection.gd")
## 윈다우드성 던전 이동 주문서 (각인): Life 1,209,600초 (14일).
const LIFE_ITEM := 117123
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("ITEM_LIFE523_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.inventory = {}; world.item_instances = {}; world.item_life523.import_state({})
	var staged: Dictionary = SUPPLY.stage(world,[{"item_class_id":LIFE_ITEM,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok",false): check(false,"grant: "+str(staged)); world.queue_free(); await process_frame; return
	world._save_game(true,staged.overrides)
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var uid: String = str(world.item_instances.keys()[0])
	var name_value: String = str(world.item_instances[uid].name)
	var t0: int = 1800000000
	check(world.item_life523.sync(t0), "the new Life item is stamped")
	var life: int = world.item_life523.life_seconds(world.item_instances[uid].record)
	evidence["life"] = {"seconds":life,"remaining":world.item_life523.remaining(uid,t0+3600),"teleport":EFFECTS.location_teleport(world.item_instances[uid].record).get("land_id",0)}
	check(life==1209600 and world.item_life523.remaining(uid,t0+3600)==1209600-3600 and int(evidence.life.teleport)>0, "Life 14일, 1시간 뒤 남은 시간, 이동 주문서 사용 소유자 연결: "+str(evidence.life))
	check(world._save_game(true)==OK, "save with the ledger")
	world.item_life523.import_state({})
	world._load_game(true)
	check(int(world.item_life523.state.acquired.get(uid,0))==t0, "reload keeps the acquisition time")
	check(world.item_life523.sweep(t0+life-1).is_empty() and world.item_instances.has(uid), "not removed one second before expiry")
	var removed: Array = world.item_life523.sweep(t0+life)
	check(removed==[name_value] and not world.item_instances.has(uid) and not world.inventory.has(name_value), "removed at acquisition + Life: "+str(removed))
	# An older save without the ledger: Life items start at the load time.
	world.item_life523.import_state({})
	var staged2: Dictionary = SUPPLY.stage(world,[{"item_class_id":LIFE_ITEM,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	world.inventory = staged2.overrides.inventory; world.item_instances = staged2.overrides.item_instances
	var before: int = int(Time.get_unix_time_from_system())
	world.item_life523.sync()
	var uid2: String = str(world.item_instances.keys()[0])
	check(int(world.item_life523.state.acquired.get(uid2,0))>=before, "a ledger-less item starts at the current time")
	world.queue_free()
	await process_frame

func run() -> void:
	if not SOURCE.not_installed(): await runtime()
	else: check(preload("res://scripts/loot/item_life523.gd").SAVE_KEY=="item_life523", "save key")
	print("ITEM_LIFE523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
