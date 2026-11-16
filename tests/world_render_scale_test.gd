extends SceneTree
## Android 90% world render scale: only on with the mobile flag, CanvasLayer
## UI stays native and screen <-> world mapping is unchanged.
##   godot --headless --path <repo> --script res://tests/world_render_scale_test.gd
##   xvfb-run -a godot --path <repo> --rendering-method gl_compatibility --script res://tests/world_render_scale_test.gd -- --render
const SCALE = preload("res://scripts/boot/world_render_scale.gd")
var checks: int = 0
var failures: Array[String] = []
var rendered: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("WORLD_RENDER_SCALE_FAIL: " + label)

func near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.01

## Phone-like host: 1920x1080 render target showing a 1280x720 canvas_items
## base (2400x1080 screen with aspect keep), the same stretch the root has.
func make_host() -> SubViewport:
	var host := SubViewport.new()
	host.size = Vector2i(1920, 1080)
	host.size_2d_override = Vector2i(1280, 720)
	host.size_2d_override_stretch = true
	host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(host)
	return host

func make_world(parent: Node) -> Dictionary:
	var world := Node2D.new()
	world.name = "World"
	parent.add_child(world)
	var camera := Camera2D.new()
	camera.position = Vector2(3000, 1800)
	camera.zoom = Vector2(1.25, 1.25)
	world.add_child(camera)
	var hud := CanvasLayer.new()
	hud.layer = 20
	world.add_child(hud)
	var label := Label.new()
	label.text = "HUD"
	hud.add_child(label)
	return {"world":world, "camera":camera, "hud":hud, "label":label}

func screen_to_world(world: Node2D, screen: Vector2) -> Vector2:
	return world.make_canvas_position_local(screen)

