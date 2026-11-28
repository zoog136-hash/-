extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 아이템 컬렉션 window (ItemBook_All) over the original
## ItemBook tables: world.item_book523 (scripts/collections/item_book523_*.gd,
## ItemBookCollection by MainTabType: 미확인 / 확인 / 던전 / 이벤트 / 레벨 /
## 연금; the 혈맹 tab is online-only and not listed) and the 96레벨 증표
## collections of the existing growth96 feature (레벨 tab,
## scripts/progression/growth96_source.gd). Each tab button lists its
## collections; 전체 lists them all.
##
## Each collection is one ItemBook_List_Button row (name (등록/전체), 완성 and
## 추천 badges, effect text) with one ItemBook_Slot per card (the original
## item's own icon (no name: the original Text_ItemName stays hidden), Item_Own
## when registered, Item_Possible when the bag holds it; an unregistered card's
## icon is gray and softly blurred). Tapping a slot registers it: the owner's quote ->
## confirmation -> execute consumes the bag item and saves (rules stay in the
## owners). The right side is the shown rows' effects (ItemBook_List_Effect)
## or 컬렉션 현황. Btn_Sort cycles 전체 / 진행 중 / 미완성 / 완성 (TWILIGHT
## 근사, the options of the same ItemBook_Tab_Collection button in the card
## collection window); Btn_Sort2 turns pages of PAGE rows (TWILIGHT 근사: the
## client scrolls one long list; a page keeps the phone's frame time). The
## trade purchase popup (Trade_Popup_Purchase_Batch, whose Atlas_Hud frame is
## absent from the 523 client), filter, keypad, replace, search, bookmark,
## grade sidebar and the item/trade/drop detail panels are not connected.
const ROOT="UI/ItemBook/ItemBook_All.csb"
const ROW="UI/ItemBook/ItemBook_List_Button.csb"
const SLOT="UI/ItemBook/ItemBook_Slot.csb"
const EFFECT_ROW="UI/ItemBook/ItemBook_List_Effect.csb"
const Images=preload("res://scripts/ui/source523_image_assets.gd")
const SourceMaterial=preload("res://scripts/ui/original_ui/source_material.gd")
const Growth96Source=preload("res://scripts/progression/growth96_source.gd")
const T="ItemBook_Tab_Collection/"
const TABS: Array[String]=["Btn_All","Btn_UnIdentified","Btn_Identified","Btn_Dungeon","Btn_Event","Btn_Level","Btn_Alchemy"]
const GROWTH96_TABS: Array[String]=["Btn_All","Btn_Level"]
const PAGE: int=12
## Common_Slot nodes hidden as authored that a collection slot never turns on.
const UNUSED_SLOT_NODES: Array[String]=["Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Select","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Text_Amount","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail","Nd_Collected"]
var showing_status: bool=false
const STATES: Array[String]=["전체","진행 중","미완성","완성"]
var state: int=0
var tab: String="Btn_All"
var page: int=0
var _shown: Array=[]
var _tab_rows: Array=[]
var _pages: int=1
var _focus_item_class_id: int=0
var _focus_item_uid: String=""

func required_members() -> Array[String]:
	return [ROOT,ROW,SLOT,EFFECT_ROW]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("growth96") if owner!=null else null

func _book() -> Object:
	var owner: Object=world()
	return owner.get("item_book523") if owner!=null else null

func _growth96_ready() -> bool:
	var runtime: Object=_runtime()
	return runtime!=null and bool(runtime.snapshot().get("ready",false))

func _book_ready() -> bool:
	var book: Object=_book()
	return book!=null and bool(book.prepare())

func open(parent: Node, item_class_id: int=0, uid: String="") -> Dictionary:
	if _runtime()==null and _book()==null:return _fail("source_item_book_runtime_unavailable")
	if not _book_ready() and not _growth96_ready():return _fail("source_item_book_source_unavailable")
	if item_class_id>0 and (_book()==null or not _book().has_collection_item(item_class_id)):
		return _fail("source_item_book_has_no_matching_collection")
	_focus_item_class_id=item_class_id
	_focus_item_uid=uid
	showing_status=false
	state=0
	page=0
	tab="Btn_All"
	return open_window(parent)

