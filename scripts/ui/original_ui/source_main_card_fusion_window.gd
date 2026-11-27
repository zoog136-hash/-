extends "res://scripts/ui/original_ui/source_main_change_page.gd"
## The original 523 card fusion window: Change_WinTotal with its
## Change_DetailView_Mix page (일반 합성). The left list shows the owned cards
## of the category as Change_Card_A_<grade> with their own pictures, the
## grade sidebar (Change_WinTotal_Class) picks the material grade, and the
## right side shows the duplicates the player registered, the
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
var _registered: Array[String]=[]
var _covered_by_reveal: bool=false

func required_members() -> Array[String]:
	var members: Array[String]=[WIN_TOTAL,"UI/Change/Change_DetailView_Mix.csb",GRADE_ROW,CARD_SET]
	for member: String in GRADE_MEMBERS.values():members.append(member)
	return members

func _page() -> String:
	return "Change_DetailView_Mix"

func _tab() -> String:
	return "mix"

func open(parent: Node, category_name: String) -> Dictionary:
	if not Cards.CATEGORIES.has(category_name):return _fail("source_card_fusion_category_unsupported")
	if category_name!=category:filter_grade="전체"
	_registered.clear()
	_moved=0.0
	category=category_name
	return open_window(parent)

func set_reveal_covered(value: bool) -> void:
	if _covered_by_reveal==value or not is_open():return
	_covered_by_reveal=value
	_scene.visible=not value
	if value:
		_registered.clear()
	else:
		refresh()

func refresh() -> Dictionary:
	if _covered_by_reveal:
		return {"ok":true,"handled":true,"refresh_pending":true}
	return super.refresh()

func close() -> void:
	_covered_by_reveal=false
	super.close()

func _catalog() -> Array:
	var owner: Object=hud()
	return owner.get("catalog_data").get(category,[]) if owner!=null else []

static func _eligible(record: Dictionary) -> bool:
	# CardDrawFusion.configure omits pending draw-pool entries. fuse also
	# skips NoMerge cards. Both may still have a permanent roster entry.
	return not record.get("source_draw_pool_pending",false) and not record.get("source_merge_out_disabled",false)

## Duplicates of `current` grade the existing fusion may consume.
func _available(current: String) -> int:
	var total: int=0
	var seen: Dictionary={}
	for raw: Variant in _catalog():
		if not raw is Dictionary:continue
		var identity: String=Cards.card_id(raw)
		if identity.is_empty() or seen.has(identity):continue
		seen[identity]=true
		if str(raw.get("grade",""))==current and _eligible(raw) and _owned(identity):
			total+=_spare(identity)
	return total

func _collect() -> void:
	_owned_records.clear()
	_materials.clear()
	var seen: Dictionary={}
	var eligible: Dictionary={}
	for raw: Variant in _catalog():
		if not raw is Dictionary:continue
		var identity: String=Cards.card_id(raw)
		if identity.is_empty() or seen.has(identity):continue
		seen[identity]=true
		var current: String=str(raw.get("grade",""))
		if current==grade and _eligible(raw) and _owned(identity):eligible[identity]=raw
		var copies: int=(1 if _owned(identity) else 0)+_spare(identity)
		if copies>0 and (filter_grade=="전체" or current==filter_grade):_owned_records.append(raw)
	var kept: Array[String]=[]
	var counts: Dictionary={}
	for identity: String in _registered:
		if not eligible.has(identity) or int(counts.get(identity,0))>=_spare(identity):continue
		counts[identity]=int(counts.get(identity,0))+1
		kept.append(identity)
		_materials.append({"record":eligible[identity],"id":identity})
	_registered=kept
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

func _enough_materials(value: String) -> bool:
	var required: int=int(Cards.FUSION_MATERIALS.get(value,0))
	return required>0 and _available(value)>=required and not _point_progress(value).get("pending",false)

func _can_fuse() -> bool:
	return _registered.size() >= int(Cards.FUSION_MATERIALS.get(grade,1)) and _enough_materials(grade)

