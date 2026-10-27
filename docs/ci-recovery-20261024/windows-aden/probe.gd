extends SceneTree
func _initialize() -> void:
	var registry=load("res://scripts/maps/native_png_registry.gd")
	var patch: Dictionary=registry.read_json("res://data/maps/native_png_navigation_corrections.json")
	var plan: Dictionary=registry.plan()
	var field=registry.load_field("aden_world")
	print("ADEN_LOAD_DIAG ",JSON.stringify({"domination_hash":FileAccess.get_sha256(registry.DOMINATION_PLAN_PATH),"expected":patch.domination_plan_sha256,"plan_nonempty":not plan.is_empty(),"aden_field_loaded":field!=null}))
	quit()
