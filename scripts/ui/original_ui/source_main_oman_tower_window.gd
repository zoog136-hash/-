extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 오만의 탑 리스트 (OmanTower_All) over the existing 지역
## 이동 destinations. The client opens it from its multi-floor teleport scroll,
## which TWILIGHT does not have; here the 순간이동 window's 오만의 탑 tab opens
## it (TWILIGHT 근사, docs/original_ui523_approx.md).
## - ListView: one OmanTower_List row ("N층") per 오만의 탑 floor the world
##   has (maps oman_01 .. oman_10). A tap hands the floor to the opener (the
##   teleport window selects it: its own price, level check and 이동하기).
## - Btn_Close and a tap outside the panel close only this list.
## Left empty: the client's scroll item and its counts (no TWILIGHT item).
const ROOT="UI/FloatingUi/OmanTower_All.csb"
const ROW="UI/FloatingUi/OmanTower_List.csb"
const FLOORS: int=10
var _pick: Callable=Callable()

func required_members() -> Array[String]:
	return [ROOT,ROW]

func _root_member() -> String:
	return ROOT

## The panel sits at the screen centre (FloatingUiScene names no OmanTower layout).
func _root_position() -> Vector2:
	return Vector2(600.0,-337.5)

## The 오만의 탑 floors the world has: [{map_id, floor}].
static func floors(owner: Object) -> Array:
	var found: Array=[]
	var maps: Variant=owner.get("maps_by_id") if owner!=null else null
	if not maps is Dictionary:return found
	for floor: int in range(1,FLOORS+1):
		var map_id: String="oman_%02d" % floor
		if (maps as Dictionary).has(map_id):found.append({"map_id":map_id,"floor":floor})
	return found

## `pick` receives the chosen floor's map id.
func open(parent: Node, pick: Callable=Callable()) -> Dictionary:
	if floors(world()).is_empty():return _fail("source_oman_tower_floors_unavailable")
	_pick=pick
	return open_window(parent)

func _spec() -> Dictionary:
	var spec: Dictionary={}
	for fx: String in ["Fx_Popup_LeftUp","Fx_Popup_RightBottom"]:spec[fx]={"exclude":true}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var rows: Array=[]
	for row: Dictionary in floors(world()):
		rows.append({"member":ROW,"spec":{"Panel/Label_Number":{"role":"source_text","text":"%d층" % int(row.floor)},"Panel/Btn_Select":{"activate":Callable(self,"_choose").bind(str(row.map_id))}}})
	var placed: Dictionary=_fill_list(root,out,"ListView",rows)
	if not placed.get("ok",false):return placed
	var catcher:=Control.new()
	catcher.name="OmanTowerOutsideClose"
	catcher.position=Vector2(-4000.0,-4000.0)
	catcher.size=Vector2(8000.0,8000.0)
	catcher.mouse_filter=Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_outside_input)
	root.add_child(catcher)
	root.move_child(catcher,0)
	return {"ok":true,"floors":rows.size()}

func _outside_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT)) and not event.pressed:
		close.call_deferred()

func _choose(map_id: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	close()
	if _pick.is_valid():_pick.call(map_id)
	return {"ok":true,"handled":true,"picked":map_id}

## Only this list closes (the window under it stays).
func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}
