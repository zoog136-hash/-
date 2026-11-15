extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 무기 숙련 window: Mastery_All (frame, title, close) with
## the weapon list (Mastery_List_Weapon rows: the weapon's own original icon
## through MasteryWeaponType.AssetID, the equipped mark, Lv n/max), the
## selected weapon's info (type, Lv, progress to the next level), the option
## rows (Mastery_List_Option per owned level: Lv, the four field colours from
## the original MasteryGradeView.ColorID -> Color -> ColorTable values, option
## 1 / option 2 names and values, the four field locks, the colour matching
## bonus (Mastery_List_Bonus) and the 레벨 부족 notice), the colour odds of
## Mastery_DetailInfo (MasteryGradeView.Probability), the in-window help
## (Mastery_Help, Btn_HelpBox / Btn_Back) and the actions 옵션 획득 (acquire),
## 변경 하기 by ticket (Btn_Change01) or by currency (Btn_Change02) and
## 숙련치 획득 (purchase).
## Every quote, payment, roll and save is the existing world.weapon_mastery
## runtime (quote -> HUD confirmation -> execute, set_color_lock). A weapon
## with partially owned (legacy) levels opens the existing mastery panel,
## which keeps 부분 옵션 복구. Left empty: the roulette effects, the level
## arrows, the detail sub lists (their row members are not in the window),
## the gauge sprite (a plain Sprite, no percent in the original node) and an
## icon whose original picture is not in the image pack.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const ROOT="UI/Mastery/Mastery_All.csb"
const WEAPON_ROW="UI/Mastery/Mastery_List_Weapon.csb"
const OPTION_ROW="UI/Mastery/Mastery_List_Option.csb"
## The four colour fields of a level: option 1 name / value, option 2 name / value.
const FIELDS: Array[Array]=[["Label_Stat",1,"name"],["Label_Stat_Num",1,"value"],["Label_Symbol_Name",2,"name"],["Label_Symbol_Num",2,"value"]]
const ROULETTE: Array[String]=["Panel_Text_Stat","Panel_Text_Stat_Num","Panel_Text_Stat_Symbol","Panel_Text_Stat_Symbol_Num","Fx_Roulette_Start_01","Fx_Roulette_Start_02","Fx_Roulette_Start_03","Fx_Roulette_Start_04","Fx_Roulette__End01_Stat","Fx_Roulette__End01_Stat_Num","Fx_Roulette__End01_Symbol","Fx_Roulette__End01_Symbol_Num","Fx_Roulette__End02_Stat","Fx_Roulette__End02_Stat_Num","Fx_Roulette__End02_Symbol","Fx_Roulette__End02_Symbol_Num"]
var selected: int=0
var help: bool=false

func required_members() -> Array[String]:
	return [ROOT,WEAPON_ROW,OPTION_ROW]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("weapon_mastery") if owner!=null else null

func open(parent: Node) -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null or not runtime.enabled or not str(runtime.balance_error).is_empty() or runtime.core.levels.is_empty():return _fail("source_mastery_window_runtime_unavailable")
	help=false
	var equipped: int=_equipped(runtime)
	if runtime.core.levels.has(equipped):selected=equipped
	elif not runtime.core.levels.has(selected):selected=int(runtime.core.levels.keys()[0])
	if _partial(runtime,selected):return _native()
	return open_window(parent)

static func _partial(runtime: Object, weapon: int) -> bool:
	return not (runtime.core.partial_status(runtime.state,weapon).get("frozen",[]) as Array).is_empty()

## Original slot colour [r, g, b] of a MasteryGradeView grade
## (ColorID -> Color.ColorTableID -> ColorTable.Value); [] without one.
static func grade_color(runtime: Object, grade: int) -> Array:
	for row: Dictionary in runtime.core.tables.get("MasteryGradeView",[]):
		if int(row.GradeID)!=grade:continue
		var color: Dictionary=SOURCE.row("Color",int(row.get("ColorID",0)))
		var value: String=str(SOURCE.row("ColorTable",int(color.get("ColorTableID",0))).get("Value","")).trim_prefix("#")
		if value.length()==6 and Color.html_is_valid("#"+value):
			var parsed:=Color.html("#"+value)
			return [parsed.r8,parsed.g8,parsed.b8]
	return []

func _equipped(runtime: Object) -> int:
	var owner: Object=world()
	if owner==null or not owner.has_method("_mastery_actual_weapon_type"):return 0
	return int(runtime.core.normalize_weapon(int(owner.call("_mastery_actual_weapon_type"))))

static func _max_level(runtime: Object, weapon: int) -> int:
	var top: int=0
	for row: Dictionary in runtime.core.levels.get(weapon,[]):top=maxi(top,int(row.Level))
	return top

