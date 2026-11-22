extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 카드 다시 뽑기 window: CardChange_All over the existing
## card swap feature (#556/#565: world.card523_swap_quote / _execute /
## _confirm / _pending, docs/cards523_reroll_skillcard.md). Rules, costs,
## counts and saves are the feature's.
## - The list (ListView_Swipe of CardChange_Slot_Card): every owned 변신 /
##   마법인형 / 성물 card of 영웅 grade or above (cards with a waiting result
##   first). A slot shows its card (the client card prefab
##   Change_Card_A_<grade> with its own picture in Nd_Card) or, while a result
##   waits, that result; 다시 뽑기 opens CardChange_Popup_Retry (remaining
##   count, the Diamond price and balance), 카드 확정 opens
##   CardChange_Popup_Confirm for a waiting result.
## - 다시 뽑기 runs card523_swap_execute (the result waits, user decision
##   2026-11-16); the 6th swap (PickCount) first opens
##   CardChange_Popup_RetrySpecial_Select with the fixed candidates.
##   카드 확정 runs card523_swap_confirm. There is no cancel of a waiting result.
## - 뽑기 확률 / 목록 보기 / 주의 사항 of the retry popup: the quote's
##   candidates (each 1 / count, the feature draws evenly) and the feature's
##   own rules.
## - The reveal as in the client: after 다시 뽑기 CardChange_Gacha flips the
##   card (the card before in Nd_Card_Before, the card back of its kind, the
##   result in the Change_Fusion_Card cell; the clip of the card's kind);
##   after 카드 확정 CardChange_Result shows the confirmed card, and a card of
##   영웅 이상 lights up in its grade (source_main_card_grade_fx). A tap or
##   the close button returns to the list.
## Left empty (no TWILIGHT data): 상품 안내 (cash goods),
## the collection view, the confirm time limit
## and the cash notice.
const ROOT="UI/CardChange/CardChange_All.csb"
const SLOT="UI/CardChange/CardChange_Slot_Card.csb"
const RETRY="UI/CardChange/CardChange_Popup_Retry.csb"
const CONFIRM="UI/CardChange/CardChange_Popup_Confirm.csb"
const PICK="UI/CardChange/CardChange_Popup_RetrySpecial_Select.csb"
const PICK_ROW="UI/CardChange/CardChange_List_RetrySpecial_Select.csb"
const GACHA="UI/CardChange/CardChange_Gacha.csb"
const RESULT="UI/CardChange/CardChange_Result.csb"
const GradeFx=preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
## CardChange_Gacha clips by card kind (Nd_Card_Before shows until frame 265,
## the result from there: the name follows).
const GACHA_CLIPS={"변신":"CardSet_One","마법인형":"Doll_CardSet_One","성물":"HolyStuff_CardSet_One"}
const GACHA_REVEAL_FRAMES: float=65.0
const CELL="Nd_Card/Change_Fusion_Card"
const Page=preload("res://scripts/ui/original_ui/source_main_change_page.gd")
const Presentation=preload("res://scripts/ui/source_card_presentation.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const CATEGORIES: Array[String]=["변신","마법인형","성물"]
const GRADES: Array[String]=["영웅","전설","신화","유일"]
## "" / retry / confirm / confirm_all / pick / gacha / result
var popup: String=""
## The reveal: {before{name,grade,record}, after{name,grade,record}}.
var reveal: Dictionary={}
var target: Dictionary={}
var quote: Dictionary={}
var pick: String=""

func required_members() -> Array[String]:
	return [ROOT,SLOT,RETRY,CONFIRM,PICK,PICK_ROW]

## The reveal scenes come with the ui43 pack; without them the list and
## the messages stay as before.
func _reveal_available() -> bool:
	return _pack!=null and _pack.manifest.get("scenes",{}).has(GACHA) and _pack.manifest.get("scenes",{}).has(RESULT)

func _root_member() -> String:
	return ROOT

func open(parent: Node) -> Dictionary:
	if world()==null or not world().has_method("card523_swap_quote"):return _fail("source_card_change_window_runtime_unavailable")
	popup=""
	return open_window(parent)

func _call(method: String, args: Array=[]) -> Variant:
	var owner: Object=world()
	return owner.callv(method,args) if owner!=null and owner.has_method(method) else null

func pending() -> Array:
	var value: Variant=_call("card523_swap_pending")
	return value if value is Array else []

## Catalog record of `identity` in `category` (the HUD's card catalog).
func record(category: String, identity: String) -> Dictionary:
	var owner: Object=hud()
	var catalog: Variant=owner.get("catalog_data") if owner!=null else null
	if not catalog is Dictionary:return {}
	for raw: Variant in catalog.get(category,[]):
		if raw is Dictionary and Cards.card_id(raw)==identity:return raw
	return {}

## Unconfirmed owned cards and pending results, waiting results first.
## Each row carries its category, identity, name, grade and source record.
func cards() -> Array:
	var owner: Object=hud()
	var catalog: Variant=owner.get("catalog_data") if owner!=null else null
	var state: Variant=owner.get("card_collection_state") if owner!=null else null
	var confirmed: Variant=_call("card523_swap_confirmed")
	if not confirmed is Dictionary:confirmed={}
	var waiting: Dictionary={}
	for row: Dictionary in pending():waiting[str(row.category)+"|"+str(row.identity)]=row
	var found: Array=[]
	if not catalog is Dictionary or not state is Dictionary:return found
	for category: String in CATEGORIES:
		var owned: Dictionary=state.get("owned",{}).get(category,{})
		var seen: Dictionary={}
		for raw: Variant in catalog.get(category,[]):
			if not raw is Dictionary or not str(raw.get("grade","")) in GRADES:continue
			var identity: String=Cards.card_id(raw)
			if seen.has(identity) or owned.get(identity,false)!=true:continue
			if confirmed.get(category,{}).has(identity) and not waiting.has(category+"|"+identity):continue
			seen[identity]=true
			found.append({"category":category,"identity":identity,"name":str(raw.get("name","")),"grade":str(raw.grade),"record":raw,"pending":waiting.get(category+"|"+identity,{})})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.pending.is_empty()!=b.pending.is_empty():return not a.pending.is_empty()
		if a.category!=b.category:return CATEGORIES.find(a.category)<CATEGORIES.find(b.category)
		return GRADES.find(a.grade)>GRADES.find(b.grade))
	return found

