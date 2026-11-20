extends RefCounted
## The original 523 지도 area tab (Map_Tab_Area) beyond the World picture:
## the map's area list (ListView_Button with Map_List_Button rows: name,
## level, lock), the 필드 / 던전 / 마을 / 거점 filters (CheckBox_Land), the
## selected area's title (Nd_Title) and its 텔레포트 비용 / 이동하기
## (Teleport_Enabled), plus Map_All's 지역 정보 button, which opens the original
## MapInfoScene (Map_Popup_AreaInfo: monster list, monster info, drop items).
## Rows, names, levels, costs and the move are the original UIMapArea /
## LandTeleport rows (current523_map_areas, current523_map_teleport); the
## move is world.current523_map_teleport (cost debited and saved there).
## A tap on the map picture keeps walking there (current523_world_map_input)
## and also selects the area at that cell with its coordinates in the title
## (TWILIGHT 근사: nearest area box of the same Land).
## Left inert (no rule here): the NPC filters (CheckBox_Area), bookmarks
## (Btn_CheckBox, Nd_Collection), zoom (Nd_Page) and the Slot_Skill quick
## teleport slots of Map_All.
## An older UI pack (ui42 and before: Map_Tab_Area scoped to the picture and
## the world row) has none of these nodes: available() is false and the map
## stays as it was.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const AREAS=preload("res://scripts/maps/current523_map_areas.gd")
const MAP_TELEPORT=preload("res://scripts/maps/current523_map_teleport.gd")
const Router=preload("res://scripts/ui/original_ui/source_button_router.gd")
const AREA="UI/Map/Map_Tab_Area.csb"
const ROW="UI/Map/Map_List_Button.csb"
const INFO="UI/MapInfoScene.csb"
const POPUP="UI/Map/Map_Popup_AreaInfo.csb"
const MONSTER_ROW="UI/Map/Map_Popup_AreaInfo_List_Button.csb"
const INFO_ROW="UI/Map/Map_Popup_AreaInfo_List_MonterInfo.csb"
const DROP_ROW="UI/Map/Map_Popup_AreaInfo_List_DropItem.csb"
## Nd_Gradation, ListView_Button, CheckBox_Land, Teleport_Enabled, Nd_Title.
const ROOTS: Array[int]=[37984,37560,11324,9140,3672]
## Map_All Btn_AreaInfo (지역 정보).
const AREA_INFO_BUTTON=2032
const FILTER_NAMES: Dictionary={"field":"Field","dungeon":"Dungeon","village":"Village","base":"Base"}
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _field: WeakRef
var _area_player: WeakRef
var _mount: WeakRef
var _out: Dictionary={}
var _world_id: int=0
var _land_id: int=-1
var _label: String=""
var _filter: String=""
var _selected: int=0
var _cell: Variant=null
var _rows: Array=[]
var _content: Node2D
var _list_size: Vector2
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _moved: float=0.0
var _popup: Node2D
var _popup_monster: int=-1
var _popup_content: Dictionary={}
var last_result: Dictionary={}

static func available(pack: RefCounted) -> bool:
	if pack==null:return false
	var scenes: Dictionary=pack.manifest.get("scenes",{})
	for member: String in [AREA,ROW,INFO,POPUP,MONSTER_ROW,INFO_ROW,DROP_ROW]:
		if not scenes.has(member):return false
	var scope: Variant=pack.manifest.get("node_scopes",{}).get(AREA)
	if not scope is Array:return false
	for offset: int in ROOTS+[10648,9196,3728]:
		if not (scope as Array).has(offset):return false
	return true

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	if not available(pack):return {"ok":false,"code":"source_map_area_tab_pack_without_area_list"}
	_pack=pack
	_hud=weakref(hud)
	_tree=NamedTree.new(pack,{AREA:ROOTS})
	return {"ok":true}

