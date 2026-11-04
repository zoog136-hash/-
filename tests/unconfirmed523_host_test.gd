extends SceneTree
const Runtime = preload("res://scripts/unconfirmed523/runtime.gd")
const View = preload("res://scripts/unconfirmed523/view.gd")
var failures: Array[String] = []
var checks: int = 0

class Ain extends RefCounted:
	var dragon_orb_expires_at: int = 0
	var source_jade_level_override: int = -1
	var saved: Dictionary = {"blessing":0,"dragon_orb_expires_at":0,"last_orb_purchase_month":"2026-11","auto_recharge":true}
	func export_state() -> Dictionary: return saved.duplicate(true)
	func import_state(value: Dictionary) -> void:
		saved = value.duplicate(true)
		dragon_orb_expires_at = int(saved.dragon_orb_expires_at)
class Quest extends RefCounted:
	func export_state() -> Dictionary: return {"claimed":{}}
class Hud extends RefCounted:
	var callback: Callable
	var opened: String = ""
	func refresh_inventory(_value: Dictionary) -> void: pass
	func open_unconfirmed523(key: String) -> void: opened = key
	func confirm_action(_title: String,_description: String,_accept: String,then: Callable) -> void: callback = then
	func show_message(_value: String) -> void: pass
class Host extends Node:
	const BASE508 = preload("res://scripts/lineagem_base508.gd")
	const EXP_PROGRESSION = preload("res://scripts/experience_progression.gd")
	var hp: int = 100
	var cache_invalidations: int = 0
	var level: int = 85
	var experience: int = 0
	var exp_need: int = 500
	var stat_points: int = 7
	var job_class: String = "기사"
	var active_map_id: String = "fixture_map"
	var gold: int = 1000
	var inventory: Dictionary = {"native stack":4}
	var item_instances: Dictionary = {}
	var equipped_items: Dictionary = {}
	var ui_preferences: Dictionary = {"item_locks":{}}
	var ain_service = Ain.new()
	var quest_service = Quest.new()
	var hud = Hud.new()
	var next_item_instance_id: int = 100
	var runtime_service
	var save_result: Error = OK
	var save_calls: int = 0
	var disk: Dictionary = {}
	var last_staged: Dictionary = {}
	var catalog: Dictionary = {"native stack":{"source_item_class_id":100,"sourceId":"m523:item:100"}}
	func _find_catalog_item_record(label: String) -> Dictionary: return catalog.get(label,{})
	func _is_instance_equipped(uid: String) -> bool:
		for item: Dictionary in equipped_items.values():
			if item.get("instance_id") == uid: return true
		return false
	func _save_game(_quiet: bool, staged: Dictionary) -> Error:
		if runtime_service != null: runtime_service.snapshot()
		save_calls += 1
		last_staged = staged.duplicate(true)
		if save_result == OK: disk = staged.duplicate(true)
		return save_result
	func _update_hud() -> void: pass
	func _invalidate_equipment_static() -> void: cache_invalidations += 1
class Source extends RefCounted:
	var available: bool = true
	var last_error: String = "fixture source unavailable"
	func ready() -> bool: return available
	func rows(table: String) -> Array:
		if table == "CurrencyUnitClass": return [{"ID":1,"CurrencyID":9,"UnitID":4,"ClassID":100,"ForGive":false,"ConsumePriority":0},{"ID":2,"CurrencyID":9,"UnitID":4,"ClassID":101,"ForGive":true,"ConsumePriority":0}]
		return []
	func row(table: String,id: int) -> Dictionary:
		if table == "ItemClass" and id in [100,101,200,300]: return {"ID":id,"Name":"fixture " + str(id),"CategoryID":78 if id == 100 else 10291 if id == 300 else 10,"MaxStackAmount":1 if id == 200 else 999999,"GradeID":3}
		if table == "Bonus": return {"ID":id}
		return {}
	func item_eligibility(_id: int,_context: Dictionary) -> Dictionary: return {"ok":true}
	func bonus_stats(_ids: Array,_context: Dictionary) -> Dictionary: return {"stats":{"ac:flat":-2.0,"experience_bonus:percent":5.0}}