func _spec() -> Dictionary:
	_collect()
	var spec: Dictionary=_frame_spec()
	var required: int=int(Cards.FUSION_MATERIALS.get(grade,0))
	var target: String=str(Cards.FUSION_NEXT.get(grade,""))
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
	var need: int=maxi(0,required-_registered.size())
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
	var selected_ids: Dictionary={}
	for entry: Dictionary in _materials:selected_ids[entry.id]=true
	var cards: Array=[]
	for record: Dictionary in _owned_records:
		var identity: String=Cards.card_id(record)
		var selectable: bool=Cards.FUSION_MATERIALS.has(record.get("grade")) and _eligible(record) and _owned(identity) and _spare(identity)>_registered.count(identity)
		var card: Dictionary=_card_row(record,selected_ids.has(identity),Callable(self,"_card_pressed").bind(str(record.get("grade","")),identity))
		if card.is_empty():continue
		card.spec["Panel_Root/CB_Check"].displaystate=selectable
		card.spec["Panel_Root/CB_Check"].touch_enabled=selectable
		cards.append(card)
	var owned_path: String=P+"Nd_CardList/ListView"
	var owned: Dictionary=_material_grid(root,out,owned_path,cards)
	if not owned.get("ok",false):return owned
	var pictures: int=int(owned.get("pictures",0))
	var registered: Array=[]
	for entry: Dictionary in _materials:
		var card: Dictionary=_card_row(entry.record,false,Callable(self,"_registered_pressed").bind(str(entry.id)))
		if not card.is_empty():registered.append(card)
	var material_path: String=P+"Nd_CardMix/Nd_Card/ListView"
	var materials: Dictionary=_material_grid(root,out,material_path,registered)
	if not materials.get("ok",false):return materials
	pictures+=int(materials.get("pictures",0))
	return {"ok":true,"category":category,"grade":grade,"filter":filter_grade,"cards":cards.size(),"built_cards":int(owned.get("built",0)),"registered":registered.size(),"pictures":pictures,"can_fuse":_can_fuse(),"available":_available(grade),"required":int(Cards.FUSION_MATERIALS.get(grade,0))}

func _material_grid(root: Node2D, out: Dictionary, path: String, cards: Array) -> Dictionary:
	var margin: float=float(_node_options(out,path).get("itemMargin",0))
	var decorate: Callable=func(scene: Node2D,card_out: Dictionary,card: Dictionary) -> bool:
		_forward_row_drags(scene,"/"+path)
		return _card_picture(scene,card_out,card.record)
	return _optional(_fill_card_grid(root,out,path,cards,decorate,margin))

func _select_filter(value: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	filter_grade=value
	if value!="전체" and value!=grade:
		grade=value
		_registered.clear()
	return _stage()

func _card_pressed(_checked: bool, value: String, identity: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var required: int=int(Cards.FUSION_MATERIALS.get(value,0))
	if required==0 or not _owned(identity) or _spare(identity)==0:return _stage()
	if value!=grade:_registered.clear()
	grade=value
	if _registered.count(identity)<_spare(identity) and _registered.size()<required*Cards.MAX_FUSION_BATCH:
		_registered.append(identity)
	return _stage()

func _registered_pressed(_checked: bool, identity: String) -> Dictionary:
	if not _dragged():_registered.erase(identity)
	return _stage()

## Fill complete groups, preferring the current material grade.
func _auto_register() -> Dictionary:
	if not _enough_materials(grade):
		var next: int=MATERIAL_GRADES.find_custom(_enough_materials)
		if next<0:
			_message("합성할 수 있는 중복 카드가 없습니다")
			return {"ok":false,"code":"card_fusion_no_materials"}
		grade=MATERIAL_GRADES[next]
		filter_grade="전체"
		_registered.clear()
	var required: int=int(Cards.FUSION_MATERIALS[grade])
	var cap: int=mini(_available(grade)/required,Cards.MAX_FUSION_BATCH)*required
	var seen: Dictionary={}
	for record: Dictionary in _catalog():
		var identity: String=Cards.card_id(record)
		if record.get("grade")!=grade or not _owned(identity) or not _eligible(record) or seen.has(identity):continue
		seen[identity]=true
		var remaining: int=mini(_spare(identity)-_registered.count(identity),cap-_registered.size())
		for copy: int in range(remaining):_registered.append(identity)
		if _registered.size()>=cap:break
	return _stage()

func _merge() -> Dictionary:
	var owner: Object=hud()
	if _registered.is_empty():
		_message("먼저 합성 재료를 등록해 주세요")
		return {"ok":false,"code":"card_fusion_registration_empty"}
	if owner==null or not _can_fuse():
		_message("같은 등급의 중복 카드 %d장이 필요합니다" % int(Cards.FUSION_MATERIALS.get(grade,0)))
		return {"ok":false,"code":"card_fusion_materials_short"}
	owner.call("_confirm_card_fusion_request",category,grade,_registered.duplicate())
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
