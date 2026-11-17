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
## - 판 매: Trade_Tab_Sell lists my registrations (Trade_List_Sell: 판매 취소 /
##   회 수 / 판매 실패 / remaining time) and Trade_Inventory the bag
##   (Inventory_Slot_Set lines, 전체 / 장비 / 소모 / 기타). A bag item opens
##   Trade_Popup_Input (KeypadSet for 판매 수량 / 총 판매 금액, 최저 거래 단가,
##   평균 판매 단가, 개당 판매 금액), then Trade_Popup_Register (총 / 개당
##   판매 금액, 등록 수수료, 보유 아데나) registers.
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
const ROOT="UI/Trade/Trade_All.csb"
const TOP_ROW="UI/Trade/Trade_List_Button.csb"
const SUB_ROW="UI/Trade/Trade_List_Button_List.csb"
const ITEM_ROW="UI/Trade/Trade_List_Search_Category.csb"
const RESULT_ROW="UI/Trade/Trade_List_Search_Result.csb"
const SELL_ROW="UI/Trade/Trade_List_Sell.csb"
const CALC_ROW="UI/Trade/Trade_List_Calculate.csb"
const BUY_POPUP="UI/Trade/Trade_Popup_Buy.csb"
const REGISTER_POPUP="UI/Trade/Trade_Popup_Register.csb"
const SET="UI/FloatingUi/Inventory_Slot_Set.csb"
const APPROX="TWILIGHT 근사"
const S="Nd_Server/"
const SEARCH="Nd_Server/Trade_Tab_Search/"
const SELL="Nd_Server/Trade_Tab_Sell/"
const BAG="Nd_Server/Trade_Tab_Sell/Trade_Inventory/Nd_Inventory/"
const INPUT="Nd_Server/Trade_Popup_Input/"
const TABS={"search":"Btn_Search","sell":"Btn_Sell","calculate":"Btn_Calculate","history":"Btn_CalculateList"}
const TAB_NODES={"search":"Trade_Tab_Search","sell":"Trade_Tab_Sell","calculate":"Trade_Tab_Calculate","history":"Trade_Tab_CalculateList"}
const BAG_TABS={"all":"Btn_All","equip":"Btn_Equipment","consume":"Btn_Consume","etc":"Btn_Etc"}
const SET_SLOTS: Array[String]=["Slot_1","Slot_2","Slot_3","Slot_4"]
const ROW_PITCH: float=76.0
const SLOT_HIDDEN: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail"]
var market: RefCounted
var tab: String="search"
var open_top: int=0
var category: int=0
var query: String=""
var result_item: int=0
var popup: String=""
var popup_key: String=""
var bag_tab: String="all"
var input_reference: String=""
var input_count: int=1
var input_price: int=0
var input_field: String="count"
var _editor: LineEdit
var _field: Variant
var _view: Dictionary={}
var _bag_scroll: float=0.0
var _bag_drag: bool=false
var _bag_moved: float=0.0
var _bag_content: Node2D
var _bag_bounds: Vector2=Vector2.ZERO

func required_members() -> Array[String]:
	return [ROOT,TOP_ROW,SUB_ROW,ITEM_ROW,RESULT_ROW,SELL_ROW,CALC_ROW,BUY_POPUP,REGISTER_POPUP,SET]

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
	_bag_scroll=0.0
	return open_window(parent)

func close() -> void:
	_release_editor()
	_bag_content=null
	super.close()

## --- View model ----------------------------------------------------------------

func _collect() -> void:
	_view={}
	match tab:
		"search":
			if result_item>0:_view["listings"]=market.listings(result_item)
			elif category!=0 or not query.is_empty():_view["items"]=market.search(category,query)
			else:_view["items"]=[]
		"sell":
			_view["mine"]=market.my_listings()
			_view["bag"]=_bag_rows()
		"calculate":
			var sold: Array=[]
			for row: Dictionary in market.my_listings():
				if str(row.status)=="sold":sold.append(row)
			_view["sold"]=sold
		"history":_view["history"]=market.history()

