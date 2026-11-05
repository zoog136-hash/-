extends SceneTree
const CODEC = preload("res://scripts/monsters/base508_sp2_frames.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lineagem-monster-pack="): path = arg.trim_prefix("--lineagem-monster-pack=")
	if path.is_empty(): push_error("Missing source model manifest"); quit(1); return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var loaded: int = 0
	var samples: int = 0
	var errors: Array = []
	for id: String in manifest.models:
		var reference: Dictionary = manifest.models[id]
		var model_path: String = path.get_base_dir().path_join(str(reference.tracks_ref))
		if FileAccess.get_sha256(model_path) != str(reference.tracks_sha256): errors.append("Model hash mismatch " + id); continue
		var model: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(model_path))
		if int(model.source_sprite_id) != int(id): errors.append("Model source ID mismatch " + id); continue
		var before: int = errors.size()
		for role: String in ["idle", "walk", "attack", "hit", "death"]:
			var frames: Array = model.tracks[role].directions[0]
			for index: int in [0, frames.size()-1]:
				for layer: Dictionary in frames[index].layers:
					var decoded: Dictionary = CODEC.render(path.get_base_dir().path_join(str(layer.path)),str(layer.sha256),int(layer.source_direction_bit),int(layer.source_frame_index))
					if decoded.is_empty(): errors.append("Source frame decode failed " + id + ":" + role); continue
					var image: Image = decoded.image
					if image.get_width()!=int(layer.pixel_size[0]) or image.get_height()!=int(layer.pixel_size[1]) or int(decoded.offset[0])!=int(layer.offset[0]) or int(decoded.offset[1])!=int(layer.offset[1]): errors.append("Source pixel bounds/offset mismatch " + id + ":" + role)
					samples += 1
		if before == errors.size():
			loaded += 1
			print("BASE508_PACKET_MODEL_OK ", id)
	print("BASE508_MODEL_PACKET_LOAD ", JSON.stringify({"requested_models":manifest.models.size(),"loaded_models":loaded,"source_layer_samples":samples,"errors":errors}))
	quit(0 if errors.is_empty() and loaded == manifest.models.size() else 1)
