extends SceneTree

# Static terrain must not be re-drawn on the minimap's ~8 Hz refresh; only the
# overlay with moving markers redraws.
class FakePlayer extends Node2D:
	var camera := Camera2D.new()
	var facing: int = 0
	func _ready() -> void: add_child(camera)

class FakeWorld extends Node2D:
	var monsters_root := Node2D.new()
	var player := FakePlayer.new()
	var world_size := Vector2(2048, 2048)
	func _ready() -> void:
		add_child(monsters_root)
		add_child(player)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String] = []
	var world := FakeWorld.new()
	root.add_child(world)
	var minimap = preload("res://scripts/maps/field_minimap.gd").new()
	root.add_child(minimap)
	minimap.size = Vector2(222, 191)
	await process_frame
	minimap.configure(world, null)
	for frame: int in range(5): await process_frame
	var static_before: int = minimap.static_redraws
	var overlay_before: int = minimap.overlay_redraws
	await create_timer(0.7).timeout
	for frame: int in range(3): await process_frame
	if minimap.static_redraws != static_before:
		failures.append("static terrain redrew %d times while idle" % (minimap.static_redraws - static_before))
	if minimap.overlay_redraws <= overlay_before:
		failures.append("overlay did not refresh markers")
	if static_before < 1: failures.append("static layer never drew")
	print("MINIMAP_STATIC_LAYER_RESULT ", JSON.stringify({"failures":failures, "static":minimap.static_redraws, "overlay":minimap.overlay_redraws}))
	quit(0 if failures.is_empty() else 1)
