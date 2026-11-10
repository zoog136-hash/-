extends SceneTree
const Runtime = preload("res://scripts/unconfirmed523/runtime.gd")
## Backend/owner contracts only. Historical custom-form widget assertions remain
## in tests/audits/unconfirmed523_custom_form_host_test.gd and are not imported.
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
class Hud extends RefCounted:
	func refresh_inventory(_value: Dictionary) -> void: pass
	func show_message(_value: String) -> void: pass
	func append_log(_value: String) -> void: pass
class HeldMaterialHost extends RefCounted:
	func material(_value: Dictionary) -> bool: return false
class Growth extends RefCounted:
	var source523 = HeldMaterialHost.new()
class Provider extends RefCounted:
	func resolve(_value: Dictionary) -> Dictionary: return {}
	func supported_held(_world: Node) -> Dictionary: return {}
class Deferred extends RefCounted:
	func cancel() -> void: pass
class Host extends Node:
	const BASE508 = preload("res://scripts/lineagem_base508.gd")
	const EXP_PROGRESSION = preload("res://scripts/experience_progression.gd")
	var hp: int = 100
	var max_hp: int = 100
	var mp: int = 100
	var max_mp: int = 100
	var attack_power: int = 10
	var defense: int = 0
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
	var quest_service = preload("res://scripts/quests/quest_service.gd").new()
	var quest_auto = preload("res://scripts/quests/quest_auto_runner.gd").new()
	var item_db: Array = []
	var catalog_db: Dictionary = {}
	var loot_catalog: Dictionary = {"by_name":{}}
	var growth = Growth.new()
	var quest_item_provider = Provider.new()
	var deferred_save = Deferred.new()
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
	func _item_locked(label: String, uid: String = "") -> bool:
		return bool(ui_preferences.item_locks.get(label,false)) or bool(ui_preferences.item_locks.get(uid,false)) or bool(item_instances.get(uid,{}).get("locked",false))
	func _save_game(_quiet: bool, staged: Dictionary) -> Error:
		if runtime_service != null: runtime_service.snapshot()
		save_calls += 1
		last_staged = staged.duplicate(true)
		if staged.has("level") and (not staged.has("quest_state") or not quest_service.validate_saved_state(staged.quest_state).is_empty()): return ERR_INVALID_DATA
		if save_result == OK: disk = staged.duplicate(true)
		return save_result
	func _update_hud() -> void: pass
	func _refresh_inventory_hud() -> void: pass
	func _refresh_combat_hud() -> void: pass
	func save_path() -> String: return "user://host-source-issued-quest.json"
	func _check_level_up(_quiet: bool) -> void:
		# This bounded producer chain gives nine EXP, below the unchanged curve.
		assert(experience < exp_need)
	func _invalidate_equipment_static() -> void: cache_invalidations += 1
class Source extends RefCounted:
	var available: bool = true
	var pass_active: bool = true
	var server_allowed: bool = true
	var pass_end: int = 0
	var extra_leaf: bool = false
	var item_cutoff: int = 0
	var last_error: String = "fixture source unavailable"
	func ready() -> bool: return available
	func rows(table: String) -> Array:
		if table == "CurrencyUnitClass": return [{"ID":1,"CurrencyID":9,"UnitID":4,"ClassID":100,"ForGive":false,"ConsumePriority":0},{"ID":2,"CurrencyID":9,"UnitID":4,"ClassID":101,"ForGive":true,"ConsumePriority":0}]
		if table == "QuestReward": return [{"QuestID":77,"RewardID":500},{"QuestID":77,"RewardID":1000},{"QuestID":77,"RewardID":1001}]
		if table == "ItemBonus": return [{"ItemClassID":400,"BonusID":4000},{"ItemClassID":401,"BonusID":4001}]
		return []
	func row(table: String,id: int) -> Dictionary:
		if table == "ItemClass" and id in [100,101,200,300]: return {"ID":id,"Name":"fixture " + str(id),"CategoryID":78 if id == 100 else 10291 if id == 300 else 10,"MaxStackAmount":1 if id == 200 else 999999,"GradeID":3}
		if table == "ItemClass" and id in [400,401]: return {"ID":id,"Name":"Life fixture","MaxStackAmount":1 if id == 400 else 3,"GradeID":3}
		if table == "Bonus" and id in [4000,4001]: return {"ID":id,"BonusTypeID":422,"Value":86400 if id == 4000 else 259200}
		if table == "Bonus": return {"ID":id}
		if table == "BonusType" and id == 422: return {"ID":422,"Name":"Life","UnitID":17}
		if table == "Reward" and id == 500: return {"ID":500,"RewardTypeID":172,"RewardClassID":724,"Amount":60}
		if table == "Reward" and id == 1000: return {"ID":1000,"RewardTypeID":2,"RewardClassID":100,"Amount":4,"ItemBlessCodeID":1}
		if table == "Reward" and id == 1001: return {"ID":1001,"RewardTypeID":2,"RewardClassID":101,"Amount":3,"ItemBlessCodeID":2}
		if table == "PassSystem" and id == 724: return {"ID":724,"PassSystemTypeID":12,"IsActive":pass_active,"ServerLimitSetID":1,"SeasonEndDateTimeID":1 if pass_end > 0 else 0}
		return {}
	func region_allowed(_id: int,_ctx: Dictionary) -> bool: return server_allowed
	func timestamp(_id: int,_ctx: Dictionary) -> int: return pass_end
	func resolve_reward(_id: int,_ctx: Dictionary) -> Dictionary:
		var rewards: Array = [{"kind":"pass_exp","id":724,"amount":60}]
		if extra_leaf: rewards.append({"kind":"unsupported","id":1,"amount":1})
		return {"ok":true,"rewards":rewards}
	func item_eligibility(id: int,ctx: Dictionary) -> Dictionary:
		if id == 200 and item_cutoff > 0 and int(ctx.get("now",0)) >= item_cutoff: return {"ok":false,"error":"item_expired"}
		return {"ok":true}
	func bonus_stats(_ids: Array,_context: Dictionary) -> Dictionary: return {"stats":{"ac:flat":-2.0,"experience_bonus:percent":5.0}}
