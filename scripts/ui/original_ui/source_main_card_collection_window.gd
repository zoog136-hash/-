extends "res://scripts/ui/original_ui/source_main_change_page.gd"
## The original 523 card collection window: Change_WinTotal with its
## Change_CollectionView page. Collections are the existing
## world.card_collections rows (scripts/cards/collection_runtime.gd): each
## is one original Change_List_Collection row (name, 완성 mark, effect text,
## the member cards as Change_Card_A_<grade> with their own pictures). The
## grade sidebar is Change_WinTotal_Class, the effect totals
## Change_List_Collection_Text (현재 | 최대), and 컬렉션 현황 shows the
## acquisition and completion counts. Completion stays automatic in the
## runtime (first acquisition, no card consumed); nothing is registered here.
## Not connected (no TWILIGHT rule or input): the search keypad
## (ItemBook_Popup_Keypad), the effect filter popup (ItemBook_Tab_Filter),
## bookmarks, and the radial progress of the 현황 circles (their
## foreground sprites stay hidden).
const Rules=preload("res://scripts/cards/native_collection_rules.gd")
const SourceUI=preload("res://scripts/ui/source_collection_presentation.gd")
const ROW="UI/Change/Change_List_Collection.csb"
const EFFECT_ROW="UI/Change/Change_List_Collection_Text.csb"
const P="Change_CollectionView/"
const STATES: Array[String]=["전체","진행 중","미완성","완성"]
const MAX_ROWS: int=60
var focus: String=""
var grade: String="전체"
var state: int=0
var showing_status: bool=false
var _rows: Array=[]
var _records: Dictionary={}

func required_members() -> Array[String]:
	return [WIN_TOTAL,ROW,EFFECT_ROW,GRADE_ROW]

func _page() -> String:
	return "Change_CollectionView"

func _tab() -> String:
	return "collection"

func open(parent: Node, category_name: String, identity: String="") -> Dictionary:
	if not Cards.CATEGORIES.has(category_name):return _fail("source_card_collection_category_unsupported")
	if category_name!=category:
		grade="전체"
		state=0
	category=category_name
	focus=identity
	_records.clear()
	return open_window(parent)

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("card_collections") if owner!=null else null

func _filtered() -> Array:
	var result: Array=[]
	for row: Dictionary in _rows:
		if grade!="전체" and str(row.get("grade",""))!=grade:continue
		var done: bool=bool(row.get("completed",false))
		if state==1 and (done or int(row.get("met_count",0))==0):continue
		if state==2 and done:continue
		if state==3 and not done:continue
		result.append(row)
	return result

