extends RefCounted
class_name TwilightL1JVisualLink
## Reversible, optional runtime image and frames binding. No save/catalog mutations.
const BRIDGE_SCRIPT = preload("res://addons/twilight_l1j/twilight_selective_bridge.gd")
var _bridge: RefCounted = BRIDGE_SCRIPT.new()
var _previous: Dictionary = {}

func enable_feature(kind: String, enabled: bool) -> bool:
    return bool(_bridge.call("set_feature_enabled", kind, enabled))

func feature_enabled(kind: String) -> bool:
    return bool(_bridge.call("is_feature_enabled", kind))

func _replace_resource(target: Node, property_name: String, value: Resource) -> bool:
    if target == null or not is_instance_valid(target) or value == null:
        return false
    var key: String = "%d:%s" % [target.get_instance_id(), property_name]
    if not _previous.has(key):
        _previous[key] = {"node": weakref(target), "property": property_name, "original": target.get(property_name)}
    target.set(property_name, value)
    return true

func apply_texture(target: Node, kind: String, texture: Texture2D) -> bool:
    if not feature_enabled(kind) or texture == null:
        return false
    if kind not in ["item_icon", "ground_icon", "npc_portrait"]:
        return false
    if not (target is TextureRect or target is Sprite2D):
        return false
    return _replace_resource(target, "texture", texture)

func bind_external_texture(target: Node, kind: String, candidate_id: String) -> bool:
    if not feature_enabled(kind) or not candidate_id.begins_with("ext:"):
        return false
    var texture: Texture2D = null
    match kind:
        "item_icon":
            texture = _bridge.call("item_icon", candidate_id) as Texture2D
        "ground_icon":
            texture = _bridge.call("ground_icon", candidate_id) as Texture2D
        "npc_portrait":
            texture = _bridge.call("npc_portrait", candidate_id) as Texture2D
        _:
            return false
    return apply_texture(target, kind, texture)

func apply_frames(target: AnimatedSprite2D, frames: SpriteFrames) -> bool:
    if not feature_enabled("sprite_frames") or target == null or frames == null:
        return false
    return _replace_resource(target, "sprite_frames", frames)

func bind_external_frames(target: AnimatedSprite2D, sprite_id: String, source: String = "spx") -> bool:
    if not feature_enabled("sprite_frames"):
        return false
    var frames: SpriteFrames = _bridge.call("sprite_frames", sprite_id, source) as SpriteFrames
    return apply_frames(target, frames)

func restore_all() -> int:
    var restored: int = 0
    for key: String in _previous.keys():
        var snapshot: Dictionary = _previous[key] as Dictionary
        var handle: WeakRef = snapshot.get("node") as WeakRef
        var target: Node = handle.get_ref() as Node if handle != null else null
        if target == null or not is_instance_valid(target):
            continue
        target.set(str(snapshot.get("property", "")), snapshot.get("original"))
        restored += 1
    _previous.clear()
    return restored

func tracked_bindings() -> int:
    return _previous.size()
