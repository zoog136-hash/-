extends SceneTree
const COORD = preload("res://addons/twilight_l1j/twilight_tile_coordinates.gd")
const MAP = preload("res://addons/twilight_l1j/twilight_map_attributes.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    if not ok:
        errors.append(label)
        print("L1J_MAP_GRID_FAIL: " + label)

func _run() -> void:
    var coord: RefCounted = COORD.new()
    _check(not bool(coord.call("is_configured")), "unsafe default")
    _check(coord.call("cell_to_world", Vector2i.ZERO) == Vector2.INF, "conversion without calibration")
    var invalid := Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
    _check(not bool(coord.call("configure", Vector2i(2048, 1536), Vector2i.ZERO, invalid)), "singular calibration")
    var flat := Transform2D(Vector2(32, 0), Vector2(0, 32), Vector2(100, 200))
    _check(bool(coord.call("configure", Vector2i(2048, 1536), Vector2i(32768, 32768), flat)), "valid calibration")
    for cell: Vector2i in [Vector2i(0, 0), Vector2i(512, 384), Vector2i(2047, 1535)]:
        var pixel: Vector2 = coord.call("cell_to_world", cell)
        _check(coord.call("world_to_cell", pixel) == cell, "world/source roundtrip " + str(cell))
    _check(coord.call("cell_to_world", Vector2i(2048, 0)) == Vector2.INF, "accepted out-of-bounds cell")
    var rotated := Transform2D(Vector2(16, 8), Vector2(-16, 8), Vector2(300, -100))
    _check(bool(coord.call("configure", Vector2i(192, 192), Vector2i(120, 250), rotated)), "rotated basis")
    _check(coord.call("world_to_cell", coord.call("cell_to_world", Vector2i(191, 191))) == Vector2i(191, 191), "rotated roundtrip")

    var attrs: RefCounted = MAP.new()
    _check(not bool(attrs.call("load_a3", 4, Vector2i(5, 3))), "invalid byte length accepted")
    var actual_size := Vector2i(4, 3)
    var first_byte: int = 0
    var last_byte: int = 11
    if FileAccess.file_exists("res://data/l1j/maps/source_maps.json"):
        var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/l1j/maps/source_maps.json"))
        for row: Dictionary in source.get("maps", []):
            if int(row.map_id) == 4:
                actual_size = Vector2i(int(row.dimensions[0]), int(row.dimensions[1]))
                var raw: PackedByteArray = FileAccess.get_file_as_bytes("res://data/l1j/maps/raw/4.bin")
                _check(FileAccess.get_sha256("res://data/l1j/maps/raw/4.bin") == str(row.row_major_sha256), "installed source map digest")
                first_byte = raw[0]
                last_byte = raw[-1]
    _check(bool(attrs.call("load_a3", 4, actual_size)), "installed source tile bytes missing")
    _check(int(attrs.call("attribute_at", Vector2i.ZERO)) == first_byte, "first byte mismatch")
    _check(int(attrs.call("attribute_at", actual_size - Vector2i.ONE)) == last_byte, "last byte mismatch")
    _check(int(attrs.call("attribute_at", Vector2i(actual_size.x, 2))) == -1, "bounds mismatch")
    _check(not bool(attrs.call("load_a3", 4, Vector2i.ZERO)), "invalid dimensions accepted")
    _check(not bool(attrs.call("is_loaded")), "failed reload retained previous mapping")
    if errors.is_empty():
        print("L1J_MAP_GRID_OK")
        quit(0)
    else:
        quit(1)