class Domain extends RefCounted:
	func view(_ctx: Dictionary,_state: Dictionary) -> Dictionary: return {"title":"fixture","notes":[],"rows":[]}
	var reward_values: Array = [{"kind":"item","id":200,"amount":2},{"kind":"experience","id":1,"amount":600}]
	var received_events: Array = []
	var cost_values: Array = [{"kind":"item","id":100,"amount":2},{"kind":"currency","id":1,"amount":10}]
	func initial_state() -> Dictionary: return {"rng":1,"claims":{},"passes":{}}
	func validate_state(value: Variant) -> String: return "" if value is Dictionary and value.has("rng") else "bad mock state"
	func propose(_request: Dictionary,_context: Dictionary, state: Dictionary) -> Dictionary:
		if state.claims.has("claim"): return {"ok":false,"error":"already claimed"}
		var next: Dictionary = state.duplicate(true)
		next.rng += 1
		next.claims.claim = true
		return {"ok":true,"state":next,"costs":cost_values.duplicate(true),"rewards":reward_values.duplicate(true)}
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
class FinalDomain extends Domain:
	func initial_state() -> Dictionary:
		var result: Dictionary = super.initial_state()
		result.final_progress = {}
		return result
class Jade extends RefCounted:
	func view(_ctx: Dictionary,_state: Dictionary) -> Dictionary: return {"title":"fixture","notes":[],"rows":[]}
	var stack_set_thresholds: bool = true
	var protection_dispatch: Dictionary = {1:54252,14:66574}
	var percent_ignore: bool = false
	var only_owned: bool = false
	var source_cutoff: int = 0
	func initial_state() -> Dictionary: return {"version":1,"latest_at":0,"jade":{}}
	func validate_state(_value: Variant) -> String: return ""
	func is_grail_item(id: int) -> bool: return id == 200
	func bonuses(ctx: Dictionary,_state: Dictionary) -> Dictionary:
		var armor: float = 1.0
		if only_owned and (int(ctx.owned.get("200",0)) == 0 or (source_cutoff > 0 and int(ctx.now) >= source_cutoff)): armor = 0
		var result: Dictionary = {"stats":{"armor_class":armor},"conditional_stats":{"undead":{"undead_additional_max_damage":5},"pvp":{"pvp_damage_reduction_pct":20,"pvp_damage_reduction_ignore_pct":2}},"effects":[],"unsupported":[]}
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

