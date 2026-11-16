extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## Shared part of the original 523 빠른 변신 / 빠른 소환 windows
## (source_main_quick_change_window / source_main_quick_summon_window).
## TWILIGHT 근사 (user decision 2026-11-16): the client's quick list has no
## TWILIGHT feature, so the windows keep a small favourites list: up to
## SLOTS owned cards of the category (the original CSB's card cells),
## stored in the save under world.ui_preferences["quick_card523"][category]
## (card ids); a tap on a registered card runs the existing catalog equip
## (hud catalog_equip_requested -> World._equip_catalog, which checks
## ownership and saves), 해제 runs it with no card. Nothing else is changed.
const Page=preload("res://scripts/ui/original_ui/source_main_change_page.gd")
const Presentation=preload("res://scripts/ui/source_card_presentation.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const SAVE_KEY="quick_card523"
## Cards per page of the client's ListView_1..3 (three rows of three).
const PER_ROW: int=3
const ROWS: Array[String]=["ListView_1","ListView_2","ListView_3"]
const SLOTS: int=9
var page: int=0

func category() -> String:
	return "변신"

func _grade_members() -> Array[String]:
	var members: Array[String]=[]
	for member: String in Page.GRADE_MEMBERS.values():members.append(member)
	return members

## --- Model ----------------------------------------------------------------------

## Owned cards of the category, highest grade first (catalog order within a grade).
func owned_cards(grade: String="") -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var owner: Object=hud()
	var catalog: Variant=owner.get("catalog_data") if owner!=null else null
	var state: Variant=owner.get("card_collection_state") if owner!=null else null
	if not catalog is Dictionary or not state is Dictionary:return result
	var owned: Dictionary=state.get("owned",{}).get(category(),{})
	var by_grade: Dictionary={}
	var seen: Dictionary={}
	for raw: Variant in catalog.get(category(),[]):
		if not raw is Dictionary:continue
		var id: String=Cards.card_id(raw)
		var card_grade: String=str(raw.get("grade",""))
		if seen.has(id) or owned.get(id,false)!=true or not Page.GRADE_MEMBERS.has(card_grade):continue
		if not grade.is_empty() and card_grade!=grade:continue
		seen[id]=true
		if not by_grade.has(card_grade):by_grade[card_grade]=[]
		by_grade[card_grade].append(raw)
	var grades: Array=Cards.GRADES.duplicate()
	grades.reverse()
	for card_grade: Variant in grades:
		for record: Dictionary in by_grade.get(str(card_grade),[]):result.append(record)
	return result

func _record(id: String) -> Dictionary:
	for record: Dictionary in owned_cards():
		if Cards.card_id(record)==id:return record
	return {}

## The registered card ids (owned ones only, at most SLOTS).
func registered() -> Array[String]:
	var owner: Object=world()
	var prefs: Variant=owner.get("ui_preferences") if owner!=null else null
	var stored: Variant=prefs.get(SAVE_KEY,{}).get(category(),[]) if prefs is Dictionary and prefs.get(SAVE_KEY,{}) is Dictionary else []
	var result: Array[String]=[]
	if not stored is Array:return result
	for value: Variant in stored:
		var id: String=str(value)
		if not id in result and not _record(id).is_empty() and result.size()<SLOTS:result.append(id)
	return result

func _store(ids: Array[String]) -> void:
	var owner: Object=world()
	var prefs: Variant=owner.get("ui_preferences") if owner!=null else null
	if not prefs is Dictionary:return
	if not prefs.get(SAVE_KEY) is Dictionary:prefs[SAVE_KEY]={}
	prefs[SAVE_KEY][category()]=Array(ids)
	if owner.has_method("_request_deferred_save"):owner.call("_request_deferred_save")

## Registers `id` in the first free slot, or takes it out when registered.
func toggle(id: String) -> Dictionary:
	var ids: Array[String]=registered()
	if id in ids:
		ids.erase(id)
		_store(ids)
		_message("빠른 목록에서 뺐습니다")
		return {"ok":true,"removed":id}
	if ids.size()>=SLOTS:
		_message("빠른 목록은 %d칸까지입니다" % SLOTS)
		return {"ok":false,"full":true}
	if _record(id).is_empty():return {"ok":false}
	ids.append(id)
	_store(ids)
	_message("빠른 목록 %d번에 등록했습니다" % ids.size())
	return {"ok":true,"added":id}

func clear_all() -> Dictionary:
	_store([] as Array[String])
	_message("빠른 목록을 모두 초기화했습니다")
	return {"ok":true}

func equipped_id() -> String:
	var owner: Object=hud()
	var state: Variant=owner.get("character_state") if owner!=null else null
	var equipped: Variant=state.get("equipped",{}).get(category(),{}) if state is Dictionary else {}
	return Cards.card_id(equipped) if equipped is Dictionary and not (equipped as Dictionary).is_empty() else ""

## The existing catalog equip (an empty record takes the card off).
func equip(id: String) -> Dictionary:
	var owner: Object=hud()
	if owner==null or not owner.has_signal("catalog_equip_requested"):return _fail("source_quick_card_equip_unavailable")
	var record: Dictionary=_record(id) if not id.is_empty() else {}
	if not id.is_empty() and record.is_empty():return {"ok":false}
	owner.emit_signal("catalog_equip_requested",category(),record.duplicate(true))
	return {"ok":true,"equip_requested":id}

## --- Cards ----------------------------------------------------------------------

static func _released(event: InputEvent) -> bool:
	return (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT)) and not event.pressed

