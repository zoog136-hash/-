extends RefCounted
## The original 523 제작 window: ProductionScene with Production_All (frame,
## close, 장비 / 기타 tabs) and Production_Tab_List (category list, recipe list
## of Production_List_Item rows, the selected product, material rows of
## Production_List_Material_Set, +1/+10/+50 and ▲▼ amount, 제 작).
## Recipes, quotes, owned counts, material choices, the confirmation and the
## transaction stay with the existing owners (world.crafting / patch523
## rules, renewal_crafting.confirm_target → craft_requested).
## 메인 / 한정 / 서버한정 list the registry recipes of the original
## recommendation list and MainCategoryID 41 / 51 (scripts/crafting/
## craft_tabs523.gd); their category list is every TWILIGHT category.
## The native search/favorites tabs reuse this recipe list and its actions.
## The 이벤트 tab is 비법서 제작 when the world has it:
## TWILIGHT 근사, the existing panel), the class filter,
## 컬렉션 이동, 결과 상세 보기, the progress bar, the limits /
## period texts, the 출처 popup, the keypad, every effect layer.
## The recipe list shows 제작 가능 우선 from the start (사용자 목록 28): recipes
## the existing quote allows first, the rest after in their own order; the
## list's Btn_Sort (Normal / Enable) turns it off and on again (TWILIGHT
## 근사(근거 약함), docs/original_ui523_approx.md). A recipe that cannot be
## made now shows the row's original Btn_Disabled dim layer (Img_Bg, black
## at 40%; its 품절 mark stays hidden) and stays selectable.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const NativeIcons=preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd")
const Craft=preload("res://scripts/ui/renewal_crafting.gd")
const Search=preload("res://scripts/ui/original_ui/source_main_inventory_search.gd")
const QueryEdit=preload("res://scripts/ui/native_touch_line_edit.gd")
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
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
const LOOKUP_TABS={"favorites":"Btn_Bookmark","search":"Btn_Search"}
const FAVORITES_KEY="craft_recipe_favorites"
const SEARCH_KEYPAD="UI/Production/Production_Popup_Keypad.csb"
## Original-table tabs (craft_tabs523): tab -> its Nd_TabMenu button.
const SOURCE_TABS: Dictionary={"main":"Btn_Main","limited":"Btn_LimitedAccount","server":"Btn_LimitedServer"}
const CraftTabs=preload("res://scripts/crafting/craft_tabs523.gd")
## The recipe ids of the shown original-table tab (made when the tab opens).
var _source_ids: Array[String]=[]
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
var _ready_first: bool=true
var _scrolls: Dictionary={}
var _last_out: Dictionary={}
var _shown_recipe: Dictionary={}
var _shown_quantity: Dictionary={}
var _shown_duplicates: Dictionary={}
var last_result: Dictionary={}
## The recipe list builds only the rows near its visible part (a tab holds
## hundreds of recipes; building every row stalled and ran out of memory).
const ITEM_WINDOW: int=10
## Recipe rows another stage may keep (index -> [recipe id, row scene]):
## a selection or amount change rebuilds only the rows whose state changed.
var _reusable: Dictionary={}
var _reuse_except: Array[String]=[]
var _reuse_by_state: bool=false
## Sort / material rows of the last tree by list: index -> scene; a row whose
## member, spec and pictures read the same is moved, not rebuilt.
var _fill_rows: Dictionary={}
var _item_ids: Array[String]=[]
var _item_content: Node2D
var _item_size: Vector2
var _item_rows: Dictionary={}
var _search: RefCounted
var _query_editor: LineEdit
var _search_supported: bool=false
var _query: String=""
var _search_kind: String="material"
var _search_picker: bool=false

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
	_search_supported=pack.manifest.get("scenes",{}).has(SEARCH_KEYPAD)
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	for name: String in ["sort","items","materials"]:_scrolls[name]=ListScroll.new()
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world):return _fail("source_production_window_host_unavailable")
	_parent=weakref(parent)
	_world=weakref(world)
	_count=1
	if SOURCE_TABS.has(_tab):_source_ids=source_tab_ids(world,_tab)
	for scroll: ListScroll in _scrolls.values():scroll.y=0.0
	(_scrolls.items as ListScroll).on_move=Callable(self,"_sync_item_rows")
	return _stage()

## After a craft (or any inventory change) with the same selection.
## After a game change (craft, bag): rows whose shown state (recipe, selection,
## 제작 가능) is unchanged are moved into the new tree instead of rebuilt
## (2026-11-19 measure: ~16 ms per row, ~0.4 s per refresh of ten rows).
func refresh() -> Dictionary:
	if not is_open():return {"ok":true,"handled":false}
	_reuse_by_state=true
	return _stage()