func held_fixture(world: Host, runtime, second: bool = false) -> void:
	var quest_id: String = "m523:quest:77"
	var rewards: Array = []
	world.inventory.clear()
	world.item_instances.clear()
	for id: int in ([100,101] if second else [100]):
		var reward_id: int = 1000 if id == 100 else 1001
		var quantity: int = 4 if id == 100 else 3
		var bless: int = 1 if id == 100 else 2
		var original: Dictionary = runtime.source.row("ItemClass",id)
		var label: String = "[원본 보상] "+str(original.Name)
		var reward: Dictionary = {"ID":reward_id,"type_name":"Item","RewardClassID":id,"Amount":quantity,"ItemBlessCodeID":bless,"RewardEnhancementTypeID":1,"ClanOnly":false,"UseImmediately":false,"source_item":original.duplicate(true)}
		rewards.append(reward)
		var record: Dictionary = {"name":label,"source":"lineagem_patch523","source_snapshot":"patch523","source_pending_use":true,"source_item_class_id":id,"sourceId":"m523:item:"+str(id),"source_original_item":original.duplicate(true),"source_bless_code_id":bless,"source_reward_id":reward_id,"source_use_immediately":false}
		world.inventory[label] = quantity
		world.item_instances["proof_stack" if id == 100 else "proof_second"] = {"name":label,"level":0,"source_reward_quantity":quantity,"record":record,"quest_reward_receipt":{"schema":1,"quest_id":quest_id,"reward_id":reward_id,"item_class_id":id,"bless_code_id":bless,"source_sha256":Runtime.Source.SOURCE_SHA256,"quantity":quantity}}
	world.quest_service.index[quest_id] = {"blockers":[],"excluded_reasons":[],"source_rewards":rewards}
	world.quest_service.claimed[quest_id] = true
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
	var unbound_before: Array = [world.inventory.duplicate(true),world.item_instances.duplicate(true),world.gold,runtime.state.duplicate(true),world.ain_service.export_state(),world.disk.duplicate(true),world.save_calls]
	var absent: Dictionary = runtime.request_presentation("events")
	check(not absent.get("ok",false) and absent.get("code") == "presentation_unavailable","missing original UI adapter reports explicit unavailable result")
	check(runtime.try_use("native stack"),"recognized source item is handled without original UI so ordinary item flow cannot consume it")
	check([world.inventory,world.item_instances,world.gold,runtime.state,world.ain_service.export_state(),world.disk,world.save_calls] == unbound_before,"unbound recognized-item request preserves owned items wallet progression RNG Ain disk and write count")
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
	check(is_equal_approx(runtime.bonus("ignore_melee_damage_reduction:percent"),1.0) and int(runtime.effect_details.effects[0].raw_value) == 10000 and runtime.effect_details.combat_policy.percent == "percentage_points_estimate","target consumer retains raw percent ignore and labels local formula estimate")
	world.free()

	_presentation_boundary()
	_followup_ports()
	_staged_owner_events()
	if failures.is_empty(): print("UNCONFIRMED523_HOST_OK: %d assertions" % checks); quit(0)
	else: printerr("UNCONFIRMED523_HOST_FAILED: " + ", ".join(failures)); quit(1)

