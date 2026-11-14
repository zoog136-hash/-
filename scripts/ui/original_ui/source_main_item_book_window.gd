extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 아이템 컬렉션 window (ItemBook_All, partial scope) for the
## 96레벨 증표 컬렉션 of the existing growth96 feature, the only TWILIGHT
## feature built from the original ItemBook tables
## (scripts/progression/growth96_source.gd: ItemBookCollection Level 96,
## ItemBookCard / ItemBookItem tokens, ItemBookCollectionSlotBonus effects).
## Registration is the existing growth96 quote -> confirmation -> execute
## ("register" consumes one 유일의 증표 I and saves); rules stay there.
##
## Only the 레 벨 tab is shown: the other tabs (전체 / 미확인 / 확인 / 던전 /
## 이벤트 / 연금) have no TWILIGHT collection data. Each collection is one
## ItemBook_List_Button row (name, 완성 badge, effect text) with one
## ItemBook_Slot per token requirement; the right side is the collection
## effects (ItemBook_List_Effect) or 컬렉션 현황. The trade purchase popup
## (Trade_Popup_Purchase_Batch, whose Atlas_Hud frame is absent from the 523
## client) is left out of the pack scope; the trade, filter, keypad, replace,
## sort, search, bookmark and grade sidebar are not connected. 레벨 보상 stays
## in the TWILIGHT growth96 view.
const ROOT="UI/ItemBook/ItemBook_All.csb"
const ROW="UI/ItemBook/ItemBook_List_Button.csb"
const SLOT="UI/ItemBook/ItemBook_Slot.csb"
const EFFECT_ROW="UI/ItemBook/ItemBook_List_Effect.csb"
const Images=preload("res://scripts/ui/source523_image_assets.gd")
const Growth96Source=preload("res://scripts/progression/growth96_source.gd")
const T="ItemBook_Tab_Collection/"
const TABS: Array[String]=["Btn_All","Btn_UnIdentified","Btn_Identified","Btn_Dungeon","Btn_Event","Btn_Level","Btn_Alchemy"]
const SHOWN_TAB="Btn_Level"
var showing_status: bool=false
var _snapshot: Dictionary={}

func required_members() -> Array[String]:
	return [ROOT,ROW,SLOT,EFFECT_ROW]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("growth96") if owner!=null else null

func open(parent: Node) -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null:return _fail("source_item_book_runtime_unavailable")
	if not bool(runtime.snapshot().get("ready",false)):return _fail("source_item_book_source_unavailable")
	showing_status=false
	return open_window(parent)

func _tokens() -> int:
	var owner: Object=world()
	return int(owner.inventory.get(Growth96Source.item_key(Growth96Source.TOKEN),0)) if owner!=null else 0

func _spec() -> Dictionary:
	_snapshot=_runtime().snapshot()
	var collections: Array=_snapshot.get("collections",[])
	var registered: int=0
	var required: int=0
	var complete: int=0
	for row: Dictionary in collections:
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
	for tab: String in TABS:
		var on: bool=tab==SHOWN_TAB
		spec["ListView_Tab/"+tab]={"visible":on,"activate":Callable(self,"_ignore")}
		spec["ListView_Tab/%s/On" % tab]={"visible":on}
		spec["ListView_Tab/%s/Off" % tab]={"visible":false}
	# Nd_Amount stays hidden as authored (with one tab it would sit on the
	# tab bar); 컬렉션 현황 shows the same counts.
	# Not connected: sidebar, sort, search, trade info, item detail panels.
	for hidden: String in ["Nd_Tab","Btn_Sort","Btn_Sort2","Nd_SearchBar","Nd_Message"]:
		spec[T+hidden]={"visible":false}
	# The search-miss message (a client "linespacing" number) does not apply:
	# the 96레벨 collections are listed whole.
	spec[T+"Nd_Collection/Text_Message"]={"exclude":true}
	spec[T+"Nd_Info_Set/Text_Title"]={"role":"source_text","text":"컬렉션 현황" if showing_status else "컬렉션 효과"}
	spec[T+"Nd_Info_Set/Nd_Info_Effect"]={"visible":not showing_status}
	spec[T+"Nd_Info_Set/Nd_Info_Condition"]={"visible":showing_status}
	spec[T+"Nd_Info_Set/Nd_Info_Effect/Btn_Collection_Condition"]={"activate":Callable(self,"_toggle_status")}
	spec[T+"Nd_Info_Set/Nd_Info_Condition/Btn_Collection_Effect"]={"activate":Callable(self,"_toggle_status")}
	# The authored ListView_Effect title is the editor sample.
	spec[T+"Nd_Info_Set/Nd_Info_Effect/ListView_Effect/Text_Title"]={"visible":false}
	var condition: String=T+"Nd_Info_Set/Nd_Info_Condition/Panel_Condition/"
	for pair: Array in [["Nd_Item_Register","Text_Num",registered,required],["Nd_Item_Complete","Text_Num_0",complete,collections.size()]]:
		var base: String=condition+str(pair[0])+"/"
		var total: int=int(pair[3])
		spec[base+str(pair[1])]={"role":"source_text","text":"%d%%" % (floori(100.0*float(pair[2])/float(total)) if total>0 else 0)}
		spec[base+"Text_Num_1"]={"role":"source_text","text":str(pair[2])}
		spec[base+"Text_Num_3"]={"role":"source_text","text":str(total)}
	spec[condition+"Nd_Menu_Complete"]={"visible":false}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var collections: Array=_snapshot.get("collections",[])
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
	return {"ok":true,"collections":collections.size(),"slots":slots,"slot_pictures":pictures,"effects":effects.size(),"tokens":_tokens(),"status":showing_status}

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
	var spec: Dictionary={"Panel_Itembook/Bg":{"visible":not done},"Panel_Itembook/Bg_Complete":{"visible":done},
		"Panel_Itembook/Bg_Recommend":{"visible":false},"Panel_Itembook/Bg_Recommend_01":{"visible":false},
		"Panel_Itembook/Fx_Select":{"visible":false},"Panel_Itembook/Icn_BookMark":{"visible":false},
		"ListView_Title/Label_Title":{"role":"source_text","text":"%s (%d/%d)" % [str(row.name),int(row.registered),int(row.required)]},
		"Panel_Badge/Image_Complete":{"visible":done},"Panel_Badge/Image_Recommend":{"visible":false},"Panel_Badge/Image_Recommend_01":{"visible":false},
		"ListView_Title/Label_Lv":{"visible":false},
		"ListView_Option/Label_Option":{"role":"source_text","text":_effect_summary(row)}}
	return {"member":ROW,"spec":spec}