class Domain extends RefCounted:
	func view(_ctx: Dictionary,_state: Dictionary) -> Dictionary: return {"title":"fixture","notes":[],"rows":[]}
	var reward_values: Array = [{"kind":"item","id":200,"amount":2},{"kind":"experience","id":1,"amount":600}]
	var received_events: Array = []
	func initial_state() -> Dictionary: return {"rng":1,"claims":{},"passes":{}}
	func validate_state(value: Variant) -> String: return "" if value is Dictionary and value.has("rng") else "bad mock state"
	func propose(_request: Dictionary,_context: Dictionary, state: Dictionary) -> Dictionary:
		if state.claims.has("claim"): return {"ok":false,"error":"already claimed"}
		var next: Dictionary = state.duplicate(true)
		next.rng += 1
		next.claims.claim = true
		return {"ok":true,"state":next,"costs":[{"kind":"item","id":100,"amount":2},{"kind":"currency","id":1,"amount":10}],"rewards":reward_values.duplicate(true)}
	func event(value: Dictionary,_context: Dictionary,state: Dictionary) -> Dictionary:
		received_events.append(value.duplicate(true))
		return {"ok":true,"state":state.duplicate(true)}
	func add_pass_exp(state: Dictionary,id: int,amount: int) -> Dictionary:
		var next: Dictionary = state.duplicate(true)
		next.passes[str(id)] = {"experience":int(next.passes.get(str(id),{}).get("experience",0))+amount}
		return {"ok":true,"state":next}
class Challenge extends Domain:
	func initial_state() -> Dictionary: return {"rng":1,"claims":{},"passes":{},"active":{"run_id":7,"failed":false},"ticks":0}
	func event(value: Dictionary,_ctx: Dictionary,state: Dictionary) -> Dictionary:
		received_events.append(value.duplicate(true))
		var next: Dictionary = state.duplicate(true)
		if value.kind == "survival_tick": next.ticks += 1
		if value.kind == "map_change": next.active.failed = true
		return {"ok":true,"state":next}
class Jade extends RefCounted:
	var stack_set_thresholds: bool = true
	var protection_dispatch: Dictionary = {1:54252,14:66574}
	var percent_ignore: bool = false
	func initial_state() -> Dictionary: return {"version":1,"latest_at":0,"jade":{}}
	func validate_state(_value: Variant) -> String: return ""
	func bonuses(_ctx: Dictionary,_state: Dictionary) -> Dictionary:
		var result: Dictionary = {"stats":{"armor_class":1.0},"effects":[],"unsupported":[]}
		if percent_ignore:
			result.stats.ignore_melee_damage_reduction_pct = 1.0
			result.effects.append({"key":"ignore_melee_damage_reduction_pct","applied":true,"type_id":5681,"raw_value":10000})
		return result
	func jade_status(_ctx: Dictionary,_state: Dictionary) -> Dictionary: return {"protection_level":0}

