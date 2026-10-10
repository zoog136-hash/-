extends RefCounted
class_name TwilightL1JMapAttributes
## Exact source byte values, not inferred walkability. Pure lookup, no live world mutations.
var _dimensions: Vector2i = Vector2i.ZERO
var _raw: PackedByteArray = PackedByteArray()
var _source_id: int = -1

func load_a3(map_id: int, dimensions: Vector2i) -> bool:
    _raw = PackedByteArray()
    _dimensions = Vector2i.ZERO
    _source_id = -1
    if map_id < 0 or map_id > 99999:
        return false
    if dimensions.x <= 0 or dimensions.y <= 0 or dimensions.x > 4096 or dimensions.y > 4096:
        return false
    var path: String = "res://data/l1j/maps/raw/%d.bin" % map_id
    if not FileAccess.file_exists(path):
        return false
    var raw_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
    if raw_bytes.size() != dimensions.x * dimensions.y:
        return false
    _source_id = map_id
    _dimensions = dimensions
    _raw = raw_bytes
    return true

func is_loaded() -> bool:
    return _source_id >= 0

func attribute_at(cell: Vector2i) -> int:
    if not is_loaded():
        return -1
    if cell.x < 0 or cell.y < 0 or cell.x >= _dimensions.x or cell.y >= _dimensions.y:
        return -1
    return int(_raw[cell.y * _dimensions.x + cell.x])

func source_map_id() -> int:
    return _source_id
