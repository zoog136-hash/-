extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 토템 window: Totem_All (frame, title, close, help) with
## one Totem_List_Totem per Totem row (Lv/name, 몬스터 처치 progress bar and
## count, active or inactive state), the 토템 효과 list
## (Totem_List_Effect_Collection: acquired options, applied AC/MR/리덕션)
## and the 공명 효과 list (Totem_List_Effect_Resonance: every TotemResonance
## threshold, reached ones on). Values come from world.totems
## (scripts/progression/totem_runtime.gd). Tapping a totem opens the
## existing TWILIGHT totem view for 성장/제작/설정, whose actions keep every
## rule and save. Not connected: the totem Spine art (Nd_Spine; Spine
## skeletons are not rendered) and Totem_Popup_Enchant (its material and
## probability rows have no binding here yet).
const ROOT="UI/Totem/Totem_All.csb"
const TOTEM="UI/Totem/Totem_List_Totem.csb"
const EFFECT="UI/Totem/Totem_List_Effect_Collection.csb"
const RESONANCE="UI/Totem/Totem_List_Effect_Resonance.csb"
var _resonance: bool=false

func required_members() -> Array[String]:
	return [ROOT,TOTEM,EFFECT,RESONANCE]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("totems") if owner!=null else null

func open(parent: Node) -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null or not runtime.available():return _fail("source_totem_definitions_unavailable")
	return open_window(parent)

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Btn_HelpBox"]={"activate":Callable(self,"_help")}
	spec["Nd_Content/Nd_Collection"]={"visible":not _resonance}
	spec["Nd_Content/Nd_Resonance"]={"visible":_resonance}
	spec["Nd_Btn/Btn_Collection_Effect"]={"visible":_resonance,"activate":Callable(self,"_toggle")}
	spec["Nd_Btn/Btn_Resonance_Effect"]={"visible":not _resonance,"activate":Callable(self,"_toggle")}
	return spec

