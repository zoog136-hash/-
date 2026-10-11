extends RefCounted
class_name TwilightL1JTileCoordinates
## External L1J tile -> TWILIGHT pixel projection. Never writes live collision or movement.
## Requires an explicitly calibrated source origin and invertible transform.
var _ready: bool = false
var _grid_size: Vector2i = Vector2i.ZERO
var _tile_origin: Vector2i = Vector2i.ZERO
var _transform: Transform2D = Transform2D.IDENTITY
var _inverse: Transform2D = Transform2D.IDENTITY

func configure(grid_size: Vector2i, source_tile_origin: Vector2i, mapping: Transform2D) -> bool:
    _ready = false
    if grid_size.x <= 0 or grid_size.y <= 0 or grid_size.x > 4096 or grid_size.y > 4096:
        return false
    if not mapping.x.is_finite() or not mapping.y.is_finite() or not mapping.origin.is_finite():
        return false
    var determinant: float = mapping.determinant()
    if not is_finite(determinant) or absf(determinant) < 0.000001:
        return false
    var inverse: Transform2D = mapping.affine_inverse()
    if not inverse.x.is_finite() or not inverse.y.is_finite() or not inverse.origin.is_finite():
        return false
    _grid_size = grid_size
    _tile_origin = source_tile_origin
    _transform = mapping
    _inverse = inverse
    _ready = true
    return true

func is_configured() -> bool:
    return _ready

func in_bounds(cell: Vector2i) -> bool:
    return _ready and cell.x >= 0 and cell.y >= 0 and cell.x < _grid_size.x and cell.y < _grid_size.y

func cell_to_world(cell: Vector2i, center: bool = true) -> Vector2:
    if not in_bounds(cell):
        return Vector2.INF
    var frac: Vector2 = Vector2(0.5, 0.5) if center else Vector2.ZERO
    var result: Vector2 = _transform * (Vector2(cell + _tile_origin) + frac)
    return result if result.is_finite() else Vector2.INF

func world_to_cell(world_pixel: Vector2) -> Vector2i:
    if not _ready or not world_pixel.is_finite():
        return Vector2i(-1, -1)
    var source: Vector2 = _inverse * world_pixel - Vector2(_tile_origin)
    if not source.is_finite() or source.x < 0 or source.y < 0 or source.x >= _grid_size.x or source.y >= _grid_size.y:
        return Vector2i(-1, -1)
    var cell: Vector2i = Vector2i(floori(source.x), floori(source.y))
    return cell if in_bounds(cell) else Vector2i(-1, -1)
