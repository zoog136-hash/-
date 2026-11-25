extends SceneTree
## Exercises the real subslot updater through its existing actor/source_aura
## fields. Controlled readiness boundaries count reconfigure/match operations;
## this is not source admission, twelve-chain activation or render evidence.
const VIEW = preload("res://scripts/cards/native_doll_subslot_visual.gd")
const RUNTIME = preload("res://scripts/cards/option_awakening_runtime.gd")
const DOLL = preload("res://scripts/cards/native_doll_subslot.gd")
const RELIC = preload("res://scripts/cards/native_relic_subslot.gd")
const SLOT_DATA = preload("res://scripts/cards/patch523_slot_data.gd")
const COMBAT_INPUT = preload("res://scripts/cards/current523_option_combat_input.gd")
const READY = "compatible_native_anchor_unverified_M_placement_and_blend"
class Pose:
	extends RefCounted
	var state: String = "idle"
	var facing8: int = 2
	var sequence: int = 7
class Player:
	extends Node2D
	var original_source_manifest: String = ""
	var source_visual_context: Dictionary = {}
	var velocity: Vector2 = Vector2.ZERO
	var motion := Pose.new()
	var property_list_reads: int = 0
	func _get_property_list() -> Array[Dictionary]:
		property_list_reads += 1
		return []
class Eligibility:
	extends RefCounted
	var awake: bool = false
	var doll_calls: int = 0
	var relic_calls: int = 0
	func source_subslot_visual_awakened(_record: Dictionary) -> bool:
		doll_calls += 1
		return awake
	func source_relic_subslot_visual_awakened(_record: Dictionary) -> bool:
		relic_calls += 1
		return awake
class World:
	extends Node2D
	var hp: int = 100
	var player := Player.new()
	var option_awakening := Eligibility.new()
	var presentation_settings: Dictionary = {}
class Actor:
	extends Node2D
	var configure_result: bool = false
	var can_install: bool = true
	var installed_flag: bool = false
	var available_pin: String = "A"
	var selected_pin: String = ""
	var configure_calls: int = 0
	var match_calls: int = 0
	var clear_calls: int = 0
	var advance_calls: int = 0
	var supplied_key: String = ""
	var supplied_manifest: String = ""
	var supplied_context: Dictionary = {}
	func current523_source_required(_key: String) -> bool: return true
	func installed() -> bool: return installed_flag
	func clear() -> void:
		clear_calls += 1
		installed_flag = false
	func configure(key: String, manifest: String, context: Dictionary) -> bool:
		configure_calls += 1
		supplied_key = key
		supplied_manifest = manifest
		supplied_context = context.duplicate(true)
		selected_pin = available_pin
		installed_flag = configure_result and can_install
		return configure_result
	func current523_card_matches(_key: String, _context: Dictionary) -> bool:
		match_calls += 1
		return installed_flag and selected_pin == available_pin
	func current523_role_available(_role: String) -> bool: return false
	func advance_source(_delta: float, _state: String, _facing: int, _sequence: int, _active: bool) -> void:
		advance_calls += 1
class Visual:
	extends RefCounted
	var ready: bool = false
	func installed() -> bool: return ready
class Aura:
	extends Node2D
	var status: String = "inactive"
	var available: bool = false
	var visual := Visual.new()
	var configure_calls: int = 0
	var deactivate_calls: int = 0
	func configure(_category: String, _record: Dictionary, enabled: bool, _target: Node2D, _manifest: String, _settings: Dictionary) -> void:
		configure_calls += 1
		if not enabled:
			deactivate()
			return
		visual.ready = available
		status = READY if available else "source_pixels_pending"
	func deactivate() -> void:
		deactivate_calls += 1
		visual.ready = false
		status = "inactive"
		hide()

class SourceContext extends RefCounted:
	var reads: int = 0
	func source_server_context() -> Dictionary:
		reads += 1
		return {"source_snapshot":"patch523","ServiceRegionCode":"KR","WorldNo":1}

