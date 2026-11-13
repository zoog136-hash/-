extends "res://scripts/monsters/base508_monster_view.gd"
## The existing NPC clock delegates pixels and source layers to the shared preview.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const SELECTION = preload("res://scripts/monsters/current523_source_bank_selection.gd")
const PRESENTATION = preload("res://scripts/animation/source_presentation_policy.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
var selection_status: Dictionary = {}
var _preview: PREVIEW = null

static func source_only_request(record: Dictionary) -> bool:
	return SELECTION.source_only_request(record)

func configure_admitted(record: Dictionary, admission: Dictionary) -> bool:
	var started: int = HITCH.now()
	selection_status = SELECTION.select(record,admission)
	HITCH.detail("view.selection",started)
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
	started = HITCH.now()
	var configured: bool = candidate._configure_selected_roles(selected,"idle")
	HITCH.detail("view.roles",started)
	if not configured:
		selection_status = selected.duplicate(true)
		selection_status["ok"] = false
		selection_status["status"] = "source_only_pending" if selected.get("source_only",false) else "selection_pending"
		selection_status["reason"] = candidate.reference_bank_status.get("error","current523_npc_core_source_action_unavailable")
		candidate.free()
		return false
	started = HITCH.now()
	_preview = candidate
	_preview._reference_request_context = selected.get("source_bank_context",{}).duplicate(true)
	_preview._reference_card_context = selected.duplicate(true)
	_preview.source_selection_status = selected.duplicate(true)
	_preview.reference_bank_status["purpose"] = "existing_npc_consumer"
	_preview.reference_bank_status["host_policy"] = selected.host_policy
	HITCH.detail("view.context",started)
	started = HITCH.now()
	_preview._load_reference_overlay_bindings(selected)
	HITCH.detail("view.overlay_bindings",started)
	started = HITCH.now()
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
	HITCH.detail("view.attach",started)
	started = HITCH.now()
	var initial_frame: bool = _preview.advance_reference_source(0.0,"idle",posmod(2 + 3,8))
	HITCH.detail("view.first_frame",started)
	if not initial_frame:
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
	_clock += maxf(delta,0.0)
	if not _preview.advance_reference_source(maxf(delta,0.0),_role,posmod(facing + 3,8)):
		selection_status["status"] = "source_only_pending" if selection_status.get("source_only",false) else "source_input_unavailable"
		selection_status["reason"] = _preview.reference_bank_status.get("error","current523_npc_source_frame_unavailable")
		hide()
		return
	last_source_frame = _preview.last_source_frame
	var total: float = duration(_role)
	if _role == "attack" and (total <= 0.0 or _clock >= total): _source_attack = false

func source_frame_status() -> Dictionary:
	return _preview.reference_source_frame_status() if is_instance_valid(_preview) else {}

func notify_current_source_spell_event(spell: Dictionary, stage: String, point: Vector2, facing: int, context: Dictionary = {}) -> bool:
	# The combat owner keeps admission, hit timing, target and effect budgets.
	# This admitted actor exposes only the shared original-pixel presentation API.
	if not bool(selection_status.get("ok",false)) or not is_instance_valid(_preview) or not _preview.installed(): return false
	return _preview.notify_current_source_spell_event(spell,stage,point,facing,context)

func source_effect_status() -> Dictionary:
	return _preview.source_effect_status.duplicate(true) if is_instance_valid(_preview) else {}
