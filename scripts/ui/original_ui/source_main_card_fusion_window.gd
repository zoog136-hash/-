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
## 보상 받기 mileage reward, the 실패 이력 history and the third/fourth
## mileage gauges.
## The page's own content sits under its Nd_Card_Change node.
const P="Change_DetailView_Mix/Nd_Card_Change/"
const MATERIAL_GRADES: Array[String]=["일반","고급","희귀","영웅","전설","신화"]
const MAX_CARDS: int=150
var grade: String="고급"
var filter_grade: String="전체"
var _owned_records: Array[Dictionary]=[]
var _materials: Array[Dictionary]=[]

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
		if copies>0 and (filter_grade=="전체" or current==filter_grade) and _owned_records.size()<MAX_CARDS:_owned_records.append(raw)
	_owned_records.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return Cards.GRADES.find(str(a.grade))>Cards.GRADES.find(str(b.grade)))

func _can_fuse() -> bool:
	var required: int=int(Cards.FUSION_MATERIALS.get(grade,0))
	return required>0 and _available(grade)>=required

func _spec() -> Dictionary:
	_collect()
	var spec: Dictionary=_frame_spec()
	var required: int=int(Cards.FUSION_MATERIALS.get(grade,0))
	var target: String=str(Cards.FUSION_NEXT.get(grade,""))
	var available: int=_available(grade)
	var pity: Dictionary=hud().get("card_collection_state").get("pity",{}).get(category,{})
	spec[P+"Nd_SelectEffect"]={"exclude":true}
	spec[P+"Nd_Fail_History"]={"visible":false}
	# 합성 시도 보상: TWILIGHT keeps pity for 희귀 and 영웅 (PITY_LIMIT tries).
	var mileage: String=P+"Nd_Mileage/"
	spec[mileage+"Btn_HelpBox"]={"activate":Callable(self,"_help")}
	for index: int in range(4):
		var gauge: String=mileage+"Nd_Gauge_0%d" % (index+1)
		if index>=Cards.PITY_GRADES.size():
			spec[gauge]={"visible":false}
			continue
		var count: int=int(pity.get(Cards.PITY_GRADES[index],0))
		spec[gauge+"/Gauge_Bar"]={"role":"source_percent","percent":100.0*float(count)/float(Cards.PITY_LIMIT)}
		spec[gauge+"/Label_Num"]={"role":"source_text","text":"%02d" % count}
		spec[gauge+"/Label_Num_1"]={"role":"source_text","text":"%02d" % Cards.PITY_LIMIT}
	var mix: String=P+"Nd_CardMix/"
	spec[mix+"Label_Tip"]={"visible":_materials.is_empty()}
	spec[mix+"Label_Tip02"]={"role":"source_text","text":"%s ~ %s 1장 획득 가능!" % [grade,target] if required>0 else "유일 등급은 합성할 수 없습니다"}
	spec[mix+"Btn_Probability"]={"activate":Callable(self,"_probability")}
	var pity_grade: bool=Cards.PITY_GRADES.has(grade)
	spec[mix+"Nd_Mileage_Reward"]={"visible":pity_grade}
	spec[mix+"Nd_Mileage_Reward/Btn_Reward"]={"visible":false}
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
	var owned: Dictionary=_optional(_fill_card_grid(root,out,P+"Nd_CardList/ListView",cards))
	if not owned.get("ok",false):return owned
	var pictures: int=0
	for index: int in range((owned.scenes as Array).size()):
		if _card_picture(owned.scenes[index],owned.outs[index],cards[index].record):pictures+=1
	var registered: Array=[]
	for entry: Dictionary in _materials:
		for copy: int in range(int(entry.count)):
			var card: Dictionary=_card_row(entry.record,false,Callable(self,"_registered_pressed"))
			if not card.is_empty():registered.append(card)
	var materials: Dictionary=_optional(_fill_card_grid(root,out,P+"Nd_CardMix/Nd_Card/ListView",registered))
	if not materials.get("ok",false):return materials
	for index: int in range((materials.scenes as Array).size()):
		if _card_picture(materials.scenes[index],materials.outs[index],registered[index].record):pictures+=1
	return {"ok":true,"category":category,"grade":grade,"filter":filter_grade,"cards":cards.size(),"registered":registered.size(),"pictures":pictures,"can_fuse":_can_fuse(),"available":_available(grade),"required":int(Cards.FUSION_MATERIALS.get(grade,0))}

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

func _help() -> Dictionary:
	_message("합성 시도 보상: 희귀·영웅 합성 %d회 연속 실패 시 상위 등급 카드 1장 추가 (TWILIGHT 규칙)" % Cards.PITY_LIMIT)
	return {"ok":true}

func _fixed() -> Dictionary:
	_message("확정 합성: 원본 규칙 데이터가 없어 연결하지 않았습니다")
	return {"ok":false,"code":"card_fixed_fusion_not_connected"}
