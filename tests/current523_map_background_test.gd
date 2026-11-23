extends SceneTree

const BACKGROUND = preload("res://scripts/maps/current523_map_background.gd")
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _run() -> void:
	var identity: Dictionary = DEFINITIONS.identity()
	_expect(identity.get("source_sha256") == DEFINITIONS.SOURCE_SHA, "actual pinned 523 input")
	var source: Array[Dictionary] = DEFINITIONS.rows("MapBackgroundView")
	_expect(source.size() == 53, "source rows 53")
	var asset_ids: Dictionary = {}
	for row: Dictionary in source:
		var binding: Dictionary = BACKGROUND.describe(int(row.ID))
		_expect(binding.ok and binding.render_type == 11 and binding.draw_ready == false, "exact Land %s" % row.ID)
		if binding.ok:
			_expect(binding.sky.id == int(row.SkyAssetId) and binding.cloud.id == int(row.CloudAssetId), "exact typed layers %s" % row.ID)
			asset_ids[binding.sky.id] = true
			asset_ids[binding.cloud.id] = true
	_expect(asset_ids.size() == 11, "distinct asset identities")
	var dream: Dictionary = BACKGROUND.describe(22801)
	_expect(dream.ok and dream.sky.path == "Image/MapBG/normal_cloud_sky.png" and dream.cloud.path == "Image/MapBG/normal_cloud.png", "dream island")
	_expect(BACKGROUND.describe(303).reason == "background_not_declared", "physical map folder is not logical Land")
	_expect(BACKGROUND.describe(4).reason == "background_not_declared", "Aden unchanged")
	_expect(BACKGROUND.describe(-1).reason == "invalid_logical_land", "bad input")
	var unopened = FIELD.new()
	_expect(unopened.source_background_binding().ok == false, "unopened field cannot bind")
	unopened.loaded = true
	unopened.set_meta("current523_generic_field", true)
	unopened.native_land = {"ID":22801}
	unopened.source_asset = "303/"
	_expect(unopened.source_background_binding() == dream, "real field binding uses Land ID")
	unopened.close()
	_expect(unopened.source_background_binding().ok == false, "no stale field binding on close")
	unopened = null
	var result: Dictionary = BACKGROUND.resolve_layers(22801)
	_expect(not result.ok and str(result.reason).begins_with("background_sky_unavailable:"), "no generated placeholder if the actual image pack is absent")
	var terrain_root: String = OS.get_environment("TWILIGHT_BACKGROUND_TEST_TERRAIN")
	if not terrain_root.is_empty():
		var field = FIELD.new()
		var admitted: bool = field.configure_catalog(terrain_root, "6b71f4adb533b7acae6a7327e83af1b1322001a0f67c417bb3fae1bec35d96ca", 22801)
		_expect(admitted and field.source_asset == "303/" and field.source_background_binding() == dream, "real Dream Island source field")
		field.close()
	var sparse_images: String = OS.get_environment("TWILIGHT_BACKGROUND_TEST_IMAGES")
	if not sparse_images.is_empty():
		var opened: Dictionary = IMAGES.configure(sparse_images, "b743a3f192ff5c4196bcd5d1775935068fe22a10a108334080be2e2fc8a1e58c")
		_expect(opened.get("ok", false), "real image manifest")
		var cloud: Dictionary = IMAGES.resolve_asset(dream.cloud.id, BACKGROUND.IMAGE_TYPE, dream.cloud.path)
		var texture := cloud.get("texture") as Texture2D
		_expect(cloud.get("ok", false) and texture != null and texture.get_size() == Vector2(768,768), "verified cloud bytes through production texture owner")
		_expect(not BACKGROUND.resolve_layers(22801).ok, "one verified layer cannot enable the incomplete pair")
	print("CURRENT523_MAP_BACKGROUND_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
