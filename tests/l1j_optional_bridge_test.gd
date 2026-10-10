extends SceneTree
const BRIDGE = preload("res://addons/twilight_l1j/twilight_selective_bridge.gd")
const PREVIEW = preload("res://addons/twilight_l1j/preview/ExternalResourcePreview.tscn")
var problems: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, message: String) -> void:
    if not value:
        problems.append(message)
        print("L1J_OPTIONAL_FAIL: " + message)

func _run() -> void:
    var adapter: RefCounted = BRIDGE.new()
    for kind: String in ["item_icon", "ground_icon", "npc_portrait", "sprite_frames", "map_attributes"]:
        _check(not bool(adapter.call("is_feature_enabled", kind)), "default on: " + kind)
    _check(adapter.call("item_icon", "ext:a3:weapon:1") == null, "unrequested icon loaded")
    _check(adapter.call("sprite_frames", "19521-0", "spx") == null, "unrequested frames loaded")
    _check(adapter.call("map_attribute", 101, "a3") == null, "unrequested map loaded")
    _check(not bool(adapter.call("set_feature_enabled", "save_game", true)), "invalid flag accepted")
    _check(bool(adapter.call("set_feature_enabled", "item_icon", true)), "valid flag rejected")
    _check(adapter.call("item_icon", "../bad") == null, "invalid source ID accepted")
    _check(adapter.call("ground_icon", "ext:go:weapon:1") == null, "disabled ground icon loaded")
    _check(bool(adapter.call("set_feature_enabled", "sprite_frames", true)), "animation flag not enabled")
    _check(adapter.call("sprite_frames", "../evil", "spx") == null, "unsafe sprite ID accepted")
    _check(adapter.call("sprite_frames", "19521-0", "evil") == null, "unsafe sprite provider accepted")
    _check(bool(adapter.call("set_feature_enabled", "map_attributes", true)), "map flag not enabled")
    _check(adapter.call("map_attribute", -1, "a3") == null, "invalid map accepted")
    _check(adapter.call("map_attribute", 101, "evil") == null, "invalid map provider accepted")
    var preview: Control = PREVIEW.instantiate() as Control
    _check(preview != null, "preview scene missing")
    if preview != null:
        root.add_child(preview)
        await process_frame
        _check(preview.get_child_count() > 0, "preview did not build controls")
        preview.queue_free()
    if problems.is_empty():
        print("L1J_OPTIONAL_BRIDGE_OK")
        quit(0)
    else:
        print("L1J_OPTIONAL_BRIDGE_FAILED: " + str(problems))
        quit(1)