func _prefab_spec(tap: Callable, selected: bool=false, check: Callable=Callable()) -> Dictionary:
	var spec: Dictionary={"Panel_Root/CB_Check":{"exclude":true},"Nd_Character/CardSample":{"role":"source_asset_slot","visible":false},
		"Nd_Character/CardSample_A":{"exclude":true},"Panel_Root/Panel_Fx":{"exclude":true},"Panel_Root/Sp_Lock":{"exclude":true},"Panel_Root/Nd_Attribute":{"exclude":true}}
	spec["Panel_Root"]={"input":tap} if tap.is_valid() else {"role":"consume"}
	if selected and check.is_valid():spec["Panel_Root/CB_Check"]={"role":"checkbox","selected":true,"activate":check}
	return spec

## A tap on a checked card's CheckBox runs the card's own action.
func _checked(_checked_now: bool, action: String, id: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	return call(action,id)

func _prefab_picture(scene: Node2D, out: Dictionary, raw: Dictionary) -> bool:
	if raw.is_empty():return false
	var card: Dictionary=_locate(scene,out,"Nd_Character/CardSample")
	if not card.get("ok",false):return false
	var detail: Dictionary=Presentation.detail(raw,true,false)
	if detail.get("status","")!="original" or not detail.get("texture") is Texture2D:return false
	return _show_picture(card.player,card.offset,{"ok":true,"texture":detail.texture,"provenance":detail.get("provenance",{}).duplicate(true),"role":str(detail.get("role",""))})

## One page of `records` over ListView_1..3 under `prefix` (three per row);
## `tap` is called with the card id, `marked` ids show the check mark.
func _fill_pages(root: Node2D, out: Dictionary, prefix: String, records: Array[Dictionary], tap: String, marked: Array[String]) -> Dictionary:
	var pages: int=maxi(1,ceili(float(records.size())/float(PER_ROW*ROWS.size())))
	page=clampi(page,0,pages-1)
	var start: int=page*PER_ROW*ROWS.size()
	var shown: int=0
	var pictures: int=0
	for r: int in range(ROWS.size()):
		var line: Array=[]
		for index: int in range(start+r*PER_ROW,mini(start+(r+1)*PER_ROW,records.size())):
			var record: Dictionary=records[index]
			var id: String=Cards.card_id(record)
			line.append({"member":str(Page.GRADE_MEMBERS[str(record.grade)]),"spec":_prefab_spec(Callable(self,"_card_input").bind(tap,id),id in marked,Callable(self,"_checked").bind(tap,id)),"record":record})
		var placed: Dictionary=_fill_list(root,out,prefix+ROWS[r],line,NAN,true)
		if not placed.get("ok",false):return placed
		for index: int in range(line.size()):
			if _prefab_picture(placed.scenes[index],placed.outs[index],line[index].record):pictures+=1
		shown+=line.size()
	return {"ok":true,"pages":pages,"shown":shown,"pictures":pictures}

func _card_input(event: InputEvent, action: String, id: String) -> void:
	if not _released(event) or _dragged():return
	call(action,id)

func _page(delta: int) -> Dictionary:
	page+=delta
	return _stage()
