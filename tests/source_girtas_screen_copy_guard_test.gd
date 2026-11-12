extends SceneTree
## Production Girtas node configuration and visibility lifecycle only.
## No source pack, generated pixels, GPU execution or Android parity claim.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func fixture(mode: String = "compatible", body_id: int = 22258):
	var preview := PREVIEW.new()
	preview._playback_mode = mode
	root.add_child(preview)
	var frame: Dictionary = {"effect_layers":[
		{"layer_id":22260,"source_attributes":["8"]},
		{"layer_id":22261,"source_attributes":["128"]}]}
	check(preview._configure_source_nodes({"body_id":body_id}, {"idle":{"directions":[[frame]]}}, 0, ""), "production configuration accepts metadata fixture")
	return preview

func copies(preview: Node2D) -> Array:
	return preview.get_children().filter(func(node: Node) -> bool: return node is BackBufferCopy)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var previous: bool = COMPOSITOR.screen_copy_available
	COMPOSITOR.screen_copy_available = false
	var fallback = fixture()
	check(copies(fallback).is_empty(), "unavailable screen copy allocates no observed copy")
	check(fallback._effect_nodes.size() == 2, "fallback retains both original attachment nodes")
	for id: int in [22260,22261]:
		var node: Sprite2D = fallback._effect_nodes[id]
		var style: Dictionary = POLICY.effect(["8"] if id == 22260 else ["128"], "compatible")
		check(node.material is CanvasItemMaterial, "fallback uses existing policy material %d" % id)
		if node.material is CanvasItemMaterial:
			check(node.material.blend_mode == int(style.blend_mode) and is_equal_approx(node.modulate.a,float(style.alpha)), "fallback preserves policy blend and alpha %d" % id)
		check(not node.has_meta("observed_backbuffer"), "fallback retains no observed shader ownership %d" % id)
	fallback.free()

	COMPOSITOR.screen_copy_available = true
	var observed = fixture()
	check(copies(observed).size() == 2, "available screen copy retains scoped observation")
	for id: int in [22260,22261]:
		var node: Sprite2D = observed._effect_nodes[id]
		var copy: BackBufferCopy = node.get_meta("observed_backbuffer")
		check(node.material is ShaderMaterial, "observed shader retained %d" % id)
		check(copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "initial absent effect does not copy %d" % id)
		node.show()
		check(copy.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT, "visible effect enables its copy %d" % id)
		node.hide()
		check(copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "frame hide disables sibling copy %d" % id)
		node.show()
		observed.hide()
		check(copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "inherited hidden effect disables copy %d" % id)
		observed.show()
		check(copy.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT, "visible restoration reuses copy %d" % id)
		node.hide()
	var owned: Array = copies(observed)
	observed.clear()
	check(copies(observed).is_empty() and owned.all(func(node: Variant) -> bool: return not is_instance_valid(node)), "clear releases all observed copies")
	observed.free()

	for mode: String in ["strict", "compatible"]:
		var other = fixture(mode, 22258 if mode == "strict" else 28443)
		check(copies(other).is_empty(), "strict or unrelated body never acquires observed copies: " + mode)
		other.free()
	COMPOSITOR.screen_copy_available = previous
	print("SOURCE_GIRTAS_SCREEN_COPY_GUARD " + JSON.stringify({"checks":checks,"failures":failures,"scope":"production Girtas metadata configuration and copy visibility; no pixels or Android device"}))
	quit(0 if failures.is_empty() else 1)
