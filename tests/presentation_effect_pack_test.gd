extends SceneTree
const PACK = preload("res://scripts/animation/presentation_effect_pack.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("PRESENTATION_EFFECT_PACK_FAIL: ",label)
func _initialize() -> void:
	var pack = PACK.new()
	var good: String = OS.get_environment("TWILIGHT_PRESENTATION_EFFECT_PACK")
	var bad: String = OS.get_environment("TWILIGHT_PRESENTATION_EFFECT_BAD_PACK")
	check(not good.is_empty() and not bad.is_empty(),"actual received and deliberately corrupted private packs required")
	check(bool(pack.load_directory(good).ok) and pack.manifests.size()==2,"all actual file hashes, action pairs and complete attachments validated")
	var previous: String = JSON.stringify(pack.manifests)
	check(not bool(pack.load_directory(bad).ok) and pack.directory==good and JSON.stringify(pack.manifests)==previous,"corrupt image or malformed byte count rejected without replacing prior candidate")
	check(not bool(pack.load_directory("user://no-candidate").ok) and pack.directory==good,"missing candidate preserves previous directory")
	print("PRESENTATION_EFFECT_PACK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"native_M_pixel_certification":false}))
	quit(0 if failures.is_empty() else 1)
