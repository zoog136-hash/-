@tool
extends EditorExportPlugin

const DATA = preload("res://scripts/resources/built_in_startup_data.gd")

func _get_name() -> String:
	return "TwilightBuiltInStartupData"

func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	var preset := get_export_preset()
	if preset == null or preset.get_preset_name() not in ["Android", "AndroidUpdatePack"]: return
	var count := 0
	var bytes := 0
	for path: String in DATA.PATHS:
		var prepared := DATA.compile_json(path)
		if prepared.is_empty(): continue
		add_file(DATA.companion_path(path), prepared, false)
		count += 1
		bytes += prepared.size()
	print("TWILIGHT_STARTUP_DATA_EXPORT files=%d bytes=%d" % [count, bytes])