func _initialize() -> void:
	await process_frame
	if "--render" in OS.get_cmdline_user_args():
		await _render_check()
	else:
		await _logic_check()
	print("WORLD_RENDER_SCALE_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "rendered":rendered}))
	SCALE.force_mode = -1
	quit(0 if failures.is_empty() else 1)

func _logic_check() -> void:
	check(is_equal_approx(SCALE.RENDER_SCALE, 0.9), "one render scale constant, 0.9")
	check(FileAccess.get_file_as_string("res://scripts/world.gd").contains('preload("res://scripts/boot/world_render_scale.gd").new()'), "World installs the render scale node")
	# Automatic mode follows the Android flag only.
	SCALE.force_mode = -1
	check(SCALE.wanted() == OS.has_feature("android"), "automatic mode is the Android flag")
	SCALE.force_mode = 0
	check(not SCALE.wanted(), "forced off")
	SCALE.force_mode = 1
	check(SCALE.wanted(), "forced on (mobile test hook)")

	# Off: nothing changes.
	SCALE.force_mode = 0
	var host: SubViewport = make_host()
	var parts: Dictionary = make_world(host)
	var world: Node2D = parts.world
	await process_frame
	await process_frame
	var mask_before: int = host.canvas_cull_mask
	var canvas_before: Transform2D = host.canvas_transform
	check(not canvas_before.is_equal_approx(Transform2D.IDENTITY), "camera drives the root canvas transform: " + str(canvas_before))
	var probes: Array[Vector2] = [Vector2(0, 0), Vector2(640, 360), Vector2(1279, 719), Vector2(211.5, 603.25)]
	var world_before: Array[Vector2] = []
	for p: Vector2 in probes: world_before.append(screen_to_world(world, p))
	var off = SCALE.new()
	world.add_child(off)
	check(not off.active and off.viewport == null and off.get_child_count() == 0, "flag off: no SubViewport or display")
	check(world.visibility_layer == 1 and host.canvas_cull_mask == mask_before, "flag off: world layer and root mask untouched")
	off.free()

	# On.
	SCALE.force_mode = 1
	var scaler = SCALE.new()
	world.add_child(scaler)
	check(scaler.active and scaler.viewport != null, "flag on: scaler active")
	check(SCALE.render_target_size(host) == Vector2(1920, 1080), "render target is the stretched 1920x1080: " + str(SCALE.render_target_size(host)))
	check(scaler.viewport.size == Vector2i(1728, 972), "world SubViewport is 90%: " + str(scaler.viewport.size))
	var pixel_ratio: float = float(scaler.viewport.size.x * scaler.viewport.size.y) / (1920.0 * 1080.0)
	check(absf(pixel_ratio - 0.81) < 0.001, "world pixels drop to 81%: " + str(pixel_ratio))
	check(scaler.viewport.world_2d == host.world_2d, "SubViewport draws the same World2D (no reparenting)")
	check(world.visibility_layer == SCALE.WORLD_VISIBILITY_BIT, "World moved to the world visibility layer")
	check(host.canvas_cull_mask & SCALE.WORLD_VISIBILITY_BIT == 0 and host.canvas_cull_mask | SCALE.WORLD_VISIBILITY_BIT == mask_before | SCALE.WORLD_VISIBILITY_BIT, "root stops drawing only the world layer")
	check(scaler.viewport.canvas_cull_mask & SCALE.WORLD_VISIBILITY_BIT != 0 and scaler.viewport.canvas_cull_mask & 1 != 0, "SubViewport draws the world and its default-layer children")
	check(scaler.viewport.gui_disable_input and not scaler.viewport.physics_object_picking, "SubViewport takes no input or picking")
	# UI is not scaled.
	var hud: CanvasLayer = parts.hud
	var label: Label = parts.label
	check(hud.get_viewport() == host and label.get_viewport() == host, "HUD layer stays in the root viewport")
	check(hud.scale == Vector2.ONE and hud.transform == Transform2D.IDENTITY, "HUD layer transform untouched")
	check(label.visibility_layer == 1 and host.canvas_cull_mask & 1 != 0, "HUD controls stay on the drawn default layer")
	check(label.get_global_transform_with_canvas() == Transform2D.IDENTITY, "HUD label keeps its native placement")
	check(scaler.layer.get_viewport() == host and scaler.layer.layer < hud.layer and scaler.layer.layer < 0, "scaled world sits under every UI layer")
	check(scaler.display.mouse_filter == Control.MOUSE_FILTER_IGNORE, "scaled world image never eats touches")
	check(scaler.display.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "scaled world image is filtered")
	# Camera moves are copied just before draw.
	var camera: Camera2D = parts.camera
	camera.position += Vector2(-150, 75)
	await process_frame
	await process_frame
	scaler.sync()
	check(scaler.viewport.canvas_transform == host.canvas_transform, "SubViewport follows the root camera")
	check(scaler.display.size == host.get_visible_rect().size and scaler.display.position == Vector2.ZERO, "scaled world image covers the visible rect")
	# Screen -> world and world -> screen are unchanged.
	camera.position -= Vector2(-150, 75)
	await process_frame
	await process_frame
	scaler.sync()
	check(host.canvas_transform == canvas_before, "root canvas transform is the same as with the flag off")
	for i: int in probes.size():
		var w: Vector2 = screen_to_world(world, probes[i])
		check(near(w, world_before[i]), "touch %s maps to the same world point: %s vs %s" % [probes[i], w, world_before[i]])
		var target: Vector2 = host.get_stretch_transform() * (host.global_canvas_transform * (host.canvas_transform * w))
		check(near(scaler.scaled_world_to_target(w), target), "world point %s is drawn at the same screen pixel: %s vs %s" % [w, scaler.scaled_world_to_target(w), target])
	# Top-level world nodes follow; nodes outside World do not.
	var flight := Node2D.new()
	flight.set_as_top_level(true)
	world.add_child(flight)
	SCALE.follow_world(flight)
	check(flight.visibility_layer == SCALE.WORLD_VISIBILITY_BIT, "top-level world node follows the world layer")
	var outside := Node2D.new()
	outside.set_as_top_level(true)
	host.add_child(outside)
	SCALE.follow_world(outside)
	check(outside.visibility_layer == 1, "nodes outside World keep their layer")
	# Leaving the tree restores everything.
	scaler.queue_free()
	await process_frame
	check(world.visibility_layer == 1 and host.canvas_cull_mask == mask_before, "removing the scaler restores layer and mask")
	SCALE.follow_world(flight)
	host.queue_free()
	await process_frame

## GL: the scaled world is drawn at the same place, the root draws no world
## pixels itself and the HUD stays crisp in the root.
func _render_check() -> void:
	SCALE.force_mode = 1
	var win: Window = root
	var world := Node2D.new()
	root.add_child(world)
	var block := ColorRect.new()
	block.color = Color(1, 0, 0)
	block.position = Vector2(200, 200)
	block.size = Vector2(100, 100)
	world.add_child(block)
	var top := Node2D.new()
	world.add_child(top)
	var top_rect := ColorRect.new()
	top_rect.color = Color(0, 0, 1)
	top_rect.position = Vector2(600, 200)
	top_rect.size = Vector2(100, 100)
	top.add_child(top_rect)
	top.set_as_top_level(true)
	var hud := CanvasLayer.new()
	hud.layer = 20
	world.add_child(hud)
	var ui := ColorRect.new()
	ui.color = Color(0, 1, 0)
	ui.position = Vector2(900, 200)
	ui.size = Vector2(100, 100)
	hud.add_child(ui)
	var scaler = SCALE.new()
	world.add_child(scaler)
	SCALE.follow_world(top)
	for i: int in 4: await process_frame
	var image: Image = win.get_texture().get_image()
	var factor: Vector2 = SCALE.render_target_size(win) / win.get_visible_rect().size
	rendered["target"] = str(SCALE.render_target_size(win))
	rendered["sub"] = str(scaler.viewport.size)
	check(_color_at(image, Vector2(250, 250) * factor).is_equal_approx(Color(1, 0, 0)), "world block drawn at its place: " + str(_color_at(image, Vector2(250, 250) * factor)))
	check(_color_at(image, Vector2(650, 250) * factor).is_equal_approx(Color(0, 0, 1)), "top-level world node drawn at its place")
	check(_color_at(image, Vector2(950, 250) * factor).is_equal_approx(Color(0, 1, 0)), "HUD drawn")
	var sub_image: Image = scaler.viewport.get_texture().get_image()
	check(_color_at(sub_image, Vector2(250, 250) * factor * 0.9).is_equal_approx(Color(1, 0, 0)), "world is inside the 90% SubViewport")
	check(not _color_at(sub_image, Vector2(950, 250) * factor * 0.9).is_equal_approx(Color(0, 1, 0)), "HUD is not inside the scaled SubViewport")
	# Without the scaled image the root itself draws no world pixels.
	scaler.display.hide()
	for i: int in 3: await process_frame
	image = win.get_texture().get_image()
	check(not _color_at(image, Vector2(250, 250) * factor).is_equal_approx(Color(1, 0, 0)), "root does not draw the world at full size")
	check(not _color_at(image, Vector2(650, 250) * factor).is_equal_approx(Color(0, 0, 1)), "root does not draw the top-level world node")
	check(_color_at(image, Vector2(950, 250) * factor).is_equal_approx(Color(0, 1, 0)), "root still draws the HUD")
	scaler.queue_free()
	for i: int in 3: await process_frame
	image = win.get_texture().get_image()
	check(_color_at(image, Vector2(250, 250) * factor).is_equal_approx(Color(1, 0, 0)), "flag off: root draws the world again")
	world.queue_free()
	await process_frame

func _color_at(image: Image, point: Vector2) -> Color:
	var p := Vector2i(point.round())
	return image.get_pixelv(p.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE))