func close() -> void:
	close_search()
	if is_instance_valid(_query_editor): _query_editor.queue_free()
	_query_editor=null
	_search_picker=false
	var previous: Node2D=_scene
	_scene=null
	# Row reuse applies while its tree is live. Reopening needs fresh rows
	# after the previous scene has been freed.
	_fill_rows.clear()
	_item_rows.clear()
	_reusable.clear()
	_reuse_except.clear()
	_reuse_by_state=false
	_item_content=null
	_last_out.clear()
	for scroll: ListScroll in _scrolls.values():
		scroll.content=null
		scroll.drag=false
		scroll.moved=0.0
		scroll.on_move=Callable()
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
	if LOOKUP_TABS.has(_tab):
		var favorites: Dictionary=_favorites(world) if _tab=="favorites" else {}
		if (_tab=="favorites" and favorites.is_empty()) or (_tab=="search" and _query.is_empty()):return ids
		var needle: String=_query.to_lower()
		for id: String in registry:
			if _tab=="favorites":
				if favorites.get(id)==true:ids.append(id)
			elif _matches_recipe(registry[id],id,needle,_search_kind):ids.append(id)
		if _ready_first:ids=ready_first(ids,func(id: String) -> bool:return _craftable(world,id))
		return ids
	if SOURCE_TABS.has(_tab):
		for id: String in _source_ids:
			if registry.has(id) and (_category.is_empty() or str((registry[id] as Dictionary).get("category",""))==_category):ids.append(id)
		if _ready_first:ids=ready_first(ids,func(id: String) -> bool:return _craftable(world,id))
		return ids
	var allowed: Array=TABS.get(_tab,[])
	for raw: Variant in registry.keys():
		var category_name: String=str((registry[raw] as Dictionary).get("category",""))
		if not allowed.has(category_name):continue
		if not _category.is_empty() and category_name!=_category:continue
		ids.append(str(raw))
	if _ready_first:ids=ready_first(ids,func(id: String) -> bool:return _craftable(world,id))
	return ids

static func _matches_recipe(recipe: Dictionary, id: String, needle: String, kind: String) -> bool:
	if kind=="result":return _title(recipe,recipe.get("result",{}),id).to_lower().contains(needle) or str(recipe.get("name","")).to_lower().contains(needle)
	for material: Dictionary in recipe.get("materials",[]):
		if str(material.get("item","")).to_lower().contains(needle):return true
	for slot: Dictionary in recipe.get("material_slots",[]):
		for candidate: Dictionary in slot.get("candidates",[]):
			if str(candidate.get("item","")).to_lower().contains(needle):return true
	return false

static func _favorites(world: Node) -> Dictionary:
	if not is_instance_valid(world):return {}
	var preferences: Variant=world.get("ui_preferences")
	var saved: Variant=preferences.get(FAVORITES_KEY) if preferences is Dictionary else null
	return saved if saved is Dictionary else {}

## 제작 가능 우선: craftable recipes first, each group in its own order.
static func ready_first(ids: Array[String], craftable: Callable) -> Array[String]:
	var ready: Array[String]=[]
	var rest: Array[String]=[]
	for id: String in ids:
		if craftable.call(id):ready.append(id)
		else:rest.append(id)
	ready.append_array(rest)
	return ready

func _toggle_ready_first() -> Dictionary:
	if _moved():return {"ok":true,"ignored_after_drag":true}
	_ready_first=not _ready_first
	(_scrolls.items as ListScroll).y=0.0
	return _stage()

func _max_count(world: Node) -> int:
	return 1 if world.crafting.recipes.get(_selected,{}).has("outcomes") else 20

## Material rows: every fixed material, then one row per candidate slot (the
## chosen candidate, or the first one while none is chosen).
func _material_rows(world: Node, quote: Dictionary) -> Array[Dictionary]:
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
	var recipe_cost: int=int(quote.get("cost",0)) if _selected.begins_with("patch523:") else int(recipe.get("adena",0))*_count
	if recipe_cost>0:rows.append({"item":"아데나","available":int(world.gold),"required":recipe_cost,"record":world._craft_item_index().get("아데나",{}),"source_id":"","material":{}})
	return rows

## --- Stage ------------------------------------------------------------------

## One build of the window reads the same character values for every recipe
## row (carrying capacity, weight, skill stats) and asks each row's 1-count
## quote up to three times (ready-first sort, row, reuse). Nothing changes
## while it is built: derived stats are memoized for the build
## (world._stat_memo_begin/_end) and each row's craftable answer is asked once
## (Twm diag 2026-11-26: opening 제작 asked skill ownership 44,928 times).
## Outside a build (scrolling rows in) every answer is asked fresh.
var _ok_memo: Dictionary = {}
var _preview_quote: Callable
var _building: bool = false

func _stage(quantity_only: bool=false) -> Dictionary:
	var started: int=FRAME_HITCH.now()
	var nested: int=FRAME_HITCH.nested()
	var world: Node=_world.get_ref() if _world!=null else null
	var memo: bool=world!=null and world.has_method("_stat_memo_begin") and world.has_method("_stat_memo_end")
	if memo:world.call("_stat_memo_begin")
	if world!=null and world.has_method("production_preview_quote"):
		_preview_quote=world.production_preview_quote()
	_ok_memo={}
	_building=true
	var result: Dictionary=_stage_built(quantity_only)
	_building=false
	_preview_quote=Callable()
	_ok_memo={}
	if memo and is_instance_valid(world):world.call("_stat_memo_end")
	FRAME_HITCH.add_self("ui_crafting",started,nested)
	return result

func _craftable(world: Node, id: String) -> bool:
	if _building and _ok_memo.has(id):return bool(_ok_memo[id])
	var ready: bool = world.production_recipe_craftable(id, _preview_quote) if world.has_method("production_recipe_craftable") else bool(_quote(world,id,1).get("ok",false))
	if _building:_ok_memo[id]=ready
	return ready

func _quote(world: Node, id: String, count: int) -> Dictionary:
	return _preview_quote.call(id,count) if _preview_quote.is_valid() else world._craft_quote(id,count)

