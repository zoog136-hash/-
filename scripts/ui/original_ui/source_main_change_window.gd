extends RefCounted
## The original 523 polymorph window: Change_WinTotal (full frame, tabs,
## title, close) with its Change_DetailView page. Every owned card of the
## category is one original Change_Card_A_<grade> card laid out three per row
## the way Change_Card_Set places them, in the page's card ListView. Each card
## shows its original card picture (BuffCard DisplayBaseAssetID through
## SourceCardPresentation); the detail side shows the selected card's
## artwork, name, grade and options. Tapping the selected card again or
## the original 즉시 변신 button runs the existing catalog equip
## (World._equip_catalog), so every rule and save stays with the game.
## The same window serves 마법인형 and 성물 (the client reuses Change_WinTotal;
## Change_WinTotal names its 성 물 tab). 성물 cards have no BuffCard attack
## type, so their page has no 모든 유형 popup.
## The page's left grade list is Change_WinTotal_Class (전체 + each grade,
## owned / catalog count), 모든 유형 opens Common_ButtonSet_Type (the card's
## original BuffCard.AttackTypeID; the labels are the popup's own), the
## search bar opens ItemBook_Popup_Keypad with a window-owned editor (card
## name contains the query, applied on 검색), 초기화 clears the three filters
## and 각 성 asks the existing option awakening (option_awakening_open_requested,
## the same request as the catalog's 각성 tab).
## 성급 강화 (Btn_Transcend) shows for a card with an original star-enchant
## group (BuffCardStarEnchantGroup: 해방된 할파스 in 523) and opens the
## existing star-enchant owner (native_halphas_star_enchant, its view);
## BuffCardTranscendence rows have no cost or rule table, so other cards keep
## the button hidden as authored for them.
## Not connected (no TWILIGHT feature): 변신 등록 (quick registration), the keypad's result list, 도펠겡어/이름 옵션,
## 사용 가능 기간 and the 합성 시도 보상 gauges.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const StageReads=preload("res://scripts/ui/original_ui/source_stage_tree_reads.gd")
const Presentation=preload("res://scripts/ui/source_card_presentation.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const ROOT="UI/Change/Change_WinTotal.csb"
const DETAIL="UI/Change/Change_DetailView.csb"
const INFO="UI/Change/Change_Upgrade_Info_Swap.csb"
const SET="UI/Change/Change_Card_Set.csb"
const CARD_DEFINITIONS=preload("res://scripts/lineagem_base508.gd")
const OPTION_ROW="UI/Change/Change_CardGradeOption_Text.csb"
const GRADE_ROW="UI/Change/Change_WinTotal_Class.csb"
const TYPE_SET="UI/CommonUi/Common_ButtonSet_Type.csb"
const KEYPAD="UI/ItemBook/ItemBook_Popup_Keypad.csb"
## Change_WinTotal nodes.
const FRAME=27316
const CHANGE_ON=25140
const CHANGE_OFF=23736
const CHANGE_LABELS: Array[int]=[25596,23788]
const COLLECTION_LABELS: Array[int]=[18312,16480]
const MIX_ON=21464
const MIX_OFF=20064
const COLLECTION_ON=17856
const COLLECTION_OFF=16428
const EXPLORE_ON=12820
const EXPLORE_OFF=11392
const TITLE=3328
const CLOSE=2556
const DETAIL_PROJECT=1496
## Change_DetailView nodes.
const CARD_PANEL_BG=51440
const CARD_PANEL_DECO=50996
const DETAIL_BG=39548
const DETAIL_FX_BG=39200
const SAMPLE_PANEL=37708
const SAMPLE=38328
const INFO_PROJECT=37432
const CHANGE_GROUP=26468
const APPLY=26524
const BUTTON_GROUP=19380
const GROUP_LINES: Array[int]=[25964,25576]
const COLLECTION_BUTTON=21388
const TAB_BG=14276
const LIST=13180
const NOTICE=12616
const NOTICE_TEXT=12668
## Change_DetailView: grade list, search bar, popups, 각성.
const CLASS_LIST=13828
const RESET=8664
const RESET_STATES: Array[int]=[9280,8716]
const SEARCH=5912
const SEARCH_TEXT=7216
const SEARCH_STATES: Array[int]=[6600,5972]
const SORT=1868
const SORT_STATES: Array[int]=[2828,1920]
const SORT_LABELS: Array[int]=[3216,2308]
## Btn_Sort2 (the 전체 sort button) and its Text_Sort: 전체 (the list's own
## order) / 등급순 (highest grade first) / 이름순. TWILIGHT 근사(근거 약함):
## the tables name no options (docs/original_ui523_approx.md).
const ORDER_BUTTON=4456
const ORDER_TEXT=4844
const ORDERS: Array[String]=["전체","등급순","이름순"]
## Highest first, in the original grade sidebar's order (SIDEBAR: 유일 above 신화).
const GRADE_RANK={"유일":0,"신화":1,"전설":2,"영웅":3,"희귀":4,"고급":5,"일반":6}
const POPUP_CLOSE=760
const TYPE_PROJECT=488
const KEYPAD_PROJECT=1460
const AWAKEN=23432
## 성급 강화: Btn_Transcend and its glow, label and icon (its particle stays out).
const TRANSCEND=14884
const TRANSCEND_PARTS: Array[int]=[15972,15620,15268]
const TRANSCEND_LABEL=15620
const StarEnchant=preload("res://scripts/cards/native_halphas_star_enchant.gd")
const AWAKEN_STATES: Array[int]=[24088,23484]
## Change_WinTotal_Class row nodes.
const ROW_PANEL=176
const ROW_NORMAL=5360
const ROW_NORMAL_TEXT: Array[int]=[5776,5416]
const ROW_PRESSED=676
const ROW_PRESSED_TEXT: Array[int]=[1120,760]
const ROW_EVENT=2672
const ROW_NEW=232
## TWILIGHT grade -> Btn_Pressed/Img_<grade> (the Change_Card_List pairs).
const ROW_IMAGES={"일반":1472,"고급":1904,"희귀":2288,"영웅":3108,"전설":3492,"신화":3876,"유일":4260}
const SIDEBAR: Array[String]=["전체","유일","신화","전설","영웅","희귀","고급","일반"]
## Common_ButtonSet_Type: per category its set node, background and buttons
## [Off, On, On label, BuffCardAttackType.ID] (0 = 모든 유형, no filter).
const TYPE_SETS={
	"변신":{"set":19308,"bg":45084,"buttons":[[42908,41052,41452,0],[39236,37420,37824,51],[35612,33804,34200,41],[31988,30176,30580,31],[28380,26584,26980,21],[24788,22996,23392,11],[21204,19416,19808,1]]},
	"마법인형":{"set":616,"bg":18764,"buttons":[[16948,15140,15540,0],[13324,11508,11912,51],[9692,7880,8284,31],[6084,4288,4684,21],[2496,708,1100,1]]},
}
## ItemBook_Popup_Keypad input bar (the Inventory_Popup_Keypad nodes): its
## result list is not mounted.
const KEYPAD_NODES: Array[int]=[8316,7940,7556,5072,6444,6020,5524,5132,2808,3996,3604,3216,2868,2424,2040,1472,364,412]
const KEYPAD_FIELD=1472
const KEYPAD_SEARCH=5072
const KEYPAD_CLOSE=2808
const KEYPAD_CANCEL=364
const LIST_SIZE:=Vector2(498,425)
const ROW_MARGIN: float=-4.0
const SET_PROJECTS: Array[int]=[724,444,176]
const SET_PANEL=120
## Change_Upgrade_Info_Swap nodes: [name, grade, title, option list, decor].
const INFO_CARD={"root":11952,"name":14400,"grade":14028,"title":13240,"list":12028,"decor":[13628,12792,12460]}
const INFO_DOLL={"root":5380,"name":11448,"grade":11120,"title":9064,"list":9416,"decor":[10180,9848,8308]}
const OPTION_PANEL=120
const OPTION_DESC=652
const OPTION_VALUE=172
const OPTION_HEIGHT: float=18.0
## TWILIGHT grade -> original card prefab. The 일반/고급/희귀/영웅/전설
## pairs are the client's own (Change_Card_List: Node_Common 일 반, Node_Rare
## 고 급, Node_Unique 희 귀, Node_Legend 영 웅, Node_Epic 전 설).
const GRADE_MEMBERS={"일반":"UI/Change/Change_Card_A_Common.csb","고급":"UI/Change/Change_Card_A_Rare.csb","희귀":"UI/Change/Change_Card_A_Unique.csb","영웅":"UI/Change/Change_Card_A_Legend.csb","전설":"UI/Change/Change_Card_A_Epic.csb","신화":"UI/Change/Change_Card_A_Myth.csb","유일":"UI/Change/Change_Card_A_Sole.csb"}
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
const MAX_CARDS: int=150
signal closed
var _pack: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _detail: Node2D
var _info: Node2D
var _content: Node2D
var _option_content: Node2D
var _option_scroll_min: float=0.0
var _category: String="변신"
var _cards: Array[Dictionary]=[]
# Positions are the keys so duplicate source IDs do not hide a card's scene.
var _card_scenes: Dictionary={}
var _card_mount_failed: Dictionary={}
var _card_geometry: Dictionary={}
var _card_range:=Vector2i(-1,-1)
var _card_refresh_queued: bool=false
var _card_hold_indices: Array[int]=[]
var _selected: String=""
var _scroll: float=0.0
var _scroll_min: float=0.0
var _drag: bool=false
var _moved: float=0.0
var _grade: String="전체"
var _type: int=0
var _order: int=0
var _query: String=""
var _class_content: Node2D
var _class_scroll: float=0.0
var _class_min: float=0.0
var _class_drag: bool=false
var _editor: LineEdit
var _field: Variant
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	# The grade list, type popup and keypad are optional (an older UI add-on
	# without their members still opens the card list).
	var members: Array[String]=[ROOT,DETAIL,INFO,SET,OPTION_ROW]
	for member: String in GRADE_MEMBERS.values():members.append(member)
	for member: String in members:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_change_window_member_missing","member":member}
	_pack=pack
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func category() -> String:
	return _category

func open(parent: Node, category_name: String) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_change_window_host_unavailable")
	if category_name not in ["변신","마법인형","성물"]:return _fail("source_change_window_category_unsupported")
	_parent=weakref(parent)
	if category_name!=_category:
		_selected=""
		_scroll=0.0
		_class_scroll=0.0
		_grade="전체"
		_type=0
		_query=""
	_category=category_name
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	_release_field()
	var previous: Node2D=_scene
	_scene=null
	_detail=null
	_info=null
	_content=null
	_option_content=null
	_class_content=null
	_reset_card_rows()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

## Owned cards of the category, highest grade first (catalog order within a grade).
func _owned_cards() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return result
	var owned: Dictionary=hud.get("card_collection_state").get("owned",{}).get(_category,{})
	var by_grade: Dictionary={}
	for raw: Variant in hud.get("catalog_data").get(_category,[]):
		if not raw is Dictionary or owned.get(Cards.card_id(raw),false)!=true:continue
		var grade: String=str(raw.get("grade",""))
		if not GRADE_MEMBERS.has(grade):continue
		if not by_grade.has(grade):by_grade[grade]=[]
		by_grade[grade].append(raw)
	var grades: Array[String]=Cards.GRADES.duplicate()
	grades.reverse()
	for grade: String in grades:
		for record: Dictionary in by_grade.get(grade,[]):result.append(record)
	return result

## The card's original BuffCard.AttackTypeID (0 when the record has none).
static func attack_type(record: Dictionary) -> int:
	var original: Variant=record.get("source_original_card")
	return int(original.get("AttackTypeID",0)) if original is Dictionary else 0

## True when `record` passes the type filter and the search query.
func _matches(record: Dictionary) -> bool:
	if _type!=0 and attack_type(record)!=_type:return false
	return _query.is_empty() or str(record.get("name","")).containsn(_query)

## Owned cards shown in the list: grade, type and query filters (at most MAX_CARDS).
func _filtered(owned: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for record: Dictionary in owned:
		if _grade!="전체" and str(record.get("grade",""))!=_grade:continue
		if not _matches(record):continue
		result.append(record)
	result=ordered(result,_order)
	if result.size()>MAX_CARDS:result.resize(MAX_CARDS)
	return result

## The list in sort order `order` (stable: ties keep the list's order).
static func ordered(records: Array[Dictionary], order: int) -> Array[Dictionary]:
	if order==0:return records
	var keyed: Array=[]
	for index: int in range(records.size()):
		var record: Dictionary=records[index]
		keyed.append([int(GRADE_RANK.get(str(record.get("grade","")),9)) if order==1 else 0,str(record.get("name","")) if order==2 else "",index])
	keyed.sort()
	var result: Array[Dictionary]=[]
	for entry: Array in keyed:result.append(records[int(entry[2])])
	return result

func _cycle_order() -> Dictionary:
	_close_popups()
	_order=(_order+1)%ORDERS.size()
	_scroll=0.0
	return _stage()

## Sidebar counts per grade: [owned shown, catalog total] under type/query.
func _grade_counts(owned: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary={}
	for grade: String in SIDEBAR:counts[grade]=[0,0]
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud!=null:
		for raw: Variant in hud.get("catalog_data").get(_category,[]):
			if not raw is Dictionary or not GRADE_MEMBERS.has(str(raw.get("grade",""))) or not _matches(raw):continue
			counts["전체"][1]+=1
			counts[str(raw.grade)][1]+=1
	for record: Dictionary in owned:
		if not _matches(record):continue
		counts["전체"][0]+=1
		counts[str(record.grade)][0]+=1
	return counts

func _filtering() -> bool:
	return _grade!="전체" or _type!=0 or not _query.is_empty()

func _available(member: String) -> bool:
	return _pack!=null and _pack.manifest.get("scenes",{}).has(member)

func _equipped_id() -> String:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return ""
	var equipped: Variant=hud.get("character_state").get("equipped",{}).get(_category,{})
	return Cards.card_id(equipped) if equipped is Dictionary and not equipped.is_empty() else ""

func _record(id: String) -> Dictionary:
	for record: Dictionary in _cards:
		if Cards.card_id(record)==id:return record
	return {}

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if parent==null or hud==null:return _fail("source_change_window_host_unavailable")
	_release_field()
	var previous_cards: Array[Dictionary]=_cards
	var previous_selection: String=_selected
	var owned: Array[Dictionary]=_owned_cards()
	_cards=_filtered(owned)
	var equipped: String=_equipped_id()
	if _record(_selected).is_empty():
		_selected=equipped if not _record(equipped).is_empty() else (Cards.card_id(_cards[0]) if not _cards.is_empty() else "")
	var doll: bool=_category=="마법인형"
	var bindings: Dictionary={CLOSE:{"role":"button","activate":Callable(self,"_close_requested")},
		CHANGE_ON:{"role":"button","visible":true,"activate":Callable(self,"_ignore")},
		CHANGE_OFF:{"role":"button","visible":false,"activate":Callable(self,"_ignore")},
		MIX_ON:{"role":"button","visible":false,"activate":Callable(self,"_fusion_requested")},
		MIX_OFF:{"role":"button","visible":true,"activate":Callable(self,"_fusion_requested")},
		COLLECTION_ON:{"role":"button","visible":false,"activate":Callable(self,"_collection_requested")},
		COLLECTION_OFF:{"role":"button","visible":true,"activate":Callable(self,"_collection_requested")}}
	var roots: Array[int]=[FRAME,CHANGE_ON,CHANGE_OFF,MIX_ON,MIX_OFF,COLLECTION_ON,COLLECTION_OFF,TITLE,CLOSE,DETAIL_PROJECT]
	if doll:
		# The 마법인형 window keeps the client's 마법인형 탐험 tab.
		roots.append_array([EXPLORE_ON,EXPLORE_OFF])
		bindings[EXPLORE_ON]={"role":"button","visible":false,"activate":Callable(self,"_explore_requested")}
		bindings[EXPLORE_OFF]={"role":"button","visible":true,"activate":Callable(self,"_explore_requested")}
		bindings[TITLE]={"role":"source_text","text":"마법인형"}
		for offset: int in CHANGE_LABELS:bindings[offset]={"role":"source_text","text":"마법인형"}
		for offset: int in COLLECTION_LABELS:bindings[offset]={"role":"source_text","text":"마법인형 컬렉션"}
	elif _category=="성물":
		bindings[TITLE]={"role":"source_text","text":"성 물"}
		for offset: int in CHANGE_LABELS:bindings[offset]={"role":"source_text","text":"성 물"}
		for offset: int in COLLECTION_LABELS:bindings[offset]={"role":"source_text","text":"성물 컬렉션"}
	var reads: Dictionary={}
	var page: Dictionary=_detail_bindings(equipped,parent,reads)
	bindings[DETAIL_PROJECT]={"role":"project","visible":true,"source_node_offsets":page.scope,"bindings":page.bindings}
	var root_scope: Array[int]=_subtree(ROOT,roots,reads)
	_consume_touch(ROOT,root_scope,bindings,reads)
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,ROOT,root_scope,bindings)
	if not result.get("ok",false):return _stage_failure(next,result,previous_cards,previous_selection)
	var detail: Dictionary=next.project_player([DETAIL_PROJECT])
	if not detail.get("ok",false):return _stage_failure(next,detail,previous_cards,previous_selection)
	var info: Dictionary=detail.player.project_player([INFO_PROJECT])
	if not info.get("ok",false):return _stage_failure(next,info,previous_cards,previous_selection)
	var list_node: Variant=detail.player.get("source_nodes").get(LIST)
	var content: Variant=(list_node.get_meta("source_list_content") if list_node.has_meta("source_list_content") else null) if is_instance_valid(list_node) else null
	var info_list: Variant=info.player.get("source_nodes").get(int((INFO_DOLL if doll else INFO_CARD).list))
	var option_content: Variant=(info_list.get_meta("source_list_content") if info_list.has_meta("source_list_content") else null) if is_instance_valid(info_list) else null
	if not content is Node2D or not option_content is Node2D:return _stage_failure(next,_fail("source_change_window_list_content_missing"),previous_cards,previous_selection)
	var geometry: Dictionary=_set_geometry()
	var class_rows: Dictionary=_fill_classes(detail.player,owned,reads)
	if not class_rows.get("ok",false):return _stage_failure(next,class_rows,previous_cards,previous_selection)
	var previous: Node2D=_scene
	# Change_WinTotal is laid out on the design centre (600, 337.5).
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_detail=detail.player
	_info=info.player
	_content=content
	_option_content=option_content
	_reset_card_rows()
	_card_geometry=geometry
	_class_content=class_rows.get("content")
	_class_min=float(class_rows.get("min",0.0))
	_class_scroll=clampf(_class_scroll,_class_min,0.0)
	if is_instance_valid(_class_content):_class_content.position.y=_class_scroll
	var rows: int=ceili(float(_cards.size())/3.0)
	_scroll_min=minf(0.0,LIST_SIZE.y-(float(rows)*(geometry.row_height+ROW_MARGIN)-ROW_MARGIN))
	_scroll=clampf(_scroll,_scroll_min,0.0)
	content.position.y=_scroll
	var pictures: int=_refresh_visible_cards()
	var shown: Dictionary=_show_selected()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"category":_category,"cards":_cards.size(),"owned":owned.size(),"card_pictures":pictures,"mounted_cards":_card_scenes.size(),"selected":_selected,"equipped":equipped,"detail":shown,
		"grade":_grade,"type":_type,"query":_query,"grade_rows":int(class_rows.get("rows",0))}
	return last_result

func _stage_failure(next: Node2D, result: Dictionary, previous_cards: Array[Dictionary], previous_selection: String) -> Dictionary:
	next.free()
	_cards=previous_cards
	_selected=previous_selection
	last_result=result
	return result

func _reset_card_rows() -> void:
	_card_scenes.clear()
	_card_mount_failed.clear()
	_card_geometry.clear()
	_card_range=Vector2i(-1,-1)
	_card_refresh_queued=false
	_card_hold_indices.clear()
	_drag=false

## Half-open card indices. Keep one overscan row on either side, and include
## overlapping row edges from the original negative margin.
static func visible_card_range(count: int, scroll: float, row_height: float) -> Vector2i:
	var pitch: float=row_height+ROW_MARGIN
	if count<=0 or pitch<=0.0:return Vector2i.ZERO
	var offset: float=absf(scroll)
	var first: int=maxi(0,floori((offset-row_height)/pitch))
	var end: int=ceili((offset+LIST_SIZE.y)/pitch)+1
	return Vector2i(mini(first*3,count),mini(end*3,count))

func _refresh_visible_cards() -> int:
	if not is_instance_valid(_content) or _card_geometry.is_empty():return 0
	var window: Vector2i=visible_card_range(_cards.size(),_scroll,_card_geometry.row_height)
	if window!=_card_range:
		_card_range=window
		for index: int in _card_scenes.keys():
			if (index>=window.x and index<window.y) or _card_hold_indices.has(index):continue
			var evicted: Node2D=_card_scenes[index]
			# Scroll refreshes are deferred outside the GUI input callback.
			_content.remove_child(evicted)
			evicted.queue_free()
			_card_scenes.erase(index)
		for index: int in range(window.x,window.y):
			if _card_scenes.has(index) or _card_mount_failed.has(index):continue
			var card: Dictionary=_card(_cards[index])
			if not card.get("ok",false):
				_card_mount_failed[index]=true
				continue
			var row: int=index/3
			var slot: Vector2=_card_geometry.slots[index%3]
			var row_height: float=_card_geometry.row_height
			var top: float=LIST_SIZE.y-float(row)*(row_height+ROW_MARGIN)
			var scene: Node2D=card.scene
			scene.position=Vector2(_card_geometry.row_x+slot.x,-(top-row_height+slot.y))
			_content.add_child(scene)
			_card_scenes[index]=scene
		# Negative row margin can overlap adjacent panels. Keep original draw order
		# even when scrolling upwards adds a new row before retained children.
		var indices: Array=_card_scenes.keys()
		indices.sort()
		for i: int in range(indices.size()):
			_content.move_child(_card_scenes[indices[i]],i)
	var pictures: int=0
	for scene: Node2D in _card_scenes.values():
		if scene.get_meta("source_change_card",{}).get("picture",false):pictures+=1
	return pictures

func _refresh_scrolled_cards(expected_content: Node2D) -> void:
	if not is_instance_valid(expected_content) or expected_content!=_content:return
	_card_refresh_queued=false
	var pictures: int=_refresh_visible_cards()
	if last_result.get("ok",false):
		last_result["card_pictures"]=pictures
		last_result["mounted_cards"]=_card_scenes.size()

## Row panel left edge and card positions from Change_Card_Set itself.
func _set_geometry() -> Dictionary:
	var tree: Dictionary=_pack.scene(SET).get("nodeTree",{})
	var panel: Dictionary=Scene._node_at_offset(tree,SET_PANEL).get("options",{}).get("widgetOptions",{})
	var size: Array=panel.get("size",[360,150])
	var slots: Array[Vector2]=[]
	for offset: int in SET_PROJECTS:
		var node: Dictionary=Scene._node_at_offset(tree,offset)
		var options: Dictionary=node.get("options",{})
		var widget: Dictionary=options.get("nodeOptions",options.get("widgetOptions",{}))
		var position: Array=widget.get("position",[0,0])
		slots.append(Vector2(float(position[0]),float(position[1])))
	# The ListView centres its items (Align_HorizontalCenter).
	return {"row_x":(LIST_SIZE.x-float(size[0]))*0.5,"row_height":float(size[1]),"slots":slots}

func _detail_bindings(equipped: String, host: Node=null, reads: Dictionary={}) -> Dictionary:
	var doll: bool=_category=="마법인형"
	var info_nodes: Dictionary=INFO_DOLL if doll else INFO_CARD
	var selected: Dictionary=_record(_selected)
	var applied: bool=not _selected.is_empty() and _selected==equipped
	var bindings: Dictionary={LIST:{"role":"source_list","row_offsets":[],"input":Callable(self,"_list_input")},
		NOTICE:{"visible":_cards.is_empty()},NOTICE_TEXT:{"role":"static_source_text"},
		SAMPLE:{"role":"source_asset_slot","visible":false},
		APPLY:{"role":"button","displaystate":not selected.is_empty() and not applied,"activate":Callable(self,"_apply_selected")},
		COLLECTION_BUTTON:{"role":"button","activate":Callable(self,"_collection_requested")}}
	var scope: Array[int]=[CARD_PANEL_BG,CARD_PANEL_DECO,DETAIL_BG,DETAIL_FX_BG,SAMPLE_PANEL,SAMPLE,APPLY,TAB_BG,LIST,NOTICE,NOTICE_TEXT]
	scope.append_array(GROUP_LINES)
	scope.append_array(_subtree(DETAIL,[COLLECTION_BUTTON],reads))
	# 각 성: the existing option awakening of the selected card.
	var can_awaken: bool=not selected.is_empty()
	scope.append_array(_subtree(DETAIL,[AWAKEN],reads))
	bindings[AWAKEN]={"role":"button","displaystate":can_awaken,"activate":Callable(self,"_awaken_requested")}
	bindings[AWAKEN_STATES[0]]={"visible":can_awaken}
	bindings[AWAKEN_STATES[1]]={"visible":not can_awaken}
	if star_target(_world_node(),_category,_selected):
		scope.append(TRANSCEND)
		scope.append_array(TRANSCEND_PARTS)
		bindings[TRANSCEND]={"role":"button","activate":Callable(self,"_star_requested")}
		bindings[TRANSCEND_LABEL]={"role":"static_source_text"}
	# Grade list (Change_WinTotal_Class rows are added after the mount).
	if _available(GRADE_ROW):
		scope.append(CLASS_LIST)
		bindings[CLASS_LIST]={"role":"source_list","row_offsets":[],"input":Callable(self,"_class_input")}
	# 초기화 clears the grade, type and search filters.
	var filtering: bool=_filtering()
	scope.append_array(_subtree(DETAIL,[RESET],reads))
	bindings[RESET]={"role":"button","displaystate":filtering,"activate":Callable(self,"_reset_filters")}
	bindings[RESET_STATES[0]]={"visible":filtering}
	bindings[RESET_STATES[1]]={"visible":not filtering}
	scope.append_array(_subtree(DETAIL,[ORDER_BUTTON],reads))
	bindings[ORDER_BUTTON]={"role":"button","activate":Callable(self,"_cycle_order")}
	bindings[ORDER_TEXT]={"role":"source_text","text":ORDERS[_order]}
	# 모든 유형: Common_ButtonSet_Type over the full-page Btn_Close.
	var type_set: Dictionary=TYPE_SETS.get(_category,{})
	if _available(TYPE_SET) and not type_set.is_empty():
		scope.append_array(_subtree(DETAIL,[SORT],reads))
		scope.append_array([POPUP_CLOSE,TYPE_PROJECT])
		var label: String=_type_label(_type)
		bindings[SORT]={"role":"button","activate":Callable(self,"_toggle_type_popup")}
		bindings[SORT_STATES[0]]={"visible":true}
		bindings[SORT_STATES[1]]={"visible":false}
		for offset: int in SORT_LABELS:bindings[offset]={"role":"source_text","text":label}
		bindings[POPUP_CLOSE]={"role":"button","visible":false,"activate":Callable(self,"_close_popups")}
		var type_scope: Array[int]=_subtree(TYPE_SET,[int(type_set.set)],reads)
		var type_bindings: Dictionary={int(type_set.set):{"visible":true},int(type_set.bg):{"role":"consume"}}
		for button: Array in type_set.buttons:
			var on: bool=int(button[3])==_type
			type_bindings[int(button[0])]={"role":"button","visible":not on,"activate":Callable(self,"_select_type").bind(int(button[3]))}
			type_bindings[int(button[1])]={"role":"button","visible":on,"activate":Callable(self,"_select_type").bind(int(button[3]))}
		_consume_touch(TYPE_SET,type_scope,type_bindings,reads)
		bindings[TYPE_PROJECT]={"role":"project","visible":false,"defer_until_shown":true,"source_node_offsets":type_scope,"bindings":type_bindings}
	# Search bar: ItemBook_Popup_Keypad with the window's own editor.
	if _available(KEYPAD) and host!=null:
		scope.append_array(_subtree(DETAIL,[SEARCH],reads))
		if not scope.has(POPUP_CLOSE):
			scope.append(POPUP_CLOSE)
			bindings[POPUP_CLOSE]={"role":"button","visible":false,"activate":Callable(self,"_close_popups")}
		scope.append(KEYPAD_PROJECT)
		bindings[SEARCH]={"role":"button","activate":Callable(self,"_open_keypad")}
		if not _query.is_empty():bindings[SEARCH_TEXT]={"role":"source_text","text":_query}
		bindings[SEARCH_STATES[0]]={"visible":true}
		bindings[SEARCH_STATES[1]]={"visible":false}
		var keypad_bindings: Dictionary={8316:{"role":"consume"},7556:{"role":"consume"},
			KEYPAD_FIELD:{"role":"source_text_field","editor":_search_editor(host)},
			KEYPAD_SEARCH:{"role":"button","activate":Callable(self,"_apply_query")},
			KEYPAD_CLOSE:{"role":"button","activate":Callable(self,"_close_popups")},
			KEYPAD_CANCEL:{"role":"button","activate":Callable(self,"_clear_query")},
			5132:{"role":"static_source_text"},2868:{"role":"static_source_text"}}
		bindings[KEYPAD_PROJECT]={"role":"project","visible":false,"defer_until_shown":true,"source_node_offsets":KEYPAD_NODES.duplicate(),"bindings":keypad_bindings}
	var info_scope: Array[int]=[int(info_nodes.name),int(info_nodes.grade),int(info_nodes.title),int(info_nodes.list)]
	for offset: Variant in info_nodes.decor:info_scope.append(int(offset))
	var info_bindings: Dictionary={int(info_nodes.name):{"role":"source_text","text":str(selected.get("name",""))},
		int(info_nodes.grade):{"role":"source_text","text":str(selected.get("grade",""))},
		int(info_nodes.title):{"role":"static_source_text"},
		int(info_nodes.list):{"role":"source_list","row_offsets":[],"input":Callable(self,"_option_list_input")}}
	_consume_touch(INFO,info_scope,info_bindings,reads)
	bindings[INFO_PROJECT]={"role":"project","visible":true,"source_node_offsets":info_scope,"bindings":info_bindings}
	_consume_touch(DETAIL,scope,bindings,reads)
	scope.append(INFO_PROJECT)
	return {"scope":scope,"bindings":bindings}

func _card(record: Dictionary) -> Dictionary:
	var member: String=GRADE_MEMBERS[str(record.grade)]
	var nodes: Dictionary=CARD_NODES[member]
	var id: String=Cards.card_id(record)
	var scope: Array[int]=[int(nodes.root),int(nodes.bg),int(nodes.character),int(nodes.frame),int(nodes.sample),int(nodes.check)]
	var bindings: Dictionary={int(nodes.root):{"input":Callable(self,"_list_input")},
		int(nodes.sample):{"role":"source_asset_slot","visible":false},
		int(nodes.check):{"role":"checkbox","selected":id==_selected,"activate":Callable(self,"_card_pressed").bind(id)}}
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,member,scope,bindings)
	if not result.get("ok",false):scene.free();return result
	var owner: Dictionary=_picture(Presentation.detail(record,true,false))
	var picture: bool=false
	if owner.get("ok",false):
		var uploaded: Dictionary=scene.set_bound_source_visual_result(int(nodes.sample),owner)
		picture=uploaded.get("ok",false) and scene.set_bound_visible(int(nodes.sample),true).get("ok",false)
	scene.set_meta("source_change_card",{"id":id,"member":member,"picture":picture,"status":str(owner.get("status","")),"reason":str(owner.get("reason",""))})
	return {"ok":true,"scene":scene,"picture":picture}