func _spec() -> Dictionary:
	var runtime: Object=_runtime()
	_rows=runtime.snapshot(category,focus) if runtime!=null else []
	var spec: Dictionary=_frame_spec()
	spec[P+"ItemBook_Tab_Filter"]={"exclude":true}
	spec[P+"ItemBook_Popup_Keypad"]={"exclude":true}
	spec[P+"Nd_Collection/Text_Message"]={"visible":_filtered().is_empty()}
	spec[P+"Btn_Sort"]={"activate":Callable(self,"_cycle_state")}
	spec[P+"Btn_Sort/Text_Sort"]={"role":"source_text","text":STATES[state]}
	spec[P+"Btn_Sort2"]={"activate":Callable(self,"_effect_filter")}
	spec[P+"Btn_Sort2/Enable"]={"visible":false}
	spec[P+"Nd_SearchBar/Btn_Search"]={"activate":Callable(self,"_search")}
	var filtering: bool=grade!="전체" or state!=0 or not focus.is_empty()
	spec[P+"Nd_SearchBar/Btn_Reset_All"]={"activate":Callable(self,"_reset"),"displaystate":filtering}
	spec[P+"Nd_SearchBar/Btn_Reset_All/Normal"]={"visible":filtering}
	spec[P+"Nd_SearchBar/Btn_Reset_All/Disabled"]={"visible":not filtering}
	spec[P+"Nd_Info_Set/Nd_Info_Effect"]={"visible":not showing_status}
	spec[P+"Nd_Info_Set/Nd_Info_Condition"]={"visible":showing_status}
	spec[P+"Nd_Info_Set/Text_Title"]={"role":"source_text","text":"컬렉션 현황" if showing_status else "컬렉션 효과"}
	spec[P+"Nd_Info_Set/Nd_Info_Effect/Btn_Collection_Condition"]={"activate":Callable(self,"_toggle_status")}
	spec[P+"Nd_Info_Set/Nd_Info_Condition/Btn_Collection_Effect"]={"activate":Callable(self,"_toggle_status")}
	# The authored ListView_Effect row is the editor sample; effect rows are
	# original Change_List_Collection_Text scenes.
	spec[P+"Nd_Info_Set/Nd_Info_Effect/ListView_Effect/Panel_set"]={"visible":false}
	var acquired: int=0
	var owner: Object=hud()
	var records: Array=owner.get("catalog_data").get(category,[]) if owner!=null else []
	for record: Variant in records:
		if record is Dictionary and _owned(Cards.card_id(record)):acquired+=1
	var completed: int=0
	for row: Dictionary in _rows:
		if bool(row.get("completed",false)):completed+=1
	for pair: Array in [["Nd_Item_Register",acquired,records.size(),"Text_Num"],["Nd_Item_Complete",completed,_rows.size(),"Text_Num_0"]]:
		var base: String=P+"Nd_Info_Set/Nd_Info_Condition/Panel_Condition/"+str(pair[0])+"/"
		var total: int=int(pair[2])
		spec[base+str(pair[3])]={"role":"source_text","text":"%d%%" % (floori(100.0*float(pair[1])/float(total)) if total>0 else 0)}
		spec[base+"Text_Num_1"]={"role":"source_text","text":str(pair[1])}
		spec[base+"Text_Num_3"]={"role":"source_text","text":str(total)}
		spec[base+("Graph_Register" if pair[0]=="Nd_Item_Register" else "Graph_Complete")]={"visible":false}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	# Grade sidebar.
	var sidebar: Array=[]
	for current: String in SIDEBAR:
		var count: int=0
		var done: int=0
		for row: Dictionary in _rows:
			if current=="전체" or str(row.get("grade",""))==current:
				count+=1
				if bool(row.get("completed",false)):done+=1
		sidebar.append(_grade_row(current,"( %d / %d )" % [done,count],current==grade,Callable(self,"_select_grade").bind(current)))
	var grades: Dictionary=_optional(_fill_list(root,out,P+"Nd_Tab/ListView_Class",sidebar))
	if not grades.get("ok",false):return grades
	# Collection rows.
	var shown: Array=_filtered()
	var rows: Array=[]
	for index: int in range(mini(shown.size(),MAX_ROWS)):rows.append(_collection_row(shown[index]))
	var listed: Dictionary=_optional(_fill_list(root,out,P+"Nd_Collection/ListView_Button",rows))
	if not listed.get("ok",false):return listed
	var cards: int=0
	var pictures: int=0
	for index: int in range((listed.scenes as Array).size()):
		var placed: Dictionary=_fill_cards(listed.scenes[index],listed.outs[index],shown[index])
		if not placed.get("ok",false):return placed
		cards+=int(placed.cards)
		pictures+=int(placed.pictures)
	# Effect totals: current (completed) | possible (every available row).
	var effects: Array=_effect_rows()
	var lines: Dictionary=_optional(_fill_list(root,out,P+"Nd_Info_Set/Nd_Info_Effect/ListView_Effect",effects))
	if not lines.get("ok",false):return lines
	return {"ok":true,"category":category,"collections":_rows.size(),"shown":rows.size(),"cards":cards,"card_pictures":pictures,"effects":effects.size(),"grade":grade,"state":STATES[state],"status":showing_status}

func _collection_row(row: Dictionary) -> Dictionary:
	var done: bool=bool(row.get("completed",false))
	var title: String="%s (%d/%d)" % [str(row.get("name","")),int(row.get("met_count",0)),(row.get("requirements",[]) as Array).size()]
	var effects: PackedStringArray=[]
	for effect: Variant in row.get("effects",[]):
		if effect is Dictionary:effects.append(SourceUI.interval_description(effect))
	var spec: Dictionary={"Panel_Include_Collection":{"exclude":true},
		"Panel_Collection/Bg":{"visible":not done},"Panel_Collection/Bg_Complete":{"visible":done},
		"Panel_Collection/Fx_Select":{"visible":false},"Panel_Collection/Icon_New":{"visible":false},
		"Icn_BookMark/BookMark_On":{"visible":false},
		"ListView_Title/Label_Title":{"role":"source_text","text":title},
		"ListView_Title/Image_Complete":{"visible":done},
		"ListView_Option/Label_Option":{"role":"source_text","text":", ".join(effects)}}
	return {"member":ROW,"spec":spec}