## The card a slot shows: the waiting result, else the card itself.
func shown(entry: Dictionary) -> Dictionary:
	var waiting: Dictionary=entry.get("pending",{})
	if waiting.is_empty():return {"name":entry.name,"grade":entry.grade,"record":entry.record}
	var result: Dictionary=waiting.get("result",{})
	return {"name":str(result.get("name","")),"grade":str(result.get("grade",entry.grade)),"record":record(str(entry.category),str(result.get("identity","")))}

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in ["Btn_Probability","Btn_CollectionView","Nd_CheckBox_All","Nd_Touch"]:spec[name]={"exclude":true}
	var all: Array=cards()
	var waiting: int=pending().size()
	spec["Nd_PageView/Label_Num"]={"role":"source_text","text":"총 %d개" % all.size()}
	spec["Btn_Confirm"]={"activate":Callable(self,"_confirm_all"),"displaystate":not all.is_empty()}
	for state: String in ["Nd_Normal","Nd_Disable"]:
		spec["Btn_Confirm/"+state+"/Label"]={"role":"source_text","text":"전체 확정"}
	var hint: String = "확정 대기 %d장 · 다시 뽑은 카드를 확정하면 획득합니다." % waiting
	if waiting==0: hint = "보유 카드를 그대로 확정하거나 다시 뽑을 수 있습니다."
	spec["Nd_PageView/Label_01"]={"role":"source_text","text":hint}
	spec["Nd_PageView/Nd_Notice"]={"visible":all.is_empty()}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var all: Array=cards()
	var rows: Array=[]
	for index: int in range(all.size()):
		var entry: Dictionary=all[index]
		var card: Dictionary=shown(entry)
		rows.append({"member":SLOT,"entry":entry,"card":card,"spec":{
			"Panel/Label_Card":{"role":"source_text","text":str(card.name)},
			"Panel/Btn_Normal":{"activate":Callable(self,"_ignore")},
			"Panel/Btn_Pressed":{"visible":false},
			"Panel/Btn_Retry":{"activate":Callable(self,"_retry").bind(index)},
			"Panel/Btn_Select":{"activate":Callable(self,"_confirm_entry").bind(entry),"displaystate":true},
			"Btn_Select/Sp_Icon":{"visible":false},
			"Btn_Select/Label_Time":{"visible":false},
			"Panel/Btn_Special":{"exclude":true}}})
	var placed: Dictionary=_fill_list(root,out,"Nd_PageView/ListView_Swipe",rows,NAN,true)
	if not placed.get("ok",false):return placed
	var pictures: int=0
	for index: int in range(rows.size()):
		if _card_prefab(placed.scenes[index],placed.outs[index],"Panel/Nd_Card",rows[index].card):pictures+=1
	var filled: Dictionary={"ok":true,"cards":rows.size(),"pictures":pictures,"popup":popup,"waiting":pending().size()}
	if not popup.is_empty():
		var shown_popup: Dictionary=_popup(root)
		if not shown_popup.get("ok",false):return shown_popup
		filled["popup_fill"]=shown_popup
	return filled

