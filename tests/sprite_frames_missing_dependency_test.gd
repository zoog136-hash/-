extends SceneTree

# A SpriteFrames whose texture is missing must fail fast and only once: it
# used to load every other texture first (~2.2 s for a boss sheet) on every
# spawn. Valid frame sets still load normally.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("SPRITE_FRAMES_MISSING_DEP_FAIL: ", label)

func _initialize() -> void:
	CATALOG.report_missing_frames = false
	var dir: String = "user://sprite-frames-missing-dep"
	DirAccess.make_dir_recursive_absolute(dir)
	var good: String = dir + "/good.tres"
	var broken: String = dir + "/broken.tres"
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	image.save_png(dir + "/real.png")
	var frames := SpriteFrames.new()
	frames.add_animation("idle_0")
	frames.add_frame("idle_0", ImageTexture.create_from_image(image))
	check(ResourceSaver.save(frames, good) == OK, "write a valid frame set")
	var text: String = '[gd_resource type="SpriteFrames" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://does/not/exist-%d.png" id="1"]\n\n[resource]\nanimations = [{"frames": [{"duration": 1.0, "texture": ExtResource("1")}], "loop": true, "name": &"idle_0", "speed": 5.0}]\n' % Time.get_ticks_usec()
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	check(not CATALOG._missing_dependency(broken).is_empty(), "missing texture is detected without loading")
	check(CATALOG._missing_dependency(good).is_empty(), "a complete frame set has no missing dependency")
	var empty: SpriteFrames = CATALOG.frames(broken, "still")
	check(empty != null and empty.get_animation_names().is_empty(), "broken set yields empty frames as before")
	check(CATALOG.failed_frames.has(broken), "the failure is remembered")
	var started: int = Time.get_ticks_usec()
	CATALOG.frames(broken, "still")
	check(Time.get_ticks_usec() - started < 5000, "a repeat request returns at once")
	var loaded: SpriteFrames = CATALOG.frames(good, "still")
	check(loaded != null and loaded.has_animation("idle_0"), "valid frame set still loads")
	print("SPRITE_FRAMES_MISSING_DEP_RESULT ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