func _bag_rows() -> Array:
	var rows: Array=[]
	for row: Dictionary in market.bag_entries():
		if bag_tab=="all" or _kind(row)==bag_tab:rows.append(row)
	return rows

static func _kind(row: Dictionary) -> String:
	if bool(row.equipment):return "equip"
	var record: Dictionary=row.record
	if str(record.get("slot","")).to_lower()=="consumable" or str(record.get("type",""))=="소모품":return "consume"
	return "etc"

## 9999만9999 (the original Text_Volume format).
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
	for absent: String in ["Nd_World","Trade_Popup_Purchase_Batch","Trade_Popup_Loading","Nd_Bg/Fx_Img_BG_Particle","Nd_Bg/Fx_Particle"]:
		spec[absent]={"exclude":true}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_TopMenu/Btn_Server_On"]={"visible":true}
	spec["Nd_TopMenu/Btn_Server_Off"]={"visible":false}
	spec["Nd_TopMenu/Btn_World_On"]={"visible":false}
	spec["Nd_TopMenu/Btn_World_Off"]={"visible":true,"activate":Callable(self,"_world_pressed")}
	for name: String in TABS:
		var on: bool=name==tab
		spec[S+"Nd_TabMenu/"+TABS[name]+"_On"]={"visible":on}
		spec[S+"Nd_TabMenu/"+TABS[name]+"_Off"]={"visible":not on,"activate":Callable(self,"_set_tab").bind(name)}
		if on:spec[S+TAB_NODES[name]]={"visible":true}
		else:spec[S+TAB_NODES[name]]={"exclude":true}
	if popup=="input":spec[S+"Trade_Popup_Input"]={"visible":true}
	else:spec[S+"Trade_Popup_Input"]={"exclude":true}
	if popup=="keypad":spec["Trade_Popup_Keypad"]={"visible":true}
	else:spec["Trade_Popup_Keypad"]={"exclude":true}
	match tab:
		"search":spec.merge(_search_spec(),true)
		"sell":spec.merge(_sell_spec(),true)
		"calculate":spec.merge(_calculate_spec(),true)
		"history":spec.merge(_history_spec(),true)
	if popup=="input":spec.merge(_input_spec(),true)
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
	spec[SEARCH+"Text_Message"]={"visible":not showing_result and items.is_empty()}
	if not showing_result and items.is_empty() and (category!=0 or not query.is_empty()):
		spec[SEARCH+"Text_Message"]["role"]="source_text"
		spec[SEARCH+"Text_Message"]["text"]="등록된 상품이 없습니다."
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
	for absent: String in ["Trade_Popup_Modify_Batch_Layout","Nd_TitleBar/Btn_CheckBox_All","Btn_Re_Registration","Btn_Modify_Batch","Trade_Inventory/Nd_Inventory/ToolTip","Trade_Inventory/Trade_Popup_Lift_Layout"]:
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
	spec[SELL+"Nd_Count/Text_Normal"]={"role":"source_text","text":"판매 등록 %02d/%d" % [active,Market.MAX_SELL_COUNT]}
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
	spec[SELL+"Nd_TaxRate/Text_Volume"]={"role":"source_text","text":"%d%%" % Market.TAX_PERCENT}
	spec[SELL+"Nd_TaxRate/Text_Info"]={"role":"source_text","text":"성 세율 %d%%+기본세율 %d%% (%s)" % [Market.CASTLE_TAX_PERCENT,Market.BASE_TAX_PERCENT,APPROX]}
	# The bag (Trade_Inventory): tabs, count, the first Inventory_Slot_Set line.
	for name: String in BAG_TABS:
		var on: bool=bag_tab==name
		spec[BAG+"Tab/"+BAG_TABS[name]+"_On"]={"visible":on}
		spec[BAG+"Tab/"+BAG_TABS[name]+"_Off"]={"visible":not on,"activate":Callable(self,"_set_bag_tab").bind(name)}
	var bag: Array=_view.get("bag",[])
	spec[BAG+"Label_Count"]={"role":"source_text","text":str(bag.size())}
	spec[BAG+"ScrollView"]={"role":"source_scroll","input":Callable(self,"_bag_input")}
	for name: String in ["Nd_Slot/Fx_Slot_UnLock","Nd_Slot_Extension","Nd_Slot_Extension_Lock"]:spec[BAG+"ScrollView/Inventory_Slot_Set/"+name]={"exclude":true}
	spec.merge(_line_spec(0,BAG+"ScrollView/Inventory_Slot_Set/Nd_Slot/"),true)
	return spec