class SlotHost extends Node:
	var level: int = 95
	var active_skill_buffs: Dictionary = {}
	var card_collections := SourceContext.new()
	var card_draw_fusion := preload("res://scripts/card_draw_fusion.gd").new()
	var equipped_catalog: Dictionary = {}

var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SOURCE_SUBSLOT_RETRY_FAIL ",label)
# The baseline has no retry deadline. Guarded reflection lets exactly the same
# test complete with behavioral failures instead of accessing missing fields.
func deadline(view: Node, field: String, due: bool) -> void:
	for property: Dictionary in view.get_property_list():
		if property.name == field:
			view.set(field,0 if due else Time.get_ticks_msec()+1000000)
			return
func make_view(world: World, actor: Actor, aura: Aura) -> Node2D:
	var view: Node2D = VIEW.new()
	world.add_child(view)
	view.actor = actor
	view.source_aura = aura
	view.add_child(actor)
	view.add_child(aura)
	return view

func empty_slot_benchmark(runtime: RefCounted) -> void:
	var samples: Array[Array] = [[],[]]
	for pair: int in 8:
		for offset: int in 2:
			var side: int = (pair + offset) % 2
			var began: int = Time.get_ticks_usec()
			if side == 0:
				for frame: int in 2000:
					runtime.subslot_view(false)
					runtime.relic_subslot_view(false)
			else:
				for frame: int in 2000:
					runtime.active_subslot_identity()
					runtime.active_subslot_identity(true)
			var elapsed: int = Time.get_ticks_usec() - began
			if pair > 0: samples[side].append(elapsed)
	for side: Array in samples: side.sort()
	evidence["empty_slots_2000_updates_full_view_p50_usec"] = samples[0][3]
	evidence["empty_slots_2000_updates_active_only_p50_usec"] = samples[1][3]

