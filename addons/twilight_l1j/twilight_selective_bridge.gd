extends RefCounted
class_name TwilightL1JSelectiveBridge
## Preview-only: safe-by-default adapter, not wired to TwilightWorld.
const REGISTRY_SCRIPT = preload("res://addons/twilight_l1j/twilight_external_registry.gd")
const KINDS := ["item_icon", "ground_icon", "npc_portrait", "sprite_frames", "map_attributes"]
var _registry: RefCounted = REGISTRY_SCRIPT.new()
var _enabled: Dictionary = {
    "item_icon": false,
    "ground_icon": false,
    "npc_portrait": false,
    "sprite_frames": false,
    "map_attributes": false,
}

func set_feature_enabled(kind: String, enabled: bool) -> bool:
    if not kind in KINDS:
        return false
    _enabled[kind] = enabled
    return true

func is_feature_enabled(kind: String) -> bool:
    return bool(_enabled.get(kind, false))

func _record(candidate_id: String) -> Dictionary:
    if not candidate_id.begins_with("ext:"):
        return {}
    var source: String = ""
    if candidate_id.begins_with("ext:a2:"):
        source = "a2_visuals"
    elif candidate_id.begins_with("ext:a3:"):
        source = "a3_items"
    elif candidate_id.begins_with("ext:go:npc:"):
        source = "go_npcs"
    elif candidate_id.begins_with("ext:go:"):
        source = "go_items"
    else:
        return {}
    if int(_registry.call("load_source", source)) < 1:
        return {}
    return _registry.call("get_record", candidate_id) as Dictionary

func _safe_texture(path: String) -> Texture2D:
    if not path.begins_with("res://assets/l1j/"):
        return null
    if not preload("res://scripts/resources/retired_assets.gd").usable(path):
        return null
    return load(path) as Texture2D

func item_icon(candidate_id: String) -> Texture2D:
    if not is_feature_enabled("item_icon"):
        return null
    return _safe_texture(str(_record(candidate_id).get("inventory_texture", "")))

func ground_icon(candidate_id: String) -> Texture2D:
    if not is_feature_enabled("ground_icon"):
        return null
    return _safe_texture(str(_record(candidate_id).get("ground_texture", "")))

func npc_portrait(candidate_id: String) -> Texture2D:
    if not is_feature_enabled("npc_portrait"):
        return null
    return _safe_texture(str(_record(candidate_id).get("portrait_texture", "")))

func _safe_sprite_id(sprite_id: String) -> bool:
    var parts: PackedStringArray = sprite_id.split("-")
    if parts.size() != 2:
        return false
    for part in parts:
        if part.is_empty():
            return false
        for ch in part:
            if not ch in "0123456789":
                return false
    return true

func sprite_frames(_sprite_id: String, _source: String = "spx") -> SpriteFrames:
    # Old L1J sprite frames under res://assets/ are retired (pre-523 pack);
    # an older install may still carry them, so they are never read.
    return null

func map_attribute(map_id: int, source: String = "a3") -> Texture2D:
    if not is_feature_enabled("map_attributes") or map_id < 0 or map_id > 99999:
        return null
    var path: String = ""
    match source:
        "a3":
            path = "res://data/l1j/maps/attributes/%d.png" % map_id
        "jp":
            path = "res://data/l1j/candidates/jp_maps/attributes/%d.png" % map_id
        _:
            return null
    if not preload("res://scripts/resources/retired_assets.gd").usable(path):
        return null
    return load(path) as Texture2D

func record_details(candidate_id: String) -> Dictionary:
    return _record(candidate_id).duplicate(true)