## The client card prefab Change_Card_A_<grade> in a Nd_Card slot.
func _card_prefab(scene: Node2D, out: Dictionary, suffix: String, card: Dictionary) -> bool:
	var grade: String=str(card.get("grade",""))
	if not Page.GRADE_MEMBERS.has(grade):return false
	var located: Dictionary=_locate(scene,out,suffix)
	if not located.get("ok",false):return false
	var slot: Node=located.player.source_nodes.get(located.offset)
	if not slot is Node2D:return false
	var card_out: Dictionary={}
	var built: Dictionary=_scene_of(str(Page.GRADE_MEMBERS[grade]),_prefab_spec(Callable()),card_out)
	if not built.get("ok",false):return false
	(slot as Node2D).add_child(built.scene)
	return _prefab_picture(built.scene,card_out,card.get("record",{}))

static func _prefab_spec(tap: Callable) -> Dictionary:
	var spec: Dictionary={"Panel_Root/CB_Check":{"exclude":true},"Nd_Character/CardSample":{"role":"source_asset_slot","visible":false},
		"Nd_Character/CardSample_A":{"exclude":true},"Panel_Root/Panel_Fx":{"exclude":true},"Panel_Root/Sp_Lock":{"exclude":true},"Panel_Root/Nd_Attribute":{"exclude":true}}
	if tap.is_valid():spec["Panel_Root"]={"input":tap}
	else:spec["Panel_Root"]={"role":"consume"}
	return spec

func _prefab_picture(scene: Node2D, out: Dictionary, raw: Dictionary) -> bool:
	if raw.is_empty():return false
	var card: Dictionary=_locate(scene,out,"Nd_Character/CardSample")
	if not card.get("ok",false):return false
	var detail: Dictionary=Presentation.detail(raw,true,false)
	if detail.get("status","")!="original" or not detail.get("texture") is Texture2D:return false
	return _show_picture(card.player,card.offset,{"ok":true,"texture":detail.texture,"provenance":detail.get("provenance",{}).duplicate(true),"role":str(detail.get("role",""))})

## --- Popups ---------------------------------------------------------------------

