extends SceneTree
const Visual = preload("res://scripts/animation/visual_manifest.gd")
var checks := 0
func check(value: bool, label: String) -> void:
	if not value: push_error(label); quit(1); assert(false, label)
	checks += 1
func _initialize() -> void:
	var isolated: String = OS.get_environment("TWILIGHT_PRIVATE_TEST_ROOT")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").simplify_path().begins_with(isolated.simplify_path() + "/"):
		push_error("Run this via tools/test_private_catalog_motion.py; real user data must not be used")
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/runtime_manifest.json"))
	var total := 0
	Visual.reset()
	for key: String in data.catalog:
		var row: Dictionary = data.catalog[key]
		check(not FileAccess.file_exists(str(row.atlas)), "source atlas deliberately absent from code fixture")
		check(Visual.catalog_texture_available(key), "external atlas available for profile metadata")
		var frames: SpriteFrames = Visual.catalog_frames(key)
		check(frames != null, "actual consumer loads private atlas: " + key)
		check(frames.get_meta("twilight_visual_key") == key, "visual identity")
		check(frames.get_animation_names().size() == row.tracks.size(), "exact tracks")
		for track: Dictionary in row.tracks:
			var name: StringName = str(track.name)
			check(frames.has_animation(name) and frames.get_frame_count(name) == int(track.count), "exact frame count")
			check(is_equal_approx(frames.get_animation_speed(name), clampf(float(track.fps), 1.0, 60.0)) and frames.get_animation_loop(name) == bool(track.loop), "timing and loop metadata preserved")
			for n: int in range(int(track.count)):
				var atlas: AtlasTexture = frames.get_frame_texture(name, n) as AtlasTexture
				var expected := Rect2(n * int(row.cell[0]), int(track.row) * int(row.cell[1]), int(row.cell[0]), int(row.cell[1]))
				check(atlas != null and atlas.atlas != null and atlas.region == expected and atlas.filter_clip, "unchanged atlas frame region")
				total += 1
		check(Visual.stats().frame_cache <= 12 and Visual.stats().texture_cache <= 12, "cache remains bounded")
		await process_frame
	check(total == 41442 and data.catalog.size() == 723, "all existing catalog frames")
	check(Visual.stats().missing.is_empty(), "no hidden fallback/missing texture")
	print(JSON.stringify({"passed":checks,"atlases":723,"frames":total,"scope":"actual VisualManifest catalog_frames using private files, no embedded atlases; not full World/Android","engine":Engine.get_version_info().string}))
	quit(0)
