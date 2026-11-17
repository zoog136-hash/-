extends SceneTree
## Field camera distance (TWILIGHT 근사): clamping/preference, world-space
## text keeping its screen size under the zoom, and screen <-> world mapping
## following the camera. Synthetic nodes only, no original resources.
##   godot --headless --path <repo> --script res://tests/field_camera_scale_test.gd
const FIELD_CAMERA = preload("res://scripts/maps/field_camera_scale.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FIELD_CAMERA_SCALE_FAIL: " + label)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

func run() -> void:
	# Constant, range and saved preference.
	check(near(FIELD_CAMERA.DEFAULT_ZOOM, 1.75), "default camera distance is 1.75")
	check(FIELD_CAMERA.MIN_ZOOM <= FIELD_CAMERA.DEFAULT_ZOOM and FIELD_CAMERA.DEFAULT_ZOOM <= FIELD_CAMERA.MAX_ZOOM, "default inside the settings range")
	check(near(FIELD_CAMERA.clamp_zoom(9.0), FIELD_CAMERA.MAX_ZOOM) and near(FIELD_CAMERA.clamp_zoom(0.0), FIELD_CAMERA.MIN_ZOOM), "clamped to the settings range")
	check(near(FIELD_CAMERA.clamp_zoom("x"), FIELD_CAMERA.DEFAULT_ZOOM) and near(FIELD_CAMERA.clamp_zoom(NAN), FIELD_CAMERA.DEFAULT_ZOOM), "invalid saved values fall back to the default")
	check(near(FIELD_CAMERA.clamp_zoom(1.52), 1.5), "snapped to the slider step")
	check(near(FIELD_CAMERA.preference({}), FIELD_CAMERA.DEFAULT_ZOOM), "missing preference uses the default")
	check(near(FIELD_CAMERA.preference({FIELD_CAMERA.PREFERENCE_KEY: 2.0}), 2.0), "saved preference is used")

	# Phone-like host (1280x720 base on a 1920x1080 target) with a camera.
	var host := SubViewport.new()
	host.size = Vector2i(1920, 1080)
	host.size_2d_override = Vector2i(1280, 720)
	host.size_2d_override_stretch = true
	root.add_child(host)
	var world := Node2D.new()
	host.add_child(world)
	var camera := Camera2D.new()
	camera.position = Vector2(4000, 2000)
	world.add_child(camera)
	camera.make_current()
	var actor := Node2D.new()
	actor.position = Vector2(4060, 2030)
	world.add_child(actor)
	var name_label := Label.new()
	name_label.size = Vector2(172, 24)
	name_label.position = Vector2(-86, -78)
	actor.add_child(name_label)
	var head := Vector2(0, -54)
	FIELD_CAMERA.keep_screen_size(name_label, head - name_label.position)
	var screen_points: Array = []
	var label_scales: Array = []
	var head_screens: Array = []
	for zoom: float in [1.0, FIELD_CAMERA.DEFAULT_ZOOM, FIELD_CAMERA.MAX_ZOOM]:
		camera.zoom = Vector2.ONE * zoom
		FIELD_CAMERA.set_applied(zoom, self)
		await process_frame
		await process_frame
		var canvas: Transform2D = host.get_canvas_transform()
		check(near(canvas.get_scale().x, zoom), "camera zoom %.2f reaches the canvas transform" % zoom)
		var screen: Vector2 = canvas * actor.global_position
		# Touch/click mapping: inverse canvas transform returns the same world point.
		check((canvas.affine_inverse() * screen).distance_to(actor.global_position) < 0.01, "screen -> world mapping follows zoom %.2f" % zoom)
		screen_points.append(screen - canvas * camera.get_screen_center_position())
		label_scales.append(name_label.get_global_transform_with_canvas().get_scale().x)
		head_screens.append(canvas * (actor.global_position + head))
		check(near(name_label.scale.x, 1.0 / zoom), "label counter-scale at zoom %.2f" % zoom)
	check(near(float(label_scales[0]), 1.0) and near(float(label_scales[1]), 1.0) and near(float(label_scales[2]), 1.0), "name label keeps its screen size at every zoom")
	var pivot_screen: Vector2 = name_label.get_global_transform_with_canvas() * name_label.pivot_offset
	check(pivot_screen.distance_to(head_screens[2]) < 0.01, "label stays anchored at the head point")
	check((screen_points[1] as Vector2).distance_to((screen_points[0] as Vector2) * FIELD_CAMERA.DEFAULT_ZOOM) < 0.01, "world offsets on screen grow by the zoom")
	FIELD_CAMERA.set_applied(1.0, self)
	check(near(name_label.scale.x, 1.0), "registered labels return to 1.0 outside original fields")
	host.free()

	# world.gd applies the factor only on original-art fields and saves it in ui_preferences.
	var source: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	check(source.contains("field_camera_original_art = requested_native != null or requested_original != null"), "factor limited to original-art fields")
	check(source.contains("player.camera.zoom = Vector2.ONE * field_camera_base_zoom * factor"), "camera zoom = field zoom x camera distance")
	check(source.contains("ui_preferences[FIELD_CAMERA.PREFERENCE_KEY]"), "camera distance saved in ui_preferences")
	var settings: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_settings.gd")
	check(settings.contains("FieldCameraDistance") and settings.contains("set_field_camera_zoom"), "settings slider present")
	print("FIELD_CAMERA_SCALE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"default_zoom":FIELD_CAMERA.DEFAULT_ZOOM,"scope":"synthetic_camera_label_mapping_twilight_approximation"}))
	quit(0 if failures.is_empty() else 1)