## Bind the selected original texture and its source role to the authored slot.
static func _picture(shown: Dictionary) -> Dictionary:
	var owner: Dictionary={"ok":shown.get("status","")=="original" and shown.get("texture") is Texture2D,"status":str(shown.get("status","")),"reason":str(shown.get("reason",""))}
	if owner.ok:
		owner["texture"]=shown.texture
		owner["provenance"]=shown.get("provenance",{}).duplicate(true)
		owner["role"]=str(shown.get("role",""))
	return owner

## Detail side: card picture, name, grade and option lines.
func _show_selected() -> Dictionary:
	if not is_instance_valid(_detail) or not is_instance_valid(_info):return {"ok":false}
	var record: Dictionary=_record(_selected)
	var nodes: Dictionary=INFO_DOLL if _category=="마법인형" else INFO_CARD
	_info.set_bound_text(int(nodes.name),str(record.get("name","")))
	_info.set_bound_text(int(nodes.grade),str(record.get("grade","")))
	var picture: bool=false
	# Change_DetailView's CardSample is a 46x46 card placeholder (scale 1.5)
	# whose siblings CardSample_Screen / _Awaken / _Multi overlay the same card
	# face: every category and grade shows its DisplayBaseAssetID front. The
	# IllustrationAssetID painting overflowed the option text and buttons
	# (user list 2026-11-26 #16).
	var owner: Dictionary=_picture(Presentation.detail(record,true,false)) if not record.is_empty() else {"ok":false}
	if owner.get("ok",false):
		var uploaded: Dictionary=_detail.set_bound_source_visual_result(SAMPLE,owner)
		picture=uploaded.get("ok",false) and _detail.set_bound_visible(SAMPLE,true).get("ok",false)
	else:_detail.set_bound_visible(SAMPLE,false)
	for child: Node in _option_content.get_children():
		_option_content.remove_child(child)
		child.queue_free()
	var options_record: Dictionary=record
	if record.get("source_snapshot")=="patch523":
		var selected_variant: Dictionary=CARD_DEFINITIONS.canonical(record)
		if not selected_variant.is_empty():options_record=selected_variant
	var offered_lines: Variant=options_record.get("source_card_display_options",options_record.get("sourceOptions",[]))
	# Source stat rows can be Array[Dictionary]. The detail also shows text rows.
	var lines: Array=[]
	if offered_lines is Array:lines.append_array(offered_lines)
	var awakening: Dictionary=_awakening_options()
	var awakened: bool=awakening.get("awakened",false)
	var added: int=0
	if not awakening.is_empty():
		var current: Array=awakening.applied if awakened else awakening.preview
		if not current.is_empty():
			lines.append("각성 적용 효과" if awakened else "각성 시 추가 능력")
			lines.append_array(current)
			added+=current.size()
		if awakened and not awakening.pending.is_empty():
			lines.append("현재 적용되지 않는 원본 옵션")
			lines.append_array(awakening.pending)
	var options: int=0
	var list_height: float=230.0 if _category=="마법인형" else 260.0
	for line: Variant in lines:
		var row: Dictionary=_option_row(line)
		if not row.get("ok",false):continue
		# Rows run top-down from the option list's top edge.
		row.scene.position=Vector2(0.0,-(list_height-OPTION_HEIGHT*float(options+1)))
		_option_content.add_child(row.scene)
		options+=1
	_option_scroll_min=minf(0.0,list_height-float(options)*OPTION_HEIGHT)
	_option_content.position.y=0.0
	var applied: bool=not _selected.is_empty() and _selected==_equipped_id()
	_detail.set_bound_displaystate(APPLY,not record.is_empty() and not applied)
	_detail.set_bound_displaystate(AWAKEN,not record.is_empty())
	_detail.set_bound_visible(AWAKEN_STATES[0],not record.is_empty())
	_detail.set_bound_visible(AWAKEN_STATES[1],record.is_empty())
	return {"ok":true,"selected":_selected,"illustration":picture,"illustration_status":str(owner.get("status","")),"options":options,"awakening_options":added,"awakened":awakened,"applied":applied}

