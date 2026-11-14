extends RefCounted
## The original 523 제작 window: ProductionScene with Production_All (frame,
## close, 장비 / 기타 tabs) and Production_Tab_List (category list, recipe list
## of Production_List_Item rows, the selected product, material rows of
## Production_List_Material_Set, +1/+10/+50 and ▲▼ amount, 제 작).
## Recipes, quotes, owned counts, material choices, the confirmation and the
## transaction stay with the existing owners (world.crafting / patch523
## rules, renewal_crafting.confirm_target → craft_requested).
## Left inert or empty (no rule here): 메인 (recommend) / 이벤트 / 한정 /
## 서버 한정 / 즐겨찾기 / 검색 tabs (Off; tapping says so), the class filter
## and sort button, 컬렉션 이동, 결과 상세 보기, the progress bar, the limits /
## period texts, the 출처 popup, the keypad, every effect layer.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const Craft=preload("res://scripts/ui/renewal_crafting.gd")
## ProductionScene is a layout source only; Production_All is mounted at
## its Production_All_Layout position (600, 337.5).
const ALL="UI/Production/Production_All.csb"
const ROOT=ALL
const LAYOUT_POSITION=Vector2(600.0,-337.5)
const TAB_LIST="UI/Production/Production_Tab_List.csb"
const ROW_ITEM="UI/Production/Production_List_Item.csb"
const ROW_SORT="UI/Production/Production_List_Sort.csb"
const ROW_MATERIAL="UI/Production/Production_List_Material_Set.csb"
const MATERIAL="UI/Production/Production_List_Material.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const MEMBER_SCOPES={SLOT:[15728,15316,15012,9004,6880]}
const REQUIRED: Array[String]=[ALL,TAB_LIST,ROW_ITEM,ROW_SORT,ROW_MATERIAL,MATERIAL,SLOT]
const P_ALL=""
const P_LIST="Production_Tab_List/"
const P_PROD="Production_Tab_List/Nd_Production/"
## 장비 / 기타 tabs over the TWILIGHT recipe categories.
const TABS: Dictionary={"equip":["무기","방어구","장신구"],"other":["물약","재료"]}
const OFF_TABS: Array[String]=["Btn_Main","Btn_Event","Btn_LimitedAccount","Btn_LimitedServer","Btn_Bookmark","Btn_Search"]
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _world: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _tab: String="equip"
var _category: String=""
var _selected: String=""
var _count: int=1
var _scrolls: Dictionary={}
var _last_out: Dictionary={}
var last_result: Dictionary={}
## The recipe list builds only the rows near its visible part (a tab holds
## hundreds of recipes; building every row stalled and ran out of memory).
const ITEM_WINDOW: int=10
## Recipe rows another stage may keep (index -> [recipe id, row scene]):
## a selection or amount change rebuilds only the rows whose state changed.
var _reusable: Dictionary={}
var _reuse_except: Array[String]=[]
var _item_ids: Array[String]=[]
var _item_content: Node2D
var _item_size: Vector2
var _item_rows: Dictionary={}

## Drag scrolling of one original ListView content (rows placed by add_row).
class ListScroll extends RefCounted:
	var content: Node2D
	var minimum: float=0.0
	var y: float=0.0
	var drag: bool=false
	var moved: float=0.0
	var on_move: Callable

	func bind(list_content: Node2D, list_height: float, rows_height: float) -> void:
		content=list_content
		minimum=minf(0.0,list_height-rows_height)
		y=clampf(y,minimum,0.0)
		content.position.y=y

	func input(event: InputEvent) -> void:
		if not is_instance_valid(content):return
		if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
			drag=event.pressed
			if event.pressed:moved=0.0
			return
		var delta: float=0.0
		if event is InputEventScreenDrag:delta=event.relative.y
		elif event is InputEventMouseMotion and drag:delta=event.relative.y
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			delta=60.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
		if delta==0.0:return
		var scale_y: float=absf(content.get_global_transform_with_canvas().get_scale().y)
		if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
		moved+=absf(delta)
		y=clampf(content.position.y+delta,minimum,0.0)
		content.position.y=y
		if on_move.is_valid():on_move.call()

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_production_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	for name: String in ["sort","items","materials"]:_scrolls[name]=ListScroll.new()
	(_scrolls.items as ListScroll).on_move=Callable(self,"_sync_item_rows")
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world):return _fail("source_production_window_host_unavailable")
	_parent=weakref(parent)
	_world=weakref(world)
	_count=1
	for scroll: ListScroll in _scrolls.values():scroll.y=0.0
	return _stage()