func _popup(root: Node2D) -> Dictionary:
	var spec: Dictionary={}
	if popup in ["gacha","result"]:return _reveal_popup(root)
	var member: String={"retry":RETRY,"confirm":CONFIRM,"confirm_all":CONFIRM,"pick":PICK}[popup]
	var card: Dictionary=shown(target) if popup!="confirm_all" else {}
	match popup:
		"retry":
			spec["Btn_Close"]={"activate":Callable(self,"_close_popup")}
			for name: String in ["Nd_Confirm/Text","Label_Caution"]:spec[name]={"exclude":true}
			spec["Btn_Probability"]={"activate":Callable(self,"_probability")}
			spec["Btn_ListView"]={"activate":Callable(self,"_candidate_list")}
			spec["Btn_Caution"]={"activate":Callable(self,"_caution")}
			spec["Nd_Confirm/Label_01"]={"role":"source_text","text":"남은 다시 뽑기 횟수 : %d회" % int(quote.get("remaining",0))}
			spec["Nd_Confirm/Label_02_Num"]={"role":"source_text","text":_number(int(quote.get("cost",{}).get("amount",0)))}
			spec["Nd_Confirm/Label_03_Num"]={"role":"source_text","text":_number(int(quote.get("diamonds",0)))}
			spec["Nd_Confirm/Label_Card"]={"role":"source_text","text":str(card.name)}
			spec["Nd_Confirm/Btn_Ok"]={"activate":Callable(self,"_swap")}
			spec["Nd_Confirm/Btn_No"]={"activate":Callable(self,"_close_popup")}
		"confirm":
			spec["Btn_Close"]={"activate":Callable(self,"_close_popup")}
			spec["Nd_Confirm/ListView"]={"exclude":true}
			spec["Nd_Confirm/Label_Card"]={"role":"source_text","text":str(card.name)}
			spec["Nd_Confirm/Btn_Ok"]={"activate":Callable(self,"_confirm_result")}
			spec["Nd_Confirm/Btn_No"]={"activate":Callable(self,"_close_popup")}
		"confirm_all":
			spec["Btn_Close"]={"activate":Callable(self,"_close_popup")}
			spec["Nd_Confirm/ListView"]={"exclude":true}
			spec["Nd_Confirm/Nd_Card"]={"exclude":true}
			spec["Nd_Confirm/Label_Card"]={"role":"source_text","text":"카드 %d장 전체 확정" % int(quote.count)}
			var blocked: int=int(quote.get("blocked",0))
			var detail: String="카드 %d장을 확정하고 목록에서 닫습니다." % int(quote.count)
			if blocked>0:detail+="\n조건을 충족하지 않은 %d장은 대기 상태로 유지됩니다." % blocked
			spec["Nd_Confirm/Label_01"]={"role":"source_text","text":detail}
			spec["Nd_Confirm/Btn_Ok"]={"activate":Callable(self,"_confirm_all_results")}
			spec["Nd_Confirm/Btn_Ok/Label"]={"role":"source_text","text":"전체 확정"}
			spec["Nd_Confirm/Btn_No"]={"activate":Callable(self,"_close_popup")}
		"pick":
			spec["Nd_Popup_Daily/Btn_Close"]={"activate":Callable(self,"_close_popup")}
			spec["Nd_Popup_Daily/Btn_Cancel"]={"activate":Callable(self,"_close_popup")}
			spec["Nd_Popup_Daily/Btn_Yes"]={"activate":Callable(self,"_swap")}
			spec["Btn_Yes/Disable"]={"visible":pick.is_empty()}
			spec["Nd_Popup_Daily/Label_Select_Num"]={"role":"source_text","text":"0" if not pick.is_empty() else "1"}
			for name: String in ["Fx_Popup_RightBottom","Fx_Popup_LeftUp"]:spec["Nd_Popup_Daily/"+name]={"exclude":true}
	var popup_out: Dictionary={}
	var built: Dictionary=_scene_of(member,spec,popup_out)
	if not built.get("ok",false):return built
	root.add_child(built.scene)
	var filled: Dictionary={"ok":true,"popup":popup}
	if popup in ["retry","confirm"]:
		filled["picture"]=_card_prefab(built.scene,popup_out,"Nd_Confirm/Nd_Card",card)
	elif popup=="pick":
		var rows: Array=[]
		for candidate: Dictionary in quote.get("pick_candidates",[]):
			var grade: String=str(candidate.get("grade",""))
			if not Page.GRADE_MEMBERS.has(grade):continue
			var spec_row: Dictionary=_prefab_spec(Callable(self,"_pick_input").bind(str(candidate.identity)))
			rows.append({"member":str(Page.GRADE_MEMBERS[grade]),"spec":spec_row,"candidate":candidate})
		var listed: Dictionary=_fill_list(built.scene,popup_out,"Nd_Popup_Daily/ListView_Card",rows,NAN,false,5)
		if not listed.get("ok",false):return listed
		for index: int in range(rows.size()):_prefab_picture(listed.scenes[index],listed.outs[index],record(str(target.category),str(rows[index].candidate.identity)))
		var names: Array=[]
		for candidate: Dictionary in quote.get("pick_candidates",[]):
			if str(candidate.identity)==pick:names.append({"member":PICK_ROW,"spec":{"Panel_List/Label_CardName":{"role":"source_text","text":str(candidate.get("name",""))}}})
		var chosen: Dictionary=_fill_list(built.scene,popup_out,"Nd_Popup_Daily/ListView_Select",names)
		if not chosen.get("ok",false):return chosen
		filled["candidates"]=rows.size()
		filled["picked"]=pick
	return filled

func _pick_input(event: InputEvent, identity: String) -> void:
	if (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed):_choose.call_deferred(identity)

## --- Actions --------------------------------------------------------------------

func _quote(entry: Dictionary) -> Dictionary:
	var value: Variant=_call("card523_swap_quote",[str(entry.category),str(entry.identity)])
	return value if value is Dictionary else {}

