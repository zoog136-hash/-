extends "res://scripts/monsters/base508_monster_view.gd"
## The existing NPC clock delegates pixels and source layers to the shared preview.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const SELECTION = preload("res://scripts/monsters/current523_source_bank_selection.gd")
const PRESENTATION = preload("res://scripts/animation/source_presentation_policy.gd")
const ACTION_ROLE = "attack"
var selection_status: Dictionary = {}
var _preview: PREVIEW = null
var _action_preview: PREVIEW = null
var _source_action_id: int = -1

static func source_only_request(record: Dictionary) -> bool:
	return SELECTION.source_only_request(record)

func configure_admitted(record: Dictionary, admission: Dictionary) -> bool:
	selection_status = SELECTION.select(record,admission)
	if not selection_status.get("ok",false): return false
	var selected: Dictionary = selection_status
	if selected.get("runtime_actor_registry_required",false):
		var active_identity: Variant = selected.get("current523_npc_source_identity")
		if selected.get("definition_selection_only",false) or not active_identity is Dictionary or active_identity.is_empty():
			selection_status["ok"] = false
			selection_status["status"] = "source_only_pending"
			selection_status["reason"] = "current523_active_actor_registry_required_for_view"
			selection_status["selection_phase"] = "awaiting_active_actor_registry"
			return false
	var candidate := PREVIEW.new()
	if not candidate._configure_selected_roles(selected,"idle"):
		selection_status = selected.duplicate(true)
		selection_status["ok"] = false
		selection_status["status"] = "source_only_pending" if selected.get("source_only",false) else "selection_pending"
		selection_status["reason"] = candidate.reference_bank_status.get("error","current523_npc_core_source_action_unavailable")
		candidate.free()
		return false
	_preview = candidate
	_preview._reference_request_context = selected.get("source_bank_context",{}).duplicate(true)
	_preview._reference_card_context = selected.duplicate(true)
	_preview.source_selection_status = selected.duplicate(true)
	_preview.reference_bank_status["purpose"] = "existing_npc_consumer"
	_preview.reference_bank_status["host_policy"] = selected.host_policy
	_preview._load_reference_overlay_bindings(selected)
	add_child(_preview)
	_tracks = _preview._playback_tracks
	_mode = _preview.source_playback_mode()
	_root = str(selected.manifest_path).get_base_dir()
	for role: String in selected.role_actions:
		var track: Dictionary = _tracks.get(role,{})
		timing_status[role] = {"effective_fps":track.get("effective_fps"),"origin":track.get("timing_origin"),"source_fps":track.get("fps")}
	attachment_status = _preview.attachment_status()
	_role = "idle"
	_clock = 0.0
	_sequence = -1
	_source_attack = false
	if not _preview.advance_reference_source(0.0,"idle",posmod(2 + 3,8)):
		selection_status["ok"] = false
		selection_status["status"] = "source_only_pending" if selected.get("source_only",false) else "selection_pending"
		selection_status["reason"] = _preview.reference_bank_status.get("error","current523_npc_initial_source_frame_unavailable")
		return false
	return true

func duration(role: String) -> float:
	var track: Dictionary = _tracks.get(role,{})
	if track.is_empty() or bool(track.get("static_pending_timing",true)): return 0.0
	var directions: Array = track.get("directions",[])
	if directions.is_empty(): return 0.0
	var total: float = 0.0
	for frame: Dictionary in directions[0]: total += PRESENTATION.duration(frame)
	return total

func advance(delta: float, state: String, facing: int, sequence: int, attacking: bool, dead: bool) -> void:
	if not is_instance_valid(_preview) or not _preview.installed(): return
	if _explicit_source_action:
		# Successful clips are released by the existing combat owner, including
		# its recovery hold. Failed clips hold no substitute while that motion is
		# active, then release without needing a successful presentation handle.
		if dead or sequence != _explicit_sequence or (not is_instance_valid(_action_preview) and not attacking):
			clear_source_action()
		else:
			return
	if sequence != _sequence and attacking and not dead:
		_sequence = sequence
		_source_attack = true
		_role = "attack"
		_clock = 0.0
		_preview.restart_reference_source("attack",sequence)
	var movement_role: String = "run" if state == "run" and _tracks.has("run") else ("walk" if state in ["walk","run","patrol","chase"] else "idle")
	var role: String = "death" if dead else ("attack" if _source_attack or attacking else ("hit" if state == "hit" else movement_role))
	if role != _role:
		_role = role
		_clock = 0.0
	if not _tracks.has(role):
		selection_status["status"] = "source_only_pending" if selection_status.get("source_only",false) else "source_input_unavailable"
		selection_status["reason"] = "current523_npc_source_role_unavailable:" + role
		source_state_status = {"ok":false,"status":"source_only_pending","requested_role":role,"reason":selection_status.reason}
		last_source_frame = -1
		_preview.hide()
		return
	_clock += maxf(delta,0.0)
	if not _preview.advance_reference_source(maxf(delta,0.0),_role,posmod(facing + 3,8)):
		selection_status["status"] = "source_only_pending" if selection_status.get("source_only",false) else "source_input_unavailable"
		selection_status["reason"] = _preview.reference_bank_status.get("error","current523_npc_source_frame_unavailable")
		source_state_status = {"ok":false,"status":"source_only_pending","requested_role":role,"reason":selection_status.reason}
		last_source_frame = -1
		_preview.hide()
		return
	_preview.show()
	selection_status["status"] = "selected"
	selection_status.erase("reason")
	source_state_status = {"ok":true,"status":"current523_source_track","role":role}
	last_source_frame = _preview.last_source_frame
	var total: float = duration(_role)
	if _role == "attack" and (total <= 0.0 or _clock >= total): _source_attack = false