## After a craft (or any inventory change) with the same selection.
func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func selected() -> String:
	return _selected

func count() -> int:
	return _count

func tab() -> String:
	return _tab

func category() -> String:
	return _category

func node_keys() -> Dictionary:
	return _last_out

## --- Model ------------------------------------------------------------------

## Recipe ids of the tab (and category), in the existing registry order.
func _recipes(world: Node) -> Array[String]:
	var ids: Array[String]=[]
	var registry: Dictionary=world.crafting.recipes
	var allowed: Array=TABS.get(_tab,[])
	for raw: Variant in registry.keys():
		var category_name: String=str((registry[raw] as Dictionary).get("category",""))
		if not allowed.has(category_name):continue
		if not _category.is_empty() and category_name!=_category:continue
		ids.append(str(raw))
	return ids

func _max_count(world: Node) -> int:
	return 1 if world.crafting.recipes.get(_selected,{}).has("outcomes") else 20

## Material rows: every fixed material, then one row per candidate slot (the
## chosen candidate, or the first one while none is chosen).
func _material_rows(world: Node) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	if _selected.is_empty():return rows
	var recipe: Dictionary=Craft.recipe_of(world,_selected)
	var slot_rows: Dictionary={}
	for slot: Dictionary in recipe.get("material_slots",[]):
		if (slot.candidates as Array).size()<2:continue
		for candidate: Dictionary in slot.candidates:slot_rows[int(candidate.get("row_id",-1))]=int(slot.slot_index)
	var statuses: Array=Craft.material_status(world,_selected,_count)
	for status: Dictionary in statuses:
		if slot_rows.has(int(status.material.get("row_id",-2))):continue
		rows.append(status)
	var choices: Dictionary=world.patch523_material_choices.get(_selected,{})
	for slot: Dictionary in recipe.get("material_slots",[]):
		var candidates: Array=slot.candidates
		if candidates.size()<2:continue
		var key: String=str(int(slot.slot_index))
		var chosen: Dictionary=candidates[0]
		var picked: bool=false
		for candidate: Dictionary in candidates:
			if int(candidate.get("row_id",-1))==int(choices.get(key,-3)):
				chosen=candidate
				picked=true
		var matched: Dictionary={}
		for status: Dictionary in statuses:
			if int(status.material.get("row_id",-2))==int(chosen.get("row_id",-1)):matched=status
		if matched.is_empty():matched={"item":str(chosen.get("item","")),"available":0,"required":int(chosen.get("quantity",0))*_count,"record":{},"source_id":str(chosen.get("source_id","")),"material":chosen.duplicate(true)}
		matched["slot"]=key
		matched["picked"]=picked
		rows.append(matched)
	var recipe_cost: int=int(world._craft_quote(_selected,_count).get("cost",0)) if _selected.begins_with("patch523:") else int(recipe.get("adena",0))*_count
	if recipe_cost>0:rows.append({"item":"아데나","available":int(world.gold),"required":recipe_cost,"record":world._craft_item_index().get("아데나",{}),"source_id":"","material":{}})
	return rows