static func _progress(runtime: Object, weapon: int, points: String, level: int) -> float:
	var low: float=0.0
	var high: float=-1.0
	for row: Dictionary in runtime.core.levels.get(weapon,[]):
		if int(row.Level)==level:low=float(row.CumulativePoint)
		if int(row.Level)==level+1:high=float(row.CumulativePoint)
	if high<0.0:return 100.0
	return clampf(100.0*(float(points)-low)/maxf(1.0,high-low),0.0,100.0)

## The first reached level without options (옵션 획득), else 0.
static func claimable_level(runtime: Object, weapon: int) -> int:
	var entry: Dictionary=runtime.core.record(runtime.state,weapon)
	for level: int in range(1,runtime.core.achieved_level(weapon,str(entry.points))+1):
		if runtime.core.acquire_availability(runtime.state,weapon,level,{}).get("ok",false):return level
	return 0

func _spec() -> Dictionary:
	var runtime: Object=_runtime()
	var spec: Dictionary={}
	for name: String in ["Nd_Level/Btn_Left","Nd_Level/Btn_Right","Nd_Fx_Mastery_List","Nd_Option/Nd_List01","Nd_Option/Nd_List02","Nd_MatchingBonus","Nd_Weapon"]:spec[name]={"exclude":true}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	var entry: Dictionary=runtime.core.record(runtime.state,selected)
	var level: int=runtime.core.achieved_level(selected,str(entry.points))
	spec["Panel_Weapon_Info/Nd_Info/Label_Type"]={"role":"source_text","text":runtime.weapon_name(selected)}
	spec["Panel_Weapon_Info/Nd_Info/Label_Level_Num"]={"role":"source_text","text":"%d/%d" % [level,_max_level(runtime,selected)]}
	spec["Panel_Weapon_Info/Nd_Info/Label_Per"]={"role":"source_text","text":"( %s%% )" % String.num(_progress(runtime,selected,str(entry.points),level),3).pad_decimals(3)}
	# Mastery_DetailInfo: the colour odds (MasteryGradeView.Probability, 1,000,000 = 100%).
	for pair: Array in [[2,"Label_Green"],[3,"Label_Blue"],[4,"Label_Red"],[5,"Label_Purple"]]:
		var odds: float=0.0
		for row: Dictionary in runtime.core.tables.get("MasteryGradeView",[]):
			if int(row.GradeID)==int(pair[0]):odds=float(row.get("Probability",0))/10000.0
		spec["Nd_List_Color/"+str(pair[1])]={"role":"source_text","text":"%s %s%%" % [runtime.grade_name(int(pair[0])),String.num(odds,1)]}
	spec["Mastery_DetailInfo/Nd_Title/Label_Title"]={"role":"source_text","text":runtime.weapon_name(selected)}
	# The in-window help over the detail panel (Btn_HelpBox / Btn_Back).
	spec["Mastery_Help"]={"visible":help}
	for name: String in ["Mastery_DetailInfo/Img_Bg","Nd_SkillFull_Option/Img_Gra_Top","Nd_SkillFull_Option/Sp_Deco","Nd_SkillFull_Option/Label_Tip","Nd_SkillFull_Option/Nd_Option","Mastery_DetailInfo/Nd_Title"]:spec[name]={"visible":not help}
	spec["Nd_SkillFull_Option/Btn_HelpBox"]={"visible":not help,"activate":Callable(self,"_help").bind(true)}
	spec["Nd_SkillFull_Option/Btn_Back"]={"visible":help,"activate":Callable(self,"_help").bind(false)}
	# Actions: 옵션 획득 replaces the two 변경 하기 buttons while a reached level has no options.
	var claim: int=claimable_level(runtime,selected)
	_action(spec,"Btn_OptionGet",runtime.quote("acquire",selected,0,claim) if claim>0 else {},"acquire",claim,"currency",claim>0)
	_action(spec,"Btn_Change01",runtime.quote("reset",selected,0,0,"ticket"),"reset",0,"ticket",claim==0)
	_action(spec,"Btn_Change02",runtime.quote("reset",selected,0,0,"currency"),"reset",0,"currency",claim==0)
	_action(spec,"Btn_Mastery_Get",runtime.quote("purchase",selected),"purchase",0,"currency",true)
	var used: int=int(runtime.core.purchase_usage(runtime.state,runtime.purchase_period()).get("count",0))
	var limit: int=(runtime.core.tables.get("MasteryPointPayment",[]) as Array).size()
	for state: String in ["Normal","Disabled"]:spec["Btn_Mastery_Get/%s/Label" % state]={"role":"source_text","text":"숙련치 획득 (%d/%d)" % [used,limit]}
	return spec

