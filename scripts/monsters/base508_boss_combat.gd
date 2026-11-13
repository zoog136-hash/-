extends RefCounted
## Exact source IDs and typed values; the existing host remains the combat clock.
## Undocumented source probability/range/delay units are never silently guessed.
const CATALOG_PATH = "res://data/lineagem_base508/boss_combat.bin"
const CATALOG_SHA256 = "37e34cffc7cff15bd59d69d4f34a63583ddae39ea261a6eb5750d2d314656840"
const LITERAL_VFX = preload("res://scripts/monsters/base508_boss_vfx.gd")
const PLAYBACK_POLICY = preload("res://scripts/animation/source_playback_policy.gd")
const HOST_ADOPTIONS = preload("res://scripts/monsters/base508_boss_host_adoptions.gd")
const AI_POLICY = preload("res://scripts/monsters/monster_ai_policy.gd")
const SOURCE_PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const ELEMENTS = {"None":"physical","Fire":"fire","Water":"water","Air":"wind","Earth":"earth","Light":"holy","Dark":"dark"}
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const ORDINARY_CONTRACTS = ["base508_exact_context_ordinary_host_action_v1","base508_exact_context_single_spell_host_action_v1","base508_exact_context_core_ready_optional_gaps_v1"]
static var _catalog: Dictionary = {}
var owner_ref: WeakRef
var world_ref: WeakRef
var source_npc_id: int = -1
var source_life: int = -1
var cooldown: float = 0.0
var queued_attack_id: int = -1
var chain_depth: int = 0
var pending: Dictionary = {}
var owned_motion: Dictionary = {}
var presentation: Dictionary = {}
var last_result: Dictionary = {}
var diagnostics: Dictionary = {}
var options: Dictionary = {}
var effect_owner: Node2D
var literal_effects: Array[Node2D] = []
var private_vfx_root: String = ""
var playback_root: String = ""
var effect_generation: int = -1

static func data(pack_root: String = "") -> Dictionary:
	HITCH.count("boss.catalog_request")
	if not _catalog.is_empty():
		HITCH.count("boss.catalog_hit")
		return _catalog
	var candidates: Array[String] = []
	if not pack_root.is_empty(): candidates.append(pack_root.path_join("boss_combat.bin"))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--base508-boss-combat-root="): candidates.append(argument.trim_prefix("--base508-boss-combat-root=").path_join("boss_combat.bin"))
	candidates.append(CATALOG_PATH)
	var install = load("res://scripts/lineagem_pack_install.gd")
	candidates.append(install.monster_root().path_join("boss_combat.bin"))
	for path: String in candidates:
		var value: Dictionary = read_catalog_file(path)
		if not value.is_empty():
			_catalog = value
			return _catalog
	return {}