## --- Stage ------------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var world: Node=_world.get_ref() if _world!=null else null
	if parent==null or world==null:return _fail("source_production_window_host_unavailable")
	var ids: Array[String]=_recipes(world)
	if not ids.has(_selected):_selected=ids[0] if not ids.is_empty() else ""
	_count=clampi(_count,1,_max_count(world))
	var quote: Dictionary=world._craft_quote(_selected,_count) if not _selected.is_empty() else {}
	var materials: Array[Dictionary]=_material_rows(world)
	var spec: Dictionary=_spec(world,ids,quote)
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var pictures: int=0
	if not _selected.is_empty():
		var result: Dictionary=Craft.recipe_of(world,_selected).get("result",{})
		if _picture(next,out,"Slot_Gauge/Slot_Gauge/Production_List_Slot/Sp_IconSample",_record(world,str(result.get("item","")),str(result.get("source_id",""))),str(result.get("item",""))):pictures+=1
	var lists: Array=[
		_fill(next,out,P_LIST+"Nd_List/ListView_Sort","sort",_sort_rows(world)),
		_fill_items(next,out,ids),
		_fill(next,out,P_PROD+"Material/ListView_Material","materials",_material_set_rows(world,materials)),
	]
	var reused: int=int(lists[1].get("reused",0))
	for filled: Dictionary in lists:
		if not filled.get("ok",false):
			next.free()
			last_result=filled
			return filled
		pictures+=int(filled.get("pictures",0))
	var previous: Node2D=_scene
	next.position=LAYOUT_POSITION
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"tab":_tab,"category":_category,"recipes":ids.size(),"selected":_selected,"count":_count,
		"materials":materials.size(),"quote_ok":quote.get("ok",false),"quote_reason":str(quote.get("reason","")),"pictures":pictures,"reused_rows":reused}
	return last_result

