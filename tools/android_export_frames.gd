extends SceneTree

## Explicit APK verifier helper; requires --index and --output arguments.
## Loads actual binary SpriteFrames extracted from the APK, then compares them
## with the existing project's sources. This does not simulate Android gameplay.
func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var index_path := ""
	var output_path := ""
	for i: int in range(arguments.size() - 1):
		if arguments[i] == "--index": index_path = arguments[i + 1]
		if arguments[i] == "--output": output_path = arguments[i + 1]
	if index_path.is_empty() or output_path.is_empty():
		push_error("Expected --index <JSON> --output <JSON>")
		quit(1)
		return
	var index_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not index_value is Array or index_value.is_empty():
		push_error("Native SpriteFrames inspection index is empty or invalid")
		quit(1)
		return
	var index: Array = index_value
	var failures: Array[String] = []
	var animations := 0
	var frames := 0
	var distinct_frames := 0
	var profiles: Array[Dictionary] = []
	for row: Dictionary in index:
		var expected := load(str(row.source)) as SpriteFrames
		var actual := load(str(row.inspection_file)) as SpriteFrames
		if expected == null or actual == null:
			failures.append("Missing load " + str(row.source))
			continue
		if expected.get_animation_names() != actual.get_animation_names():
			failures.append("Animation names differ " + str(row.source))
		if expected.get_meta("twilight_canvas_size", Vector2.ZERO) != actual.get_meta("twilight_canvas_size", Vector2.ZERO):
			failures.append("Original-based canvas metadata differs " + str(row.source))
		var poses: Array[Dictionary] = []
		for animation: StringName in expected.get_animation_names():
			animations += 1
			if not actual.has_animation(animation): continue
			var count := expected.get_frame_count(animation)
			if count == 0 or count != actual.get_frame_count(animation):
				failures.append("Frame count differs or is empty " + str(row.source) + ":" + animation)
				continue
			if expected.get_animation_speed(animation) != actual.get_animation_speed(animation) or expected.get_animation_loop(animation) != actual.get_animation_loop(animation):
				failures.append("Timing/loop differs " + str(row.source) + ":" + animation)
			var unique_regions: Dictionary = {}
			for frame: int in range(count):
				frames += 1
				var wanted := expected.get_frame_texture(animation, frame) as AtlasTexture
				var packed := actual.get_frame_texture(animation, frame) as AtlasTexture
				if wanted == null or packed == null:
					failures.append("Missing atlas texture " + str(row.source) + ":" + animation + ":" + str(frame))
					continue
				if wanted.region != packed.region or wanted.margin != packed.margin or wanted.atlas.resource_path != packed.atlas.resource_path or expected.get_frame_duration(animation, frame) != actual.get_frame_duration(animation, frame):
					failures.append("Atlas frame differs " + str(row.source) + ":" + animation + ":" + str(frame))
				unique_regions[str(packed.atlas.resource_path) + ":" + str(packed.region)] = true
			distinct_frames += unique_regions.size()
			poses.append({"animation": animation, "frames": count, "distinct_atlas_regions": unique_regions.size()})
		profiles.append({"source": row.source, "animations": poses})
	var report := {"sprite_frames": index.size(), "animations": animations, "frames": frames,
		"distinct_atlas_regions_across_animations": distinct_frames, "profiles": profiles,
		"failures": failures, "passed": failures.is_empty(),
		"scope": "Exported animation resources match source. This does not certify distinct image pixels, original-art delivery, or Android device rendering."}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write Android frame validation report: " + output_path)
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t") + "\n")
	print("ANDROID_COMPILED_FRAMES animations=%d frames=%d profiles=%d passed=%s" % [animations, frames, index.size(), failures.is_empty()])
	quit(0 if failures.is_empty() else 1)