func check_slot_eligibility() -> void:
	var host := SlotHost.new()
	var runtime := RUNTIME.new()
	runtime.world = host
	runtime.combat.configure(runtime)
	runtime.core.native_mode = true
	var before: Dictionary = runtime.progress.duplicate(true)
	check(runtime.active_subslot_identity().is_empty() and runtime.active_subslot_identity(true).is_empty() and host.card_collections.reads == 0,
		"empty slots skip source context lookup and do not change saved progress")
	check(runtime.progress == before and not runtime.subslot_view(false).active and not runtime.relic_subslot_view(false).active,
		"full UI views remain available for an empty slot")
	if "--subslot-bench" in OS.get_cmdline_user_args():
		for index: int in 32: host.active_skill_buffs[index] = {"remaining":30}
		empty_slot_benchmark(runtime)
		host.active_skill_buffs.clear()

	var old_doll: Array = [COMBAT_INPUT._identity_for_test,COMBAT_INPUT._data,COMBAT_INPUT._store]
	var old_relic: Array = [SLOT_DATA.pack,SLOT_DATA.problem,SLOT_DATA.relic,SLOT_DATA.relic_combat,SLOT_DATA._store]
	var doll: String = "source:m508:2:42"
	var main: String = "source:m508:2:43"
	var relic: String = "source:m523:98:44"
	var native: Dictionary = {"source_snapshot":"base508","server_limit_set_id":0}
	var origin: Dictionary = {"ID":42,"GradeID":3}
	var effect: Dictionary = {"type":{"Name":"InvokeOption"},"bonus":{"ID":1}}
	COMBAT_INPUT._identity_for_test = {"fixture":"slot-hot-path"}
	COMBAT_INPUT._store = null
	COMBAT_INPUT._data = {"ready":true,"source_input_identity":COMBAT_INPUT._identity_for_test,
		"subslot_buffs":{doll:{"card":origin,"effects":[effect]}}}
	var relic_row: Dictionary = {"ID":44,"GradeID":4,"BuffCardDeckID":98,"ServerLimitSetID":0}
	SLOT_DATA.pack = {"fixture":true}
	SLOT_DATA.problem = ""
	SLOT_DATA._store = null
	SLOT_DATA.relic = {"cards":{"98:44":{"card":relic_row,"subslot_buff":1,"effects":[]}}}
	SLOT_DATA.relic_combat = {"relic_subslot_buffs":{"98:44":{"card":relic_row,"effects":[effect]}}}
	runtime.core.catalog = {
		"마법인형":{doll:{"source_original":native}},
		"성물":{relic:{"source":"lineagem_patch523","sourceId":"m523:98:44","source_card_id":44,"source_deck_id":98,"source_grade_id":4}}}
	host.equipped_catalog = {"마법인형":{"source":"lineagem_base508","sourceId":"m508:2:43","source_card_id":43,
		"source_grade_id":2,"source_original":native}}
	host.card_draw_fusion.owned = {"마법인형":{doll:true,main:true},"성물":{relic:true}}
	runtime.progress[DOLL.FIELD] = doll
	runtime.progress[RELIC.FIELD] = relic
	check(runtime.active_subslot_identity().is_empty() and runtime.active_subslot_identity(true).is_empty(),"selected but locked slots remain inactive")
	host.active_skill_buffs = {"doll":{"source_snapshot":"base508","source_buff_class_id":91531},
		"relic":{"source_snapshot":"patch523","source_buff_class_id":RELIC.Unlock.BUFF}}
	check(runtime.active_subslot_identity() == doll and runtime.subslot_view(false).active,"owned, unlocked doll is still admitted")
	check(runtime.active_subslot_identity(true) == relic and runtime.relic_subslot_view(false).active,"legacy untimed relic is still admitted")
	var active: Dictionary = runtime.combat.active()
	check(active.has(doll) and active.has("relic_subslot11:"+relic),"combat uses the same admitted doll and relic rows")
	host.equipped_catalog["마법인형"].source_grade_id = 3
	check(runtime.active_subslot_identity().is_empty() and not runtime.subslot_view(false).active,"same-grade conflict suspends the doll immediately")
	runtime.progress[RUNTIME.RELIC_SUMMON_TIME] = {"schema":1,"item_class_id":365758,"identity":relic,"expires_utc":int(Time.get_unix_time_from_system())+60}
	check(runtime.active_subslot_identity(true) == relic,"matching future relic timer keeps the slot active")
	runtime.progress[RUNTIME.RELIC_SUMMON_TIME].expires_utc = 0
	check(runtime.active_subslot_identity(true).is_empty() and not runtime.relic_subslot_view(false).active,"expired relic loses eligibility in the next lookup")
	check(runtime.combat.active().is_empty(),"inactive secondary rows are removed from combat immediately")
	COMBAT_INPUT._identity_for_test = old_doll[0]
	COMBAT_INPUT._data = old_doll[1]
	COMBAT_INPUT._store = old_doll[2]
	SLOT_DATA.pack = old_relic[0]
	SLOT_DATA.problem = old_relic[1]
	SLOT_DATA.relic = old_relic[2]
	SLOT_DATA.relic_combat = old_relic[3]
	SLOT_DATA._store = old_relic[4]
	host.free()