## Member cards of one collection row in its CardListView.
func _fill_cards(scene: Node2D, out: Dictionary, row: Dictionary) -> Dictionary:
	var lookup: Dictionary=_lookup()
	var cards: Array=[]
	var records: Array[Dictionary]=[]
	var owned: Array[bool]=[]
	for requirement: Variant in row.get("requirements",[]):
		if not requirement is Dictionary:continue
		var record: Dictionary=lookup.get(str(requirement.get("category",category))+":"+str(requirement.get("id","")),{})
		if record.is_empty():continue
		var card: Dictionary=_card_row(record,false,Callable(self,"_card_pressed").bind(str(requirement.get("name",""))))
		if card.is_empty():continue
		cards.append(card)
		records.append(record)
		owned.append(bool(requirement.get("met",false)))
	var placed: Dictionary=_fill_list(scene,out,"Panel_Collection/CardListView",cards,NAN,true)
	if not placed.get("ok",false):return placed
	var pictures: int=0
	for index: int in range(cards.size()):
		if _card_picture(placed.scenes[index],placed.outs[index],records[index]):pictures+=1
		# Unowned members keep the game's existing unowned tint.
		if not owned[index]:placed.scenes[index].modulate=preload("res://scripts/ui/catalog_card_ownership.gd").UNOWNED_ICON_TINT
	return {"ok":true,"cards":cards.size(),"pictures":pictures}

## category:card id -> catalog record (built once per open).
func _lookup() -> Dictionary:
	if not _records.is_empty():return _records
	var owner: Object=hud()
	for member_category: String in Cards.CATEGORIES:
		for record: Variant in owner.get("catalog_data").get(member_category,[]):
			if record is Dictionary:_records[member_category+":"+Cards.card_id(record)]=record
	return _records

func _effect_rows() -> Array:
	var runtime: Object=_runtime()
	var active: Dictionary={}
	var possible: Dictionary={}
	var labels: Dictionary={}
	var units: Dictionary={}
	var order: Array[String]=[]
	if runtime==null:return []
	for row: Dictionary in _rows:
		if not bool(row.get("available",true)):continue
		for effect: Dictionary in runtime.displayed_effects(row,true):
			var key: String=SourceUI.effect_identity(effect)
			if not possible.has(key):order.append(key)
			possible[key]=float(possible.get(key,0))+float(effect.value)
			labels[key]=SourceUI.effect_title(effect)
			units[key]=str(effect.get("unit",""))
		if bool(row.get("completed",false)):
			for effect: Dictionary in runtime.displayed_effects(row):
				var key: String=SourceUI.effect_identity(effect)
				active[key]=float(active.get(key,0))+float(effect.value)
	var rows: Array=[]
	for key: String in order:
		var unit: String="%" if units[key]=="percent" else ""
		var on: bool=float(active.get(key,0))!=0.0
		var spec: Dictionary={"Nd_Effect/On":{"visible":on},"Nd_Effect/Off":{"visible":not on}}
		for state_name: String in ["On","Off"]:
			spec["Nd_Effect/%s/Label_Dsc" % state_name]={"role":"source_text","text":str(labels[key])}
			spec["Nd_Effect/%s/Label_Num01" % state_name]={"role":"source_text","text":_value(float(active.get(key,0)))+unit}
			spec["Nd_Effect/%s/Label_Num02" % state_name]={"role":"source_text","text":_value(float(possible[key]))+unit}
		rows.append({"member":EFFECT_ROW,"spec":spec})
	return rows

static func _value(value: float) -> String:
	return ("+" if value>0 else "")+(str(int(value)) if value==floorf(value) else String.num(value,2))

func _select_grade(value: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	grade=value
	return _stage()

func _cycle_state() -> Dictionary:
	state=(state+1)%STATES.size()
	return _stage()

func _toggle_status() -> Dictionary:
	showing_status=not showing_status
	return _stage()

func _reset() -> Dictionary:
	grade="전체"
	state=0
	focus=""
	var owner: Object=hud()
	if owner!=null and owner.get("normal_card_collection_focus")!=null:owner.set("normal_card_collection_focus","")
	return _stage()

func _search() -> Dictionary:
	_message("컬렉션 검색: 원본 검색 키패드(ItemBook_Popup_Keypad)는 연결하지 않았습니다")
	return {"ok":false,"code":"source_collection_search_not_connected"}

func _effect_filter() -> Dictionary:
	_message("효과 필터: 원본 필터 창(ItemBook_Tab_Filter)은 연결하지 않았습니다")
	return {"ok":false,"code":"source_collection_effect_filter_not_connected"}

func _card_pressed(_checked: bool, name: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if not name.is_empty():_message(name)
	return {"ok":true}
