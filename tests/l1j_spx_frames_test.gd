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
    var sprite_id: String = "99999-0"
    var expected_count: int = 2
    var fixture_frames: String = "res://assets/l1j/candidates/spx_converted/99999-0/SpriteFrames.tres"
    var fixture_metadata: String = "res://assets/l1j/candidates/spx_converted/99999-0/frame_metadata.json"
    var original_frames: String = "res://assets/l1j/candidates/spx_converted/21624-0/SpriteFrames.tres"
    var original_metadata: String = "res://assets/l1j/candidates/spx_converted/21624-0/frame_metadata.json"
    var fixture_present: bool = FileAccess.file_exists(fixture_frames) or FileAccess.file_exists(fixture_metadata)
    var original_present: bool = FileAccess.file_exists(original_frames) or FileAccess.file_exists(original_metadata)
    if not fixture_present and not original_present:
        print("L1J_SPX_FRAMES_SKIP: optional original SPX sequence and explicit CI fixture are absent; original art remains unavailable")
        quit(0)
        return
    if not fixture_present:
        # Installed source packs contain genuine sequence IDs, never the CI ID.
        sprite_id = "21624-0"
        if FileAccess.file_exists(original_metadata):
            var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(original_metadata))
            if source is Dictionary: expected_count = int(source.get("frame_count", 0))
        else:
            _check(false, "partially installed original sequence lacks metadata")
        _check(expected_count > 1, "original sequence metadata missing")
    var bridge: RefCounted = BRIDGE.new()
    var absent: SpriteFrames = bridge.call("sprite_frames", sprite_id, "spx") as SpriteFrames
    _check(absent == null, "disabled bridge loaded frames")
    bridge.call("set_feature_enabled", "sprite_frames", true)
    var frames: SpriteFrames = bridge.call("sprite_frames", sprite_id, "spx") as SpriteFrames
    _check(frames != null, "valid SpriteFrames .tres was not imported")
    if frames != null:
        _check(frames.has_animation("default"), "default animation missing")
        _check(frames.get_frame_count("default") == expected_count, "wrong frame count")
        _check(frames.get_frame_texture("default", 0) != null, "PNG frame 0 missing")
        _check(frames.get_frame_texture("default", 1) != null, "PNG frame 1 missing")
        var actor := AnimatedSprite2D.new()
        root.add_child(actor)
        actor.sprite_frames = frames
        actor.animation = "default"
        actor.frame = 1
        _check(actor.sprite_frames.get_frame_count(actor.animation) == expected_count, "animation not applied to Sprite2D")
        actor.queue_free()
    if failures.is_empty():
        print("L1J_SPX_FRAMES_OK")
        quit(0)
    else:
        quit(1)
