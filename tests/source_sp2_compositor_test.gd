extends SceneTree
## P02 integer kernels and P13 shadow flags from the restored 525 client.
## These checks do not assert native 523/Android visual equivalence. Procedural
## texels below are test inputs only; no replacement game art is produced.
const COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
var checks: int = 0
var errors: Array[String] = []
var render_checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok and errors.size() < 30: errors.append(message)

func reference(destination: int, source: int, operation: int) -> int:
	var out: int = 0
	for channel: int in 3:
		var shift: int = [11, 5 if operation == 0 else 6, 0][channel]
		var maximum: int = 63 if channel == 1 and operation == 0 else 31
		var d: int = (destination >> shift) & maximum
		var s: int = (source >> shift) & maximum
		var value: int = 0
		match operation:
			0: value = (d + s) / 2
			1: value = d + s - (d * s) / 31
			2: value = (d * s) / 31
		out |= value << shift
	return out

func arithmetic() -> void:
	check(COMPOSITOR.blend565(0xFFFF, 0xFFFF, 0) == 0xFFFF, "average white remains white")
	check(COMPOSITOR.blend565(0xFFFF, 0, 0) == 0x7BEF, "black shadow averages destination rather than replacing it")
	check(COMPOSITOR.blend565(0, 0xFFFF, 0) == 0x7BEF, "average truncates each RGB565 channel")
	check(COMPOSITOR.blend565(0x0020, 0x0020, 0) == 0x0020, "average keeps the sixth green bit")
	check(COMPOSITOR.blend565(0xFFFF, 0xFFFF, 2) == 0xFFDF, "multiply white discards the low green bit")
	check(COMPOSITOR.blend565(0xFFFF, 0, 2) == 0, "black multiply differs from half opacity MIX")
	check(COMPOSITOR.blend565(0xFFFF, 0, 1) == 0xFFDF, "zero source screen is processed, including green quantization")
	check(COMPOSITOR.blend565(0x8410, 0x8410, 1) != 0xFFFF, "screen differs from saturated ADD")
	# Exhaust the individual channel domains, including G6 in average. Inputs
	# are assembled independently of the production kernel's packed arithmetic.
	for operation: int in 3:
		for channel: int in 3:
			var shift: int = [11, 5 if operation == 0 else 6, 0][channel]
			var domain: int = 64 if channel == 1 and operation == 0 else 32
			for d: int in domain:
				for s: int in domain:
					var destination: int = d << shift
					var source: int = s << shift
					check(COMPOSITOR.blend565(destination, source, operation) == reference(destination, source, operation), "channel kernel %d/%d/%d/%d" % [operation, channel, d, s])
	var random := RandomNumberGenerator.new()
	random.seed = 0x20261112
	for index: int in 2048:
		var destination: int = random.randi_range(0, 65535)
		var source: int = random.randi_range(0, 65535)
		for operation: int in 3:
			check(COMPOSITOR.blend565(destination, source, operation) == reference(destination, source, operation), "packed arithmetic %d/%d" % [index, operation])
			if operation != 0:
				check(COMPOSITOR.blend565(destination ^ 0x20, source ^ 0x20, operation) == reference(destination, source, operation), "screen/multiply ignore physical green bit5")

func policies() -> void:
	for item: Dictionary in [{"kind":"shadow","source_attributes":[]}, {"kind":"clothes","source_attributes":["8"]}, {"kind":"clothes","source_attributes":["128"]}]:
		var style: Dictionary = COMPOSITOR.style(item, [], false, "compatible")
		var expected: int = 0 if item.kind == "shadow" else (1 if item.source_attributes == ["8"] else 2)
		check(style.get("operation", -1) == expected, "source layer selects its documented kernel")
		check(style.get("flags", -1) == [1, 8, 128][expected], "effective native flags are retained")
		check(not str(style.get("origin", "")).is_empty(), "style retains evidence origin")
		check(COMPOSITOR.style(item, [], false, "strict").is_empty(), "strict mode retains its existing policy")
		var unresolved: Dictionary = item.duplicate(true)
		unresolved.source_attributes_unresolved = true
		check(COMPOSITOR.style(unresolved, [], false, "compatible").is_empty(), "unresolved layer attributes never select a kernel")
	check(COMPOSITOR.style({"kind":"shadow","source_attributes":[]}, [], true, "compatible").is_empty(), "unresolved body flags never select shadow average")
	check(COMPOSITOR.style({"kind":"shadow","source_attributes":["128"]}, ["32768"], false, "compatible").get("operation", -1) == 0, "shadow clears parent8000 and adds1, independent of its own attr")
	check(COMPOSITOR.style({"kind":"shadow"}, ["8"], false, "compatible").is_empty(), "shadow combined flags9 remain outside the narrow adapter")
	for attributes: Array in [[], ["0"], ["4"], ["1", "8"], ["128", "8"], ["512"], ["64"], ["4096"], ["unknown"]]:
		check(COMPOSITOR.style({"kind":"clothes","source_attributes":attributes}, [], false, "compatible").is_empty(), "unmapped attributes retain the previous renderer: " + str(attributes))