func _initialize() -> void: call_deferred("_run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("HOST_FAIL: " + label)
func fixture() -> Dictionary:
	var world = Host.new()
	var runtime = Runtime.new()
	runtime.world = world
	world.runtime_service = runtime
	runtime.source = Source.new()
	runtime._source_configured = true
	runtime.domains = {"events":Domain.new(),"jade_grail":Jade.new()}
	runtime.state = runtime.fresh()
	runtime.test_now = 1793780000
	return {"world":world,"runtime":runtime}
func _run() -> void:
	var f: Dictionary = fixture()
	var runtime = f.runtime
	var world = f.world
	var ctx: Dictionary = runtime.context()
	var policy_before: Dictionary = runtime.policy.duplicate(true)
	check(not runtime.apply_policy_config({"policy":{"allow_test_items":true}}).get("ok",false) and runtime.policy == policy_before,"policy file cannot enable source TestItem or partially mutate defaults")
	check(not runtime.apply_policy_config({"time_policy":{"utc_offset_minutes":9999}}).get("ok",false),"unsafe timezone configuration rejected")
	check(runtime.apply_policy_config({"policy":{"stack_set_thresholds":false,"protection_dispatch":{"1":54252,"14":66574}},"time_policy":{"attendance_reset_hour":5}}).get("ok",false) and not runtime.domains.jade_grail.stack_set_thresholds,"validated source policy reaches domain without source grants")
	check(int(ctx.max_level) == 85 and ctx.max_level_basis == "local_monotonic_level","source max level uses proven monotonic local model")
	check(int(ctx.class_id) == Host.BASE508.source_class_id("기사"),"actual BASE508 class mapping")
	check(int(ctx.owned.get("100",0)) == 4 and ctx.instances.is_empty(),"native catalog stack counts without invented physical IDs")
	check(int(ctx.currencies.get("9",0)) == 4,"currency consumes ForGive=false mapping only")
	var start_fingerprint: String = runtime.fingerprint()
	var start_revision: int = int(runtime.state.revision)
	var result: Dictionary = runtime.execute("events",{},start_revision,start_fingerprint)
	check(result.get("ok",false),"successful atomic transaction")
	check(int(world.inventory["native stack"]) == 2 and world.gold == 990,"exact stack and Adena costs once")
	check(world.item_instances.size() == 2 and world.next_item_instance_id == 102,"two nonstack rewards have independent stable IDs")
	check(world.level == 86 and world.experience == 100 and world.stat_points == 8 and world.exp_need == Host.EXP_PROGRESSION.required_for_level(86,500),"level85 experience reward uses actual progression API")
	check(int(world.disk.unconfirmed523.domains.events.rng) == 2 and world.disk.inventory == world.inventory and int(world.disk.level) == 86,"durable payload contains matching costs rewards progression RNG")
	check(not runtime.execute("events",{},start_revision,start_fingerprint).get("ok",false) and world.save_calls == 1,"duplicate stale confirmation cannot repeat transaction")
	check(not runtime.execute("events",{}).get("ok",false),"claim state prevents repeat without UI token")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	runtime.domains.events.reward_values = [{"kind":"pass_exp","id":724,"amount":60}]
	result = runtime.execute("events",{})
	check(result.get("ok",false) and int(runtime.context().pass_exp.get("724",0)) == 60 and int(world.disk.unconfirmed523.domains.events.passes["724"].experience) == 60,"pass XP helper progression and context commit in same save")
	runtime.time_policy = {"utc_offset_minutes":123,"pass_reset_hour":5}
	check(int(runtime.context().time_policy.utc_offset_minutes) == 123 and int(runtime.context().time_policy.pass_reset_hour) == 5,"host time policy override retained")
	runtime._source_configured = false
	check(not runtime.execute("events",{}).get("ok",false),"freshly installed source cannot use unconfigured domains before restart")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	world.save_result = ERR_CANT_CREATE
	var original: Dictionary = {"inventory":world.inventory.duplicate(true),"instances":world.item_instances.duplicate(true),"gold":world.gold,"experience":world.experience,"state":runtime.state.duplicate(true)}
	result = runtime.execute("events",{})
	check(not result.get("ok",false),"save failure returned")
	check(world.inventory == original.inventory and world.item_instances == original.instances and world.gold == original.gold and world.experience == original.experience and runtime.state == original.state,"save failure changes no cost reward claim RNG or experience")
	check(runtime.save_blocked and not runtime.execute("events",{}).get("ok",false) and world.save_calls == 1,"uncertain publication blocks retries until explicit reload")
	runtime.restore({"unconfirmed523":original.state})
	check(not runtime.save_blocked,"explicit valid reload clears save protection")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	world.item_instances = {"locked":{"name":"native stack","source_reward_quantity":4,"record":{"source_item_class_id":100,"sourceId":"m523:item:100","source_reward_quantity":4}}}
	world.ui_preferences.item_locks.locked = true
	check(not runtime.execute("events",{}).get("ok",false) and world.save_calls == 0,"locked exact native stack cannot pay")
	world.ui_preferences.item_locks.clear(); world.item_instances.locked.sealed = true
	check(not runtime.execute("events",{}).get("ok",false) and world.save_calls == 0,"sealed exact native stack cannot pay")
	world.item_instances.locked.erase("sealed"); world.equipped_items.weapon = {"instance_id":"locked"}
	check(not runtime.execute("events",{}).get("ok",false) and world.save_calls == 0,"equipped native item cannot pay")
	world.equipped_items.clear(); world.item_instances.locked.expires_at = runtime.now()
	check(not runtime.execute("events",{}).get("ok",false) and world.save_calls == 0,"expired physical stack cannot pay or reappear as bag remainder")
	world.item_instances.locked.erase("expires_at"); world.item_instances.locked.record.expiration = "unknown format"
	check(not runtime.execute("events",{}).get("ok",false),"ambiguous physical expiration fails closed")
	world.item_instances.locked.record.erase("expiration"); world.item_instances.locked.source_reward_quantity = 5
	check(runtime.context().has("ownership_error") and not runtime.execute("events",{}).get("ok",false),"physical quantity exceeding bag refuses transaction")
	check(Runtime.native_id({"source_item_class_id":100,"sourceId":"m523:item:101"}) == 0,"conflicting native IDs rejected")
	world.item_instances.locked.source_reward_quantity = 4; world.item_instances.locked.record.sourceId = "m523:item:101"
	check(runtime.context().has("ownership_error") and not runtime.execute("events",{}).get("ok",false),"conflicting native physical record cannot become catalog-name stack")
	check(Runtime.native_id({"source_item_class_id":100.5,"sourceId":"m523:item:100"}) == 0,"fractional native ID rejected")
	check(Runtime.native_id({"source_item_class_id":100,"sourceId":"m523:item:100:bless:2"}) == 100,"explicit native bless variant preserves ID")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	check(runtime.check_load({}).is_empty(),"legacy save without entire namespace initializes complete fresh domains")
	var malformed: Dictionary = runtime.fresh()
	malformed.domains.erase("events")
	check(not runtime.validate(malformed).is_empty(),"missing events subsection rejected instead of resetting claims RNG")
	malformed = runtime.fresh(); malformed.domains.erase("jade_grail")
	var preserved_live: Dictionary = runtime.state.duplicate(true)
	runtime.restore({"unconfirmed523":malformed})
	check(runtime.save_blocked and runtime.state == preserved_live,"missing jade subsection protects existing live state without reset")
	runtime.restore({"unconfirmed523":runtime.fresh()})
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(runtime.fresh()))
	runtime.source.available = false
	runtime.restore({"unconfirmed523":roundtrip})
	check(not runtime.save_blocked and runtime._empty_progress(runtime.state),"JSON numeric roundtrip of fresh progress keeps missing-pack ordinary saves available")
	var added_progress: Dictionary = roundtrip.duplicate(true)
	added_progress.domains.events.claims.claim = true
	runtime.restore({"unconfirmed523":added_progress})
	check(runtime.save_blocked,"numeric-safe default comparison still protects genuine source progress")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	var snapshot: Dictionary = runtime.snapshot()
	check(int(snapshot.domains.jade_grail.latest_at) == runtime.now(),"ordinary snapshot observes clock without context recursion")
	runtime.test_now -= 1
	check(int(runtime.snapshot().domains.jade_grail.latest_at) == int(snapshot.domains.jade_grail.latest_at),"ordinary snapshot never moves observed clock backward")
	runtime.state.domains.events.claims.progress = true
	var progress: Dictionary = runtime.state.duplicate(true)
	runtime.source.available = false
	runtime.restore({"unconfirmed523":progress})
	check(runtime.save_blocked and runtime.state == progress,"missing source preserves complete domain payload and blocks save")
	runtime.source.available = true
	check(not runtime.execute("events",{}).get("ok",false),"install availability alone cannot bypass protected reload")
	runtime.restore({"unconfirmed523":progress})
	check(not runtime.save_blocked,"source restored plus explicit reload validates preserved progress")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	runtime.rebuild()
	check(is_equal_approx(runtime.bonus("ac:flat"),-1.0) and is_equal_approx(float(runtime.stat_record().get("def",0)),1.0),"jade source positive armor maps once to negative canonical AC then positive defense")
	runtime.state.bonus_rewards = [{"id":99,"expires_at":runtime.now()+10,"pass_id":1,"source_reward_id":50,"receipt_id":"1:50:99"}]
	runtime.rebuild()
	check(is_equal_approx(runtime.bonus("ac:flat"),-3.0) and is_equal_approx(runtime.bonus("experience_bonus:percent"),5.0),"earned bonus uses canonical source helper colon keys without second AC negation")
	var cache_before: int = world.cache_invalidations
	runtime.test_now += 10; runtime.advance_time()
	check(world.cache_invalidations > cache_before,"bonus expiry invalidates equipped-record stat cache")
	check(is_equal_approx(runtime.bonus("ac:flat"),-1.0),"earned bonus expires exactly at cutoff")
	runtime.test_now -= 5; runtime.advance_time()
	check(is_equal_approx(runtime.bonus("ac:flat"),-1.0),"expired earned bonus cannot reactivate after clock rollback")
	var next: Dictionary = runtime.state.duplicate(true)
	var staged: Dictionary = {}
	var bonus: Dictionary = {"kind":"bonus","id":99,"amount":1,"expires_at":runtime.now()+10,"pass_id":1,"source_reward_id":50}
	check(not runtime._reward(bonus,staged,next,runtime.context()).is_empty(),"stable bonus receipt cannot be earned twice")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	runtime.record_event("kill",{"event_id":"monster:life1","source_id":42,"player_credit":true})
	runtime.record_event("kill",{"event_id":"monster:life1","source_id":42,"player_credit":true})
	runtime.record_event("kill",{"event_id":"monster:life2","source_id":42,"player_credit":false})
	check(int(runtime.state.event_counters.get("kill",0)) == 1 and int(runtime.state.event_counters.get("kill:42",0)) == 1,"real credited kill occurrence counted once")
	var saved: Dictionary = runtime.snapshot()
	runtime.restore({"unconfirmed523":saved})
	runtime.record_event("kill",{"event_id":"monster:life1","source_id":42,"player_credit":true})
	check(int(runtime.state.event_counters.kill) == 1,"event receipts dedupe after reload")
	check(runtime.domains.events.received_events.size() == 1,"deduped host occurrence reaches pass event adapter once")
	var cold: Dictionary = fixture()
	cold.runtime.restore({"unconfirmed523":saved})
	cold.runtime.record_event("kill",{"event_id":"monster:life1","source_id":42,"player_credit":true})
	check(int(cold.runtime.state.event_counters.kill) == 2,"cold-process instance ID reuse earns a distinct session occurrence")
	cold.world.free()
	world.catalog.unrelated = {"source_item_class_id":101,"sourceId":"m523:item:101"}; world.inventory.unrelated = 1
	check(not runtime.try_use("unrelated"),"unrelated native item remains with ordinary item flow")
	check(runtime.try_use("native stack") and world.hud.opened == "events","known source adapter category opens correct UI")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	runtime.domains.challenge = Challenge.new()
	runtime.state.domains.challenge = runtime.domains.challenge.initial_state()
	var tick_revision: int = int(runtime.state.revision)
	runtime.advance_time(); runtime.advance_time()
	check(int(runtime.state.domains.challenge.ticks) == 1 and runtime.domains.challenge.received_events[0].alive,"live survival tick includes real alive state and dedupes same second")
	check(int(runtime.state.revision) == tick_revision and runtime.state.event_counters.is_empty(),"survival observation does not stale confirmations or add top counters")
	runtime.snapshot()
	check(int(runtime.state.domains.challenge.ticks) == 1,"save snapshot cannot create offline survival observations")
	world.hp = 0; runtime.test_now += 1; runtime.advance_time()
	check(not runtime.domains.challenge.received_events[1].alive,"dead player observation reaches challenge consumer")
	runtime.record_event("map_change",{"event_id":"map1","map_id":"other"})
	check(runtime.state.domains.challenge.active.failed and runtime.domains.challenge.received_events[2].kind == "map_change","map-change event reaches active challenge")
	runtime.totals["damage_reduction_ignore:flat"] = 2.0
	check(runtime.catalog_bonus("damage_reduction_ignore") == 2,"existing catalog damage path receives canonical flat ignore")
	runtime.domains.jade_grail.percent_ignore = true
	runtime.rebuild()
	check(is_zero_approx(runtime.bonus("ignore_melee_damage_reduction:percent")) and not runtime.effect_details.effects[0].applied and runtime.effect_details.unsupported[0].reason == "unsupported_combat_consumer" and int(runtime.effect_details.unsupported[0].raw_value) == 10000,"unconsumed percentage ignore retains source evidence and explicit unsupported flag")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	var view = View.new()
	root.add_child(view)
	view.runtime = runtime
	view.section = "events"
	view._confirm({"detail":"fixture"},{"label":"confirm"},{},"events")
	view.section = "jade_grail"
	check(world.hud.callback.is_valid(),"confirmation callback captured")
	world.hud.callback.call(1)
	check(world.save_calls == 1 and int(runtime.state.domains.events.rng) == 2,"actual HUD count argument and tab switch keep displayed transaction domain")
	view.free(); world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	view = View.new(); root.add_child(view); view.configure(runtime)
	var refresh_found: bool = false
	for control: Node in view.get_child(0).get_children():
		if control is Button and control.text == "새로고침": refresh_found = true
	check(refresh_found,"manual refresh toolbar action available")
	view._choose({"detail":"choice"},{"request":{},"required_choices":[{"count":1,"options":[{"label":"a","value":1},{"label":"b","value":2}]}]},"events")
	var list: ItemList
	for control: Node in view.choice_panel.get_children():
		if control is ItemList: list = control
	list.select(1)
	view.refresh(true)
	check(is_instance_valid(list) and list.get_selected_items() == PackedInt32Array([1]),"explicit goal refresh preserves active reward selection")
	view.free(); world.free()

	var presentation: Array = [{"id":"inactive","actions":[]},{"id":"disabled","actions":[{"disabled":true}]},{"id":"active_a","actions":[{"label":"use"}]},{"id":"active_b","actions":[{"disabled":false}]}]
	var ordered: Array = View.usable_first(presentation)
	check(ordered.map(func(row: Dictionary): return row.id) == ["active_a","active_b","inactive","disabled"],"enabled-action rows display first with stable order in both groups")
	check(ordered.size() == presentation.size() and presentation[0].id == "inactive","display priority retains every row and leaves source rows untouched")
	if failures.is_empty(): print("UNCONFIRMED523_HOST_OK: %d assertions" % checks); quit(0)
	else: printerr("UNCONFIRMED523_HOST_FAILED: " + ", ".join(failures)); quit(1)
