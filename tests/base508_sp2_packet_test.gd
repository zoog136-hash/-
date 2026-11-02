extends SceneTree
const CODEC = preload("res://scripts/monsters/base508_sp2_frames.gd")
func _initialize() -> void:
	var reference: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--sp2-reference="): reference = argument.trim_prefix("--sp2-reference=")
	if reference.is_empty(): push_error("Missing --sp2-reference samples JSON"); quit(1); return
	var samples: Array = JSON.parse_string(FileAccess.get_file_as_string(reference))
	var errors: int = 0
	for row: Dictionary in samples:
		var result: Dictionary = CODEC.render(str(row.path),str(row.sha256),int(row.bit),int(row.frame))
		if result.is_empty(): push_error("Source packet failed: "+str(row.path)); errors+=1; continue
		var image: Image = result.image
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
		if image.get_width()!=int(row.width) or image.get_height()!=int(row.height) or int(result.offset[0])!=int(row.offset[0]) or int(result.offset[1])!=int(row.offset[1]) or hash.finish().hex_encode()!=str(row.rgba_sha256):
			push_error("Source RGBA/offset differs: "+str(row.path)+" "+str(row.bit)+":"+str(row.frame));errors+=1
	print("BASE508_SP2_PACKET_RGBA ",samples.size()," errors=",errors)
	quit(0 if errors==0 else 1)