static func read_catalog_file(path: String) -> Dictionary:
	var started: int = HITCH.now()
	var verified: bool = FileAccess.file_exists(path) and FileAccess.get_sha256(path) == CATALOG_SHA256
	HITCH.detail("boss.catalog_verify",started)
	if not verified: return {}
	started = HITCH.now()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path).decompress_dynamic(64 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	HITCH.detail("boss.catalog_inflate",started)
	started = HITCH.now()
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	HITCH.detail("boss.catalog_json",started)
	if value is Dictionary and value.get("kind") == "base508_npc_combat_catalog" and value.get("source_snapshot") == "base508": return value
	return {}

func configure(owner: Node, world: Node, record: Dictionary) -> bool:
	clear()
	if not owner is Node2D or not actor_contract(owner) or not world_contract(world): return false
	var nid: int = int(record.get("source_m_npc_id", -1))
	var original: Dictionary = record.get("source_m_original", {})
	var private_root: String = str(record.get("source_m_combat_pack_root",str(record.get("source_m_asset_manifest_path","")).get_base_dir()))
	# These actors were always rejected below. Reject before opening/inflating
	# the default catalog. Explicit pack roots retain the former priming order:
	# a later actor may rely on the first verified shared catalog from that root.
	if private_root.is_empty():
		if nid <= 0 or int(original.get("ID", -1)) != nid or bool(original.get("TestNPC",false)): return false
		if not bool(owner.get("is_boss")) and record.get("source_m_host_action_contract",{}).get("contract","") not in ORDINARY_CONTRACTS:
			HITCH.count("boss.catalog_ineligible_skipped")
			return false
	var source: Dictionary = data(private_root).get("source_npcs", {}).get(str(nid), {})
	if nid <= 0 or source.is_empty() or int(original.get("ID", -1)) != nid or int(original.get("Sprite", -1)) != int(source.sprite_id): return false
	if bool(original.get("TestNPC",false)): return false
	if not bool(owner.get("is_boss")):
		if record.get("source_m_host_action_contract",{}).get("contract","") not in ORDINARY_CONTRACTS or HOST_ADOPTIONS.for_record(record,"",data()).is_empty(): return false
	owner_ref = weakref(owner); world_ref = weakref(world)
	source_npc_id = nid; source_life = int(owner.get("life_id"))
	effect_generation = int(world.get("combat_generation"))
	private_vfx_root = str(record.get("source_m_boss_vfx_pack_root",private_root.path_join("boss_vfx")))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--base508-boss-vfx-root="): private_vfx_root=argument.trim_prefix("--base508-boss-vfx-root=")
	var player_manifest: Variant = world.player.get("original_source_manifest")
	playback_root = str(player_manifest).get_base_dir() if player_manifest is String else ""
	if playback_root.is_empty(): playback_root=private_root
	options = record.get("source_m_boss_combat_options", {}).duplicate(true)
	if int(options.get("explicit_attack_id",-1)) <= 0 and str(options.get("selection_policy","")).is_empty():
		options.merge(HOST_ADOPTIONS.for_record(record,str(world.get("active_map_id")) if world.get("active_map_id") is String else "",data()),true)
	if record.has("source_m_host_action_contract"):
		var adoption: Dictionary = HOST_ADOPTIONS.for_record(record,"",data())
		if adoption.is_empty():
			clear(); return false
		options.merge(adoption,true)
		options["host_action_contract_locked"] = true
	diagnostics = {"identity":"exact_base508_npc_id","selection":"explicit_attack_id_or_unique_supported_attack","clock":"existing_host_attack_windup_and_cooldown; native_FixedDelayTime_unit_pending","range":"existing_host_pixel_range; native_source_cells_pending","status_chance":"existing_host_status_accuracy_and_resistance; native_spell_probability_unverified","source_vfx":"exact_spell_sprite_id; installed_overlay_only"}
	if options.get("selection_policy","") == "explicit_host_adoption_not_native_AI": diagnostics["host_adoption"] = options.get("adoption_contract")
	return true

func clear() -> void:
	_cancel_pending_motion()
	_clear_literal_effects()
	_clear_presentation()
	pending.clear(); owned_motion.clear(); last_result.clear(); diagnostics.clear(); options.clear()
	cooldown = 0.0; queued_attack_id = -1; chain_depth = 0
	source_npc_id = -1; source_life = -1; owner_ref = null; world_ref = null
	if is_instance_valid(effect_owner):
		effect_owner.clear()
		effect_owner.queue_free()
	effect_owner = null;private_vfx_root="";playback_root="";effect_generation=-1

func owner() -> Node:
	return owner_ref.get_ref() if owner_ref != null else null
func world() -> Node:
	return world_ref.get_ref() if world_ref != null else null
static func world_contract(scene: Node) -> bool:
	if not is_instance_valid(scene): return false
	if typeof(scene.get("hp")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(scene.get("hp"))): return false
	if typeof(scene.get("combat_generation")) != TYPE_INT or not scene.get("rng") is RandomNumberGenerator: return false
	var player: Variant = scene.get("player")
	if not player is Node2D or not is_instance_valid(player) or not player.has_method("apply_stun"): return false
	for method: String in ["_has_line_of_sight_world","_on_player_hit","_roll_monster_hit","_status_effect_chance","_stun_resistance_stat"]:
		if not scene.has_method(method): return false
	return true

static func actor_contract(actor: Node) -> bool:
	if not is_instance_valid(actor) or typeof(actor.get("life_id")) != TYPE_INT or typeof(actor.get("dead")) != TYPE_BOOL: return false
	if typeof(actor.get("is_boss")) != TYPE_BOOL or typeof(actor.get("attack_interval")) not in [TYPE_INT,TYPE_FLOAT]: return false
	if typeof(actor.get("attack_cooldown")) not in [TYPE_INT,TYPE_FLOAT] or typeof(actor.get("enraged")) != TYPE_BOOL: return false
	var pose: Variant = actor.get("motion")
	if not pose is Object or not is_instance_valid(pose) or not pose.has_method("begin_attack"): return false
	for method: String in ["is_stunned","is_feared","is_silenced","_target_attackable","current_attack_range","current_attack_type"]:
		if not actor.has_method(method): return false
	return true

func valid_life() -> bool:
	var actor: Node = owner(); var scene: Node = world()
	return actor_contract(actor) and world_contract(scene) and not bool(actor.get("dead")) and int(actor.get("life_id")) == source_life and float(scene.get("hp")) > 0.0
func active() -> bool:
	return source_npc_id > 0 and valid_life()
func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - maxf(0.0,delta))
	_advance_presentation(maxf(0.0,delta))
	if source_npc_id > 0 and (not valid_life() or int(world().get("combat_generation")) != effect_generation): _clear_literal_effects()
	if source_npc_id > 0 and (not valid_life() or (not owned_motion.is_empty() and int(owned_motion.get("world_generation",-1)) != int(world().get("combat_generation")))):
		_cancel_pending_motion()
		_clear_presentation()
		if is_instance_valid(effect_owner): effect_owner.clear()

