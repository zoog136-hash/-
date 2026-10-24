extends SceneTree
func _initialize() -> void:
	var base: String="res://assets/maps/aden_live_plaza/"
	var m: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base+"manifest.json"))
	var pack:=PCKPacker.new();var path: String="user://aden_generated_test.pck"
	assert(pack.pck_start(path)==OK)
	for row: Dictionary in m.rows:assert(pack.add_file("res://packed_plaza/"+row.file,base+row.file)==OK)
	assert(pack.flush()==OK);assert(ProjectSettings.load_resource_pack(path))
	var count: int=0
	for row: Dictionary in m.rows:
		var packed_path: String="res://packed_plaza/"+row.file
		assert(FileAccess.get_sha256(packed_path)==row.sha256)
		var image:=Image.new();assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(packed_path))==OK)
		assert(image.get_size()==Vector2i(row.size[0],row.size[1]));count+=1
	print("GENERATED_PCK_OK ",count," raw PNG payloads decoded from mounted pack; not an APK test")
	quit()