## Offsets and bindings the area project (Map_Tab_Area) adds for this tab.
func bind(field_map: Object, world_id: int, world_label: String) -> Dictionary:
	_world_id=world_id
	_label=world_label
	_field=weakref(field_map)
	_land_id=_land_of(field_map)
	_rows=[]
	_content=null
	_scroll=0.0
	_cell=null
	var here: Dictionary=_player_area()
	_selected=int(here.get("area_id",0))
	_filter=str(here.get("filter","")) if not here.is_empty() else "field"
	var spec: Dictionary={
		"ListView_Button":{"input":Callable(self,"_list_input")},
		"CheckBox_Land":{"visible":true},
		"Teleport_Enabled":{"visible":false},
		"Teleport_Enabled/Payment/Label":{"role":"source_text","text":"0"},
		"Teleport_Enabled/Btn_Teleport":{"activate":Callable(self,"_teleport_requested")},
		"Nd_Title":{"visible":true},
		"Nd_Title/Label":{"role":"source_text","text":world_label},
	}
	for key: String in FILTER_NAMES:
		var name: String=FILTER_NAMES[key]
		spec["CheckBox_Land/Btn_%s_On" % name]={"visible":_filter==key,"activate":Callable(self,"_set_filter").bind(key)}
		spec["CheckBox_Land/Btn_%s_Off" % name]={"visible":_filter!=key,"activate":Callable(self,"_set_filter").bind(key)}
	_out={}
	var bound: Dictionary=_tree.bind(AREA,"",[],spec,_out)
	return {"ok":true,"scope":bound.scope,"bindings":bound.bindings}

## Map_All binding of 지역 정보.
func area_info_binding() -> Dictionary:
	return {"role":"button","activate":Callable(self,"open_area_info")}

func presented(area_player: Node2D, mount: Node2D) -> Dictionary:
	_area_player=weakref(area_player)
	_mount=weakref(mount)
	var node: Variant=area_player.get("source_nodes").get(37560)
	var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null
	if not content is Node2D:return _remember({"ok":false,"code":"source_map_area_tab_list_content_missing"})
	_content=content
	_list_size=NamedTree.list_size(_out,_pack,AREA,"ListView_Button")
	var filled: Dictionary=_fill_rows()
	if not filled.get("ok",false):return _remember(filled)
	_show_selection()
	return _remember({"ok":true,"world_id":_world_id,"areas":AREAS.areas(_world_id).size(),"rows":_rows.size(),"filter":_filter,"selected":_selected})

func close() -> void:
	close_area_info()
	_rows=[]
	_content=null
	_area_player=null

func selected_area() -> Dictionary:
	return AREAS.area(_world_id,_selected)

func filter() -> String:
	return _filter

func rows() -> Array:
	return _rows

## A tap on the map picture at source `cell`: its area is selected (filter
## follows) and the title names the area and the coordinates.
func select_cell(cell: Vector2) -> Dictionary:
	if _land_id<0 or not cell.is_finite():return {"ok":false,"code":"source_map_area_tab_cell_invalid"}
	var found: Dictionary=AREAS.nearest(_world_id,_land_id,cell)
	_cell=Vector2i(floori(cell.x),floori(cell.y))
	if found.is_empty():
		_selected=0
		_show_selection()
		return {"ok":true,"area":{},"cell":_cell}
	_selected=int(found.area_id)
	if str(found.filter)!=_filter and not str(found.filter).is_empty():
		_filter=str(found.filter)
		_fill_rows()
	_show_selection()
	return {"ok":true,"area":found,"cell":_cell,"approximation":AREAS.APPROXIMATION}

func _set_filter(key: String) -> Dictionary:
	if _filter==key:return {"ok":true,"unchanged":true}
	_filter=key
	_scroll=0.0
	var filled: Dictionary=_fill_rows()
	_show_selection()
	return filled

func _select(area_id: int) -> Dictionary:
	if _moved>12.0:return {"ok":true,"ignored_after_drag":true}
	_selected=area_id
	_cell=null
	_show_selection()
	return {"ok":true,"selected":area_id}

## --- Rows --------------------------------------------------------------------

func _fill_rows() -> Dictionary:
	if not is_instance_valid(_content):return {"ok":false,"code":"source_map_area_tab_list_content_missing"}
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_rows=[]
	var height: float=0.0
	var level: int=_level()
	var index: int=0
	for area: Dictionary in AREAS.filtered(_world_id,_filter):
		var built: Dictionary=_row(area,level)
		if not built.get("ok",false):return built
		height+=_tree.add_row(_content,ROW,built.scene,index,_list_size)
		_rows.append({"area_id":int(area.area_id),"scene":built.scene,"out":built.out})
		index+=1
	_scroll_min=minf(0.0,_list_size.y-height)
	_scroll=clampf(_scroll,_scroll_min,0.0)
	_content.position.y=_scroll
	_set_filter_buttons()
	return {"ok":true,"rows":_rows.size()}

