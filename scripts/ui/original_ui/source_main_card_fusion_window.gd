extends "res://scripts/ui/original_ui/source_main_change_page.gd"
## The original 523 card fusion window: Change_WinTotal with its
## Change_DetailView_Mix page (일반 합성). The left list shows the owned cards
## of the category as Change_Card_A_<grade> with their own pictures, the
## grade sidebar (Change_WinTotal_Class) picks the material grade, and the
## right side shows the duplicates the existing rule would consume, the
## 실패 횟수/합성 시도 보상 gauges (희귀/영웅 pity) and the original
## 카드 자동 등록 / 합 성 buttons. 합 성 goes through the existing
## confirmation (renewal_hud._confirm_card_fusion_request ->
## card_fusion_requested -> TwilightCardDrawFusion.fuse); rules, rolls and
## saves stay there. Change_Fusion_All is the client's result reveal page
## (PageView of Change_Fusion_CardSet): the existing card reveal keeps
## showing results. Not connected (no TWILIGHT rule): 확정 합성, the
## fourth mileage gauge (no verified point lane).
## The page's own content sits under its Nd_Card_Change node.
const P="Change_DetailView_Mix/Nd_Card_Change/"
const MATERIAL_GRADES: Array[String]=["일반","고급","희귀","영웅","전설","신화"]
var grade: String="고급"
var filter_grade: String="전체"
var _owned_records: Array[Dictionary]=[]
var _materials: Array[Dictionary]=[]
var _covered_by_reveal: bool=false
var _refresh_when_uncovered: bool=false

func required_members() -> Array[String]:
	var members: Array[String]=[WIN_TOTAL,GRADE_ROW,CARD_SET]
	for member: String in GRADE_MEMBERS.values():members.append(member)
	return members

func _page() -> String:
	return "Change_DetailView_Mix"

func _tab() -> String:
	return "mix"

func open(parent: Node, category_name: String) -> Dictionary:
	if not Cards.CATEGORIES.has(category_name):return _fail("source_card_fusion_category_unsupported")
	if category_name!=category:filter_grade="전체"
	category=category_name
	return open_window(parent)

func set_reveal_covered(value: bool) -> void:
	if _covered_by_reveal==value or not is_open():return
	_covered_by_reveal=value
	_scene.visible=not value
	if not value and _refresh_when_uncovered:
		_refresh_when_uncovered=false
		refresh()

func refresh() -> Dictionary:
	if _covered_by_reveal:
		_refresh_when_uncovered=true
		return {"ok":true,"handled":true,"refresh_pending":true}
	return super.refresh()

func close() -> void:
	_covered_by_reveal=false
	_refresh_when_uncovered=false
	super.close()

func _catalog() -> Array:
	var owner: Object=hud()
	return owner.get("catalog_data").get(category,[]) if owner!=null else []

## Duplicates of `current` grade the existing fusion may consume.
func _available(current: String) -> int:
	var total: int=0
	var seen: Dictionary={}
	for raw: Variant in _catalog():
		if not raw is Dictionary:continue
		var identity: String=Cards.card_id(raw)
		if str(raw.get("grade",""))==current and not seen.has(identity) and not bool(raw.get("source_merge_out_disabled",false)):
			seen[identity]=true
			total+=_spare(identity)
	return total

func _collect() -> void:
	_owned_records.clear()
	_materials.clear()
	var seen: Dictionary={}
	var remaining: int=int(Cards.FUSION_MATERIALS.get(grade,0))
	for raw: Variant in _catalog():
		if not raw is Dictionary:continue
		var identity: String=Cards.card_id(raw)
		if identity.is_empty() or seen.has(identity):continue
		seen[identity]=true
		var current: String=str(raw.get("grade",""))
		if current==grade and remaining>0 and not bool(raw.get("source_merge_out_disabled",false)):
			var used: int=mini(remaining,_spare(identity))
			if used>0:
				_materials.append({"record":raw,"count":used})
				remaining-=used
		var copies: int=(1 if _owned(identity) else 0)+_spare(identity)
		if copies>0 and (filter_grade=="전체" or current==filter_grade):_owned_records.append(raw)
	# Every owned card of the filter, highest grade first (stable: ties keep
	# the catalog order); the list builds only the rows in view.
	var keyed: Array=[]
	for index: int in range(_owned_records.size()):keyed.append([-Cards.GRADES.find(str(_owned_records[index].get("grade",""))),index])
	keyed.sort()
	var ordered: Array[Dictionary]=[]
	for entry: Array in keyed:ordered.append(_owned_records[int(entry[1])])
	_owned_records=ordered

func _point_progress(current:String)->Dictionary:
	var owner:Object=hud()
	return owner.call("source_fusion_progress",category,current) if owner!=null and owner.has_method("source_fusion_progress") else {}

func _can_fuse() -> bool:
	var required: int=int(Cards.FUSION_MATERIALS.get(grade,0))
	return required>0 and not _point_progress(grade).get("pending",false) and _available(grade)>=required