func _awakening_options() -> Dictionary:
	if _selected.is_empty():return {}
	var world: Node=_world_node()
	var runtime: Variant=world.get("option_awakening") if world!=null else null
	return runtime.card_options(_category,_selected) if runtime!=null else {}

func _option_list_input(event: InputEvent) -> void:
	if not is_instance_valid(_option_content) or _option_scroll_min==0.0:return
	var delta: float=0.0
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT):
		delta=event.relative.y/maxf(0.001,absf(_option_content.get_global_transform_with_canvas().get_scale().y))
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=54.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -54.0
	_option_content.position.y=clampf(_option_content.position.y+delta,_option_scroll_min,0.0)

func _option_row(line: Variant) -> Dictionary:
	# "SP +1" -> desc "SP", value "+1" (the row's two original labels).
	var desc: String=str(line.get("label","")) if line is Dictionary else str(line)
	var value: String=str(line.get("value","")) if line is Dictionary else ""
	if line is String:
		var cut: int=line.rfind(" ")
		if cut>0 and line.substr(cut+1).left(1) in ["+","-"]:
			desc=line.left(cut)
			value=line.substr(cut+1)
	var bindings: Dictionary={OPTION_PANEL:{"role":"consume"},OPTION_DESC:{"role":"source_text","text":desc},OPTION_VALUE:{"role":"source_text","text":value,"visible":not value.is_empty()}}
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,OPTION_ROW,[OPTION_PANEL,OPTION_DESC,OPTION_VALUE],bindings)
	if not result.get("ok",false):scene.free();return result
	return {"ok":true,"scene":scene}

