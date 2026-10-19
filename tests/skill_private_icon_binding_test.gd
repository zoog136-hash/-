extends SceneTree
const Catalog = preload("res://scripts/skills/skill_catalog.gd")
const FALLBACK = "res://assets/skills/icons/lm_0f78dd70d9994d34.svg"
const PRIVATE = "res://assets/skills/private_icons/lm_0f78dd70d9994d34.png"

func _initialize() -> void:
	var row: Dictionary = {"id": "lm_0f78dd70d9994d34", "icon": FALLBACK}
	var want: String = PRIVATE if ResourceLoader.exists(PRIVATE) else FALLBACK
	if Catalog.preferred_icon_path(row) != want:
		push_error("private skill icon ID override failed")
		quit(1)
		return
	if Catalog.preferred_icon_path({"id": "../invalid", "icon": FALLBACK}) != FALLBACK:
		push_error("invalid icon ID accepted")
		quit(1)
		return
	if not ResourceLoader.exists(FALLBACK):
		push_error("existing fallback image missing")
		quit(1)
		return
	print("SKILL_ICON_PRIVATE_BINDING_PASS")
	quit(0)
