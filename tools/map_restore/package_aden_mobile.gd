extends SceneTree
# Builds a standalone supplemental asset pack, not an Android APK.
func _initialize() -> void:
	var out: String=OS.get_environment("ADEN_MOBILE_PCK")
	if out.is_empty():printerr("Set ADEN_MOBILE_PCK output path");quit(1);return
	var base: String="res://assets/maps/aden_world_mobile/"
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base+"manifest.json"))
	var paths: Array[String]=[base+"manifest.json","res://data/maps/aden_mobile_pack.json"]
	for row: Dictionary in manifest.ground+manifest.assets.values()+[manifest.overview]:paths.append(base+row.file)
	var pack:=PCKPacker.new()
	assert(pack.pck_start(out)==OK)
	for path: String in paths:assert(pack.add_file(path,path)==OK)
	assert(pack.flush()==OK);assert(ProjectSettings.load_resource_pack(out,true))
	var checked: int=0
	for row: Dictionary in manifest.ground+manifest.assets.values()+[manifest.overview]:
		assert(FileAccess.get_sha256(base+row.file)==row.sha256);checked+=1
	print("MOBILE_PCK_OK files=",paths.size()," sha_verified=",checked," bytes=",FileAccess.open(out,FileAccess.READ).get_length())
	quit()