func _card_pressed(_checked: bool, id: String) -> Dictionary:
	if absf(_moved)>12.0:
		_sync_checks()
		return {"ok":true,"ignored_after_drag":true}
	if id==_selected:
		_sync_checks()
		return _apply_selected()
	_selected=id
	_sync_checks()
	return _show_selected()

func _sync_checks() -> void:
	for scene: Node2D in _card_scenes.values():
		if not is_instance_valid(scene):continue
		var info: Dictionary=scene.get_meta("source_change_card",{})
		scene.set_bound_selected_state(int(CARD_NODES[str(info.get("member",""))].check),str(info.get("id",""))==_selected)

## The existing catalog equip: World._equip_catalog checks ownership, the
## original card conditions and saves; the window then shows the result.
func _apply_selected() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var record: Dictionary=_record(_selected)
	if hud==null or record.is_empty():return _fail("source_change_window_card_unselected")
	if _selected==_equipped_id():return {"ok":true,"already_applied":true,"id":_selected}
	hud.emit_signal("catalog_equip_requested",_category,record.duplicate(true))
	var shown: Dictionary=_show_selected()
	return {"ok":true,"existing_equip_requested":true,"id":_selected,"applied":shown.get("applied",false)}

func _fusion_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var target: String=_category
	close()
	if hud!=null and hud.has_method("open_card_fusion"):hud.call("open_card_fusion",target)
	return {"ok":true,"existing_fusion":true}

