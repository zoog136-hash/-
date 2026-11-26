extends RefCounted
## The original 523 장비 강화 window: EnchantScene with Enchant_All (단일 강화
## page: "+N 이름을 강화 하시겠습니까?", 주문서 + 대상 slots, 안전 / 비안전 구간,
## stat rows (Enchant_Text_Set), 수수료 / 주문서 수, 강화 확률, 강 화 시 작)
## and Enchant_Inventory (장비 / 주문서 tabs over Inventory_Slot_Set rows,
## 보유 아데나, close). Candidates, chances, costs, the confirmation and the
## roll stay with the existing owners: world._enhancement_candidates supplies
## the rows, 강화 시작 emits hud.enhancement_requested at once (no extra
## confirmation: the original window has none, user request 2026-11-22),
## the world rolls and reopens this window.
## The result is the client's own in-window presentation: Enchant_All's
## Fx_Enchant_Start (slot glow) and Enchant_Popup_Message (Success / Fail
## banner, Text_Item) play over the window, then hold their legible result;
## a tap anywhere ends it early. No TWILIGHT full-screen result is drawn over
## the original window. Text_Item's result text is a TWILIGHT 근사 (the
## client's string is not in the 523 tables).
## 다중 강화 (Nd_Enchant_Multi, TWILIGHT 근사: the existing single roll run in
## turn): bag taps pick up to MULTI_MAX targets, Nd_Btn_01..10 choose the goal
## +N, 강화 시작 starts World.attempt_enhancement_series, which rolls each
## target up to the goal; the series stops at the first failure (유지 / 하락),
## a destroyed target or too few scrolls. Label_Num shows the fewest scrolls
## the goal needs; the picked list (ListView_Item) stays empty.
## Left inert or empty (no rule for them in this project): the other Enchant_All pages
## (속성 부여 / 은총 / 스킬 / 용해 / 삭제), 자동 강화, 실패 기록,
## the grade filters, 상세보기 / 일괄 선택, tooltips and the other effect
## layers.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const NativeIcons=preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd")
const Forge=preload("res://scripts/ui/renewal_forge.gd")
const ENCHANT=preload("res://scripts/original_enhancement.gd")
const ROOT="UI/EnchantScene.csb"
const ALL="UI/FloatingUi/Enchant_All.csb"
const INVENTORY="UI/FloatingUi/Enchant_Inventory.csb"
const TEXT_SET="UI/FloatingUi/Enchant_Text_Set.csb"
const SMELT_BODY="UI/FloatingUi/Enchant_Tab_Smelt.csb"
const SPIRIT_BODY="UI/FloatingUi/Enchant_Tab_Properties_Smelt.csb"
const TITLE="UI/CommonUi/Inven_Icon_TitleLayout.csb"
const SET="UI/FloatingUi/Inventory_Slot_Set.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
## Common_Slot keeps its button, frame, item picture, selection and amount.
const MEMBER_SCOPES={SLOT:[15728,15316,15012,9004,6880]}
const REQUIRED: Array[String]=[ROOT,ALL,INVENTORY,TEXT_SET,TITLE,SET,SLOT]
## The result presentation members (an older UI pack without them keeps the
## window and leaves the result to the HUD's fallback).
const FX_START="UI/Effect/Effect_Source/Fx_Enchant_Start.csb"
const POPUP="UI/FloatingUi/Enchant_Popup_Message.csb"
const PRESENTATION: Array[String]=[FX_START,POPUP]
const P_FX="Enchant_All_Layout/Fx_Enchant_Start"
const P_POPUP="Enchant_All_Layout/Enchant_Popup_Message"
const POPUP_SETS: Array[String]=["EnChant_Success","EnChant_Fail"]
## The tab row Enchant_Popup_Message's banner lies on: its texts are hidden
## while the banner plays, so no window text shows through the banner.
const P_TAB="Enchant_All_Layout/Nd_Common/Tab"
## Fx_Enchant_Start's clip (frames 5..115) at the Cocos 60 fps timeline: the
## longer of the two clips (Success 0..80, Fail 100..165).
const PRESENT_SECONDS: float=110.0/60.0
const P_ALL="Enchant_All_Layout/"
const P_COMMON="Enchant_All_Layout/Nd_Common/"
const P_ENCHANT="Enchant_All_Layout/Nd_Enchant/"
const P_INV="Enchant_Inventory_Layout/Nd_Inven/Nd_InvenMode/"
const P_SMELT_START=P_ALL+"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant"
const SET_SLOTS: Array[String]=["Slot_1","Slot_2","Slot_3","Slot_4"]
## Inventory_Slot_Set's authored horizontal slot pitch (-117, -41, 35, 111)
## as the line pitch, as the main inventory and the refine window use.
const ROW_PITCH: float=76.0
const ROW_TAIL: float=40.0
## Enchant_Text_Set authors one 40 px line; further stat lines follow it.
const TEXT_PITCH: float=30.0
const TEXT_TAIL: float=20.0
## Enchant_All pages with no rule here, kept out of the scene.
const MULTI_MAX: int=10
const P_MULTI="Enchant_All_Layout/Nd_Enchant_Multi/"
const OTHER_PAGES: Array[String]=["Nd_Enchant_Bless","Nd_Enchant_Smelt","Nd_Enchant_Grace","Nd_ChangeProperty","Nd_Enchant_Properties_Smelt","Nd_Enchant_Skill","Nd_Dissolve","Nd_Delete",
	"Nd_Btn_Auto","Nd_Enchant_Btn/Nd_Auto_Enchant","Enchant_ToolTip_Bless","Enchant_ToolTip_Skill","Enchant_ToolTip_Smelt","Enchant_ToolTip_Grace","Enchant_ToolTip_Properties_Smelt","Btn_FailHistory"]
const OTHER_TABS: Array[String]=["Nd_Properties","Nd_Bless","Nd_Magic","Nd_Smelt","Nd_Grace","Nd_Properties_Smelt","Nd_Label"]
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _scroll: String=""
var _scroll_row: Dictionary={}
var _blessing: bool=false
var _candidates: Array=[]
var _selected: String=""
var _tab: String="equip"
var multi: bool=false
var _picked: Array[String]=[]
var _goal: int=0
var _bag: Scroller=Scroller.new()
var _text: Scroller=Scroller.new()
var _last_out: Dictionary={}
var last_result: Dictionary={}
## The pack has Fx_Enchant_Start and Enchant_Popup_Message.
var _presents: bool=false
## {kind: "success" | "fail", text, token} while the result plays.
var _presentation: Dictionary={}
var _pending_result_refresh: Dictionary = {}
var _last_presentation_problem: String = ""
var _blocker: Control
var _token: int=0
var _smelt:Dictionary={}
var _smelt_quote:Dictionary={}
var _smelt_status:String=""

