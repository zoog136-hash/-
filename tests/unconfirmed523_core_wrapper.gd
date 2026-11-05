extends SceneTree
## Unchanged required Core assertions, with real source bytes available while
## this clean checkout's editor import remains incomplete.
const NativeImageLoader = preload("res://tests/native_resource_loader.gd")
var real_resource_loader: ResourceFormatLoader

func _initialize() -> void:
	real_resource_loader = NativeImageLoader.new()
	ResourceLoader.add_resource_format_loader(real_resource_loader,true)
	call_deferred("start_original_suite")

func start_original_suite() -> void:
	# Core preloads a renderer whose typed world dependency preloads audio.
	# Register the real-byte loader before parsing that unchanged script.
	var suite: GDScript = load("res://tests/core_runtime_save_test.gd")
	if suite == null or not suite.can_instantiate():
		printerr("UNCONFIRMED523_CORE_WRAPPER: unchanged Core suite failed to parse")
		quit(1)
		return
	set_script(suite)
	call("_initialize")
