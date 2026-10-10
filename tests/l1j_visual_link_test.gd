extends SceneTree
const LINK_SCRIPT = preload("res://addons/twilight_l1j/twilight_visual_link.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, reason: String) -> void:
    if not condition:
        failures.append(reason)
        print("L1J_VISUAL_LINK_FAIL: " + reason)

func _texture(color: Color) -> ImageTexture:
    var picture: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
    picture.fill(color)
    return ImageTexture.create_from_image(picture)

func _run() -> void:
    var link: RefCounted = LINK_SCRIPT.new()
    var first: ImageTexture = _texture(Color.RED)
    var replacement: ImageTexture = _texture(Color.GREEN)
    var item: TextureRect = TextureRect.new()
    var drop: Sprite2D = Sprite2D.new()
    var actor: AnimatedSprite2D = AnimatedSprite2D.new()
    root.add_child(item)
    root.add_child(drop)
    root.add_child(actor)
    item.texture = first
    drop.texture = first
    var original_frames: SpriteFrames = SpriteFrames.new()
    var imported_frames: SpriteFrames = SpriteFrames.new()
    actor.sprite_frames = original_frames

    _check(not bool(link.call("feature_enabled", "item_icon")), "icon unexpectedly enabled")
    _check(not bool(link.call("apply_texture", item, "item_icon", replacement)), "inactive changed")
    _check(item.texture == first, "inactive mutated")
    _check(bool(link.call("enable_feature", "item_icon", true)), "enable item rejected")
    _check(bool(link.call("apply_texture", item, "item_icon", replacement)), "item bind failed")
    _check(item.texture == replacement, "item not replaced")
    _check(bool(link.call("enable_feature", "ground_icon", true)), "enable drop rejected")
    _check(bool(link.call("apply_texture", drop, "ground_icon", replacement)), "drop bind failed")
    _check(drop.texture == replacement, "drop not replaced")
    _check(bool(link.call("enable_feature", "sprite_frames", true)), "enable frames rejected")
    _check(bool(link.call("apply_frames", actor, imported_frames)), "frames bind failed")
    _check(actor.sprite_frames == imported_frames, "frames not replaced")
    _check(not bool(link.call("enable_feature", "save_game", true)), "invalid feature accepted")
    _check(not bool(link.call("bind_external_texture", item, "item_icon", "../unsafe")), "unsafe ID accepted")
    _check(int(link.call("tracked_bindings")) == 3, "tracking count differs")
    _check(int(link.call("restore_all")) == 3, "restore count differs")
    _check(item.texture == first, "item restore failed")
    _check(drop.texture == first, "drop restore failed")
    _check(actor.sprite_frames == original_frames, "frames restore failed")
    _check(int(link.call("tracked_bindings")) == 0, "snapshot leak")
    if not FileAccess.file_exists("res://data/l1j/registry/a2_visuals_normalized.json"):
        _check(not bool(link.call("bind_external_texture", item, "item_icon", "ext:a2:item:34")), "missing pack should not bind")
    item.queue_free()
    drop.queue_free()
    actor.queue_free()
    if failures.is_empty():
        print("L1J_VISUAL_LINK_OK")
        quit(0)
    else:
        quit(1)