## One action button: Normal / Disabled by the runtime quote, the quoted cost
## (the original Adena icon only for an Adena charge) and the confirmation.
func _action(spec: Dictionary, button: String, quote: Dictionary, action: String, prefix: int, payment: String, shown: bool) -> void:
	var ok: bool=bool(quote.get("ok",false))
	var charge: Dictionary=quote.get("charge",{})
	var adena: bool=int(charge.get("CurrencyID",0))==1
	spec[button]={"visible":shown,"activate":Callable(self,"_ask").bind(action,prefix,payment)}
	spec[button+"/Normal"]={"visible":ok}
	spec[button+"/Disabled"]={"visible":not ok}
	for state: String in ["Normal","Disabled","Disabled/Nd_Info"]:
		for cost_node: String in ["","Nd_Cost/"]:
			spec["%s/%s/%sLabel_Amount" % [button,state,cost_node]]={"role":"source_text","text":_number(int(charge.get("Cost",0))),"visible":not charge.is_empty()}
			spec["%s/%s/%sIcon" % [button,state,cost_node]]={"visible":adena}
			spec["%s/%s/%sBg_Amount" % [button,state,cost_node]]={"visible":not charge.is_empty()}

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var runtime: Object=_runtime()
	var equipped: int=_equipped(runtime)
	var weapons: Array=[]
	var weapon_ids: Array[int]=[]
	for key: Variant in runtime.core.levels:
		var weapon: int=int(key)
		var entry: Dictionary=runtime.core.record(runtime.state,weapon)
		var on: bool=weapon==selected
		weapons.append({"member":WEAPON_ROW,"spec":{"Panel/Btn_Normal":{"visible":not on,"activate":Callable(self,"_select").bind(weapon)},
			"Panel/Btn_Pressed":{"visible":on,"activate":Callable(self,"_select").bind(weapon)},
			"Nd_Contents/Sp_Equip":{"visible":weapon==equipped},"Nd_Contents/Sp_New":{"visible":false},
			"Nd_Contents/Icn_Type":{"role":"source_asset_slot","visible":false},"Nd_Contents/ProgressBar":{"visible":false},
			"Nd_Contents/Label_Level_Num":{"role":"source_text","text":"%d/%d" % [runtime.core.achieved_level(weapon,str(entry.points)),_max_level(runtime,weapon)]},
			"Panel/Btn_Disabled":{"exclude":true},"Panel/Fx_Start":{"exclude":true}}})
		weapon_ids.append(weapon)
	var listed: Dictionary=_fill_list(root,out,"Nd_Weapon_List/ListView_List",weapons,NAN,true)
	if not listed.get("ok",false):return listed
	var icons: int=0
	for index: int in range((listed.get("scenes",[]) as Array).size()):
		var located: Dictionary=_locate(listed.scenes[index],listed.outs[index],"Nd_Contents/Icn_Type")
		if located.get("ok",false) and _show_picture(located.player,located.offset,weapon_icon(runtime,weapon_ids[index])):icons+=1
	var rows: Array=_option_rows(runtime)
	var options: Dictionary=_fill_list(root,out,"ListView_Option",rows)
	if not options.get("ok",false):return options
	return {"ok":true,"selected":selected,"weapons":weapons.size(),"icons":icons,"option_rows":rows.size(),"help":help}

## The weapon's own original icon (MasteryWeaponType.AssetID of its base
## row); not ok (the slot stays empty) when the image pack lacks it.
static func weapon_icon(runtime: Object, weapon: int) -> Dictionary:
	for row: Dictionary in runtime.core.tables.get("MasteryWeaponType",[]):
		if int(row.BaseType)!=weapon or int(row.ActualType)!=weapon:continue
		return SourceImages.resolve_asset_value(row.get("AssetID"))
	return {"ok":false,"code":"source_mastery_weapon_type_missing"}

## The two options of a level as {Slot: {name, value}} (original Slot 1, 2).
static func level_options(runtime: Object, entry: Dictionary, weapon: int, level: int) -> Dictionary:
	var result: Dictionary={}
	var slots: Dictionary=runtime.core._owned_slots(entry,weapon,level)
	for slot: int in slots:
		var row: Dictionary=runtime.core.options[int(entry.options[int(slots[slot])].group_id)][weapon]
		var text: String=runtime.bonus_text(runtime.core.bonuses[int(row.BonusID)])
		var cut: int=text.rfind(" +")
		result[slot]={"name":text.left(cut) if cut>0 else text,"value":text.substr(cut+1) if cut>0 else ""}
	return result

