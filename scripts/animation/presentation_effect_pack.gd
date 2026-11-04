extends RefCounted
## Only an explicitly chosen, hash-checked local rendering candidate.
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
var directory: String = ""
var manifests: Dictionary = {}

func load_directory(path: String) -> Dictionary:
	var header_path: String = path.path_join("presentation_effects.json")
	var file := FileAccess.open(header_path,FileAccess.READ)
	if file==null or file.get_length()>2*1024*1024: return _error()
	file.close()
	var header: Variant = JSON.parse_string(FileAccess.get_file_as_string(header_path))
	if not header is Dictionary or header.get("kind")!="twilight-presentation-effect-candidate" or header.get("schema")!=1: return _error()
	if not header.get("native_M_pixel_or_trigger_certified") is bool or header.native_M_pixel_or_trigger_certified!=false: return _error()
	var files: Variant = header.get("files")
	if not files is Array or files.is_empty() or files.size()>1024: return _error()
	var seen: Dictionary = {}
	var total: int = 0
	for row: Variant in files:
		if not row is Dictionary: return _error()
		var expected_bytes: Variant = row.get("bytes")
		if not (expected_bytes is int or expected_bytes is float) or not is_finite(float(expected_bytes)) or float(expected_bytes)<=0.0 or float(expected_bytes)!=floorf(float(expected_bytes)): return _error()
		var relative: String = str(row.get("path",""))
		if not INSTALL.safe_relative(relative) or seen.has(relative): return _error()
		var target: String = path.path_join(relative)
		file = FileAccess.open(target,FileAccess.READ)
		if file==null or file.get_length()>16*1024*1024 or file.get_length()!=int(row.get("bytes",-1)): return _error()
		total+=file.get_length()
		file.close()
		if total>128*1024*1024 or FileAccess.get_sha256(target)!=str(row.get("sha256","")): return _error()
		seen[relative] = true
	var actions: Variant = header.get("actions")
	if not actions is Dictionary or actions.size()!=2: return _error()
	var next: Dictionary = {}
	for action: String in ["0","3"]:
		var relative: String = str(actions.get(action,""))
		if not seen.has(relative): return _error()
		var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(path.path_join(relative)))
		if not index is Dictionary or index.get("schema")!=1 or index.get("mode")!="literal_body_shadow_inspection_only": return _error()
		var records: Variant = index.get("records")
		if not records is Dictionary or records.size()!=2 or not records.has("overlay:24941") or not records.has("overlay:29044"): return _error()
		var preview = PREVIEW.new()
		preview._manifest_path = path.path_join(relative)
		preview._manifest_records = records
		var valid: bool = preview._overlay_files_available(24941) and preview._overlay_files_available(29044,24941)
		if not valid:
			preview.free()
			return _error()
		for id: int in [24941,29044]:
			var model: Dictionary = preview._overlay_record(id)
			var track: Dictionary = model.get("tracks",{}).get("idle",{})
			valid = valid and int(track.get("source_action_id",-1))==int(action)
			for frames: Array in track.get("directions",[]):
				for frame: Dictionary in frames:
					var duration: Variant = frame.get("duration")
					valid = valid and (duration is int or duration is float) and is_finite(float(duration)) and float(duration)>0.0 and float(duration)<10.0
		preview.free()
		if not valid: return _error()
		next[int(action)] = path.path_join(relative)
	directory = path
	manifests = next
	return {"ok":true,"candidate":true,"files":seen.size()}

func _error() -> Dictionary:
	return {"ok":false,"error":"자체 해석 효과 팩의 형식·파일·해시가 다릅니다. 기존 선택을 유지합니다."}