## Drag scrolling of one original ScrollView whose authored first line is
## extended by added lines (the refine window's rule).
class Scroller extends RefCounted:
	var content: Node2D
	var top: float=0.0
	var bottom: float=0.0
	var y: Variant=null
	var drag: bool=false
	var moved: float=0.0
	var pitch: float=76.0

	func bind(row: Variant, lines: int, line_pitch: float, tail: float) -> void:
		content=null
		pitch=line_pitch
		if not row is Node2D:return
		var node: Node=(row as Node2D).get_parent()
		var row_offset: float=(row as Node2D).position.y
		while node!=null and node.name!="SourceOriginalScrollContent":
			if node is Node2D:row_offset+=(node as Node2D).position.y
			node=node.get_parent()
		if not node is Node2D:return
		content=node
		top=content.position.y
		bottom=minf(top,-(row_offset+line_pitch*float(lines-1)+tail))
		if y!=null:content.position.y=clampf(float(y),bottom,top)

	func keep() -> void:
		if is_instance_valid(content):y=content.position.y

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
			delta=pitch*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
		if delta==0.0:return
		var scale_y: float=absf(content.get_global_transform_with_canvas().get_scale().y)
		if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
		moved+=absf(delta)
		content.position.y=clampf(content.position.y+delta,bottom,top)
		y=content.position.y

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_enchant_window_member_missing","member":member}
	_pack=pack
	_presents=PRESENTATION.all(func(member: String) -> bool: return pack.manifest.get("scenes",{}).has(member))
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

## Opens on `scroll`'s targets (장비 tab), or on the 주문서 tab without one.
func open(parent: Node, scroll: String, candidates: Array, blessing: bool=false) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_enchant_window_host_unavailable")
	_parent=weakref(parent)
	_bag.y=null
	_text.y=null
	_selected=""
	return update(scroll,candidates,blessing)

## The native inventory chose this exact physical material. The source
## EnchantScene still owns the layout and touch controls; only its confirmed
## common start invokes the existing equipment transaction.
func open_smelt(parent:Node,offer:Dictionary)->Dictionary:
	var kind:String=str(offer.get("kind",""))
	var member:String=SMELT_BODY if kind=="smelt" else SPIRIT_BODY
	if kind not in ["smelt","spirit_smelt"] or not offer.get("ok",false) or str(offer.get("uid","")).is_empty() or not is_instance_valid(parent):
		return _fail("source_smelt_entry_unavailable")
	if not _pack.manifest.get("scenes",{}).has(member):return _fail("source_smelt_body_unavailable")
	close()
	_parent=weakref(parent)
	_bag.y=null;_text.y=null
	_smelt=offer.duplicate(true)
	_candidates=offer.get("targets",[]).duplicate(true)
	_scroll=str(offer.get("name",""))
	_selected="";_tab="equip";multi=false
	_smelt_status="제련할 장비를 선택하세요" if not _candidates.is_empty() else "가방에 이 재료에 맞는 장비가 없습니다"
	return _restage()

## New candidates after an attempt (or another scroll): keeps the selected
## physical item when it is still listed.
func update(scroll: String, candidates: Array, blessing: bool=false) -> Dictionary:
	# The committed world requests refreshed rows immediately. Keep the
	# exact pre-roll slot (including a destroyed item) under the running
	# authored proof, and apply the refreshed owner rows when it ends.
	if is_presenting():
		_pending_result_refresh = {"scroll":scroll,"candidates":candidates.duplicate(true),"blessing":blessing}
		return {"ok":true,"handled":true,"result_refresh_pending":true}
	_smelt.clear();_smelt_quote.clear();_smelt_status=""
	_blessing=blessing
	if blessing:multi=false
	var blessing_reference: String=str(candidates[0].get("scroll_reference",scroll)) if blessing and not candidates.is_empty() else ""
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var selected_scroll: Dictionary=Forge.selected_scroll(hud,scroll,blessing_reference) if is_instance_valid(hud) else {"reference":scroll}
	if selected_scroll.reference!=_scroll_row.get("reference",""):
		_bag.y=null
		_picked.clear()
	_scroll_row=selected_scroll
	_scroll=scroll
	_candidates=candidates.duplicate(true)
	_prune_picked()
	if scroll.is_empty():multi=false
	_tab="equip" if not scroll.is_empty() else "scroll"
	if _entry().is_empty():_selected=str(_candidates[0].get("target_id","")) if not _candidates.is_empty() else ""
	return _restage()

func close() -> void:
	_blessing=false
	_scroll_row={}
	_smelt.clear();_smelt_quote.clear();_smelt_status=""
	_presentation={}
	_pending_result_refresh={}
	_blocker=null
	var previous: Node2D=_scene
	_scene=null
	_bag.content=null
	_text.content=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func scroll_name() -> String:
	return _scroll

func selected() -> String:
	return _selected

func tab() -> String:
	return _tab

func node_keys() -> Dictionary:
	return _last_out

## --- Model ------------------------------------------------------------------

func _entry() -> Dictionary:
	for entry: Variant in _candidates:
		if entry is Dictionary and str(entry.get("target_id",""))==_selected and not _selected.is_empty():return entry
	return {}

func _listing(hud: Node) -> Array:
	return _candidates if _tab=="equip" else Forge.owned_scrolls(hud)

