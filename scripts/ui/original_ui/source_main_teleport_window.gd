extends RefCounted
## The original 523 텔레포트 tab (Map_All frame + Map_Tab_Teleport) for the
## existing 지역 이동 window: destination rows (Map_List_Button: name,
## Lv.N ~, lock under the level), the selected destination's title, the
## 텔레포트 비용 and 이동하기. Destinations, levels, prices, the refusal reason
## and the move stay with the existing owners (world.maps, npc/teleport_policy,
## hud.npc_teleport_requested → world._npc_teleport_requested).
## Left inert or empty (no rule here): the other map tabs, the destination
## preview picture, 전체 / 즐겨찾기 목록 and bookmarks, 세율, every effect.
## The authored Hadin portrait, name and line stay as the tab authors them.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const POLICY=preload("res://scripts/npc/teleport_policy.gd")
const ALL="UI/Map/Map_All.csb"
const TAB="UI/Map/Map_Tab_Teleport.csb"
const ROW="UI/Map/Map_List_Button.csb"
const REQUIRED: Array[String]=[ALL,TAB,ROW]
## Map_All roots this window mounts: frame, top menu, tab bar, teleport tab.
const ROOTS: Array[int]=[32176,29168,9052,31108]
## Map_All_Layout in MapScene (600, 337.5).
const LAYOUT_POSITION=Vector2(600.0,-337.5)
const P_TAB="Map_Tab_Teleport/Map_Tab_Teleport/"
## Com_Icn_Adena of Atlas_Common (the atlas of the authored Com_Icn_Gem).
const ADENA_ICON={"path":"Com_Icn_Adena.png","plistFile":"UI_Resource/Atlas_Common.plist","resourceType":1}
const OTHER_TABS: Array[String]=["Btn_World","Btn_Island","Btn_Aden","Btn_Dungeon","Btn_Siege"]
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _world: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _selected: String=""
var _content: Node2D
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _moved: float=0.0
var _last_out: Dictionary={}
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_teleport_window_member_missing","member":member}
	var scope: Variant=pack.manifest.get("node_scopes",{}).get(ALL)
	if scope is Array:
		for offset: int in ROOTS:
			if not (scope as Array).has(offset):return {"ok":false,"handled":false,"code":"source_teleport_window_member_missing","member":ALL}
	_pack=pack
	_tree=NamedTree.new(pack,{ALL:ROOTS})
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world):return _fail("source_teleport_window_host_unavailable")
	_parent=weakref(parent)
	_world=weakref(world)
	_selected=""
	_scroll=0.0
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func selected() -> String:
	return _selected

func node_keys() -> Dictionary:
	return _last_out

## The existing 지역 이동 destinations (renewal_teleport's list).
static func destinations(world: Node) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	for raw: Variant in world.get("maps"):
		if not raw is Dictionary:continue
		var map_id: String=str(raw.get("id",""))
		if not (world.get("maps_by_id") as Dictionary).has(map_id):continue
		var rule: Dictionary=POLICY._rule(map_id)
		rows.append({"id":map_id,"name":str(raw.get("name",map_id)),"min_level":int(rule.min_level),"price":int(rule.price)})
	return rows

func _quote(world: Node, map_id: String) -> Dictionary:
	return POLICY.quote(map_id,world.get("maps_by_id"),str(world.get("active_map_id")),int(world.get("level")),int(world.get("gold")))

## --- Stage ------------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var world: Node=_world.get_ref() if _world!=null else null
	if parent==null or world==null:return _fail("source_teleport_window_host_unavailable")
	var rows: Array[Dictionary]=destinations(world)
	var chosen: Dictionary={}
	for row: Dictionary in rows:
		if row.id==_selected:chosen=row
	if chosen.is_empty() and not rows.is_empty():
		chosen=rows[0]
		_selected=str(chosen.id)
	var quote: Dictionary=_quote(world,_selected) if not chosen.is_empty() else {}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ALL,_spec(world,chosen,quote),out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var paid: bool=_adena_icon(next,out)
	var list: Dictionary=NamedTree.locate(next,out,P_TAB+"ListView_Button")
	var node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null
	if not content is Node2D:
		next.free()
		return _fail("source_teleport_window_list_content_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,TAB,"Map_Tab_Teleport/ListView_Button")
	var height: float=0.0
	for index: int in range(rows.size()):
		var row: Dictionary=_row(world,rows[index])
		if not row.get("ok",false):
			next.free()
			last_result=row
			return row
		height+=_tree.add_row(content,ROW,row.scene,index,size)
	var previous: Node2D=_scene
	next.position=LAYOUT_POSITION
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	_content=content
	_scroll_min=minf(0.0,size.y-height)
	_scroll=clampf(_scroll,_scroll_min,0.0)
	content.position.y=_scroll
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ALL,"destinations":rows.size(),"selected":_selected,"quote_ok":quote.get("ok",false),"quote_reason":str(quote.get("reason","")),"adena_icon":paid}
	return last_result

