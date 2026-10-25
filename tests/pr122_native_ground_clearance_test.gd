extends SceneTree
## Negative controls for PR122 native-ground versus actual-prop classification.
const CLEARANCE = preload("res://tests/qa_rendered_prop_clearance.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("NATIVE_GROUND_CLEARANCE_FAIL: " + label)
func run() -> void:
	var renderer := NativePngRenderer.new()
	root.add_child(renderer)
	renderer.set_process(false)
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var tile := Sprite2D.new()
	tile.centered = false
	tile.texture = ImageTexture.create_from_image(image)
	tile.z_index = -20
	tile.set_meta("source_file","ground.png")
	tile.set_meta("source_position",[0,0])
	renderer.add_child(tile)
	var bounds := Rect2(0,0,8,8)
	check(not CLEARANCE.clear_bounds(renderer,bounds),"unregistered low-depth sprite is still a prop")
	renderer.chunks["ground.png"] = tile
	check(CLEARANCE.clear_bounds(renderer,bounds),"registered native base tile does not occlude actor")
	tile.set_meta("native_foreground","cutout")
	check(not CLEARANCE.clear_bounds(renderer,bounds),"foreground metadata overrides ground registration")
	tile.remove_meta("native_foreground")
	tile.z_index = 0
	check(not CLEARANCE.clear_bounds(renderer,bounds),"actor-depth source sprite is not ground")
	tile.z_index = -20
	tile.remove_meta("source_position")
	check(not CLEARANCE.clear_bounds(renderer,bounds),"incomplete source metadata fails closed")
	tile.set_meta("source_position",[0,0])
	renderer.chunks.erase("ground.png")
	renderer.chunks["ground.png#cutout"] = tile
	check(not CLEARANCE.clear_bounds(renderer,bounds),"suffixed cutout entry cannot masquerade as base tile")
	renderer.chunks.erase("ground.png#cutout")
	renderer.chunks["ground.png"] = tile
	var prop := Sprite2D.new()
	prop.centered = false
	prop.texture = tile.texture
	renderer.add_child(prop)
	check(not CLEARANCE.clear_bounds(renderer,bounds),"actual foreground overlap remains rejected")
	prop.position = Vector2(64,64)
	check(CLEARANCE.clear_bounds(renderer,bounds),"separate foreground does not overlap")
	prop.position = Vector2.ZERO
	prop.hide()
	check(CLEARANCE.clear_bounds(renderer,bounds),"existing hidden-prop policy is unchanged")
	prop.show()
	var nested := Node2D.new()
	renderer.add_child(nested)
	renderer.remove_child(prop)
	nested.add_child(prop)
	check(not CLEARANCE.clear_bounds(renderer,bounds),"nested foreground still participates in overlap")
	var ordinary := Node2D.new()
	root.add_child(ordinary)
	renderer.remove_child(tile)
	ordinary.add_child(tile)
	check(not CLEARANCE.clear_bounds(ordinary,bounds),"other renderers cannot use native source metadata to bypass props")
	ordinary.free()
	renderer.chunks.clear()
	renderer.free()
	print("NATIVE_GROUND_CLEARANCE_OK " if failures.is_empty() else "NATIVE_GROUND_CLEARANCE_FAILED ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