## Stat lines: every stat the item has now or after success, with the
## current and the success value.
func _stat_rows(entry: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var now: Dictionary=entry.get("stats_now",{}) if entry.get("stats_now") is Dictionary else {}
	var next: Dictionary=entry.get("stats_next",{}) if entry.get("stats_next") is Dictionary else {}
	var keys: Array=now.keys()
	for key: Variant in next.keys():
		if not keys.has(key):keys.append(key)
	for key: Variant in keys:
		var a: float=float(now.get(key,0.0))
		var b: float=float(next.get(key,0.0))
		if is_zero_approx(a) and is_zero_approx(b):continue
		var label: String=ENCHANT.stat_label(str(key))
		var sign: float=1.0
		if str(key)=="defense":
			label="AC"
			sign=-1.0
		rows.append({"label":label,"now":_value(a*sign),"next":"%s(%s)" % [_value(b*sign),_delta((b-a)*sign)]})
	return rows

static func _value(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value,round(value)) else "%.2f" % value

static func _delta(value: float) -> String:
	return ("+" if value>=0.0 else "")+_value(value)

## "+11 마법 지팡이를 강화 하시겠습니까?" with the particle of the last syllable.
static func _title(entry: Dictionary) -> String:
	var name: String=str(entry.get("name","")).get_slice(" · 원본#",0)
	var particle: String="를"
	# "장갑 (각인)" takes the particle of 장갑, not of the closing bracket.
	var spoken: String=name
	while spoken.ends_with(")") and spoken.rfind("(")>0:spoken=spoken.left(spoken.rfind("(")).strip_edges()
	if not spoken.is_empty():
		var code: int=spoken.unicode_at(spoken.length()-1)
		if code>=0xAC00 and code<=0xD7A3 and (code-0xAC00)%28!=0:particle="을"
	var level: int=int(entry.get("level",0))
	return "%s%s%s 강화 하시겠습니까?" % ["+%d " % level if level>0 else "",name,particle]

## --- Stage ------------------------------------------------------------------

func _restage() -> Dictionary:
	_bag.keep()
	_text.keep()
	return _stage()

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if parent==null or hud==null:return _fail("source_enchant_window_host_unavailable")
	var entry: Dictionary=_entry()
	var listing: Array=_listing(hud)
	var rows: Array[Dictionary]=_stat_rows(entry)
	var spec: Dictionary=_spec(hud,entry,listing,rows)
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	if not _smelt.is_empty():
		var body:String=_smelt_body_path(_smelt.kind)
		if not NamedTree.locate(next,out,body).get("ok",false) or not NamedTree.locate(next,out,P_SMELT_START).get("ok",false):
			next.free()
			return _fail("source_smelt_controls_unavailable")
	var pictures: int=0
	var material:Dictionary=Forge.image_record_of(hud,_scroll_row) if not _scroll.is_empty() and _smelt.is_empty() else _smelt.get("record",{})
	if not _scroll.is_empty() and _picture(next,out,P_COMMON+"Nd_Slot/Inventory_Slot0/Sp_IconSample",material,_scroll):pictures+=1
	if not entry.is_empty() and _picture(next,out,P_COMMON+"Nd_Slot/Inventory_Slot1/Sp_IconSample",Forge.image_record_of(hud,entry),str(entry.get("name",""))):pictures+=1
	var filled: Dictionary=_fill_bag(hud,next,out,listing)
	var texts: Dictionary=_fill_text(next,out,rows) if filled.get("ok",false) and _smelt.is_empty() else filled
	if not texts.get("ok",false):
		next.free()
		last_result=texts
		return texts
	pictures+=int(filled.get("pictures",0))
	var previous: Node2D=_scene
	# EnchantScene is laid out on the 1200x675 design frame.
	next.position=Vector2.ZERO
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	_input_below_content(next,out,P_INV+"ScrollView_Item")
	_input_below_content(next,out,P_ENCHANT+"Nd_TextSet/ScrollView")
	_bag.bind(_row(next,out,P_INV+"ScrollView_Item/Inventory_Slot_Set"),maxi(1,ceili(float(listing.size())/float(SET_SLOTS.size()))),ROW_PITCH,ROW_TAIL)
	_text.bind(_row(next,out,P_ENCHANT+"Nd_TextSet/ScrollView/TextSet"),maxi(1,rows.size()),TEXT_PITCH,TEXT_TAIL)
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"scroll":_scroll,"tab":_tab,"candidates":_candidates.size(),"listed":listing.size(),"selected":_selected,
		"stat_rows":rows.size(),"pictures":pictures,"bag_pictures":int(filled.get("bag_pictures",0)),"can_enchant":not entry.is_empty()}
	if not _smelt.is_empty():
		last_result["mode"]=_smelt.kind
		last_result["material_uid"]=_smelt.uid
		last_result["can_smelt"]=_smelt_quote.get("ok",false)
	return last_result