func attack_row(id: int) -> Dictionary:
	for row: Dictionary in data().get("npc_attacks", {}).get(str(source_npc_id), []):
		if int(row.ID) == id: return row
	return {}
func spell_for(row: Dictionary) -> Dictionary:
	return data().get("spells", {}).get(str(int(row.get("SpellID", 0))), {})
func supported(row: Dictionary) -> bool:
	if row.is_empty(): return false
	if not bool(row.get("IsSpell", false)):
		var count: int=int(row.get("DiceCount",0));var spots:int=int(row.get("DiceSpots",0))
		if count<0 or count>1000 or spots<0 or spots>1000000 or (count>0 and spots<=0):return false
		return count>0 or int(row.get("DiceBonus",0))>0
	var spell: Dictionary = spell_for(row)
	if spell.is_empty() or bool(spell.get("source_spell",{}).get("TestSpell",false)): return false
	var target: String = str(spell.get("targetting_type",{}).get("Name",""))
	var kind: String = str(spell.get("target_kind",{}).get("Name",""))
	if kind != "Enemy" or target not in ["Self","SingleObject","LandPoint"]: return false
	var dice: Dictionary = spell.get("damage_dice", {})
	var count:int=int(dice.get("dice_count",0));var spots:int=int(dice.get("dice_spots",0))
	if count<0 or count>1000 or spots<0 or spots>1000000 or (count>0 and spots<=0):return false
	if int(dice.get("base",0))>0 or count>0:return true
	return not status_packet(spell).is_empty()

func status_packet(spell: Dictionary) -> Dictionary:
	var duration: Dictionary = spell.get("status_duration_seconds", {})
	var low: float = float(duration.get("min",duration.get("fixed",0.0)))
	var high: float = float(duration.get("max",duration.get("fixed",low)))
	if low <= 0.0 or high < low: return {}
	for buff: Dictionary in spell.get("buffs", []):
		if buff.get("supported_status") == "stun": return {"kind":"stun","min_seconds":low,"max_seconds":high,"source_buff_id":buff.source_buff_id}
	return {}

func choose_attack(explicit_id: int = -1) -> Dictionary:
	if explicit_id > 0:
		var explicit: Dictionary = attack_row(explicit_id)
		return explicit if supported(explicit) else {}
	if queued_attack_id > 0: return choose_attack(queued_attack_id)
	var choices: Array = []
	for row: Dictionary in data().get("npc_attacks", {}).get(str(source_npc_id), []):
		if supported(row): choices.append(row)
	if choices.size() == 1: return choices[0]
	# A host weighted-choice adapter is an explicit opt-in, never called native M probability.
	if options.get("selection_policy", "") == "host_weighted_source_Prob":
		var sum: int = 0
		for row: Dictionary in choices: sum += maxi(0,int(row.get("Prob",0)))
		if sum > 0:
			var roll: int = world().rng.randi_range(1,sum)
			for row: Dictionary in choices:
				roll -= maxi(0,int(row.get("Prob",0)))
				if roll <= 0:
					diagnostics.selection = "explicit_host_weighted_source_Prob; native_denominator_unverified"
					return row
	diagnostics["selection_pending"] = {"supported_choices":choices.size(),"reason":"multiple source attacks; explicit attack ID or reviewed selection policy required"}
	return {}