func _row(area: Dictionary, level: int) -> Dictionary:
	var spec: Dictionary={"Panel":{"input":Callable(self,"_list_input")}}
	var chosen: bool=int(area.area_id)==_selected
	for state: String in ["Btn_Normal","Btn_Pressed"]:
		spec[state]={"visible":(state=="Btn_Pressed")==chosen,"activate":Callable(self,"_select").bind(int(area.area_id))}
		spec[state+"/Label"]={"role":"source_text","text":str(area.name)}
		var frame_name: String={3:"Img_Village",4:"Img_Dungeon",5:"Img_Field"}.get(int(area.type_id),"Img_Base")
		for frame: String in ["Img_Base","Img_Dungeon","Img_Field","Img_Village"]:spec[state+"/Nd_Bg/"+frame]={"visible":frame==frame_name}
	spec["Btn_CheckBox"]={"exclude":true}
	spec["Label_Lv"]={"role":"source_text","text":str(area.level_label)}
	spec["Nd_Lock"]={"visible":not str(area.destination_id).is_empty() and level<int(area.min_level)}
	var out: Dictionary={}
	var row_tree: RefCounted=NamedTree.new(_pack)
	var built: Dictionary=row_tree.scene_of(ROW,spec,out)
	if not built.get("ok",false):return built
	forward_drags(built.scene,Callable(self,"_list_input"))
	return {"ok":true,"scene":built.scene,"out":out}

## A row's buttons hand their finger's drag to the list (router DRAG_META):
## a list whose rows are all buttons still scrolls on a phone.
static func forward_drags(node: Node, input: Callable) -> void:
	if node.has_meta("source_button"):
		var button: Variant=node.get_meta("source_button")
		if is_instance_valid(button) and not (button as Object).has_meta(Router.DRAG_META):(button as Object).set_meta(Router.DRAG_META,input)
	for child: Node in node.get_children():forward_drags(child,input)

func _set_filter_buttons() -> void:
	var player: Object=_area_player.get_ref() if _area_player!=null else null
	if player==null:return
	for key: String in FILTER_NAMES:
		for state: String in ["On","Off"]:
			var offset: int=_offset("CheckBox_Land/Btn_%s_%s" % [FILTER_NAMES[key],state])
			if offset>=0:player.set_bound_visible(offset,(state=="On")==(_filter==key))

func _show_selection() -> void:
	for row: Dictionary in _rows:
		var chosen: bool=int(row.area_id)==_selected
		for state: String in ["Btn_Normal","Btn_Pressed"]:
			var located: Dictionary=NamedTree.locate(row.scene,row.out,state)
			if located.get("ok",false):located.player.set_bound_visible(located.offset,(state=="Btn_Pressed")==chosen)
	var player: Object=_area_player.get_ref() if _area_player!=null else null
	if player==null:return
	var area: Dictionary=AREAS.area(_world_id,_selected)
	var title: String=_label if area.is_empty() else str(area.name)
	if _cell is Vector2i:title+=" (%d, %d)" % [_cell.x,_cell.y]
	var label: int=_offset("Nd_Title/Label")
	if label>=0:player.set_bound_text(label,title)
	var teleport: bool=not area.is_empty() and not str(area.destination_id).is_empty()
	var panel: int=_offset("Teleport_Enabled")
	if panel>=0:player.set_bound_visible(panel,teleport)
	var price: int=_offset("Teleport_Enabled/Payment/Label")
	if price>=0 and teleport:player.set_bound_text(price,_number(int(area.price)))

func _offset(suffix: String) -> int:
	for key: String in _out:
		if key.ends_with("/"+suffix):return int(_out[key].offset)
	return -1

