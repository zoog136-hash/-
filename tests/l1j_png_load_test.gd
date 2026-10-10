extends SceneTree
const BRIDGE = preload("res://addons/twilight_l1j/twilight_selective_bridge.gd")
const LINK = preload("res://addons/twilight_l1j/twilight_visual_link.gd")
const PREVIEW = preload("res://addons/twilight_l1j/preview/ExternalResourcePreview.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, name: String) -> void:
    if not ok:
        failures.append(name)
        print("L1J_PNG_LOAD_FAIL: " + name)

func _run() -> void:
    var bridge: RefCounted = BRIDGE.new()
    _check(bool(bridge.call("set_feature_enabled", "item_icon", true)), "item flag")
    _check(bool(bridge.call("set_feature_enabled", "ground_icon", true)), "ground flag")
    _check(bool(bridge.call("set_feature_enabled", "npc_portrait", true)), "portrait flag")
    var icon: Texture2D = bridge.call("item_icon", "ext:a2:item:34") as Texture2D
    var ground: Texture2D = bridge.call("ground_icon", "ext:a2:item:34") as Texture2D
    var monster: Texture2D = bridge.call("npc_portrait", "ext:a2:monster:ms852") as Texture2D
    _check(icon != null, "actual PNG item missing")
    _check(ground != null, "actual PNG floor missing")
    _check(monster != null, "actual PNG monster missing")
    if icon != null:
        _check(icon.get_size() == Vector2(4, 4), "item PNG dimensions wrong")
    var link: RefCounted = LINK.new()
    var original: ImageTexture = ImageTexture.new()
    var item_node := TextureRect.new()
    var ground_node := Sprite2D.new()
    root.add_child(item_node)
    root.add_child(ground_node)
    item_node.texture = original
    ground_node.texture = original
    _check(bool(link.call("enable_feature", "item_icon", true)), "enable item")
    _check(bool(link.call("enable_feature", "ground_icon", true)), "enable ground")
    _check(bool(link.call("bind_external_texture", item_node, "item_icon", "ext:a2:item:34")), "bind external item")
    _check(bool(link.call("bind_external_texture", ground_node, "ground_icon", "ext:a2:item:34")), "bind external ground")
    _check(item_node.texture != original and item_node.texture != null, "item UI texture unchanged")
    _check(ground_node.texture != original and ground_node.texture != null, "ground texture unchanged")
    _check(int(link.call("restore_all")) == 2, "missing rollback")
    _check(item_node.texture == original and ground_node.texture == original, "resource rollback failed")

    var preview: Control = PREVIEW.instantiate() as Control
    root.add_child(preview)
    await process_frame
    var source_edit: LineEdit = preview.get("_candidate") as LineEdit
    var scene_bridge: RefCounted = preview.get("bridge") as RefCounted
    source_edit.text = "ext:a2:item:34"
    scene_bridge.call("set_feature_enabled", "item_icon", true)
    preview.call("_show_item")
    var displayed: TextureRect = preview.get("_image") as TextureRect
    _check(displayed.texture != null, "standalone scene did not display PNG")
    preview.queue_free()
    item_node.queue_free()
    ground_node.queue_free()
    if failures.is_empty():
        print("L1J_PNG_LOAD_OK")
        quit(0)
    else:
        quit(1)