func _host_range(row: Dictionary, spell: Dictionary) -> float:
	# Only callers with a verified map coordinate contract may supply a scale.
	var scale: float = float(options.get("verified_source_cell_pixel_scale",0.0))
	if scale > 0.0:
		var source_range: float = float(row.get("Range",0))
		if spell.get("targetting_type",{}).get("Name","") == "Self": source_range = float(spell.source_spell.get("TargetAreaRadius",0))
		diagnostics.range = "caller_supplied_verified_source_cell_scale"
		return source_range * scale
	return float(owner().call("current_attack_range"))

func try_begin(line_of_sight: bool, explicit_id: int = -1) -> bool:
	if not active(): return false
	var actor: Node = owner(); var scene: Node = world()
	# Service ticks and AI decisions can use different delta batches. Preserve
	# the later deadline before the generic AI checks this shared clock.
	actor.attack_cooldown = maxf(float(actor.attack_cooldown),cooldown)
	if cooldown > 0.0 or not pending.is_empty() or not line_of_sight: return false
	if float(actor.attack_cooldown) > 0.0: return false
	if actor.is_stunned() or actor.is_feared() or not actor._target_attackable() or actor.motion.active: return false
	var selected_id: int = explicit_id if explicit_id > 0 else int(options.get("explicit_attack_id",-1))
	if bool(options.get("host_action_contract_locked",false)):
		if explicit_id > 0 and explicit_id != int(options.explicit_attack_id): return false
		selected_id = int(options.explicit_attack_id)
	var row: Dictionary = choose_attack(selected_id)
	if row.is_empty(): return false
	if actor.is_silenced() and (bool(row.IsSpell) or str(actor.current_attack_type()) == "magic"): return false
	var spell: Dictionary = spell_for(row)
	var distance: float = actor.global_position.distance_to(scene.player.global_position)
	var reach: float = _host_range(row,spell)
	if reach <= 0.0 or distance > reach: return false
	var aim: Vector2 = scene.player.global_position - actor.global_position
	var windup: float = minf(0.68, float(actor.attack_interval) * 0.75)
	var sequence: int = actor.motion.begin_attack(windup,aim,"magic" if bool(row.IsSpell) else str(actor.current_attack_type()),actor.motion.profile.marker_for("magic" if bool(row.IsSpell) else "slash"))
	if sequence < 0: return false
	pending = {"attack":row.duplicate(true),"spell":spell,"sequence":sequence,"owner_life":source_life,"owner_instance_id":actor.get_instance_id(),"motion_instance_id":actor.motion.get_instance_id(),"world_generation":int(scene.get("combat_generation")),"target_id":scene.player.get_instance_id(),"reach":reach,"origin":actor.global_position}
	owned_motion = {"sequence":sequence,"owner_life":source_life,"owner_instance_id":actor.get_instance_id(),"motion_instance_id":actor.motion.get_instance_id(),"world_generation":int(scene.get("combat_generation"))}
	effect_generation = int(scene.get("combat_generation"))
	queued_attack_id = -1
	_begin_presentation()
	actor.velocity = Vector2.ZERO
	cooldown = maxf(0.0,AI_POLICY.attack_interval(float(actor.attack_interval),bool(actor.enraged)))
	# Share the generic AI clock: recovery ending must not permit a second
	# generic attack between native casts. No source delay unit is inferred.
	actor.attack_cooldown = cooldown
	diagnostics["last_source_fixed_delay_raw"] = int(row.get("FixedDelayTime",0))
	diagnostics["last_source_cast_delay_raw"] = int(spell.get("source_spell",{}).get("CastDelay",0))
	_emit_vfx(spell,"cast",actor.global_position)
	return true

func cancel(sequence: int) -> void:
	if int(presentation.get("sequence",-1)) == sequence: _clear_presentation()
	if int(pending.get("sequence",-1)) != sequence and int(owned_motion.get("sequence",-1)) != sequence: return
	_cancel_pending_motion()
	if is_instance_valid(effect_owner): effect_owner.clear()