func copies(sprite: Sprite2D) -> Array[BackBufferCopy]:
	var out: Array[BackBufferCopy] = []
	for child: Node in sprite.get_children():
		if child is BackBufferCopy: out.append(child)
	return out

func texture_and_reset() -> void:
	var image := Image.create_empty(3, 2, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0.4, 0.2, 0.7, 1))
	image.set_pixel(1, 0, Color(0.9, 0.1, 0.6, 0))
	image.set_pixel(2, 1, Color(0.2, 0.8, 0.3, 1))
	var before: PackedByteArray = image.get_data().duplicate()
	var texture := ImageTexture.create_from_image(image)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.position = Vector2(17, 19)
	sprite.scale = Vector2(1.5, 1.5)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	root.add_child(viewport)
	var parent := Node2D.new()
	viewport.add_child(parent)
	parent.add_child(sprite)
	for attributes: Array in [["8"], ["128"], ["8"]]:
		COMPOSITOR.apply(sprite, COMPOSITOR.style({"kind":"clothes","source_attributes":attributes}, [], false, "compatible"))
		check(sprite.material is ShaderMaterial, "source composition attaches a shader")
		var copy_nodes: Array[BackBufferCopy] = copies(sprite)
		check(copy_nodes.size() == 1, "one backbuffer copy per reused sprite")
		if copy_nodes.size() == 1:
			check(copy_nodes[0].show_behind_parent, "copy precedes the sprite draw")
			check(copy_nodes[0].copy_mode == BackBufferCopy.COPY_MODE_RECT, "copy is bounded to the sprite region")
			check(copy_nodes[0].rect == Rect2(17, 19, 5, 3), "copy uses outward rounded viewport coordinates in Godot4.7.2")
			check((sprite.get_global_transform_with_canvas() * copy_nodes[0].transform).is_equal_approx(Transform2D.IDENTITY), "copy transform cancels actor and canvas transforms")
		check(sprite.texture == texture and sprite.texture.get_image().get_data() == before and image.get_data() == before, "source texture bytes remain unchanged")
		check(sprite.position == Vector2(17, 19) and sprite.scale == Vector2(1.5, 1.5), "source origin and scale remain unchanged")
	# Reusing the same node with a different source frame must move the
	# copy region with its exact source rectangle, without replacing pixels.
	sprite.centered = true
	sprite.offset = Vector2(-4, 7)
	COMPOSITOR.apply(sprite, COMPOSITOR.style({"kind":"clothes","source_attributes":["8"]}, [], false, "compatible"))
	check(copies(sprite).size() == 1 and copies(sprite)[0].rect == Rect2(8, 28, 6, 3), "copy bounds follow the centered source origin and frame geometry")
	var copy: BackBufferCopy = copies(sprite)[0]
	var next_parent := Node2D.new()
	viewport.add_child(next_parent)
	sprite.reparent(next_parent)
	check(RenderingServer.frame_pre_draw.is_connected(Callable(copy, "_refresh_region")), "copy reconnects pre-draw when the source is reparented")
	sprite.reparent(parent)
	check(RenderingServer.frame_pre_draw.is_connected(Callable(copy, "_refresh_region")), "copy reconnects on every tree entry, not only its first ready")
	sprite.centered = false
	sprite.offset = Vector2.ZERO
	parent.position = Vector2(11, 13)
	copy.call("_refresh_region") # Headless has no frame_pre_draw GPU callback.
	check(copy.rect == Rect2(28, 32, 5, 3), "parent-only motion refreshes copy bounds without applying a new source frame")
	viewport.canvas_transform = Transform2D(0, Vector2(-5, -7))
	copy.call("_refresh_region")
	check(copy.rect == Rect2(23, 25, 5, 3), "camera-only motion refreshes viewport bounds without source reapply")
	check((sprite.get_global_transform_with_canvas() * copy.transform).is_equal_approx(Transform2D.IDENTITY), "copy keeps identity canvas transform after parent and camera motion")
	check(sprite.position == Vector2(17, 19) and sprite.scale == Vector2(1.5, 1.5), "camera compensation never moves or scales source art")
	viewport.size_2d_override = Vector2i(64, 64)
	viewport.size_2d_override_stretch = true
	copy.call("_refresh_region")
	check(copy.rect == Rect2(46, 50, 9, 6), "copy bounds include the final SubViewport canvas stretch")
	check((sprite.get_viewport_transform() * sprite.global_transform * copy.transform).is_equal_approx(Transform2D.IDENTITY), "copy transform cancels final viewport stretch as well as actor motion")
	viewport.size_2d_override_stretch = false
	viewport.size_2d_override = Vector2i.ZERO
	parent.position = Vector2(-1000, -1000)
	copy.call("_refresh_region")
	check(copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "offscreen source never issues an empty full-viewport copy")
	parent.position = Vector2.ZERO
	sprite.hide()
	copy.call("_refresh_region")
	check(copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "hidden source disables its retained copy")
	sprite.show()
	copy.call("_refresh_region")
	check(copy.copy_mode == BackBufferCopy.COPY_MODE_RECT and copy.rect.has_area(), "visible source resumes a bounded copy without a source frame change")
	COMPOSITOR.apply(sprite, {})
	await process_frame
	check(sprite.material == null and copies(sprite).size() <= 1 and copies(sprite).all(func(copy: BackBufferCopy) -> bool: return copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED), "empty style removes stale shader and disables its reusable copy")
	COMPOSITOR.reset(sprite)
	await process_frame
	check(sprite.material == null and copies(sprite).size() <= 1 and copies(sprite).all(func(copy: BackBufferCopy) -> bool: return copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED), "reset is repeatable without allocating live copies")
	viewport.free()

