extends SceneTree

# Regression: merged PR80 must ship the actual 723 atlases, not just
# generators and a fallback loader that silently passes when art is absent.
const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
const EXPECTED: Dictionary = {"transform": 413, "doll": 166, "relic": 144}

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("PR80_RESOURCE_ASSETS_FAIL " + reason)
    quit(1)

func _run() -> void:
    var path: String = "res://data/visuals/runtime_manifest.json"
    if not FileAccess.file_exists(path):
        _fail("manifest not shipped")
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not raw is Dictionary:
        _fail("manifest parse")
        return
    var manifest: Dictionary = raw
    if int(manifest.get("schema", 0)) != 1:
        _fail("manifest schema")
        return
    var catalog: Dictionary = manifest.get("catalog", {})
    if catalog.size() != 723:
        _fail("expected 723 catalog IDs; got " + str(catalog.size()))
        return
    var counts: Dictionary = {"transform": 0, "doll": 0, "relic": 0}
    var sampled: Dictionary = {}
    var frames: int = 0
    for key: String in catalog:
        var info: Dictionary = catalog[key]
        var kind: String = key.get_slice(":", 0)
        if not counts.has(kind):
            _fail("unknown type " + kind)
            return
        counts[kind] = int(counts[kind]) + 1
        var atlas: String = str(info.get("atlas", ""))
        if not atlas.begins_with("res://assets/catalog_motion/") or not atlas.ends_with(".webp"):
            _fail("unexpected atlas path for " + key)
            return
        if not FileAccess.file_exists(atlas) or not ResourceLoader.exists(atlas):
            _fail("atlas missing for " + key)
            return
        for raw_track: Variant in info.get("tracks", []):
            if not raw_track is Dictionary:
                _fail("invalid animation track for " + key)
                return
            frames += int((raw_track as Dictionary).get("count", 0))
        if not sampled.has(kind):
            var clips: SpriteFrames = VISUALS.catalog_frames(key)
            if clips == null or clips.get_animation_names().is_empty():
                _fail("runtime could not load " + key)
                return
            sampled[kind] = true
    if frames != 41442:
        _fail("expected 41442 frames, got " + str(frames))
        return
    for kind: String in EXPECTED:
        if int(counts[kind]) != int(EXPECTED[kind]):
            _fail("wrong " + kind + " count: " + str(counts[kind]))
            return
    print("PR80_RESOURCE_ASSETS_OK 723 WebP atlases, 41442 frames, 3 kinds runtime-linked")
    quit(0)