func _retry(index: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var all: Array=cards()
	if index<0 or index>=all.size():return {"ok":false}
	target=all[index]
	quote=_quote(target)
	pick=""
	popup="retry"
	return _stage()

func _confirm_entry(entry: Dictionary) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	target=entry
	var value: Variant=_call("card523_swap_quote",[str(entry.category),str(entry.identity),true])
	quote=value if value is Dictionary else {}
	if not bool(quote.get("can_confirm",false)):
		_message(str(quote.get("confirm_reason",quote.get("reason","확정할 결과가 없습니다"))))
		return {"ok":false}
	popup="confirm"
	return _stage()

func _confirm_all() -> Dictionary:
	var value: Variant=_call("card523_swap_quote_all")
	quote=value if value is Dictionary else {}
	if not quote.get("ok",false):
		_message(str(quote.get("reason","확정할 수 있는 대기 결과가 없습니다")))
		return {"ok":false}
	popup="confirm_all"
	return _stage()

func _confirm_all_results() -> Dictionary:
	var value: Variant=_call("card523_swap_confirm_all",[str(quote.get("token",""))])
	var done: Dictionary=value if value is Dictionary else {}
	_message(("카드 전체 확정: %d장" % int(done.count)) if done.get("ok",false) else str(done.get("reason","전체 확정 실패")))
	popup=""
	return _stage()

func _choose(identity: String) -> Dictionary:
	pick=identity
	return _stage()

## 뽑기 확률: the feature draws one of the quote's same-grade candidates
## evenly (card_swap523 execute), so each has 1 / candidate_count.
static func probability_text(offer: Dictionary) -> String:
	var count: int=int(offer.get("candidate_count",(offer.get("candidates",[]) as Array).size()))
	if count<=0:return "다시 뽑을 수 있는 카드가 없습니다"
	var each: String=("%.4f" % (100.0/float(count))).rstrip("0").rstrip(".")
	return "같은 등급 카드 %d종 중 1장이 나옵니다 (각 %s%%, 지금 카드 제외)" % [count,each]

## 목록 보기: the candidate names (the first 20, then the rest's count).
static func list_text(offer: Dictionary) -> String:
	var names: PackedStringArray=[]
	var candidates: Array=offer.get("candidates",[])
	for index: int in range(mini(20,candidates.size())):names.append(str(candidates[index].get("name","")))
	if names.is_empty():return "다시 뽑을 수 있는 카드가 없습니다"
	var more: int=candidates.size()-names.size()
	return "다시 뽑기 후보 %d종: %s%s" % [candidates.size()," · ".join(names)," 외 %d종" % more if more>0 else ""]

func _probability() -> Dictionary:
	_message(probability_text(quote))
	return {"ok":true}

func _candidate_list() -> Dictionary:
	_message(list_text(quote))
	return {"ok":true}

## 주의 사항: the feature's own rules (the original text is the cash / mileage
## notice TWILIGHT has no part of).
func _caution() -> Dictionary:
	_message("다시 뽑은 결과는 카드 확정을 눌러야 획득됩니다. 확정 전에는 원래 카드가 유지되며, 다시 뽑기는 영웅 이상 카드만 할 수 있습니다.")
	return {"ok":true}

func _close_popup() -> Dictionary:
	popup=""
	return _stage()

## 다시 뽑기: the quoted swap (the result waits for 카드 확정); the 6th swap
## first takes one of the fixed candidates.
func _swap() -> Dictionary:
	if not quote.get("ok",false):
		_message(str(quote.get("reason","다시 뽑을 수 없습니다")))
		return {"ok":false}
	if int(quote.get("pick_count",0))>0 and popup!="pick":
		popup="pick"
		return _stage()
	if int(quote.get("pick_count",0))>0 and pick.is_empty():
		_message("후보 카드를 선택하세요")
		return {"ok":false}
	var before: Dictionary=shown(target)
	var result: Variant=_call("card523_swap_execute",[str(quote.token),pick])
	var done: Dictionary=result if result is Dictionary else {}
	popup=""
	if done.get("ok",false):
		var after: Dictionary=done.get("pending",{}).get("result",{})
		_message("다시 뽑기 결과: %s · 카드 확정으로 획득합니다" % str(after.get("name","")))
		if _reveal_available():
			reveal={"category":str(target.category),"before":before,"after":{"name":str(after.get("name","")),"grade":str(after.get("grade","")),"record":record(str(target.category),str(after.get("identity","")))}}
			popup="gacha"
	else:_message(str(done.get("reason","다시 뽑기 실패")))
	return _stage()

## 카드 확정: the original card becomes the waiting result.
func _confirm_result() -> Dictionary:
	var result: Variant=_call("card523_swap_confirm",[str(quote.get("confirm_token",""))])
	var done: Dictionary=result if result is Dictionary else {}
	_message(("카드 확정: "+str(done.get("result",{}).get("name",""))) if done.get("ok",false) else str(done.get("reason","확정 실패")))
	popup=""
	if done.get("ok",false) and _reveal_available():
		var got: Dictionary=done.get("result",{})
		var identity: String=str(got.get("identity",got.get("id","")))
		var raw: Dictionary=record(str(done.get("category",target.get("category",""))),identity)
		reveal={"category":str(done.get("category","")),"after":{"name":str(got.get("name",raw.get("name",""))),"grade":str(got.get("grade",raw.get("grade",""))),"record":raw}}
		popup="result"
	return _stage()

## --- Reveal (CardChange_Gacha / CardChange_Result) ----------------------------

func _reveal_popup(root: Node2D) -> Dictionary:
	var after: Dictionary=reveal.get("after",{})
	var gacha: bool=popup=="gacha"
	var grade: String=str(after.get("grade",""))
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_popup")}
	spec["Nd_ButtonSet/Btn_Open"]={"activate":Callable(self,"_close_popup")}
	spec["FullFrameType_A/Fx_Img_BG_Particle"]={"exclude":true}
	if gacha:
		for name: String in ["Nd_Skill_Card","Fx_Skill_Screen"]:spec[name]={"exclude":true}
	else:
		spec["Btn_Close"]={"activate":Callable(self,"_close_popup")}
		# The authored sample card (a fixed 영웅 prefab) gives way to the result.
		spec["Nd_Card/Change_Card_A_Legend"]={"exclude":true}
	# The flip shows the light of the clip itself; the grade light is the
	# confirmed card's.
	GradeFx.cell_spec(self,spec,CELL+"/",grade if not gacha else "")
	spec[CELL+"/Text_Card_Name"]={"role":"source_text","text":str(after.get("name",""))}
	spec[CELL+"/Btn_Card"]={"activate":Callable(self,"_close_popup")}
	var popup_out: Dictionary={}
	var built: Dictionary=_scene_of(GACHA if gacha else RESULT,spec,popup_out)
	if not built.get("ok",false):return built
	var scene: Node2D=built.scene
	root.add_child(scene)
	var filled: Dictionary={"ok":true,"popup":popup,"pictures":0}
	if _cell_prefab(scene,popup_out,CELL+"/Panel",after):filled.pictures+=1
	if gacha:
		var before: Dictionary=reveal.get("before",{})
		if _cell_prefab(scene,popup_out,"Nd_Card_Before",before):filled.pictures+=1
		filled["clip"]=str(GACHA_CLIPS.get(str(reveal.get("category","")),"CardSet_One"))
		scene.play(str(filled.clip),false)
		var nested: Node2D=GradeFx.project(self,scene,popup_out,CELL)
		if nested!=null:
			var ref: WeakRef=weakref(nested)
			(Engine.get_main_loop() as SceneTree).create_timer(GACHA_REVEAL_FRAMES/60.0).timeout.connect(func() -> void:
				var live: Variant=ref.get_ref()
				if live!=null and is_instance_valid(live):live.play("Fx_Cardname",false))
	else:
		filled["clip"]="CardSet_One"
		scene.play("CardSet_One",false)
		var lit: Dictionary=GradeFx.light(self,scene,popup_out,CELL,grade)
		filled["lit"]=bool(lit.get("lit",false))
		if not filled.lit:
			var nested: Node2D=GradeFx.project(self,scene,popup_out,CELL)
			if nested!=null:nested.play("Fx_Cardname",false)
	return filled

## The client card prefab of `card` (Change_Card_A_<grade> with its picture)
## under the node at `suffix`.
func _cell_prefab(scene: Node2D, out: Dictionary, suffix: String, card: Dictionary) -> bool:
	var grade: String=str(card.get("grade",""))
	if not Page.GRADE_MEMBERS.has(grade):return false
	var located: Dictionary=_locate(scene,out,suffix)
	if not located.get("ok",false):return false
	var host: Variant=located.player.source_nodes.get(located.offset)
	if not host is Node2D:return false
	var card_out: Dictionary={}
	var built: Dictionary=_scene_of(str(Page.GRADE_MEMBERS[grade]),_prefab_spec(Callable()),card_out)
	if not built.get("ok",false):return false
	(host as Node2D).add_child(built.scene)
	return _prefab_picture(built.scene,card_out,card.get("record",{}))
