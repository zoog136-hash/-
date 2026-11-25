extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 스킬카드 window over the existing skill card deck 41
## feature (#556: world.skill_card523_deck / _materials / _merge_quote /
## _merge_execute / _levelup_quote / _levelup_execute,
## docs/cards523_reroll_skillcard.md). Rules, rolls, costs and saves are the
## feature's; every action is quote -> HUD confirmation -> execute.
## - 스킬 tab (SkillCard_Tab_Skill): the grade column (SkillCard_List_Class,
##   learned cards per grade), the learned cards (SkillCard_Slot_A: grade
##   frame, the spell's own original icon, Lv), the selected card's info
##   (SkillCard_Tab_Skill_Info: name, grade, the UIBuffCardLevelUpDesc stage
##   texts, the stage gauge, 스킬 강화 / MAX, 스킬 바로가기 -> skills).
## - 스킬 강화 (SkillCard_Popup_Enchant): the card (SkillCard_Slot_B), its
##   stage texts, the same-grade material books (3 x 3 per page, ◀ ▶,
##   자동 선택 / 취소, tap to toggle), the experience before / after, the
##   original success chance and the Adena price; 강화 feeds the chosen books
##   and tries when the gauge is full (else feeds only).
## - 합성 tab (SkillCard_Tab_Compose): the source grades 일반 / 영웅 / 전설
##   with their unlearned books, tap to register (SkillCard_Slot_A), 카드 자동
##   등록, the registered cards, the target and the original merge chance;
##   합 성 runs the existing merge (failure loses the books: OnFailReward false).
## - The popup's 성공 확률 shows the levelup quote's chance; its 전체 button
##   orders the books 전체 / 수량순 / 이름순 (TWILIGHT 근사(근거 약함)).
## Left empty (no TWILIGHT feature or data): 상점 바로가기, 확정 합성, 실패 이력
## 조회 and 실패 횟수 / 합성 시도 보상 gauges, the lock buttons, the grade filter
## of the popup (its books are one grade), the result roulette / reveal and stage 4.
const ROOT="UI/SkillCard/SkillCard_All.csb"
const POPUP="UI/SkillCard/SkillCard_Popup_Enchant.csb"
const CLASS_ROW="UI/SkillCard/SkillCard_List_Class.csb"
const SLOT="UI/SkillCard/SkillCard_Slot_A.csb"
const SLOT_B="UI/SkillCard/SkillCard_Slot_B.csb"
const COMMON_SLOT="UI/CommonUi/Common_Slot.csb"
const SkillImages=preload("res://scripts/ui/source523_skill_buff_images.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const Rows=preload("res://scripts/resources/current523_definition_rows.gd")
## Skill card GradeID -> name and the client's per-grade picture suffix.
const GRADES={1:"일반",4:"영웅",5:"전설",32:"신화"}
const GRADE_SUFFIX={1:"Common",4:"Legend",5:"Epic",32:"Myth"}
const SUFFIXES: Array[String]=["Common","Rare","Unique","Legend","Epic","Myth"]
## Merge source grade -> target grade (BuffCardRuleMergeView deck 41).
const MERGE_TARGET={1:4,4:5,5:32}
const SLOT_EXCLUDED: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Select","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Text_Amount","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail","Nd_Collected"]
const PAGE_SIZE: int=9
const PAGE_ROWS: Array[String]=["ListView_1","ListView_2","ListView_3"]
const GRID_COLUMNS: int=4
const SKILL_DETAIL="SkillCard_Tab_Skill_Info"
const COMPOSE_INFO="SkillCard_Tab_Compose_Info/Nd_Compose/"
const COMPOSE_GRID="SkillCard_Tab_Compose/Nd_SkillList/ListView"
const REGISTERED_LIST=COMPOSE_INFO+"Nd_Card/ListView"
## skill / compose / enchant
var tab: String="skill"
var grade: int=1
var selected: int=-1
var compose_grade: int=1
var registered: Dictionary={}
var feed: Dictionary={}
var page: int=0
## The enchant popup's book order (Btn_Sort "전체"): TWILIGHT 근사(근거 약함),
## docs/original_ui523_approx.md.
const BOOK_ORDERS: Array[String]=["전체","수량순","이름순"]
var book_order: int=0
var _grid_positions: Dictionary={}
var _held_slot: int=-1
var _stage_deck: Variant=null

func required_members() -> Array[String]:
	return [ROOT,POPUP,CLASS_ROW,SLOT,SLOT_B,COMMON_SLOT]

func _root_member() -> String:
	return POPUP if tab=="enchant" else ROOT

func _call(method: String, args: Array=[]) -> Variant:
	var owner: Object=world()
	return owner.callv(method,args) if owner!=null and owner.has_method(method) else null

func open(parent: Node) -> Dictionary:
	if world()==null or not world().has_method("skill_card523_deck"):return _fail("source_skill_card_window_runtime_unavailable")
	tab="skill"
	selected=-1
	registered.clear()
	feed.clear()
	_grid_positions.clear()
	var deck: Array=deck()
	grade=int(deck[0].grade_id) if not deck.is_empty() else 1
	return open_window(parent)

func deck() -> Array:
	var value: Variant=_call("skill_card523_deck")
	return value if value is Array else []

func materials(grade_id: int) -> Array:
	var value: Variant=_call("skill_card523_materials",[grade_id])
	return value if value is Array else []

func _deck_of(grade_id: int) -> Array:
	var found: Array=[]
	for card: Dictionary in (deck() if _stage_deck==null else _stage_deck):
		if int(card.grade_id)==grade_id:found.append(card)
	return found

func _card() -> Dictionary:
	var shown: Array=_deck_of(grade)
	return shown[selected] if selected>=0 and selected<shown.size() else {}

static func grade_text(grade_id: int) -> String:
	var name: String=str(GRADES.get(grade_id,""))
	return name.substr(0,1)+" "+name.substr(1,1) if name.length()==2 else name

static func percent_text(value: float) -> String:
	return ("%.4f" % value).rstrip("0").rstrip(".")+"%"

## --- Spec ---------------------------------------------------------------------

func _spec() -> Dictionary:
	if tab=="enchant":return _enchant_spec()
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_SkillCard_Tab/Btn_BMStore"]={"exclude":true}
	spec["Nd_SkillCard_Tab/Icon_New"]={"visible":false}
	spec["Nd_SkillCard_Tab/Icon_New_1"]={"visible":false}
	spec["Nd_SkillCard_Tab/Btn_Skill_On"]={"visible":tab=="skill","activate":Callable(self,"_tab").bind("skill")}
	spec["Nd_SkillCard_Tab/Btn_Skill_Off"]={"visible":tab!="skill","activate":Callable(self,"_tab").bind("skill")}
	spec["Nd_SkillCard_Tab/Btn_Compose_On"]={"visible":tab=="compose","activate":Callable(self,"_tab").bind("compose")}
	spec["Nd_SkillCard_Tab/Btn_Compose_Off"]={"visible":tab!="compose","activate":Callable(self,"_tab").bind("compose")}
	if tab=="skill":
		spec["SkillCard_Tab_Compose"]={"exclude":true}
		_skill_spec(spec)
	else:
		spec["SkillCard_Tab_Skill"]={"exclude":true}
		_compose_spec(spec)
	return spec

func _skill_spec(spec: Dictionary) -> void:
	var p: String="SkillCard_Tab_Skill/"
	spec[p+"Nd_SelectEffect"]={"exclude":true}
	spec[p+"Nd_SkillList/Label_Notice"]={"visible":_deck_of(grade).is_empty()}
	_skill_detail_spec(spec,_card())

func _skill_detail_spec(spec: Dictionary, card: Dictionary) -> void:
	var i: String=SKILL_DETAIL+"/Nd_Detail/"
	spec[SKILL_DETAIL]={"visible":not card.is_empty()}
	spec[i+"Nd_Title/Label_Skill"]={"role":"source_text","text":str(card.get("name",""))}
	spec[i+"Nd_Info/Label_Class_Value"]={"role":"source_text","text":grade_text(int(card.get("grade_id",0)))}
	spec[i+"Nd_Info/ListView"]={"exclude":true}
	spec[i+"Nd_LvInfo/ListView"]={"exclude":true}
	spec[i+"Nd_LvInfo/Label_None"]={"visible":(card.get("stage_descriptions",{}) as Dictionary).is_empty()}
	for name: String in ["Nd_LvInfo_Btn","Btn_Lock","Btn_Unlock","Nd_Btn_Set/Nd_Move"]:spec[i+name]={"exclude":true}
	var e: String=i+"Nd_Btn_Set/Nd_Enchant/"
	var maxed: bool=not bool(card.get("enhanceable",false))
	var required: int=maxi(1,int(card.get("required_exp",0)))
	var progress: float=100.0*float(card.get("exp",0))/float(required)
	spec[e+"Nd_ProgressBar/Label_Level"]={"role":"source_text","text":"Lv.%d" % int(card.get("level",0))}
	spec[e+"Nd_ProgressBar/Label_Effect"]={"visible":false}
	spec[e+"Nd_ProgressBar/Label_Value"]={"role":"source_text","text":percent_text(progress),"visible":not maxed}
	spec[e+"Nd_ProgressBar/Label_Value_Max"]={"visible":maxed}
	spec[e+"Nd_ProgressBar/ProgressBar"]={"role":"source_percent","percent":100.0 if maxed else clampf(progress,0.0,100.0)}
	spec[e+"Btn_Skill"]={"activate":Callable(self,"_enchant")}
	spec[e+"Btn_Skill/Normal"]={"visible":not maxed}
	spec[e+"Btn_Skill/Disabled"]={"visible":maxed}
	spec[e+"Btn_Move"]={"activate":Callable(self,"_route").bind("open_skills")}

func _compose_spec(spec: Dictionary) -> void:
	var p: String="SkillCard_Tab_Compose/"
	spec[p+"Nd_SelectEffect"]={"exclude":true}
	spec[p+"Nd_Fail_History"]={"exclude":true}
	spec[p+"Nd_SkillList/Label_Notice"]={"visible":materials(compose_grade).is_empty()}
	var c: String=COMPOSE_INFO
	var target: int=int(MERGE_TARGET.get(compose_grade,0))
	spec[c+"Label_Tip"]={"role":"source_text","text":"%s 1장 획득 가능!" % str(GRADES.get(target,""))}
	spec[c+"Btn_Probability"]={"activate":Callable(self,"_merge_probability")}
	for name: String in ["Nd_TabMenu/Btn_Fixed_On","Nd_TabMenu/Btn_Fixed_Off","Nd_TabMenu/Btn_Normal_Off","Nd_Reward","Nd_Fixed","Nd_Reward_All","Nd_Message"]:spec[c+name]={"exclude":true}
	spec[c+"Nd_TabMenu/Btn_Normal_On"]={"activate":Callable(self,"_ignore")}
	spec[c+"Btn_Compose"]={"activate":Callable(self,"_merge")}
	spec[c+"Btn_Auto"]={"activate":Callable(self,"_auto_register")}
	_compose_status_spec(spec)

func _compose_status_spec(spec: Dictionary) -> void:
	var c: String=COMPOSE_INFO
	var quote: Dictionary=_merge_quote()
	var count: int=_registered_count()
	var ready: bool=quote.get("ok",false) and count>=int(quote.get("source_amount",0))
	spec[c+"Label_Title"]={"role":"source_text","text":"왼쪽 카드를 선택해 주세요." if count==0 else "등록한 카드 %d / %d" % [count,int(quote.get("source_amount",0))]}
	spec[c+"Nd_Card/Label_Message"]={"visible":count==0}
	spec[c+"Btn_Compose/Normal"]={"visible":ready}
	spec[c+"Btn_Compose/Disabled"]={"visible":not ready}

func _enchant_spec() -> Dictionary:
	var spec: Dictionary={}
	var card: Dictionary=_card()
	var quote: Dictionary=_levelup_quote()
	spec["Nd_Skill/Btn_Close"]={"activate":Callable(self,"_tab").bind("skill")}
	spec["Fx_Start"]={"exclude":true}
	spec["Nd_Skill/Nd_Bg/Img_bg1"]={"role":"consume"}
	var inv: String="Nd_Inventory/"
	spec[inv+"Btn_Close"]={"exclude":true}
	for name: String in ["Common_ButtonSet_Grade","Img_Disabled"]:spec[inv+name]={"exclude":true}
	spec[inv+"Btn_Sort"]={"activate":Callable(self,"_cycle_book_order")}
	spec[inv+"Btn_Sort/Normal"]={"visible":true}
	spec[inv+"Btn_Sort/Disabled"]={"visible":false}
	spec[inv+"Btn_Sort/Normal/Label_Class"]={"role":"source_text","text":BOOK_ORDERS[book_order]}
	var books: Array=_books(card)
	var pages: int=maxi(1,ceili(float(books.size())/float(PAGE_SIZE)))
	page=clampi(page,0,pages-1)
	spec[inv+"Btn_Prev"]={"activate":Callable(self,"_page").bind(-1)}
	spec[inv+"Btn_Next"]={"activate":Callable(self,"_page").bind(1)}
	spec[inv+"Label_PageInfo"]={"role":"source_text","text":"(%d/%d)" % [page+1,pages]}
	spec[inv+"Btn_Auto"]={"activate":Callable(self,"_auto_feed")}
	spec[inv+"Btn_Cancel"]={"activate":Callable(self,"_clear_feed")}
	spec[inv+"Nd_Notice"]={"visible":books.is_empty()}
	var s: String="Nd_Skill/Nd_Skill/"
	spec[s+"Label_Title"]={"role":"source_text","text":str(card.get("name",""))}
	spec[s+"Btn_Probability"]={"activate":Callable(self,"_enchant_probability")}
	spec[s+"Fx_CardSelect_Material"]={"exclude":true}
	spec[s+"Nd_Enchant/Label_Skill_Percent"]={"role":"source_text","text":"성공 확률 "+percent_text(float(quote.get("probability_percent",0.0)))}
	spec[s+"Nd_Enchant/Nd_Arrow"]={"visible":true}
	# Before: the card's level and gauge; after: the gauge with the fed books
	# (the next level once the gauge is full).
	var need: float=maxf(1.0,float(quote.get("required_exp",card.get("required_exp",0))))
	var exp_now: float=float(quote.get("exp",card.get("exp",0)))
	var exp_after: float=float(quote.get("exp_after_feed",exp_now))
	var level: int=int(card.get("level",0))
	var maxed: bool=level>=int(card.get("max_level",level))
	var full: bool=exp_after>=need and not maxed
	var n: String=s+"Nd_Enchant/"
	spec[n+"Panel_Exp_Before/Label_Level"]={"role":"source_text","text":"Lv.%d" % level}
	spec[n+"Panel_Exp_Before/Label_Exp_0"]={"role":"source_text","text":"%.4f%%" % (100.0*exp_now/need)}
	spec[n+"Panel_Exp_After/Label_Level"]={"role":"source_text","text":"Lv.%d" % (level+1 if full else level)}
	spec[n+"Panel_Exp_After/Label_Exp_0"]={"role":"source_text","text":"%.4f%%" % (100.0*minf(exp_after,need)/need)}
	spec[n+"Panel_Exp_After/Label_Max_On"]={"visible":maxed}
	spec[n+"Panel_Exp_After/Label_Max_Off"]={"visible":false}
	spec[n+"Panel_Exp_After/Fx_Levelup"]={"exclude":true}
	spec[n+"Nd_ProgressBar/ProgressBar_Exp"]={"role":"source_percent","percent":100.0*minf(exp_after,need)/need}
	spec[n+"ListView"]={"exclude":true}
	var cost: int=int(quote.get("cost",{}).get("amount",0))
	var can: bool=bool(quote.get("ok",false))
	spec[s+"Btn_Production"]={"activate":Callable(self,"_levelup")}
	spec[s+"Btn_Production/Normal"]={"visible":can}
	spec[s+"Btn_Production/Disabled"]={"visible":not can}
	spec[s+"Btn_Production/Text_Price"]={"role":"source_text","text":_number(cost)}
	spec[s+"Fx_Btn_Production"]={"exclude":true}
	spec["Nd_Skill/Nd_Info/Nd_Title/Label"]={"role":"source_text","text":str(card.get("name",""))}
	spec["Nd_Skill/Nd_Info/ListView"]={"exclude":true}
	spec[s+"SkillCard_Slot_B"]={"visible":true}
	_slot_spec(spec,s+"SkillCard_Slot_B/Panel/",int(card.get("grade_id",1)),int(card.get("level",0)))
	spec[s+"SkillCard_Slot_B/Panel/Label_Amount"]={"visible":false}
	for name: String in ["Btn_Recycle","CB_Check","Sp_Lock","Icon_New","Panel_Fx"]:spec[s+"SkillCard_Slot_B/Panel/"+name]={"exclude":true}
	return spec

## Grade frame (Nd_Grade/Item_<suffix>), Common_Slot trimmed to its picture.
func _slot_spec(spec: Dictionary, p: String, grade_id: int, level: int) -> void:
	for suffix: String in SUFFIXES:spec[p+"Nd_Grade/Item_"+suffix]={"visible":suffix==str(GRADE_SUFFIX.get(grade_id,""))}
	spec[p+"Nd_Grade/Item_Disabled"]={"visible":false}
	spec[p+"Label_Level"]={"role":"source_text","text":"Lv.%d" % level,"visible":level>=0}
	spec[p+"Common_Slot/Btn"]={"activate":Callable(self,"_ignore")}
	spec[p+"Common_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	for name: String in SLOT_EXCLUDED:spec[p+"Common_Slot/"+name]={"exclude":true}

## --- Fill ---------------------------------------------------------------------

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	if tab=="enchant":return _fill_enchant(root,out)
	var list: String="SkillCard_Tab_Skill/" if tab=="skill" else "SkillCard_Tab_Compose/"
	var grades: Array=[1,4,5,32] if tab=="skill" else [1,4,5]
	var current: int=grade if tab=="skill" else compose_grade
	var classes: Array=[]
	var counts: Dictionary={}
	for id: int in grades:
		var count: int=_deck_of(id).size() if tab=="skill" else _book_count(id)
		counts[id]=count
		var on: bool=id==current
		var spec: Dictionary={"Panel/Btn_Normal":{"visible":not on,"activate":Callable(self,"_grade").bind(id)},"Panel/Btn_Pressed":{"visible":on,"activate":Callable(self,"_grade").bind(id)},
			"Btn_Normal/Label_Normal":{"role":"source_text","text":grade_text(id)},"Btn_Pressed/Label_Pressed":{"role":"source_text","text":grade_text(id)},
			"Btn_Normal/Label_Normal_Num":{"role":"source_text","text":"( %d )" % count},"Btn_Pressed/Label_Pressed_Num":{"role":"source_text","text":"( %d )" % count},
			"Panel/Icon_New":{"visible":false}}
		for suffix: String in SUFFIXES:spec["Btn_Pressed/Img_"+suffix]={"visible":suffix==str(GRADE_SUFFIX.get(id,""))}
		classes.append({"member":CLASS_ROW,"spec":spec})
	var placed: Dictionary=_fill_list(root,out,list+"ListView_Class",classes)
	if not placed.get("ok",false):return placed
	var shown: Array=_deck_of(grade) if tab=="skill" else materials(compose_grade)
	var grid: Dictionary=_fill_skill_grid(root,out,list+"Nd_SkillList/ListView",shown,current)
	if not grid.get("ok",false):return grid
	var filled: Dictionary={"ok":true,"tab":tab,"grade":current,"cards":shown.size(),"icons":grid.icons,"mounted_cards":grid.mounted}
	if tab=="compose":
		root.set_meta("compose_material_counts",counts)
		var reg: Dictionary=_fill_registered(root,out,shown)
		if not reg.get("ok",false):return reg
		filled["icons"]+=reg.icons
		filled["registered"]=reg.rows
		filled["registered_icons"]=reg.icons
	return filled

func _fill_registered(root: Node2D, out: Dictionary, books: Array, staging: Node2D=null) -> Dictionary:
	var chosen: Array=[]
	for entry: Dictionary in books:
		var id: String=str(entry.physical_id)
		for n: int in range(int(registered.get(id,0))):
			var spec: Dictionary={}
			_slot_spec(spec,"",int(entry.grade_id),-1)
			spec["Label_Level"]={"visible":false}
			spec["Panel_Fx"]={"exclude":true}
			spec["Common_Slot/Btn"]["touch_enabled"]=false
			spec["Panel/Panel_Slot"]={"input":Callable(self,"_registered_input").bind(id)}
			chosen.append({"member":SLOT,"spec":spec,"entry":entry})
	var result: Dictionary=_fill_list(root,out,REGISTERED_LIST,chosen,NAN,false,GRID_COLUMNS,"",staging)
	if result.get("ok",false):result["icons"]=_icons(result,chosen)
	return result

func _fill_skill_grid(root: Node2D, out: Dictionary, suffix: String, cards: Array, current: int) -> Dictionary:
	var list: Dictionary=_list(root,out,suffix)
	if not list.get("ok",false):return list
	var geometry: Dictionary=_row_geometry(SLOT)
	var gap: float=float(_node_options(out,suffix).get("itemMargin",0))
	var size: Vector2=list.size
	var pitch: float=geometry.size.y+gap
	if size.y<=0.0 or geometry.size.x<=0.0 or geometry.size.y<=0.0 or pitch<=0.0:
		return _fail("source_skill_card_grid_geometry_invalid")
	var key: String=list.key
	var view: String="%s:%d" % [tab,current]
	var rows: int=ceili(float(cards.size())/GRID_COLUMNS)
	var minimum: float=minf(0.0,size.y-(rows*pitch-gap))
	var value: float=clampf(float(_grid_positions.get(view,0.0)),minimum,0.0)
	var state: Dictionary={"content":list.content,"min":minimum,"value":value,"skill_grid":cards,"geometry":geometry,
		"size":size,"gap":gap,"pitch":pitch,"view":view,"mounted":{},"span":Vector2i(-1,-1)}
	var built: Dictionary=_mount_skill_grid(key,state,value)
	if not built.get("ok",false):return built
	_scrolls[key]=state
	(list.content as Node2D).position.y=value
	return {"ok":true,"mounted":state.mounted.size(),"icons":built.icons}

func _mount_skill_grid(key: String, state: Dictionary, value: float) -> Dictionary:
	var size: Vector2=state.size
	var cards: Array=state.skill_grid
	var pitch: float=state.pitch
	var first: int=maxi(0,floori(-value/pitch)-1)*GRID_COLUMNS
	var end: int=mini(cards.size(),(ceili((size.y-value)/pitch)+1)*GRID_COLUMNS)
	var span:=Vector2i(first,end)
	if span==state.span:return {"ok":true,"icons":0}
	var cached_trees: Variant=_stage_trees
	if cached_trees==null:_stage_trees={}
	var prepared: Dictionary=_prepare_skill_slots(key,cards,state.mounted,span)
	_stage_trees=cached_trees
	if not prepared.get("ok",false):return prepared
	var mounted: Dictionary=state.mounted
	var content: Node2D=state.content
	for index: int in mounted.keys():
		if (index>=first and index<end) or (index==_held_slot and _dragging==key):continue
		var old: Node2D=mounted[index]
		content.remove_child(old)
		old.queue_free()
		mounted.erase(index)
	var extent: Vector2=state.geometry.size
	var gap: float=state.gap
	var left: float=(size.x-extent.x*GRID_COLUMNS-gap*(GRID_COLUMNS-1))*0.5
	for index: int in prepared.scenes:
		var scene: Node2D=prepared.scenes[index]
		@warning_ignore("integer_division")
		var row: int=index/GRID_COLUMNS
		_place(content,scene,state.geometry,Vector2(left+float(index%GRID_COLUMNS)*(extent.x+gap),size.y-extent.y-row*pitch))
		scene.set_meta(ROW_LIST_META,key)
		_forward_row_drags(scene,key)
		mounted[index]=scene
	state.span=span
	return {"ok":true,"icons":prepared.icons}

func _prepare_skill_slots(key: String, cards: Array, mounted: Dictionary, span: Vector2i) -> Dictionary:
	var scenes: Dictionary={}
	var icons: int=0
	for index: int in range(span.x,span.y):
		if mounted.has(index):continue
		var entry: Dictionary=cards[index]
		var spec: Dictionary={}
		var remaining: int=int(entry.get("remaining",0))
		_slot_spec(spec,"",int(entry.grade_id),int(entry.get("level",0)) if tab=="skill" else -1)
		spec["Label_Level"]={"role":"source_text","text":"Lv.%d" % int(entry.get("level",0)) if tab=="skill" else str(remaining),"visible":true}
		spec["Panel_Fx"]={"exclude":true}
		# The inner icon button has no action here. Let the slot own touches
		# across its entire surface, including drags that start on the icon.
		spec["Common_Slot/Btn"]["touch_enabled"]=false
		spec["Panel/Panel_Slot"]={"input":Callable(self,"_slot_input").bind(key,index)}
		if tab=="compose":spec["Nd_Grade/Item_Disabled"]={"visible":int(registered.get(str(entry.physical_id),0))>=remaining}
		var out: Dictionary={}
		var built: Dictionary=_scene_of(SLOT,spec,out,key)
		if not built.get("ok",false):
			for pending: Node2D in scenes.values():pending.free()
			return built
		var scene: Node2D=built.scene
		scenes[index]=scene
		if tab=="compose":
			var overlay: Dictionary=_locate(scene,out,"Nd_Grade/Item_Disabled")
			if overlay.get("ok",false):
				scene.set_meta("compose_disabled",overlay.player.source_nodes[overlay.offset])
		if _slot_icon(scene,out,entry):icons+=1
	return {"ok":true,"scenes":scenes,"icons":icons}

func _scroll_to(key: String, value: float) -> void:
	var state: Dictionary=_scrolls.get(key,{})
	if state.has("skill_grid") and is_instance_valid(state.content):
		var clamped: float=clampf(value,float(state.min),0.0)
		if not _mount_skill_grid(key,state,clamped).get("ok",false):return
		_grid_positions[state.view]=clamped
	super._scroll_to(key,value)

func _stage() -> Dictionary:
	# The kit remembers ordinary lists by authored node path. The virtual
	# grid restores its own tab/grade position before mounting any slots.
	var previous: Dictionary=_scrolls.duplicate()
	var previous_out: Dictionary=_out
	var previous_result: Dictionary=last_result
	var previous_drag: String=_dragging
	var previous_held: int=_held_slot
	for key: String in previous:
		if previous[key].has("skill_grid"):_scrolls.erase(key)
	_held_slot=-1
	if tab=="skill":_stage_deck=deck()
	var result: Dictionary=super._stage()
	_stage_deck=null
	if not result.get("ok",false):
		_scrolls=previous
		_out=previous_out
		last_result=previous_result
		_dragging=previous_drag
		_held_slot=previous_held
	return result

## The card's material books in the popup's order.
func _books(card: Dictionary) -> Array:
	return ordered_books(materials(int(card.get("grade_id",0))),book_order)

## 전체: the feature's order; 수량순: most first; 이름순 (stable).
static func ordered_books(books: Array, order: int) -> Array:
	if order==0:return books
	var keyed: Array=[]
	for index: int in range(books.size()):
		var entry: Dictionary=books[index]
		keyed.append([-int(entry.get("remaining",0)) if order==1 else 0,str(entry.get("name","")) if order==2 else "",index])
	keyed.sort()
	return keyed.map(func(key: Array) -> Dictionary:return books[int(key[2])])

func _cycle_book_order() -> Dictionary:
	book_order=(book_order+1)%BOOK_ORDERS.size()
	page=0
	return _stage()

## 성공 확률 (the popup's Btn_Probability): the levelup quote's own chance.
func _enchant_probability() -> Dictionary:
	var quote: Dictionary=_levelup_quote()
	var card: Dictionary=_card()
	if int(card.get("level",0))>=int(card.get("max_level",0)):
		_message("최고 강화 단계입니다")
		return {"ok":false}
	_message("%s Lv.%d → Lv.%d 강화 성공 확률 %s (경험치 게이지가 가득 차야 시도합니다)" % [str(card.get("name","")),int(card.get("level",0)),int(card.get("level",0))+1,percent_text(float(quote.get("probability_percent",0.0)))])
	return {"ok":true}

func _fill_enchant(root: Node2D, out: Dictionary) -> Dictionary:
	var card: Dictionary=_card()
	var books: Array=_books(card)
	var start: int=page*PAGE_SIZE
	var rows: int=0
	for r: int in range(PAGE_ROWS.size()):
		var line: Array=[]
		for index: int in range(start+r*3,mini(start+r*3+3,books.size())):
			var entry: Dictionary=books[index]
			var spec: Dictionary={}
			_slot_spec(spec,"",int(entry.grade_id),-1)
			var chosen: int=int(feed.get(str(entry.physical_id),0))
			spec["Label_Level"]={"role":"source_text","text":"%d/%d" % [chosen,int(entry.remaining)] if chosen>0 else "%d" % int(entry.remaining),"visible":true}
			spec["Panel_Fx"]={"exclude":true}
			spec["Nd_Grade/Item_Disabled"]={"visible":chosen>=int(entry.remaining)}
			spec["Panel/Panel_Slot"]={"input":Callable(self,"_feed_input").bind(str(entry.physical_id),int(entry.remaining))}
			line.append({"member":SLOT,"spec":spec,"entry":entry})
		var placed: Dictionary=_fill_list(root,out,"Nd_Inventory/ListView_Swipe/"+PAGE_ROWS[r],line,NAN,true)
		if not placed.get("ok",false):return placed
		_icons(placed,line)
		rows+=line.size()
	var shown: Dictionary={"ok":true,"tab":"enchant","card":int(card.get("card_id",0)),"books":books.size(),"page_books":rows,"feed":feed.duplicate()}
	var located: Dictionary=_locate(root,out,"Nd_Skill/Nd_Skill/SkillCard_Slot_B/Common_Slot/Sp_IconSample")
	if located.get("ok",false):shown["icon"]=_show_picture(located.player,located.offset,_spell_icon(int(card.get("spell_class_id",0))))
	return shown

func _icons(placed: Dictionary, rows: Array) -> int:
	var count: int=0
	for index: int in range(rows.size()):
		if _slot_icon(placed.scenes[index],placed.outs[index],rows[index].entry):count+=1
	return count

func _slot_icon(scene: Node2D, out: Dictionary, entry: Dictionary) -> bool:
	var located: Dictionary=_locate(scene,out,"Common_Slot/Sp_IconSample")
	if not located.get("ok",false):return false
	if entry.has("spell_class_id"):return _show_picture(located.player,located.offset,_spell_icon(int(entry.spell_class_id)))
	return _show_item_icon(located.player,located.offset,_book_icon(entry))

## The learned card's spell icon (SpellClass IconID).
static func _spell_icon(spell_class_id: int) -> Dictionary:
	var rows: Array[Dictionary]=Rows.related("SpellClass","ID",spell_class_id)
	if rows.is_empty():return {"ok":false}
	var info: Dictionary=SkillImages.describe_spell_class_row(rows[-1],"IconID")
	return {"ok":info.get("texture") is Texture2D,"texture":info.get("texture"),"status":str(info.get("status","")),"provenance":info.get("provenance",{})}

## A material book's own item icon (its physical record).
func _book_icon(entry: Dictionary) -> Dictionary:
	var instances: Variant=world().get("item_instances")
	var raw: Variant=instances.get(str(entry.get("physical_id","")),{}) if instances is Dictionary else {}
	var record: Dictionary=raw.get("record",{}) if raw is Dictionary else {}
	if record.is_empty():return {"ok":false}
	return SourceImages.describe_item(record,str(entry.get("name","")))

func _book_count(grade_id: int) -> int:
	var total: int=0
	for entry: Dictionary in materials(grade_id):total+=int(entry.get("remaining",0))
	return total

func _registered_count() -> int:
	var total: int=0
	for key: String in registered:total+=int(registered[key])
	return total

func _merge_quote() -> Dictionary:
	var value: Variant=_call("skill_card523_merge_quote",[compose_grade,registered.duplicate()])
	return value if value is Dictionary else {}

func _levelup_quote() -> Dictionary:
	var card: Dictionary=_card()
	if card.is_empty():return {}
	var tried: Variant=_call("skill_card523_levelup_quote",[int(card.card_id),feed.duplicate(),true])
	if tried is Dictionary and (tried.get("ok",false) or feed.is_empty()):return tried
	var fed: Variant=_call("skill_card523_levelup_quote",[int(card.card_id),feed.duplicate(),false])
	return fed if fed is Dictionary else {}

## --- Input ----------------------------------------------------------------------

static func _released(event: InputEvent) -> bool:
	return (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed)

func _slot_input(event: InputEvent, key: String, index: int) -> void:
	var dragging: bool=_dragging==key
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		if event.pressed:_held_slot=index
	_list_input(event,key)
	if not _released(event):return
	var tap: bool=dragging and _held_slot==index and not _dragged() and not (event is InputEventScreenTouch and event.canceled)
	_held_slot=-1
	_finish_slot_gesture.call_deferred(_scene,key,index,tap)

func _finish_slot_gesture(owner: Node2D, key: String, index: int, tap: bool) -> void:
	if not is_open() or owner!=_scene:return
	var state: Dictionary=_scrolls.get(key,{})
	if not state.has("skill_grid"):return
	if not tap:
		# Release the mounted slot that kept the active drag alive.
		state.span=Vector2i(-1,-1)
		_mount_skill_grid(key,state,state.value)
		return
	var entry: Dictionary=state.skill_grid[index]
	_slot_tap(index,entry)

func _registered_input(event: InputEvent, physical_id: String) -> void:
	if _released(event):_unregister.call_deferred(physical_id)

func _feed_input(event: InputEvent, physical_id: String, remaining: int) -> void:
	if _released(event):_toggle_feed.call_deferred(physical_id,remaining)

## --- Actions --------------------------------------------------------------------

func _tab(name: String) -> Dictionary:
	var previous: String=tab
	var leaving_enchant: bool=name=="skill" and tab=="enchant"
	var was_open: bool=is_open()
	if leaving_enchant and not was_open:feed.clear()
	tab=name
	var result: Dictionary=_stage()
	if result.get("ok",false) and leaving_enchant:feed.clear()
	if not result.get("ok",false) and was_open:tab=previous
	return result

func _grade(id: int) -> Dictionary:
	var previous_grade: int=grade if tab=="skill" else compose_grade
	var previous_selected: int=selected
	var previous_registered: Dictionary=registered.duplicate()
	if tab=="skill":
		grade=id
		selected=-1
	else:
		compose_grade=id
		registered.clear()
	var result: Dictionary=_stage()
	if not result.get("ok",false) and is_open():
		if tab=="skill":
			grade=previous_grade
			selected=previous_selected
		else:
			compose_grade=previous_grade
			registered=previous_registered
	return result

func _slot_tap(index: int, entry: Dictionary={}) -> Dictionary:
	if tab=="skill":
		var previous: int=selected
		selected=index
		if not is_open():return {"ok":false}
		var changed: Dictionary=_update_skill_detail(_card() if entry.is_empty() else entry)
		if not changed.get("ok",false):
			selected=previous
			_update_skill_detail(_card())
		return changed
	var source: Dictionary=_read_compose_materials()
	var books: Array=source.books
	if not entry.is_empty():
		var physical_id: String=str(entry.physical_id)
		index=books.find_custom(func(book: Dictionary) -> bool:return str(book.physical_id)==physical_id)
	if index<0 or index>=books.size():return {"ok":false}
	var key: String=str(books[index].physical_id)
	var quote: Dictionary=_merge_quote()
	var need: int=int(quote.get("source_amount",0))
	if need>0 and _registered_count()>=need:
		_message("합성에는 %d장이 필요합니다" % need)
		return {"ok":false}
	if int(registered.get(key,0))>=int(books[index].remaining):return {"ok":false}
	var previous: Dictionary=registered.duplicate()
	registered[key]=int(registered.get(key,0))+1
	return _stage_registration(previous,source)

func _update_skill_detail(card: Dictionary) -> Dictionary:
	var spec: Dictionary={}
	_skill_detail_spec(spec,card)
	var result: Dictionary=_apply_content_bindings(spec)
	if not result.get("ok",false):return result
	return {"ok":true,"handled":true,"card":int(card.get("card_id",0))}

func _apply_content_bindings(spec: Dictionary) -> Dictionary:
	for suffix: String in spec:
		var binding: Dictionary=spec[suffix]
		if not (binding.has("text") or binding.has("visible") or binding.has("percent")):continue
		var located: Dictionary=_locate(_scene,_out,suffix)
		if not located.get("ok",false):continue
		var player: Node2D=located.player
		var offset: int=located.offset
		for property: String in ["text","percent","visible"]:
			if not binding.has(property):continue
			var result: Dictionary=player.call("set_bound_"+property,offset,binding[property])
			if not result.get("ok",false):return result
	return {"ok":true}

func _unregister(physical_id: String) -> Dictionary:
	if not registered.has(physical_id):return {"ok":false}
	var previous: Dictionary=registered.duplicate()
	registered[physical_id]=int(registered[physical_id])-1
	if int(registered[physical_id])<=0:registered.erase(physical_id)
	return _stage_registration(previous)

## 카드 자동 등록: the feature's own automatic pick (an empty selection).
func _auto_register() -> Dictionary:
	var previous: Dictionary=registered.duplicate()
	registered.clear()
	var value: Variant=_call("skill_card523_merge_quote",[compose_grade,{}])
	var quote: Dictionary=value if value is Dictionary else {}
	for material: Dictionary in quote.get("materials",[]):registered[str(material.physical_id)]=int(registered.get(str(material.physical_id),0))+int(material.get("quantity",1))
	if registered.is_empty():_message(str(quote.get("reason","등록할 카드가 없습니다")))
	return _stage_registration(previous)

func _read_compose_materials() -> Dictionary:
	var counts: Dictionary={1:0,4:0,5:0}
	var books: Array=[]
	for entry: Dictionary in materials(-1):
		var id: int=int(entry.grade_id)
		if counts.has(id):counts[id]+=int(entry.remaining)
		if id==compose_grade:books.append(entry)
	return {"counts":counts,"books":books}

func _stage_registration(previous: Dictionary, source: Dictionary={}) -> Dictionary:
	if not is_open():return _stage()
	var list: Dictionary=_list(_scene,_out,COMPOSE_GRID)
	var grid: Dictionary=_scrolls.get(list.get("key",""),{})
	if source.is_empty():source=_read_compose_materials()
	# An inventory change can invalidate row indices, quantities or another
	# grade's total. Rebuild from the authoritative source in that case.
	var in_place: bool=grid.get("skill_grid") == source.books and _scene.get_meta("compose_material_counts",{}) == source.counts
	var result: Dictionary=_refresh_registered(grid,source.books) if in_place else _stage()
	if not result.get("ok",false):registered=previous
	return result

func _refresh_registered(grid: Dictionary, books: Array) -> Dictionary:
	var staging:=Node2D.new()
	_stage_trees={}
	var made: Dictionary=_fill_registered(_scene,_out,books,staging)
	_stage_trees=null
	if not made.get("ok",false):
		staging.free()
		return made
	var status: Dictionary={}
	_compose_status_spec(status)
	var applied: Dictionary=_apply_content_bindings(status)
	if not applied.get("ok",false):
		staging.free()
		return applied
	var key: String=made.key
	var content: Node2D=made.scroll.content
	var offset: float=float(_scrolls.get(key,{}).get("value",0.0))
	for old: Node2D in content.get_children():
		if old.get_meta(ROW_LIST_META,"")!=key:continue
		content.remove_child(old)
		old.queue_free()
	for scene: Node2D in made.scenes:
		staging.remove_child(scene)
		content.add_child(scene)
	staging.free()
	_scrolls[key]=made.scroll
	_scroll_to(key,offset)
	for index: int in grid.mounted:
		var scene: Node2D=grid.mounted[index]
		var overlay: Node2D=scene.get_meta("compose_disabled",null) if scene.has_meta("compose_disabled") else null
		if overlay==null:continue
		var entry: Dictionary=books[index]
		overlay.visible=int(registered.get(str(entry.physical_id),0))>=int(entry.remaining)
	var filled: Dictionary=last_result.filled
	filled.icons+=int(made.icons)-int(filled.registered_icons)
	filled.registered_icons=made.icons
	filled.registered=made.rows
	return last_result

func _merge_probability() -> Dictionary:
	var quote: Dictionary=_merge_quote()
	_message("합성 확률 %s (%s %d장 → %s 1장, 실패 시 재료 소멸)" % [percent_text(float(quote.get("probability_percent",0.0))),str(GRADES.get(compose_grade,"")),int(quote.get("source_amount",0)),str(GRADES.get(int(MERGE_TARGET.get(compose_grade,0)),""))])
	return {"ok":true}

## 합 성: quote -> HUD confirmation -> the existing merge.
func _merge() -> Dictionary:
	var quote: Dictionary=_merge_quote()
	if not quote.get("ok",false) or _registered_count()<int(quote.get("source_amount",0)):
		_message(str(quote.get("reason","등록한 카드가 부족합니다")) if not quote.get("ok",false) else "카드를 %d장 등록하세요" % int(quote.get("source_amount",0)))
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_skill_card_window_confirmation_unavailable")
	var token: String=str(quote.token)
	owner.call("confirm_action","스킬 카드 합성","%s %d장 → %s 1장\n성공 확률 %s · 실패하면 재료가 사라집니다" % [str(GRADES.get(compose_grade,"")),int(quote.source_amount),str(GRADES.get(int(MERGE_TARGET.get(compose_grade,0)),"")),percent_text(float(quote.get("probability_percent",0.0)))],"합성",func(_count: int) -> void:
		var result: Variant=_call("skill_card523_merge_execute",[token])
		var done: Dictionary=result if result is Dictionary else {}
		_message(str(done.get("message",done.get("reason",""))) if not str(done.get("message","")).is_empty() or not done.get("ok",false) else ("합성 성공 · "+str(done.get("result",{}).get("name","")) if done.get("success",false) else "합성 실패"))
		if done.get("ok",false):registered.clear()
		if is_open():_stage())
	return {"ok":true,"quoted":"skill_card523_merge"}

func _enchant() -> Dictionary:
	var card: Dictionary=_card()
	if card.is_empty() or not bool(card.get("enhanceable",false)):
		_message("최고 강화 단계입니다" if not card.is_empty() else "카드를 선택하세요")
		return {"ok":false}
	tab="enchant"
	feed.clear()
	page=0
	return _stage()

func _page(delta: int) -> Dictionary:
	page+=delta
	return _stage()

func _toggle_feed(physical_id: String, remaining: int) -> Dictionary:
	var chosen: int=int(feed.get(physical_id,0))
	if chosen>=remaining:feed.erase(physical_id)
	else:feed[physical_id]=chosen+1
	return _stage()

## 자동 선택: same-grade books in order until the gauge would be full.
func _auto_feed() -> Dictionary:
	feed.clear()
	var card: Dictionary=_card()
	var need: int=int(card.get("required_exp",0))-int(card.get("exp",0))
	for entry: Dictionary in materials(int(card.get("grade_id",0))):
		while need>0 and int(feed.get(str(entry.physical_id),0))<int(entry.remaining):
			feed[str(entry.physical_id)]=int(feed.get(str(entry.physical_id),0))+1
			var quote: Variant=_call("skill_card523_levelup_quote",[int(card.card_id),feed.duplicate(),false])
			if not quote is Dictionary or not quote.get("ok",false):
				feed[str(entry.physical_id)]=int(feed[str(entry.physical_id)])-1
				if int(feed[str(entry.physical_id)])<=0:feed.erase(str(entry.physical_id))
				break
			need=int(quote.required_exp)-int(quote.exp_after_feed)
	if feed.is_empty():_message("먹일 수 있는 같은 등급 카드가 없습니다")
	return _stage()

func _clear_feed() -> Dictionary:
	feed.clear()
	return _stage()

## 강화: quote -> HUD confirmation -> the existing feed / attempt.
func _levelup() -> Dictionary:
	var quote: Dictionary=_levelup_quote()
	if not quote.get("ok",false):
		_message(str(quote.get("reason","강화할 수 없습니다")))
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_skill_card_window_confirmation_unavailable")
	var token: String=str(quote.token)
	var body: String="%s Lv.%d · 경험치 %d → %d / %d\n%s · 아데나 %s" % [str(quote.name),int(quote.level),int(quote.exp),int(quote.exp_after_feed),int(quote.required_exp),
		"강화 시도 (성공 확률 %s)" % percent_text(float(quote.probability_percent)) if bool(quote.get("attempt",false)) else "카드 먹이기만", _number(int(quote.cost.amount))]
	if int(quote.get("wasted_exp",0))>0:body+="\n넘치는 경험치 %d는 사라집니다" % int(quote.wasted_exp)
	owner.call("confirm_action","스킬 강화",body,"강화",func(_count: int) -> void:
		var result: Variant=_call("skill_card523_levelup_execute",[token])
		var done: Dictionary=result if result is Dictionary else {}
		_message(str(done.get("message",done.get("reason",""))))
		if done.get("ok",false):feed.clear()
		if is_open():_stage())
	return {"ok":true,"quoted":"skill_card523_levelup"}