func _line_spec(line: int, prefix: String) -> Dictionary:
	var spec: Dictionary={}
	var bag: Array=_view.get("bag",[])
	for index: int in range(SET_SLOTS.size()):
		var key: String=prefix+SET_SLOTS[index]+"/"
		var at: int=line*SET_SLOTS.size()+index
		var row: Dictionary=bag[at] if at<bag.size() else {}
		for hidden: String in SLOT_HIDDEN:spec[key+hidden]={"exclude":true}
		spec[key+"Sp_Select"]={"visible":false}
		var text: String=""
		if not row.is_empty():text=("+%d" % int(row.level) if int(row.level)>0 else "") if bool(row.equipment) else (str(int(row.count)) if int(row.count)>1 else "")
		spec[key+"Text_Amount"]={"role":"source_text","text":text,"visible":not text.is_empty()}
		spec[key+"Btn"]={"activate":Callable(self,"_bag_pressed").bind(at)}
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

func _input_spec() -> Dictionary:
	var spec: Dictionary={}
	var row: Dictionary=market.entry(input_reference)
	spec[INPUT+"Nd_World"]={"exclude":true}
	spec[INPUT+"Nd_Server/FullFrameType_A"]={"exclude":true}
	var keys: Dictionary={"Btn_0":"0","Btn_1":"1","Btn_2":"2","Btn_3":"3","Btn_4":"4","Btn_5":"5","Btn_6":"6","Btn_7":"7","Btn_8":"8","Btn_9":"9"}
	for name: String in keys:spec[INPUT+"KeypadSet/"+name]={"activate":Callable(self,"_digit").bind(int(keys[name]))}
	spec[INPUT+"KeypadSet/Btn_Max"]={"activate":Callable(self,"_max")}
	spec[INPUT+"KeypadSet/Btn_Del"]={"activate":Callable(self,"_delete")}
	spec[INPUT+"KeypadSet/Btn_Plus"]={"activate":Callable(self,"_step").bind(1)}
	spec[INPUT+"KeypadSet/Btn_Minus"]={"activate":Callable(self,"_step").bind(-1)}
	var active: int=input_count if input_field=="count" else input_price
	spec[INPUT+"KeypadSet/Text_Volume"]={"role":"source_text","text":str(active)}
	var info: String=INPUT+"Nd_Item_Info/"
	spec[info+"Text_ItemName"]={"role":"source_text","text":str(row.get("name",""))}
	spec[info+"Nd_TextSet/Text_Info"]={"role":"source_text","text":"보유 %d개" % int(row.get("count",0))}
	spec[info+"Nd_TextSet/Text_Info_Skill"]={"visible":false}
	spec[info+"Nd_TextSet/Nd_Set"]={"visible":false}
	var counting: bool=input_field=="count"
	var c: String=info+"Nd_Count/Btn_Count/"
	spec[c+"Btn_Normal"]={"visible":not counting,"activate":Callable(self,"_set_field").bind("count")}
	spec[c+"Btn_Pressed"]={"visible":counting,"activate":Callable(self,"_set_field").bind("count")}
	spec[c+"Btn_Disabled"]={"visible":false}
	spec[c+"Btn_Normal/Text_Volume"]={"role":"source_text","text":str(input_count)}
	spec[c+"Btn_Pressed/Text_Volume"]={"role":"source_text","text":str(input_count)}
	spec[c+"Btn_Pressed/World"]={"visible":false}
	spec[info+"Nd_Count/Text_Volume"]={"visible":false}
	var reference: float=market.reference_unit_price(int(row.get("item_class_id",0)))
	spec[info+"Nd_Price_Minimum/Btn_Minimum"]={"activate":Callable(self,"_price_at_minimum")}
	spec[info+"Nd_Price_Minimum/Text_Volume"]={"role":"source_text","text":_unit(reference)}
	spec[info+"Nd_Avg/Text_Volume"]={"role":"source_text","text":_unit(reference)}
	spec[info+"Nd_Avg/Text_Title"]={"role":"source_text","text":"평균 판매 단가 (근사)"}
	spec[info+"Nd_Price_2/Text_Volume"]={"role":"source_text","text":_unit(float(input_price)/float(maxi(1,input_count)))}
	var p: String=info+"Nd_Price_1/Btn_Price/"
	spec[p+"Btn_Normal"]={"visible":counting,"activate":Callable(self,"_set_field").bind("price")}
	spec[p+"Btn_Pressed"]={"visible":not counting,"activate":Callable(self,"_set_field").bind("price")}
	spec[p+"Btn_Normal/Text_Volume"]={"role":"source_text","text":_money(input_price)}
	spec[p+"Btn_Pressed/Text_Volume"]={"role":"source_text","text":_money(input_price)}
	spec[p+"Btn_Pressed/World"]={"visible":false}
	spec[INPUT+"Nd_TaxRate/Text_Volume"]={"role":"source_text","text":"%d%%" % Market.TAX_PERCENT}
	spec[INPUT+"Nd_TaxRate/Text_Info"]={"role":"source_text","text":"성 세율 %d%%+기본세율 %d%% (%s)" % [Market.CASTLE_TAX_PERCENT,Market.BASE_TAX_PERCENT,APPROX]}
	spec[INPUT+"Btn_Yes"]={"activate":Callable(self,"_input_confirmed")}
	spec[INPUT+"Btn_Cancel"]={"activate":Callable(self,"_close_popup")}
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
			var bag: Dictionary=_fill_bag(root,out)
			if not bag.get("ok",false):return bag
			filled["bag"]=bag.rows
			filled["bag_pictures"]=bag.pictures
		"calculate","history":
			var calc: Dictionary=_fill_calc(root,out)
			if not calc.get("ok",false):return calc
			filled["rows"]=calc.rows
	if popup=="input":_input_picture(root,out)
	if popup in ["buy","register"]:
		var shown: Dictionary=_mount_popup(root)
		if not shown.get("ok",false):return shown
		filled["popup_member"]=shown.member
	if popup=="keypad":call_deferred("_attach_editor")
	return filled.merged({"ok":true})

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
	var items: Array=_view.get("items",[])
	var rows: Array=[]
	for row: Dictionary in items:
		var spec: Dictionary=_slot_spec("Common_Slim_ItemSlot/")
		spec["Panel/Btn_SellList"]={"activate":Callable(self,"_item_pressed").bind(int(row.item_class_id))}
		spec["Panel/Text_Volume"]={"role":"source_text","text":_money(int(row.min_price))}
		spec["Panel/Text_Class"]={"visible":false}
		spec["Panel/Text_Info"]={"role":"source_text","text":"매물 %d건" % int(row.count)+(" · "+APPROX if bool(row.approx) else "")}
		spec["Panel/Text__ItemName"]={"role":"source_text","text":str(row.name)}
		rows.append({"member":ITEM_ROW,"spec":spec})
	var listed: Dictionary=_fill_list(root,out,SEARCH+"Tab_Search_Category/ListView",rows)
	if not listed.get("ok",false):return listed
	var pictures: int=0
	for index: int in range((listed.scenes as Array).size()):
		if _class_picture(listed.scenes[index],listed.outs[index],"Common_Slim_ItemSlot/Sp_IconSample",int(items[index].item_class_id)):pictures+=1
	return {"ok":true,"rows":rows.size(),"pictures":pictures}

