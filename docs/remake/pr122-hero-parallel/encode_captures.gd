extends SceneTree
## Lossless transport encoding only. Never edits or resamples captured pixels.
func _initialize() -> void:
	var rows: Array = []
	for sid: String in ["179", "182"]:
		var path := "res://docs/remake/pr122-hero-parallel/evidence/r005-visible-main/Main-all-poses-" + sid
		var source := Image.new()
		assert(source.load_png_from_buffer(FileAccess.get_file_as_bytes(path + ".png")) == OK)
		source.convert(Image.FORMAT_RGBA8)
		assert(source.save_webp(path + ".webp", false) == OK)
		var check := Image.new()
		assert(check.load_webp_from_buffer(FileAccess.get_file_as_bytes(path + ".webp")) == OK)
		check.convert(Image.FORMAT_RGBA8)
		assert(check.get_size() == source.get_size() and check.get_data() == source.get_data())
		rows.append({"target": sid, "lossless_webp": path + ".webp", "webp_sha256": FileAccess.get_sha256(path + ".webp"), "raw_png_local_only": path + ".png", "raw_png_sha256": FileAccess.get_sha256(path + ".png"), "RGBA_exact": true})
	var file := FileAccess.open("res://docs/remake/pr122-hero-parallel/evidence/r005-visible-main/encoding.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "PASS", "resampling": false, "rows": rows}, "  ") + "\n")
	print("HERO_CAPTURE_LOSSLESS_ENCODING_PASS images=2 changed_RGBA_pixels=0")
	quit(0)
