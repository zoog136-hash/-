extends SceneTree
## 사용자 목록 11 (월드맵): the minimap's tap opens the original world map when it
## is connected (and still walks without it); the map's Nd_Page zoom steps
## the picture around the view's middle through its three page marks; Map_All
## 내 위치 보기 binds only when the UI pack has its nodes. Synthetic, no pack.
const MINIMAP=preload("res://scripts/maps/field_minimap.gd")
const TAB=preload("res://scripts/ui/original_ui/source_main_map_area_tab.gd")
const SCROLL=preload("res://scripts/ui/original_ui/source_scroll.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	var connected: bool=true
	var opened: int=0
	func open_world_map_from_minimap() -> bool:
		if connected:opened+=1
		return connected

class FakeWorld extends Node:
	var hud: FakeHud
	var destinations: Array=[]
	func _set_click_destination(at: Vector2) -> void:destinations.append(at)

class FakePlayer extends Node2D:
	var source_nodes: Dictionary={}
	var shown: Dictionary={}
	func set_bound_visible(offset: int, value: bool) -> Dictionary:
		shown[offset]=value
		return {"ok":true}

class FakePack extends RefCounted:
	var manifest: Dictionary={"node_scopes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("WORLD_MAP_ENTRY_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _press(at: Vector2) -> InputEventScreenTouch:
	var event:=InputEventScreenTouch.new()
	event.pressed=true
	event.position=at
	return event

func _run() -> void:
	_minimap()
	_zoom()
	_self_position()
	print("WORLD_MAP_ENTRY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _minimap() -> void:
	var world:=FakeWorld.new()
	world.hud=FakeHud.new()
	var minimap=MINIMAP.new()
	minimap.world=world
	root.add_child(world)
	world.add_child(world.hud)
	minimap.visible=false
	world.add_child(minimap)
	minimap.set_process(false)
	minimap._gui_input(_press(Vector2(60,60)))
	check(world.hud.opened==1 and world.destinations.is_empty(),"a minimap tap opens the original world map instead of walking")
	world.hud.connected=false
	minimap._gui_input(_press(Vector2(60,60)))
	check(world.destinations.size()==1,"without the original map the minimap tap still walks there")
	minimap._gui_input(_press(Vector2(1,1)))
	check(world.destinations.size()==1 and world.hud.opened==1,"a tap outside the minimap picture does nothing")
	world.queue_free()

func _zoom() -> void:
	var tab=TAB.new()
	var player:=FakePlayer.new()
	var holder:=Node2D.new()
	var scroll=SCROLL.new()
	scroll.configure({"innerSize":[3200,1974]},Vector2(960,468))
	scroll.bind_input(func(_event: InputEvent) -> void: pass)
	holder.add_child(scroll)
	holder.set_meta("source_scroll",scroll)
	player.add_child(holder)
	root.add_child(player)
	player.source_nodes[TAB.MAP_SCROLL]=holder
	tab._area_player=weakref(player)
	for index: int in TAB.ZOOM_SCALES.size():
		for state: String in ["On","Off"]:tab._out["Map_Tab_Area/Nd_Page/Sp_Page%s_%d" % [state,index]]={"offset":9000+index*2+(0 if state=="On" else 1)}
	scroll.set_source_position(Vector2(-1121,458.5))
	var content: Node2D=scroll.content
	var middle: Vector2=scroll.input_control().position+scroll.input_control().size*0.5
	var under: Vector2=content.transform.affine_inverse()*middle
	check(tab.zoom(-1).get("unchanged",false) and tab.zoom_level()==0,"the first page mark is the widest view")
	var closer: Dictionary=tab.zoom(1)
	check(closer.get("ok",false) and tab.zoom_level()==1 and content.scale.is_equal_approx(Vector2.ONE*TAB.ZOOM_SCALES[1]),"Btn_Plus scales the picture to the next step")
	check((content.transform*under).is_equal_approx(middle),"the spot in the middle of the view stays in the middle")
	check(player.shown.get(9002)==true and player.shown.get(9000)==false and player.shown.get(9003)==false,"the page marks follow the zoom step")
	tab.zoom(1)
	check(tab.zoom(1).get("unchanged",false) and tab.zoom_level()==TAB.ZOOM_SCALES.size()-1,"zoom stops at the last page mark")
	tab.zoom(-1);tab.zoom(-1)
	check(tab.zoom_level()==0 and content.scale.is_equal_approx(Vector2.ONE) and (content.transform*under).is_equal_approx(middle),"Btn_Minus returns to the first view")
	player.queue_free()

func _self_position() -> void:
	var tab=TAB.new()
	var pack:=FakePack.new()
	tab._pack=pack
	check(tab.self_position_bindings().is_empty(),"내 위치 보기 stays unbound without its nodes in the UI pack")
	pack.manifest.node_scopes["UI/Map/Map_All.csb"]=[5852,6292,5904]
	var bound: Dictionary=tab.self_position_bindings()
	check(bound.get(5852,{}).get("role")=="button" and (bound[5852].activate as Callable).get_method()=="self_position" and bound.get(5904,{}).get("role")=="static_source_text","내 위치 보기 binds its original button and label")