## The collections the sort state shows (진행 중: started, not complete).
static func filtered(collections: Array, state_index: int) -> Array:
	var found: Array=[]
	for row: Dictionary in collections:
		var done: bool=bool(row.get("complete",false))
		if state_index==1 and (done or int(row.get("registered",0))==0):continue
		if state_index==2 and done:continue
		if state_index==3 and not done:continue
		found.append(row)
	return found

## Rows of page `index` (clamped) of `rows`, `size` per page.
static func page_of(rows: Array, index: int, size: int=PAGE) -> Dictionary:
	var pages: int=maxi(1,ceili(float(rows.size())/float(size)))
	var at: int=clampi(index,0,pages-1)
	return {"rows":rows.slice(at*size,mini(rows.size(),(at+1)*size)),"page":at,"pages":pages}

func _cycle_state() -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	state=(state+1)%STATES.size()
	page=0
	return _stage()

func _next_page() -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	page=(page+1)%maxi(1,_pages)
	return _stage()

func _select_tab(button: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if button==tab:return {"ok":true,"unchanged":true}
	tab=button
	page=0
	return _stage()

func _tokens() -> int:
	var owner: Object=world()
	return int(owner.inventory.get(Growth96Source.item_key(Growth96Source.TOKEN),0)) if owner!=null else 0

## Every collection row of the selected tab: the original tables, then the
## 96레벨 증표 collections on 레벨 / 전체.
func _rows_of(button: String) -> Array:
	var rows: Array=[]
	if _focus_item_class_id>0:
		return _book().rows(button,_focus_item_class_id,_focus_item_uid) if _book_ready() else rows
	if _book_ready():rows.append_array(_book().rows(button))
	if button in GROWTH96_TABS and _growth96_ready():
		for row: Dictionary in _runtime().snapshot().get("collections",[]):
			var copy: Dictionary=row.duplicate(true)
			copy["owner"]="growth96"
			rows.append(copy)
	return rows

func _spec() -> Dictionary:
	_tab_rows=_rows_of(tab)
	var registered: int=0
	var required: int=0
	var complete: int=0
	for row: Dictionary in _tab_rows:
		registered+=int(row.registered)
		required+=int(row.required)
		if bool(row.complete):complete+=1
	var spec: Dictionary={}
	# Not connected and left out of the scope: the trade / filter / keypad /
	# replace popups, the filter bar (its labels carry a client "textid"),
	# and the item, effect, trade and drop detail panels.
	for absent: String in ["Trade_Popup_Purchase_Batch_Layout","Trade_Popup_Loading_Layout","ItemBook_Popup_Replace_Layout","ItemBook_Tab_Filter","ItemBook_Popup_Keypad","Nd_Filter"]:
		spec[absent]={"exclude":true}
	for absent: String in ["Nd_Info_Set/TradeInfo","Nd_Info_Set/ItemInfo","Nd_Info_Set/EffectInfo","Nd_Info_Set/Nd_Info_ItemDrop"]:
		spec[T+absent]={"exclude":true}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for button: String in TABS:
		var on: bool=button==tab
		spec["ListView_Tab/"+button]={"visible":true,"activate":Callable(self,"_select_tab").bind(button)}
		spec["ListView_Tab/%s/On" % button]={"visible":on}
		spec["ListView_Tab/%s/Off" % button]={"visible":not on}
	# Nd_Amount stays hidden as authored; 컬렉션 현황 shows the same counts.
	# Not connected: sidebar, search, trade info, item detail panels.
	for hidden: String in ["Nd_Tab","Nd_SearchBar","Nd_Message"]:
		spec[T+hidden]={"visible":false}
	var paged: Dictionary=page_of(filtered(_tab_rows,state),page)
	_shown=[]
	for row: Dictionary in paged.rows:_shown.append(_book().detail(row) if str(row.get("owner",""))=="item_book523" else row)
	page=int(paged.page)
	_pages=int(paged.pages)
	spec[T+"Btn_Sort"]={"visible":true,"activate":Callable(self,"_cycle_state")}
	spec[T+"Btn_Sort/Text_Sort"]={"role":"source_text","text":STATES[state]}
	spec[T+"Btn_Sort2"]={"visible":_pages>1,"activate":Callable(self,"_next_page")}
	spec[T+"Btn_Sort2/Normal"]={"visible":true}
	spec[T+"Btn_Sort2/Enable"]={"visible":false}
	spec[T+"Btn_Sort2/Normal/Text_Sort"]={"role":"source_text","text":"%d/%d" % [page+1,_pages]}
	# The search-miss message (a client "linespacing" number) does not apply:
	# a tab lists its collections whole.
	spec[T+"Nd_Collection/Text_Message"]={"exclude":true}
	spec[T+"Nd_Info_Set/Text_Title"]={"role":"source_text","text":"컬렉션 현황" if showing_status else "컬렉션 효과"}
	spec[T+"Nd_Info_Set/Nd_Info_Effect"]={"visible":not showing_status}
	spec[T+"Nd_Info_Set/Nd_Info_Condition"]={"visible":showing_status}
	spec[T+"Nd_Info_Set/Nd_Info_Effect/Btn_Collection_Condition"]={"activate":Callable(self,"_toggle_status")}
	spec[T+"Nd_Info_Set/Nd_Info_Condition/Btn_Collection_Effect"]={"activate":Callable(self,"_toggle_status")}
	# The authored ListView_Effect title is the editor sample.
	spec[T+"Nd_Info_Set/Nd_Info_Effect/ListView_Effect/Text_Title"]={"visible":false}
	var condition: String=T+"Nd_Info_Set/Nd_Info_Condition/Panel_Condition/"
	for pair: Array in [["Nd_Item_Register","Text_Num",registered,required],["Nd_Item_Complete","Text_Num_0",complete,_tab_rows.size()]]:
		var base: String=condition+str(pair[0])+"/"
		var total: int=int(pair[3])
		spec[base+str(pair[1])]={"role":"source_text","text":"%d%%" % (floori(100.0*float(pair[2])/float(total)) if total>0 else 0)}
		spec[base+"Text_Num_1"]={"role":"source_text","text":str(pair[2])}
		spec[base+"Text_Num_3"]={"role":"source_text","text":str(total)}
	spec[condition+"Nd_Menu_Complete"]={"visible":false}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var collections: Array=_shown
	var rows: Array=[]
	for row: Dictionary in collections:rows.append(_collection_row(row))
	var listed: Dictionary=_fill_list(root,out,T+"Nd_Collection/ListView_Button",rows)
	if not listed.get("ok",false):return listed
	var slots: int=0
	var pictures: int=0
	for index: int in range((listed.scenes as Array).size()):
		var placed: Dictionary=_fill_slots(listed.scenes[index],listed.outs[index],collections[index])
		if not placed.get("ok",false):return placed
		slots+=int(placed.slots)
		pictures+=int(placed.pictures)
	var effects: Array=[]
	for row: Dictionary in collections:effects.append(_effect_row(row))
	var lines: Dictionary=_fill_list(root,out,T+"Nd_Info_Set/Nd_Info_Effect/ListView_Effect",effects)
	if not lines.get("ok",false):return lines
	return {"ok":true,"tab":tab,"state":STATES[state],"page":page,"pages":_pages,"shown":collections.size(),"collections":_tab_rows.size(),"slots":slots,"slot_pictures":pictures,"effects":effects.size(),"tokens":_tokens(),"status":showing_status}

static func _effect_text(row: Dictionary) -> String:
	var names: PackedStringArray=[]
	for effect: Variant in row.get("effects",[]):
		if effect is Dictionary:names.append(str(effect.get("display","")))
	return ", ".join(names)

## The row's one-line option: the first effect and how many more (the
## effect panel lists them all).
static func _effect_summary(row: Dictionary) -> String:
	var effects: Array=row.get("effects",[])
	if effects.size()<=2:return _effect_text(row)
	return "%s 외 %d" % [str(effects[0].get("display","")),effects.size()-1]

func _collection_row(row: Dictionary) -> Dictionary:
	var done: bool=bool(row.complete)
	var recommend: bool=bool(row.get("recommend",false)) and not done
	var spec: Dictionary={"Panel_Itembook/Bg":{"visible":not done and not recommend},"Panel_Itembook/Bg_Complete":{"visible":done},
		"Panel_Itembook/Bg_Recommend":{"visible":recommend},"Panel_Itembook/Bg_Recommend_01":{"exclude":true},
		"Panel_Itembook/Fx_Select":{"exclude":true},"Panel_Itembook/Icn_BookMark":{"exclude":true},"Panel_Itembook/Icon_New":{"exclude":true},
		"ListView_Title/Label_Title":{"role":"source_text","text":"%s (%d/%d)" % [str(row.name),int(row.registered),int(row.required)]},
		"Panel_Badge/Image_Complete":{"visible":done},"Panel_Badge/Image_Recommend":{"visible":recommend},"Panel_Badge/Image_Recommend_01":{"exclude":true},
		"ListView_Title/Label_Lv":{"visible":false},
		"ListView_Option/Label_Option":{"role":"source_text","text":_effect_summary(row)}}
	return {"member":ROW,"spec":spec}

## One card's ItemBook_Slot: Item_Own when registered, Item_Possible when the
## bag holds it, the amount above 1, and no name (the original keeps
## Text_ItemName hidden: the slot is the icon alone).
static func slot_spec(registered: bool, possible: bool, growth: bool, amount: int, press: Callable) -> Dictionary:
	var spec: Dictionary={"Panel/Item_Own":{"visible":registered},"Panel/Item_Possible":{"visible":possible},
		"Panel/Text_ItemName":{"exclude":true},
		"Panel/Text_Amount":{"visible":not growth and amount>1,"role":"source_text","text":_number(amount)},
		"Panel/Fx_Registration":{"exclude":true},"CommonSlot/Btn":{"activate":press,"displaystate":press.is_valid()}}
	# 사용자 목록 8: the Common_Slot layers a collection slot never shows (all
	# hidden as authored) are not built; a page of 40-50 slots built each one
	# with its sprites, materials and back buffers (~10 ms a slot).
	for name: String in UNUSED_SLOT_NODES:spec["CommonSlot/"+name]={"exclude":true}
	return spec

## One ItemBook_Slot per card (growth96: per token requirement).
func _fill_slots(scene: Node2D, out: Dictionary, row: Dictionary) -> Dictionary:
	var growth: bool=str(row.get("owner",""))=="growth96"
	var tokens: int=_tokens() if growth else 0
	var specs: Array=[]
	for card: Dictionary in row.get("cards",[]):
		var registered: bool=bool(card.registered)
		var possible: bool=not registered and (tokens>0 if growth else bool(card.get("possible",false)))
		var amount: int=int(card.get("amount",1))
		var press: Callable=Callable(self,"_slot_pressed").bind(str(card.id),registered) if growth else Callable(self,"_card_pressed").bind(str(row.id),str(card.id),registered)
		if not card.get("focus_match",true):press=Callable()
		specs.append({"member":SLOT,"spec":slot_spec(registered,possible,growth,amount,press)})
	var placed: Dictionary=_fill_list(scene,out,"Panel_Itembook/CardListView",specs,NAN,true)
	if not placed.get("ok",false):return placed
	var pictures: int=0
	var cards: Array=row.get("cards",[])
	var dimmed: int=0
	for index: int in range((placed.scenes as Array).size()):
		var raw: Dictionary=_growth_item_row(str(cards[index].id)) if growth else _item_row(int(cards[index].get("item_class_id",0)))
		if not _item_picture(placed.scenes[index],placed.outs[index],raw):continue
		pictures+=1
		# Not yet registered: the icon in gray, softly blurred (shader only).
		if not bool(cards[index].registered) and _dim_picture(placed.scenes[index],placed.outs[index]):dimmed+=1
	return {"ok":true,"slots":specs.size(),"pictures":pictures,"dimmed":dimmed}

## The slot icon of an unregistered card: gray + soft blur material
## (source_material.gray_blur, TWILIGHT 근사 of the client's gray UI shader).
func _dim_picture(scene: Node2D, out: Dictionary) -> bool:
	var located: Dictionary=_locate(scene,out,"CommonSlot/Sp_IconSample")
	if not located.get("ok",false):return false
	var node: Variant=located.player.source_nodes.get(located.offset)
	var sprite: Variant=node.get_meta("source_sprite") if is_instance_valid(node) and node.has_meta("source_sprite") else null
	if not sprite is Sprite2D or (sprite as Sprite2D).texture==null:return false
	var material: ShaderMaterial=SourceMaterial.gray_blur((sprite as Sprite2D).texture)
	if material==null:return false
	(sprite as Sprite2D).material=material
	return true

func _growth_item_row(card_id: String) -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null:return {}
	var requirement: Dictionary=runtime.source.cards.get(card_id,{}).get("item",{})
	return runtime.source.items.get(str(int(requirement.get("ItemClassID",0))),{})

func _item_row(item_class_id: int) -> Dictionary:
	var book: Object=_book()
	if book==null or item_class_id<=0 or book.source.reader==null:return {}
	return book.source.reader.row("ItemClass",item_class_id)

## The card item's own original icon (its original ItemClass row).
func _item_picture(scene: Node2D, out: Dictionary, row: Dictionary) -> bool:
	var located: Dictionary=_locate(scene,out,"CommonSlot/Sp_IconSample")
	if not located.get("ok",false) or row.is_empty() or not Images.selected():return false
	var info: Dictionary=Images.describe_item_class_row(row)
	info["role"]="item_book_registration_item"
	return _show_item_icon(located.player, located.offset, info)

func _effect_row(row: Dictionary) -> Dictionary:
	var spec: Dictionary={"Panel_Effect/Label_Title":{"role":"source_text","text":"%s (%d/%d)" % [str(row.name),int(row.registered),int(row.required)]},
		"Panel_set/Label_Effect01":{"role":"source_text","text":_effect_text(row)}}
	return {"member":EFFECT_ROW,"spec":spec}

func _toggle_status() -> Dictionary:
	showing_status=not showing_status
	return _stage()

## An original ItemBook card: item_book523 quote -> confirmation -> execute.
func _card_pressed(collection_id: String, card_id: String, registered: bool) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if registered:
		_message("이미 등록한 칸입니다")
		return {"ok":true,"registered":true}
	var book: Object=_book()
	if book==null:return _fail("source_item_book_runtime_unavailable")
	var focus: Dictionary={}
	if _focus_item_class_id>0:focus={"item_class_id":_focus_item_class_id,"uid":_focus_item_uid}
	var offer: Dictionary=book.quote(collection_id,card_id,focus)
	if not offer.get("ok",false):
		_message(str(offer.get("message","등록할 수 없습니다")))
		return {"ok":false,"code":"item_book_register_refused","reason":str(offer.get("code",""))}
	var revision: int=int(offer.revision)
	if not focus.is_empty():focus["offer"]=offer.duplicate(true)
	var review: Control=hud().confirm_item_collection_registration("컬렉션 등록",str(offer.get("message","")),func(_count: int=1) -> void:
		var result: Dictionary=book.execute(collection_id,card_id,revision,focus)
		_message(str(result.get("message","")))
		if is_open():_stage())
	if review==null:
		_message("원본 컬렉션 등록 확인창을 열 수 없습니다.")
		return _fail("source_item_book_registration_review_unavailable")
	return {"ok":true,"existing_confirmation":true,"collection":collection_id,"card":card_id}

## A 96레벨 증표 slot: the existing growth96 quote -> confirmation -> execute.
func _slot_pressed(id: String, registered: bool) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if registered:
		_message("이미 등록한 증표입니다")
		return {"ok":true,"registered":true}
	var runtime: Object=_runtime()
	var offer: Dictionary=runtime.quote("register",id)
	if not offer.get("ok",false):
		_message(str(offer.get("message",offer.get("error","등록할 수 없습니다"))))
		return {"ok":false,"code":"item_book_register_refused"}
	var revision: int=int(offer.revision)
	var review: Control=hud().confirm_item_collection_registration("증표 등록",str(offer.get("message","")),func(_count: int=1) -> void:
		var result: Dictionary=runtime.execute("register",id,revision)
		_message(str(result.get("message",result.get("error",""))))
		if is_open():_stage())
	if review==null:
		_message("원본 증표 등록 확인창을 열 수 없습니다.")
		return _fail("source_item_book_registration_review_unavailable")
	return {"ok":true,"existing_confirmation":true,"id":id}