## One ItemBook_Slot per token requirement of a collection row.
func _fill_slots(scene: Node2D, out: Dictionary, row: Dictionary) -> Dictionary:
	var tokens: int=_tokens()
	var specs: Array=[]
	for card: Dictionary in row.get("cards",[]):
		var registered: bool=bool(card.registered)
		specs.append({"member":SLOT,"spec":{"Panel/Item_Own":{"visible":registered},"Panel/Item_Possible":{"visible":not registered and tokens>0},
			"Panel/Text_ItemName":{"visible":false},"Panel/Text_Amount":{"visible":false},"Panel/Fx_Registration":{"visible":false},
			"CommonSlot/Btn":{"activate":Callable(self,"_slot_pressed").bind(str(card.id),registered)}}})
	var placed: Dictionary=_fill_list(scene,out,"Panel_Itembook/CardListView",specs,NAN,true)
	if not placed.get("ok",false):return placed
	var pictures: int=0
	var cards: Array=row.get("cards",[])
	for index: int in range((placed.scenes as Array).size()):
		if _token_picture(placed.scenes[index],placed.outs[index],str(cards[index].id)):pictures+=1
	return {"ok":true,"slots":specs.size(),"pictures":pictures}

## The requirement item's own original icon (the original ItemClass row the
## growth96 view already shows on its 등록 buttons).
func _token_picture(scene: Node2D, out: Dictionary, card_id: String) -> bool:
	var located: Dictionary=_locate(scene,out,"CommonSlot/Sp_IconSample")
	var runtime: Object=_runtime()
	if not located.get("ok",false) or runtime==null or not Images.selected():return false
	var requirement: Dictionary=runtime.source.cards.get(card_id,{}).get("item",{})
	var row: Dictionary=runtime.source.items.get(str(int(requirement.get("ItemClassID",0))),{})
	if row.is_empty():return false
	var info: Dictionary=Images.describe_item_class_row(row)
	if not info.get("texture") is Texture2D:return false
	var owner: Dictionary={"ok":true,"texture":info.texture,"provenance":info.get("provenance",{}).duplicate(true),"role":"item_book_registration_item"}
	return _show_picture(located.player,located.offset,owner)

func _effect_row(row: Dictionary) -> Dictionary:
	var spec: Dictionary={"Panel_Effect/Label_Title":{"role":"source_text","text":"%s (%d/%d)" % [str(row.name),int(row.registered),int(row.required)]},
		"Panel_set/Label_Effect01":{"role":"source_text","text":_effect_text(row)}}
	return {"member":EFFECT_ROW,"spec":spec}

func _toggle_status() -> Dictionary:
	showing_status=not showing_status
	return _stage()

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
	hud().call("confirm_action","증표 등록",str(offer.get("message","")),"등록",func(_count: int=1) -> void:
		var result: Dictionary=runtime.execute("register",id,revision)
		_message(str(result.get("message",result.get("error",""))))
		if is_open():_stage())
	return {"ok":true,"existing_confirmation":true,"id":id}
