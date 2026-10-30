extends SceneTree

const QA = preload("res://tests/qa_rendered_prop_clearance.gd")
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Explicit QA geometry fixture; no actor art or production map is modified.
	# Reproduce the new renderer's nested chunk shape, absent from legacy faded.
	var renderer := Node2D.new()
	root.add_child(renderer)
	renderer.position = Vector2(50, 100)
	var chunk := Node2D.new()
	chunk.position = Vector2(25, 30)
	chunk.scale = Vector2(2, 2)
	renderer.add_child(chunk)
	var sprite := Sprite2D.new()
	sprite.position = Vector2(10, 20)
	sprite.centered = false
	var fixture := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	fixture.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(fixture)
	chunk.add_child(sprite)
	check(not QA.clear_bounds(renderer, Rect2(100, 175, 4, 4)), "nested chunk prop blocks a body with empty legacy faded inventory")
	check(QA.clear_bounds(renderer, Rect2(0, 0, 8, 8)), "distant body remains clear")
	sprite.visible = false
	check(QA.clear_bounds(renderer, Rect2(100, 175, 4, 4)), "hidden prop has no visible overlap")
	sprite.visible = true
	chunk.visible = false
	check(QA.clear_bounds(renderer, Rect2(100, 175, 4, 4)), "hidden ancestor has no visible overlap")
	chunk.visible = true
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite.texture
	atlas.region = Rect2(0, 0, 8, 8)
	atlas.margin = Rect2(4, 2, 8, 8)
	sprite.texture = atlas
	check(QA.clear_bounds(renderer, Rect2(96, 171, 2, 2)), "empty atlas padding does not count as a visible prop")
	check(not QA.clear_bounds(renderer, Rect2(104, 176, 2, 2)), "scaled atlas content blocks the actual body")
	sprite.texture = null
	check(QA.clear_bounds(renderer, Rect2(104, 176, 2, 2)), "textureless node cannot cover body")
	check(not QA.clear_bounds(null, Rect2()), "missing renderer cannot authorize a visual pass")
	print("RENDERED_PROP_CLEARANCE_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	if failures.is_empty(): print("RENDERED_PROP_CLEARANCE_OK")
	quit(0 if failures.is_empty() else 1)
