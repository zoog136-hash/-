extends RefCounted
## The original 523 "재료 아이템 출처" popup (Production_Popup_Source) for one
## item, filled from scripts/acquisition523/item_acquisition523.gd:
##  - Nd_SourceItem: the item's Common_Slot picture and name;
##  - drop mode: Nd_LocationList (몬스터 / 획득 장소) with one
##    Production_List_Source row per monster and shown place;
##  - acquirement mode: Nd_AcquirementList (획득 방법) with
##    Production_List_Acquirement rows (ItemCraftInputSource text, 상점 tab,
##    special dungeon);
##  - craft mode: Label_Notice ("아래 제작 리스트를 터치하면 제작 화면으로
##    이동합니다.") with Production_List_Source_Text_Set rows, two crafts per
##    row; a craft opens the existing crafting window on that recipe.
## The client shows one list at a time; which one it prefers when an item has
## several kinds of source is not in the tables. Here: an ItemCraftInputSource
## row first (that table exists only for non-drop sources), then monster drops,
## then the other 획득 방법 rows, then crafts (see
## docs/acquisition_emblem523_missing_rules.md).
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const Acquisition=preload("res://scripts/acquisition523/item_acquisition523.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const CraftUI=preload("res://scripts/ui/renewal_crafting.gd")
const ROOT="UI/Production/Production_Popup_Source.csb"
const ROW_DROP="UI/Production/Production_List_Source.csb"
const ROW_ACQUIREMENT="UI/Production/Production_List_Acquirement.csb"
const ROW_CRAFT_SET="UI/Production/Production_List_Source_Text_Set.csb"
const ROW_CRAFT="UI/Production/Production_List_Source_Text.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
## Common_Slot keeps its button, frame and item picture only.
const MEMBER_SCOPES={SLOT:[15728,15316,15012]}
const REQUIRED: Array[String]=[ROOT,ROW_DROP,ROW_ACQUIREMENT,ROW_CRAFT_SET,ROW_CRAFT,SLOT]
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _world: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _content: Node2D
var _data: Dictionary={}
var _item_name: String=""
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _moved: float=0.0
var last_result: Dictionary={}
var last_navigation: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_acquisition_popup_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node, item_class_id: int, item_name: String="") -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_acquisition_popup_host_unavailable")
	var data: Dictionary=Acquisition.sources(item_class_id)
	if not data.get("ok",false):return {"ok":false,"handled":false,"code":"source_acquisition_rows_unavailable","problem":str(data.get("problem",""))}
	_parent=weakref(parent)
	_world=weakref(world)
	_data=data
	_item_name=item_name if not item_name.is_empty() else str(data.get("name",""))
	_scroll=0.0
	return _stage()

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func data() -> Dictionary:
	return _data

func _craft_rows() -> Array:
	# Only crafts whose recipe the game has (world.crafting) are listed.
	var world: Object=_world.get_ref() if _world!=null else null
	var recipes: Dictionary=world.get("crafting").get("recipes") if world!=null and world.get("crafting")!=null else {}
	var rows: Array=[]
	for craft: Dictionary in _data.get("crafts",[]):
		var recipe: Variant=recipes.get(str(craft.recipe_id))
		if not recipe is Dictionary:continue
		# The row label holds one short line: the output name (+enchant when set).
		var output: Dictionary=recipe.get("result",{}) if recipe.get("result") is Dictionary else {}
		var title: String=str(output.get("item",recipe.get("name","")))
		if int(output.get("level",0))>0:title+=" +%d" % int(output.level)
		rows.append({"recipe_id":str(craft.recipe_id),"craft_id":int(craft.craft_id),"name":title})
	return rows