func _list_input(event: InputEvent) -> void:
	if not is_instance_valid(_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_drag=event.pressed
		if event.pressed:_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=70.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_moved+=absf(delta)
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.y=_scroll

## --- Teleport ------------------------------------------------------------------

func _world() -> Node:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	return hud.get_parent() if hud!=null else null

func _level() -> int:
	var world: Node=_world()
	return int(world.get("level")) if world!=null and world.get("level")!=null else 1

func _teleport_requested() -> Dictionary:
	var world: Node=_world()
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var area: Dictionary=AREAS.area(_world_id,_selected)
	if world==null or hud==null or area.is_empty() or str(area.destination_id).is_empty():return {"ok":false,"code":"source_map_area_tab_destination_required"}
	var quote: Dictionary=MAP_TELEPORT.quote(world,str(area.destination_id))
	if not quote.get("ok",false):
		if hud.has_method("show_message"):hud.call("show_message",str(quote.get("reason","")))
		return {"ok":false,"reason":str(quote.get("reason",""))}
	var result: Dictionary=world.call("current523_map_teleport",str(area.destination_id))
	if hud.has_method("show_message"):hud.call("show_message",str(result.get("reason","")))
	# Arrived: the map closes (the field it showed is left behind).
	if result.get("ok",false) and hud.has_method("toggle_map"):
		var controller: Variant=hud.get("original_main_ui_controller")
		if is_instance_valid(controller) and controller.has_method("world_map_is_open") and controller.world_map_is_open():hud.call("toggle_map")
	return {"ok":true,"requested":str(area.destination_id),"moved":bool(result.get("ok",false)),"result":result}

## --- 지역 정보 (MapInfoScene) --------------------------------------------------

func area_info_open() -> bool:
	return is_instance_valid(_popup) and not _popup.is_queued_for_deletion()

func open_area_info() -> Dictionary:
	var mount: Node2D=_mount.get_ref() if _mount!=null else null
	var area: Dictionary=AREAS.area(_world_id,_selected)
	if mount==null:return {"ok":false,"code":"source_map_area_info_mount_unavailable"}
	if area.is_empty():
		var hud: Node=_hud.get_ref() if _hud!=null else null
		if hud!=null and hud.has_method("show_message"):hud.call("show_message","지역을 먼저 선택하세요")
		return {"ok":false,"code":"source_map_area_info_area_required"}
	var field: Object=_field.get_ref() if _field!=null else null
	var monsters: Array=AREAS.monsters(_world_id,int(area.area_id),field)
	if _popup_monster<0 or not monsters.any(func(m: Dictionary) -> bool: return int(m.npc_id)==_popup_monster):
		_popup_monster=int(monsters[0].npc_id) if not monsters.is_empty() else -1
	return _stage_popup(mount,area,monsters)

func close_area_info() -> Dictionary:
	if area_info_open():
		_popup.hide()
		_popup.queue_free()
	_popup=null
	_popup_content={}
	return {"ok":true,"closed":true}

func _pick_monster(npc_id: int) -> Dictionary:
	if _popup_moved()>12.0:return {"ok":true,"ignored_after_drag":true}
	_popup_monster=npc_id
	return open_area_info()

func _stage_popup(mount: Node2D, area: Dictionary, monsters: Array) -> Dictionary:
	var chosen: Dictionary={}
	for monster: Dictionary in monsters:
		if int(monster.npc_id)==_popup_monster:chosen=monster
	var drops: Array=AREAS.drops(int(chosen.npc_id)) if not chosen.is_empty() else []
	var spec: Dictionary={
		"Black_BG":{"role":"consume"},
		"Btn_Close":{"activate":Callable(self,"close_area_info")},
		"Nd_Bg/Text_Title":{"role":"source_text","text":str(area.name)},
		"Nd_List/ListView":{"input":Callable(self,"_popup_input").bind("monsters")},
		"Nd_MonsterInfo/ListView_MonsterInfo":{"input":Callable(self,"_popup_input").bind("info")},
		"Nd_DropItem/ListView_DropItem":{"input":Callable(self,"_popup_input").bind("drops")},
		"Nd_Info/Label_Type":{"role":"source_text","text":_type_text(chosen)},
		"Nd_Info/Label_Empty":{"visible":drops.is_empty()},
	}
	var out: Dictionary={}
	var tree: RefCounted=NamedTree.new(_pack)
	var built: Dictionary=tree.scene_of(INFO,spec,out)
	if not built.get("ok",false):return _remember(built)
	var next: Node2D=built.scene
	var lists: Dictionary={}
	for pair: Array in [["monsters","Nd_List/ListView"],["info","ListView_MonsterInfo"],["drops","ListView_DropItem"]]:
		var located: Dictionary=NamedTree.locate(next,out,str(pair[1]))
		var node: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
		var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null
		if not content is Node2D:
			next.free()
			return _remember({"ok":false,"code":"source_map_area_info_list_missing","list":pair[0]})
		lists[pair[0]]={"content":content,"size":NamedTree.list_size(out,_pack,POPUP,str(pair[1])),"scroll":0.0,"min":0.0,"moved":0.0}
	var rows: Dictionary={"monsters":[],"info":[],"drops":[]}
	for monster: Dictionary in monsters:
		var picked: bool=int(monster.npc_id)==_popup_monster
		var text: String="%s Lv.%d" % [str(monster.name),int(monster.level)] if int(monster.level)>0 else str(monster.name)
		var row_spec: Dictionary={"Panel":{"input":Callable(self,"_popup_input").bind("monsters")}}
		for state: String in ["Btn_Normal","Btn_Pressed"]:
			row_spec[state]={"visible":(state=="Btn_Pressed")==picked,"activate":Callable(self,"_pick_monster").bind(int(monster.npc_id))}
			row_spec[state+"/Label_"+state.trim_prefix("Btn_")]={"role":"source_text","text":text}
			# Day/night spawn is not resolved here: the day mark stays.
			row_spec[state+"/Nd_Time/Img_Night"]={"visible":false}
		rows.monsters.append({"member":MONSTER_ROW,"spec":row_spec})
	if not chosen.is_empty():
		for line: Array in [["레벨","Lv.%d" % int(chosen.level)],["선공","선공" if bool(chosen.aggressive) else "비선공"]]:
			rows.info.append({"member":INFO_ROW,"spec":{"Label_Title":{"role":"source_text","text":str(line[0])},"Label_Info":{"role":"source_text","text":str(line[1])},"Panel_MonsterInfo":{"input":Callable(self,"_popup_input").bind("info")}}})
	for drop: Dictionary in drops:
		# The item picture slot (Common_Slot) stays hidden: no icon owner here.
		rows.drops.append({"member":DROP_ROW,"spec":{"Label_Item":{"role":"source_text","text":str(drop.name)},"Common_Slot":{"exclude":true},"Panel":{"input":Callable(self,"_popup_input").bind("drops")}}})
	for key: String in rows:
		var height: float=0.0
		var index: int=0
		for row: Dictionary in rows[key]:
			var row_built: Dictionary=NamedTree.new(_pack).scene_of(str(row.member),row.spec,{})
			if not row_built.get("ok",false):
				next.free()
				return _remember(row_built)
			forward_drags(row_built.scene,Callable(self,"_popup_input").bind(key))
			height+=tree.add_row(lists[key].content,str(row.member),row_built.scene,index,lists[key].size)
			index+=1
		lists[key].min=minf(0.0,float((lists[key].size as Vector2).y)-height)
	var previous: Node2D=_popup
	next.z_index=160
	mount.add_child(next)
	_popup=next
	_popup_content=lists
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	return _remember({"ok":true,"area_info":true,"area_id":int(area.area_id),"monsters":monsters.size(),"selected_monster":_popup_monster,"drops":drops.size(),"approximation":AREAS.APPROXIMATION})

static func _type_text(monster: Dictionary) -> String:
	if monster.is_empty():return ""
	if bool(monster.get("boss",false)):return "보스형"
	return "선공형" if bool(monster.get("aggressive",false)) else "일반형"

func _popup_moved() -> float:
	var moved: float=0.0
	for key: String in _popup_content:moved=maxf(moved,float(_popup_content[key].moved))
	return moved

func _popup_input(event: InputEvent, key: String) -> void:
	var list: Dictionary=_popup_content.get(key,{})
	if list.is_empty() or not is_instance_valid(list.content):return
	if event is InputEventScreenTouch:
		if event.pressed:list.moved=0.0
		return
	if not event is InputEventScreenDrag:return
	var delta: float=event.relative.y
	var scale_y: float=absf((list.content as Node2D).get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0:delta/=scale_y
	list.moved=float(list.moved)+absf(delta)
	list.scroll=clampf(float(list.scroll)+delta,float(list.min),0.0)
	(list.content as Node2D).position.y=float(list.scroll)

## The 지역 정보 popup's live original buttons (empty while it is closed).
func popup_buttons() -> Array:
	var found: Array=[]
	if area_info_open():collect_buttons(_popup,found)
	return found

static func collect_buttons(node: Node, found: Array) -> void:
	if node.has_meta("source_button"):found.append(node.get_meta("source_button"))
	for child: Node in node.get_children():collect_buttons(child,found)

## --- Helpers ---------------------------------------------------------------------

func _player_area() -> Dictionary:
	var world: Node=_world()
	var field: Object=_field.get_ref() if _field!=null else null
	if world==null or field==null or _land_id<0:return {}
	var coordinates: Variant=field.get("coordinates")
	var player: Variant=world.get("player")
	if coordinates==null or not is_instance_valid(player):return {}
	var source: Vector2=coordinates.to_source(player.global_position)
	return AREAS.nearest(_world_id,_land_id,source) if source.is_finite() else {}

static func _land_of(field: Object) -> int:
	if field==null:return -1
	var data: Variant=field.get("data")
	if data is Dictionary and (data as Dictionary).has("source_land_id"):return int(data.source_land_id)
	var definition: Variant=field.get("definition")
	if definition is Dictionary and definition.has("source_map_id"):return int(definition.source_map_id)
	return -1

static func _number(value: int) -> String:
	var digits: String=str(absi(value))
	var grouped: String=""
	while digits.length()>3:
		grouped=","+digits.right(3)+grouped
		digits=digits.left(digits.length()-3)
	return ("-" if value<0 else "")+digits+grouped

func _remember(result: Dictionary) -> Dictionary:
	last_result=result.duplicate(true)
	return result
