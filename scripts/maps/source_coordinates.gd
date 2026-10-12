extends RefCounted
class_name OriginalMapCoordinates
## Supplied MapViewer: +X NE, +Y SE, 48x24 diamonds and 24x24 halves.
## Source integers address tiles. Foot points add (0.5,0.5); inverse floors cells.
var origin := Vector2i.ZERO
var dimensions := Vector2i.ONE
func configure(source_origin: Array, size: Array) -> void:
	origin=Vector2i(int(source_origin[0]),int(source_origin[1]))
	dimensions=Vector2i(int(size[0]),int(size[1]))
func to_world(source: Vector2, center: bool = true) -> Vector2:
	var p: Vector2=source-Vector2(origin)+(Vector2(0.5,0.5) if center else Vector2.ZERO)
	return Vector2(24*(p.x+p.y),12*(p.y-p.x+dimensions.x))
func to_source(pixel: Vector2) -> Vector2:
	return Vector2(origin)+world_to_grid(pixel)
## Keep local navigation calculations away from the large source origin.
## Adding 32768 in a float32 Vector2 before subtracting it quantizes edge tests.
func world_to_grid(pixel: Vector2) -> Vector2:
	var a: float=pixel.x/24.0
	var b: float=pixel.y/12.0-dimensions.x
	return Vector2((a-b)/2,(a+b)/2)
func cell_to_world(cell: Vector2i) -> Vector2: return to_world(Vector2(cell+origin))
func world_to_cell(pixel: Vector2) -> Vector2i:
	if not pixel.is_finite(): return Vector2i(-1,-1)
	var a: float=pixel.x/24.0
	var b: float=pixel.y/12.0-dimensions.x
	return Vector2i(floori((a-b)/2),floori((a+b)/2))
## Arrays retain double precision around source coordinates near 32768.
## Vector2 stores float32; using it for persisted fractional source values loses pixels.
func source_components(pixel: Vector2) -> Array:
	var a: float=pixel.x/24.0
	var b: float=pixel.y/12.0-dimensions.x
	return [origin.x+(a-b)/2,origin.y+(a+b)/2]
func components_to_world(source: Array) -> Vector2:
	var x: float=float(source[0])-origin.x
	var y: float=float(source[1])-origin.y
	return Vector2(24*(x+y),12*(y-x+dimensions.x))
func half_tile_position(chunk_origin: Vector2i, half_x: int, y: int) -> Vector2:
	return to_world(Vector2(chunk_origin)+Vector2(floori(half_x/2.0),y))+Vector2((half_x&1)*24-24,-12)
func canvas_bounds() -> Rect2: return Rect2(Vector2.ZERO,Vector2(24,12)*(dimensions.x+dimensions.y))