func _stage_built(quantity_only: bool) -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var world: Node=_world.get_ref() if _world!=null else null
	if parent==null or world==null:return _fail("source_production_window_host_unavailable")
	var started: int=FRAME_HITCH.now()
	var ids: Array[String]=_recipes(world)
	started=FRAME_HITCH.detail_next("craft.recipe_order",started)
	if not ids.has(_selected):_selected=ids[0] if not ids.is_empty() else ""
	_count=clampi(_count,1,_max_count(world))
	var quote: Dictionary=_quote(world,_selected,_count) if not _selected.is_empty() else {}
	var materials: Array[Dictionary]=_material_rows(world,quote)
	var recipe: Dictionary=Craft.recipe_of(world,_selected) if not _selected.is_empty() else {}
	var product: Dictionary=recipe.get("result",{})
	var quantity: Dictionary=_quantity_spec(int(product.get("quantity",0))*_count,_max_count(world),bool(quote.get("ok",false)))
	started=FRAME_HITCH.detail_next("craft.recipe_detail",started)
	if quantity_only:
		if _can_refresh_quantity(world,ids,recipe):
			var updated: Dictionary=_refresh_quantity(world,quantity,materials)
			if updated.get("ok",false):
				FRAME_HITCH.detail("craft.quantity_nodes",started)
				return _publish_stage(ids.size(),materials.size(),quote,int(updated.pictures),_item_rows.size())
		_reuse_by_state=true
	var spec: Dictionary=_spec(world,ids,recipe,quantity)
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var duplicates: Dictionary=_tree.duplicate_paths.duplicate()
	var pictures: int=0
	if not _selected.is_empty():
		if _picture(next,out,"Slot_Gauge/Slot_Gauge/Production_List_Slot/Sp_IconSample",_record(world,str(product.get("item","")),str(product.get("source_id",""))),str(product.get("item",""))):pictures+=1
	var list_started: int=FRAME_HITCH.detail_next("craft.window_root",started)
	# The visible list rows all use the same few authored members. Geometry
	# and bindings can read those records once during this synchronous build.
	var reads: Dictionary={}
	var lists: Array=[
		_fill(next,out,P_LIST+"Nd_List/ListView_Sort","sort",_sort_rows(world),reads),
		_fill_items(next,out,ids,reads),
		_fill(next,out,P_PROD+"Material/ListView_Material","materials",_material_set_rows(world,materials),reads),
	]
	var reused: int=int(lists[1].get("reused",0))
	for filled: Dictionary in lists:
		if not filled.get("ok",false):
			next.free()
			last_result=filled
			return filled
		pictures+=int(filled.get("pictures",0))
	FRAME_HITCH.detail("craft.window_lists",list_started)
	FRAME_HITCH.detail("craft.window_nodes",started)
	var previous: Node2D=_scene
	next.position=LAYOUT_POSITION
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	_shown_recipe=recipe.duplicate(true)
	_shown_quantity=quantity
	_shown_duplicates=duplicates
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	return _publish_stage(ids.size(),materials.size(),quote,pictures,reused)

func _publish_stage(recipes: int, materials: int, quote: Dictionary, pictures: int, reused: int) -> Dictionary:
	last_result={"ok":true,"handled":true,"member":ROOT,"tab":_tab,"category":_category,"recipes":recipes,"selected":_selected,"count":_count,
		"materials":materials,"quote_ok":quote.get("ok",false),"quote_reason":str(quote.get("reason","")),"pictures":pictures,"reused_rows":reused}
	return last_result

## Preserve the normal rebuild when the order, visible readiness or selected
## definition changed. A count edit alone does not need another scene.
func _can_refresh_quantity(world: Node, ids: Array[String], recipe: Dictionary) -> bool:
	if not is_open() or _selected.is_empty() or last_result.get("selected")!=_selected or _shown_quantity.is_empty():return false
	if ids!=_item_ids or recipe!=_shown_recipe or not is_instance_valid(_item_content):return false
	var row_height: float=_item_height()
	var top: float=-row_height*float(ids.find(_selected))
	var scroll: ListScroll=_scrolls.items
	if scroll.y<top or scroll.y>top+_item_size.y-row_height:return false
	for index: int in _item_rows:
		var row: Node2D=_item_rows[index]
		if index>=ids.size() or not is_instance_valid(row) or bool(row.get_meta("row_ok",false))!=_craftable(world,ids[index]):return false
	return true

func _refresh_quantity(world: Node, quantity: Dictionary, materials: Array[Dictionary]) -> Dictionary:
	if not _write_quantity_fields(quantity):
		_write_quantity_fields(_shown_quantity)
		return {"ok":false}
	var rows: Array=_material_set_rows(world,materials)
	var filled: Dictionary={"ok":true,"pictures":0}
	if not _update_material_amounts(rows):
		filled=_fill(_scene,_last_out,P_PROD+"Material/ListView_Material","materials",rows)
	if not filled.get("ok",false):
		_write_quantity_fields(_shown_quantity)
		return filled
	_shown_quantity=quantity
	return filled

func _write_quantity_fields(spec: Dictionary) -> bool:
	var targets: Dictionary={}
	for path: String in spec:
		var target: Dictionary=NamedTree.locate_exact(_scene,_last_out,path,_shown_duplicates)
		if not target.get("ok",false):return false
		targets[path]=target
	var setters: Dictionary={"text":"set_bound_text","visible":"set_bound_visible","displaystate":"set_bound_displaystate"}
	for path: String in spec:
		var target: Dictionary=targets[path]
		for field: String in setters:
			if not spec[path].has(field):continue
			var result: Dictionary=target.player.call(setters[field],target.offset,spec[path][field])
			if not result.get("ok",false):return false
	return true