## True when the existing star-enchant owner accepts this card.
static func star_target(world: Object, category: String, identity: String) -> bool:
	if world==null or identity.is_empty() or category!=StarEnchant.CATEGORY:return false
	return bool(StarEnchant.from_world(world,category,identity).get("ok",false))

func _world_node() -> Node:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	return hud.get_parent() if hud is Node else null

## 성급 강화: the existing star-enchant window of the selected card.
func _star_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null or not hud.has_method("open_halphas_star_enchant"):return _fail("source_change_window_star_enchant_unavailable")
	var target: String=_category
	var focus: String=_selected
	close()
	hud.call("open_halphas_star_enchant",target,focus)
	return {"ok":true,"existing_star_enchant":true,"id":focus}

func _collection_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var target: String=_category
	var focus: String=_selected
	close()
	if hud!=null and hud.has_method("open_normal_card_collections"):hud.call("open_normal_card_collections",target,focus)
	return {"ok":true,"existing_collection":true}

func _explore_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null or not hud.has_method("open_doll_explore"):return _fail("source_doll_explore_owner_missing")
	# The HUD owns both the menu tile and the real Change_WinTotal tab. It
	# closes this view only when the original destination can be opened.
	return hud.call("open_doll_explore")

## 각 성: the same request as the catalog's 각성 tab (World opens the
## existing option awakening for the card, or reports why it cannot).
func _awaken_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null or _record(_selected).is_empty():return _fail("source_change_window_card_unselected")
	if not hud.has_signal("option_awakening_open_requested"):return _fail("source_change_window_awakening_unavailable")
	hud.emit_signal("option_awakening_open_requested",_category,_selected)
	return {"ok":true,"existing_option_awakening_requested":true,"id":_selected}

