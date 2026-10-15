extends RefCounted
class_name OriginalMapCoordinates
## Source integers name cells; actor/NPC foot points use their centers.
## Default: supplied MapViewer's +X NE, +Y SE, 48x24 diamond.
## Per-map measured affine bases also support flips and different scales.
## Keep scalar doubles until the final canvas point to preserve save precision.
var origin := Vector2i.ZERO
var dimensions := Vector2i.ONE
var basis_x := Vector2(24,-12)
var basis_y := Vector2(24,12)
var translation := Vector2(0,12)
var valid: bool = false
var determinant: float = 576.0

func configure(source_origin: Array, size: Array, mapping: Dictionary = {}) -> bool:
	valid = false
	if not _pair(source_origin) or not _pair(size): return false
	if float(size[0]) < 1 or float(size[1]) < 1 or float(size[0]) > 65536 or float(size[1]) > 65536: return false
	for value: Variant in source_origin + size:
		if float(value) != floorf(float(value)) or absf(float(value)) > 2147480000: return false
	var bx: Variant = mapping.get("basis_x",[24,-12])
	var by: Variant = mapping.get("basis_y",[24,12])
	var offset: Variant = mapping.get("translation",[0,12*int(size[0])])
	if not _pair(bx) or not _pair(by) or not _pair(offset): return false
	var det: float = float(bx[0])*float(by[1])-float(bx[1])*float(by[0])
	if absf(det) < 0.000001 or absf(det) > 100000000: return false
	origin = Vector2i(int(source_origin[0]),int(source_origin[1]))
	dimensions = Vector2i(int(size[0]),int(size[1]))
	basis_x = Vector2(float(bx[0]),float(bx[1]))
	basis_y = Vector2(float(by[0]),float(by[1]))
	translation = Vector2(float(offset[0]),float(offset[1]))
	determinant = float(basis_x.x)*basis_y.y-float(basis_x.y)*basis_y.x
	valid = true
	return true

func _pair(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for item: Variant in value:
		if not (item is int or item is float) or not is_finite(float(item)): return false
	return true

func grid_to_world(x: float, y: float) -> Vector2:
	if not valid or not is_finite(x) or not is_finite(y): return Vector2.INF
	return Vector2(basis_x.x*x+basis_y.x*y+translation.x,basis_x.y*x+basis_y.y*y+translation.y)

func to_world(source: Vector2, center: bool = true) -> Vector2:
	var half: float = 0.5 if center else 0.0
	return grid_to_world(float(source.x)-origin.x+half,float(source.y)-origin.y+half)

func to_source(pixel: Vector2) -> Vector2:
	var xy: Array = source_components(pixel)
	return Vector2(xy[0],xy[1])

func grid_components(pixel: Vector2) -> Array:
	if not valid or not pixel.is_finite(): return [INF,INF]
	var x: float = float(pixel.x)-translation.x
	var y: float = float(pixel.y)-translation.y
	return [(x*basis_y.y-y*basis_y.x)/determinant,(y*basis_x.x-x*basis_x.y)/determinant]

func world_to_grid(pixel: Vector2) -> Vector2:
	var xy: Array = grid_components(pixel)
	return Vector2(xy[0],xy[1])

func cell_to_world(cell: Vector2i) -> Vector2: return grid_to_world(cell.x+0.5,cell.y+0.5)

func world_to_cell(pixel: Vector2) -> Vector2i:
	var xy: Array = grid_components(pixel)
	if not is_finite(xy[0]) or not is_finite(xy[1]) or absf(xy[0]) > 2147480000 or absf(xy[1]) > 2147480000: return Vector2i(-1,-1)
	return Vector2i(floori(xy[0]),floori(xy[1]))

func source_components(pixel: Vector2) -> Array:
	var xy: Array = grid_components(pixel)
	return [origin.x+xy[0],origin.y+xy[1]]

func components_to_world(source: Array) -> Vector2:
	if not _pair(source): return Vector2.INF
	return grid_to_world(float(source[0])-origin.x,float(source[1])-origin.y)

func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([grid_to_world(cell.x,cell.y),grid_to_world(cell.x+1,cell.y),grid_to_world(cell.x+1,cell.y+1),grid_to_world(cell.x,cell.y+1)])

func edge_points(cell: Vector2i, heading: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = cell_polygon(cell)
	var edge: int = posmod(heading/2,4)
	return PackedVector2Array([polygon[edge],polygon[(edge+1)%4]])

func half_tile_position(chunk_origin: Vector2i, half_x: int, y: int) -> Vector2:
	return to_world(Vector2(chunk_origin)+Vector2(floori(half_x/2.0),y))-basis_y+float(half_x&1)*(basis_x+basis_y)*0.5

func canvas_bounds() -> Rect2:
	if not valid: return Rect2()
	var rect := Rect2(grid_to_world(0,0),Vector2.ZERO)
	for corner: Vector2 in [grid_to_world(dimensions.x,0),grid_to_world(0,dimensions.y),grid_to_world(dimensions.x,dimensions.y)]: rect = rect.expand(corner)
	return rect