func _spec() -> Dictionary:
	_collect()
	var spec: Dictionary=_frame_spec()
	var required: int=int(Cards.FUSION_MATERIALS.get(grade,0))
	var target: String=str(Cards.FUSION_NEXT.get(grade,""))
	var available: int=_available(grade)
	var pity: Dictionary=hud().get("card_collection_state").get("pity",{}).get(category,{})
	spec[P+"Nd_SelectEffect"]={"exclude":true}
	# 실패 이력 조회: the original FailHistory_All over the TJ failure records.
	spec[P+"Nd_Fail_History"]={"visible":true}
	spec[P+"Nd_Fail_History/Btn_History"]={"activate":Callable(self,"_fail_history")}
	# The third original lane has 20 points as well. The unsupported fourth
	# gauge stays absent; the source-less game keeps its existing two gauges.
	var mileage: String=P+"Nd_Mileage/"
	spec[mileage+"Btn_HelpBox"]={"activate":Callable(self,"_help")}
	for index: int in range(4):
		var gauge: String=mileage+"Nd_Gauge_0%d" % (index+1)
		var tier:String=Cards.ORIGINAL_POINT_GRADES[index] if index<Cards.ORIGINAL_POINT_GRADES.size() else ""
		if tier.is_empty() or (tier not in Cards.PITY_GRADES and not _point_progress(tier).get("known",false)):
			spec[gauge]={"visible":false}
			continue
		var count:int=int(pity.get(tier,0))
		spec[gauge+"/Gauge_Bar"]={"role":"source_percent","percent":100.0*float(count)/float(Cards.PITY_LIMIT)}
		spec[gauge+"/Label_Num"]={"role":"source_text","text":"%02d" % count}
		spec[gauge+"/Label_Num_1"]={"role":"source_text","text":"%02d" % Cards.PITY_LIMIT}
	var mix: String=P+"Nd_CardMix/"
	spec[mix+"Label_Tip"]={"visible":_materials.is_empty()}
	spec[mix+"Label_Tip02"]={"role":"source_text","text":"%s ~ %s 1장 획득 가능!" % [grade,target] if required>0 else "유일 등급은 합성할 수 없습니다"}
	spec[mix+"Btn_Probability"]={"activate":Callable(self,"_probability")}
	var points:Dictionary=_point_progress(grade)
	var pity_grade:bool=Cards.PITY_GRADES.has(grade) or points.get("known",false)
	var pending:bool=bool(points.get("pending",false))
	spec[mix+"Nd_Mileage_Reward"]={"visible":pity_grade}
	spec[mix+"Nd_Mileage_Reward/Btn_Reward"]={"visible":pending,"displaystate":pending,"activate":Callable(self,"_claim_reward")}
	var fails: int=int(pity.get(grade,0))
	spec[mix+"Nd_Mileage_Reward/Gauge_Bar"]={"role":"source_percent","percent":100.0*float(fails)/float(Cards.PITY_LIMIT)}
	spec[mix+"Nd_Mileage_Reward/Label_Num"]={"role":"source_text","text":"%02d" % fails}
	spec[mix+"Nd_Mileage_Reward/Label_Num_1"]={"role":"source_text","text":"%02d" % Cards.PITY_LIMIT}
	spec[mix+"Nd_Fixed"]={"visible":false}
	var can_fuse: bool=_can_fuse()
	spec[mix+"Btn_Auto"]={"activate":Callable(self,"_auto_register")}
	spec[mix+"Btn_Merge"]={"activate":Callable(self,"_merge"),"displaystate":can_fuse}
	var need: int=maxi(0,required-available)
	spec[mix+"Node_Condition"]={"visible":need>0 and required>0}
	spec[mix+"Node_Condition/Label_Dummy"]={"role":"source_text","text":"%s 카드 %d장 추가" % [grade,need]}
	spec[mix+"Nd_TabMenu/Btn_Normal_On"]={"visible":true}
	spec[mix+"Nd_TabMenu/Btn_Normal_Off"]={"visible":false}
	spec[mix+"Nd_TabMenu/Btn_Fixed_On"]={"visible":false}
	spec[mix+"Nd_TabMenu/Btn_Fixed_Off"]={"activate":Callable(self,"_fixed")}
	spec[mix+"Nd_Card/Label_Message"]={"visible":_materials.is_empty()}
	spec[P+"Nd_CardList/Nd_Notice"]={"visible":_owned_records.is_empty()}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var sidebar: Array=[]
	var total: int=0
	for current: String in MATERIAL_GRADES:total+=_available(current)
	for current: String in SIDEBAR:
		var text: String="( %d )" % total if current=="전체" else ("( %d / %d )" % [_available(current),int(Cards.FUSION_MATERIALS[current])] if Cards.FUSION_MATERIALS.has(current) else "( %d )" % _available(current))
		sidebar.append(_grade_row(current,text,current==filter_grade,Callable(self,"_select_filter").bind(current)))
	var grades: Dictionary=_optional(_fill_list(root,out,P+"Nd_Tab/ListView_Class",sidebar))
	if not grades.get("ok",false):return grades
	var cards: Array=[]
	for record: Dictionary in _owned_records:
		var card: Dictionary=_card_row(record,str(record.get("grade",""))==grade,Callable(self,"_card_pressed").bind(str(record.get("grade",""))))
		if not card.is_empty():cards.append(card)
	var decorate: Callable=func(scene: Node2D,card_out: Dictionary,card: Dictionary) -> bool:return _card_picture(scene,card_out,card.record)
	var owned: Dictionary=_optional(_fill_card_grid(root,out,P+"Nd_CardList/ListView",cards,decorate))
	if not owned.get("ok",false):return owned
	var pictures: int=int(owned.get("pictures",0))
	var registered: Array=[]
	for entry: Dictionary in _materials:
		for copy: int in range(int(entry.count)):
			var card: Dictionary=_card_row(entry.record,false,Callable(self,"_registered_pressed"))
			if not card.is_empty():registered.append(card)
	var materials: Dictionary=_optional(_fill_card_grid(root,out,P+"Nd_CardMix/Nd_Card/ListView",registered,decorate))
	if not materials.get("ok",false):return materials
	pictures+=int(materials.get("pictures",0))
	return {"ok":true,"category":category,"grade":grade,"filter":filter_grade,"cards":cards.size(),"built_cards":int(owned.get("built",0)),"registered":registered.size(),"pictures":pictures,"can_fuse":_can_fuse(),"available":_available(grade),"required":int(Cards.FUSION_MATERIALS.get(grade,0))}