## --- Grade list (Change_WinTotal_Class) --------------------------------------

func _fill_classes(detail: Node2D, owned: Array[Dictionary], reads: Dictionary={}) -> Dictionary:
	if not _available(GRADE_ROW):return {"ok":true,"rows":0}
	var list_node: Variant=detail.get("source_nodes").get(CLASS_LIST)
	var content: Variant=(list_node.get_meta("source_list_content") if list_node.has_meta("source_list_content") else null) if is_instance_valid(list_node) else null
	if not content is Node2D:return _fail("source_change_window_grade_list_missing")
	var tree: Dictionary=StageReads.node_tree(_pack,DETAIL,reads)
	var options: Dictionary=Scene._node_at_offset(tree,CLASS_LIST).get("options",{})
	var raw_size: Array=options.get("widgetOptions",{}).get("size",[166,475])
	var size:=Vector2(float(raw_size[0]),float(raw_size[1]))
	var gap: float=float(options.get("itemMargin",0))
	var panel: Dictionary=Scene._node_at_offset(StageReads.node_tree(_pack,GRADE_ROW,reads),ROW_PANEL).get("options",{}).get("widgetOptions",{})
	var row_size: Array=panel.get("size",[160,72])
	var row_position: Array=panel.get("position",[0,0])
	var anchor: Array=panel.get("anchorPoint",[0.5,0.5])
	var extent:=Vector2(float(row_size[0]),float(row_size[1]))
	var origin:=Vector2(float(row_position[0])-float(anchor[0])*extent.x,float(row_position[1])-float(anchor[1])*extent.y)
	var counts: Dictionary=_grade_counts(owned)
	var y: float=size.y
	var rows: int=0
	for grade: String in SIDEBAR:
		var count: Array=counts.get(grade,[0,0])
		var built: Dictionary=_grade_row(grade,"( %d / %d )" % [int(count[0]),int(count[1])],grade==_grade,reads)
		if not built.get("ok",false):return built
		# Rows run top-down; a row's root panel lower-left sits on the line.
		var at: Vector2=Vector2((size.x-extent.x)*0.5,y-extent.y)-origin
		built.scene.position=Vector2(at.x,-at.y)
		content.add_child(built.scene)
		y-=extent.y+gap
		rows+=1
	return {"ok":true,"rows":rows,"content":content,"min":minf(0.0,size.y-(size.y-y-gap))}