func _mode() -> String:
	# An item with its own ItemCraftInputSource text (the client's non-drop
	# source table) shows that list even when monsters also drop it.
	for row: Dictionary in _data.get("acquirements",[]):
		if str(row.get("kind",""))=="craft_input_source":return "acquirement"
	if not (_data.get("drops",[]) as Array).is_empty():return "drop"
	if not (_data.get("acquirements",[]) as Array).is_empty():return "acquirement"
	if not _craft_rows().is_empty():return "craft"
	return "none"

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if parent==null:return _fail("source_acquisition_popup_host_unavailable")
	var mode: String=_mode()
	var spec: Dictionary={
		# Btn_Cancel is the full-screen dismiss button; its placeholder title
		# "Button" names no font (fontResource and fontName empty), so the
		# node is not mounted and an invisible input area closes the popup.
		"Btn_Cancel":{"exclude":true},
		"Fx_Popup_LeftUp":{"exclude":true},"Fx_Popup_RightBottom":{"exclude":true},
		"Nd_SourceItem/Label":{"role":"source_text","text":_item_name},
		"Nd_SourceItem/Production_Slot/Btn":{"activate":Callable(self,"_ignore")},
		"Nd_LocationList":{"visible":mode=="drop"},
		"Nd_AcquirementList":{"visible":mode=="acquirement"},
		"Label_Notice":{"visible":mode=="craft"},
		"ListView":{"role":"source_list","row_offsets":[],"input":Callable(self,"_list_input")},
	}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var picture: bool=_slot_picture(next,out,"Nd_SourceItem/Production_Slot/Sp_IconSample",int(_data.item_class_id),_item_name)
	var list: Dictionary=NamedTree.locate(next,out,"ListView")
	var list_node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	var content: Variant=list_node.get_meta("source_list_content",null) if is_instance_valid(list_node) else null
	if not content is Node2D:
		next.free()
		return _fail("source_acquisition_popup_list_content_missing")
	var list_size: Vector2=NamedTree.list_size(out,_pack,ROOT,"ListView")
	var rows: int=0
	var height: float=0.0
	var crafts: Array=_craft_rows()
	match mode:
		"drop":
			for row: Dictionary in _data.drops:
				var scene: Dictionary=_row(ROW_DROP,{"Panel":{"input":Callable(self,"_list_input")},"Label_Monster":{"role":"source_text","text":str(row.npc)},"Label_Location":{"role":"source_text","text":str(row.location) if not str(row.location).is_empty() else "-"}})
				if not scene.get("ok",false):continue
				height+=_tree.add_row(content,ROW_DROP,scene.scene,rows,list_size)
				rows+=1
		"acquirement":
			for row: Dictionary in _data.acquirements:
				var panel: Dictionary={"input":Callable(self,"_row_input").bind(str(row.get("destination","")))}
				var scene: Dictionary=_row(ROW_ACQUIREMENT,{"Panel":panel,"Label_Monster":{"role":"source_text","text":str(row.text)}})
				if not scene.get("ok",false):continue
				height+=_tree.add_row(content,ROW_ACQUIREMENT,scene.scene,rows,list_size)
				rows+=1
		"craft":
			for index: int in range(0,crafts.size(),2):
				var row_spec: Dictionary={"Panel":{"input":Callable(self,"_list_input")}}
				for side: int in range(2):
					var key: String="Production_List_Source_Text_%d/" % side
					if index+side>=crafts.size():
						row_spec["Production_List_Source_Text_%d" % side]={"visible":false}
						continue
					var craft: Dictionary=crafts[index+side]
					row_spec[key+"Btn_Normal"]={"activate":Callable(self,"_open_craft").bind(str(craft.recipe_id))}
					row_spec[key+"Btn_Normal/Label_Item_Name"]={"role":"source_text","text":str(craft.name)}
					row_spec[key+"Btn_Normal/Production_Slot/Btn"]={"activate":Callable(self,"_open_craft").bind(str(craft.recipe_id))}
					row_spec[key+"Btn_Pressed"]={"visible":false}
				var row_out: Dictionary={}
				var built_row: Dictionary=_tree.scene_of(ROW_CRAFT_SET,row_spec,row_out)
				if not built_row.get("ok",false):continue
				for side: int in range(2):
					if index+side<crafts.size():_slot_picture(built_row.scene,row_out,"Production_List_Source_Text_%d/Btn_Normal/Production_Slot/Sp_IconSample" % side,int(_data.item_class_id),_item_name)
				height+=_tree.add_row(content,ROW_CRAFT_SET,built_row.scene,rows,list_size)
				rows+=1
	var previous: Node2D=_scene
	# The popup is laid out on the design centre (600, 337.5).
	next.position=Vector2(600.0,-337.5)
	var dismiss:=Control.new()
	dismiss.name="SourceDismissArea"
	dismiss.position=Vector2(-800.0,-337.5)
	dismiss.size=Vector2(1600.0,675.0)
	dismiss.mouse_filter=Control.MOUSE_FILTER_STOP
	dismiss.gui_input.connect(_dismiss_input)
	next.add_child(dismiss)
	next.move_child(dismiss,0)
	parent.add_child(next)
	next.z_index=160
	_scene=next
	_content=content
	_scroll_min=minf(0.0,list_size.y-height)
	_scroll=clampf(_scroll,_scroll_min,0.0)
	content.position.y=_scroll
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"mode":mode,"rows":rows,"item_class_id":int(_data.item_class_id),"item_picture":picture,
		"drop_rows_total":int(_data.get("drop_rows_total",0)),"drop_monsters":int(_data.get("drop_monsters",0)),"acquirements":(_data.acquirements as Array).size(),"crafts_connected":crafts.size(),"crafts_total":int(_data.get("crafts_total",0)),"classification":_data.get("classification",{})}
	return last_result