func _option_rows(runtime: Object) -> Array:
	var entry: Dictionary=runtime.core.record(runtime.state,selected)
	var reached: int=runtime.core.achieved_level(selected,str(entry.points))
	var owned: Array=[]
	for key: Variant in entry.colors:owned.append(int(key))
	owned.sort()
	var rows: Array=[]
	for level: int in owned:
		var colors: Array=entry.colors[str(level)]
		var locks: Array=entry.locks.get(str(level),[false,false,false,false])
		var texts: Dictionary=level_options(runtime,entry,selected,level)
		var spec: Dictionary={"Nd_Level/Label_Level":{"role":"source_text","text":str(level)},"Nd_Level/Sp_New":{"visible":false},
			"Panel_1/Btn_Pressed":{"visible":false},"Panel_1/Btn_Lock":{"visible":false},"Panel_1/Nd_NotApply":{"visible":level>reached},
			"Panel_1/Fx_Line":{"exclude":true},"Panel_1/Fx_Mastery_List":{"exclude":true},"Panel_1/Fx_Panel":{"exclude":true}}
		for name: String in ROULETTE:spec["Nd_Contents/"+name]={"exclude":true}
		for field: int in range(4):
			var rgb: Array=grade_color(runtime,int(colors[field])) if field<colors.size() else []
			if not rgb.is_empty():spec["Nd_Bg/Img_Bg0%d" % (field+1)]={"color":rgb}
			var locked: bool=field<locks.size() and bool(locks[field])
			spec["Nd_Lock_Btn0%d/Btn_Lock" % (field+1)]={"visible":locked,"activate":Callable(self,"_lock").bind(level,field,false)}
			spec["Nd_Lock_Btn0%d/Btn_UnLock" % (field+1)]={"visible":not locked,"activate":Callable(self,"_lock").bind(level,field,true)}
			var text: Dictionary=texts.get(int(FIELDS[field][1]),{})
			spec["Nd_Contents/"+str(FIELDS[field][0])]={"role":"source_text","text":str(text.get(str(FIELDS[field][2]),"")),"visible":not text.is_empty()}
		# The colour matching bonus of four equal colours on a complete level.
		var same: bool=colors.size()==4 and texts.size()==2 and colors.all(func(c: Variant) -> bool: return int(c)==int(colors[0]))
		var matching: Dictionary=runtime.core.matching_bonus(selected,int(colors[0])) if same else {}
		spec["Panel_1/Mastery_List_Bonus"]={"visible":not matching.is_empty()}
		spec["Mastery_List_Bonus/Panel_1/Btn_Pressed"]={"visible":false}
		spec["Mastery_List_Bonus/Panel_1/Label_Matching_Bonus"]={"role":"source_text","text":runtime.bonus_text(matching) if not matching.is_empty() else ""}
		spec["Mastery_List_Bonus/Panel_1/Nd_NotApply"]={"visible":not matching.is_empty() and level>reached}
		rows.append({"member":OPTION_ROW,"spec":spec})
	return rows

## --- Actions ------------------------------------------------------------------

func _select(weapon: int) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if weapon==selected:return {"ok":true,"same":true}
	selected=weapon
	if _partial(_runtime(),weapon):return _native()
	return _stage()

func _help(shown: bool) -> Dictionary:
	help=shown
	return _stage()

func _lock(level: int, field: int, locked: bool) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var result: Dictionary=_runtime().set_color_lock(selected,level,field,locked)
	_stage()
	return result

## The existing quote -> HUD confirmation -> execute of world.weapon_mastery.
func _ask(action: String, prefix: int, payment: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var runtime: Object=_runtime()
	var weapon: int=selected
	var quote: Dictionary=runtime.quote(action,weapon,0,prefix,payment)
	if not quote.get("ok",false):
		_message(runtime.reason_text(str(quote.get("reason","실패"))))
		return {"ok":false,"quoted":action,"reason":str(quote.get("reason",""))}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_mastery_window_confirmation_unavailable")
	var charge: Dictionary=quote.charge
	var title: String={"reset":"숙련 옵션 변경","acquire":"Lv.%d 숙련 옵션 획득" % prefix,"purchase":"숙련치 획득"}.get(action,action)
	var price: String="%s %s" % [runtime.currency_name(int(charge.CurrencyID)),_number(int(charge.Cost))]
	if action=="reset" and not (quote.get("frozen_levels",[]) as Array).is_empty():price+="\n일부만 보유한 레벨은 보존합니다"
	owner.call("confirm_action",title,price,"실행",func(_count: int) -> void:
		var result: Dictionary=runtime.execute(action,weapon,0,prefix,quote.before,payment)
		_message(title+" 완료" if result.get("ok",false) else runtime.reason_text(str(result.get("reason","실패"))))
		if is_open():_stage())
	return {"ok":true,"quoted":action,"payment":payment}

## Legacy partial levels: the existing mastery panel keeps 부분 옵션 복구.
func _native() -> Dictionary:
	var result: Dictionary=_route("open_mastery_native")
	result["handled"]=true
	result["native_panel"]=true
	return result
