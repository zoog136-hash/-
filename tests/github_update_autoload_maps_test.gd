extends SceneTree
## GitHub Download ZIP and the Termux updater must be complete without a second
## private pack installation, env var, or editor command-line map switch.
const PNG = preload("res://scripts/maps/native_png_registry.gd")
const OMAN = preload("res://scripts/maps/remake_registry.gd")
var errors: Array[String] = []
var checks: int = 0

func verify(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		errors.append(msg)
		printerr("GITHUB_MAP_AUTOLOAD_FAIL: "+msg)

func _initialize() -> void:
	# A normal main game keeps the ordinary save namespace.
	verify(not PNG.enabled(), "ordinary launch does not use isolated review save")
	# CI can select this same checkout directory with an absolute pack override.
	# Require its exact normalized bundled path, retaining every hash/decode check.
	verify(ProjectSettings.globalize_path(PNG.root_path()).simplify_path() == ProjectSettings.globalize_path(PNG.BUNDLED_ROOT).simplify_path(), "PNG source from the updated GitHub checkout")
	verify(PNG.installed(), "PNG index matches the source SHA-256 receipt")
	verify(PNG.bundled_enabled(), "ordinary launch auto-enables updated PNG")
	verify(OMAN.pack_root() == OMAN.BUNDLED_ROOT, "Oman source from the updated GitHub checkout")
	verify(OMAN.installed("oman_01") and OMAN.installed("oman_10"), "all original Oman pack IDs available")
	verify(PNG.catalog_entries().size() == 2, "new temples enter ordinary region list")
	for mid: String in ["albino_01","albino_02","escaros_01","escaros_05","yahee_temple","balrog_temple"]:
		verify(PNG.supports(mid), "new image automatically selected for "+mid)
	verify(not PNG.supports("albino_03") and not PNG.supports("albino_04") and PNG.canonical("albino_03")=="albino_02" and PNG.canonical("albino_04")=="albino_02", "retired Albino 3/4 safely redirect to active area 2")
	verify(PNG.canonical("escaros_05") == "escaros_05", "existing save map ID does not change")
	var index: Dictionary = PNG.read_json(PNG.root_path()+"/index.json")
	for mid: String in ["albino_01","escaros_world","yahee_temple","balrog_temple"]:
		var manifest: Dictionary = PNG.read_json(PNG.root_path()+"/"+mid+"/manifest.json")
		verify(not manifest.is_empty() and not manifest.get("chunks",[]).is_empty(), mid+" real asset manifest")
		if not manifest.get("chunks",[]).is_empty():
			var chunk: Dictionary = manifest.chunks[0]
			var file: String = PNG.root_path()+"/"+mid+"/"+str(chunk.file)
			verify(FileAccess.get_sha256(file) == str(chunk.sha256),mid+" live original PNG SHA-256")
			var image := Image.new()
			verify(image.load(file) == OK and image.get_width()>0, mid+" raw PNG really decodes from res://")
	verify(index.get("schema") == 1, "verified map index schema")
	var normal_field: PlayableField = PNG.load_field("escaros_05")
	verify(normal_field is NativePngField and str(normal_field.data.map_id) == "escaros_world", "legacy Escaros ID renders real continuous source")
	var temple_field: PlayableField = PNG.load_field("yahee_temple")
	verify(temple_field is NativePngField, "ordinary temple has verified native field")
	var oman_field: RemakePlayableField = OMAN.load_field("oman_01")
	verify(oman_field != null, "bundled Oman grid verifies and loads in game")
	if oman_field != null: oman_field.close()
	print("GITHUB_MAP_AUTOLOAD_RESULT ",JSON.stringify({"checks":checks,"failures":errors,"save_namespace":"ordinary","bundled":true}))
	quit(0 if errors.is_empty() else 1)
