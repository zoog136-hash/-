extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 버프 정보 window: Inventory_Buff_Info_All (frame, the
## 버프 / 디버프 / 발동 마법 tabs, close) over the existing active effects
## (world._combined_active_buffs: skill buffs, timed item buffs, the dragon
## orb). Each effect is one Inventory_Buff_List_Item row: its original
## BuffClass ON icon in the Common_Slot picture (the HUD buff row's own
## Source523SkillImages.describe_buff), the effect name, the item / skill
## description and the remaining time, updated every second while open.
## Left empty (no TWILIGHT data): the 디버프 and 발동 마법 lists (TWILIGHT keeps
## no named player debuffs or invoke list; their own 없습니다 notices show),
## 상세보기 (ToolTip_HudType_Buff), a buff whose original icon is not known.
const SkillImages=preload("res://scripts/ui/source523_skill_buff_images.gd")
const ROOT="UI/FloatingUi/Inventory_Buff_Info_All.csb"
const ROW="UI/FloatingUi/Inventory_Buff_List_Item.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
## tab -> [pressed button, released button, list node]
const TABS={"buff":["Btn_BuffInfo_On","Btn_BuffInfo_Off","Nd_Tab_Buff"],"debuff":["Btn_DebuffInfo_On","Btn_DebuffInfo_Off","Nd_Tab_Debuff"],"spell":["Btn_SpellInfo_On","Btn_SpellInfo_Off","Nd_Tab_Spell"]}
## Common_Slot keeps its button, frame and picture.
const SLOT_EXCLUDED: Array[String]=["Nd_Grace","Nd_Properties","Nd_Properties_Smelt","Nd_Lock","Nd_Wrong","Sp_Select","Sp_Center","Sp_Left_Top","Sp_Left_Middle","Sp_Right_Top","Sp_Left_Bottom","Text_Amount","Label_Center","Sp_Random","Sp_Choice","Sp_Infinity","Sp_Check","Img_Enchant","Sp_Pause","Btn_Probability","Btn_Detail","Nd_Collected"]
var tab: String="buff"
var _times: Array=[]
var _shown_keys: Array=[]
var _timer: Timer

func required_members() -> Array[String]:
	return [ROOT,ROW,SLOT]

func _root_member() -> String:
	return ROOT

## Inventory_Buff_Info_All_Layout sits at (191.3, 345) in FloatingUiScene.
func _root_position() -> Vector2:
	return Vector2(191.3,-345.0)

func open(parent: Node) -> Dictionary:
	if not world() is Object or not world().has_method("_combined_active_buffs"):return _fail("source_buff_window_runtime_unavailable")
	tab="buff"
	return open_window(parent)

func _buffs() -> Dictionary:
	var owner: Object=world()
	var buffs: Variant=owner.call("_combined_active_buffs") if owner!=null and owner.has_method("_combined_active_buffs") else {}
	return buffs if buffs is Dictionary else {}

static func remaining_text(seconds: float) -> String:
	var total: int=maxi(0,int(ceil(seconds)))
	if total>=3600:return "%d:%02d:%02d" % [total/3600,(total/60)%60,total%60]
	return "%02d:%02d" % [total/60,total%60]

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["Btn_ToolTip"]={"exclude":true}
	spec["Tab/Sprite_New"]={"visible":false}
	for name: String in TABS:
		var on: bool=name==tab
		spec["Tab/"+str(TABS[name][0])]={"visible":on,"activate":Callable(self,"_tab").bind(name)}
		spec["Tab/"+str(TABS[name][1])]={"visible":not on,"activate":Callable(self,"_tab").bind(name)}
		spec[str(TABS[name][2])]={"visible":true} if on else {"exclude":true}
		spec[str(TABS[name][2])+"/ToolTip_HudType_Buff"]={"exclude":true}
	spec["Nd_Tab_Buff/Text_Notice"]={"visible":_buffs().is_empty()}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	_times.clear()
	_shown_keys.clear()
	if tab!="buff":return {"ok":true,"tab":tab,"rows":0}
	var buffs: Dictionary=_buffs()
	var rows: Array=[]
	for key: Variant in buffs:
		var effect: Dictionary=buffs[key] if buffs[key] is Dictionary else {}
		var spec: Dictionary={"Panel/Btn_Normal":{"activate":Callable(self,"_ignore")},"Panel/Btn_Pressed":{"exclude":true},"Panel/Btn_Disabled":{"exclude":true},
			"Btn_Normal/Label_Exp":{"role":"source_text","text":str(key)},
			"Btn_Normal/Label_Content":{"role":"source_text","text":str(effect.get("desc","")).split("\n")[0]},
			"Btn_Normal/Lable_Info":{"role":"source_text","text":remaining_text(float(effect.get("remaining",0.0)))},
			"Btn_Normal/Lable_Id":{"visible":false},
			"Slot/Btn":{"activate":Callable(self,"_ignore")},
			"Slot/Sp_IconSample":{"role":"source_asset_slot","visible":false}}
		for name: String in SLOT_EXCLUDED:spec["Slot/"+name]={"exclude":true}
		rows.append({"member":ROW,"spec":spec,"key":str(key),"effect":effect})
		_shown_keys.append(str(key))
	var placed: Dictionary=_fill_list(root,out,"Nd_Tab_Buff/ListView_Buff",rows)
	if not placed.get("ok",false):return placed
	var icons: int=0
	for index: int in range(rows.size()):
		var scene: Node2D=placed.scenes[index]
		var row_out: Dictionary=placed.outs[index]
		if _icon(scene,row_out,rows[index].effect):icons+=1
		var time: Dictionary=_locate(scene,row_out,"Btn_Normal/Lable_Info")
		if time.get("ok",false):_times.append({"key":rows[index].key,"player":time.player,"offset":time.offset})
	_watch(root)
	return {"ok":true,"tab":tab,"rows":rows.size(),"icons":icons}

## The effect's original BuffClass ON icon, as the HUD buff row resolves it.
func _icon(scene: Node2D, out: Dictionary, effect: Dictionary) -> bool:
	var owner: Object=world()
	var service: Variant=owner.get("original_skills") if owner!=null else null
	var source: RefCounted=null
	var record: Dictionary={}
	if service is Object and (service as Object).get("catalog")!=null:
		source=(service as Object).get("catalog").get("source523")
		if owner.has_method("_skill_record"):record=owner.call("_skill_record",str(effect.get("skill_id","")))
	var info: Dictionary=SkillImages.describe_buff(effect,"OnIconID",source,record)
	if not info.get("texture") is Texture2D:return false
	var located: Dictionary=_locate(scene,out,"Slot/Sp_IconSample")
	if not located.get("ok",false):return false
	return _show_picture(located.player,located.offset,{"ok":true,"texture":info.texture,"status":str(info.get("status","")),"provenance":info.get("provenance",{})})

## A one-second timer under the mounted tree: remaining times follow the
## live effects; a changed effect set rebuilds the list.
func _watch(root: Node2D) -> void:
	_timer=Timer.new()
	_timer.wait_time=1.0
	_timer.autostart=true
	_timer.timeout.connect(_tick)
	root.add_child(_timer)

func _tick() -> void:
	if not is_open() or tab!="buff":return
	var buffs: Dictionary=_buffs()
	var keys: Array=[]
	for key: Variant in buffs:keys.append(str(key))
	if keys!=_shown_keys:
		_stage()
		return
	for row: Dictionary in _times:
		var effect: Variant=buffs.get(row.key)
		if effect is Dictionary and is_instance_valid(row.player):row.player.set_bound_text(int(row.offset),remaining_text(float(effect.get("remaining",0.0))))

func _tab(name: String) -> Dictionary:
	if name==tab:return {"ok":true,"same":true}
	tab=name
	return _stage()