func _spec(world: Node, ids: Array[String], recipe: Dictionary, quantity: Dictionary) -> Dictionary:
	var spec: Dictionary={}
	# Frame.
	spec[P_ALL+"FullFrameType_A/Fx_Img_BG_Particle"]={"exclude":true}
	spec[P_ALL+"Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in TABS:
		var tab_name: String="Btn_Equip" if name=="equip" else "Btn_Other"
		spec[P_ALL+"Nd_TabMenu/"+tab_name+"_On"]={"visible":_tab==name}
		spec[P_ALL+"Nd_TabMenu/"+tab_name+"_Off"]={"visible":_tab!=name,"activate":Callable(self,"_set_tab").bind(name)}
	for name: String in SOURCE_TABS:
		spec[P_ALL+"Nd_TabMenu/"+str(SOURCE_TABS[name])+"_On"]={"visible":_tab==name}
		spec[P_ALL+"Nd_TabMenu/"+str(SOURCE_TABS[name])+"_Off"]={"visible":_tab!=name,"activate":Callable(self,"_set_tab").bind(name)}
	for key: String in LOOKUP_TABS:
		var tab_name: String=P_ALL+"Nd_TabMenu/"+str(LOOKUP_TABS[key])
		var available: bool=key!="search" or _search_supported
		spec[tab_name+"_On"]={"visible":available and _tab==key}
		spec[tab_name+"_Off"]={"visible":available and _tab!=key,"activate":Callable(self,"_set_tab").bind(key)}
	spec[P_ALL+"Nd_TabMenu/Btn_Event_On"]={"visible":false}
	spec[P_ALL+"Nd_TabMenu/Btn_Event_Off"]={"activate":Callable(self,"_notice").bind("이 탭은 원본 규칙이 없어 열 수 없습니다")}
	# 비법서 제작 (TWILIGHT 근사): the original has no GachaCraft entry here, so
	# the 이벤트 tab opens the existing 비법서 제작 panel (renewal_crafting).
	if world.has_method("patch523_gacha_craft_owned"):
		spec[P_ALL+"Nd_TabMenu/Btn_Event_Off"]={"activate":Callable(self,"_open_gacha")}
		spec[P_ALL+"Nd_TabMenu/Btn_Event_Off/Label"]={"role":"source_text","text":"비법서 제작"}
	spec[P_ALL+"Production_Tab_Main"]={"exclude":true}
	if _tab=="search" and _search_supported:spec.merge(_search_spec())
	else:spec[P_ALL+"Nd_SearchBar"]={"exclude":true}
	spec[P_ALL+"Production_Popup_Keypad_Layout"]={"exclude":true}
	spec[P_ALL+"Nd_Notice"]={"visible":ids.is_empty()}
	# Tab_List: lists.
	for name: String in ["Nd_Block","Btn_Back","Nd_List/Nd_Button_List","Nd_ItemList/Common_ButtonSet_Class"]:spec[P_LIST+name]={"exclude":true}
	spec[P_LIST+"Nd_ItemList/Btn_Sort"]={"activate":Callable(self,"_toggle_ready_first")}
	spec[P_LIST+"Nd_ItemList/Btn_Sort/Normal"]={"visible":not _ready_first}
	spec[P_LIST+"Nd_ItemList/Btn_Sort/Enable"]={"visible":_ready_first}
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
	var result: Dictionary=recipe.get("result",{})
	spec["Slot_Gauge/Slot_Gauge/Production_List_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	spec["Slot_Gauge/Slot_Gauge/Production_List_Slot/Sp_Select"]={"visible":false}
	spec[P_PROD+"Fx_Slot_Gauge/Btn_Tooltip"]={"activate":Callable(self,"_product_info")}
	var level: int=int(result.get("level",0))
	spec[P_PROD+"ProgressBar/Label_Item_Name"]={"role":"source_text","text":("+%d " % level if level>0 else "")+str(result.get("item","")).get_slice(" · 원본#",0)}
	spec[P_PROD+"Material/Label_Notice"]={"visible":recipe.has("outcomes")}
	spec[P_PROD+"Material/ListView_Material"]={"input":Callable(_scrolls.materials,"input")}
	spec[P_PROD+"Btn_Probability"]={"visible":recipe.has("outcomes"),"activate":Callable(self,"_probability")}
	spec[P_PROD+"Btn_Production/Normal/Sp_Block"]={"visible":false}
	spec.merge(quantity)
	return spec

func _search_spec() -> Dictionary:
	var bar: String=P_ALL+"Nd_SearchBar/"
	var picker: String=bar+"Nd_Popup_Select/"
	return {P_ALL+"Nd_SearchBar":{"visible":true},
		bar+"Btn_Search":{"activate":Callable(self,"open_search")},
		bar+"Btn_Search/Text":{"role":"source_text","text":_query if not _query.is_empty() else "아이템 이름"},
		bar+"Btn_Reset_All":{"activate":Callable(self,"_clear_search")},
		bar+"Btn_Reset_All/Normal":{"visible":not _query.is_empty()},
		bar+"Btn_Reset_All/Disabled":{"visible":_query.is_empty()},
		bar+"Btn_Select/Btn_Material":{"visible":_search_kind=="material","activate":Callable(self,"_toggle_search_kind")},
		bar+"Btn_Select/Btn_Result":{"visible":_search_kind=="result","activate":Callable(self,"_toggle_search_kind")},
		bar+"Nd_Popup_Select":{"visible":_search_picker},
		picker+"Btn_All_On":{"visible":_search_kind=="material","activate":Callable(self,"_set_search_kind").bind("material")},
		picker+"Btn_All_Off":{"visible":_search_kind!="material","activate":Callable(self,"_set_search_kind").bind("material")},
		picker+"Btn_Premium_On":{"visible":_search_kind=="result","activate":Callable(self,"_set_search_kind").bind("result")},
		picker+"Btn_Premium_Off":{"visible":_search_kind!="result","activate":Callable(self,"_set_search_kind").bind("result")}}

func _quantity_spec(produced: int, most: int, can: bool) -> Dictionary:
	var spec: Dictionary={}
	spec["Slot_Gauge/Slot_Gauge/Production_List_Slot/Text_Amount"]={"role":"source_text","text":_number(produced),"visible":produced>1}
	spec[P_PROD+"ProgressBar/Label_Amount"]={"role":"source_text","text":str(_count)}
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
	spec[P_PROD+"Btn_Production"]={"activate":Callable(self,"_craft_requested"),"displaystate":can}
	spec[P_PROD+"Btn_Production/Normal"]={"visible":can}
	spec[P_PROD+"Btn_Production/Disabled"]={"visible":not can}
	return spec

## --- Rows -------------------------------------------------------------------

func _sort_rows(world: Node) -> Array:
	var rows: Array=[]
	var titles: Array=["전체"]
	if SOURCE_TABS.has(_tab):
		for name: String in TABS:titles.append_array(TABS[name])
	else:titles.append_array(TABS.get(_tab,[]))
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
	var ok: bool=_craftable(world,id)
	var spec: Dictionary={"Panel":{"input":Callable(_scrolls.items,"input")}}
	spec["Btn_Normal"]={"visible":not chosen,"activate":Callable(self,"_select").bind(id)}
	spec["Btn_Pressed"]={"visible":chosen,"activate":Callable(self,"_select").bind(id)}
	for state: String in ["Btn_Normal","Btn_Pressed"]:
		spec[state+"/Sp_Arrow_Close"]={"visible":not chosen}
		spec[state+"/Sp_Arrow_Open"]={"visible":chosen}
	# Not craftable now: the original dim layer over the row (Img_Bg, 40%
	# black); the row still selects (its tap goes to the same select).
	spec["Btn_Disabled"]={"visible":not ok,"activate":Callable(self,"_select").bind(id)}
	spec["Btn_Disabled/Nd_SoldOut"]={"visible":false}
	spec["Nd_Collection"]={"visible":false}
	spec["Label_Production"]={"visible":ok}
	spec["Label_Item"]={"role":"source_text","text":_title(recipe,result,id)}
	spec["Common_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	spec["Common_Slot/Sp_Select"]={"visible":false}
	var quantity: int=int(result.get("quantity",1))
	spec["Common_Slot/Text_Amount"]={"role":"source_text","text":_number(quantity),"visible":quantity>1}
	spec["Common_Slot/Btn"]={"activate":Callable(self,"_select").bind(id)}
	var bookmark: String="Panel/Btn_CheckBox/"
	var starred: bool=_favorites(world).get(id)==true
	spec[bookmark+"Btn_Normal"]={"activate":Callable(self,"_toggle_favorite").bind(id),"visible":not starred}
	spec[bookmark+"Btn_Enable"]={"activate":Callable(self,"_toggle_favorite").bind(id),"visible":starred}
	return {"member":ROW_ITEM,"ok":ok,"favorite":starred,"spec":spec,"picture":["Common_Slot/Sp_IconSample",_record(world,str(result.get("item","")),str(result.get("source_id",""))),str(result.get("item",""))]}

func _fill_items(root: Node2D, out: Dictionary, ids: Array[String], reads: Dictionary) -> Dictionary:
	var list: Dictionary=NamedTree.locate(root,out,P_LIST+"Nd_ItemList/ListView")
	var node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null
	if not content is Node2D:return _fail("source_production_window_list_content_missing")
	_reusable={}
	var by_state: bool=_reuse_by_state
	_reuse_by_state=false
	if by_state and is_instance_valid(_item_content):
		var world: Node=_world.get_ref() if _world!=null else null
		var favorites: Dictionary=_favorites(world)
		for index: Variant in _item_rows:
			var kept: Node2D=_item_rows[index]
			if not is_instance_valid(kept) or world==null:continue
			var id: String=str(kept.get_meta("recipe_id",""))
			if int(index)>=ids.size() or ids[int(index)]!=id:continue
			if bool(kept.get_meta("row_chosen",false))==(id==_selected) and bool(kept.get_meta("row_ok",false))==_craftable(world,id) and bool(kept.get_meta("row_favorite",false))==(favorites.get(id)==true):_reusable[int(index)]=kept
	elif not _reuse_except.is_empty() and is_instance_valid(_item_content):
		for index: Variant in _item_rows:
			var kept: Node2D=_item_rows[index]
			var id: String=str(kept.get_meta("recipe_id",""))
			if is_instance_valid(kept) and not _reuse_except.has(id) and int(index)<ids.size() and ids[int(index)]==id:_reusable[int(index)]=kept
	_reuse_except=[]
	_item_ids=ids
	_item_content=content
	_item_size=NamedTree.list_size(out,_pack,TAB_LIST,"Nd_ItemList/ListView",reads)
	_item_rows={}
	var row_height: float=_item_height(reads)
	var height: float=row_height*float(ids.size())
	var scroll: ListScroll=_scrolls.items
	# Keep the selected recipe in view when it moved out of the window.
	var at: int=ids.find(_selected)
	if at>=0:
		var top: float=-row_height*float(at)
		if scroll.y<top or scroll.y>top+_item_size.y-row_height:scroll.y=top
	scroll.bind(content,_item_size.y,height)
	return _sync_item_rows(reads)

func _item_height(reads: Dictionary={}) -> float:
	return float(_tree.row_panel(ROW_ITEM,reads).size[1])

func _sync_item_rows(reads: Dictionary={}) -> Dictionary:
	if not is_instance_valid(_item_content):return {"ok":true,"pictures":0}
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_production_window_host_unavailable")
	var row_height: float=_item_height(reads)
	if row_height<=0.0:return _fail("source_production_item_geometry_missing")
	var first: int=maxi(0,floori(-(_scrolls.items as ListScroll).y/row_height)-2)
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
		var built: Dictionary=_tree.scene_of(row.member,row.spec,row_out,reads)
		if not built.get("ok",false):return built
		_tree.add_row(_item_content,row.member,built.scene,index,_item_size,0.0,reads)
		built.scene.set_meta("recipe_id",_item_ids[index])
		built.scene.set_meta("row_chosen",_item_ids[index]==_selected)
		built.scene.set_meta("row_ok",bool(row.get("ok",false)))
		built.scene.set_meta("row_favorite",row.favorite)
		_item_rows[index]=built.scene
		if _picture(built.scene,row_out,str(row.picture[0]),row.picture[1],str(row.picture[2])):pictures+=1
	return {"ok":true,"pictures":pictures,"rows":_item_rows.size(),"reused":reused}

## Two materials per Production_List_Material_Set row (_L, _R).
func _material_set_rows(world: Node, materials: Array[Dictionary]) -> Array:
	var rows: Array=[]
	for start: int in range(0,materials.size(),2):
		var spec: Dictionary={"Panel":{"input":Callable(_scrolls.materials,"input")}}
		var pictures: Array=[]
		var amounts: Dictionary={}
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
			var label: String=key+"Btn_Normal/Label_Item_Count"
			amounts[label]="선택 필요" if row.has("slot") and not bool(row.get("picked",false)) else "%s/%s" % [_number(int(row.available)),_number(int(row.required))]
			spec[label]={"role":"source_text","text":amounts[label]}
			spec[key+"Btn_Normal/Btn_Replace"]={"visible":row.has("slot"),"activate":Callable(self,"_replace").bind(str(row.get("slot","")))}
			spec[key+"Btn_Normal/Production_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
			spec[key+"Btn_Normal/Production_Slot/Sp_Select"]={"visible":false}
			spec[key+"Btn_Normal/Production_Slot/Text_Amount"]={"visible":false}
			spec[key+"Btn_Normal/Production_Slot/Btn"]={"activate":Callable(self,"_material_info").bind(at)}
			pictures.append([key+"Btn_Normal/Production_Slot/Sp_IconSample",_record(world,str(row.item),str(row.source_id),row.get("record",{})),str(row.item)])
		rows.append({"member":ROW_MATERIAL,"spec":spec,"pictures":pictures,"amounts":amounts})
	return rows

## The layout signature covers the original images, bindings and visibility.
## Only when it agrees can the live rows retain everything except the count text.
func _update_material_amounts(rows: Array) -> bool:
	var current: Dictionary=_fill_rows.get("materials",{})
	if current.size()!=rows.size():return false
	var updates: Array[Array]=[]
	for index: int in range(rows.size()):
		var scene: Node2D=current.get(index)
		var row: Dictionary=rows[index]
		if not is_instance_valid(scene):return false
		var previous: Dictionary=scene.get_meta("material_row",{})
		if previous.is_empty() or _material_layout_signature(previous)!=_material_layout_signature(row):return false
		var out: Dictionary=scene.get_meta("material_bindings",{})
		var duplicates: Dictionary=scene.get_meta("material_duplicates",{})
		for path: String in row.amounts:
			var old_text: Variant=previous.amounts.get(path)
			if row.amounts[path]==old_text:continue
			var target: Dictionary=NamedTree.locate_exact(scene,out,path,duplicates)
			if not old_text is String or not target.get("ok",false) or not is_instance_valid(target.player):return false
			updates.append([target.player,target.offset,row.amounts[path],old_text])
	for index: int in range(updates.size()):
		var step: Array=updates[index]
		if step[0].set_bound_text(step[1],step[2]).get("ok",false):continue
		for undo: int in range(index):
			var prior: Array=updates[undo]
			prior[0].set_bound_text(prior[1],prior[3])
		return false
	for index: int in range(rows.size()):
		var scene: Node2D=current[index]
		scene.set_meta("material_row",rows[index])
		scene.set_meta("row_signature",_row_signature(rows[index]))
	return true

static func _material_layout_signature(row: Dictionary) -> String:
	var spec: Dictionary=row.spec.duplicate()
	for path: String in row.amounts:
		var binding: Dictionary=spec[path].duplicate()
		binding.erase("text")
		spec[path]=binding
	return str(spec)+str(row.pictures)

static func _row_signature(row: Dictionary) -> String:
	return str(row.member)+str(row.spec)+str(row.get("pictures",[]))+str(row.get("picture",[]))

func _fill(root: Node2D, out: Dictionary, suffix: String, scroll: String, rows: Array, reads: Dictionary={}) -> Dictionary:
	var list: Dictionary=NamedTree.locate(root,out,suffix)
	var node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null
	if not content is Node2D:return _fail("source_production_window_list_content_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,TAB_LIST,suffix.trim_prefix(P_LIST),reads)
	var height: float=0.0
	var pictures: int=0
	var gap: float=4.0 if scroll=="materials" else 0.0
	var previous: Dictionary=_fill_rows.get(scroll,{})
	var kept_rows: Dictionary={}
	var created: Array[Node2D]=[]
	for index: int in range(rows.size()):
		var row: Dictionary=rows[index]
		var signature: String=_row_signature(row)
		var old: Variant=previous.get(index)
		if is_instance_valid(old) and str((old as Node).get_meta("row_signature",""))==signature:
			kept_rows[index]=old
			continue
		var row_out: Dictionary={}
		var built: Dictionary=_tree.scene_of(row.member,row.spec,row_out,reads)
		if not built.get("ok",false):
			for staged: Node2D in created:staged.free()
			return built
		created.append(built.scene)
		built.scene.set_meta("row_signature",signature)
		if row.has("amounts"):
			built.scene.set_meta("material_row",row)
			built.scene.set_meta("material_bindings",row_out)
			built.scene.set_meta("material_duplicates",_tree.duplicate_paths.duplicate())
		kept_rows[index]=built.scene
		var wanted: Array=row.get("pictures",[])
		if row.has("picture"):wanted=[row.picture]
		for picture: Array in wanted:
			if _picture(built.scene,row_out,str(picture[0]),picture[1],str(picture[2])):pictures+=1
	# All replacement rows are ready. Remove stale rows only from this live
	# list, not the previous window that the full rebuild owns.
	for index: int in previous:
		var old: Variant=previous[index]
		if is_instance_valid(old) and old.get_parent()==content and old!=kept_rows.get(index):
			content.remove_child(old)
			old.queue_free()
	for index: int in range(rows.size()):
		var scene: Node2D=kept_rows[index]
		if scene.get_parent()!=null:scene.get_parent().remove_child(scene)
		height+=_tree.add_row(content,rows[index].member,scene,index,size,gap,reads)
	_fill_rows[scroll]=kept_rows
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
	return NativeIcons.show_item(located.player,located.offset,info,_hud.get_ref())

## --- Actions -----------------------------------------------------------------

func _moved() -> bool:
	for scroll: ListScroll in _scrolls.values():
		if scroll.moved>12.0:return true
	return false

func _set_tab(value: String) -> Dictionary:
	if value==_tab:return {"ok":true}
	close_search()
	_search_picker=false
	_tab=value
	_category=""
	_selected=""
	_count=1
	_source_ids=source_tab_ids(_world.get_ref() if _world!=null else null,value)
	for scroll: ListScroll in _scrolls.values():scroll.y=0.0
	return _stage()

func search_is_open() -> bool:
	return _search!=null and _search.is_open()

func search_presentation() -> Dictionary:
	return _search.presentation() if search_is_open() else {}

func focus_search_at(point: Vector2) -> bool:
	return search_is_open() and _search.focus_input_at(point)

func close_search() -> void:
	if _search!=null:_search.close()
	_search=null

func open_search() -> Dictionary:
	var parent: Variant=_parent.get_ref() if _parent!=null else null
	if not is_open() or _tab!="search" or not _search_supported or not is_instance_valid(parent):return _fail("source_craft_search_unavailable")
	if search_is_open():return {"ok":true,"handled":true}
	if not is_instance_valid(_query_editor):
		_query_editor=QueryEdit.new()
		_query_editor.name="ProductionQueryEditor"
		_query_editor.hide()
		parent.add_child(_query_editor)
		_query_editor.text_submitted.connect(_keyboard_query)
	_query_editor.text=_query
	_search=Search.new()
	var configured: Dictionary=_search.configure_production(_pack,self,_query_editor)
	var opened: Dictionary=_search.open(parent) if configured.get("ok",false) else configured
	if not opened.get("handled",false):
		close_search()
		_notice("원본 제작 검색창을 열 수 없습니다.")
	return opened

func _keyboard_query(_text: String) -> void:
	if search_is_open():_search.apply_query()

func apply_search_query(text: String) -> Dictionary:
	if not is_open() or _tab!="search" or not search_is_open():return _fail("source_craft_search_current_owner_changed")
	close_search()
	_query=text.strip_edges()
	return _restage_lookup()

func _clear_search() -> Dictionary:
	_query=""
	_search_picker=false
	return _restage_lookup()

func _toggle_search_kind() -> Dictionary:
	_search_picker=not _search_picker
	return _stage()

func _set_search_kind(kind: String) -> Dictionary:
	_search_kind=kind
	_search_picker=false
	return _restage_lookup()

func _restage_lookup() -> Dictionary:
	_selected=""
	_count=1
	(_scrolls.items as ListScroll).y=0.0
	return _stage()

func _toggle_favorite(id: String) -> Dictionary:
	if _moved():return {"ok":true,"ignored_after_drag":true}
	var world: Node=_world.get_ref() if _world!=null else null
	if not is_instance_valid(world) or not id in _item_ids or not world.crafting.recipes.has(id):return _fail("source_production_window_recipe_missing")
	var favorites: Dictionary=_favorites(world).duplicate()
	if favorites.get(id)==true:favorites.erase(id)
	else:favorites[id]=true
	world.ui_preferences[FAVORITES_KEY]=favorites
	world._request_deferred_save()
	_reuse_except=[id]
	return _stage()

## The recipe ids of an original-table tab for this character now.
static func source_tab_ids(world: Node, tab_name: String, reader: RefCounted=null) -> Array[String]:
	if world==null or not SOURCE_TABS.has(tab_name):return []
	var registry: Dictionary=world.crafting.recipes
	if tab_name=="limited":return CraftTabs.by_main_category(registry,CraftTabs.LIMITED_ACCOUNT,reader)
	if tab_name=="server":return CraftTabs.by_main_category(registry,CraftTabs.LIMITED_SERVER,reader)
	return CraftTabs.recommended(registry,CraftTabs.context(world,reader),reader)

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
	return _change_count(1)

func _add_count(delta: int) -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_production_window_host_unavailable")
	return _change_count(clampi(_count+delta,1,_max_count(world)))

func _change_count(value: int) -> Dictionary:
	var previous: int=_count
	_count=value
	var result: Dictionary=_stage(true)
	if not result.get("ok",false):_count=previous
	return result

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
	var quote: Dictionary=world._craft_quote(_selected,_count) if _selected.begins_with("patch523:") else {}
	var rows: Array[Dictionary]=_material_rows(world,quote)
	if index<0 or index>=rows.size():return {"ok":true}
	var row: Dictionary=rows[index]
	var detail: Dictionary=_recipe_item_info(world,row)
	if detail.get("handled",false):return detail
	return _notice("%s · 보유 %s / 필요 %s" % [str(row.item).get_slice(" · 원본#",0),_number(int(row.available)),_number(int(row.required))])

func _product_info() -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null or _selected.is_empty():return _fail("source_production_window_recipe_missing")
	var detail: Dictionary=_recipe_item_info(world,Craft.recipe_of(world,_selected).get("result",{}))
	if detail.get("handled",false):return detail
	var quote: Dictionary=world._craft_quote(_selected,_count)
	return _notice("제작 가능" if quote.get("ok",false) else str(quote.get("reason","제작 불가")))

func _recipe_item_info(world: Node, row: Dictionary) -> Dictionary:
	var record: Dictionary=_record(world,str(row.get("item","")),str(row.get("source_id","")),row.get("record",{}))
	return preload("res://scripts/ui/original_ui/source_reward_item_info.gd").toggle(_hud.get_ref() if _hud!=null else null,int(record.get("source_item_class_id",0)))

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
	var execute: Callable=Callable(self,"_craft_confirmed").bind(_selected,_count)
	return {"ok":Craft.confirm_craft(hud,world,_selected,_count,execute),"confirmation_owner":"renewal_crafting.confirm_craft"}

static func _last_craft(world: Node) -> Dictionary:
	var log: Variant=world.get("crafting_log")
	return log[-1] if log is Array and not (log as Array).is_empty() and log[-1] is Dictionary else {}

func _craft_confirmed(_amount: int, recipe: String, count: int) -> void:
	var world: Node=_world.get_ref() if _world!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if world==null or hud==null or not is_open():return
	var before: Dictionary=_last_craft(world)
	hud.emit_signal("craft_requested",recipe,count)
	var entry: Dictionary=_last_craft(world)
	if is_same(before,entry) or str(entry.get("recipe_id",""))!=recipe:return
	var controller: Variant=hud.get("original_main_ui_controller")
	if is_instance_valid(controller) and controller.has_method("try_open_feature_window"):
		controller.try_open_feature_window("craft_result",[craft_result(world,entry)])

## The finished craft of the existing log as the 제작 결과 window shows it:
## an outcome recipe's label by its produced item (대성공 / 성공 / 실패).
static func craft_result(world: Node, entry: Dictionary) -> Dictionary:
	var name: String=str(entry.get("output",""))
	var label: String=""
	for outcome: Dictionary in Craft.recipe_of(world,str(entry.get("recipe_id",""))).get("outcomes",[]):
		if int(entry.get("quantity",0))>0 and str(outcome.get("item",""))==name:label=str(outcome.get("label",""))
	var record: Variant=world.call("_find_catalog_item_record",name) if world.has_method("_find_catalog_item_record") else {}
	var id: Variant=record.get("source_item_class_id",0) if record is Dictionary else 0
	return {"name":name.get_slice(" · 원본#",0),"quantity":int(entry.get("quantity",0)),"batch":int(entry.get("batch",1)),"label":label,
		"item_class_id":int(id) if typeof(id) in [TYPE_INT,TYPE_FLOAT] else 0}

func _open_gacha() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or not hud.has_method("open_gacha_craft523"):return _notice("비법서 제작 화면을 열 수 없습니다")
	if not hud.call("open_gacha_craft523"):return _fail("source_gacha_craft_window_unavailable")
	return {"ok":true,"handled":true,"routed":"open_gacha_craft523"}

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
