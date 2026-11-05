extends Node2D
## Explicit source awakening state only. Native placement/blend remain compatible
## presentation, not a claim that Type48 is a universal VFX enum.
const VIEW = preload("res://scripts/animation/original_source_preview.gd")
const SOURCE = preload("res://scripts/lineagem_base508.gd")
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const RULES_PATH = "res://data/lineagem_base508/awakening_effects.json"
const CURRENT523 = preload("res://scripts/resources/current523_source_awakening_selection.gd")
var host: Node2D
var visual = VIEW.new()
var signature: String = ""
var settings: Dictionary = {}
var status: String = "inactive"
var sprite_id: int = 0
var selection_status: Dictionary = {}
var _source_bank_visual: bool = false

static func rule(category: String, record: Dictionary) -> Dictionary:
	# The retained registry is a bounded source relationship allowlist, not a
	# legacy pixel pack or permission to render saved card artwork.
	if not SOURCE.native(record): return {}
	var canonical_record: Dictionary = {}
	for candidate: Dictionary in SOURCE.cards().get("catalog", {}).get(category, []):
		if candidate.sourceId == record.get("sourceId", ""): canonical_record = candidate; break
	if canonical_record.is_empty(): return {}
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if not source is Dictionary: return {}
	for entry: Dictionary in source.get("rules", []):
		var row: Dictionary = entry.effect_row
		if int(row.BuffCardDeckID) == int(canonical_record.source_deck_id) and int(row.GradeID) == int(canonical_record.source_grade_id): return entry
	return {}

func configure(category: String, record: Dictionary, enabled: bool, target: Node2D, manifest: String, presentation: Dictionary) -> void:
	settings = presentation.duplicate(true)
	var binding: Dictionary = rule(category, record) if enabled else {}
	if binding.is_empty():
		deactivate(); return
	if not is_instance_valid(target) or not target.installed():
		deactivate(); status="source_host_pending"; return
	var mode: String = target.source_playback_mode()
	var context: Dictionary = target.source_bank_request_context() if target.has_method("source_bank_request_context") else {}
	if mode != "compatible":
		deactivate(); status="strict_unverified_composition"; return
	# The manifest argument remains part of the existing caller ABI. Current
	# pixels are selected exclusively from the pinned bank/context below.
	var selected: Dictionary = CURRENT523.select(category,record,binding,context)
	if not bool(selected.get("ok",false)):
		deactivate()
		selection_status = selected.duplicate(true)
		status = str(selected.get("reason","source_pixels_pending"))
		return
	var key: String = "%s:%s:%s:%s:%s:%s" % [str(record.sourceId),str(selected.sprite_id),str(target.get_instance_id()),str(selected.manifest_path),str(selected.manifest_sha256),mode]
	if signature == key and _source_bank_visual and visual.installed(): return
	deactivate()
	signature = key
	host = target
	sprite_id = int(binding.sprite_id)
	if get_parent() != target:
		if get_parent() != null: get_parent().remove_child(self)
		target.add_child(self)
	if visual.get_parent() == null: add_child(visual)
	visual.playback_mode_override = mode
	selection_status = selected.duplicate(true)
	var roles: Dictionary = selected.role_actions.duplicate()
	var loops: Dictionary = {"idle":bool(selected.loop_policy.idle)}
	var optional_walk: bool = selected.get("optional_role_actions",{}).has("walk")
	if optional_walk:
		roles["walk"] = int(selected.optional_role_actions.walk)
		loops["walk"] = bool(selected.loop_policy.walk)
	var configured: bool = visual._configure_reference_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),roles,loops,"idle","awakening")
	if not configured and optional_walk:
		selection_status["walk_status"] = "source_walk_unavailable; hide_on_movement"
		selection_status["walk_problem"] = str(visual.reference_bank_status.get("error","source_walk_inputs_unavailable"))
		roles = selected.role_actions.duplicate()
		loops = {"idle":bool(selected.loop_policy.idle)}
		configured = visual._configure_reference_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),roles,loops,"idle","awakening")
	if not configured:
		selection_status["status"] = "selection_pending"
		selection_status["reason"] = str(visual.reference_bank_status.get("error","source_pixels_pending"))
		status = "source_pixels_pending"
		return
	selection_status["role_actions"] = roles
	selection_status["loop_policy"] = loops
	visual._reference_overlay_parent = {"request_key":selected.request_key,"consumer":"awakening","manifest_sha256":selected.manifest_sha256,"source_snapshot":"patch523","source_reference":selected.source_reference.duplicate(true),"host_policy":selected.host_policy,"ancestor_actor_ids":[]}
	visual.source_selection_status = selection_status.duplicate(true)
	visual.reference_bank_status["purpose"] = "existing_enabled_source_awakening"
	_source_bank_visual = true
	status = "compatible_native_anchor_unverified_M_placement_and_blend"

func deactivate() -> void:
	signature = ""
	host = null
	sprite_id = 0
	_source_bank_visual = false
	selection_status.clear()
	visual.clear()
	status = "inactive"
	hide()

func apply_settings(value: Dictionary) -> void:
	settings = value.duplicate(true)

func _process(delta: float) -> void:
	if not _source_bank_visual or not is_instance_valid(host) or not host.installed() or not visual.installed() or not host.is_visible_in_tree(): hide(); return
	var role: String = "walk" if host.source_role() in ["walk", "run"] else "idle"
	# Missing walk pixels are not replaced with an invented idle/movement action.
	var available: bool = visual._playback_tracks.has(role)
	visible = available and host.visible and not bool(settings.get("reduced_motion", false)) and float(settings.get("impact_intensity", 1.0)) > 0.0
	if available:
		if not visual.advance_reference_source(delta,role,posmod(int(host.source_facing)+3,8)):
			status = "source_pixels_pending"
			hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(visual) and visual.get_parent() == null: visual.free()
