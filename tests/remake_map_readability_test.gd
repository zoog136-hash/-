extends SceneTree
## Exercise the shipped art, offsets and map records at a real viewport boundary.
const FIELD = preload("res://scripts/maps/playable_field.gd")
const RENDERER = preload("res://scripts/maps/field_renderer.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("REMAKE_MAP_READABILITY_FAIL "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var field := FIELD.new()
	field.configure(CATALOG.apply_map(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_field.json"))))
	var actor := Node2D.new()
	root.add_child(actor)
	var renderer := RENDERER.new()
	root.add_child(renderer)
	actor.position = Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	renderer.configure(field,actor)
	renderer.set_process(false)
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	# This existing 627px tower starts in chunk y=8, beyond the old 360px
	# streaming margin, while its roof is still visible inside the viewport.
	var record: Dictionary = {}
	for candidate: Dictionary in field.data.props:
		if candidate.kind == "tower" and Vector2(candidate.position[0],candidate.position[1]) == Vector2(45470,8300): record = candidate; break
	check(not record.is_empty(),"existing Aden tower probe is present")
	if record.is_empty(): quit(1); return
	var anchor := Vector2(record.position[0],record.position[1])
	var key := Vector2i((anchor/renderer.chunk_size).floor())
	var view := Rect2(anchor.x-640,7030,1280,720)
	root.canvas_transform = Transform2D(0,-view.position)
	actor.position = view.get_center()
	renderer.refresh_visible()
	var old_margin: Rect2 = view.grow(float(field.data.streaming.margin))
	check(not old_margin.intersects(Rect2(Vector2(key)*renderer.chunk_size,Vector2.ONE*renderer.chunk_size)),"probe lies beyond old anchor-only culling")
	check(renderer.chunks.has(key),"visible roof keeps its foot-anchor chunk loaded")
	check(renderer.chunks.size()<25,"overhang-aware streaming remains local")
	var tower: Sprite2D
	var canopy: Sprite2D
	for chunk: Node2D in renderer.chunks.values():
		for node: Node in chunk.get_children():
			if not node is Sprite2D: continue
			var sprite: Sprite2D = node
			if sprite.position == anchor: tower = sprite
			if str(sprite.get_meta("prop_kind","")) in ["oak","oak2","pine","birch"]: canopy = sprite
	check(tower != null,"existing tower art is instantiated")
	if tower != null:
		var predicted: Rect2 = renderer._prop_extent(record)
		predicted.position += anchor
		var actual: Rect2 = tower.global_transform*tower.get_rect()
		check(predicted.is_equal_approx(actual),"streaming extent matches actual sprite scale/offset")
		check(actual.intersects(view),"tower roof really overlaps visible viewport")
		# Actor stands behind the right edge, outside the old 34%-width box.
		actor.position = Vector2(actual.end.x-8,anchor.y-100)
		check(absf(actor.position.x-anchor.x)>float(tower.get_meta("visual_size").x)*.34,"edge probe reproduces former fade gap")
		check(renderer.occludes_player(tower),"roof edge protects actor silhouette")
		renderer.stream_clock = 100
		renderer._process(.3)
		check(tower.modulate.a<.8,"foreground alpha actually decreases at roof edge")
		actor.position = anchor+Vector2(0,80)
		renderer._process(.3)
		check(is_equal_approx(tower.modulate.a,1.0),"front-facing actor restores opaque prop")
		actor.position = Vector2(actual.end.x+100,anchor.y-100)
		check(not renderer.occludes_player(tower),"unrelated nearby props stay opaque")
	if canopy != null:
		actor.position = canopy.position+Vector2(0,-95)
		check(renderer.occludes_player(canopy),"existing centered canopy fade is preserved")
	for zoom_value: float in [.65,1.0,1.4]:
		view = Rect2(Vector2(anchor.x-640/zoom_value,7750-720/zoom_value),Vector2(1280,720)/zoom_value)
		var transform := Transform2D.IDENTITY.scaled(Vector2.ONE*zoom_value)
		transform.origin = -view.position*zoom_value
		root.canvas_transform = transform
		actor.position = view.get_center()
		renderer.refresh_visible()
		check(renderer.chunks.has(key),"visible roof remains loaded at camera zoom "+str(zoom_value))
		check(renderer.chunks.size()<25,"zoomed culling retains bounded local chunks")
		for loaded: Vector2i in renderer.chunks:
			var chunk_bounds: Rect2 = renderer.bucket_bounds.get(loaded,Rect2(Vector2(loaded)*renderer.chunk_size,Vector2.ONE*renderer.chunk_size))
			check(chunk_bounds.intersects(view.grow(float(field.data.streaming.margin))),"loaded chunk contributes within view/margin")
	# Culling is reversible; the roof's offscreen anchor does not become pinned.
	root.canvas_transform = Transform2D(0,-Vector2(1200,4000))
	actor.position = Vector2(1840,4360)
	renderer.refresh_visible()
	check(not renderer.chunks.has(key),"distant roof chunk unloads again")
	renderer.free()
	actor.free()
	print("REMAKE_MAP_READABILITY_OK " if failures.is_empty() else "REMAKE_MAP_READABILITY_FAILED ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
