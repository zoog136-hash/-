extends SceneTree
## In 523 source play, combat is closed only while the hidden legacy actor
## root is the target set; with the source population's visible root, the
## attack button and auto hunting target its monsters (2026-11-14 report).
##   godot --headless --path <repo> --script res://tests/source_combat_targets_test.gd
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("SOURCE_COMBAT_TARGETS_FAIL: " + label)

class Controller extends RefCounted:
	var source_owned: bool = true

func _initialize() -> void:
	var world: Node = (load("res://scripts/world.gd") as GDScript).new()
	var legacy := Node2D.new()
	legacy.visible = false
	legacy.process_mode = Node.PROCESS_MODE_DISABLED
	var source := Node2D.new()
	world.set("monsters_root", legacy)
	check(not world._source_combat_targets_hidden(), "host play keeps combat open")
	world.set("current523_aden_play_active", true)
	world.set("_current523_aden_play_controller", Controller.new())
	check(world.current523_aden_source_active(), "source play is active in the fixture")
	check(world._source_combat_targets_hidden(), "the hidden legacy root never becomes a combat target set")
	world.set("monsters_root", source)
	check(not world._source_combat_targets_hidden(), "the attached 523 source actor root is a combat target set")
	source.visible = false
	check(world._source_combat_targets_hidden(), "a hidden root is never targeted")
	var text: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	for name: String in ["func _attack(", "func _nearest_visible_monster_in_weapon_range(", "func _nearest_reachable_monster(", "func _skill_target(", "func _deal_successful_player_hit(", "func _on_player_hit("]:
		var at: int = text.find(name)
		var body: String = text.substr(at, 400)
		check(at >= 0 and body.contains("_source_combat_targets_hidden()") and not body.contains("if current523_aden_source_active(): return"), name + " uses the hidden-root rule")
	legacy.free(); source.free(); world.free()
	print("SOURCE_COMBAT_TARGETS_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