func _spec(hud: Node, entry: Dictionary, listing: Array, rows: Array[Dictionary]) -> Dictionary:
	var spec: Dictionary={}
	for page: String in OTHER_PAGES:spec[P_ALL+page]={"exclude":true}
	for tab_name: String in OTHER_TABS:spec[P_COMMON+"Tab/"+tab_name]={"exclude":true}
	for fx: String in ["Fx_Popup_LeftUp","Fx_Popup_RightBottom","Fx_Enchant_Safety","Fx_Item_Active_Right"]:spec[fx]={"exclude":true}
	# The result presentation rests hidden; _play_presentation shows and plays it.
	if _presents:
		spec[P_FX]={"visible":false}
		spec[P_POPUP]={"visible":false}
		for set_name: String in POPUP_SETS:spec[P_POPUP+"/Set/"+set_name+"/Text_Item"]={"role":"source_text","text":" "}
	else:
		spec[P_FX]={"exclude":true}
		spec[P_POPUP]={"exclude":true}
	var has: bool=not entry.is_empty()
	var level: int=int(entry.get("level",0))
	var safe: bool=has and level<int(entry.get("safe_level",0))
	var cursed: bool=_scroll.contains("저주")
	# Frame: 저주 주문서 → Curse; past the safe level → Unsafety; else Bless.
	spec[P_COMMON+"Enchant_Base_Curse"]={"visible":cursed}
	spec[P_COMMON+"Enchant_Base_Unsafety"]={"visible":not cursed and has and not safe}
	spec[P_COMMON+"Enchant_Base_Bless"]={"visible":not cursed and not (has and not safe)}
	# 단일 강화 / 다중 강화 tabs (hidden under the result banner while it plays).
	spec[P_COMMON+"Tab"]={"visible":true}
	spec[P_COMMON+"Tab/Nd_Single"]={"visible":true}
	spec[P_COMMON+"Tab/Nd_Multi"]={"visible":true}
	spec[P_COMMON+"Tab/Nd_Single/Btn_Single_On"]={"visible":not multi}
	spec[P_COMMON+"Tab/Nd_Single/Btn_Single_Off"]={"visible":multi,"activate":Callable(self,"_set_multi").bind(false)}
	spec[P_COMMON+"Tab/Nd_Multi/Btn_Multi_On"]={"visible":multi}
	spec[P_COMMON+"Tab/Nd_Multi/Btn_Multi_Off"]={"visible":not multi,"activate":Callable(self,"_set_multi").bind(true)}
	if multi:
		has=not _picked.is_empty() and _goal>0
		_multi_spec(hud,spec)
	else:spec[P_ALL+"Nd_Enchant_Multi"]={"exclude":true}
	spec[P_COMMON+"Label_Title"]={"role":"source_text","text":_title(entry) if has else ("강화할 장비를 선택하세요" if not _scroll.is_empty() else "강화 주문서를 선택하세요")}
	# Slot0: the scroll; Slot1: the target (TWILIGHT forge order 주문서 + 대상).
	var owned: int=int(_scroll_row.get("count",0))
	for slot: String in ["Inventory_Slot0","Inventory_Slot1"]:
		var key: String=P_COMMON+"Nd_Slot/"+slot+"/"
		spec[key+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		spec[key+"Sp_Select"]={"visible":false}
		var amount: String=(str(owned) if owned>0 else "") if slot=="Inventory_Slot0" else ("+%d" % level if has and level>0 else "")
		spec[key+"Text_Amount"]={"role":"source_text","text":amount,"visible":not amount.is_empty()}
	spec[P_COMMON+"Nd_Slot/Inventory_Slot0/Btn"]={"activate":Callable(self,"_set_tab").bind("scroll")}
	spec[P_COMMON+"Nd_Slot/Inventory_Slot1/Btn"]={"activate":Callable(self,"_set_tab").bind("equip")}
	spec[P_ALL+"Nd_Enchant"]={"visible":not multi}
	# Nd_Enchant: zone, stats, cost, probability.
	spec[P_ENCHANT+"Label_Safe"]={"visible":has and safe}
	spec[P_ENCHANT+"Label_Unsafe"]={"visible":has and not safe}
	spec[P_ENCHANT+"Nd_TextSet"]={"visible":has and not rows.is_empty()}
	spec[P_ENCHANT+"Nd_TextSet/ScrollView"]={"role":"source_scroll","input":Callable(_text,"input")}
	spec.merge(_text_spec(rows,0,P_ENCHANT+"Nd_TextSet/ScrollView/TextSet/"),true)
	var count: int=int(entry.get("count",1))
	var cost: int=int(entry.get("cost",0))
	spec[P_ENCHANT+"Nd_Money"]={"visible":has and count<=1}
	spec[P_ENCHANT+"Nd_Money/Sp_Icon_Bless"]={"visible":false}
	spec[P_ENCHANT+"Nd_Money/Text_Price"]={"role":"source_text","text":_number(cost)}
	spec[P_ENCHANT+"Nd_Blessed_Cost"]={"visible":has and count>1}
	spec[P_ENCHANT+"Nd_Blessed_Cost/Text_Price"]={"role":"source_text","text":_number(cost)}
	spec[P_ENCHANT+"Nd_Blessed_Cost/Text_Scroll_Amount"]={"role":"source_text","text":_number(count)}
	spec[P_ENCHANT+"Btn_Probability"]={"visible":has,"activate":Callable(self,"_probability")}
	spec[P_ENCHANT+"Btn_Probability_Bless"]={"visible":false}
	spec[P_ALL+"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant"]={"activate":Callable(self,"_enchant_requested"),"displaystate":has}
	spec[P_ALL+"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant/Normal"]={"visible":has}
	spec[P_ALL+"Nd_Enchant_Btn/Nd_Enchant/Btn_Enchant/Disabled"]={"visible":not has}
	# Enchant_Inventory: 장비 / 주문서 tabs, owned list, Adena, close.
	spec["Enchant_Inventory_Layout/Nd_Inven/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in ["Nd_Tab/Nd_Dissolve","Nd_Tab/Nd_Delete","Nd_Number","Nd_Grade","Menu_Button"]:spec[P_INV+name]={"exclude":true}
	spec["Enchant_Inventory_Layout/Nd_Inven/Nd_SelectMode"]={"exclude":true}
	var equip: bool=_tab=="equip"
	spec[P_INV+"Nd_Tab/Nd_Equipment/Btn_All_On"]={"visible":equip}
	spec[P_INV+"Nd_Tab/Nd_Equipment/Btn_All_Off"]={"visible":not equip,"activate":Callable(self,"_set_tab").bind("equip")}
	spec[P_INV+"Nd_Tab/Nd_Equipment/Btn_Equip_On"]={"visible":not equip}
	spec[P_INV+"Nd_Tab/Nd_Equipment/Btn_Equip_Off"]={"visible":equip,"activate":Callable(self,"_set_tab").bind("scroll")}
	spec[P_INV+"Nd_Adena/Text_Volume"]={"role":"source_text","text":_number(int(hud.character_state.get("gold",0)))}
	spec[P_INV+"ScrollView_Item"]={"role":"source_scroll","input":Callable(_bag,"input")}
	spec[P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot/Fx_Slot_UnLock"]={"exclude":true}
	spec[P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot_Extension"]={"exclude":true}
	spec[P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot_Extension_Lock"]={"exclude":true}
	spec.merge(_row_spec(listing,0,P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot/"),true)
	if _blessing:
		var tab_path: String=P_COMMON+"Tab/Nd_Bless"
		spec[tab_path]={"visible":true}
		spec[tab_path+"/Btn_Bless_On"]={"visible":true}
		spec[tab_path+"/Btn_Bless_Off"]={"exclude":true}
		spec[P_COMMON+"Tab/Nd_Single"]={"exclude":true}
		spec[P_COMMON+"Tab/Nd_Multi"]={"exclude":true}
		for suffix: String in ["Label_Safe","Label_Unsafe","Nd_Money","Nd_Blessed_Cost","Btn_Probability"]:
			spec[P_ENCHANT+suffix]={"exclude":true}
		spec[P_COMMON+"Enchant_Base_Unsafety"]={"visible":false}
		spec[P_COMMON+"Enchant_Base_Bless"]={"visible":true}
		spec[P_COMMON+"Label_Title"]={"role":"source_text","text":str(entry.get("name","장비 선택")).get_slice(" · 원본#",0)+" · 축복 부여"}
		spec[P_ENCHANT+"Btn_Probability_Bless"]={"visible":has,"activate":Callable(self,"_probability"),"touch_enabled":has}
	if not _smelt.is_empty():_apply_smelt_spec(spec)
	return spec

func _apply_smelt_spec(spec:Dictionary)->void:
	var spirit:bool=_smelt.kind=="spirit_smelt"
	var body:String=P_ALL+("Nd_Enchant_Properties_Smelt" if spirit else "Nd_Enchant_Smelt")
	var tab:String=P_COMMON+"Tab/"+("Nd_Properties_Smelt" if spirit else "Nd_Smelt")
	var tab_button:String="Btn_Properties_Smelt_" if spirit else "Btn_Smelt_"
	var can:bool=_smelt_quote.get("ok",false)
	spec[body]={"visible":true}
	spec[body+"/Nd_Money"]={"visible":can}
	spec[body+"/Nd_Money/Text_Price"]={"role":"source_text","text":_number(int(_smelt_quote.get("gold_cost",0))) if can else ""}
	spec[body+"/Label_Time_Notice"]={"visible":false}
	var content:String="Enchant_Tab_Properties_Smelt" if spirit else "Enchant_Tab_Smelt"
	spec[body+"/"+content+"/Label_Notice"]={"visible":false}
	spec[P_ALL+"Nd_Enchant"]={"exclude":true}
	spec[P_COMMON+"Tab/Nd_Single"]={"exclude":true}
	spec[P_COMMON+"Tab/Nd_Multi"]={"exclude":true}
	spec[tab]={"visible":true}
	spec[tab+"/"+tab_button+"On"]={"visible":true}
	spec[tab+"/"+tab_button+"Off"]={"visible":false}
	spec[P_COMMON+"Label_Title"]={"role":"source_text","text":_smelt_status}
	spec[P_COMMON+"Nd_Slot/Inventory_Slot0/Btn"]={"visible":false}
	spec[P_COMMON+"Nd_Slot/Inventory_Slot0/Text_Amount"]={"role":"source_text","text":str(_smelt.get("quantity",0)),"visible":int(_smelt.get("quantity",0))>0}
	spec[P_INV+"Nd_Tab/Nd_Equipment/Btn_Equip_Off"]={"visible":false}
	var start:String=P_SMELT_START
	spec[start]={"activate":Callable(self,"_smelt_execute"),"displaystate":can}
	spec[start+"/Normal"]={"visible":can}
	spec[start+"/Disabled"]={"visible":not can}
	for state:String in ["Normal","Disabled"]:
		spec[start+"/"+state+"/Label"]={"role":"source_text","text":"제련 시작"}

static func _smelt_body_path(kind:String)->String:
	return P_ALL+("Nd_Enchant_Properties_Smelt/Enchant_Tab_Properties_Smelt" if kind=="spirit_smelt" else "Nd_Enchant_Smelt/Enchant_Tab_Smelt")

func _smelt_action()->Dictionary:
	return {"kind":_smelt.get("kind",""),"target_id":_selected,"material_ids":[str(_smelt.get("uid",""))]}

func _smelt_select(entry:Dictionary)->Dictionary:
	_selected=str(entry.get("target_id",""))
	var hud:Node=_hud.get_ref() if _hud!=null else null
	var world:Node=hud.get_parent() if is_instance_valid(hud) else null
	if not is_instance_valid(world) or not world.has_method("native_smelt523_quote"):return _fail("source_smelt_owner_unavailable")
	_smelt_quote=world.native_smelt523_quote(_smelt_action())
	_smelt_status=("%s · 재료 1개" % str(entry.get("name",""))) if _smelt_quote.get("ok",false) else str(_smelt_quote.get("error","원본 제련 조건을 확인하세요"))
	return _restage()

func _smelt_execute()->Dictionary:
	if _smelt.is_empty() or not _smelt_quote.get("ok",false):return {"ok":false,"handled":true}
	var hud:Node=_hud.get_ref() if _hud!=null else null
	var world:Node=hud.get_parent() if is_instance_valid(hud) else null
	if not is_instance_valid(world) or not world.has_method("native_smelt523_commit"):return _fail("source_smelt_owner_unavailable")
	_smelt_quote.clear()
	var outcome:Dictionary=world.native_smelt523_commit(_smelt_action())
	_smelt_status=str(outcome.get("detail","제련 완료")) if outcome.get("ok",false) else str(outcome.get("error","제련을 완료하지 못했습니다"))
	if outcome.get("ok",false):
		_smelt["quantity"]=maxi(0,int(_smelt.get("quantity",0))-1)
	_restage()
	return outcome


func _text_spec(rows: Array[Dictionary], index: int, prefix: String) -> Dictionary:
	var row: Dictionary=rows[index] if index<rows.size() else {}
	return {prefix+"Text_List_1":{"role":"source_text","text":str(row.get("label",""))},
		prefix+"Text_List_1_0":{"role":"source_text","text":str(row.get("now",""))},
		prefix+"Text_List_1_Value":{"role":"source_text","text":str(row.get("next",""))}}

## Spec of one Inventory_Slot_Set line (four slots from `line`*4).
func _row_spec(listing: Array, line: int, prefix: String) -> Dictionary:
	var spec: Dictionary={}
	for index: int in range(SET_SLOTS.size()):
		var key: String=prefix+SET_SLOTS[index]+"/"
		var at: int=line*SET_SLOTS.size()+index
		var entry: Dictionary=listing[at] if at<listing.size() else {}
		spec[key+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		var reference: String=str(entry.get("target_id",entry.get("reference","")))
		var chosen: bool=not entry.is_empty() and ((reference in _picked if multi else reference==_selected) if _tab=="equip" else reference==_scroll_row.get("reference",""))
		spec[key+"Sp_Select"]={"visible":chosen}
		var text: String=""
		if not entry.is_empty():
			if _tab=="equip":text="+%d" % int(entry.get("level",0)) if int(entry.get("level",0))>0 else ""
			else:text=_number(int(entry.get("count",0)))
		spec[key+"Text_Amount"]={"role":"source_text","text":text,"visible":not text.is_empty()}
		spec[key+"Btn"]={"activate":Callable(self,"_slot_pressed").bind(at,reference)}
	return spec

func _fill_bag(hud: Node, root: Node2D, out: Dictionary, listing: Array) -> Dictionary:
	var pictures: int=0
	var lines: int=maxi(1,ceili(float(listing.size())/float(SET_SLOTS.size())))
	var prefix: String=P_INV+"ScrollView_Item/Inventory_Slot_Set/Nd_Slot/"
	for index: int in range(SET_SLOTS.size()):
		_forward(root,out,prefix+SET_SLOTS[index]+"/Btn",_bag)
		if index<listing.size() and _picture(root,out,prefix+SET_SLOTS[index]+"/Sp_IconSample",Forge.image_record_of(hud,listing[index]),str(listing[index].get("name",""))):pictures+=1
	if lines>1:
		var row: Variant=_row(root,out,P_INV+"ScrollView_Item/Inventory_Slot_Set")
		if not row is Node2D or row.get_parent()==null:return _fail("source_enchant_window_slot_row_missing")
		for line: int in range(1,lines):
			var row_out: Dictionary={}
			var spec: Dictionary=_row_spec(listing,line,"Nd_Slot/")
			spec["Nd_Slot/Fx_Slot_UnLock"]={"exclude":true}
			spec["Nd_Slot_Extension"]={"exclude":true}
			spec["Nd_Slot_Extension_Lock"]={"exclude":true}
			var built: Dictionary=_tree.scene_of(SET,spec,row_out)
			if not built.get("ok",false):return built
			var scene: Node2D=built.scene
			scene.position=row.position+Vector2(0.0,ROW_PITCH*float(line))
			row.get_parent().add_child(scene)
			for index: int in range(SET_SLOTS.size()):
				_forward(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Btn",_bag)
				var at: int=line*SET_SLOTS.size()+index
				if at<listing.size() and _picture(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample",Forge.image_record_of(hud,listing[at]),str(listing[at].get("name",""))):pictures+=1
	return {"ok":true,"bag_pictures":pictures,"pictures":pictures}

func _fill_text(root: Node2D, out: Dictionary, rows: Array[Dictionary]) -> Dictionary:
	if rows.size()<=1:return {"ok":true}
	var row: Variant=_row(root,out,P_ENCHANT+"Nd_TextSet/ScrollView/TextSet")
	if not row is Node2D or row.get_parent()==null:return _fail("source_enchant_window_text_row_missing")
	for index: int in range(1,rows.size()):
		var built: Dictionary=_tree.scene_of(TEXT_SET,_text_spec(rows,index,""),{})
		if not built.get("ok",false):return built
		var scene: Node2D=built.scene
		scene.position=row.position+Vector2(0.0,TEXT_PITCH*float(index))
		row.get_parent().add_child(scene)
	return {"ok":true}

func _row(root: Node2D, out: Dictionary, suffix: String) -> Variant:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return null
	return located.player.source_nodes.get(located.offset)

## The ScrollView's drag area is created above its content; under the
## content the slot buttons receive their taps (drags over them are forwarded
## back to the scroll by _forward).
static func _input_below_content(root: Node2D, out: Dictionary, suffix: String) -> void:
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return
	var node: Variant=located.player.source_nodes.get(located.offset)
	var scroll: Variant=node.get_meta("source_scroll") if is_instance_valid(node) and node.has_meta("source_scroll") else null
	var area: Variant=scroll.input_control() if is_instance_valid(scroll) else null
	if area is Control and area.get_parent()==scroll:scroll.move_child(area,0)

## Dragging over a slot scrolls the list (the slot button keeps its tap).
func _forward(root: Node2D, out: Dictionary, suffix: String, scroller: Scroller) -> void:
	var node: Variant=_row(root,out,suffix)
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) and node.has_meta("source_button") else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if area is Control and not area.gui_input.is_connected(scroller.input):area.gui_input.connect(scroller.input)
	# The bag targets in this window belong to this exact transaction, never
	# to the main inventory PointerTransfer. Route their original button.
	if not _smelt.is_empty() and is_instance_valid(button):
		button.set_meta("source_drag_forward",Callable(scroller,"input"))
		var ancestor:Node=node
		while is_instance_valid(ancestor) and ancestor!=root:
			var identity:Variant=ancestor.get_meta("original_ui_source",{})
			if identity is Dictionary and identity.get("scene")==SLOT:
				ancestor.set_meta("source_slot_routed",true)
			ancestor=ancestor.get_parent()

## The item picture the existing image owner resolves; none -> the slot stays empty.
func _picture(root: Node2D, out: Dictionary, suffix: String, record: Dictionary, title: String) -> bool:
	if record.is_empty():return false
	var located: Dictionary=NamedTree.locate(root,out,suffix)
	if not located.get("ok",false):return false
	var info: Dictionary=SourceImages.describe_item(record,title)
	return NativeIcons.show_item(located.player,located.offset,info,_hud.get_ref())

## --- Actions -----------------------------------------------------------------

func _slot_pressed(index: int, expected: Variant=null) -> Dictionary:
	if not _smelt.is_empty():
		if _bag.moved>12.0 or index<0 or index>=_candidates.size() or int(_smelt.get("quantity",0))<=0:return {"ok":false,"handled":true}
		return _smelt_select(_candidates[index])
	if _bag.moved>12.0:return {"ok":true,"ignored_after_drag":true}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_enchant_window_host_unavailable")
	var listing: Array=_listing(hud)
	if index<0 or index>=listing.size():return {"ok":true,"empty_slot":true}
	var entry: Dictionary=listing[index]
	var reference: String=str(entry.get("target_id",entry.get("reference","")))
	if expected!=null and expected!=reference:return _restage()
	if _tab=="equip":
		if multi:return _toggle_pick(str(entry.get("target_id","")))
		_selected=str(entry.get("target_id",""))
		return _restage()
	var name: String=str(entry.get("name",""))
	if reference==_scroll_row.get("reference",""):return _set_tab("equip")
	# The existing scroll activation: the world reopens this window with that
	# scroll's targets (a 축복 부여 scroll opens its own blessing list).
	hud.inventory_item_activated.emit(reference)
	return {"ok":true,"scroll_activated":name,"reference":reference}

func select_target(target_id: String) -> Dictionary:
	_selected=target_id
	_tab="equip"
	return _restage()

func _set_tab(value: String) -> Dictionary:
	if value=="equip" and _scroll.is_empty():return _notice("강화 주문서를 먼저 선택하세요")
	if value!=_tab:_bag.y=null
	_tab=value
	return _restage()

func _notice(text: String) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud!=null and hud.has_method("show_message"):hud.call("show_message",text)
	return {"ok":true,"notice":text}

## 강화 확률: the chances the existing rule supplies for this target.
func _probability() -> Dictionary:
	var entry: Dictionary=_entry()
	if entry.is_empty():return _fail("source_enchant_window_target_unselected")
	if _blessing:
		return _notice("축복 부여 %.1f%% · %s\n%s" % [float(entry.get("success_chance",0)),str(entry.get("success_basis","")),str(entry.get("bonus_text",""))])
	return _notice("성공 %.1f%% · 유지 %.1f%% · 하락 %.1f%% · 소실 %.1f%% · 성공 강화폭 %s" % [float(entry.get("success_chance",0.0)),float(entry.get("no_change_chance",0.0)),float(entry.get("decrease_chance",0.0)),float(entry.get("destroy_chance",0.0)),str(entry.get("gain_text","+1"))])

## --- 다중 강화 ----------------------------------------------------------------

func _multi_spec(hud: Node, spec: Dictionary) -> void:
	# Nd_Enchant_Multi is authored hidden: the 다중 강화 tab shows it.
	spec[P_ALL+"Nd_Enchant_Multi"]={"visible":true}
	spec[P_MULTI+"Nd_Fx_Enchant_Sound"]={"exclude":true}
	spec[P_MULTI+"Nd_Money"]={"visible":false}
	spec[P_MULTI+"Label_Num"]={"role":"source_text","text":"주문서 필요 수량 %s" % _number(scrolls_needed())}
	spec[P_MULTI+"Btn_Reset"]={"activate":Callable(self,"_reset_multi"),"displaystate":not _picked.is_empty()}
	spec[P_MULTI+"Btn_Reset/Normal"]={"visible":not _picked.is_empty()}
	spec[P_MULTI+"Btn_Reset/Disabled"]={"visible":_picked.is_empty()}
	var slot: String=P_MULTI+"Nd_Slot_Multi/Inventory_Slot/"
	spec[slot+"Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	spec[slot+"Sp_Select"]={"visible":false}
	var count: String="%d개" % _picked.size() if not _picked.is_empty() else ""
	spec[slot+"Text_Amount"]={"role":"source_text","text":count if not count.is_empty() else "0","visible":not count.is_empty()}
	for n: int in range(1,11):
		var key: String=P_MULTI+"Nd_Progress/Nd_Btn_%02d/" % n
		spec[key+"Btn_On"]={"visible":n==_goal,"activate":Callable(self,"_set_goal").bind(n)}
		spec[key+"Btn_Off"]={"visible":n!=_goal,"activate":Callable(self,"_set_goal").bind(n)}
		spec[key+"Nd_Gauge"]={"visible":false}

## The fewest scrolls the picked targets need for the goal (one roll per level
## at the entry's scroll count, every roll a success).
func scrolls_needed() -> int:
	var total: int=0
	for entry: Variant in _candidates:
		if entry is Dictionary and str(entry.get("target_id","")) in _picked:
			total+=maxi(0,_goal-int(entry.get("level",0)))*maxi(1,int(entry.get("count",1)))
	return total

func picked() -> Array[String]:
	return _picked

func goal() -> int:
	return _goal

func _set_multi(value: bool) -> Dictionary:
	if value and _scroll.is_empty():return _notice("강화 주문서를 먼저 선택하세요")
	multi=value
	_tab="equip"
	return _restage()

func _toggle_pick(target_id: String) -> Dictionary:
	if target_id in _picked:_picked.erase(target_id)
	elif _picked.size()>=MULTI_MAX:return _notice("다중 강화는 %d개까지 고를 수 있습니다" % MULTI_MAX)
	else:_picked.append(target_id)
	return _restage()

func _set_goal(n: int) -> Dictionary:
	_goal=n
	return _restage()

func _reset_multi() -> Dictionary:
	_picked.clear()
	_goal=0
	return _restage()

func _multi_requested() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_enchant_window_host_unavailable")
	if _picked.is_empty() or _goal<=0:return _notice("강화할 장비와 목표 단계를 고르세요")
	if is_presenting():return {"ok":true,"ignored_while_presenting":true}
	var targets: Array[String]=_picked.duplicate()
	var goal_level: int=_goal
	var scroll: String=_scroll
	# 강화 시작 starts the series at once (no confirmation step).
	var world: Node=hud.get_parent()
	if world==null or not world.has_method("attempt_enhancement_series"):return _fail("source_enchant_window_series_unavailable")
	var series: Variant=world.call("attempt_enhancement_series",scroll,targets,goal_level)
	var outcome: Dictionary=series if series is Dictionary else {}
	var stop: String=str(outcome.get("stop",""))
	if int(outcome.get("rolls",0))>0:
		present("success" if stop.is_empty() else "fail","+%d 다중 강화 완료" % goal_level if stop.is_empty() else "다중 강화 중단")
	return {"ok":true,"started":"multi","targets":targets.size(),"goal":goal_level,"series":outcome}

## Drops picked targets that left the candidate list (sold, destroyed).
func _prune_picked() -> void:
	var ids: Array=_candidates.map(func(e: Variant) -> String: return str((e as Dictionary).get("target_id","")) if e is Dictionary else "")
	_picked=_picked.filter(func(id: String) -> bool: return id in ids)

func _enchant_requested() -> Dictionary:
	if is_presenting():return {"ok":true,"ignored_while_presenting":true}
	if multi:return _multi_requested()
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var entry: Dictionary=_entry()
	if hud==null or entry.is_empty() or _scroll.is_empty():
		if hud!=null and hud.has_method("show_message"):hud.call("show_message","강화할 장비를 고르세요" if entry.is_empty() else "강화 주문서가 없습니다")
		return _fail("source_enchant_window_target_unselected")
	if _blessing:
		return {"ok":Forge.request_blessing(hud,_scroll,entry,Callable(self,"_finish_blessing").bind(_scroll_row.reference,_selected))}
	# 강화 시작 rolls at once: the original window has no confirmation step.
	return {"ok":Forge.request_target(hud,_scroll,entry),"request_owner":"renewal_forge.request_target"}

func _finish_blessing(reference: String, target: String) -> void:
	if is_open() and _blessing and _scroll_row.get("reference")==reference and _selected==target:_close_requested()

## --- Result presentation ---------------------------------------------------

func presents() -> bool:
	return _presents

func is_presenting() -> bool:
	return not _presentation.is_empty() and is_open()

## The committed result `result` (success / maintain / decrease / destroy)
## of a roll from +from_level to +to_level, shown by the window's own
## presentation. False (nothing shown) when the window is closed or the pack
## lacks the presentation members.
func present_result(result: String, from_level: int, to_level: int) -> bool:
	return present("success" if result=="success" else "fail",result_text(result,from_level,to_level))

## TWILIGHT 근사: the banner's Text_Item text (the client's string is not in
## the 523 tables). Item names are not repeated here (Label_Title has it).
static func result_text(result: String, from_level: int, to_level: int) -> String:
	match result:
		"success":return "+%d 강화 성공" % to_level
		"decrease":return "강화 실패 +%d → +%d" % [from_level,to_level]
		"destroy":return "강화 실패 · 장비 소실"
	return "강화 실패 · +%d 유지" % from_level

func presentation_problem() -> String:
	return _last_presentation_problem

func present(kind: String, text: String) -> bool:
	_last_presentation_problem = ""
	if not _presents or not is_open():
		_last_presentation_problem = "source_enchant_result_members_unavailable"
		return false
	if is_presenting(): return false
	_token+=1
	_presentation={"kind":"success" if kind=="success" else "fail","text":text,"token":_token}
	if not _play_presentation():
		# A configured manifest alone does not prove the projections or
		# clips mounted. Do not consume the committed result or block input.
		end_presentation(_token)
		return false
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var settings: Variant = hud.get_parent().get("presentation_settings") if hud != null and hud.get_parent() != null else null
	if settings is Dictionary and (settings.get("reduced_motion",false) or float(settings.get("impact_intensity",1.0)) <= 0.0):
		var glow: Dictionary = NamedTree.locate(_scene, _last_out, P_FX)
		if glow.get("ok",false): glow.player.set_bound_visible(glow.offset,false)
		_presentation.players[0].stop()
		_hold_presentation(_token)
	elif hud!=null and hud.is_inside_tree():
		hud.get_tree().create_timer(PRESENT_SECONDS,true).timeout.connect(_hold_presentation.bind(_token))
	return true

## Both original message clips fade their text to zero at the end. Keep
## the outcome on its fully opaque authored key until the player dismisses
## it, including when a slow frame spans the entire entrance animation.
func _hold_presentation(token: int) -> void:
	if _presentation.is_empty() or token != _token or not is_open(): return
	var players: Array = _presentation.get("players", [])
	if players.size() < 2 or not is_instance_valid(players[1]): return
	var banner: Node = players[1]
	banner.seek_frame(40.0 if _presentation.kind == "success" else 145.0)
	banner.stop()
	_presentation["held"] = true

## Ends the presentation `token` (the latest when -1): restore the window.
func end_presentation(token: int=-1) -> void:
	if _presentation.is_empty() or (token>=0 and token!=int(_presentation.get("token",-1))):return
	for player: Variant in _presentation.get("players",[]):
		if is_instance_valid(player):player.stop()
	_presentation={}
	if is_instance_valid(_blocker):_blocker.queue_free()
	_blocker=null
	if not is_open():
		_pending_result_refresh={}
		return
	for pair: Array in [[P_FX,false],[P_POPUP,false],[P_TAB,true]]:
		var located: Dictionary=NamedTree.locate(_scene,_last_out,str(pair[0]))
		if located.get("ok",false):located.player.set_bound_visible(located.offset,bool(pair[1]))
	var pending: Dictionary = _pending_result_refresh
	_pending_result_refresh={}
	if not pending.is_empty():update(pending.scroll,pending.candidates,bool(pending.get("blessing",false)))

func _play_presentation() -> bool:
	var played: Array[String]=[]
	var players: Array=[]
	_presentation["players"]=players
	for pair: Array in [[P_FX,"Fx_Enchant_Start"],[P_POPUP,"Success" if _presentation.kind=="success" else "Fail"]]:
		var located: Dictionary=NamedTree.locate(_scene,_last_out,str(pair[0]))
		if not located.get("ok",false):
			_last_presentation_problem="source_enchant_result_projection_missing:"+str(pair[1])
			return false
		var projected: Dictionary=located.player.project_player([located.offset])
		if not projected.get("ok",false):
			_last_presentation_problem="source_enchant_result_player_missing:"+str(pair[1])
			return false
		var player: Variant=projected.player
		if not player.play(str(pair[1]),false).get("ok",false):
			_last_presentation_problem="source_enchant_result_clip_missing:"+str(pair[1])
			return false
		players.append(player)
		played.append(str(pair[1]))
		if not located.player.set_bound_visible(located.offset,true).get("ok",false):
			_last_presentation_problem="source_enchant_result_visibility_failed:"+str(pair[1])
			return false
	# The failure branch keeps explicit maintain/decrease/destroy text even
	# though they all use the one original Fail banner clip.
	var label_path := P_POPUP+"/Set/"+("EnChant_Success" if _presentation.kind=="success" else "EnChant_Fail")+"/Text_Item"
	var label: Dictionary=NamedTree.locate(_scene,_last_out,label_path)
	if not label.get("ok",false) or not label.player.set_bound_text(label.offset,str(_presentation.text)).get("ok",false):
		_last_presentation_problem="source_enchant_result_text_binding_missing"
		return false
	_presentation["played"]=played
	var tab: Dictionary=NamedTree.locate(_scene,_last_out,P_TAB)
	if tab.get("ok",false):tab.player.set_bound_visible(tab.offset,false)
	_block()
	return true

## A tap anywhere during the presentation ends it (and cannot reach the
## window's buttons underneath, so it never starts another roll).
func _block() -> void:
	if is_instance_valid(_blocker) and _blocker.get_parent()==_scene:return
	var blocker:=Control.new()
	blocker.name="EnchantResultTouch"
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	blocker.position=Vector2(-4000.0,-4000.0)
	blocker.size=Vector2(8000.0,8000.0)
	var token: int=int(_presentation.get("token",-1))
	blocker.gui_input.connect(func(event: InputEvent) -> void:
		# Mouse clicks arrive as emulated touches too (emulate_touch_from_mouse).
		if event is InputEventScreenTouch or event is InputEventMouseButton:blocker.accept_event()
		if event is InputEventScreenTouch and event.pressed:
			end_presentation(token))
	_scene.add_child(blocker)
	_blocker=blocker

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