func _followup_ports() -> void:
	var f: Dictionary = fixture()
	var runtime = f.runtime
	var world = f.world
	runtime.domains.jade_grail.percent_ignore = true
	runtime.rebuild()
	check(runtime.combat_context("melee",{}).undead_max_damage == 0 and runtime.combat_context("melee",{}).pvp_reduction_percent == 0,"scoped grail bonuses never become ordinary PvE effects")
	check(runtime.combat_context("melee",{"undead":true}).undead_max_damage == 5 and runtime.combat_context("magic",{"undead":true}).undead_max_damage == 0,"source undead maximum uses explicit target and physical attack policy")
	var hit: Dictionary = {"pvp":true,"percent_reduction":10.0,"flat_reduction":20,"critical":true}
	var adjusted: Dictionary = runtime.outgoing_context("melee",hit)
	check(adjusted.percent_reduction == 7.0 and adjusted.source523_percent_ignore == 3.0 and hit.percent_reduction == 10.0 and adjusted.flat_reduction == 20,"typed and PvP ignore share existing percent budget without mutating context or flat restoration")
	check(runtime.outgoing_context("ranged",{"percent_reduction":10.0}).percent_reduction == 10.0 and runtime.outgoing_context("melee",{"percent_reduction":0.5}).percent_reduction == 0.0,"ignore respects attack kind and observed reduction budget")
	check(runtime.incoming_damage(100,"melee",{}) == 100 and runtime.incoming_damage(100,"melee",{"pvp":true}) == 80 and runtime.incoming_damage(0,"melee",{"pvp":true}) == 0,"incoming source reduction requires real PvP and preserves zero damage")
	check(runtime.apply_policy_config({"policy":{"conditional_percent_mode":"disabled","undead_damage_mode":"disabled"}}).ok and runtime.outgoing_context("melee",hit).percent_reduction == 10.0 and runtime.combat_context("melee",{"undead":true}).undead_max_damage == 0,"adjustable estimate policies can disable both consumers without altering source rows")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	held_fixture(world,runtime)
	var proof_before: Dictionary = world.item_instances.proof_stack.quest_reward_receipt.duplicate(true)
	var staged: Dictionary = runtime._stage_world()
	var error: String = runtime._cost({"kind":"item","id":100,"amount":1,"instance_id":"proof_stack","expected_quantity":4},staged,runtime.context())
	check(error.is_empty() and staged.item_instances.proof_stack.source_reward_quantity == 3 and staged.item_instances.proof_stack.quest_reward_receipt == proof_before and world.item_instances.proof_stack.source_reward_quantity == 4,"exact owned consumption stages remaining stack and preserves immutable issued proof and live state")
	check(staged.quest_state.item_grants["m523:quest:77"][0].used_quantity == 1 and world.quest_service.item_grants.is_empty(),"actual quest owner stages held-use ledger without applying it before save")
	check(not runtime._cost({"kind":"item","id":100,"amount":1,"instance_id":"proof_stack","expected_quantity":4},staged,runtime.context()).is_empty(),"same physical unit snapshot cannot be debited twice")
	check(not runtime._cost({"kind":"item","id":100,"amount":1,"instance_id":"missing"},runtime._stage_world(),runtime.context()).is_empty(),"instance-bound debit cannot fall through to another stack")
	world.item_instances.proof_stack.locked = true
	check(not runtime._cost({"kind":"item","id":100,"amount":1,"instance_id":"proof_stack"},runtime._stage_world(),runtime.context()).is_empty(),"exact instance costs retain lock protection")
	world.item_instances.proof_stack.locked = false
	world.item_instances.proof_stack.quest_reward_receipt.quantity = 3
	check(runtime.context().has("ownership_error") and not runtime.execute("events",{}).ok and world.save_calls == 0,"remaining greater than issued proof fails before any write")
	world.item_instances.proof_stack.quest_reward_receipt.quantity = 4
	world.item_instances.proof_stack.quest_reward_receipt.bless_code_id = 2
	check(runtime.context().has("ownership_error"),"receipt blessing is matched to actual source physical record")
	world.free()
	_owned_quest_transactions()

	f = fixture(); runtime = f.runtime; world = f.world
	var proof: Dictionary = {"schema":1,"quest_id":77,"reward_id":500,"source_sha256":Runtime.Source.SOURCE_SHA256,"claim_id":"upstream:77:local-day:once"}
	var initial: Dictionary = runtime.state.duplicate(true)
	var prepared: Dictionary = runtime.prepare_pass_reward(proof)
	check(prepared.ok and runtime.state == initial and world.save_calls == 0 and int(prepared.staged.unconfirmed523.domains.events.passes["724"].experience) == 60,"pass reward preparation resolves exact source target without live mutation or write")
	prepared.staged.unconfirmed523.domains.events.passes["724"].experience = 999
	var beginning: Dictionary = runtime.begin_prepared_commit(prepared.plan_id)
	check(beginning.ok and beginning.staged.keys() == ["unconfirmed523"] and int(beginning.staged.unconfirmed523.domains.events.passes["724"].experience) == 60 and runtime.busy,"prepared preview mutation cannot alter opaque plan and pass patch owns only its namespace")
	beginning.staged["upstream_claim_fixture"] = {"claimed":true}
	var write_result: Error = world._save_game(true,beginning.staged)
	var committed: Dictionary = runtime.finish_prepared_commit(prepared.plan_id,write_result,beginning.staged)
	check(committed.ok and world.save_calls == 1 and world.disk.upstream_claim_fixture.claimed and int(runtime.context().pass_exp["724"]) == 60,"two-phase port commits source pass XP and caller-staged claim in one writer payload")
	check(not runtime.prepare_pass_reward(proof).ok and not runtime.begin_prepared_commit(prepared.plan_id).ok,"durable namespaced source grant and single-use plan reject duplicate claim")
	for i: int in range(8200): runtime.state.event_receipts["old:%d" % i] = true
	runtime.record_event("pickup",{"event_id":"after_many_kills","amount":1})
	check(runtime.state.event_receipts.has(prepared.receipt_id),"pass grant dedup receipt outlives bounded live event replay receipts")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	prepared = runtime.prepare_pass_reward(proof)
	world.gold += 1
	check(not runtime.begin_prepared_commit(prepared.plan_id).ok and world.save_calls == 0,"prepared source grant becomes stale after ownership or funds change")
	world.gold -= 1
	check(runtime.cancel_prepared(prepared.plan_id) and not runtime.begin_prepared_commit(prepared.plan_id).ok,"cancelled prepared grant leaves no claim or consumption")
	runtime.source.extra_leaf = true
	check(not runtime.prepare_pass_reward(proof).ok and runtime.state == runtime.fresh() and world.save_calls == 0,"unsupported composite leaf fails all staged pass state before write")
	runtime.source.extra_leaf = false
	runtime.source.pass_active = false
	check(not runtime.prepare_pass_reward(proof).ok,"direct pass port preserves source active flag")
	runtime.source.pass_active = true; runtime.source.server_allowed = false
	check(not runtime.prepare_pass_reward(proof).ok,"direct pass port preserves source server limit")
	runtime.source.server_allowed = true; runtime.source.pass_end = runtime.now()
	check(not runtime.prepare_pass_reward(proof).ok,"direct pass port enforces season expiry at boundary")
	runtime.source.pass_end = 0
	var bad: Dictionary = proof.duplicate(true); bad.source_sha256 = "wrong"
	check(not runtime.prepare_pass_reward(bad).ok,"source grant proof requires exact original archive SHA")
	bad = proof.duplicate(true); bad.quest_id = 78
	check(not runtime.prepare_pass_reward(bad).ok,"source grant proof must match raw QuestReward edge")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	prepared = runtime.prepare_pass_reward(proof)
	beginning = runtime.begin_prepared_commit(prepared.plan_id)
	initial = runtime.state.duplicate(true)
	world.save_result = ERR_CANT_CREATE
	write_result = world._save_game(true,beginning.staged)
	check(not runtime.finish_prepared_commit(prepared.plan_id,write_result,beginning.staged).ok and runtime.save_blocked and runtime.state == initial and world.gold == 1000 and world.disk.is_empty(),"failed composite writer preserves live progression funds RNG and blocks uncertain retry")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	prepared = runtime.prepare_pass_reward(proof)
	beginning = runtime.begin_prepared_commit(prepared.plan_id)
	beginning.staged.unconfirmed523.domains.events.passes["724"].experience = 600
	check(not runtime.finish_prepared_commit(prepared.plan_id,OK,beginning.staged).ok and runtime.save_blocked and runtime.state == runtime.fresh(),"mismatched published composite payload blocks live application")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	prepared = runtime.prepare_pass_reward(proof)
	beginning = runtime.begin_prepared_commit(prepared.plan_id)
	runtime.record_event("pickup",{"event_id":"interleaved_authoritative_event","amount":1})
	var interleaved: Dictionary = runtime.state.duplicate(true)
	check(not runtime.finish_prepared_commit(prepared.plan_id,OK,beginning.staged).ok and runtime.save_blocked and runtime.state == interleaved and int(runtime.state.event_counters.pickup) == 1,"yield/interleaved live event cannot be overwritten by a prepared grant and forces uncertain-save protection")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	staged = runtime._stage_world()
	check(runtime.stage_item(staged,400,2).is_empty() and staged.item_instances.size() == 2,"source nonstack Life grants create independent exact physical copies")
	var issued: int = runtime.now()
	for physical: Dictionary in staged.item_instances.values():
		check(int(physical.issued_at) == issued and int(physical.expires_at) == issued+86400 and int(physical.record.source_life_seconds) == 86400 and physical.record.expires_at == physical.expires_at,"new Life grant preserves exact source seconds and acquisition provenance on physical and record")
	check(runtime.stage_item(staged,401,4).is_empty() and staged.item_instances.size() == 4,"native stack maximum splits timed grants without merging distinct physical expiry")
	runtime.test_now += 10
	check(runtime.stage_item(staged,401,1).is_empty() and staged.item_instances.size() == 5,"later Life grant receives a fresh physical identity rather than extending an earlier stack")
	var expiries: Dictionary = {}
	for physical: Dictionary in staged.item_instances.values():
		if Runtime.native_id(physical.record) == 401: expiries[int(physical.expires_at)] = true
	check(expiries.size() == 2,"distinct Life acquisition timestamps retain distinct expiries")
	world.inventory = staged.inventory; world.item_instances = staged.item_instances
	runtime.test_now = issued+86400
	check(int(runtime.context().owned.get("400",0)) == 0 and int(runtime.context().owned.get("401",0)) == 5,"physical Life expiry removes only due copies from usable ownership without deleting them")
	check(world.item_instances.size() == 5,"expiry preserves physical evidence and inventory ownership")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	world.inventory["grail"] = 1
	world.item_instances = {"grail":{"name":"grail","record":{"source_item_class_id":200,"sourceId":"m523:item:200"},"expires_at":runtime.now()+2}}
	runtime.domains.jade_grail.only_owned = true
	runtime.advance_time()
	var invalidations: int = world.cache_invalidations
	check(runtime.bonus("ac:flat") == -1,"owned physical grail applies before its timestamp cutoff")
	runtime.test_now += 1; runtime.advance_time()
	check(world.cache_invalidations == invalidations,"physical expiry observation does not rebuild while eligibility is unchanged")
	runtime.test_now += 1; runtime.advance_time()
	check(world.cache_invalidations == invalidations+1 and runtime.bonus("ac:flat") == 0 and world.item_instances.has("grail"),"physical grail cutoff rebuilds and invalidates cached stats without discarding owned record")
	runtime.test_now -= 1; runtime.advance_time()
	check(runtime.bonus("ac:flat") == 0 and runtime.context().now == runtime.effective_now(),"clock rollback cannot reactivate expired physical grail effects")
	world.item_instances.grail.erase("expires_at")
	runtime.source.item_cutoff = runtime.effective_now()+2
	runtime.domains.jade_grail.source_cutoff = runtime.source.item_cutoff
	runtime.test_now = runtime.effective_now()
	runtime.advance_time(); invalidations = world.cache_invalidations
	runtime.test_now += 2; runtime.advance_time()
	check(world.cache_invalidations == invalidations+1 and runtime.bonus("ac:flat") == 0,"owned source eligibility cutoff invalidates stats using bounded per-source checks")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	check(runtime.apply_policy_config({"policy":{"luckybag_final_scope":"source_item","luckybag_final_completion":"once","luckybag_final_rules":{"1991":{"uses":7,"completion":"cycle","scope":"source_item","final_rewards":"all"}}}}).ok,"strict final reward policy accepts explicit source pool rule")
	var policy_saved: Dictionary = runtime.policy.duplicate(true)
	check(not runtime.apply_policy_config({"policy":{"luckybag_final_rules":{"1991":{"uses":7,"unknown":true}}}}).ok and runtime.policy == policy_saved,"unknown final reward policy fields fail atomically")
	check(not runtime.apply_policy_config({"policy":{"luckybag_final_rules":{"1991":{"uses":0}}}}).ok and not runtime.apply_policy_config({"policy":{"luckybag_final_scope":"account"}}).ok,"invalid final reward threshold and unsupported history scope stay blocked")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	runtime.domains.events = FinalDomain.new()
	var legacy: Dictionary = runtime.fresh()
	legacy.domains.events.erase("final_progress")
	legacy = JSON.parse_string(JSON.stringify(legacy))
	var legacy_copy: Dictionary = legacy.duplicate(true)
	runtime.source.available = false
	runtime.restore({"unconfirmed523":legacy})
	check(not runtime.save_blocked and runtime.state == legacy_copy and not runtime.state.domains.events.has("final_progress"),"public empty pre-final-progress JSON save remains packless-compatible without rewriting owned progress")
	legacy.domains.events.claims.paid = true
	runtime.restore({"unconfirmed523":legacy})
	check(runtime.save_blocked and runtime.state == legacy,"real legacy claim progress remains protected when original pack is absent")
	legacy = legacy_copy.duplicate(true); legacy.domains.events.erase("claims")
	runtime.restore({"unconfirmed523":legacy})
	check(runtime.save_blocked,"optional empty final-progress normalization cannot mask other missing saved fields")
	world.free()