func _cancel_pending_motion() -> void:
	# Consume before cancellation signals: Monster._cancel_attack re-enters cancel().
	var action: Dictionary = pending if not pending.is_empty() else owned_motion
	pending = {}; owned_motion = {}; queued_attack_id = -1
	if action.is_empty(): return
	var actor: Node = owner()
	if not is_instance_valid(actor) or typeof(actor.get("life_id")) != TYPE_INT: return
	if actor.get_instance_id() != int(action.get("owner_instance_id",-1)) or int(actor.life_id) != int(action.get("owner_life",-1)): return
	var pose: Variant = actor.get("motion")
	if not pose is Object or not is_instance_valid(pose) or not pose.has_method("cancel_attack"): return
	if typeof(pose.get("sequence")) != TYPE_INT or typeof(pose.get("active")) != TYPE_BOOL: return
	if pose.get_instance_id() != int(action.get("motion_instance_id",-1)) or int(pose.sequence) != int(action.get("sequence",-1)) or not bool(pose.active): return
	# Only this source attack is cancelled. A pooled/new-life/replacement pose is untouched.
	pose.cancel_attack()

func _begin_presentation() -> void:
	_clear_presentation()
	var actor: Node = owner()
	if not is_instance_valid(actor) or not is_instance_valid(actor.get("source_m_view")): return
	var view: Node = actor.get("source_m_view")
	var action: Dictionary = pending_source_action()
	var id: int = int(action.get("selected_source_action_id",-1))
	if id < 0 or not view.has_method("advance_source_action"):
		diagnostics["source_motion_pending"] = action
		return
	if not bool(view.call("advance_source_action",id,0.0,int(actor.motion.facing8),int(pending.sequence))):
		diagnostics["source_motion_pending"] = {"source_action_id":id,"reason":"authored action unavailable; no generic attack substitution claimed"}
		return
	presentation = {"action_id":id,"sequence":pending.sequence,"world_generation":pending.world_generation,"elapsed":0.0,"duration":float(view.call("source_action_duration",id))}

func _advance_presentation(delta: float) -> void:
	if presentation.is_empty(): return
	if not valid_life() or int(world().get("combat_generation")) != int(presentation.world_generation):
		_clear_presentation(); return
	var actor: Node = owner(); var view: Node = actor.get("source_m_view")
	if not is_instance_valid(view) or int(actor.motion.sequence) != int(presentation.sequence):
		_clear_presentation(); return
	var duration: float = float(presentation.duration)
	# End-exclusive sampling also holds the last frame when an exact source
	# attack route shares a looped role track (mermaid's authored Breath3).
	var sample_end:float=maxf(0.0,duration-minf(0.000001,duration*0.5))
	var frame_delta:float=minf(delta,maxf(0.0,sample_end-float(presentation.elapsed))) if duration>0.0 else delta
	presentation.elapsed += delta
	view.call("advance_source_action",int(presentation.action_id),frame_delta,int(actor.motion.facing8),int(presentation.sequence))
	# A short source clip keeps its last authored frame through host recovery.
	# Releasing ownership early lets the generic view hide action-only actors
	# or restart a basic attack. The host clock is not a native FPS claim.
	if (duration <= 0.0 or float(presentation.elapsed) >= duration) and not actor.motion.active: _clear_presentation()

func _clear_presentation() -> void:
	var actor: Node = owner()
	if is_instance_valid(actor) and typeof(actor.get("life_id")) == TYPE_INT and int(actor.life_id) == source_life:
		var view: Variant = actor.get("source_m_view")
		if is_instance_valid(view) and view.has_method("clear_source_action"): view.call("clear_source_action")
	presentation.clear()

func pending_source_action() -> Dictionary:
	if pending.is_empty(): return {}
	var row: Dictionary = pending.attack
	var result: Array = []
	for source: Dictionary in data().get("source_actions", []):
		if int(source.MotionType) == int(row.MotionType) and int(source.WeaponType) == int(row.WeaponType): result.append(int(source.ID))
	if bool(options.get("host_action_contract_locked",false)) and int(options.get("host_source_action_id",-1)) > 0:
		var adopted:int=int(options.host_source_action_id)
		if result.has(adopted): return {"source_attack_id":row.ID,"candidate_source_action_ids":result,"source_motion_type":row.MotionType,"source_weapon_type":row.WeaponType,"selected_source_action_id":adopted,"selection_origin":"exact_context_available_action_host_contract"}
	return {"source_attack_id":row.ID,"candidate_source_action_ids":result,"source_motion_type":row.MotionType,"source_weapon_type":row.WeaponType,"selected_source_action_id":result[0] if result.size()==1 else -1}