static func _scalar(effect: Dictionary) -> String:
	var value: float=float(effect.get("bonus",{}).get("Value",0))
	var denominator: float=float(effect.get("ui_unit",{}).get("Denominator",0))
	if denominator>0:value/=denominator
	if str(effect.get("type",{}).get("Name",""))=="ArmorClass":value=-value
	var percent: bool=int(effect.get("type",{}).get("UnitID",0))==3 or str(effect.get("type",{}).get("Name","")).contains("Percent")
	return ("+" if value>0 else "")+(str(int(value)) if value==floorf(value) else String.num(value,2))+("%" if percent else "")

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var runtime: Object=_runtime()
	var totems: Array=[]
	for def: Dictionary in runtime.rows("Totem"):
		var id: int=int(def.ID)
		var p: Dictionary=runtime.progress(id)
		var need: int=maxi(1,int(def.get("ActivationKillCount",1)))
		var kills: int=int(p.get("kills",0))
		var on: bool=bool(p.get("active",false))
		var name: String="Lv.%d %s" % [int(p.get("level",0)),runtime.description(int(def.get("DescID",0)))]
		totems.append({"member":TOTEM,"spec":{"Panel/Nd_Totem_On":{"visible":on},"Panel/Nd_Totem_Off":{"visible":not on},
			"Nd_Totem_On/Nd_Title/Label_Name":{"role":"source_text","text":name},"Nd_Totem_Off/Nd_Title/Label_Name":{"role":"source_text","text":name},
			"Nd_ProgressBar":{"visible":not on},
			"Nd_ProgressBar/ProgressBar_Exp":{"role":"source_percent","percent":clampf(100.0*float(kills)/float(need),0.0,100.0)},
			"Nd_ProgressBar/Label_Num":{"role":"source_text","text":"%d/%d" % [mini(kills,need),need]},
			"Panel/Nd_Fx_TotemOpen":{"visible":false},
			"Panel/Btn_Totem":{"activate":Callable(self,"_totem_pressed").bind(id)}}})
	var listed: Dictionary=_fill_list(root,out,"Nd_Content/ListViewTotem",totems,NAN,true)
	if not listed.get("ok",false):return listed
	# 토템 효과: acquired options (sum per bonus type) and the applied stats.
	var acquired: Dictionary={}
	var order: Array[String]=[]
	for def: Dictionary in runtime.rows("Totem"):
		for stage: Variant in runtime.progress(int(def.ID)).get("selected",{}).values():
			for bonus_id: Variant in (stage as Dictionary).values():
				var effect: Dictionary=runtime.typed_bonus(int(bonus_id)).duplicate(true)
				var key: String=str(effect.get("type",{}).get("Name",""))
				if not acquired.has(key):
					acquired[key]=effect
					order.append(key)
				else:acquired[key].bonus.Value=int(acquired[key].bonus.Value)+int(effect.bonus.Value)
	var effects: Array=[]
	for key: String in order:
		var effect: Dictionary=acquired[key]
		effects.append(_effect_row(runtime.description(int(effect.type.get("DescID",0))),_scalar(effect),true))
	for pair: Array in [["AC","ArmorClass",-1],["MR","MagicResist",1],["대미지 리덕션","DamageReduction",1]]:
		var value: int=int(runtime.bonus(str(pair[1])))*int(pair[2])
		effects.append(_effect_row(str(pair[0]),("+" if value>0 else "")+str(value),value!=0))
	var collection: Dictionary=_fill_list(root,out,"Nd_Collection/ListView",effects)
	if not collection.get("ok",false):return collection
	var resonance: Dictionary=runtime.resonance()
	var reached: Array=[]
	for row: Variant in resonance.get("reached",[]):reached.append(int(row.get("TotalLevel",-1)))
	var rows: Array=[]
	for threshold: Dictionary in runtime.rows("TotemResonance"):
		var effect: Dictionary=runtime.typed_bonus(int(threshold.BonusID))
		var on: bool=int(threshold.TotalLevel) in reached
		var spec: Dictionary={"Panel/Nd_On":{"visible":on},"Panel/Nd_Off":{"visible":not on}}
		for state: String in ["Nd_On","Nd_Off"]:
			spec[state+"/Label_Title"]={"role":"source_text","text":"강화 %d달성" % int(threshold.TotalLevel)}
			spec[state+"/Label_Option"]={"role":"source_text","text":"%s %s" % [runtime.description(int(effect.get("type",{}).get("DescID",0))),_scalar(effect)]}
		rows.append({"member":RESONANCE,"spec":spec})
	var listed_resonance: Dictionary=_fill_list(root,out,"Nd_Resonance/ListView",rows)
	if not listed_resonance.get("ok",false):return listed_resonance
	return {"ok":true,"totems":totems.size(),"effects":effects.size(),"resonance":rows.size(),"total_level":int(resonance.get("total_level",0)),"showing_resonance":_resonance}

static func _effect_row(label: String, value: String, on: bool) -> Dictionary:
	var spec: Dictionary={"Panel/Nd_On":{"visible":on},"Panel/Nd_Off":{"visible":not on}}
	for state: String in ["Nd_On","Nd_Off"]:
		spec[state+"/Label_Dsc"]={"role":"source_text","text":label}
		spec[state+"/Label_Num01"]={"role":"source_text","text":value}
		spec[state+"/Label_Num02"]={"role":"source_text","text":""}
	return {"member":EFFECT,"spec":spec}

func _toggle() -> Dictionary:
	_resonance=not _resonance
	return _stage()

func _totem_pressed(id: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	return _route("open_totems",[false,id])

func _help() -> Dictionary:
	_message("토템: 지정 몬스터를 처치해 활성화하고, 재료로 성장시켜 옵션을 얻습니다 · 활성 토템 레벨 합계로 공명 효과가 열립니다")
	return {"ok":true}