func _fill_results(root: Node2D, out: Dictionary) -> Dictionary:
	var listings: Array=_view.get("listings",[])
	var rows: Array=[]
	for row: Dictionary in listings:
		var spec: Dictionary=_slot_spec("Common_Slim_ItemSlot/")
		spec["Panel/Btn_Normal"]={"activate":Callable(self,"_listing_pressed").bind(str(row.key))}
		spec["Panel/Btn_Pressed"]={"visible":false}
		spec["Panel/Btn_CheckBox"]={"visible":false}
		spec["Panel/Text_Volume_1"]={"role":"source_text","text":_money(int(row.bundle_price))}
		spec["Panel/Text_Volume_2"]={"role":"source_text","text":_unit(float(row.unit_price))}
		spec["Panel/Text_Time"]={"role":"source_text","text":"%s개" % _money(int(row.bundle_size))}
		spec["Panel/Text_Class"]={"visible":false}
		spec["Panel/Nd_TextSet/Text_Info"]={"role":"source_text","text":(APPROX+" 매물" if bool(row.approx) else "실측 매물")+(" · 남은 %d건" % int(row.available) if int(row.available)>1 else "")}
		spec["Panel/Nd_TextSet/Text_Info_Skill"]={"visible":false}
		spec["Panel/Nd_TextSet/Nd_Set"]={"visible":false}
		spec["Panel/Text_Info"]={"visible":false}
		spec["Panel/Text__ItemName"]={"role":"source_text","text":str(row.name)}
		rows.append({"member":RESULT_ROW,"spec":spec})
	var listed: Dictionary=_fill_list(root,out,SEARCH+"Tab_Search_Result/ListView",rows)
	if not listed.get("ok",false):return listed
	for index: int in range((listed.scenes as Array).size()):
		_class_picture(listed.scenes[index],listed.outs[index],"Common_Slim_ItemSlot/Sp_IconSample",int(listings[index].item_class_id))
	return {"ok":true,"rows":rows.size()}

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
	var info: Dictionary=Images.describe_item_class_row(row)
	if not info.get("texture") is Texture2D:return false
	return _show_picture(located.player,located.offset,{"ok":true,"texture":info.texture,"provenance":info.get("provenance",{}).duplicate(true),"role":"trade_item"})

