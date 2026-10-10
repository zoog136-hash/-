extends SceneTree
const BRIDGE = preload("res://addons/twilight_l1j/twilight_selective_bridge.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, label: String) -> void:
    if not value:
        failures.append(label)
        print("L1J_SPX_FRAMES_FAIL: " + label)

func _run() -> void:
    var bridge: RefCounted = BRIDGE.new()
    var absent: SpriteFrames = bridge.call("sprite_frames", "99999-0", "spx") as SpriteFrames
    _check(absent == null, "disabled bridge loaded frames")
    bridge.call("set_feature_enabled", "sprite_frames", true)
    var frames: SpriteFrames = bridge.call("sprite_frames", "99999-0", "spx") as SpriteFrames
    _check(frames != null, "valid SpriteFrames .tres was not imported")
    if frames != null:
        _check(frames.has_animation("default"), "default animation missing")
        _check(frames.get_frame_count("default") == 2, "wrong frame count")
        _check(frames.get_frame_texture("default", 0) != null, "PNG frame 0 missing")
        _check(frames.get_frame_texture("default", 1) != null, "PNG frame 1 missing")
        var actor := AnimatedSprite2D.new()
        root.add_child(actor)
        actor.sprite_frames = frames
        actor.animation = "default"
        actor.frame = 1
        _check(actor.texture_filter == CanvasItem.TEXTURE_FILTER_INHERIT, "unexpected sprite config")
        _check(actor.sprite_frames.get_frame_count(actor.animation) == 2, "animation not applied to Sprite2D")
        actor.queue_free()
    if failures.is_empty():
        print("L1J_SPX_FRAMES_OK")
        quit(0)
    else:
        quit(1)
