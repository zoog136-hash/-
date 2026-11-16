extends SceneTree
## 시간 충전석 (LandTimeRecharger) — TWILIGHT 근사.
## Pool part (no ZIP needed): prepare/switch/pulse/end keep their results; the new
## "recharge" change adds time above TimeLimit up to TimeLimit + MaxRechargeTime, refuses
## when full, keeps the busy guard, and another pool instance that saw the old state does
## not take the recharge for a rollback. A raised balance without a recharge record is
## still refused.
## Item part (original ZIP, actual Main): a 시간 충전석 has a use owner; with the own
## map time in effect one unit is debited and the pool charged, a full group keeps the
## item; with the default always-open policy the existing dungeon window recharge is used.
const POOL = preload("res://scripts/maps/current523_map_time_pool.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const PROFILE: Dictionary = {"source_snapshot":"patch523","ServiceRegionCode":"KR","WorldNo":1}
const GROUP: Dictionary = {"ID":41,"DescID":1,"ContentsResetScheduleTypeID":1,"TimeLimit":3600,"MaxRechargeTime":7200,"StartDateTimeID":0,"EndDateTimeID":0,"ServiceTypeID":13}
const STONE := 202238 # [시간 충전석][미션] 주말 월드 던전 시간 충전석 → group 30582, 3600 s
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("MAP_TIME_RECHARGE523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func wipe() -> void:
	for path: String in [POOL.PATH, POOL.LOCK_PATH, POOL.REGISTRATION_PATH.path_join("head.json")]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(POOL.LOCK_PATH): DirAccess.remove_absolute(POOL.LOCK_PATH)
	if DirAccess.dir_exists_absolute(POOL.REGISTRATION_PATH): DirAccess.remove_absolute(POOL.REGISTRATION_PATH)

func near(value: int, target: int, slack: int = 5000) -> bool:
	return value <= target and value >= target - slack

func pool_part() -> void:
	wipe()
	var host := Node.new(); root.add_child(host)
	var pool = POOL.new()
	check(pool.configure(host), "pool configure")
	# Regression: the existing four changes.
	var prepared: Dictionary = pool.prepare([GROUP], PROFILE)
	check(prepared.ok and prepared.prepared and prepared.committed and int(prepared.remaining_ms) == 3600000, "prepare: TimeLimit balance "+str(prepared.remaining_ms))
	var switched: Dictionary = pool.switch_session(7, [GROUP], PROFILE)
	check(switched.ok and switched.active and pool.active() and int(switched.remaining_ms) == 3600000, "switch: lease active")
	check(pool.pulse(), "pulse while active")
	var ended: Dictionary = pool.end_session()
	check(ended.ok and not ended.active and not pool.active() and ended.committed, "end: lease closed and committed")
	var quoted: Dictionary = pool.quote([GROUP], PROFILE)
	check(quoted.ok and near(int(quoted.remaining_ms), 3600000), "quote after end")
	evidence["regression"] = {"prepare":prepared.remaining_ms,"switch":switched.remaining_ms,"end":ended.remaining_ms}
	# Another pool instance sees the state before the recharge.
	var host2 := Node.new(); root.add_child(host2)
	var other = POOL.new(); other.configure(host2)
	check(other.quote([GROUP], PROFILE).ok, "second instance reads the state")
	# Recharge.
	var before: int = int(quoted.remaining_ms)
	var charged: Dictionary = pool.recharge(GROUP, PROFILE, 3600000)
	evidence["recharge"] = {"ok":charged.ok,"reason":charged.reason,"remaining":charged.remaining_ms,"recharged":charged.get("recharged_ms"),"cap":charged.get("cap_ms")}
	check(charged.ok and int(charged.remaining_ms) == before + 3600000 and int(charged.recharged_ms) == 3600000 and int(charged.cap_ms) == 10800000, "recharge +1h above TimeLimit "+str(evidence.recharge))
	var seen_by_other: Dictionary = other.quote([GROUP], PROFILE)
	check(seen_by_other.ok and int(seen_by_other.remaining_ms) == before + 3600000, "the other instance accepts the recorded recharge (no rollback): "+str(seen_by_other.reason))
	# Fill to the cap, then refuse.
	var last: Dictionary = {}
	var full: Dictionary = {}
	var steps: int = 0
	for i: int in 6:
		var step: Dictionary = pool.recharge(GROUP, PROFILE, 3600000)
		if not step.ok: full = step; break
		last = step; steps += 1
	evidence["cap"] = {"steps":steps,"last":last.get("remaining_ms"),"last_added":last.get("recharged_ms"),"full":full.get("reason")}
	check(steps >= 1 and steps <= 2 and int(last.remaining_ms) == 10800000 and int(last.recharged_ms) <= 3600000, "recharges stop exactly at TimeLimit + MaxRechargeTime "+str(evidence.cap))
	check(not full.is_empty() and full.reason == "map_time_recharge_full" and int(full.remaining_ms) == 10800000, "a full group refuses")
	# Busy guard and argument guard.
	pool._busy = true
	check(pool.recharge(GROUP, PROFILE, 1000).reason == "map_time_operation_busy", "busy guard")
	pool._busy = false
	check(not pool.recharge(GROUP, PROFILE, 0).ok and not pool.recharge(GROUP, {}, 1000).ok, "invalid amount / missing server profile refused")
	# A recharge during an open lease: the lease keeps charging from the new balance.
	var spent: Dictionary = pool.switch_session(7, [GROUP], PROFILE)
	check(spent.ok and pool.active(), "switch over a recharged balance")
	check(pool.pulse(), "pulse over a recharged balance")
	var during: Dictionary = pool.recharge(GROUP, PROFILE, 1000)
	check(during.ok and pool.active() and int(during.recharged_ms) > 0, "recharge during an open lease keeps the lease "+str(during.reason))
	var closed: Dictionary = pool.end_session()
	var after_close: Dictionary = pool.quote([GROUP], PROFILE)
	check(closed.ok and after_close.ok and int(after_close.remaining_ms) <= 10800000 and int(after_close.remaining_ms) > 10800000 - 10000, "end over a recharged balance "+str(after_close.remaining_ms))
	# Validator: a balance above TimeLimit without a recharge record is refused, an
	# old document (no recharged_ms) is still valid.
	var state: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POOL.PATH))
	var scope: String = state.scopes.keys()[0]
	var tampered: Dictionary = state.duplicate(true)
	tampered.scopes[scope].groups["41"].erase("recharged_ms")
	check(not pool._document_problem(tampered).is_empty(), "balance above TimeLimit without recharged_ms is invalid")
	var old: Dictionary = state.duplicate(true)
	old.scopes[scope].groups["41"].erase("recharged_ms"); old.scopes[scope].groups["41"].remaining_ms = 1000
	check(pool._document_problem(old).is_empty(), "an old document without recharged_ms stays valid")
	var over: Dictionary = state.duplicate(true)
	over.scopes[scope].groups["41"].remaining_ms = 10800001
	check(not pool._document_problem(over).is_empty(), "balance above the cap is invalid")
	host.queue_free(); host2.queue_free()
	wipe()