func _record_picture(scene: Node2D, out: Dictionary, suffix: String, record: Dictionary, title: String) -> bool:
	var located: Dictionary=_locate(scene,out,suffix)
	if not located.get("ok",false) or record.is_empty():return false
	var info: Dictionary=Images.describe_item(record,title)
	if not info.get("texture") is Texture2D:return false
	return _show_picture(located.player,located.offset,{"ok":true,"texture":info.texture,"status":str(info.get("status","")),"provenance":info.get("provenance",{})})

## --- Bag grid ----------------------------------------------------------------

func _fill_bag(root: Node2D, out: Dictionary) -> Dictionary:
	var bag: Array=_view.get("bag",[])
	var first_key: String=BAG+"ScrollView/Inventory_Slot_Set"
	var located: Dictionary=_locate(root,out,first_key)
	if not located.get("ok",false):return located
	var first: Variant=located.player.source_nodes.get(located.offset)
	var content: Node=(first as Node).get_parent() if first is Node else null
	while content!=null and content.name!="SourceOriginalScrollContent":content=content.get_parent()
	if not first is Node2D or not content is Node2D:return _fail("source_trade_window_bag_rows_missing")
	var origin: Vector2=_offset_in(first,content)
	var pictures: int=0
	for index: int in range(mini(SET_SLOTS.size(),bag.size())):
		if _record_picture(root,out,first_key+"/Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample",bag[index].record,str(bag[index].name)):pictures+=1
	var lines: int=maxi(1,ceili(float(bag.size())/float(SET_SLOTS.size())))
	for line: int in range(1,lines):
		var row_out: Dictionary={}
		var spec: Dictionary=_line_spec(line,"Nd_Slot/")
		for name: String in ["Nd_Slot/Fx_Slot_UnLock","Nd_Slot_Extension","Nd_Slot_Extension_Lock"]:spec[name]={"exclude":true}
		var built: Dictionary=_scene_of(SET,spec,row_out,"trade_bag")
		if not built.get("ok",false):return built
		var scene: Node2D=built.scene
		scene.position=origin+Vector2(0.0,ROW_PITCH*float(line))
		content.add_child(scene)
		for index: int in range(SET_SLOTS.size()):
			var at: int=line*SET_SLOTS.size()+index
			_forward(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Btn")
			if at<bag.size() and _record_picture(scene,row_out,"Nd_Slot/"+SET_SLOTS[index]+"/Sp_IconSample",bag[at].record,str(bag[at].name)):pictures+=1
	for index: int in range(SET_SLOTS.size()):_forward(root,out,first_key+"/Nd_Slot/"+SET_SLOTS[index]+"/Btn")
	_bag_content=content
	_bag_bounds=Vector2(content.position.y,minf(content.position.y,content.position.y-(origin.y+ROW_PITCH*float(lines-1)+40.0)))
	_bag_scroll=clampf(_bag_scroll,_bag_bounds.y,_bag_bounds.x)
	content.position.y=_bag_scroll if _bag_scroll!=0.0 else _bag_bounds.x
	_bag_scroll=content.position.y
	call_deferred("_bag_input_below",located.player,located.offset)
	return {"ok":true,"rows":bag.size(),"pictures":pictures}

static func _offset_in(row: Node2D, content: Node2D) -> Vector2:
	var offset: Vector2=row.position
	var node: Node=row.get_parent()
	while node!=null and node!=content:
		if node is Node2D:offset+=(node as Node2D).position
		node=node.get_parent()
	return offset

## The scroll view's drag area sits under the slots, which forward drags.
func _bag_input_below(player: Variant, offset: int) -> void:
	if not is_instance_valid(player):return
	var scroll_node: Variant=player.source_nodes.get(offset)
	var scroll_owner: Node=(scroll_node as Node).get_parent() if scroll_node is Node else null
	while scroll_owner!=null and not scroll_owner.has_meta("source_scroll"):scroll_owner=scroll_owner.get_parent()
	if scroll_owner==null:return
	var scroll: Variant=scroll_owner.get_meta("source_scroll")
	var area: Variant=scroll.input_control() if is_instance_valid(scroll) and scroll.has_method("input_control") else null
	if area is Control and area.get_parent()==scroll:scroll.move_child(area,0)

func _forward(root: Node2D, out: Dictionary, suffix: String) -> void:
	var located: Dictionary=_locate(root,out,suffix)
	if not located.get("ok",false):return
	var node: Variant=located.player.source_nodes.get(located.offset)
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) and node.has_meta("source_button") else null
	var area: Variant=button.get("_input_area") if is_instance_valid(button) else null
	if area is Control and not area.gui_input.is_connected(_bag_input):area.gui_input.connect(_bag_input)

