extends SceneTree
## Teleport/map entry: new map-object sprites load under a per-refresh time
## budget and the rest follow on the next frames. Synthetic sprites only.
##   godot --headless --path <repo> --script res://tests/current523_bank_object_load_budget_test.gd
const OBJECTS=preload("res://scripts/maps/current523_bank_objects.gd")
const LAYERS=preload("res://tests/current523_bank_object_layers_test.gd")
const LOAD_USEC: int=8000
class Mapping extends RefCounted:
	func to_world(raw: Vector2, _wrap: bool) -> Vector2: return raw
class SlowFixture extends LAYERS.Fixture:
	var texture: Texture2D
	var loads: Array[int]=[]
	var per_refresh: Array[int]=[]
	func _load_sprite(id: int) -> Dictionary:
		loads.append(id)
		var until: int=Time.get_ticks_usec()+LOAD_USEC
		while Time.get_ticks_usec()<until: pass
		if id==99: return {"ok":false,"error":"fixture_absent"}
		return {"ok":true,"static":true,"frames":[{"layers":[{"fixture_texture":texture,"offset":[0,0]}]}]}
	func refresh(records: Array[Dictionary], malformed: int=0) -> void:
		var before: int=loads.size()
		super.refresh(records,malformed)
		per_refresh.append(loads.size()-before)
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("MAP_OBJECT_LOAD_BUDGET_FAIL: "+label)
func rows(ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for i: int in ids.size():result.append({"sprite_id":ids[i],"raw_x":float(i*8),"raw_y":0.0})
	return result
func owner(budget: int) -> SlowFixture:
	var image:=Image.create_empty(4,4,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	var value:=SlowFixture.new();value.texture=ImageTexture.create_from_image(image)
	value.coordinates=Mapping.new();value._mode="compatible";value.sprite_load_budget_usec=budget
	root.add_child(value);value.set_process(false)
	return value
func run() -> void:
	var ids: Array=[1,2,3,1,4,5,99,6]
	# Default: every new sprite in one refresh (unchanged behavior).
	var plain: SlowFixture=owner(-1)
	plain.refresh(rows(ids))
	check(plain.per_refresh==[7] and plain._nodes.size()==7 and not plain.metrics().has("deferred_records"),"no budget loads all sprites in one refresh")
	# Budgeted: at most two 8 ms loads per 12 ms refresh, the rest follow.
	var budgeted: SlowFixture=owner(OBJECTS.FRAME_SPRITE_LOAD_BUDGET_USEC)
	budgeted.refresh(rows(ids))
	check(budgeted.per_refresh[0]==2,"first refresh loads only within its budget (%d)"%budgeted.per_refresh[0])
	check(int(budgeted.metrics().deferred_records)>0 and budgeted._pending_refresh,"remaining records are deferred, not unresolved")
	check(budgeted.metrics().unresolved_records==0,"a deferred record is not counted as unresolved")
	var steps: int=0
	while budgeted._pending_refresh and steps<20:
		budgeted._process_step(0.016)
		steps+=1
	for count: int in budgeted.per_refresh: check(count<=2,"each refresh starts at most two new loads")
	check(budgeted._nodes.size()==plain._nodes.size(),"every placement appears after the following frames (%d/%d)"%[budgeted._nodes.size(),plain._nodes.size()])
	var order_plain: Array=[];var order_budgeted: Array=[]
	for node: Node2D in plain._nodes:order_plain.append([node.position,node.get_meta("sprite_id")])
	for node: Node2D in budgeted._nodes:order_budgeted.append([node.position,node.get_meta("sprite_id")])
	check(order_plain==order_budgeted,"final placements keep the exact source order and coordinates")
	check(budgeted.loads.size()==7 and budgeted.metrics().unresolved_records==1 and int(budgeted.metrics().deferred_records)==0,"each sprite loads once; a real failure stays unresolved")
	# Already loaded sprites are never delayed.
	var before: int=budgeted.loads.size()
	budgeted.refresh(rows([6,5,4,3,2,1]))
	check(budgeted.loads.size()==before and not budgeted._pending_refresh and budgeted._nodes.size()==6,"cached sprites show at once without loads")
	plain.free();budgeted.free()
	print("MAP_OBJECT_LOAD_BUDGET_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