func release(sequence: int) -> bool:
	if pending.is_empty() or int(pending.sequence) != sequence: return false
	if valid_life() and (not owner().motion.active or not owner().motion.released or int(owner().motion.sequence) != sequence): return false
	var action: Dictionary = pending; pending = {}
	if not valid_life(): return true
	var actor: Node = owner(); var scene: Node = world()
	if int(action.motion_instance_id) != actor.motion.get_instance_id() or int(action.owner_instance_id) != actor.get_instance_id() or int(action.owner_life) != int(actor.life_id) or int(action.world_generation) != int(scene.get("combat_generation")) or int(action.target_id) != scene.player.get_instance_id(): return true
	var row: Dictionary = action.attack; var spell: Dictionary = action.spell
	if actor.is_stunned() or actor.is_feared() or not actor._target_attackable(): return true
	if actor.is_silenced() and (bool(row.IsSpell) or str(actor.current_attack_type()) == "magic"): return true
	if actor.global_position.distance_to(scene.player.global_position) > float(action.reach) or not scene._has_line_of_sight_world(actor.global_position,scene.player.global_position): return true
	var raw: int = roll_damage(row,spell,scene.rng)
	var status: Dictionary = status_packet(spell)
	var channel: String = "magic" if bool(row.IsSpell) else str(actor.current_attack_type())
	var initial_life: int = int(actor.life_id)
	var old_status: Dictionary = {}
	for kind: String in ["stun","silence","hold","fear","poison","bleed"]:
		for suffix: String in ["_duration","_accuracy"]:
			var property: String = kind + suffix
			old_status[property] = actor.get(property)
			actor.set(property,0)
	var old_stun_accuracy: int = int(old_status.get("stun_accuracy",0))
	var old_element: String = str(actor.attack_element)
	var duration: float = scene.rng.randf_range(float(status.min_seconds),float(status.max_seconds)) if not status.is_empty() else 0.0
	if duration > 0.0:
		actor.stun_duration = duration
		# Reuse the existing host status formula; this is not an asserted M success chance.
		actor.stun_accuracy = old_stun_accuracy if old_stun_accuracy > 0 else int(actor.magic_accuracy)
	var source_element: String = str(spell.get("element",{}).get("Name","None"))
	if bool(row.IsSpell) and ELEMENTS.has(source_element): actor.attack_element = ELEMENTS[source_element]
	if raw > 0:
		# The authoritative host hit/crit/reduction/resistance/counter/death path runs once.
		scene._on_player_hit(actor,raw,channel)
	elif duration > 0.0 and scene._roll_monster_hit(actor,"magic"):
		var chance: float = scene._status_effect_chance(int(actor.stun_accuracy),int(actor.monster_level),int(scene._stun_resistance_stat()),int(scene.level))
		if scene.rng.randf() < chance: scene.player.apply_stun(duration)
	if is_instance_valid(actor) and int(actor.life_id) == initial_life:
		for property: String in old_status: actor.set(property,old_status[property])
		actor.attack_element = old_element
	if not valid_life() or int(actor.life_id) != initial_life or source_life != int(action.owner_life) or source_npc_id != int(row.NpcClassID) or int(scene.get("combat_generation")) != int(action.world_generation): return true
	_emit_vfx(spell,"effect",Vector2(action.origin) if spell.get("targetting_type",{}).get("Name","") == "Self" else scene.player.global_position)
	_emit_vfx(spell,"impact",scene.player.global_position)
	last_result = {"source_npc_attack_id":row.ID,"source_spell_id":int(row.SpellID),"raw_damage":raw,"source_status_duration_seconds":duration,"world_generation":action.world_generation,"damage_origin":"typed_source_dice; existing_host_combat_formula","actual_hit_result":"host_resolver_owns_outcome; no fake success event"}
	var next: int = int(row.get("NextAttack",0))
	if next > 0 and supported(attack_row(next)) and chain_depth < 16:
		queued_attack_id = next; chain_depth += 1
	else:
		queued_attack_id = -1; chain_depth = 0
	return true