func _spec(world: Node, ids: Array[String], quote: Dictionary) -> Dictionary:
	var spec: Dictionary={}
	# Frame.
	spec[P_ALL+"FullFrameType_A/Fx_Img_BG_Particle"]={"exclude":true}
	spec[P_ALL+"Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in TABS:
		var tab_name: String="Btn_Equip" if name=="equip" else "Btn_Other"
		spec[P_ALL+"Nd_TabMenu/"+tab_name+"_On"]={"visible":_tab==name}
		spec[P_ALL+"Nd_TabMenu/"+tab_name+"_Off"]={"visible":_tab!=name,"activate":Callable(self,"_set_tab").bind(name)}
	for tab_name: String in OFF_TABS:
		spec[P_ALL+"Nd_TabMenu/"+tab_name+"_On"]={"visible":false}
		spec[P_ALL+"Nd_TabMenu/"+tab_name+"_Off"]={"activate":Callable(self,"_notice").bind("이 탭은 원본 규칙이 없어 장비·기타 제작만 연결했습니다")}
	spec[P_ALL+"Production_Tab_Main"]={"exclude":true}
	spec[P_ALL+"Nd_SearchBar"]={"exclude":true}
	spec[P_ALL+"Production_Popup_Keypad_Layout"]={"exclude":true}
	spec[P_ALL+"Nd_Notice"]={"visible":ids.is_empty()}
	# Tab_List: lists.
	for name: String in ["Nd_Block","Btn_Back","Nd_List/Nd_Button_List","Nd_ItemList/Common_ButtonSet_Class","Nd_ItemList/Btn_Sort"]:spec[P_LIST+name]={"exclude":true}
	spec[P_LIST+"Nd_ItemList/Label_Notice"]={"visible":ids.is_empty()}
	spec[P_LIST+"Nd_List/ListView_Sort"]={"input":Callable(_scrolls.sort,"input")}
	spec[P_LIST+"Nd_ItemList/ListView"]={"input":Callable(_scrolls.items,"input")}
	spec[P_LIST+"Label_Notice"]={"visible":_selected.is_empty() and not ids.is_empty()}
	# Nd_Production: the selected recipe.
	var has: bool=not _selected.is_empty()
	spec[P_LIST+"Nd_Production"]={"visible":has}
	for name: String in ["Panel_Limited","Fx_Slot_Gauge/Slot_Gauge/Slot_Gauge/FX_Back_OutGlow","Label_Limited_Level","Label_Limited_Class","Nd_Storage_Charge","Btn_Collection","Btn_DetailInfo","Btn_Production_Cancel","ProgressBar/ProgressBar","ProgressBar/Label_Loading"]:spec[P_PROD+name]={"exclude":true}
	# Fx_Slot_Gauge holds the product slot (its glow is an effect layer).
	spec[P_PROD+"Fx_Slot_Gauge"]={"visible":true}
	spec[P_PROD+"Fx_Slot_Gauge/Slot_Gauge"]={"visible":true}
	var recipe: Dictionary=Craft.recipe_of(world,_selected) if has else {}
	var result: Dictionary=recipe.get("result",{})
	spec["Slot_Gauge/Slot_Gauge/Production_List_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	spec["Slot_Gauge/Slot_Gauge/Production_List_Slot/Sp_Select"]={"visible":false}
	var quantity: int=int(result.get("quantity",0))*_count
	spec["Slot_Gauge/Slot_Gauge/Production_List_Slot/Text_Amount"]={"role":"source_text","text":_number(quantity),"visible":quantity>1}
	spec[P_PROD+"Fx_Slot_Gauge/Btn_Tooltip"]={"activate":Callable(self,"_product_info")}
	var level: int=int(result.get("level",0))
	spec[P_PROD+"ProgressBar/Label_Item_Name"]={"role":"source_text","text":("+%d " % level if level>0 else "")+str(result.get("item","")).get_slice(" · 원본#",0)}
	spec[P_PROD+"ProgressBar/Label_Amount"]={"role":"source_text","text":str(_count)}
	var most: int=_max_count(world)
	spec[P_PROD+"ProgressBar/Btn_Arrow_Top"]={"activate":Callable(self,"_add_count").bind(1),"displaystate":_count<most}
	spec[P_PROD+"ProgressBar/Btn_Arrow_Bottom"]={"activate":Callable(self,"_add_count").bind(-1),"displaystate":_count>1}
	# 수량 초기화 (Btn_Count_01), +10, +50.
	spec[P_PROD+"Nd_Count/Btn_Count_01"]={"activate":Callable(self,"_reset_count"),"displaystate":_count>1}
	spec[P_PROD+"Nd_Count/Btn_Count_01/Normal"]={"visible":_count>1}
	spec[P_PROD+"Nd_Count/Btn_Count_01/Disabled"]={"visible":_count<=1}
	for amount: int in [10,50]:
		var key: String=P_PROD+"Nd_Count/Btn_Count_%02d" % amount
		spec[key]={"activate":Callable(self,"_add_count").bind(amount),"displaystate":_count<most}
		spec[key+"/Normal"]={"visible":_count<most}
		spec[key+"/Disabled"]={"visible":_count>=most}
	spec[P_PROD+"Material/Label_Notice"]={"visible":recipe.has("outcomes")}
	spec[P_PROD+"Material/ListView_Material"]={"input":Callable(_scrolls.materials,"input")}
	spec[P_PROD+"Btn_Probability"]={"visible":recipe.has("outcomes"),"activate":Callable(self,"_probability")}
	var can: bool=quote.get("ok",false)
	spec[P_PROD+"Btn_Production"]={"activate":Callable(self,"_craft_requested"),"displaystate":can}
	spec[P_PROD+"Btn_Production/Normal"]={"visible":can}
	spec[P_PROD+"Btn_Production/Normal/Sp_Block"]={"visible":false}
	spec[P_PROD+"Btn_Production/Disabled"]={"visible":not can}
	return spec

## --- Rows -------------------------------------------------------------------

func _sort_rows(world: Node) -> Array:
	var rows: Array=[]
	var titles: Array=["전체"]
	titles.append_array(TABS.get(_tab,[]))
	for title: String in titles:
		var value: String="" if title=="전체" else title
		var chosen: bool=value==_category
		var spec: Dictionary={"Panel":{"input":Callable(_scrolls.sort,"input")}}
		for state: String in ["Btn_Normal","Btn_Pressed"]:
			spec[state]={"visible":(state=="Btn_Pressed")==chosen,"activate":Callable(self,"_set_category").bind(value)}
			spec[state+"/Label"]={"role":"source_text","text":title}
		rows.append({"member":ROW_SORT,"spec":spec})
	return rows

func _item_row(world: Node, id: String) -> Dictionary:
	var recipe: Dictionary=world.crafting.recipes.get(id,{})
	var result: Dictionary=recipe.get("result",{})
	var chosen: bool=id==_selected
	var ok: bool=world._craft_quote(id,1).get("ok",false)
	var spec: Dictionary={"Panel":{"input":Callable(_scrolls.items,"input")}}
	spec["Btn_Normal"]={"visible":not chosen,"activate":Callable(self,"_select").bind(id)}
	spec["Btn_Pressed"]={"visible":chosen,"activate":Callable(self,"_select").bind(id)}
	for state: String in ["Btn_Normal","Btn_Pressed"]:
		spec[state+"/Sp_Arrow_Close"]={"visible":not chosen}
		spec[state+"/Sp_Arrow_Open"]={"visible":chosen}
	spec["Btn_Disabled"]={"visible":false}
	spec["Nd_Collection"]={"visible":false}
	spec["Label_Production"]={"visible":ok}
	spec["Label_Item"]={"role":"source_text","text":_title(recipe,result,id)}
	spec["Common_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	spec["Common_Slot/Sp_Select"]={"visible":false}
	var quantity: int=int(result.get("quantity",1))
	spec["Common_Slot/Text_Amount"]={"role":"source_text","text":_number(quantity),"visible":quantity>1}
	spec["Common_Slot/Btn"]={"activate":Callable(self,"_select").bind(id)}
	return {"member":ROW_ITEM,"spec":spec,"picture":["Common_Slot/Sp_IconSample",_record(world,str(result.get("item","")),str(result.get("source_id",""))),str(result.get("item",""))]}

func _fill_items(root: Node2D, out: Dictionary, ids: Array[String]) -> Dictionary:
	var list: Dictionary=NamedTree.locate(root,out,P_LIST+"Nd_ItemList/ListView")
	var node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null
	if not content is Node2D:return _fail("source_production_window_list_content_missing")
	_reusable={}
	if not _reuse_except.is_empty() and is_instance_valid(_item_content):
		for index: Variant in _item_rows:
			var kept: Node2D=_item_rows[index]
			var id: String=str(kept.get_meta("recipe_id",""))
			if is_instance_valid(kept) and not _reuse_except.has(id) and int(index)<ids.size() and ids[int(index)]==id:_reusable[int(index)]=kept
	_reuse_except=[]
	_item_ids=ids
	_item_content=content
	_item_size=NamedTree.list_size(out,_pack,TAB_LIST,"Nd_ItemList/ListView")
	_item_rows={}
	var height: float=_item_height()*float(ids.size())
	var scroll: ListScroll=_scrolls.items
	# Keep the selected recipe in view when it moved out of the window.
	var at: int=ids.find(_selected)
	if at>=0:
		var top: float=-_item_height()*float(at)
		if scroll.y<top or scroll.y>top+_item_size.y-_item_height():scroll.y=top
	scroll.bind(content,_item_size.y,height)
	return _sync_item_rows()

func _item_height() -> float:
	return float(_tree.row_panel(ROW_ITEM).size[1])

func _sync_item_rows() -> Dictionary:
	if not is_instance_valid(_item_content):return {"ok":true,"pictures":0}
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_production_window_host_unavailable")
	var first: int=maxi(0,floori(-(_scrolls.items as ListScroll).y/_item_height())-2)
	var last: int=mini(_item_ids.size(),first+ITEM_WINDOW)
	for index: Variant in _item_rows.keys():
		if int(index)<first or int(index)>=last:
			var old: Node2D=_item_rows[index]
			_item_rows.erase(index)
			if is_instance_valid(old):old.queue_free()
	var pictures: int=0
	var reused: int=0
	for index: int in range(first,last):
		if _item_rows.has(index):continue
		if _reusable.has(index):
			var kept: Node2D=_reusable[index]
			_reusable.erase(index)
			kept.get_parent().remove_child(kept)
			_item_content.add_child(kept)
			_item_rows[index]=kept
			reused+=1
			continue
		var row: Dictionary=_item_row(world,_item_ids[index])
		var row_out: Dictionary={}
		var built: Dictionary=_tree.scene_of(row.member,row.spec,row_out)
		if not built.get("ok",false):return built
		_tree.add_row(_item_content,row.member,built.scene,index,_item_size)
		built.scene.set_meta("recipe_id",_item_ids[index])
		_item_rows[index]=built.scene
		if _picture(built.scene,row_out,str(row.picture[0]),row.picture[1],str(row.picture[2])):pictures+=1
	return {"ok":true,"pictures":pictures,"rows":_item_rows.size(),"reused":reused}

## Two materials per Production_List_Material_Set row (_L, _R).
func _material_set_rows(world: Node, materials: Array[Dictionary]) -> Array:
	var rows: Array=[]
	for start: int in range(0,materials.size(),2):
		var spec: Dictionary={"Panel":{"input":Callable(_scrolls.materials,"input")}}
		var pictures: Array=[]
		for side: int in range(2):
			var key: String="Production_List_Material_"+("L" if side==0 else "R")+"/"
			var at: int=start+side
			if at>=materials.size():
				spec[key.trim_suffix("/")]={"visible":false}
				continue
			var row: Dictionary=materials[at]
			spec[key+"Btn_Pressed"]={"visible":false}
			spec[key+"Btn_Normal"]={"activate":Callable(self,"_material_info").bind(at)}
			spec[key+"Btn_Normal/Label_Item_Name"]={"role":"source_text","text":str(row.item).get_slice(" · 원본#",0)}
			var counted: String="선택 필요" if row.has("slot") and not bool(row.get("picked",false)) else "%s/%s" % [_number(int(row.available)),_number(int(row.required))]
			spec[key+"Btn_Normal/Label_Item_Count"]={"role":"source_text","text":counted}
			spec[key+"Btn_Normal/Btn_Replace"]={"visible":row.has("slot"),"activate":Callable(self,"_replace").bind(str(row.get("slot","")))}
			spec[key+"Btn_Normal/Production_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
			spec[key+"Btn_Normal/Production_Slot/Sp_Select"]={"visible":false}
			spec[key+"Btn_Normal/Production_Slot/Text_Amount"]={"visible":false}
			spec[key+"Btn_Normal/Production_Slot/Btn"]={"activate":Callable(self,"_material_info").bind(at)}
			pictures.append([key+"Btn_Normal/Production_Slot/Sp_IconSample",_record(world,str(row.item),str(row.source_id),row.get("record",{})),str(row.item)])
		rows.append({"member":ROW_MATERIAL,"spec":spec,"pictures":pictures})
	return rows

func _fill(root: Node2D, out: Dictionary, suffix: String, scroll: String, rows: Array) -> Dictionary:
	var list: Dictionary=NamedTree.locate(root,out,suffix)
	var node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null
	if not content is Node2D:return _fail("source_production_window_list_content_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,TAB_LIST,suffix.trim_prefix(P_LIST))
	var height: float=0.0
	var pictures: int=0
	var gap: float=4.0 if scroll=="materials" else 0.0
	for index: int in range(rows.size()):
		var row: Dictionary=rows[index]
		var row_out: Dictionary={}
		var built: Dictionary=_tree.scene_of(row.member,row.spec,row_out)
		if not built.get("ok",false):return built
		height+=_tree.add_row(content,row.member,built.scene,index,size,gap)
		var wanted: Array=row.get("pictures",[])
		if row.has("picture"):wanted=[row.picture]
		for picture: Array in wanted:
			if _picture(built.scene,row_out,str(picture[0]),picture[1],str(picture[2])):pictures+=1
	(_scrolls[scroll] as ListScroll).bind(content,size.y,height)
	return {"ok":true,"pictures":pictures,"rows":rows.size()}

## The item record the existing image owner reads (patch523 rows by their
## ItemClass source_id, others by the TWILIGHT catalog record).
func _record(world: Node, item_name: String, source_id: String, record: Dictionary={}) -> Dictionary:
	if source_id.is_valid_int() and int(source_id)>0:return {"source_item_class_id":int(source_id),"name":item_name,"_item_class_only":true}
	if not record.is_empty():return record
	return world._craft_item_index().get(item_name,{})

func _picture(root: Node2D, out: Dictionary, suffix: String, record: Dictionary, title: String) -> bool:
	if record.is_empty():return false
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var info: Dictionary=SourceImages.describe_item_class(int(record.source_item_class_id),title) if record.get("_item_class_only",false) else SourceImages.describe_item(record,title)
	var owner: Dictionary={"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
	if not owner.ok:return false
	if not located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false):return false
	return located.player.set_bound_visible(located.offset,true).get("ok",false)

## --- Actions -----------------------------------------------------------------

func _moved() -> bool:
	for scroll: ListScroll in _scrolls.values():
		if scroll.moved>12.0:return true
	return false

func _set_tab(value: String) -> Dictionary:
	if value==_tab:return {"ok":true}
	_tab=value
	_category=""
	_selected=""
	_count=1
	for scroll: ListScroll in _scrolls.values():scroll.y=0.0
	return _stage()

func _set_category(value: String) -> Dictionary:
	if _moved():return {"ok":true,"ignored_after_drag":true}
	_category=value
	_selected=""
	_count=1
	(_scrolls.items as ListScroll).y=0.0
	return _stage()

func _select(id: String) -> Dictionary:
	if _moved():return {"ok":true,"ignored_after_drag":true}
	_reuse_except=[_selected,id]
	if id!=_selected:
		_selected=id
		_count=1
		(_scrolls.materials as ListScroll).y=0.0
	return _stage()

func select_recipe(id: String) -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null or not world.crafting.recipes.has(id):return _fail("source_production_window_recipe_missing")
	var category_name: String=str(world.crafting.recipes[id].get("category",""))
	for name: String in TABS:
		if (TABS[name] as Array).has(category_name):_tab=name
	_category=""
	_selected=id
	_count=1
	return _stage()

func _reset_count() -> Dictionary:
	_reuse_except=[_selected]
	_count=1
	return _stage()

func _add_count(delta: int) -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_production_window_host_unavailable")
	_reuse_except=[_selected]
	_count=clampi(_count+delta,1,_max_count(world))
	return _stage()

## 대체: the next candidate of a material slot (the existing choice store).
func _replace(slot_key: String) -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null or _selected.is_empty():return _fail("source_production_window_recipe_missing")
	var recipe: Dictionary=world.crafting.recipes.get(_selected,{})
	for slot: Dictionary in recipe.get("material_slots",[]):
		if str(int(slot.slot_index))!=slot_key:continue
		var candidates: Array=slot.candidates
		var chosen: Dictionary=world.patch523_material_choices.get(_selected,{}).duplicate(true)
		var current: int=-1
		for index: int in range(candidates.size()):
			if int(candidates[index].row_id)==int(chosen.get(slot_key,-3)):current=index
		chosen[slot_key]=int(candidates[(current+1)%candidates.size()].row_id)
		world.patch523_material_choices[_selected]=chosen
		_reuse_except=[_selected]
		return _stage()
	return _fail("source_production_window_slot_missing")

func _notice(text: String) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud!=null and hud.has_method("show_message"):hud.call("show_message",text)
	return {"ok":true,"notice":text}

func _material_info(index: int) -> Dictionary:
	if _moved():return {"ok":true,"ignored_after_drag":true}
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_production_window_host_unavailable")
	var rows: Array[Dictionary]=_material_rows(world)
	if index<0 or index>=rows.size():return {"ok":true}
	var row: Dictionary=rows[index]
	return _notice("%s · 보유 %s / 필요 %s" % [str(row.item).get_slice(" · 원본#",0),_number(int(row.available)),_number(int(row.required))])

func _product_info() -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null or _selected.is_empty():return _fail("source_production_window_recipe_missing")
	var quote: Dictionary=world._craft_quote(_selected,_count)
	return _notice("제작 가능" if quote.get("ok",false) else str(quote.get("reason","제작 불가")))

func _probability() -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null or _selected.is_empty():return _fail("source_production_window_recipe_missing")
	var chances: PackedStringArray=[]
	for outcome: Dictionary in Craft.recipe_of(world,_selected).get("outcomes",[]):
		chances.append("%s %.2f%%" % ["지급 없음" if outcome.get("empty_result",false) else str(outcome.label),float(outcome.probability)/10000.0])
	return _notice(" / ".join(chances))

func _craft_requested() -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if world==null or hud==null or _selected.is_empty():return _fail("source_production_window_recipe_missing")
	return {"ok":Craft.confirm_craft(hud,world,_selected,_count),"confirmation_owner":"renewal_crafting.confirm_craft"}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

## The product name (the recipe's "원본523 · " prefix and the source id
## suffix are TWILIGHT bookkeeping, not item names).
static func _title(recipe: Dictionary, result: Dictionary, id: String) -> String:
	var title: String=str(result.get("item","")).get_slice(" · 원본#",0)
	if title.is_empty():title=str(recipe.get("name",id)).trim_prefix("원본523 · ")
	var level: int=int(result.get("level",0))
	return ("+%d " % level if level>0 else "")+title

static func _number(value: int) -> String:
	var digits: String=str(absi(value))
	var grouped: String=""
	while digits.length()>3:
		grouped=","+digits.right(3)+grouped
		digits=digits.left(digits.length()-3)
	return ("-" if value<0 else "")+digits+grouped

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
