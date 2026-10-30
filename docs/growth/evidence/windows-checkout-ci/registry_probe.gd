extends SceneTree

func _initialize() -> void:
	var registry = load("res://scripts/maps/native_png_registry.gd")
	var corrections: Dictionary = registry.read_json(registry.NAVIGATION_CORRECTIONS)
	var plan: Dictionary = registry.plan()
	var field = registry.load_field("aden_world")
	print("WINDOWS_CHECKOUT_REGISTRY_RESULT ", JSON.stringify({
		"domination_sha256": FileAccess.get_sha256(registry.DOMINATION_PLAN_PATH),
		"expected_sha256": corrections.domination_plan_sha256,
		"plan_nonempty": not plan.is_empty(), "aden_field_loaded": field != null}))
	if field != null: print("WINDOWS_CHECKOUT_REGISTRY_OK")
	quit(0 if field != null else 1)
