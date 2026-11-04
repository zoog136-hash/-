extends SceneTree
const CONTROLLER = preload("res://scripts/maps/current523_aden_play_controller.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
var checks: int = 0
var failures: Array[String] = []

class DisplayProbe extends FieldRenderer:
	var accept: bool = false
	var problem: String = "unsupported display correction"
	var delta := Vector2.ZERO
	var attempts: Array[Vector2] = []
	func set_visual_delta(value: Vector2) -> bool:
		attempts.append(value)
		if not accept: return false
		delta = value
		return true

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	if FileAccess.file_exists(OPTIONS.PATH):
		push_error("Controller guard requires an empty isolated user profile")
		quit(1)
		return
	var options: Dictionary = {"enabled":true,"navigation_profile":OPTIONS.LEGACY,"offset_x":0,"offset_y":0,"raw_root":"/fixture/raw","tile_root":"/fixture/tiles"}
	check(OPTIONS.write(options) == OK, "explicit local profile baseline saved")
	var before: String = FileAccess.get_sha256(OPTIONS.PATH)
	var display := DisplayProbe.new()
	var controller = CONTROLLER.new()
	controller.active = true
	controller.settings = options.duplicate(true)
	controller.set("_renderer", display)
	var changed: Dictionary = options.duplicate(true)
	changed.offset_y = 12
	check(not controller.apply_options(changed), "renderer rejection propagates to API result")
	check(FileAccess.get_sha256(OPTIONS.PATH) == before and OPTIONS.read() == options, "failed renderer application preserves all configuration bytes")
	check(controller.settings == options and display.delta == Vector2.ZERO, "failed application retains prior accepted settings")
	check(not controller.problem.is_empty(), "failed renderer application exposes a reason")
	display.accept = true
	check(controller.apply_options(changed), "successful correction applies and persists")
	check(OPTIONS.read().offset_y == 12 and display.delta == Vector2(0, 12), "saved correction matches actual accepted renderer state")
	check(controller.problem.is_empty(), "successful correction clears an earlier error")
	controller.active = false
	controller.set("_renderer", null)
	display.free()
	DirAccess.remove_absolute(OPTIONS.PATH)
	print("CURRENT523_ADEN_PLAY_CONTROLLER_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
