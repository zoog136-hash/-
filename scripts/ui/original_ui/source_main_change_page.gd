extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original Change_WinTotal frame (full frame, category tabs, title,
## close) hosting one of its own page ProjectNodes. The tabs route to the
## existing windows of the category: 변신/마법인형 list (open_catalog),
## 합성 (open_card_fusion), 컬렉션 (open_normal_card_collections) and the
## category's fourth tab (마법인형 탐험 / 용병 파견 -> their original windows; 성물
## 제단 has no TWILIGHT feature and stays hidden). Pages not shown are left
## out of the node scope.
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Presentation=preload("res://scripts/ui/source_card_presentation.gd")
const WIN_TOTAL="UI/Change/Change_WinTotal.csb"
const PAGES: Array[String]=["Change_ExploreView","Change_PrayView","Change_DispatchView","Change_DetailView","Change_DetailView_Mix","Change_CollectionView","Change_UpgradeView","ChangeQuick_All"]
## TWILIGHT grade -> original card prefab (Change_Card_List grade pairs, as
## source_main_change_window).
const GRADE_MEMBERS={"일반":"UI/Change/Change_Card_A_Common.csb","고급":"UI/Change/Change_Card_A_Rare.csb","희귀":"UI/Change/Change_Card_A_Unique.csb","영웅":"UI/Change/Change_Card_A_Legend.csb","전설":"UI/Change/Change_Card_A_Epic.csb","신화":"UI/Change/Change_Card_A_Myth.csb","유일":"UI/Change/Change_Card_A_Sole.csb"}
const GRADE_SPRITES={"일반":"Sp_Card_Common","고급":"Sp_Card_Rare","희귀":"Sp_Card_Unique","영웅":"Sp_Card_Legend","전설":"Sp_Card_Epic","신화":"Sp_Card_Myth","유일":"Sp_Card_Sole"}
## Per prefab: Panel_Root, Img_Bg, Nd_Character, Sp_Card_<grade>, CardSample, CB_Check.
const CARD_NODES={
	"UI/Change/Change_Card_A_Common.csb":{"root":276,"bg":4024,"character":1928,"frame":2520,"sample":2256,"check":1244},
	"UI/Change/Change_Card_A_Rare.csb":{"root":276,"bg":4056,"character":1932,"frame":2524,"sample":2260,"check":1244},
	"UI/Change/Change_Card_A_Unique.csb":{"root":320,"bg":3104,"character":1976,"frame":2568,"sample":2304,"check":1288},
	"UI/Change/Change_Card_A_Epic.csb":{"root":320,"bg":3100,"character":1976,"frame":2568,"sample":2304,"check":1288},
	"UI/Change/Change_Card_A_Legend.csb":{"root":320,"bg":3104,"character":1976,"frame":2568,"sample":2304,"check":1288},
	"UI/Change/Change_Card_A_Myth.csb":{"root":320,"bg":3096,"character":1972,"frame":2564,"sample":2300,"check":1288},
	"UI/Change/Change_Card_A_Sole.csb":{"root":320,"bg":3128,"character":2004,"frame":2596,"sample":2332,"check":1320},
}
## Change_WinTotal_Class pressed images per grade (Btn_Pressed/Img_*).
const GRADE_IMAGES={"일반":"Img_Common","고급":"Img_Rare","희귀":"Img_Unique","영웅":"Img_Legend","전설":"Img_Epic","신화":"Img_Myth","유일":"Img_Sole"}
const GRADE_ROW="UI/Change/Change_WinTotal_Class.csb"
const CARD_SET="UI/Change/Change_Card_Set.csb"
const CARD_SET_PANEL=120
const CARD_SET_SLOTS: Array[int]=[724,444,176]
const CARD_SET_MARGIN: float=-4.0
## Rows built beyond each edge of a virtual card grid's view.
const CARD_GRID_MARGIN: int=1
const SIDEBAR: Array[String]=["전체","유일","신화","전설","영웅","희귀","고급","일반"]
var category: String="변신"

func _root_member() -> String:
	return WIN_TOTAL

## The page this window mounts (overridden): one of PAGES.
func _page() -> String:
	return ""

## The tab shown pressed: change / mix / collection / explore / dispatch.
func _tab() -> String:
	return ""

func _frame_spec() -> Dictionary:
	var spec: Dictionary={}
	for page: String in PAGES:
		if page!=_page():spec[page]={"exclude":true}
	var doll: bool=category=="마법인형"
	var relic: bool=category=="성물"
	var names: Dictionary={"변신":"변 신","마법인형":"마법인형","성물":"성 물"}
	var tabs: Dictionary={"Change":"change","Mix":"mix","Collection":"collection"}
	if doll:tabs["Explore"]="explore"
	elif not relic:tabs["Dispatch"]="dispatch"
	for name: String in ["Change","Mix","Collection","Explore","Pray","Dispatch"]:
		var shown: bool=tabs.has(name)
		var on: bool=shown and tabs.get(name,"")==_tab()
		spec["Nd_Change_Tab/Btn_%s_On" % name]={"visible":on,"activate":Callable(self,"_tab_requested").bind(str(tabs.get(name,"")))}
		spec["Nd_Change_Tab/Btn_%s_Off" % name]={"visible":shown and not on,"activate":Callable(self,"_tab_requested").bind(str(tabs.get(name,"")))}
		spec["Nd_Change_Tab/Icon_New_%s" % name]={"visible":false}
	for state: String in ["On","Off"]:
		spec["Btn_Change_%s/Label" % state]={"role":"source_text","text":str(names.get(category,category))}
		spec["Btn_Collection_%s/Label" % state]={"role":"source_text","text":("인형" if doll else category)+" 컬렉션"}
	# Btn_Move ("Text Label" placeholder) names no TWILIGHT destination.
	spec["Nd_Change_Tab/Btn_Move"]={"visible":false}
	spec["Nd_TopMenu/Label_Title"]={"role":"source_text","text":str(names.get(category,category))}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	return spec

func _tab_requested(tab: String) -> Dictionary:
	if tab==_tab():return {"ok":true,"same_tab":true}
	var target: String=category
	match tab:
		"change":
			if target in ["변신","마법인형"]:return _route("open_catalog",[target])
			return _route("open_catalog",[target])
		"mix":return _route("open_card_fusion",[target])
		"collection":return _route("open_normal_card_collections",[target,""])
		"dispatch":return _route("open_card_dispatch")
		"explore":return _route("open_doll_explore")
	return {"ok":false}

## One original Change_Card_A_<grade> card: its own picture through
## SourceCardPresentation (DisplayBaseAssetID), checkbox selection.
func _card_row(record: Dictionary, selected: bool, activate: Callable) -> Dictionary:
	var grade: String=str(record.get("grade",""))
	if not GRADE_MEMBERS.has(grade):return {}
	var spec: Dictionary={"Panel_Root/CB_Check":{"role":"checkbox","selected":selected,"activate":activate},
		"Nd_Character/CardSample":{"role":"source_asset_slot","visible":false},
		"Nd_Character/CardSample_A":{"exclude":true},"Panel_Root/Panel_Fx":{"exclude":true},
		"Panel_Root/Sp_Lock":{"exclude":true},"Panel_Root/Nd_Attribute":{"exclude":true}}
	return {"member":GRADE_MEMBERS[grade],"spec":spec,"record":record}

## Shows the card picture in a built Change_Card_A scene.
func _card_picture(scene: Node2D, out: Dictionary, record: Dictionary) -> bool:
	var located: Dictionary=_locate(scene,out,"Nd_Character/CardSample")
	if not located.get("ok",false):return false
	var shown: Dictionary=Presentation.detail(record,true,false)
	var owner: Dictionary={"ok":shown.get("status","")=="original" and shown.get("texture") is Texture2D}
	if not owner.ok:return false
	owner["texture"]=shown.texture
	owner["provenance"]=shown.get("provenance",{}).duplicate(true)
	owner["role"]=str(shown.get("role",""))
	return _show_picture(located.player,located.offset,owner)

## One Change_WinTotal_Class sidebar row (grade, count text).
func _grade_row(grade: String, count_text: String, on: bool, activate: Callable) -> Dictionary:
	# The client spaces two-letter grade names ("등 급").
	var label: String=grade.substr(0,1)+" "+grade.substr(1,1) if grade.length()==2 else grade
	var spec: Dictionary={"Panel/Btn_Normal":{"visible":not on,"activate":activate},"Panel/Btn_Pressed":{"visible":on,"activate":activate},
		"Btn_Normal/Label_Normal":{"role":"source_text","text":label},"Btn_Normal/Label_Normal_Num":{"role":"source_text","text":count_text},
		"Btn_Pressed/Label_Pressed":{"role":"source_text","text":label},"Btn_Pressed/Label_Pressed_Num":{"role":"source_text","text":count_text},
		"Panel/Icon_New":{"visible":false},"Btn_Pressed/Img_Event":{"visible":false}}
	for name: String in GRADE_IMAGES:spec["Btn_Pressed/"+str(GRADE_IMAGES[name])]={"visible":name==grade}
	return {"member":GRADE_ROW,"spec":spec}

## A list fill whose ListView node is absent from this pack's tree stays
## empty (the window still opens); `missing` names the suffix.
static func _optional(result: Dictionary) -> Dictionary:
	if result.get("ok",false) or str(result.get("error",""))!="source_window_node_missing":return result
	var scenes: Array[Node2D]=[]
	var outs: Array[Dictionary]=[]
	return {"ok":true,"rows":0,"scenes":scenes,"outs":outs,"missing":str(result.get("suffix",""))}

func _owned(id: String, member_category: String="") -> bool:
	var owner: Object=hud()
	if owner==null:return false
	return owner.get("card_collection_state").get("owned",{}).get(member_category if not member_category.is_empty() else category,{}).get(id,false)==true

func _spare(id: String, member_category: String="") -> int:
	var owner: Object=hud()
	if owner==null:return 0
	return maxi(0,int(owner.get("card_collection_state").get("spare",{}).get(member_category if not member_category.is_empty() else category,{}).get(id,0)))

## Cards three per row the way Change_Card_Set places them (its ProjectNode
## slots inside the centred 360x150 row panel, ListView itemMargin -4), in
## the card ListView at `suffix`. The list is virtual: every card keeps its
## place in the scroll range, but only the rows in view (plus
## CARD_GRID_MARGIN rows each side) are built; scrolling builds the rows
## that come into view and frees those that left. `decorate`
## (scene, out, card) -> bool runs once per built card (its picture).
## Returns {ok, cards, built, pictures, scenes, outs} (scenes/outs: the
## cards built now, in card order; `first` is the first built index).
func _fill_card_grid(root: Node2D, out: Dictionary, suffix: String, cards: Array, decorate: Callable=Callable(), margin: float=CARD_SET_MARGIN) -> Dictionary:
	var list: Dictionary=_list(root,out,suffix)
	if not list.get("ok",false):return list
	var tree: Dictionary=_pack.scene(CARD_SET).get("nodeTree",{})
	var panel: Dictionary=Scene._node_at_offset(tree,CARD_SET_PANEL).get("options",{}).get("widgetOptions",{})
	var panel_size: Array=panel.get("size",[360,150])
	var slots: Array[Vector2]=[]
	for offset: int in CARD_SET_SLOTS:
		var options: Dictionary=Scene._node_at_offset(tree,offset).get("options",{})
		var position: Array=options.get("nodeOptions",options.get("widgetOptions",{})).get("position",[0,0])
		slots.append(Vector2(float(position[0]),float(position[1])))
	var size: Vector2=list.size
	var row_height: float=float(panel_size[1])
	var rows: int=ceili(float(cards.size())/3.0)
	var pitch: float=row_height+margin
	var grid: Dictionary={"cards":cards,"decorate":decorate,"slots":slots,"size":size,"row_height":row_height,"pitch":pitch,
		"row_x":(size.x-float(panel_size[0]))*0.5,"key":str(list.key),"built":{},"pictures":0,"builds":0}
	var key: String=str(list.key)
	_scrolls[key]={"content":list.content,"min":minf(0.0,size.y-(float(rows)*pitch-margin)),"value":0.0,"grid":grid}
	var synced: Dictionary=_sync_card_grid(key)
	if not synced.get("ok",false):return synced
	var scenes: Array[Node2D]=[]
	var outs: Array[Dictionary]=[]
	var indices: Array=(grid.built as Dictionary).keys()
	indices.sort()
	for index: Variant in indices:
		scenes.append(grid.built[index].scene)
		outs.append(grid.built[index].out)
	return {"ok":true,"cards":cards.size(),"built":indices.size(),"pictures":int(grid.pictures),"first":int(indices[0]) if not indices.is_empty() else 0,"scenes":scenes,"outs":outs}

## The card rows of grid `key` to keep built at its scroll value.
func card_grid_rows(key: String) -> Vector2i:
	var state: Dictionary=_scrolls.get(key,{})
	var grid: Dictionary=state.get("grid",{})
	if grid.is_empty():return Vector2i(0,-1)
	var pitch: float=grid.pitch
	var rows: int=ceili(float((grid.cards as Array).size())/3.0)
	var top: float=-float(state.get("value",0.0))
	var first: int=maxi(0,floori(top/pitch)-CARD_GRID_MARGIN)
	var last: int=mini(rows-1,ceili((top+(grid.size as Vector2).y)/pitch)+CARD_GRID_MARGIN)
	return Vector2i(first,last)

func _scrolled(key: String) -> void:
	if _scrolls.get(key,{}).has("grid"):_sync_card_grid(key)

## Builds the cards of grid `key` that came into view; frees those that left.
func _sync_card_grid(key: String) -> Dictionary:
	var state: Dictionary=_scrolls.get(key,{})
	var grid: Dictionary=state.get("grid",{})
	if grid.is_empty() or not is_instance_valid(state.get("content")):return {"ok":true}
	var content: Node2D=state.content
	var rows: Vector2i=card_grid_rows(key)
	var built: Dictionary=grid.built
	for index: Variant in built.keys():
		var row: int=int(index)/3
		if row>=rows.x and row<=rows.y:continue
		var old: Variant=built[index].scene
		if is_instance_valid(old):
			old.hide()
			old.queue_free()
		built.erase(index)
	var cards: Array=grid.cards
	for row: int in range(rows.x,rows.y+1):
		for column: int in 3:
			var index: int=row*3+column
			if index>=cards.size() or built.has(index):continue
			var card_out: Dictionary={}
			var made: Dictionary=_scene_of(str(cards[index].member),cards[index].spec,card_out,key)
			if not made.get("ok",false):return made
			var top: float=(grid.size as Vector2).y-float(row)*float(grid.pitch)
			var slot: Vector2=grid.slots[column]
			made.scene.position=Vector2(float(grid.row_x)+slot.x,-(top-float(grid.row_height)+slot.y))
			content.add_child(made.scene)
			built[index]={"scene":made.scene,"out":card_out}
			grid.builds=int(grid.builds)+1
			if (grid.decorate as Callable).is_valid() and bool((grid.decorate as Callable).call(made.scene,card_out,cards[index])):grid.pictures=int(grid.pictures)+1
	return {"ok":true}