func _owned_quest_transactions() -> void:
	var f: Dictionary = fixture()
	var runtime = f.runtime
	var world: Host = f.world
	held_fixture(world,runtime,true)
	var original_state: Dictionary = world.quest_service.export_state()
	var issued: Dictionary = world.item_instances.proof_stack.quest_reward_receipt.duplicate(true)
	runtime.domains.events.cost_values = [{"kind":"item","id":100,"amount":1,"instance_id":"proof_stack"},{"kind":"item","id":101,"amount":1,"instance_id":"proof_second"},{"kind":"item","id":100,"amount":1,"instance_id":"proof_stack"}]
	runtime.domains.events.reward_values = [{"kind":"pass_exp","id":724,"amount":60}]
	var result: Dictionary = runtime.execute("events",{})
	var receipts: Array = world.quest_service.item_grants.get("m523:quest:77",[])
	check(result.ok and world.save_calls == 1 and world.item_instances.proof_stack.source_reward_quantity == 2 and world.item_instances.proof_second.source_reward_quantity == 2,"multiple exact owned costs and repeated same-unit debit compose in one save")
	check(receipts.size() == 2 and int(receipts[0].used_quantity) == 2 and int(receipts[1].used_quantity) == 1 and world.disk.quest_state == world.quest_service.export_state(),"owner-produced use receipts compose without overwriting another reward ledger")
	check(world.item_instances.proof_stack.quest_reward_receipt == issued and world.quest_service.claimed == original_state.claimed and world.disk.quest_state.item_grants["m523:quest:77"][0].pack_sha256 == Runtime.Source.SOURCE_SHA256,"issued proof and claims remain immutable while verified consumer identity is persisted")
	var saved: Dictionary = world.disk.duplicate(true)
	world.quest_service.import_state(saved.quest_state)
	runtime.restore(saved)
	check(not runtime.context().has("ownership_error") and Runtime.QuestOwnership.proof(world,"proof_stack").ok,"current main owner accepts the remaining source stack after saved-state reload")
	var continuation: Dictionary = Runtime.QuestOwnership.prepare_debit(world,"proof_stack",1)
	var continued: Dictionary = Runtime.QuestOwnership.use_state(world,continuation,Runtime.Source.SOURCE_SHA256)
	check(continued.ok and int(continued.state.item_grants["m523:quest:77"][0].used_quantity) == 3,"same verified consumer can continue a saved partial use through the existing owner")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	held_fixture(world,runtime)
	runtime.domains.events.cost_values = [{"kind":"item","id":100,"amount":1,"instance_id":"proof_stack"}]
	runtime.domains.events.reward_values = [{"kind":"pass_exp","id":724,"amount":60}]
	world.save_result = ERR_CANT_CREATE
	original_state = world.quest_service.export_state()
	issued = world.item_instances.proof_stack.duplicate(true)
	result = runtime.execute("events",{})
	check(not result.ok and world.quest_service.export_state() == original_state and world.item_instances.proof_stack == issued and world.disk.is_empty() and runtime.save_blocked,"failed shared writer applies neither owner ledger debit nor pass reward and blocks uncertain retry")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	held_fixture(world,runtime)
	# Recreate a prior consumer's durable use through its owner, not a hand-made ledger.
	var prepared: Dictionary = Runtime.QuestOwnership.prepare_debit(world,"proof_stack",1)
	var used: Dictionary = Runtime.QuestOwnership.use_state(world,prepared,"a".repeat(64))
	world.inventory = prepared.override.inventory; world.item_instances = prepared.override.item_instances
	world.quest_service.import_state(used.state)
	runtime.domains.events.cost_values = [{"kind":"item","id":100,"amount":1,"instance_id":"proof_stack"}]
	original_state = world.quest_service.export_state()
	var crossed: Dictionary = runtime.execute("events",{})
	check(crossed.ok and world.save_calls == 1 and world.item_instances.proof_stack.source_reward_quantity == 2 and world.quest_service.item_grants["m523:quest:77"][0].pack_sha256 == "a".repeat(64) and runtime._held_consumption.is_empty(),"published shared ABI preserves the first consumer pack identity across a verified later owner")
	world.item_instances.proof_stack.quest_reward_receipt.quest_id = 77
	check(runtime.context().has("ownership_error"),"integer fixture quest IDs cannot impersonate current main canonical receipt identity")
	world.item_instances.proof_stack.quest_reward_receipt.quest_id = "m523:quest:77"
	world.quest_service.claimed.clear()
	check(runtime.context().has("ownership_error"),"raw reward edge without actual source owner's completed claim cannot authorize held consumption")
	world.free()

	f = fixture(); runtime = f.runtime; world = f.world
	held_fixture(world,runtime)
	var staged: Dictionary = runtime._stage_world()
	var error: String = runtime._cost({"kind":"item","id":100,"amount":1,"instance_id":"proof_stack"},staged,runtime.context())
	staged.unconfirmed523 = runtime.state.duplicate(true)
	world.ui_preferences.item_locks.proof_stack = true
	check(error.is_empty() and not runtime._publish(staged).ok and world.save_calls == 0 and world.quest_service.item_grants.is_empty() and world.item_instances.proof_stack.source_reward_quantity == 4,"owner quote is revalidated immediately before shared writer and stale lock applies no debit or receipt")
	world.free()

