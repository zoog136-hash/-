extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 거래소 window (Trade_All, 서버 거래소) over the offline
## trade runtime (scripts/exchange/trade523_market.gd: original category
## tree, frozen real-server rows, TWILIGHT 근사 rows, 판매 / 정산 rules).
## - 검 색: ListView_Button lists the original top categories
##   (Trade_List_Button) and, under the open one, its sub categories
##   (Trade_List_Button_List). Tab_Search_Category lists the items
##   (Trade_List_Search_Category: lowest unit price, listing count);
##   판매 목록 opens Tab_Search_Result (Trade_List_Search_Result rows: bundle
##   price, unit price); a row opens Trade_Popup_Buy, 확 인 buys.
##   Btn_Search opens Trade_Popup_Keypad (its TextField) for a name search;
##   전체 초기화 clears the category and the query.
## - 기존 매물 회수: the authored Trade_Tab_Sell list only shows previous
##   cancellable/expired escrow; inventory and registration controls are excluded.
## - 정 산 / 정산 내역: Trade_Tab_Calculate (sold rows, 정 산) and
##   Trade_Tab_CalculateList (the last 30 days).
## Rows the runtime marks approx show "TWILIGHT 근사". Left out (online-only
## or no TWILIGHT data): 월드 거래소 (Nd_World, its tabs and popups; the top
## button explains), 일괄 구매 / 일괄 수정 / 재등록 / check boxes, 검색 조건
## filter, class filter, sort, favorites, tooltips, 컬렉션 / 제작 이동,
## Trade_Popup_Purchase_Batch (its Atlas_Hud frame is absent from the 523
## client) and the loading popup.
const Market=preload("res://scripts/exchange/trade523_market.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const Images=preload("res://scripts/ui/source523_image_assets.gd")
const NativeIcons=preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd")
const ROOT="UI/Trade/Trade_All.csb"
const TOP_ROW="UI/Trade/Trade_List_Button.csb"
const SUB_ROW="UI/Trade/Trade_List_Button_List.csb"
const ITEM_ROW="UI/Trade/Trade_List_Search_Category.csb"
const RESULT_ROW="UI/Trade/Trade_List_Search_Result.csb"
const SELL_ROW="UI/Trade/Trade_List_Sell.csb"
const CALC_ROW="UI/Trade/Trade_List_Calculate.csb"
const BUY_POPUP="UI/Trade/Trade_Popup_Buy.csb"
const APPROX="TWILIGHT 근사"
const S="Nd_Server/"
const SEARCH="Nd_Server/Trade_Tab_Search/"
const SELL="Nd_Server/Trade_Tab_Sell/"
const TABS={"search":"Btn_Search","sell":"Btn_Sell","calculate":"Btn_Calculate","history":"Btn_CalculateList"}
const TAB_NODES={"search":"Trade_Tab_Search","sell":"Trade_Tab_Sell","calculate":"Trade_Tab_Calculate","history":"Trade_Tab_CalculateList"}
const SLOT_HIDDEN: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail"]
var market: RefCounted
var tab: String="search"
var open_top: int=0
var category: int=0
var query: String=""
var result_item: int=0
var popup: String=""
var popup_key: String=""
var _editor: LineEdit
var _field: Variant
var _view: Dictionary={}

func required_members() -> Array[String]:
	return [ROOT,TOP_ROW,SUB_ROW,ITEM_ROW,RESULT_ROW,SELL_ROW,CALC_ROW,BUY_POPUP]

func _root_member() -> String:
	return ROOT

func open(parent: Node, first_tab: String="search") -> Dictionary:
	var owner: Object=world()
	if owner==null or owner.get("source_shop")==null:return _fail("source_trade_window_runtime_unavailable")
	if market==null:
		market=Market.new()
		var configured: Dictionary=market.configure(owner)
		if not configured.get("ok",false):
			market=null
			return {"ok":false,"handled":false,"code":"source_trade_window_tables_unavailable","problem":str(configured.get("problem",""))}
	tab=first_tab if TABS.has(first_tab) else "search"
	popup=""
	result_item=0
	return open_window(parent)

func close() -> void:
	_release_editor()
	super.close()

## --- View model ----------------------------------------------------------------

func _collect() -> void:
	_view={"reclaimable":market.has_reclaimable()}
	if tab=="sell" and not _view.reclaimable:tab="search"
	if market.has_method("state_problem"):_view["save_problem"]=market.state_problem()
	match tab:
		"search":
			if result_item>0:
				_view["listings"]=market.listings(result_item)
				if market.has_method("price_reference"):_view["price_reference"]=market.price_reference(result_item)
			elif category!=0 or not query.is_empty():_view["items"]=market.search(category,query)
			else:_view["items"]=[]
		"sell":
			_view["mine"]=market.my_listings()
		"calculate":
			var sold: Array=[]
			for row: Dictionary in market.my_listings():
				if str(row.status)=="sold":sold.append(row)
			_view["sold"]=sold
		"history":_view["history"]=market.history()

static func _price_basis(basis: String) -> String:
	match basis:
		"exact":return "동일 아이템 시세"
		"category_grade":return "동일 분류·등급 참고"
		"grade":return "동일 등급 참고"
	return "가격 자료 없음"

static func _money(value: int) -> String:
	if value<10000:return str(value)
	var high: int=value/10000
	var low: int=value%10000
	return "%d만%d" % [high,low] if low>0 else "%d만" % high

static func _unit(value: float) -> String:
	if value>=100.0 or is_equal_approx(value,roundf(value)):return _money(int(roundf(value)))
	return "%.2f" % value

static func _remaining(seconds: int) -> String:
	var minutes: int=seconds/60
	if minutes>=1440:return "%d일 %d시간" % [minutes/1440,(minutes%1440)/60]
	if minutes>=60:return "%d시간 %d분" % [minutes/60,minutes%60]
	return "%d분 %d초" % [minutes,seconds%60]

static func _date(timestamp: int) -> String:
	var d: Dictionary=Time.get_datetime_dict_from_unix_time(timestamp+32400)
	var hour: int=int(d.hour)
	return "%d년 %02d월 %02d일 %s %02d:%02d" % [int(d.year),int(d.month),int(d.day),"오전" if hour<12 else "오후",hour%12 if hour%12!=0 else 12,int(d.minute)]

## --- Spec ------------------------------------------------------------------------

func _spec() -> Dictionary:
	_collect()
	var spec: Dictionary={}
	for absent: String in ["Nd_World","Trade_Popup_Purchase_Batch","Trade_Popup_Loading","Nd_Bg/Fx_Img_BG_Particle","Nd_Bg/Fx_Particle",S+"Trade_Popup_Input"]:
		spec[absent]={"exclude":true}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_TopMenu/Btn_Server_On"]={"visible":true}
	spec["Nd_TopMenu/Btn_Server_On/Label"]={"role":"source_text","text":"로컬 거래소"}
	spec["Nd_TopMenu/Btn_Server_Off"]={"visible":false}
	spec["Nd_TopMenu/Btn_World_On"]={"visible":false}
	spec["Nd_TopMenu/Btn_World_Off"]={"visible":true,"activate":Callable(self,"_world_pressed")}
	for name: String in TABS:
		var on: bool=name==tab
		var button: String=S+"Nd_TabMenu/"+TABS[name]
		if name=="sell" and not _view.reclaimable:
			spec[button+"_On"]={"exclude":true}
			spec[button+"_Off"]={"exclude":true}
		else:
			spec[button+"_On"]={"visible":on}
			spec[button+"_Off"]={"visible":not on,"activate":Callable(self,"_set_tab").bind(name)}
			if name=="sell":
				spec[button+"_On/Label"]={"role":"source_text","text":"기존 매물 회수"}
				spec[button+"_Off/Label"]=spec[button+"_On/Label"]
		spec[S+TAB_NODES[name]]={"visible":true} if on else {"exclude":true}
	if popup=="keypad":spec["Trade_Popup_Keypad"]={"visible":true}
	else:spec["Trade_Popup_Keypad"]={"exclude":true}
	match tab:
		"search":spec.merge(_search_spec(),true)
		"sell":spec.merge(_sell_spec(),true)
		"calculate":spec.merge(_calculate_spec(),true)
		"history":spec.merge(_history_spec(),true)
	if popup=="keypad":spec.merge(_keypad_spec(),true)
	return spec

func _search_spec() -> Dictionary:
	var spec: Dictionary={}
	for absent: String in ["Trade_Tab_Search_Attr","Popup_Filter","Nd_Button_List","Nd_Button_Filter","Nd_Details","Btn_Collection","Btn_Production"]:
		spec[SEARCH+absent]={"exclude":true}
	spec[SEARCH+"Nd_SearchBar/Btn_Reset_All"]={"activate":Callable(self,"_reset_search")}
	spec[SEARCH+"Nd_SearchBar/Btn_Search"]={"activate":Callable(self,"_open_keypad")}
	if not query.is_empty():spec[SEARCH+"Nd_SearchBar/Btn_Search/Text"]={"role":"source_text","text":query}
	var showing_result: bool=result_item>0
	var items: Array=_view.get("items",[])
	var save_issue: String=str(_view.get("save_problem",""))
	var no_listings: bool=showing_result and _view.get("listings",[]).is_empty()
	spec[SEARCH+"Text_Message"]={"visible":not save_issue.is_empty() or no_listings or (not showing_result and items.is_empty())}
	if not save_issue.is_empty():
		spec[SEARCH+"Text_Message"].merge({"role":"source_text","text":"거래소 저장을 확인해 주세요. 기존 내역은 보존됩니다."},true)
	elif no_listings:
		var unavailable: String="비교할 가격 자료가 없습니다." if _view.get("price_reference",{}).is_empty() else "오늘 구매할 수 있는 매물이 없습니다."
		spec[SEARCH+"Text_Message"].merge({"role":"source_text","text":unavailable},true)
	elif not showing_result and items.is_empty() and (category!=0 or not query.is_empty()):
		spec[SEARCH+"Text_Message"].merge({"role":"source_text","text":"일치하는 TWILIGHT 아이템이 없습니다."},true)
	if showing_result:
		spec[SEARCH+"Tab_Search_Category"]={"exclude":true}
		var r: String=SEARCH+"Tab_Search_Result/"
		spec[SEARCH+"Tab_Search_Result"]={"visible":true}
		for absent: String in ["ToolTip_Result","Nd_TitleBar/Btn_CheckBox_All","Btn_Buy_Batch"]:spec[r+absent]={"exclude":true}
		for sort: String in ["Btn_Sort_Up_1","Btn_Sort_Down_1","Btn_Sort_Up_2","Btn_Sort_Down_2"]:spec[r+"Nd_TitleBar/"+sort]={"visible":false}
		spec[r+"Nd_TitleBar/Label_Time"]={"role":"source_text","text":"수 량"}
		spec[r+"Btn_Reset"]={"activate":Callable(self,"_refresh_pressed")}
		spec[r+"Btn_Back"]={"activate":Callable(self,"_back_to_items")}
	else:
		spec[SEARCH+"Tab_Search_Result"]={"exclude":true}
		var c: String=SEARCH+"Tab_Search_Category/"
		spec[SEARCH+"Tab_Search_Category"]={"visible":true}
		for absent: String in ["Common_ButtonSet_Class_Layout","ToolTip_CommonType","Btn_Close"]:spec[c+absent]={"exclude":true}
		spec[c+"Btn_Sort"]={"visible":false}
		spec[c+"Btn_Reset"]={"activate":Callable(self,"_refresh_pressed")}
		var title: String=market.category_name(category) if category!=0 else ("검색: "+query if not query.is_empty() else "")
		spec[c+"Nd_TitleBar/Label_Num"]={"role":"source_text","text":title}
	return spec

func _sell_spec() -> Dictionary:
	var spec: Dictionary={}
	for absent: String in ["Trade_Popup_Modify_Batch_Layout","Nd_TitleBar/Btn_CheckBox_All","Btn_Re_Registration","Btn_Modify_Batch","Trade_Inventory","Nd_TaxRate"]:
		spec[SELL+absent]={"exclude":true}
	var mine: Array=_view.get("mine",[])
	var active: int=0
	var expired: int=0
	var selling: int=0
	var total: int=0
	for row: Dictionary in mine:
		if str(row.status)!="sold":active+=1
		if str(row.status)=="expired":expired+=1
		if str(row.status)=="selling":
			selling+=1
			total+=int(row.price)
	spec[SELL+"Nd_Count/Text_Normal"]={"role":"source_text","text":"회수할 매물 %d건" % active}
	spec[SELL+"Nd_Count/Text_Full"]={"visible":false}
	spec[SELL+"Nd_Count/Text_Disabled"]={"visible":false}
	spec[SELL+"Nd_TotalAmount/Text_Volume"]={"role":"source_text","text":_money(total)}
	spec[SELL+"Nd_TotalAmount/Btn_Return_All"]={"activate":Callable(self,"_take_back_all").bind("expired"),"displaystate":expired>0}
	spec[SELL+"Nd_TotalAmount/Btn_Return_All/Normal"]={"visible":expired>0}
	spec[SELL+"Nd_TotalAmount/Btn_Return_All/Disabled"]={"visible":expired==0}
	spec[SELL+"Nd_TotalAmount/Btn_Return_All/Normal/Label"]={"role":"source_text","text":"회 수 (%d)" % expired}
	spec[SELL+"Btn_Cancel"]={"activate":Callable(self,"_take_back_all").bind("selling"),"displaystate":selling>0}
	spec[SELL+"Btn_Cancel/Normal"]={"visible":selling>0}
	spec[SELL+"Btn_Cancel/Disabled"]={"visible":selling==0}
	spec[SELL+"Btn_Cancel/Normal/Label"]={"role":"source_text","text":"일괄 취소 (%d)" % selling}
	spec[SELL+"Text_Message"]={"visible":active==0}
	return spec

func _calculate_spec() -> Dictionary:
	var spec: Dictionary={}
	var p: String=S+"Trade_Tab_Calculate/"
	var sold: Array=_view.get("sold",[])
	var total: int=0
	for row: Dictionary in sold:total+=int(row.net)
	spec[p+"Nd_Count/Text_Normal"]={"role":"source_text","text":"판매 완료 %d건" % sold.size()}
	spec[p+"Nd_Count/Text_Disabled"]={"visible":false}
	spec[p+"Nd_Calculate/Text_Title_Disabled"]={"visible":false}
	spec[p+"Nd_Calculate/Text_Volume"]={"role":"source_text","text":_money(total)}
	spec[p+"Nd_Calculate/Btn_Calculate_All"]={"activate":Callable(self,"_settle"),"displaystate":not sold.is_empty()}
	spec[p+"Nd_Calculate/Btn_Calculate_All/Normal"]={"visible":not sold.is_empty()}
	spec[p+"Nd_Calculate/Btn_Calculate_All/Disabled"]={"visible":sold.is_empty()}
	spec[p+"Nd_Calculate/Btn_Calculate_All/Normal/Label"]={"role":"source_text","text":"정 산 (%d)" % sold.size()}
	spec[p+"Text_Message"]={"visible":sold.is_empty()}
	return spec

func _history_spec() -> Dictionary:
	var spec: Dictionary={}
	var p: String=S+"Trade_Tab_CalculateList/"
	var rows: Array=_view.get("history",[])
	var total: int=0
	for row: Dictionary in rows:total+=int(row.net)
	spec[p+"Nd_Count/Text_Disabled"]={"role":"source_text","text":"정산 내역 %d건" % rows.size()}
	spec[p+"Nd_Calculate/Text_Volume"]={"role":"source_text","text":_money(total)}
	spec[p+"Text_Message"]={"visible":rows.is_empty()}
	return spec

func _keypad_spec() -> Dictionary:
	var spec: Dictionary={}
	var k: String="Trade_Popup_Keypad/"
	spec[k+"Nd_Input_Bar/Nd_TextField/TextField"]={"role":"source_text_field","editor":_search_editor()}
	spec[k+"Nd_Input_Bar/Btn_Search"]={"activate":Callable(self,"_apply_query")}
	spec[k+"Nd_Input_Bar/Btn_Close"]={"activate":Callable(self,"_close_popup")}
	spec[k+"Nd_Input_Bar/Nd_TextField/Btn_Cancel"]={"activate":Callable(self,"_clear_query")}
	return spec

## --- Fill ------------------------------------------------------------------------

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	if _view.reclaimable:_fit_reclaim_label(root,out)
	var filled: Dictionary={"tab":tab,"popup":popup}
	match tab:
		"search":
			var tree: Dictionary=_fill_tree(root,out)
			if not tree.get("ok",false):return tree
			filled["category_rows"]=tree.rows
			if result_item>0:
				var listed: Dictionary=_fill_results(root,out)
				if not listed.get("ok",false):return listed
				filled["listings"]=listed.rows
			else:
				var items: Dictionary=_fill_items(root,out)
				if not items.get("ok",false):return items
				filled["items"]=items.rows
		"sell":
			var mine: Dictionary=_fill_mine(root,out)
			if not mine.get("ok",false):return mine
			filled["mine"]=mine.rows
		"calculate","history":
			var calc: Dictionary=_fill_calc(root,out)
			if not calc.get("ok",false):return calc
			filled["rows"]=calc.rows
	if popup=="buy":
		var shown: Dictionary=_mount_popup(root)
		if not shown.get("ok",false):return shown
		filled["popup_member"]=shown.member
	if popup=="keypad":call_deferred("_attach_editor")
	return filled.merged({"ok":true})

func _fit_reclaim_label(root: Node2D, out: Dictionary) -> void:
	var suffix: String="Btn_Sell_On" if tab=="sell" else "Btn_Sell_Off"
	var located: Dictionary=_locate(root,out,S+"Nd_TabMenu/"+suffix+"/Label")
	if not located.get("ok",false):return
	var owner: Node=located.player.source_nodes.get(located.offset)
	var label: Node2D=owner.get_meta("source_text",null) if is_instance_valid(owner) else null
	if not is_instance_valid(label):return
	# Authored button width 165, left-aligned text at x≈66, and a small
	# right inset. The replacement caption is longer than the original.
	var width: float=label.original_font.get_string_size(str(label.original_options.text),HORIZONTAL_ALIGNMENT_LEFT,-1,int(label.original_options.fontSize)).x
	if width>94.0:label.scale.x=94.0/width

func _fill_tree(root: Node2D, out: Dictionary) -> Dictionary:
	var rows: Array=[]
	var actions: Array=[]
	for top: Dictionary in market.categories():
		var on: bool=int(top.id)==open_top
		var label: String=str(top.name)
		rows.append({"member":TOP_ROW,"spec":{"Panel/Btn_Normal":{"visible":not on,"activate":Callable(self,"_top_pressed").bind(int(top.id))},
			"Panel/Btn_Pressed":{"visible":on,"activate":Callable(self,"_top_pressed").bind(int(top.id))},
			"Panel/Btn_Normal/Label":{"role":"source_text","text":label},"Panel/Btn_Pressed/Label":{"role":"source_text","text":label},
			"Panel/Btn_Pressed/Img_World":{"visible":false},"Panel/Nd_Star":{"visible":false}}})
		if on:
			for child: Dictionary in top.children:
				var picked: bool=int(child.id)==category
				var name: String=str(child.name)
				rows.append({"member":SUB_ROW,"spec":{"Panel/Btn_Normal":{"visible":not picked,"activate":Callable(self,"_category_pressed").bind(int(child.id))},
					"Panel/Btn_Pressed":{"visible":picked,"activate":Callable(self,"_category_pressed").bind(int(child.id))},
					"Panel/Btn_Normal/Label":{"role":"source_text","text":name},"Panel/Btn_Pressed/Label":{"role":"source_text","text":name}}})
	var listed: Dictionary=_fill_list(root,out,SEARCH+"ListView_Button",rows)
	if not listed.get("ok",false):return listed
	return {"ok":true,"rows":rows.size()}

func _slot_spec(prefix: String) -> Dictionary:
	var spec: Dictionary={}
	for hidden: String in SLOT_HIDDEN:spec[prefix+hidden]={"exclude":true}
	spec[prefix+"Sp_Select"]={"visible":false}
	spec[prefix+"Text_Amount"]={"visible":false}
	return spec

func _fill_items(root: Node2D, out: Dictionary) -> Dictionary:
	return _fill_market_list(root,out,SEARCH+"Tab_Search_Category/ListView",_view.get("items",[]),ITEM_ROW,_item_spec)

func _item_spec(row: Dictionary) -> Dictionary:
	var spec: Dictionary=_slot_spec("Common_Slim_ItemSlot/")
	spec["Panel/Btn_SellList"]={"activate":Callable(self,"_item_pressed").bind(int(row.item_class_id))}
	var count: int=int(row.count)
	var label: String="TWILIGHT 매물 %d건 · %s" % [count,_price_basis(str(row.get("price_basis","")))]
	if count==0:label="가격 자료 없음" if str(row.get("price_basis","" )).is_empty() else "오늘 구매 가능 매물 없음"
	spec["Panel/Text_Volume"]={"role":"source_text","text":_unit(float(row.get("unit_price",row.min_price))) if count>0 else "-"}
	spec["Panel/Text_Class"]={"visible":false}
	spec["Panel/Text_Info"]={"role":"source_text","text":label}
	spec["Panel/Text__ItemName"]={"role":"source_text","text":str(row.name)}
	return spec

func _fill_results(root: Node2D, out: Dictionary) -> Dictionary:
	return _fill_market_list(root,out,SEARCH+"Tab_Search_Result/ListView",_view.get("listings",[]),RESULT_ROW,_result_spec)

func _result_spec(row: Dictionary) -> Dictionary:
	var spec: Dictionary=_slot_spec("Common_Slim_ItemSlot/")
	spec["Panel/Btn_Normal"]={"activate":Callable(self,"_listing_pressed").bind(str(row.key))}
	spec["Panel/Btn_Pressed"]={"visible":false}
	spec["Panel/Btn_CheckBox"]={"visible":false}
	spec["Panel/Text_Volume_1"]={"role":"source_text","text":_money(int(row.bundle_price))}
	spec["Panel/Text_Volume_2"]={"role":"source_text","text":_unit(float(row.unit_price))}
	spec["Panel/Text_Time"]={"role":"source_text","text":"%s개" % _money(int(row.bundle_size))}
	spec["Panel/Text_Class"]={"visible":false}
	spec["Panel/Nd_TextSet/Text_Info"]={"role":"source_text","text":"TWILIGHT · "+_price_basis(str(row.get("price_basis","")))}
	spec["Panel/Nd_TextSet/Text_Info_Skill"]={"visible":false}
	spec["Panel/Nd_TextSet/Nd_Set"]={"visible":false}
	spec["Panel/Text_Info"]={"visible":false}
	spec["Panel/Text__ItemName"]={"role":"source_text","text":str(row.name)}
	return spec

## Search summaries and individual listings are the large market lists.
## Keep their full data and original spacing, but prepare and paint just the
## rows in and near the original clip. Other tabs use their existing lists.
func _fill_market_list(root: Node2D, out: Dictionary, suffix: String, items: Array, member: String, spec: Callable) -> Dictionary:
	var list: Dictionary=_list(root,out,suffix)
	if not list.get("ok",false):return list
	var size: Vector2=list.size
	var geometry: Dictionary=_row_geometry(member)
	var gap: float=float(_node_options(out,suffix).get("itemMargin",0))
	var pitch: float=float(geometry.size.y)+gap
	if size.y<=0.0 or pitch<=0.0:return _fail("source_trade_window_market_list_geometry_invalid")
	var key: String=list.key
	var state: Dictionary={
		"content":list.content,"min":minf(0.0,size.y-items.size()*pitch+gap),"value":0.0,
		"market_rows":items,"member":member,"spec":spec,"size":size,"geometry":geometry,
		"pitch":pitch,"mounted":{},"span":Vector2i(-1,-1),
	}
	var mounted: Dictionary=_mount_market_rows(key,state,0.0)
	if not mounted.get("ok",false):return mounted
	_scrolls[key]=state
	return {"ok":true,"rows":items.size(),"pictures":mounted.pictures}

static func _market_span(count: int, scroll: float, height: float, pitch: float) -> Vector2i:
	var top: float=-scroll
	return Vector2i(maxi(0,floori(top/pitch)-1),mini(count,ceili((top+height)/pitch)+1))

func _mount_market_rows(key: String, state: Dictionary, scroll: float) -> Dictionary:
	var items: Array=state.market_rows
	var size: Vector2=state.size
	var span: Vector2i=_market_span(items.size(),scroll,size.y,state.pitch)
	if span==state.span:return {"ok":true,"pictures":0}
	var mounted: Dictionary=state.mounted
	var prepared: Dictionary={}
	var pictures: int=0
	var spec: Callable=state.spec
	for index: int in range(span.x,span.y):
		if mounted.has(index):continue
		var row: Dictionary=items[index]
		var row_out: Dictionary={}
		var built: Dictionary=_scene_of(state.member,spec.call(row),row_out,key)
		if not built.get("ok",false):
			for pending: Node2D in prepared.values():pending.free()
			return built
		var scene: Node2D=built.scene
		if _class_picture(scene,row_out,"Common_Slim_ItemSlot/Sp_IconSample",int(row.item_class_id)):pictures+=1
		prepared[index]=scene
	# Keep the committed rows and hit targets on a failed scroll build.
	for index: int in mounted.keys():
		if index>=span.x and index<span.y:continue
		var previous: Node2D=mounted[index]
		mounted.erase(index)
		previous.hide()
		previous.queue_free()
	var extent: Vector2=state.geometry.size
	for index: int in prepared:
		var scene: Node2D=prepared[index]
		_place(state.content,scene,state.geometry,Vector2((size.x-extent.x)*0.5,size.y-extent.y-state.pitch*float(index)))
		scene.set_meta(ROW_LIST_META,key)
		_forward_row_drags(scene,key)
		mounted[index]=scene
	state.span=span
	return {"ok":true,"pictures":pictures}

func _scroll_to(key: String, value: float) -> void:
	var state: Dictionary=_scrolls.get(key,{})
	if state.has("market_rows") and is_instance_valid(state.content):
		var mounted: Dictionary=_mount_market_rows(key,state,clampf(value,float(state.min),0.0))
		if not mounted.get("ok",false):return
	super._scroll_to(key,value)

func _fill_mine(root: Node2D, out: Dictionary) -> Dictionary:
	var mine: Array=[]
	for row: Dictionary in _view.get("mine",[]):
		if str(row.status)!="sold":mine.append(row)
	var rows: Array=[]
	for row: Dictionary in mine:
		var status: String=str(row.status)
		var spec: Dictionary=_slot_spec("Common_Slim_ItemSlot/")
		spec["Panel/Btn_CheckBox"]={"visible":false}
		spec["Panel/Text__ItemName"]={"role":"source_text","text":str(row.name)}
		spec["Panel/Text_Volume_1"]={"role":"source_text","text":_money(int(row.price))}
		spec["Panel/Text_Volume_2"]={"role":"source_text","text":_unit(float(row.price)/float(maxi(1,int(row.quantity))))}
		spec["Panel/Text_Class"]={"visible":false}
		spec["Panel/Nd_TextSet/Text_Info"]={"role":"source_text","text":"수량 %s" % _money(int(row.quantity))}
		spec["Panel/Nd_TextSet/Text_Info_Skill"]={"visible":false}
		spec["Panel/Nd_TextSet/Nd_Set"]={"visible":false}
		spec["Panel/Img_Disabled"]={"visible":status=="expired"}
		spec["Panel/Text_Mode_Set/Text_Fail"]={"visible":status=="expired"}
		spec["Panel/Text_Mode_Set/Text_Time"]={"role":"source_text","text":_remaining(int(row.remaining_seconds)),"visible":status=="selling"}
		spec["Panel/Text_Mode_Set/Text_Ready"]={"visible":false}
		spec["Panel/Button_Set/Btn_Cancel"]={"visible":status=="selling","activate":Callable(self,"_take_back").bind(str(row.id))}
		spec["Panel/Button_Set/Btn_Return"]={"visible":status=="expired","activate":Callable(self,"_take_back").bind(str(row.id))}
		spec["Panel/Button_Set/Btn_Server"]={"visible":false}
		rows.append({"member":SELL_ROW,"spec":spec})
	var listed: Dictionary=_fill_list(root,out,SELL+"Nd_Trade_Registration/ListView",rows)
	if not listed.get("ok",false):return listed
	for index: int in range((listed.scenes as Array).size()):
		_class_picture(listed.scenes[index],listed.outs[index],"Common_Slim_ItemSlot/Sp_IconSample",int(mine[index].item_class_id))
	return {"ok":true,"rows":rows.size()}

func _fill_calc(root: Node2D, out: Dictionary) -> Dictionary:
	var history: bool=tab=="history"
	var source: Array=_view.get("history" if history else "sold",[])
	var rows: Array=[]
	for row: Dictionary in source:
		var spec: Dictionary=_slot_spec("Common_Slim_ItemSlot/")
		spec["Panel/Text__ItemName"]={"role":"source_text","text":str(row.name)}
		spec["Panel/Text_Class"]={"visible":false}
		spec["Panel/Nd_TextSet/Text_Info"]={"role":"source_text","text":"수량 %s · 세금 %d%% (%s)" % [_money(int(row.quantity)),Market.TAX_PERCENT,APPROX]}
		spec["Panel/Nd_TextSet/Text_Info_Skill"]={"visible":false}
		spec["Panel/Nd_TextSet/Nd_Set"]={"visible":false}
		spec["Panel/Text_Volume_1"]={"role":"source_text","text":_money(int(row.gross))}
		spec["Panel/Text_Volume_2"]={"role":"source_text","text":_money(int(row.net))}
		spec["Panel/Text_Time"]={"role":"source_text","text":_date(int(row.get("sold_at",row.get("sell_at",0))))}
		spec["Panel/Img_Disabled"]={"visible":history}
		spec["Panel/Text_Notice"]={"visible":false}
		rows.append({"member":CALC_ROW,"spec":spec})
	var list_key: String=S+("Trade_Tab_CalculateList" if history else "Trade_Tab_Calculate")+"/Nd_List/ListView"
	var listed: Dictionary=_fill_list(root,out,list_key,rows)
	if not listed.get("ok",false):return listed
	for index: int in range((listed.scenes as Array).size()):
		_class_picture(listed.scenes[index],listed.outs[index],"Common_Slim_ItemSlot/Sp_IconSample",int(source[index].item_class_id))
	return {"ok":true,"rows":rows.size()}

## The original ItemClass row's own icon; none -> the slot stays empty.
func _class_picture(scene: Node2D, out: Dictionary, suffix: String, item_class_id: int) -> bool:
	var located: Dictionary=_locate(scene,out,suffix)
	if not located.get("ok",false) or not Images.selected():return false
	var row: Dictionary=SOURCE.row("ItemClass",item_class_id)
	if row.is_empty():return false
	return _show_trade_picture(located,Images.describe_item_class_row(row),item_class_id)

func _show_trade_picture(located: Dictionary, info: Dictionary, item_id: int) -> bool:
	if info.get("texture") is Texture2D:
		return _show_picture(located.player,located.offset,{"ok":true,"texture":info.texture,"status":str(info.get("status","")),"provenance":info.get("provenance",{}),"role":"trade_item"})
	var host: Object=hud()
	if not host is Node or info.get("reason")!="unsupported_csb":return false
	var slot: Dictionary=Scene.external_scene_slot_contract(_pack,located.member,located.offset)
	var binding: Dictionary=NativeIcons.request(host,info,{"source_slot_contract":slot,"member":located.member,"node_offset":located.offset,"reference":"m523:item:"+str(item_id)})
	return _show_picture(located.player,located.offset,binding)

## --- Purchase popup -----------------------------------------------------------

func _mount_popup(root: Node2D) -> Dictionary:
	var spec: Dictionary=_slot_spec("Common_Slim_ItemSlot/")
	spec["Fx_Popup_LeftUp"]={"exclude":true}
	spec["Fx_Popup_RightBottom"]={"exclude":true}
	spec["Btn_Cancel"]={"activate":Callable(self,"_close_popup")}
	spec["Nd_Item/Nd_TextSet/Text_Info_Skill"]={"visible":false}
	spec["Nd_Item/Nd_TextSet/Nd_Set"]={"visible":false}
	var quoted: Dictionary=market.quote_buy(popup_key)
	var row: Dictionary=quoted.get("row",market.listing(popup_key))
	var item_class_id: int=int(row.get("item_class_id",0))
	spec["Nd_Item/Text__ItemName"]={"role":"source_text","text":str(row.get("name",""))}
	spec["Nd_Item/Nd_TextSet/Text_Info"]={"role":"source_text","text":"%s개" % _money(int(row.get("bundle_size",0)))+(" · "+APPROX if bool(row.get("approx",false)) else "")}
	spec["Nd_Buy_All/Text_Volume"]={"role":"source_text","text":_money(int(row.get("bundle_price",0)))}
	spec["Nd_Buy/Text_Volume"]={"role":"source_text","text":_unit(float(row.get("unit_price",0.0)))}
	spec["Nd_Diamond/Text_Volume"]={"role":"source_text","text":_money(market.diamonds())}
	var reference: float=market.reference_unit_price(item_class_id)
	spec["Nd_Notice"]={"visible":float(row.get("unit_price",0.0))>reference*1.2}
	spec["Text_Message"]={"role":"source_text","text":"구매 하시겠습니까?" if quoted.get("ok",false) else str(quoted.get("reason",""))}
	spec["Btn_Yes"]={"activate":Callable(self,"_buy_confirmed"),"displaystate":quoted.get("ok",false)}
	var out: Dictionary={}
	var built: Dictionary=_scene_of(BUY_POPUP,spec,out)
	if not built.get("ok",false):return built
	root.add_child(built.scene)
	if item_class_id>0:_class_picture(built.scene,out,"Nd_Item/Common_Slim_ItemSlot/Sp_IconSample",item_class_id)
	return {"ok":true,"member":BUY_POPUP}

func _search_editor() -> LineEdit:
	if not is_instance_valid(_editor):
		_editor=preload("res://scripts/ui/native_touch_line_edit.gd").new()
		_editor.name="TradeWindowSearch"
		_editor.max_length=20
		_editor.visible=false
		var parent: Object=_parent.get_ref() if _parent!=null else null
		if parent is Node:(parent as Node).add_child(_editor)
		_editor.text_submitted.connect(func(_text: String) -> void:_apply_query())
	_editor.text=query
	return _editor

func _attach_editor() -> void:
	if not is_open() or popup!="keypad":return
	var located: Dictionary=_locate(_scene,_out,"Trade_Popup_Keypad/Nd_Input_Bar/Nd_TextField/TextField")
	if not located.get("ok",false):return
	var node: Variant=located.player.source_nodes.get(located.offset)
	var field: Variant=node.get_meta("source_text_field",null) if is_instance_valid(node) and node.has_meta("source_text_field") else null
	if field==null or not field.has_method("attach_editor"):return
	if not field.attach_editor().get("ok",false):return
	_field=field
	if is_instance_valid(_editor):
		_editor.grab_focus()
		if _editor.has_method("edit"):_editor.call("edit")

func _release_editor() -> void:
	# The field hands the editor back before its scene is freed.
	if _field!=null and is_instance_valid(_field) and _field.has_method("release_editor"):_field.release_editor()
	_field=null
	if is_instance_valid(_editor):
		_editor.visible=false
		_editor.release_focus()

## --- Actions -------------------------------------------------------------------

func _world_pressed() -> Dictionary:
	_message("월드 거래소는 온라인 전용입니다 · 로컬 거래소를 이용하세요")
	return {"ok":true,"world_offline":true}

func _set_tab(name: String) -> Dictionary:
	tab=name
	popup=""
	result_item=0
	return _stage()

func _top_pressed(id: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	open_top=0 if open_top==id else id
	category=id
	result_item=0
	return _stage()

func _category_pressed(id: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	category=id
	result_item=0
	return _stage()

func _item_pressed(id: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	result_item=id
	return _stage()

func _back_to_items() -> Dictionary:
	result_item=0
	return _stage()

func _refresh_pressed() -> Dictionary:
	return _stage()

func _reset_search() -> Dictionary:
	category=0
	open_top=0
	query=""
	result_item=0
	if is_instance_valid(_editor):_editor.text=""
	return _stage()

func _open_keypad() -> Dictionary:
	popup="keypad"
	return _stage()

func _apply_query() -> Dictionary:
	if is_instance_valid(_editor) and _editor.has_method("apply_ime"):_editor.call("apply_ime")
	var text: String=_editor.text.strip_edges() if is_instance_valid(_editor) else query
	_release_editor()
	popup=""
	query=text
	category=0 if not text.is_empty() else category
	open_top=0 if not text.is_empty() else open_top
	result_item=0
	return _stage()

func _clear_query() -> Dictionary:
	if is_instance_valid(_editor):_editor.text=""
	return {"ok":true}

func _close_popup() -> Dictionary:
	_release_editor()
	popup=""
	return _stage()

func _listing_pressed(key: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	popup="buy"
	popup_key=key
	return _stage()

func _buy_confirmed() -> Dictionary:
	var result: Dictionary=market.buy(popup_key)
	_message(str(result.get("message",result.get("reason",""))))
	popup=""
	if result.get("ok",false) and market.listings(result_item).is_empty():result_item=0
	_stage()
	return result

func _take_back(id: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var result: Dictionary=market.take_back(id)
	_message(str(result.get("message",result.get("reason",""))))
	_stage()
	return result

func _take_back_all(status: String) -> Dictionary:
	var done: int=0
	var last: Dictionary={}
	for row: Dictionary in market.my_listings():
		if str(row.status)!=status:continue
		last=market.take_back(str(row.id))
		if not last.get("ok",false):break
		done+=1
	_message(("%d건 처리 완료" % done) if last.get("ok",false) or done>0 else str(last.get("reason","처리할 아이템이 없습니다")))
	_stage()
	return {"ok":done>0,"done":done}

func _settle() -> Dictionary:
	var result: Dictionary=market.settle_all()
	_message(str(result.get("message",result.get("reason",""))))
	_stage()
	return result