func _row(member: String, spec: Dictionary) -> Dictionary:
	return _tree.scene_of(member,spec,{})

func _slot_picture(root: Node2D, out: Dictionary, suffix: String, item_class_id: int, title: String) -> bool:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var info: Dictionary=SourceImages.describe_item_class(item_class_id,title)
	var owner: Dictionary={"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
	if not owner.ok:return false
	if not located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

## Existing destinations only: the crafting window on the recipe, the shop,
## the dungeon list.
func _open_craft(recipe_id: String) -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null or not hud.has_method("open_crafting"):return _fail("source_acquisition_craft_destination_unavailable")
	_close_requested()
	CraftUI.pending_focus=recipe_id
	CraftUI.last_focus={}
	hud.call("open_crafting")
	var focused: bool=bool(CraftUI.last_focus.get("focused",false)) and str(CraftUI.last_focus.get("recipe_id",""))==recipe_id
	last_navigation={"destination":"crafting","recipe_id":recipe_id,"focused":focused}
	return {"ok":true,"destination":"crafting","recipe_id":recipe_id,"focused":focused}

func _navigate(destination: String) -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_acquisition_destination_unavailable")
	var method: String={"shop":"open_shop","source_dungeons":"open_source_dungeons"}.get(destination,"")
	if method.is_empty() or not hud.has_method(method):return _fail("source_acquisition_destination_unavailable")
	_close_requested()
	hud.call(method)
	last_navigation={"destination":destination,"method":method}
	return {"ok":true,"destination":destination}

func _row_input(event: InputEvent, destination: String) -> void:
	_list_input(event)
	if destination.is_empty():return
	var released: bool=(event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed)
	if released and absf(_moved)<=12.0:_navigate.call_deferred(destination)

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
		delta=84.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_moved+=delta
	scroll_by(delta)

## Dragging up (negative) reveals lower rows.
func scroll_by(delta: float) -> void:
	if not is_instance_valid(_content):return
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.y=_scroll

func _dismiss_input(event: InputEvent) -> void:
	var released: bool=(event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed)
	if released:_close_requested.call_deferred()

func _ignore() -> Dictionary:
	return {"ok":true}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
