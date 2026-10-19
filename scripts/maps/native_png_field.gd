extends PlayableField
class_name NativePngField
## Pixel coordinates come from the decoded PNG, not an assumed server map ID.
## Hand-traced floors share one navigation/physics mesh. Unreviewed pockets stay solid.
var png_manifest: Dictionary
var png_root: String

func configure_png(mid: String, plan: Dictionary, manifest: Dictionary, local_root: String) -> void:
	png_manifest = manifest
	png_root = local_root
	var spec: Dictionary = plan.maps[mid]
	var spawn: Array = spec.spawn
	var portals: Array = [{"id":"aden_return","name":"아덴 귀환","position":[spawn[0]-60,spawn[1]],"target_map":"aden_world","radius":18}]
	if mid.begins_with("albino_"):
		var next: String = "albino_%02d" % (int(mid.right(2))%3+1)
		portals.append({"id":"next","name":"다음 구역","position":[spawn[0]+60,spawn[1]],"target_map":next,"radius":18})
	portals=spec.get("portals",portals)
	var value: Dictionary = {
		"map_id":mid,"map_name":spec.name,"short_name":spec.name,
		"layout_revision":int(plan.revision),"bounds":manifest.bounds,"native_png":true,
		"navigation":{"cell_size":16,"clearance":4,"use_baked_cache":false},
		"camera":{"zoom":1.0,"offset":[0,0],"follow_speed":7.0},
		"spawn_position":spawn,"navigable_polygons":spec.walk_polygons,
		"collision":spec.get("collision",[]),"monster_spawn":[],"npc_spawn":[],"portal":portals,"teleport":[],
		"regions":spec.get("regions",[]),"surfaces":[],"roads":[],"water":[],"props":[],"bridges":[],
		"safe_zone":[],"combat_zone":[],"boss_zone":[],"route_checks":spec.route_checks,
		"minimap":{"title":spec.name},"collision_scope":spec.collision_scope,
		"population_status":spec.monster_coordinate_status}
	configure(value)
	# This mask only excludes transparent source pixels. Actual water, walls and
	# obstacles still come from the independent visual trace, never PNG colours.
	if int(manifest.get("alpha_guard_cell_size",0))==cell_size:
		for run: Array in manifest.get("alpha_solid_runs",[]):
			astar.fill_solid_region(Rect2i(int(run[1]),int(run[0]),int(run[2]),1))
		_build_reachability()

func build_physics(parent: Node2D) -> StaticBody2D:
	# The exact same solid cells used by click pathfinding stop manual movement.
	# Merge each row into runs to avoid one shape per solid cell.
	var body := StaticBody2D.new()
	body.name = "NativePngCollision"
	body.collision_layer = 4
	body.collision_mask = 0
	parent.add_child(body)
	for y: int in range(height):
		var start: int = -1
		for x: int in range(width+1):
			var solid: bool = x<width and astar.is_point_solid(Vector2i(x,y))
			if solid and start<0: start=x
			if not solid and start>=0:
				var node := CollisionShape2D.new()
				var shape := RectangleShape2D.new()
				shape.size = Vector2((x-start)*cell_size,cell_size)
				node.shape = shape
				node.position = bounds.position+Vector2((start+x)*.5*cell_size,(y+.5)*cell_size)
				body.add_child(node)
				start=-1
	# Explicit external walls cover the finite canvas as well.
	for box: Rect2 in [Rect2(bounds.position-Vector2(32,32),Vector2(bounds.size.x+64,32)),Rect2(Vector2(bounds.position.x-32,bounds.end.y),Vector2(bounds.size.x+64,32)),Rect2(bounds.position-Vector2(32,0),Vector2(32,bounds.size.y)),Rect2(Vector2(bounds.end.x,bounds.position.y),Vector2(32,bounds.size.y))]:
		var node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size=box.size;node.shape=shape;node.position=box.get_center();body.add_child(node)
	return body

func overview_texture() -> Texture2D:
	var image := Image.new()
	if image.load(png_root+"/overview.png") != OK: return null
	return ImageTexture.create_from_image(image)
