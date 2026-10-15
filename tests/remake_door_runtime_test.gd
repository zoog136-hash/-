extends SceneTree
## Synthetic door overlay on a real installed floor; not original door evidence.
var failures: Array[String]=[]
var checks: int=0
var world: TwilightWorld
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("REMAKE_DOOR_FAIL "+label)
func rendered(edge: PackedVector2Array) -> bool:
	for chunk: Node in world.field_renderer.chunks.values():
		for node: Node in chunk.get_children():
			if not node is RemakeSourceRenderer.BoundaryRow: continue
			for segment: PackedVector2Array in node.segments:
				if segment==edge or (segment[0]==edge[1] and segment[1]==edge[0]): return true
	return false
func run() -> void:
	if not preload("res://scripts/maps/remake_registry.gd").installed("oman_01"):
		print("REMAKE_DOOR_SKIP: private source floor absent");quit();return
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.save_timer=-100000;world._set_map("oman_01",false)
	world.set_process(false);world.player.set_physics_process(false);world.field_population.set_process(false)
	var field: RemakePlayableField=world.field_map
	check(field.definition.doors.is_empty(),"test fixture must not replace real doors")
	if not field.definition.doors.is_empty(): quit(1);return
	var cell:=Vector2i(-1,-1)
	var near: Vector2i=field.world_to_cell(world.player.global_position)
	for y: int in range(near.y-4,near.y+5):
		for x: int in range(near.x-4,near.x+5):
			if field.can_step(Vector2i(x,y),4) and field.can_step(Vector2i(x,y+1),0): cell=Vector2i(x,y)
	check(cell.x>=0,"real open edge selected")
	if cell.x<0: quit(1);return
	var edge: PackedVector2Array=field.coordinates.edge_points(cell,4)
	var ray:=PhysicsRayQueryParameters2D.create(field.cell_to_world(cell),field.cell_to_world(cell+Vector2i.DOWN),4)
	var sx: int=cell.x+field.coordinates.origin.x
	var sy: int=cell.y+field.coordinates.origin.y
	field.source_doors.configure([{"id":999,"direction":0,"locx":sx,"locy":sy,"left_edge_location":sx,"right_edge_location":sx}],field.coordinates.origin)
	for opened: bool in [false,true,false,true]:
		field.source_doors.set_open(999,opened)
		world.field_renderer.refresh_visible()
		await physics_frame
		await physics_frame
		var hit: Dictionary=world.get_world_2d().direct_space_state.intersect_ray(ray)
		check(field.can_step(cell,4)==opened,"navigation follows door state")
		check(hit.is_empty()==opened,"real physics follows door state")
		check(rendered(edge)!=opened,"rendered stone boundary follows door state")
	field.source_doors.configure([],field.coordinates.origin)
	world.field_renderer.refresh_visible()
	world.queue_free();await process_frame
	print("REMAKE_DOOR_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"door_provenance":"SYNTHETIC_QA_OVERLAY_NOT_A3_DOOR"}))
	quit(0 if failures.is_empty() else 1)