func stone_record() -> Dictionary:
	return D.variant_item(D.definition_id(str(STONE)).get("native_record",{}),1)

func count(world: Node, name: String) -> int:
	return int(world.inventory.get(name,0))

func item_part() -> void:
	wipe()
	var record: Dictionary = stone_record()
	var effect: Dictionary = STACK.profile(record)
	evidence["profile"] = {"kind":effect.get("kind",""),"group":effect.get("spec",{}).get("group_id",0),"seconds":effect.get("spec",{}).get("seconds",0)}
	check(effect.get("kind") == "time_recharge" and int(effect.spec.group_id) == 30582 and int(effect.spec.seconds) == 3600, "#%d has the time-recharge use owner %s" % [STONE,str(evidence.profile)])
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.level = 90
	world.inventory = {}; world.item_instances = {}
	var staged: Dictionary = INVENTORY.stage(world,[{"item_class_id":STONE,"amount":4,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "grant 4 stones: "+str(staged.get("error",""))):
		world.queue_free(); for frame: int in 5: await process_frame
		return
	world._save_game(true,staged.overrides)
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	var name: String = str(record.name)
	var controller: RefCounted = world._aden_play_controller()
	var saved_settings: Dictionary = controller.settings.duplicate(true)
	# Default: always open → the dungeon window pools.
	controller.settings["map_open_policy"] = OPTIONS.OWN_ALWAYS_OPEN_V1
	check(not controller.map_time_in_effect(), "default policy: own map time not in effect")
	var play = world.dungeon_play
	var bonus_before: int = int(play.pool(30582,int(Time.get_unix_time_from_system())).bonus)
	world.item_use_cooldowns.clear()
	var dungeon_use: Dictionary = STACK.try_use(world,name)
	var bonus_after: int = int(play.pool(30582,int(Time.get_unix_time_from_system())).bonus)
	evidence["dungeon_route"] = {"ok":dungeon_use.get("ok"),"reason":dungeon_use.get("reason",""),"route":dungeon_use.get("route",""),"left":count(world,name),"bonus":[bonus_before,bonus_after]}
	check(dungeon_use.get("ok",false) and dungeon_use.get("route") == "dungeon_play" and count(world,name) == 3 and bonus_after == bonus_before + 3600, "always open: the dungeon window pool gets +1h, one stone used "+str(evidence.dungeon_route))
	# Own map time in effect → the map time pool.
	controller.settings["map_open_policy"] = OPTIONS.SOURCE_CONDITIONS_V1
	controller.settings["map_time_policy"] = OPTIONS.OWN_MAP_TIME
	check(controller.map_time_in_effect(), "own map time in effect")
	var results: Array = []
	for i: int in 3:
		world.item_use_cooldowns.clear()
		var used: Dictionary = STACK.try_use(world,name)
		results.append({"ok":used.get("ok"),"reason":used.get("reason",""),"route":used.get("route",""),"remaining":used.get("map_time",{}).get("remaining_ms",-1),"left":count(world,name)})
	evidence["map_route"] = results
	var group: Dictionary = SOURCE.row("LandTimeLimitGroup",30582)
	var cap: int = POOL.cap_ms(group)
	var steps: int = int(group.MaxRechargeTime) / 3600
	evidence["group"] = {"TimeLimit":group.get("TimeLimit"),"MaxRechargeTime":group.get("MaxRechargeTime"),"cap_ms":cap}
	check(results[0].ok and results[0].route == "own_map_time" and int(results[0].left) == 2 and int(results[0].remaining) == int(group.TimeLimit)*1000 + 3600000, "first map-time use: TimeLimit + 1h, 3→2 "+str(results[0]))
	if steps >= 3:
		check(results[2].ok and int(results[2].left) == 0, "three uses within MaxRechargeTime "+str(results))
	else:
		check(not results[steps].ok and str(results[steps].reason).contains("상한") and int(results[steps].left) == 3 - steps, "a full group keeps the stone "+str(results))
	# The debit survives a reload and the pool file keeps the charge.
	var left: int = count(world,name)
	world._load_game(true)
	check(count(world,name) == left, "reload keeps the debited count")
	var reader = POOL.new()
	var host := Node.new(); root.add_child(host); reader.configure(host)
	var after: Dictionary = reader.quote([group], preload("res://scripts/maps/current523_map_runtime_context.gd").capture(world).server_profile)
	check(after.ok and int(after.remaining_ms) > int(group.TimeLimit)*1000, "the pool file keeps the charged time "+str(after.get("remaining_ms")))
	host.queue_free()
	controller.settings = saved_settings
	world.queue_free()
	for frame: int in 5: await process_frame
	wipe()

func run() -> void:
	pool_part()
	if not SOURCE.not_installed(): await item_part()
	print("MAP_TIME_RECHARGE523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