static func roll_damage(row: Dictionary, spell: Dictionary, rng: RandomNumberGenerator) -> int:
	var dice: Dictionary = spell.get("damage_dice",{}) if bool(row.get("IsSpell",false)) else {"base":int(row.get("DiceBonus",0)),"dice_count":int(row.get("DiceCount",0)),"dice_spots":int(row.get("DiceSpots",0))}
	var amount: int = int(dice.get("base",0)); var count: int = int(dice.get("dice_count",0)); var spots: int = int(dice.get("dice_spots",0))
	if count < 0 or count > 1000 or spots < 0 or spots > 1000000: return 0
	if count > 0 and spots <= 0: return 0
	for index: int in range(count): amount += rng.randi_range(1,spots)
	return maxi(0,amount)

func _clear_literal_effects() -> void:
	for effect: Node2D in literal_effects:
		if is_instance_valid(effect): effect.clear();effect.queue_free()
	literal_effects.clear()

static func source_effect_direction(host_facing8:int) -> int:
	# Same host-facing adapter as monster_view/original_source_preview. This
	# is a compatibility basis, not a claim of native M direction verification.
	return posmod(host_facing8+3,8)

func _literal_vfx(sprite_id:int,action_id:int,point:Vector2) -> bool:
	if private_vfx_root.is_empty() or not FileAccess.file_exists(private_vfx_root.path_join("boss_vfx.json")): return false
	literal_effects=literal_effects.filter(func(effect:Node2D)->bool:return is_instance_valid(effect) and not effect.is_queued_for_deletion())
	if literal_effects.size()>=16:
		diagnostics["vfx_pending"]="bounded source SP2 effect budget reached; no invented pending lifetime"
		return false
	var effect=LITERAL_VFX.new()
	var mode:String=PLAYBACK_POLICY.mode(playback_root)
	var host_facing8:int=int(owner().motion.facing8)
	var source_slot:int=source_effect_direction(host_facing8)
	if not effect.configure(private_vfx_root,sprite_id,action_id,source_slot,mode):
		effect.free();return false
	diagnostics["literal_vfx_source_status"]=effect.source_status.duplicate(true)
	diagnostics["literal_vfx_source_status"].merge({"host_facing8":host_facing8,"source_direction_slot":source_slot,"direction_contract":"existing_host_facing_plus3_mod8; native_M_unverified"})
	if int(effect.source_status.get("visible_source_layers",0))<=0:
		effect.clear();effect.free()
		return false
	owner().add_child(effect);effect.global_position=point;literal_effects.append(effect)
	return true

func _emit_vfx(spell: Dictionary, phase: String, point: Vector2) -> bool:
	if spell.is_empty() or not valid_life(): return false
	var source_field: String = {"cast":"CasterEffectSpriteID","effect":"EffectSpriteID","impact":"EffectExplosionSpriteID"}.get(phase,"")
	if source_field.is_empty() or int(spell.get("source_spell",{}).get(source_field,0)) <= 0: return false
	if phase == "effect" and int(spell.get("source_spell",{}).get("EffectSpriteActionNo",0)) != 0:
		diagnostics["vfx_pending"] = "nonzero exact source effect action requires installed action binding; no action0 substitution"
		return false
	var scene: Node = world(); var actor: Node = owner()
	var source_sprite: int = int(spell.source_spell.get(source_field,0))
	if _literal_vfx(source_sprite,0,point): return true
	var manifest_value: Variant = scene.player.get("original_source_manifest")
	var manifest: String = manifest_value if manifest_value is String else ""
	if manifest.is_empty():
		diagnostics["vfx_pending"] = "source runtime manifest not installed"
		return false
	if not is_instance_valid(effect_owner):
		effect_owner = SOURCE_PREVIEW.new()
		actor.add_child(effect_owner)
	if effect_owner.get_script() == SOURCE_PREVIEW:
		var active_overlays: int = 0
		for overlay: Node2D in effect_owner.get("_overlay_nodes"):
			if is_instance_valid(overlay): active_overlays += 1
		if active_overlays >= 16:
			diagnostics["vfx_pending"] = "source overlay ownership budget reached; unknown timing is not fabricated"
			return false
	var ok: bool = effect_owner.notify_source_spell_event(int(spell.source_spell.ID),phase,point,int(actor.motion.facing8),manifest)
	if not ok: diagnostics["vfx_pending"] = {"spell_id":spell.source_spell.ID,"phase":phase,"exact_source_effect_fields":spell.get("effect_fields",{}),"reason":"exact source overlay unavailable or strict-unverified; no icon/generated substitute"}
	return ok
