extends SceneTree
## Install real-byte loaders before the typed gameplay test's preload graph.
func _initialize() -> void:
	var loader = preload("res://tests/pr122_published_boss_approval_main.gd").NativeImageLoader.new()
	ResourceLoader.add_resource_format_loader(loader, true)
	set_meta("approval_source_loader", loader)
	var probe = load("res://tests/pr122_approval_clearing_probe.gd")
	if probe == null or not probe.can_instantiate():
		push_error("CLEARING_PROBE_COMPILE_FAILED")
		quit(1)
		return
	set_script(probe)
	call_deferred("run")
