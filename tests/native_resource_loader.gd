extends ResourceFormatLoader
## Test-only real-byte loader for existing source resources before editor import.
## Shared by Main and Core; contains no presentation harness or replacement art.
var read_paths: Dictionary = {}
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["png","webp","jpg","jpeg","svg","ttf","otf","wav","ogg"])
func _handles_type(type: StringName) -> bool:
	return type in [&"Texture2D",&"ImageTexture",&"Texture",&"Font",&"FontFile",&"AudioStream",&"AudioStreamWAV",&"AudioStreamOggVorbis"]
func _get_resource_type(path: String) -> String:
	match path.get_extension().to_lower():
		"ttf","otf": return "FontFile"
		"wav": return "AudioStreamWAV"
		"ogg": return "AudioStreamOggVorbis"
	return "Texture2D" if path.get_extension().to_lower() in _get_recognized_extensions() else ""
func _exists(path: String) -> bool:
	return FileAccess.file_exists(path)
func _load(path: String, _original: String, _threads: bool, _cache: int) -> Variant:
	read_paths[path] = true
	match path.get_extension().to_lower():
		"wav": return AudioStreamWAV.load_from_file(path)
		"ogg": return AudioStreamOggVorbis.load_from_file(path)
		"ttf","otf":
			var font := FontFile.new()
			font.data = FileAccess.get_file_as_bytes(path)
			return font
	var image := Image.new()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var error: Error = ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"png": error = image.load_png_from_buffer(bytes)
		"webp": error = image.load_webp_from_buffer(bytes)
		"jpg","jpeg": error = image.load_jpg_from_buffer(bytes)
		"svg": error = image.load_svg_from_buffer(bytes)
	return ERR_FILE_CORRUPT if error != OK or image.is_empty() else ImageTexture.create_from_image(image)