func _staged_owner_events() -> void:
	var f: Dictionary = fixture()
	var runtime = f.runtime
	var world: Host = f.world
	# Fishing was removed from the game: a fishing override earns nothing.
	check(runtime.observe_staged_owner({"fishing523":{"pending":{},"items":{}}}) == {"ok":true},"removed fishing never earns pass progress")
	world.free()
	var directory: String = OS.get_environment("TWILIGHT_523_SOURCE_DIR")
	if directory.is_empty(): print("HOST_SOURCE_EVENT_JOINS_NOT_RUN: set TWILIGHT_523_SOURCE_DIR and TWILIGHT_523_ALLOW_TEST_SOURCE=1")
	else: _actual_source_event_joins(directory)

func _goal_progress(runtime, candidate: Dictionary, type_id: int) -> int:
	var total: int = 0
	for progress: Dictionary in candidate.domains.events.get("quest_progress",{}).values():
		for goal_id: String in progress:
			if int(runtime.source.row("Goal",int(goal_id)).get("GoalTypeID",0)) == type_id: total += int(progress[goal_id])
	return total

func _actual_source_event_joins(directory: String) -> void:
	var f: Dictionary = fixture()
	var runtime = f.runtime
	var world: Host = f.world
	var original = Runtime.Source.new()
	check(original.configure_directory(directory).ok,"actual common523 source opens under explicit test gate for event joins")
	runtime.source = original
	runtime.domains = {"events":preload("res://scripts/unconfirmed523/events_domain.gd").new(),"challenge":preload("res://scripts/unconfirmed523/challenge_domain.gd").new()}
	for domain in runtime.domains.values(): domain.setup(original)
	runtime.state = runtime.fresh()
	world.ain_service.saved.blessing = 100
	var challenge_id: int = 0
	for raw: Dictionary in original.rows("Challenge"):
		if int(raw.get("EinhasadCost",0)) == 20 and runtime.domains.challenge.eligibility(int(raw.ID),runtime.context()).is_empty(): challenge_id = int(raw.ID); break
	check(challenge_id > 0,"actual active eligible Challenge retains source twenty blessing entry cost")
	var result: Dictionary = runtime.execute("challenge",{"op":"challenge_start","challenge_id":challenge_id,"local_policy":true})
	check(result.ok and world.ain_service.saved.blessing == 80 and world.disk.ainhasad_state.blessing == 80 and int(world.disk.unconfirmed523.event_counters.blessing_use) == 20 and _goal_progress(runtime,world.disk.unconfirmed523,10) > 0,"actual source Challenge blessing debit and goal10 progress commit in the same writer")
	check(int(runtime.state.revision) == 1 and world.save_calls == 1 and runtime.state.event_receipts.has("source_grant:unconfirmed523:blessing_use:1"),"blessing join neither saves twice nor synthesizes a World kill occurrence")
	world.free()
	var quest_pack: String = OS.get_environment("TWILIGHT_QUEST523_PACK")
	if quest_pack.is_empty(): print("HOST_GENUINE_QUEST_CONSUMPTION_NOT_RUN: set TWILIGHT_QUEST523_PACK to the verified existing projection ZIP")
	else: _genuine_source_ownership(original,quest_pack)