func _bag_input(event: InputEvent) -> void:
	if not is_instance_valid(_bag_content):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_bag_drag=event.pressed
		if event.pressed:_bag_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _bag_drag:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=ROW_PITCH*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	var scale_y: float=absf(_bag_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_bag_moved+=absf(delta)
	_bag_content.position.y=clampf(_bag_content.position.y+delta,_bag_bounds.y,_bag_bounds.x)
	_bag_scroll=_bag_content.position.y

## --- Popups ------------------------------------------------------------------------

func _input_picture(root: Node2D, out: Dictionary) -> void:
	var row: Dictionary=market.entry(input_reference)
	if not row.is_empty():_record_picture(root,out,INPUT+"Nd_Item_Info/Common_Slim_ItemSlot/Sp_IconSample",row.record,str(row.name))

func _mount_popup(root: Node2D) -> Dictionary:
	var member: String=BUY_POPUP if popup=="buy" else REGISTER_POPUP
	var spec: Dictionary=_slot_spec("Common_Slim_ItemSlot/")
	spec["Fx_Popup_LeftUp"]={"exclude":true}
	spec["Fx_Popup_RightBottom"]={"exclude":true}
	spec["Btn_Cancel"]={"activate":Callable(self,"_close_popup")}
	spec["Nd_Item/Nd_TextSet/Text_Info_Skill"]={"visible":false}
	spec["Nd_Item/Nd_TextSet/Nd_Set"]={"visible":false}
	var item_class_id: int=0
	var record: Dictionary={}
	var title: String=""
	if popup=="buy":
		var quoted: Dictionary=market.quote_buy(popup_key)
		var row: Dictionary=quoted.get("row",market.listing(popup_key))
		item_class_id=int(row.get("item_class_id",0))
		spec["Nd_Item/Text__ItemName"]={"role":"source_text","text":str(row.get("name",""))}
		spec["Nd_Item/Nd_TextSet/Text_Info"]={"role":"source_text","text":"%s개" % _money(int(row.get("bundle_size",0)))+(" · "+APPROX if bool(row.get("approx",false)) else "")}
		spec["Nd_Buy_All/Text_Volume"]={"role":"source_text","text":_money(int(row.get("bundle_price",0)))}
		spec["Nd_Buy/Text_Volume"]={"role":"source_text","text":_unit(float(row.get("unit_price",0.0)))}
		spec["Nd_Diamond/Text_Volume"]={"role":"source_text","text":_money(market.diamonds())}
		var reference: float=market.reference_unit_price(item_class_id)
		spec["Nd_Notice"]={"visible":float(row.get("unit_price",0.0))>reference*1.2}
		spec["Text_Message"]={"role":"source_text","text":"구매 하시겠습니까?" if quoted.get("ok",false) else str(quoted.get("reason",""))}
		spec["Btn_Yes"]={"activate":Callable(self,"_buy_confirmed"),"displaystate":quoted.get("ok",false)}
	else:
		var quoted: Dictionary=market.quote_sell(input_reference,input_count,input_price)
		var row: Dictionary=market.entry(input_reference)
		record=row.get("record",{})
		title=str(row.get("name",""))
		spec["Nd_Item/Text__ItemName"]={"role":"source_text","text":title}
		spec["Nd_Item/Nd_TextSet/Text_Info"]={"role":"source_text","text":"수량 %s" % _money(input_count)}
		spec["Nd_Sell_All/Text_Volume"]={"role":"source_text","text":_money(input_price)}
		spec["Nd_Sell/Text_Volume"]={"role":"source_text","text":_unit(float(input_price)/float(maxi(1,input_count)))}
		spec["Nd_Notice"]={"visible":bool(quoted.get("low_warning",false))}
		spec["Nd_Commission/Text_Volume"]={"role":"source_text","text":_money(Market.COMMISSION)}
		spec["Nd_Commission/Text_Title"]={"role":"source_text","text":"등록 수수료 (근사)"}
		var gold: int=int(world().get("gold")) if world()!=null else 0
		spec["Nd_Adena/Text_Volume"]={"role":"source_text","text":_money(gold),"visible":gold>=Market.COMMISSION}
		spec["Nd_Adena/Text_Volume_Lack"]={"role":"source_text","text":_money(gold),"visible":gold<Market.COMMISSION}
		spec["Text_Message"]={"role":"source_text","text":"판매 등록하시겠습니까?" if quoted.get("ok",false) else str(quoted.get("reason",""))}
		spec["Text_Notice_2"]={"role":"source_text","text":"오프라인 거래소: 구매자는 %s 시뮬레이션입니다." % APPROX}
		spec["Btn_Yes"]={"activate":Callable(self,"_register_confirmed"),"displaystate":quoted.get("ok",false)}
	var out: Dictionary={}
	var built: Dictionary=_scene_of(member,spec,out)
	if not built.get("ok",false):return built
	root.add_child(built.scene)
	if item_class_id>0:_class_picture(built.scene,out,"Nd_Item/Common_Slim_ItemSlot/Sp_IconSample",item_class_id)
	elif not record.is_empty():_record_picture(built.scene,out,"Nd_Item/Common_Slim_ItemSlot/Sp_IconSample",record,title)
	return {"ok":true,"member":member}

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
	_message("월드 거래소는 온라인 전용입니다 · 서버 거래소를 이용하세요")
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

func _set_bag_tab(name: String) -> Dictionary:
	bag_tab=name
	_bag_scroll=0.0
	return _stage()

func _bag_pressed(index: int) -> Dictionary:
	if _bag_moved>12.0:return {"ok":true,"ignored_after_drag":true}
	var bag: Array=_view.get("bag",[])
	if index<0 or index>=bag.size():return {"ok":true,"empty_slot":true}
	var row: Dictionary=bag[index]
	if not bool(row.registrable):
		_message(str(row.reason))
		return {"ok":false,"code":"trade_item_not_registrable","reason":str(row.reason)}
	input_reference=str(row.reference)
	input_count=1
	input_field="count"
	input_price=maxi(Market.MIN_SALE_AMOUNT,ceili(market.reference_unit_price(int(row.item_class_id))))
	popup="input"
	return _stage()

func _set_field(name: String) -> Dictionary:
	input_field=name
	return _stage()

func _max_count() -> int:
	return maxi(1,int(market.entry(input_reference).get("count",1)))

func _digit(value: int) -> Dictionary:
	if input_field=="count":input_count=clampi(input_count*10+value,0,_max_count())
	else:input_price=clampi(input_price*10+value,0,Market.MAX_SALE_AMOUNT)
	return _stage()

func _delete() -> Dictionary:
	if input_field=="count":input_count/=10
	else:input_price/=10
	return _stage()

func _max() -> Dictionary:
	if input_field=="count":input_count=_max_count()
	else:input_price=clampi(ceili(market.reference_unit_price(int(market.entry(input_reference).get("item_class_id",0)))*float(maxi(1,input_count))),Market.MIN_SALE_AMOUNT,Market.MAX_SALE_AMOUNT)
	return _stage()

func _step(delta: int) -> Dictionary:
	if input_field=="count":input_count=clampi(input_count+delta,1,_max_count())
	else:input_price=clampi(input_price+delta,0,Market.MAX_SALE_AMOUNT)
	return _stage()

func _price_at_minimum() -> Dictionary:
	input_price=clampi(ceili(market.reference_unit_price(int(market.entry(input_reference).get("item_class_id",0)))*float(maxi(1,input_count))),Market.MIN_SALE_AMOUNT,Market.MAX_SALE_AMOUNT)
	return _stage()

func _input_confirmed() -> Dictionary:
	var quoted: Dictionary=market.quote_sell(input_reference,input_count,input_price)
	if not quoted.get("ok",false):
		_message(str(quoted.get("reason","")))
		return quoted
	popup="register"
	return _stage()

func _register_confirmed() -> Dictionary:
	var result: Dictionary=market.register(input_reference,input_count,input_price)
	_message(str(result.get("message",result.get("reason",""))))
	popup="" if result.get("ok",false) else "input"
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