func _select_filter(value: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	filter_grade=value
	if Cards.FUSION_MATERIALS.has(value):grade=value
	return _stage()

func _card_pressed(_checked: bool, value: String) -> Dictionary:
	if _dragged():return _stage()
	if Cards.FUSION_MATERIALS.has(value):grade=value
	return _stage()

func _registered_pressed(_checked: bool) -> Dictionary:
	return _stage()

## The existing view's 카드 자동 등록: the lowest grade with enough duplicates.
func _auto_register() -> Dictionary:
	if _can_fuse():return _stage()
	for current: String in MATERIAL_GRADES:
		if _available(current)>=int(Cards.FUSION_MATERIALS[current]):
			grade=current
			filter_grade="전체"
			return _stage()
	_message("합성할 수 있는 중복 카드가 없습니다")
	return {"ok":false,"code":"card_fusion_no_materials"}

func _merge() -> Dictionary:
	var owner: Object=hud()
	if owner==null or not _can_fuse():
		_message("같은 등급의 중복 카드 %d장이 필요합니다" % int(Cards.FUSION_MATERIALS.get(grade,0)))
		return {"ok":false,"code":"card_fusion_materials_short"}
	owner.call("_confirm_card_fusion_request",category,grade)
	return {"ok":true,"existing_confirmation":true,"category":category,"grade":grade}

func _probability() -> Dictionary:
	_message("현재 게임 합성 성공률 %.2f%% · 처음 획득한 카드 1장은 영구 보관되며 중복만 소비됩니다" % (float(Cards.FUSION_WEIGHTS.get(grade,0))/100.0))
	return {"ok":true}

## 실패 이력 조회: FailHistory_All over this window (this category's 합성).
func _fail_history() -> Dictionary:
	var owner: Object=hud()
	var controller: Variant=owner.get("original_main_ui_controller") if owner!=null else null
	if not is_instance_valid(controller):return _fail("source_fail_history_controller_unavailable")
	var start: String={"변신":"Btn_Change_Mix","마법인형":"Btn_Magic_Mix","성물":"Btn_HolyRelics_Mix"}.get(category,"Btn_Change_Mix")
	if controller.has_method("try_open_overlay_window"):return controller.try_open_overlay_window("fail_history",[start])
	return controller.try_open_feature_window("fail_history",[start])

func _claim_reward() -> Dictionary:
	var owner:Object=hud()
	if owner==null or not owner.has_method("_claim_source_fusion_reward"):return _fail("source_fusion_reward_unavailable")
	return owner.call("_claim_source_fusion_reward",category,grade)

func _help() -> Dictionary:
	var points:Dictionary=_point_progress(grade)
	if points.get("known",false):_message("합성 실패나 전용 주문서로 점수를 모으고, 20점에서 보상 받기를 누르세요.")
	else:_message("TWILIGHT 기본 합성: 희귀·영웅 실패 %d회 누적 시 상위 등급 카드 1장 추가" % Cards.PITY_LIMIT)
	return {"ok":true}

func _fixed() -> Dictionary:
	_message("확정 합성: 원본 규칙 데이터가 없어 연결하지 않았습니다")
	return {"ok":false,"code":"card_fixed_fusion_not_connected"}
