extends SceneTree
class SafeMeter extends PlayableField:
	var safe_queries: int=0
	func is_safe(point: Vector2) -> bool:
		safe_queries+=1
		return super.is_safe(point)
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SPAWN_SAFE_MEMO_FAIL "+label)
func _initialize() -> void:call_deferred("run")
func definition(right_safe: bool) -> Dictionary:
	return {"map_id":"safe_memo_fixture","map_name":"fixture","bounds":[0,0,256,256],"navigation":{"cell_size":16,"clearance":0,"use_baked_cache":false},"spawn_position":[8,8],"collision":[],"regions":[{"id":"safe","type":"safe","rect":[128 if right_safe else 0,0,128,256]},{"id":"combat","type":"combat","rect":[0,0,256,256]}],"monster_spawn":[{"id":"a","rect":[0,0,256,256]},{"id":"b","rect":[0,0,256,256]},{"id":"c","rect":[32,32,128,128]}]}
func run() -> void:
	var field:=SafeMeter.new()
	for right_safe: bool in [false,true]:
		field.safe_queries=0
		field.configure(definition(right_safe))
		check(field.safe_queries==256,"one safe query per reachable cell despite overlapping spawn regions")
		for region: Dictionary in field.data.monster_spawn:
			var expected: Array[Vector2i]=[]
			var box: Array=region.rect
			for y: int in range(int(box[1])/16,(int(box[1])+int(box[3]))/16):
				for x: int in range(int(box[0])/16,(int(box[0])+int(box[2]))/16):
					var cell:=Vector2i(x,y)
					if field.reachable[y*field.width+x]!=0 and not field.is_safe(field.cell_to_world(cell)) and field.spawn_contains(region,field.cell_to_world(cell)):expected.append(cell)
			check(field.spawn_cells[region.id]==expected,"ordered original predicate results "+str(region.id))
		check(field.spawn_cells.a.size()==128,"no density loss outside the safe region")
		var first: Vector2i=field.spawn_cells.a[0]
		check(first.x==(0 if right_safe else 8),"reconfiguration does not reuse previous safe map")
	print("SPAWN_SAFE_MEMO_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
