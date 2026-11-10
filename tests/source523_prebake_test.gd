extends SceneTree
## The loading screen's first-run prebake: nothing is pending without a
## selected pack; BAKE.present() is a cheap exact "already baked" test (key,
## schema and size); each loader's baked() follows its own bake.
const PREBAKE = preload("res://scripts/boot/source523_prebake.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const IMAGE_PACK = preload("res://scripts/resources/source523_image_pack.gd")
const UI_PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const SOURCE_PACK = preload("res://scripts/maps/current523_source_pack.gd")
const TILE_PACK = preload("res://scripts/maps/current523_tile_pack.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	for variable: String in ["TWILIGHT_SOURCE523_IMAGES", "TWILIGHT_SOURCE_UI"]:
		OS.set_environment(variable, "")
		OS.set_environment(variable + "_SHA256", "")
	var options_path: String = PREBAKE.OPTIONS.PATH
	var had_options: bool = FileAccess.file_exists(options_path)
	if not had_options: check(PREBAKE.pending().is_empty(), "nothing is pending without a selected pack")
	var sha: String = "ab".repeat(32)
	OS.set_environment("TWILIGHT_SOURCE523_IMAGES", "user://absent_images")
	OS.set_environment("TWILIGHT_SOURCE523_IMAGES_SHA256", sha)
	var steps: Array[Dictionary] = PREBAKE.pending()
	check(steps.size() >= 1 and steps[0].id == "images" and steps[0].sha == sha, "an unbaked selected pack is pending")
	check(not PREBAKE.run(steps[0]), "a pack that cannot be verified fails without throwing")
	check(not IMAGE_PACK.baked(sha) and not UI_PACK.baked(sha) and not SOURCE_PACK.baked(sha) and not TILE_PACK.baked(sha), "nothing is baked for an unknown pin")
	# present(): exact key, schema and size.
	var name: String = "prebake_test_fixture"
	BAKE.clear(name)
	check(BAKE.write(name, "key-1", {"value": 1}), "fixture bake written")
	check(BAKE.present(name, "key-1"), "a written bake is present")
	check(not BAKE.present(name, "key-2"), "another key is not present")
	check(not BAKE.present(name, ""), "an empty key is never present")
	var data: String = BAKE.data_path(name)
	var file := FileAccess.open(data, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_8(0)
	file.close()
	check(not BAKE.present(name, "key-1"), "a bake whose size changed is not present")
	BAKE.clear(name)
	OS.set_environment("TWILIGHT_SOURCE523_IMAGES", "")
	OS.set_environment("TWILIGHT_SOURCE523_IMAGES_SHA256", "")
	print("SOURCE523_PREBAKE_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
