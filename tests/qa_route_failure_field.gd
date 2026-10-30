extends RefCounted
## Two disconnected, immutable native-grid islands. This is a pathfinding
## fixture, not a rendered map or a replacement for production collision.
static func create() -> NativePngField:
	var field:=NativePngField.new()
	field.width=256;field.height=128;field.cell_size=16
	field.bounds=Rect2(0,0,field.width*16,field.height*16)
	field.astar=AStarGrid2D.new()
	field.astar.region=Rect2i(0,0,field.width,field.height)
	field.astar.cell_size=Vector2(16,16)
	field.astar.offset=Vector2(8,8)
	field.astar.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	field.astar.update()
	field.astar.fill_solid_region(field.astar.region)
	field.reachable.resize(field.width*field.height)
	for island: Rect2i in [Rect2i(8,8,16,16),Rect2i(40,8,16,16)]:
		field.astar.fill_solid_region(island,false)
		for y: int in range(island.position.y,island.end.y):
			for x: int in range(island.position.x,island.end.x):field.reachable[y*field.width+x]=1
	return field