func _grade_row(grade: String, count_text: String, on: bool, reads: Dictionary={}) -> Dictionary:
	# The client spaces two-letter grade names ("등 급").
	var label: String=grade.substr(0,1)+" "+grade.substr(1,1) if grade.length()==2 else grade
	var scope: Array[int]=_subtree(GRADE_ROW,[ROW_PANEL],reads)
	var activate: Callable=Callable(self,"_select_grade").bind(grade)
	var bindings: Dictionary={ROW_PANEL:{"input":Callable(self,"_class_input")},
		ROW_NORMAL:{"role":"button","visible":not on,"activate":activate},
		ROW_PRESSED:{"role":"button","visible":on,"activate":activate},
		ROW_NORMAL_TEXT[0]:{"role":"source_text","text":label},ROW_NORMAL_TEXT[1]:{"role":"source_text","text":count_text},
		ROW_PRESSED_TEXT[0]:{"role":"source_text","text":label},ROW_PRESSED_TEXT[1]:{"role":"source_text","text":count_text},
		ROW_EVENT:{"visible":false},ROW_NEW:{"visible":false}}
	for name: String in ROW_IMAGES:bindings[int(ROW_IMAGES[name])]={"visible":name==grade}
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,GRADE_ROW,scope,bindings)
	if not result.get("ok",false):scene.free();return result
	return {"ok":true,"scene":scene}

func _select_grade(grade: String) -> Dictionary:
	if absf(_moved)>12.0:return {"ok":true,"ignored_after_drag":true}
	if grade==_grade:return {"ok":true,"same_grade":true}
	_grade=grade
	_scroll=0.0
	return _stage()