func _initialize() -> void: call_deferred("run")
func run() -> void:
	check_slot_eligibility()
	var world := World.new()
	root.add_child(world)
	world.add_child(world.player)
	world.player.position = Vector2(100,200)
	var record: Dictionary = {"sourceId":"m523:2:42","source_snapshot":"patch523"}
	var actor := Actor.new()
	var aura := Aura.new()
	var view: Node2D = make_view(world,actor,aura)
	view.update_source(0.0,world,record)
	check(actor.configure_calls == 1 and view.status == "source_asset_pending" and not view.visible,"initial missing body stays pending and hidden")
	actor.configure_result = true
	deadline(view,"_next_source_check_msec",false)
	for frame: int in 30: view.update_source(0.0,world,record)
	check(actor.configure_calls == 1 and actor.match_calls == 0,"pending frames do not repeat configuration or settings checks")
	deadline(view,"_next_source_check_msec",true)
	view.update_source(0.0,world,record)
	check(actor.configure_calls == 2 and view.status == "source_native" and view.visible,"same identity retries when body becomes available")
	check(actor.supplied_key == "doll:m523:2:42" and actor.supplied_context == world.player.source_visual_context,"retry preserves exact card key and owner context")
	var configured: int = actor.configure_calls
	var cleared: int = actor.clear_calls
	var advanced: int = actor.advance_calls
	var property_reads: int = world.player.property_list_reads
	deadline(view,"_next_source_check_msec",false)
	for frame: int in 30: view.update_source(0.0,world,record)
	check(actor.configure_calls == configured and actor.match_calls == 0 and actor.clear_calls == cleared,"ready frames add no repeated reconfigure or match I/O")
	check(actor.advance_calls == advanced+30,"healthy body playback continues without resets")
	check(world.player.property_list_reads == property_reads,"ready playback never enumerates all player properties")
	deadline(view,"_next_source_check_msec",true)
	view.update_source(0.0,world,record)
	check(actor.match_calls == 1 and actor.configure_calls == configured and actor.clear_calls == cleared,"due matching bank check preserves running body")
	actor.available_pin = "B"
	deadline(view,"_next_source_check_msec",false)
	view.update_source(0.0,world,record)
	check(actor.configure_calls == configured,"unchanged context pin probing is throttled")
	deadline(view,"_next_source_check_msec",true)
	view.update_source(0.0,world,record)
	check(actor.selected_pin == "B" and actor.configure_calls == configured+1,"same-key bank pin change rebinds once when due")
	actor.installed_flag = false
	configured = actor.configure_calls
	deadline(view,"_next_source_check_msec",false)
	view.update_source(0.0,world,record)
	check(not view.visible and view.status == "source_asset_pending" and actor.configure_calls == configured,"lost installed body hides immediately without repeated loading")
	deadline(view,"_next_source_check_msec",true)
	view.update_source(0.0,world,record)
	check(actor.configure_calls == configured+1 and view.status == "source_native","lost body can recover at the same binding")
	configured = actor.configure_calls
	deadline(view,"_next_source_check_msec",false)
	world.player.source_visual_context = {"class_id":2}
	view.update_source(0.0,world,record)
	check(actor.configure_calls == configured+1 and actor.supplied_context == {"class_id":2},"changed owner context bypasses old retry cooldown")
	configured = actor.configure_calls
	world.player.original_source_manifest = "res://fixture-changed-manifest.json"
	view.update_source(0.0,world,record)
	check(actor.configure_calls == configured+1 and actor.supplied_manifest == world.player.original_source_manifest,"changed manifest is read immediately")
	view.clear()
	check(view.binding.is_empty() and view.aura_signature.is_empty() and view.status == "inactive" and not view.visible,"clear invalidates body and aura state")
	configured = actor.configure_calls
	view.update_source(0.0,world,record)
	check(actor.configure_calls == configured+1 and view.status == "source_native","clear permits immediate requested binding")
	world.hp = 0
	view.update_source(0.0,world,record)
	check(view.status == "inactive" and not view.visible and aura.status == "inactive","death immediately clears source attachments")
	world.hp = 100
	view.update_source(0.0,world,record)
	check(view.status == "source_native","existing request can resume after death clear")
	view.update_source(0.0,world,{})
	check(view.status == "inactive" and view.binding.is_empty(),"empty subslot clears its binding")
	cleared = actor.clear_calls
	view.update_source(0.0,world,{})
	check(actor.clear_calls == cleared,"already released body is not cleared again every frame")
	view.free()

	actor = Actor.new()
	actor.configure_result = true
	actor.can_install = false
	aura = Aura.new()
	view = make_view(world,actor,aura)
	view.update_source(0.0,world,record)
	check(view.status == "source_asset_pending" and not view.visible,"configure success without installed pixels is not ready")
	actor.can_install = true
	deadline(view,"_next_source_check_msec",true)
	view.update_source(0.0,world,record)
	check(actor.configure_calls == 2 and view.status == "source_native","incomplete successful configure retries later")
	view.free()

	actor = Actor.new()
	actor.configure_result = true
	aura = Aura.new()
	view = make_view(world,actor,aura)
	world.option_awakening.awake = true
	view.update_source(0.0,world,record)
	check(aura.configure_calls == 1 and aura.status == "source_pixels_pending" and view.aura_signature.is_empty(),"failed aura configure is not cached as successful")
	var aura_id: int = aura.get_instance_id()
	aura.available = true
	deadline(view,"_next_source_check_msec",false)
	deadline(view,"_next_aura_check_msec",false)
	for frame: int in 30: view.update_source(0.0,world,record)
	check(aura.configure_calls == 1 and actor.configure_calls == 1 and actor.match_calls == 0,"aura pending retries do not load every frame or restart body")
	deadline(view,"_next_aura_check_msec",true)
	view.update_source(0.0,world,record)
	check(aura.configure_calls == 2 and aura.status == READY and not view.aura_signature.is_empty(),"same-key aura retries after availability changes")
	check(aura.get_instance_id() == aura_id and actor.configure_calls == 1,"aura-only recovery reuses node and preserves body")
	var aura_calls: int = aura.configure_calls
	aura.hide()
	deadline(view,"_next_aura_check_msec",false)
	for frame: int in 15: view.update_source(0.0,world,record)
	check(aura.configure_calls == aura_calls,"intentionally hidden ready aura is not treated as failed")
	aura.visual.ready = false
	view.update_source(0.0,world,record)
	check(view.aura_signature.is_empty() and aura.configure_calls == aura_calls,"lost aura visual invalidates success without unbounded configure")
	deadline(view,"_next_aura_check_msec",true)
	view.update_source(0.0,world,record)
	check(aura.configure_calls == aura_calls+1 and aura.visual.installed(),"lost aura visual retries independently")
	aura_calls = aura.configure_calls
	actor.available_pin = "C"
	deadline(view,"_next_source_check_msec",true)
	view.update_source(0.0,world,record)
	check(actor.configure_calls == 2 and aura.configure_calls == aura_calls+1 and aura.get_instance_id() == aura_id,"same-key body rebind invalidates and rebuilds aura binding")
	aura_calls = aura.configure_calls
	configured = actor.configure_calls
	deadline(view,"_next_source_check_msec",false)
	deadline(view,"_next_aura_check_msec",false)
	world.presentation_settings = {"reduced_motion":true}
	view.update_source(0.0,world,record)
	check(aura.configure_calls == aura_calls+1 and actor.configure_calls == configured,"changed presentation retries aura immediately without body reset")
	world.option_awakening.awake = false
	aura_calls = aura.configure_calls
	deadline(view,"_next_aura_check_msec",false)
	view.update_source(0.0,world,record)
	check(aura.status == "inactive" and not aura.visual.installed() and aura.configure_calls == aura_calls+1,"lost eligibility deactivates aura immediately during cooldown")
	view.update_source(0.0,world,record)
	check(aura.configure_calls == aura_calls+1,"unchanged disabled aura does not reconfigure each frame")
	view.category = "성물"
	var doll_calls: int = world.option_awakening.doll_calls
	view.update_source(0.0,world,{"sourceId":"m523:98:42","source_snapshot":"patch523"})
	check(world.option_awakening.relic_calls == 1 and world.option_awakening.doll_calls == doll_calls and actor.supplied_key == "relic:m523:98:42","relic keeps its existing distinct eligibility and source namespace")
	view.clear()
	check(aura.status == "inactive" and view.aura_signature.is_empty(),"release clears successful or pending aura cache")
	view.free()
	world.free()
	print("SOURCE_SUBSLOT_ATTACHMENT_RETRY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"synthetic source eligibility and visual readiness; no original admission or rendering claim"}))
	quit(0 if failures.is_empty() else 1)