func _spec(world: Node, chosen: Dictionary, quote: Dictionary) -> Dictionary:
	var spec: Dictionary={}
	spec["FullFrameType_A/Fx_Img_BG_Particle"]={"exclude":true}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_TabMenu/Btn_Teleport_On"]={"visible":true}
	spec["Nd_TabMenu/Btn_Teleport_Off"]={"visible":false}
	for name: String in OTHER_TABS:
		spec["Nd_TabMenu/"+name+"_On"]={"visible":false}
		spec["Nd_TabMenu/"+name+"_Off"]={"visible":false}
	spec["Map_Tab_Teleport"]={"visible":true}
	spec[P_TAB+"Nd_Gradation/Fx_Img_BG_Particle"]={"exclude":true}
	for name: String in ["Nd_Preview","Fx_Teleport_Open","Nd_Npc/Nd_Spine","Btn_CheckBox","Nd_Tax","Label_Message"]:spec[P_TAB+name]={"exclude":true}
	spec[P_TAB+"ListView_Button"]={"input":Callable(self,"_list_input")}
	var has: bool=not chosen.is_empty()
	var ok: bool=quote.get("ok",false)
	spec[P_TAB+"Nd_Title"]={"visible":has}
	spec[P_TAB+"Nd_Title/Label"]={"role":"source_text","text":str(chosen.get("name",""))}
	spec[P_TAB+"Teleport_Enabled"]={"visible":has and ok}
	spec[P_TAB+"Teleport_Enabled/Payment/Label"]={"role":"source_text","text":_number(int(chosen.get("price",0)))}
	spec[P_TAB+"Teleport_Enabled/Payment/Icon"]={"role":"source_asset_slot","visible":false}
	spec[P_TAB+"Teleport_Enabled/Btn_Teleport"]={"activate":Callable(self,"_teleport_requested")}
	spec[P_TAB+"Teleport_Disabled"]={"visible":has and not ok,"title":str(quote.get("reason","")),"activate":Callable(self,"_teleport_requested")}
	return spec

func _row(world: Node, row: Dictionary) -> Dictionary:
	var chosen: bool=str(row.id)==_selected
	var locked: bool=int(world.get("level"))<int(row.min_level)
	var spec: Dictionary={"Panel":{"input":Callable(self,"_list_input")}}
	for state: String in ["Btn_Normal","Btn_Pressed"]:
		spec[state]={"visible":(state=="Btn_Pressed")==chosen,"activate":Callable(self,"_select").bind(str(row.id))}
		spec[state+"/Label"]={"role":"source_text","text":str(row.name)}
		# The client picks Base / Dungeon / Field / Village per map type, which
		# this game's maps do not record: the neutral Base frame is shown.
		for frame: String in ["Img_Dungeon","Img_Field","Img_Village"]:spec[state+"/Nd_Bg/"+frame]={"visible":false}
		spec[state+"/Nd_Bg/Img_Base"]={"visible":true}
	# The bookmark star is not packed (no bookmark rule here).
	spec["Btn_CheckBox"]={"exclude":true}
	spec["Label_Lv"]={"role":"source_text","text":"Lv.%d ~" % int(row.min_level)}
	spec["Nd_Lock"]={"visible":locked}
	var built: Dictionary=_tree.scene_of(ROW,spec,{})
	if not built.get("ok",false):return built
	return {"ok":true,"scene":built.scene}

## 텔레포트 비용 is paid in Adena here: the original Adena picture of the pack
## takes the authored diamond's place.
func _adena_icon(root: Node2D, out: Dictionary) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,P_TAB+"Teleport_Enabled/Payment/Icon")
	if not located.get("ok",false):return false
	var texture: Texture2D=_pack.texture(ADENA_ICON,true)
	if texture==null:return false
	var picture: Dictionary={"ok":true,"texture":texture,"status":"original_ui_pack_atlas_frame","provenance":{"member":{"path":"UI/"+str(ADENA_ICON.plistFile).replace(".plist",".png"),"format":"PNG","atlas":"UI/"+str(ADENA_ICON.plistFile),"frame":str(ADENA_ICON.path)},"pack_manifest_sha256":str(_pack.manifest_sha256)}}
	if not located.player.set_bound_source_visual_result(located.offset,picture).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

## --- Actions -----------------------------------------------------------------

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

func _select(map_id: String) -> Dictionary:
	if _moved>12.0:return {"ok":true,"ignored_after_drag":true}
	_selected=map_id
	return _stage()

func _teleport_requested() -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if world==null or hud==null or _selected.is_empty():return _fail("source_teleport_window_destination_required")
	var quote: Dictionary=_quote(world,_selected)
	if not quote.get("ok",false):
		if hud.has_method("show_message"):hud.call("show_message",str(quote.get("reason","")))
		return {"ok":false,"reason":str(quote.get("reason",""))}
	# The existing move: the world rechecks, moves and debits.
	var target: String=_selected
	hud.emit_signal("npc_teleport_requested",target)
	var moved: bool=str(world.get("active_map_id"))==target
	# Arrived: the window closes like the existing panel's move; refused or
	# failed: the world's message stays and the window shows the new state.
	if moved:_close_requested()
	elif is_open():_stage()
	return {"ok":true,"requested":target,"moved":moved}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _number(value: int) -> String:
	var digits: String=str(absi(value))
	var grouped: String=""
	while digits.length()>3:
		grouped=","+digits.right(3)+grouped
		digits=digits.left(digits.length()-3)
	return ("-" if value<0 else "")+digits+grouped

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
