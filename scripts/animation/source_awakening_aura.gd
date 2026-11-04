extends Node2D
## Explicit source awakening state only. Native placement/blend remain compatible
## presentation, not a claim that Type48 is a universal VFX enum.
const VIEW = preload("res://scripts/animation/original_source_preview.gd")
const SOURCE = preload("res://scripts/lineagem_base508.gd")
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const RULES_PATH = "res://data/lineagem_base508/awakening_effects.json"
var host: Node2D
var visual = VIEW.new()
var signature: String = ""
var settings: Dictionary = {}
var status: String = "inactive"
var sprite_id: int = 0

static func rule(category: String, record: Dictionary) -> Dictionary:
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
	if binding.is_empty() or not is_instance_valid(target) or not target.installed():
		deactivate(); return
	var mode: String = target.source_playback_mode()
	var path: String = INSTALL.resolve_file(manifest.get_base_dir(), "awakening/manifest.json")
	var key: String = "%s:%s:%s:%s" % [str(record.sourceId), str(binding.sprite_id), str(target.get_instance_id()), path + mode]
	if signature == key: return
	deactivate()
	signature = key
	host = target
	sprite_id = int(binding.sprite_id)
	if mode != "compatible": status = "strict_unverified_composition"; return
	if not FileAccess.file_exists(path): status = "awakening_pack_not_installed"; return
	if get_parent() != target:
		if get_parent() != null: get_parent().remove_child(self)
		target.add_child(self)
	if visual.get_parent() == null: add_child(visual)
	visual.playback_mode_override = mode
	if not visual.configure("sprite:" + str(sprite_id), path):
		status = "source_pixels_pending"; return
	status = "compatible_native_anchor_unverified_M_placement_and_blend"

func deactivate() -> void:
	signature = ""
	host = null
	sprite_id = 0
	visual.clear()
	status = "inactive"
	hide()

func apply_settings(value: Dictionary) -> void:
	settings = value.duplicate(true)

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not host.installed() or not visual.installed() or not host.is_visible_in_tree(): hide(); return
	var role: String = "walk" if host.source_role() in ["walk", "run"] else "idle"
	# Missing walk pixels are not replaced with an invented idle/movement action.
	var available: bool = visual._playback_tracks.has(role)
	visible = available and host.visible and not bool(settings.get("reduced_motion", false)) and float(settings.get("impact_intensity", 1.0)) > 0.0
	if available: visual.advance_source(delta, role, host.source_facing, 0, false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(visual) and visual.get_parent() == null: visual.free()