func _class_input(event: InputEvent) -> void:
	if not is_instance_valid(_class_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_class_drag=event.pressed
		if event.pressed:_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _class_drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=69.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_class_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_moved+=delta
	_class_scroll=clampf(_class_scroll+delta,_class_min,0.0)
	_class_content.position.y=_class_scroll

## --- 유형 popup (Common_ButtonSet_Type) ---------------------------------------

## The popup button's own label for BuffCardAttackType `id`.
func _type_label(id: int) -> String:
	if not _available(TYPE_SET):return ""
	var tree: Dictionary=_pack.scene(TYPE_SET).get("nodeTree",{})
	for button: Array in TYPE_SETS.get(_category,{}).get("buttons",[]):
		if int(button[3])==id:return str(Scene._node_at_offset(tree,int(button[2])).get("options",{}).get("text",""))
	return ""

func _toggle_type_popup() -> Dictionary:
	if not is_instance_valid(_detail):return _fail("source_change_window_not_open")
	var node: Node2D=_detail.source_nodes.get(TYPE_PROJECT)
	var should_show: bool=is_instance_valid(node) and not node.visible
	_close_popups()
	if not should_show:return {"ok":true,"type_popup":false}
	var shown: Dictionary=_detail.set_bound_visible(TYPE_PROJECT,true)
	if not shown.ok:return shown
	_detail.set_bound_visible(POPUP_CLOSE,true)
	_detail.set_bound_visible(SORT_STATES[0],false)
	_detail.set_bound_visible(SORT_STATES[1],true)
	return {"ok":true,"type_popup":true}

func _select_type(id: int) -> Dictionary:
	_close_popups()
	if id==_type:return {"ok":true,"same_type":true}
	_type=id
	_scroll=0.0
	return _stage()

## Hides the type popup and the keypad (the editor keeps its text).
func _close_popups() -> Dictionary:
	if not is_instance_valid(_detail):return {"ok":true}
	for offset: int in [TYPE_PROJECT,POPUP_CLOSE,KEYPAD_PROJECT]:_detail.set_bound_visible(offset,false)
	_detail.set_bound_visible(SORT_STATES[0],true)
	_detail.set_bound_visible(SORT_STATES[1],false)
	_release_field()
	return {"ok":true}

## --- Search (ItemBook_Popup_Keypad) ------------------------------------------

## The window's own editor (hidden under the host while no keypad shows it).
func _search_editor(host: Node) -> LineEdit:
	if not is_instance_valid(_editor):
		_editor=preload("res://scripts/ui/native_touch_line_edit.gd").new()
		_editor.name="ChangeWindowCardSearch"
		_editor.max_length=20
		_editor.visible=false
		host.add_child(_editor)
		_editor.text_submitted.connect(func(_text: String) -> void:_apply_query())
	_editor.text=_query
	return _editor

func _keypad_field() -> Variant:
	if not is_instance_valid(_detail):return null
	var player: Dictionary=_detail.project_player([KEYPAD_PROJECT])
	if not player.get("ok",false):return null
	var node: Variant=player.player.get("source_nodes").get(KEYPAD_FIELD)
	return node.get_meta("source_text_field") if is_instance_valid(node) and node.has_meta("source_text_field") else null

func _open_keypad() -> Dictionary:
	if not is_instance_valid(_detail):return _fail("source_change_window_keypad_unavailable")
	_close_popups()
	var shown: Dictionary=_detail.set_bound_visible(KEYPAD_PROJECT,true)
	if not shown.ok:return _fail("source_change_window_keypad_unavailable")
	var field: Variant=_keypad_field()
	if field==null:
		_close_popups()
		return _fail("source_change_window_keypad_unavailable")
	_detail.set_bound_visible(POPUP_CLOSE,true)
	var attached: Dictionary=field.attach_editor()
	if not attached.get("ok",false):
		_close_popups()
		return attached
	_field=field
	if is_instance_valid(_editor):
		_editor.grab_focus()
		if _editor.has_method("edit"):_editor.call("edit")
	return {"ok":true,"keypad":true}

func _apply_query() -> Dictionary:
	if is_instance_valid(_editor) and _editor.has_method("apply_ime"):_editor.call("apply_ime")
	var query: String=_editor.text.strip_edges() if is_instance_valid(_editor) else _query
	_close_popups()
	if query==_query:return {"ok":true,"same_query":true}
	_query=query
	_scroll=0.0
	return _stage()

func _clear_query() -> Dictionary:
	if is_instance_valid(_editor):_editor.text=""
	return {"ok":true}

func _release_field() -> void:
	if _field!=null and is_instance_valid(_field) and _field.has_method("release_editor"):_field.release_editor()
	_field=null
	if is_instance_valid(_editor):_editor.visible=false

func _reset_filters() -> Dictionary:
	if not _filtering():return {"ok":true,"already_clear":true}
	_grade="전체"
	_type=0
	_query=""
	_scroll=0.0
	_class_scroll=0.0
	if is_instance_valid(_editor):_editor.text=""
	return _stage()

func _ignore() -> Dictionary:
	return {"ok":true}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

func _ignore_input(_event: InputEvent) -> void:
	pass

func _list_input(event: InputEvent) -> void:
	if not is_instance_valid(_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_drag=event.pressed and not (event is InputEventScreenTouch and event.canceled)
		if _drag:
			_moved=0.0
			# The source router owns the original pressed checkbox through release.
			# Keep the rows from the start of the gesture mounted while it drags.
			_card_hold_indices.assign(_card_scenes.keys())
		elif not _card_hold_indices.is_empty():
			_card_hold_indices.clear()
			_card_range=Vector2i(-1,-1)
			_queue_card_refresh()
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=146.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_moved+=delta
	# Dragging up (negative) reveals lower rows.
	_scroll=clampf(_scroll+delta,_scroll_min,0.0)
	_content.position.y=_scroll
	_queue_card_refresh()

func _queue_card_refresh() -> void:
	if not _card_refresh_queued and not _card_geometry.is_empty() and visible_card_range(_cards.size(),_scroll,_card_geometry.row_height)!=_card_range:
		_card_refresh_queued=true
		_refresh_scrolled_cards.call_deferred(_content)

## Touch-enabled original nodes in the mounted subtrees with no action of
## their own swallow their touch; labels it does not drive keep their text.
func _consume_touch(member: String, scope: Array[int], bindings: Dictionary, reads: Dictionary={}) -> void:
	var tree: Dictionary=StageReads.node_tree(_pack,member,reads)
	for offset: int in scope:_consume_subtree(Scene._node_at_offset(tree,offset),bindings,scope)

static func _consume_subtree(node: Dictionary, bindings: Dictionary, scope: Array[int]) -> void:
	if node.is_empty():return
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var offset: int=int(node.get("_offset",-1))
	if offset not in scope:return
	if bool(widget.get("touchEnabled",false)) and node.get("classname")!="ProjectNode":
		var binding: Dictionary=bindings.get(offset,{})
		if not binding.has("role") and not binding.has("input"):
			binding["role"]="consume"
			bindings[offset]=binding
	if node.get("classname") in ["Text","TextBMFont"] and not bindings.get(offset,{}).has("role"):
		var label: Dictionary=bindings.get(offset,{})
		label["role"]="static_source_text"
		bindings[offset]=label
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_consume_subtree(child,bindings,scope)

## A node scope keeps only the listed nodes and their ancestors: list every
## descendant of each mounted node (a nested ProjectNode keeps its own scope).
func _subtree(member: String, roots: Array[int], reads: Dictionary={}) -> Array[int]:
	var tree: Dictionary=StageReads.node_tree(_pack,member,reads)
	var result: Array[int]=[]
	for offset: int in roots:_collect(Scene._node_at_offset(tree,offset),result)
	return result

static func _collect(node: Dictionary, result: Array[int]) -> void:
	if node.is_empty():return
	var offset: int=int(node.get("_offset",-1))
	if offset not in result:result.append(offset)
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_collect(child,result)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