func _genuine_source_ownership(original, quest_pack: String) -> void:
	var f: Dictionary = fixture()
	var runtime = f.runtime
	var world: Host = f.world
	var source_quest = world.quest_service.source
	check(source_quest.install_zip(quest_pack).ok and source_quest.load_pack() and source_quest.document.source_sha256 == Runtime.Source.SOURCE_SHA256,"fixed-SHA public quest projection installs and loads the actual private source graph")
	for row: Dictionary in source_quest.quests:
		world.quest_service.quests.append(row)
		world.quest_service.index[str(row.id)] = row
	world.job_class = "사신"
	world.inventory.clear(); world.item_instances.clear()
	var completed: bool = world.quest_auto.complete(world,["m523:quest:79584","m523:quest:79594","m523:quest:79604"])
	check(completed and world.quest_service.claimed.get("m523:quest:79604",false) and world.experience == 9,"unchanged public Quest_auto_runner genuinely issues the source class94 prerequisite chain and its nine EXP")
	var physical_id: String = ""
	for id: String in world.item_instances:
		if int(world.item_instances[id].record.get("source_item_class_id",0)) == 313 and Runtime.QuestOwnership.proof(world,id).get("ok",false): physical_id = id; break
	check(not physical_id.is_empty(),"actual auto-issued ItemClass313 has the canonical source owner's grant proof")
	if physical_id.is_empty(): world.free(); return
	runtime.source = original
	var issued: Dictionary = world.item_instances[physical_id].quest_reward_receipt.duplicate(true)
	var original_claims: Dictionary = world.quest_service.claimed.duplicate(true)
	var before: int = int(world.item_instances[physical_id].source_reward_quantity)
	var staged: Dictionary = runtime._stage_world()
	var error: String = runtime._cost({"kind":"item","id":313,"amount":1,"instance_id":physical_id,"expected_quantity":before},staged,runtime.context())
	check(error.is_empty() and not runtime._held_consumption.get("use_authorized",true) and Runtime.QuestConsumption.matches_payload(world,runtime._held_consumption,staged),"runtime delegates a genuinely issued selected debit to the published ABI without effect authorization")
	var overwritten: Dictionary = staged.duplicate(true); overwritten.quest_state = world.quest_service.export_state()
	check(not Runtime.QuestConsumption.matches_payload(world,runtime._held_consumption,overwritten),"final old-ledger overwrite of a genuinely issued selected consumption is rejected")
	staged.unconfirmed523 = runtime.state.duplicate(true)
	runtime.busy = true
	var result: Dictionary = runtime._publish(staged)
	check(result.ok and world.item_instances[physical_id].source_reward_quantity == before-1 and world.item_instances[physical_id].quest_reward_receipt == issued and world.quest_service.claimed == original_claims,"one owner-layer QA write adopts physical remainder and source use ledger without regranting or changing claims")
	var use: Dictionary = world.quest_service.item_grants[issued.quest_id][0]
	check(use.used_quantity == 1 and use.quantity == issued.quantity and use.pack_sha256 == Runtime.Source.SOURCE_SHA256,"actual source-issued selected consumption retains original quantity and verified current consumer proof")
	print("HOST_GENUINE_QUEST_CONSUMPTION_OK: ownership-layer QA only; Item313 quest79604; no processing/effect completion claim")
	world.free()

