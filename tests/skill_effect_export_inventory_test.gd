extends SceneTree
const EXPORT = preload("res://addons/source84_export/raw_pack_export.gd")
const ROOT = "res://assets/external_spx/similar_skills/"
var errors: Array[String] = []
var checks := 0
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: errors.append(note); push_error(note)
func _initialize() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	var valid := EXPORT.validate_supplied_effects(spec, ROOT)
	check(valid.error.is_empty() and valid.files.size() == 100, "100 actual SHA-verified resources accepted")
	var legacy: Dictionary = spec.duplicate(true)
	for key: String in spec.effects:
		if str(spec.effects[key].atlas).begins_with("reviewed201_cast_"): legacy.effects.erase(key)
	legacy.scope.erase("additional_reviewed_cast_groups")
	legacy.scope.erase("reviewed_cast_resource_count")
	check(EXPORT.validate_supplied_effects(legacy, ROOT).files.size() == 91, "original 91-resource manifest still accepted")
	var bad: Dictionary = spec.duplicate(true)
	bad.effects.erase(bad.effects.keys()[0])
	check(not EXPORT.validate_supplied_effects(bad, ROOT).error.is_empty(), "missing inventory member rejected")
	bad = spec.duplicate(true)
	bad.scope.reviewed_cast_resource_count = 91
	check(not EXPORT.validate_supplied_effects(bad, ROOT).error.is_empty(), "stale count rejected")
	for field: String in ["sha256", "atlas"]:
		bad = spec.duplicate(true)
		var key: String = bad.effects.keys()[-1]
		bad.effects[key][field] = "../unavailable.png" if field == "atlas" else "invalid"
		var rejected := EXPORT.validate_supplied_effects(bad, ROOT)
		check(not rejected.error.is_empty() and rejected.files.is_empty(), "bad " + field + " rejects entire batch")
	# Pack and reopen the exact validated raw bytes; exported PNG paths must work
	# independently of editor texture imports.
	var path := "user://skill-effect-export-test.pck"
	var packer := PCKPacker.new()
	check(packer.pck_start(path) == OK, "raw effect pack opens")
	for name: String in valid.files:
		check(packer.add_file("res://export_inventory_probe/" + name, ROOT + name) == OK, "raw PNG added: " + name)
	check(packer.flush() == OK and ProjectSettings.load_resource_pack(path), "raw pack loads")
	for name: String in valid.files:
		var source := ROOT + name
		var exported := "res://export_inventory_probe/" + name
		check(FileAccess.get_sha256(exported) == FileAccess.get_sha256(source), "packed bytes preserved: " + name)
		check(Image.load_from_file(exported) != null, "raw packed PNG decodes: " + name)
	DirAccess.remove_absolute(path)
	print("SKILL_EFFECT_EXPORT_INVENTORY checks=", checks, " resources=", valid.files.size(), " errors=", errors.size())
	quit(0 if errors.is_empty() else 1)