func rgb565(value: int) -> Color:
	var r: int = (value >> 11) & 31
	var g: int = (value >> 5) & 63
	var b: int = value & 31
	return Color(float((r << 3) | (r >> 2)) / 255.0, float((g << 2) | (g >> 4)) / 255.0, float((b << 3) | (b >> 2)) / 255.0, 1)

func uniform_texture(value: int) -> ImageTexture:
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(rgb565(value))
	return ImageTexture.create_from_image(image)

func render_fixture() -> void:
	if DisplayServer.get_name() == "headless":
		errors.append("--render requires an actual renderer; headless is not a pixel validation")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(8, 8)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := Sprite2D.new()
	background.centered = false
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.scale = Vector2(4, 4)
	viewport.add_child(background)
	var first := Sprite2D.new()
	first.centered = false
	first.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	first.scale = Vector2(4, 4)
	viewport.add_child(first)
	var second := Sprite2D.new()
	second.centered = false
	second.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	second.scale = Vector2(4, 4)
	viewport.add_child(second)
	for destination: int in [0, 0xFFFF, 0x8410, 0x7BEF, 0x0020]:
		background.texture = uniform_texture(destination)
		for source: int in [0, 0xFFFF, 0x8410, 0x0421]:
			first.texture = uniform_texture(source)
			for operation: int in 3:
				var style: Dictionary = {"operation":operation,"flags":[1,8,128][operation],"origin":"regression_test_only"}
				COMPOSITOR.apply(first, style)
				second.hide()
				await process_frame
				await RenderingServer.frame_post_draw
				var actual: Color = viewport.get_texture().get_image().get_pixel(2, 2)
				var expected: Color = rgb565(reference(destination, source, operation))
				render_checks += 1
				check(actual.to_rgba32() == expected.to_rgba32(), "OpenGL pixel %04x/%04x/%d: %s != %s" % [destination,source,operation,actual,expected])
				# A second source sprite must sample the first sprite's result,
				# not reuse a viewport copy taken before both were drawn.
				second.texture = uniform_texture(0x8410)
				COMPOSITOR.apply(second, {"operation":2,"flags":128,"origin":"regression_test_only"})
				second.show()
				await process_frame
				await RenderingServer.frame_post_draw
				actual = viewport.get_texture().get_image().get_pixel(2, 2)
				expected = rgb565(reference(reference(destination, source, operation), 0x8410, 2))
				render_checks += 1
				check(actual.to_rgba32() == expected.to_rgba32(), "OpenGL chained source layers retain draw order")
	# Transparent coverage is absent even when hidden RGB is nonzero. A
	# covered black sample above is still processed by every native kernel.
	second.hide()
	background.texture = uniform_texture(0xFFFF)
	var transparent := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	transparent.fill(Color(1, 0.5, 0.25, 0))
	first.texture = ImageTexture.create_from_image(transparent)
	COMPOSITOR.apply(first, {"operation":2,"flags":128,"origin":"regression_test_only"})
	await process_frame
	await RenderingServer.frame_post_draw
	render_checks += 1
	check(viewport.get_texture().get_image().get_pixel(2, 2).to_rgba32() == rgb565(0xFFFF).to_rgba32(), "OpenGL transparent texel preserves destination rather than rendering hidden RGB")
	# Reset must restore ordinary source draw rather than leave an old shader.
	second.hide()
	COMPOSITOR.apply(first, {})
	first.texture = uniform_texture(0xF800)
	await process_frame
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().get_pixel(2, 2).to_rgba32() == rgb565(0xF800).to_rgba32(), "OpenGL reset removes stale source composition")
	# Only the camera/parent moves: the installed material and frame do not
	# change. frame_pre_draw must update the raw viewport copy rectangle.
	background.texture = uniform_texture(0xFFFF)
	first.position = Vector2(2, 2)
	first.scale = Vector2(2, 2)
	first.texture = uniform_texture(0)
	COMPOSITOR.apply(first, {"operation":0,"flags":1,"origin":"regression_test_only"})
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.canvas_transform = Transform2D(0, Vector2(-1, 0))
	await process_frame
	await RenderingServer.frame_post_draw
	var moving_copy: BackBufferCopy = copies(first)[0]
	check(moving_copy.rect == Rect2(1, 2, 4, 4), "OpenGL pre-draw tracks camera-only movement without reapply")
	render_checks += 1
	check(viewport.get_texture().get_image().get_pixel(1, 3).to_rgba32() == rgb565(0x7BEF).to_rgba32(), "OpenGL camera-only movement samples the new viewport region")
	var moving_parent := Node2D.new()
	viewport.add_child(moving_parent)
	first.reparent(moving_parent)
	moving_parent.position = Vector2(1, 1)
	await process_frame
	await RenderingServer.frame_post_draw
	check(moving_copy.rect == Rect2(2, 3, 4, 4), "OpenGL pre-draw tracks parent-only movement without reapply")
	render_checks += 1
	check(viewport.get_texture().get_image().get_pixel(2, 3).to_rgba32() == rgb565(0x7BEF).to_rgba32(), "OpenGL parent-only movement samples the new viewport region")
	viewport.size_2d_override = Vector2i(4, 4)
	viewport.size_2d_override_stretch = true
	await process_frame
	await RenderingServer.frame_post_draw
	check(moving_copy.rect == Rect2(4, 6, 4, 2), "OpenGL copy bounds include final stretch and clip to framebuffer size")
	render_checks += 1
	check(viewport.get_texture().get_image().get_pixel(4, 6).to_rgba32() == rgb565(0x7BEF).to_rgba32(), "OpenGL stretched viewport samples its correctly transformed source region")
	viewport.free()

func run() -> void:
	arithmetic()
	policies()
	await texture_and_reset()
	if "--render" in OS.get_cmdline_user_args(): await render_fixture()
	print("SOURCE_SP2_COMPOSITOR " + JSON.stringify({"checks":checks,"render_checks":render_checks,"errors":errors,"failures":errors,"scope":"P02 integer kernels and narrow P13 flags; synthetic regression inputs; not native523 or Android equivalence"}))
	quit(0 if errors.is_empty() else 1)