func _presentation_boundary() -> void:
	var f: Dictionary = fixture()
	var runtime = f.runtime
	var world: Host = f.world
	var sections: Array[String] = []
	var adapter_response: Dictionary = {"ok":true,"opened":true,"details":{"owner":"test_adapter"}}
	var before: Array = [world.inventory.duplicate(true),world.item_instances.duplicate(true),world.gold,runtime.state.duplicate(true),world.save_calls]
	runtime.bind_presentation(func(section: String) -> Dictionary:
		sections.append(section)
		return adapter_response)
	var response: Dictionary = runtime.request_presentation("challenge")
	check(response.get("ok",false) and response.get("opened",false) and sections == ["challenge"],"bound presentation adapter receives the exact requested backend domain")
	response.details.owner = "caller_mutation"
	check(adapter_response.details.owner == "test_adapter","presentation response copy cannot mutate the bound owner's response")
	check(not runtime.request_presentation("unknown").get("ok",false) and sections == ["challenge"],"unknown presentation domain is rejected before invoking the adapter")
	check(runtime.try_use("native stack") and sections == ["challenge","events"],"recognized container routes to bound events adapter")
	world.catalog["native jade"] = {"source_item_class_id":300,"sourceId":"m523:item:300"}
	world.inventory["native jade"] = 1
	check(runtime.try_use("native jade") and sections == ["challenge","events","jade_grail"],"recognized jade category routes to bound jade_grail adapter")
	world.inventory.erase("native jade"); world.catalog.erase("native jade")
	check([world.inventory,world.item_instances,world.gold,runtime.state,world.save_calls] == before,"opening presentation adapter commits no backend transaction or source RNG")
	runtime.bind_presentation(func(_section: String): return true)
	check(not runtime.request_presentation("events").get("ok",false),"invalid adapter response cannot masquerade as a successful open")
	runtime.bind_presentation(Callable())
	check(runtime.request_presentation("events").get("code") == "presentation_unavailable" and runtime.try_use("native stack"),"explicit unbind restores unavailable boundary while retaining recognized-item ownership")
	check(not runtime.snapshot().has("presentation_adapter"),"presentation callable is not persisted in the source save namespace")
	check(world.save_calls == 0 and world.disk.is_empty(),"presentation binding requests and unbinding never write the shared save")
	world.free()
