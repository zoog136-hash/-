extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 TJ의 쿠폰 retry windows over the existing TJ coupon
## feature (world.tj_coupons, scripts/tj: real failure records, owned coupons,
## the original coupon policy, redeem / redeem_awakening).
## - 합성 재도전: Recovery_All_Compose. The four Recovery_Card grade cards
##   (희귀 / 영웅 / 전설 / 신화) are 선택 가능 when an owned coupon has an
##   unused failure record of that grade; a tap opens Recovery_Popup_CardList
##   (성공 후보 1장, then the coupon's ChoiceFailCardCount 실패 후보 from the
##   record's own candidates, Recovery_List_Card rows with the client card
##   prefab Change_Card_A_<grade>, chosen names as Recovery_List_CardName),
##   then Nd_ChangeRetry shows the chosen cards; 확 인 confirms and calls
##   tj_coupons.redeem (the world checks, rolls, pays and saves).
## - 각성 재도전: Recovery_All_Awaken. Grade cards 영웅 / 전설 / 신화; the
##   popup Recovery_Popup_Awaken_CardList lists the failed awakening targets;
##   각 성 shows Nd_Retry with the card and 확 인 redeems the record
##   (the existing awakening engine keeps its own costs).
## - 확률 보기 (합성): the original merge rule's SuccessProbability for the
##   deck and grade (the same row tj runtime rolls with, server-matched).
## Left empty (no TWILIGHT data or feature): 각성 확률 보기, 후보 카드 컬렉션 보기 /
## 컬렉션 보기, the awakening detail panel (Nd_Detail), the moving select
## frame (Nd_SelectEffect) and the reveal effects. Skill card retry (Recovery_All_Compose_Skill) has no TWILIGHT
## engine and equipment recovery (Recovery_All) no TWILIGHT record. Without
## the 523 TJ source or a server context the existing TJ page opens instead
## (it installs the source and stores the context).
const Page=preload("res://scripts/ui/original_ui/source_main_change_page.gd")
const Presentation=preload("res://scripts/ui/source_card_presentation.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const COMPOSE="UI/Recovery/Recovery_All_Compose.csb"
const AWAKEN="UI/Recovery/Recovery_All_Awaken.csb"
const GRADE_CARD="UI/Recovery/Recovery_Card.csb"
const POPUP="UI/Recovery/Recovery_Popup_CardList.csb"
const AWAKEN_POPUP="UI/Recovery/Recovery_Popup_Awaken_CardList.csb"
const CARD_ROW="UI/Recovery/Recovery_List_Card.csb"
const NAME_ROW="UI/Recovery/Recovery_List_CardName.csb"
## BuffCardDeckID of each category (scripts/tj/coupon_service DECK).
const DECKS={"변신":1,"마법인형":2,"성물":98}
## Recovery_Card grade node -> original GradeID (희귀 3, 영웅 4, 전설 5, 신화 32).
const GRADE_NODES={"Nd_Unique":3,"Nd_Legend":4,"Nd__Epic":5,"Nd_Myth":32}
const GRADE_NAMES={1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",32:"신화",52:"유일"}
## Each window's grade card ProjectNodes (Nd_CardSelect) -> the node they show.
const COMPOSE_BUTTONS={"Btn_Unique":"Nd_Unique","Btn_Legend":"Nd_Legend","Btn_Epic":"Nd__Epic","Btn_Myth":"Nd_Myth"}
const AWAKEN_BUTTONS={"Btn_Legend":"Nd_Legend","Btn_Epic":"Nd__Epic","Btn_Myth":"Nd_Myth"}
const CARD_IMAGES={"변신":"Img_Card_Change","마법인형":"Img_Card_Doll","성물":"Img_Card_HolyStuff"}
## Grid columns: the popup card list holds Recovery_List_Card_Set rows of six
## (770 = 6 x 124 + 5 x 5); the awakening list (488 wide) takes three.
const POPUP_COLUMNS: int=6
const AWAKEN_COLUMNS: int=3
var kind: String="fusion"
var category: String="변신"
## select / popup / retry
var stage: String="select"
var grade: int=0
var coupon: String=""
var retry_event: Dictionary={}
var fail_count: int=1
var revision: int=-1
var picked_success: Array[String]=[]
var picked_fail: Array[String]=[]
var _records: Dictionary={}

func required_members() -> Array[String]:
	return [COMPOSE,AWAKEN,GRADE_CARD,POPUP,AWAKEN_POPUP,CARD_ROW,NAME_ROW]

func _root_member() -> String:
	return AWAKEN if kind=="awakening" else COMPOSE

func _tj() -> Object:
	var owner: Object=world()
	return owner.get("tj_coupons") if owner!=null else null

## Opens the window of `retry_kind` (fusion / awakening) and `category_name`;
## empty picks the first one with a usable record (else 변신 합성).
func open(parent: Node, retry_kind: String="", category_name: String="") -> Dictionary:
	var tj: Object=_tj()
	if tj==null:return _fail("source_tj_window_runtime_unavailable")
	if tj.core.definitions.is_empty() and not tj.load_default_source():return _fail("source_tj_window_source_unavailable")
	if tj.core.blocked or tj.context().is_empty():return _fail("source_tj_window_context_unavailable")
	if retry_kind.is_empty():
		var usable: Array=usable_records()
		retry_kind=str(usable[0].kind) if not usable.is_empty() else "fusion"
		category_name=str(usable[0].category) if not usable.is_empty() else "변신"
	if retry_kind not in ["fusion","awakening"] or not DECKS.has(category_name):return _fail("source_tj_window_kind_unsupported")
	kind=retry_kind
	category=category_name
	_reset("select")
	_records.clear()
	return open_window(parent)

## Every unused failure record an owned coupon can retry, as
## {coupon, retry_event, kind, category, grade, fail_count} (the coupon's own
## candidates() filter: deck, history type, season, server, minimum grade).
func usable_records() -> Array:
	var tj: Object=_tj()
	var found: Array=[]
	if tj==null:return found
	var context: Dictionary=tj.context()
	for id: String in tj.core.definitions.get("coupons",{}):
		if int(tj.owned_count(id))<1:continue
		var view: Dictionary=tj.core.candidates(id,context,tj.core.clock())
		if not view.get("ok",false):continue
		for row: Dictionary in view.get("events",[]):
			var row_kind: String=str(row.get("adapter",""))
			var row_category: String=""
			for name: String in DECKS:
				if int(DECKS[name])==int(row.get("deck",0)):row_category=name
			if row_kind not in ["fusion","awakening"] or row_category.is_empty():continue
			var count: int=int(view.get("policy",{}).get("ChoiceFailCardCount",0))
			found.append({"coupon":id,"retry_event":row,"kind":row_kind,"category":row_category,"grade":int(row.get("grade",0)),"fail_count":count if count>0 else 1})
	return found

func _usable_here() -> Array:
	var found: Array=[]
	for row: Dictionary in usable_records():
		if row.kind==kind and row.category==category:found.append(row)
	return found

func _reset(next: String) -> void:
	stage=next
	if next=="select":
		grade=0
		coupon=""
		retry_event={}
		revision=-1
	picked_success.clear()
	picked_fail.clear()

func _card_name(id: String) -> String:
	var tj: Object=_tj()
	return str(tj.core.definitions.get("cards",{}).get(id,{}).get("Name",id)) if tj!=null else id

## The game catalog record of BuffCard `id` (card_draw_fusion pools).
func _record(id: String) -> Dictionary:
	if _records.is_empty():
		var owner: Object=world()
		var fusion: Variant=owner.get("card_draw_fusion") if owner!=null else null
		if fusion is Object:
			for name: String in DECKS:
				for pool: Variant in (fusion as Object).get("pools").get(name,{}).values():
					for entry: Variant in pool:
						if entry is Dictionary and int(entry.get("record",{}).get("source_card_id",0))>0:_records[str(int(entry.record.source_card_id))]=entry.record
	return _records.get(id,{})

func _owned(record: Dictionary) -> bool:
	var owner: Object=hud()
	if owner==null or record.is_empty():return false
	var state: Variant=owner.get("card_collection_state")
	return state is Dictionary and state.get("owned",{}).get(category,{}).get(Cards.card_id(record),false)==true

## --- Spec -----------------------------------------------------------------

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Nd_Title/Text_Title"]={"role":"source_text","text":"%s %s 재도전" % [category,"각성" if kind=="awakening" else "합성"]}
	spec["Nd_Title/Text_AllNew"]={"visible":false}
	var buttons: Dictionary=AWAKEN_BUTTONS if kind=="awakening" else COMPOSE_BUTTONS
	for button: String in buttons:
		var shown: String=buttons[button]
		var id: int=int(GRADE_NODES[shown])
		var p: String="Nd_CardSelect/"+button+"/"
		spec[p+"Btn_Card"]={"activate":Callable(self,"_grade").bind(id)}
		spec[p+"Btn_Probability"]={"exclude":true} if kind=="awakening" else {"activate":Callable(self,"_probability").bind(id)}
		for node: String in GRADE_NODES:
			if node!=shown:spec[p+"Btn_Card/"+node]={"exclude":true}
		spec[p+"Btn_Card/"+shown]={"visible":true}
		spec[p+"Btn_Card/"+shown+"/Label_Grade"]={"role":"source_text","text":"%s %s" % [GRADE_NAMES[id],category]}
		for name: String in CARD_IMAGES:spec[p+"Btn_Card/"+shown+"/"+str(CARD_IMAGES[name])]={"visible":name==category}
	if kind=="fusion":
		spec["Nd_CardSelect/Nd_MagicDoll_AllNewTJ"]={"visible":category=="마법인형"}
		spec["Nd_CardSelect"]={"visible":stage!="retry"}
		if stage=="retry":_retry_spec(spec,"Nd_ChangeRetry/")
		else:spec["Nd_ChangeRetry"]={"exclude":true}
		if stage=="popup":_popup_spec(spec)
		else:spec["Recovery_Popup_CardList"]={"exclude":true}
	else:
		spec["Nd_CardSelect"]={"visible":stage!="retry"}
		if stage=="retry":
			spec["Nd_Retry"]={"visible":true}
			_retry_spec(spec,"Nd_Retry/")
		else:spec["Nd_Retry"]={"exclude":true}
		if stage=="popup":_awaken_popup_spec(spec)
		else:spec["Recovery_Popup_Awaken_CardList"]={"exclude":true}
	return spec

func _retry_spec(spec: Dictionary, p: String) -> void:
	spec[p+"Nd_Button/Btn_Cancle"]={"activate":Callable(self,"_cancel")}
	spec[p+"Nd_Button/Btn_ReSelect"]={"activate":Callable(self,"_reselect")}
	spec[p+"Nd_Button/Btn_Ok"]={"activate":Callable(self,"_redeem")}

## The original merge chance of this deck and grade (BuffCardMergeRule
## SuccessProbability out of 1,000,000, the row tj runtime rolls with).
func success_chance(grade_id: int) -> float:
	var tj: Object=_tj()
	if tj==null:return -1.0
	var found: Array=[]
	for row: Variant in tj.core.definitions.get("merge_rules",[]):
		if not row is Dictionary or int(row.get("BuffCardDeckID",0))!=int(DECKS.get(category,0)) or int(row.get("GradeID",0))!=grade_id:continue
		if tj.core.has_method("server_matches") and not tj.core.server_matches(int(row.get("ServerLimitSetID",0)),tj.context()):continue
		found.append(row)
	return float(found[0].SuccessProbability)/10000.0 if found.size()==1 else -1.0

func _probability(grade_id: int) -> Dictionary:
	var chance: float=success_chance(grade_id)
	if chance<0.0:
		_message("현재 서버의 원본 합성 확률을 확인할 수 없습니다")
		return {"ok":false}
	var text: String=("%.4f" % chance).rstrip("0").rstrip(".")
	_message("%s %s 합성 재도전 성공 확률 %s%% (성공 시 고른 성공 후보, 실패 시 고른 실패 후보 중 1장)" % [GRADE_NAMES.get(grade_id,""),category,text])
	return {"ok":true,"percent":chance}

func _phase() -> String:
	return "success" if picked_success.is_empty() else "fail"

func _complete() -> bool:
	return picked_success.size()==1 and picked_fail.size()==fail_count

func _popup_spec(spec: Dictionary) -> void:
	var p: String="Recovery_Popup_CardList/"
	spec["Recovery_Popup_CardList"]={"visible":true}
	spec[p+"Btn_Close"]={"activate":Callable(self,"_popup_close")}
	spec["Nd_Popup_CardList/Btn_Close"]={"activate":Callable(self,"_popup_close")}
	spec["Nd_Popup_CardList/Btn_Cancel"]={"activate":Callable(self,"_popup_close")}
	spec["Nd_Popup_CardList/Btn_Ok"]={"activate":Callable(self,"_popup_ok")}
	spec["Nd_Popup_CardList/Btn_Ok/Normal"]={"visible":_complete()}
	spec["Nd_Popup_CardList/Btn_Ok/Disabled"]={"visible":not _complete()}
	spec["Nd_Popup_CardList/Btn_CollectionView"]={"exclude":true}
	spec[p+"CardChange_Popup_CollectionView"]={"exclude":true}
	spec["Nd_Popup_CardList/Bg/Label_Title"]={"role":"source_text","text":"성공 후보 카드 선택" if _phase()=="success" else "실패 후보 카드 선택"}
	spec["Nd_SuccessList/Label_Num"]={"role":"source_text","text":"남은 선택 수 : %d" % (1-picked_success.size())}
	spec["Nd_FailList/Label_Num"]={"role":"source_text","text":"남은 선택 수 : %d" % (fail_count-picked_fail.size())}
	for list: String in ["Nd_SuccessList","Nd_FailList"]:
		var on: bool=(list=="Nd_SuccessList")==(_phase()=="success")
		spec[list+"/Nd_Ani_Ing01"]={"visible":on}
		spec[list+"/Nd_Ani_Ing02"]={"visible":on}

func _awaken_popup_spec(spec: Dictionary) -> void:
	var p: String="Recovery_Popup_Awaken_CardList/"
	spec["Recovery_Popup_Awaken_CardList"]={"visible":true}
	spec[p+"Btn_Close"]={"activate":Callable(self,"_popup_close")}
	spec["Nd_Popup/Btn_Close"]={"activate":Callable(self,"_popup_close")}
	spec["Nd_Popup/Btn_Collection"]={"exclude":true}
	spec["Nd_Popup/Nd_Detail"]={"exclude":true}
	# The select frame follows the chosen card in the client; the chosen card
	# shows its own Nd_Select mark here instead of a frame left in place.
	spec["Nd_Popup/Nd_SelectEffect"]={"exclude":true}
	spec["Nd_Popup/Nd_Non"]={"visible":retry_event.is_empty()}
	spec["Nd_Popup/Btn_Awaken"]={"activate":Callable(self,"_popup_ok")}
	spec["Nd_Popup/Btn_Awaken/Normal"]={"visible":not retry_event.is_empty()}
	spec["Nd_Popup/Btn_Awaken/Disabled"]={"visible":retry_event.is_empty()}
	spec["Nd_CardList/Label_Notice"]={"visible":_grade_records().is_empty()}

## --- Fill -----------------------------------------------------------------

## The window's own title loop (Fx_Loop) and each grade card's original
## state clip: Active (활성화, usable record) or Disabled (선택 불가).
func _play_states(root: Node2D, out: Dictionary) -> Dictionary:
	root.play("Fx_Loop",true)
	var available: Dictionary={}
	for row: Dictionary in _usable_here():available[int(row.grade)]=true
	var states: Dictionary={}
	if stage=="retry":return states
	var buttons: Dictionary=AWAKEN_BUTTONS if kind=="awakening" else COMPOSE_BUTTONS
	for button: String in buttons:
		var on: bool=available.has(int(GRADE_NODES[buttons[button]]))
		var nested: Node2D=_project(root,out,"Nd_CardSelect/"+button)
		if nested!=null and nested.play("Active" if on else "Disabled",on).get("ok",false):states[button]="Active" if on else "Disabled"
	if stage=="popup":
		var popup: Node2D=_project(root,out,"Recovery_Popup_CardList" if kind=="fusion" else "Recovery_Popup_Awaken_CardList")
		if popup!=null:popup.play("Fx_Loading",true)
	return states

## The nested player of the ProjectNode at `suffix`.
func _project(root: Node2D, out: Dictionary, suffix: String) -> Node2D:
	var located: Dictionary=_locate(root,out,suffix)
	if not located.get("ok",false):return null
	var node: Node=located.player.source_nodes.get(located.offset)
	var nested: Variant=node.get_meta("source_project_player") if node!=null and node.has_meta("source_project_player") else null
	return nested if nested is Node2D else null

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var filled: Dictionary={"ok":true,"kind":kind,"category":category,"stage":stage,"grades":_usable_here().size(),"states":_play_states(root,out)}
	if stage=="popup" and kind=="fusion":
		var phase: Array=retry_event.get("success_candidates" if _phase()=="success" else "fail_candidates",[])
		var cards: Array=[]
		for id: Variant in phase:cards.append(str(id))
		var listed: Dictionary=_cards(root,out,"Nd_Popup_CardList/ListView_Card",cards,POPUP_COLUMNS,true)
		if not listed.get("ok",false):return listed
		filled["cards"]=int(listed.rows)
		filled["pictures"]=int(listed.pictures)
		for pair: Array in [["Nd_SuccessList/ListView",picked_success],["Nd_FailList/ListView",picked_fail]]:
			var names: Array=[]
			for id: String in pair[1]:
				names.append({"member":NAME_ROW,"spec":{"Panel/Label_Name":{"role":"source_text","text":_card_name(id)},"Panel":{"input":Callable(self,"_name_input").bind(id)}}})
			var placed: Dictionary=_fill_list(root,out,pair[0],names)
			if not placed.get("ok",false):return placed
		filled["picked"]=[picked_success.duplicate(),picked_fail.duplicate()]
	elif stage=="popup":
		var cards: Array=[]
		for row: Dictionary in _grade_records():cards.append(str(row.retry_event.success_candidates[0]))
		var listed: Dictionary=_cards(root,out,"Nd_CardList/ListView",cards,AWAKEN_COLUMNS,true)
		if not listed.get("ok",false):return listed
		filled["cards"]=int(listed.rows)
		filled["pictures"]=int(listed.pictures)
	elif stage=="retry":
		var lists: Array=[["Nd_ChangeRetry/ListView_SuccessCard",picked_success],["Nd_ChangeRetry/ListView_FailCard",picked_fail]] if kind=="fusion" else [["Nd_Retry/ListView_Card",picked_success]]
		var shown: int=0
		for pair: Array in lists:
			var listed: Dictionary=_cards(root,out,pair[0],pair[1],0,false)
			if not listed.get("ok",false):return listed
			shown+=int(listed.rows)
		filled["cards"]=shown
	return filled

## Recovery_List_Card rows for BuffCard `ids` in the list at `suffix`
## (`columns` 0: one horizontal line), each with the client card prefab
## Change_Card_A_<grade> and its own picture in Nd_Card.
func _cards(root: Node2D, out: Dictionary, suffix: String, ids: Array, columns: int, tappable: bool) -> Dictionary:
	var list: Dictionary=_list(root,out,suffix)
	if not list.get("ok",false):return list
	var rows: Array=[]
	var selected: Array=picked_success+picked_fail
	for id: String in ids:
		var record: Dictionary=_record(id)
		var spec: Dictionary={"Panel_Card/Label_Card":{"role":"source_text","text":_card_name(id)},
			"Panel_Card/Nd_Select":{"visible":tappable and (id in selected or (kind=="awakening" and not retry_event.is_empty() and str(retry_event.success_candidates[0])==id))},
			"Panel_Card/Nd_Own":{"visible":_owned(record)}}
		if tappable:spec["Panel_Card"]={"input":Callable(self,"_card_input").bind(str(list.key),id)}
		rows.append({"member":CARD_ROW,"spec":spec,"id":id,"record":record})
	var placed: Dictionary=_fill_list(root,out,suffix,rows,NAN,columns==0,maxi(1,columns))
	if not placed.get("ok",false):return placed
	var pictures: int=0
	for index: int in range(rows.size()):
		if _card_prefab(placed.scenes[index],placed.outs[index],rows[index].record,str(list.key),str(rows[index].id),tappable):pictures+=1
	return {"ok":true,"rows":rows.size(),"pictures":pictures}

## The client card prefab inside a Recovery_List_Card Nd_Card (the slot the
## 124x142 Change_Card_A fills above the name); empty without a game record.
func _card_prefab(scene: Node2D, out: Dictionary, record: Dictionary, list_key: String, id: String, tappable: bool) -> bool:
	var grade_name: String=str(record.get("grade",""))
	if record.is_empty() or not Page.GRADE_MEMBERS.has(grade_name):return false
	var located: Dictionary=_locate(scene,out,"Panel_Card/Nd_Card")
	if not located.get("ok",false):return false
	var slot: Node=located.player.source_nodes.get(located.offset)
	if not slot is Node2D:return false
	var input: Callable=Callable(self,"_card_input").bind(list_key,id) if tappable else Callable(self,"_list_input").bind(list_key)
	var spec: Dictionary={"Panel_Root":{"input":input},"Panel_Root/CB_Check":{"exclude":true},
		"Nd_Character/CardSample":{"role":"source_asset_slot","visible":false},
		"Nd_Character/CardSample_A":{"exclude":true},"Panel_Root/Panel_Fx":{"exclude":true},
		"Panel_Root/Sp_Lock":{"exclude":true},"Panel_Root/Nd_Attribute":{"exclude":true}}
	var card_out: Dictionary={}
	var built: Dictionary=_scene_of(str(Page.GRADE_MEMBERS[grade_name]),spec,card_out,list_key)
	if not built.get("ok",false):return false
	(slot as Node2D).add_child(built.scene)
	var card: Dictionary=_locate(built.scene,card_out,"Nd_Character/CardSample")
	if not card.get("ok",false):return false
	var shown: Dictionary=Presentation.detail(record,true,false)
	if shown.get("status","")!="original" or not shown.get("texture") is Texture2D:return false
	return _show_picture(card.player,card.offset,{"ok":true,"texture":shown.texture,"provenance":shown.get("provenance",{}).duplicate(true),"role":str(shown.get("role",""))})

func _grade_records() -> Array:
	var found: Array=[]
	for row: Dictionary in _usable_here():
		if int(row.grade)==grade and not (row.retry_event.get("success_candidates",[]) as Array).is_empty():found.append(row)
	return found

## --- Input ----------------------------------------------------------------

static func _released(event_in: InputEvent) -> bool:
	return (event_in is InputEventScreenTouch and not event_in.pressed) or (event_in is InputEventMouseButton and event_in.button_index==MOUSE_BUTTON_LEFT and not event_in.pressed)

func _card_input(event_in: InputEvent, list_key: String, id: String) -> void:
	var dragging: bool=_dragging==list_key
	_list_input(event_in,list_key)
	if _released(event_in) and dragging and not _dragged():_pick.call_deferred(id)

func _name_input(event_in: InputEvent, id: String) -> void:
	if _released(event_in):_unpick.call_deferred(id)

## --- Actions --------------------------------------------------------------

## A grade card: its newest usable record opens the candidate popup.
func _grade(id: int) -> Dictionary:
	var rows: Array=[]
	for row: Dictionary in _usable_here():
		if int(row.grade)==id:rows.append(row)
	if rows.is_empty():
		_message("이 등급의 재도전 이력이 없습니다")
		return {"ok":false,"grade":id}
	var tj: Object=_tj()
	_reset("popup")
	grade=id
	revision=int(tj.core.state.revision)
	if kind=="fusion":
		var row: Dictionary=rows[-1]
		coupon=str(row.coupon)
		retry_event=row.retry_event
		fail_count=int(row.fail_count)
	else:
		coupon=""
		retry_event={}
	return _stage()

func _pick(id: String) -> Dictionary:
	if stage!="popup":return {"ok":false}
	if kind=="awakening":
		for row: Dictionary in _grade_records():
			if str(row.retry_event.success_candidates[0])==id:
				coupon=str(row.coupon)
				retry_event=row.retry_event
				fail_count=1
		return _stage()
	if _phase()=="success":
		if (retry_event.get("success_candidates",[]) as Array).has(id):picked_success.assign([id])
	elif picked_fail.has(id):picked_fail.erase(id)
	elif picked_fail.size()<fail_count and (retry_event.get("fail_candidates",[]) as Array).has(id):picked_fail.append(id)
	return _stage()

func _unpick(id: String) -> Dictionary:
	if picked_success.has(id):
		picked_success.clear()
		picked_fail.clear()
	else:picked_fail.erase(id)
	return _stage()

func _popup_close() -> Dictionary:
	_reset("select")
	return _stage()

func _popup_ok() -> Dictionary:
	if kind=="awakening":
		if retry_event.is_empty():return {"ok":false}
		picked_success.assign([str(retry_event.success_candidates[0])])
		picked_fail.assign([str(retry_event.fail_candidates[0])] if not (retry_event.get("fail_candidates",[]) as Array).is_empty() else [])
	elif not _complete():
		_message("성공 후보 1장과 실패 후보 %d장을 선택하세요" % fail_count)
		return {"ok":false}
	stage="retry"
	return _stage()

func _cancel() -> Dictionary:
	_reset("select")
	return _stage()

func _reselect() -> Dictionary:
	var keep: int=grade
	return _grade(keep)

## 확 인: the existing redeem through the HUD confirmation; the world checks
## the coupon, record, candidates and revision again, rolls, pays and saves.
func _redeem() -> Dictionary:
	var tj: Object=_tj()
	var owner: Object=hud()
	if tj==null or owner==null or not owner.has_method("confirm_action"):return _fail("source_tj_window_confirmation_unavailable")
	if coupon.is_empty() or retry_event.is_empty():return {"ok":false}
	var item: String=coupon
	var event_id: String=str(retry_event.id)
	var at: int=revision
	var good: Array=picked_success.duplicate()
	var bad: Array=picked_fail.duplicate()
	var fee: int=int(tj.core.settings.get("retry_gold_cost",0))
	var name: String=str(tj.core.definitions.get("coupons",{}).get(item,{}).get("item",{}).get("Name","TJ의 쿠폰"))
	var body: String="%s 1장을 사용합니다.\n%s" % [name,"기존 각성 비용이 함께 필요합니다." if kind=="awakening" else "성공 후보 %s · 실패 후보 %d장" % [_card_name(good[0]),bad.size()]]
	if fee>0:body+="\nTWILIGHT 추가 비용 %s 아데나" % _number(fee)
	owner.call("confirm_action","TJ의 쿠폰",body,"도전",func(_count: int) -> void:
		var result: Dictionary=tj.redeem(item,event_id,at,good,bad)
		var success: String=" · 성공" if result.get("ok",false) and bool(result.get("success",false)) else (" · 실패" if result.get("ok",false) else "")
		_message(str(result.get("error","완료"))+success)
		if result.get("ok",false):_reset("select")
		if is_open():_stage())
	return {"ok":true,"quoted":"tj_coupons.redeem","retry_event":event_id}