func source_frame_status() -> Dictionary:
	if _explicit_source_action:
		return _action_preview.reference_source_frame_status() if is_instance_valid(_action_preview) else source_state_status.duplicate(true)
	if source_state_status.get("ok") == false: return source_state_status.duplicate(true)
	return _preview.reference_source_frame_status() if is_instance_valid(_preview) else {}

func advance_source_action(action_id: int, delta: float, facing: int, sequence: int) -> bool:
	# base508_boss_combat already chooses this exact action from the admitted
	# source attack's MotionType/WeaponType. Its existing sequence/life checks
	# and clock remain the only gameplay owner; no action is selected here.
	if not bool(selection_status.get("ok",false)) or not is_instance_valid(_preview) or not _preview.installed(): return false
	if action_id < 0 or not is_finite(delta) or delta < 0.0 or facing < 0 or facing > 7: return false
	if not _explicit_source_action or _explicit_sequence != sequence or _source_action_id != action_id:
		clear_source_action()
		_explicit_source_action = true
		_explicit_sequence = sequence
		_source_action_id = action_id
		_sequence = sequence
		_preview.hide()
		last_source_frame = -1
		var candidate := PREVIEW.new()
		candidate.playback_mode_override = _preview.source_playback_mode()
		if not candidate._configure_reference_bank(str(selection_status.manifest_path),str(selection_status.manifest_sha256),int(selection_status.sprite_id),{ACTION_ROLE:action_id},{ACTION_ROLE:false},ACTION_ROLE,"npc"):
			source_state_status = {"ok":false,"status":"source_only_pending","requested_source_action_id":action_id,"reason":candidate.reference_bank_status.get("error","current523_npc_explicit_action_unavailable")}
			candidate.free()
			return false
		var selected: Dictionary = selection_status.duplicate(true)
		selected["role_actions"] = {ACTION_ROLE:action_id}
		selected["loop_policy"] = {ACTION_ROLE:false}
		selected["explicit_action_owner"] = "existing_boss_combat_source_motion"
		candidate._reference_request_context = selected.get("source_bank_context",{}).duplicate(true)
		candidate._reference_texture_budget = _preview._reference_texture_budget
		candidate._reference_card_context = selected.duplicate(true)
		candidate.source_selection_status = selected.duplicate(true)
		candidate._load_reference_overlay_bindings(selected)
		_action_preview = candidate
		add_child(_action_preview)
	if not is_instance_valid(_action_preview): return false
	if not _action_preview.advance_reference_source(delta,ACTION_ROLE,posmod(facing + 3,8)):
		source_state_status = {"ok":false,"status":"source_only_pending","requested_source_action_id":action_id,"reason":_action_preview.reference_bank_status.get("error","current523_npc_explicit_action_frame_unavailable")}
		_action_preview.free()
		_action_preview = null
		last_source_frame = -1
		return false
	last_source_frame = _action_preview.last_source_frame
	source_state_status = {"ok":true,"status":"current523_source_action","source_action_id":action_id,"sequence":sequence,
		"timing_pending":bool(_action_preview._playback_tracks.get(ACTION_ROLE,{}).get("static_pending_timing",true))}
	return true

func source_action_duration(action_id: int) -> float:
	if not _explicit_source_action or action_id != _source_action_id or not is_instance_valid(_action_preview): return 0.0
	var track: Dictionary = _action_preview._playback_tracks.get(ACTION_ROLE,{})
	if track.is_empty() or bool(track.get("static_pending_timing",true)): return 0.0
	var directions: Array = track.get("directions",[])
	if directions.is_empty(): return 0.0
	var total: float = 0.0
	for frame: Dictionary in directions[0]: total += PRESENTATION.duration(frame)
	return total

func clear_source_action() -> void:
	if is_instance_valid(_action_preview): _action_preview.free()
	_action_preview = null
	_source_action_id = -1
	_explicit_source_action = false
	_explicit_sequence = -1
	_source_attack = false
	_clock = 0.0
	source_state_status = {}
	if is_instance_valid(_preview):
		_preview.show()
		last_source_frame = _preview.last_source_frame

func notify_current_source_spell_event(spell: Dictionary, stage: String, point: Vector2, facing: int, context: Dictionary = {}) -> bool:
	# The combat owner keeps admission, hit timing, target and effect budgets.
	# This admitted actor exposes only the shared original-pixel presentation API.
	if not bool(selection_status.get("ok",false)) or not is_instance_valid(_preview) or not _preview.installed(): return false
	return _preview.notify_current_source_spell_event(spell,stage,point,facing,context)

func source_effect_status() -> Dictionary:
	return _preview.source_effect_status.duplicate(true) if is_instance_valid(_preview) else {}
