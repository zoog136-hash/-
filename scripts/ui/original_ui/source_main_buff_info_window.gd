extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 버프 정보 window: Inventory_Buff_Info_All (frame, the
## 버프 / 디버프 / 발동 마법 tabs, close) over the existing active effects
## (world._combined_active_buffs: skill buffs, timed item buffs, the dragon
## orb). Each effect is one Inventory_Buff_List_Item row: its original
## BuffClass ON icon in the Common_Slot picture (the HUD buff row's own
## Source523SkillImages.describe_buff), the effect name, the item / skill
## description and the remaining time, updated every second while open.
## 디버프 lists the effects on the player now: the player's own status timers
## (스턴 / 사일런스 / 홀드 / 공포 / 중독 / 출혈, player.gd) and the original
## BuffClass effects monsters put on the player (patch523_npc_spells
## .player_buffs, IsGood false: BuffClass DescID name, EffectDescID text, ON
## icon); a good BuffClass effect from there joins the 버프 list. 발동 마법
## lists the worn equipment's invokes the combat runtime rolls
## (patch523_equipment_combat.active, every kind it handles): the invoked
## SpellClass name and icon for a spell invoke, the item name otherwise, the
## original chance. Times follow the runtime every second.
## Left empty: 상세보기 (ToolTip_HudType_Buff), a row whose original icon is
## not known (the player status timers have no BuffClass).
const SkillImages=preload("res://scripts/ui/source523_skill_buff_images.gd")
const ROOT="UI/FloatingUi/Inventory_Buff_Info_All.csb"
const ROW="UI/FloatingUi/Inventory_Buff_List_Item.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const EquipmentCombat=preload("res://scripts/crafting/patch523_equipment_combat.gd")
const Rows=preload("res://scripts/resources/current523_definition_rows.gd")
## player.gd status timers -> the name the debuff list shows.
const PLAYER_STATUS: Array=[["stun_remaining","스턴"],["silence_remaining","사일런스"],["hold_remaining","홀드"],["fear_remaining","공포"],["poison_remaining","중독"],["bleed_remaining","출혈"]]
## patch523_equipment_combat kinds, in list order -> the content text.
const INVOKE_KINDS: Array=["attack_source_spell","attack_fixed_damage","attack_weapon_scale","defence_flat_reduction","defence_fixed_counter"]
## The empty notices (the authored text is the 버프 one for all three tabs).
const NOTICES={"buff":"","debuff":"적용 중인 디버프가 없습니다.","spell":"발동하는 마법이 없습니다."}
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
	var result: Dictionary=(buffs as Dictionary).duplicate() if buffs is Dictionary else {}
	for row: Dictionary in _source_effects(true):result[row.key]=row.effect
	return result

## The rows of `kind` (buff / debuff / spell): key -> effect dictionary with
## remaining (seconds, -1 none), desc, and source_buff_class / source_spell_class
## when the original row is known.
func rows_of(kind: String) -> Dictionary:
	if kind=="buff":return _buffs()
	var result: Dictionary={}
	if kind=="debuff":
		var player: Object=world().get("player") if world()!=null else null
		if is_instance_valid(player):
			for status: Array in PLAYER_STATUS:
				var left: float=float(player.get(str(status[0])) if player.get(str(status[0]))!=null else 0.0)
				if left>0.0:result[str(status[1])]={"remaining":left,"desc":"","player_status":str(status[0])}
		for row: Dictionary in _source_effects(false):result[row.key]=row.effect
	elif kind=="spell":
		for row: Dictionary in _invokes():result[row.key]=row.effect
	return result

## Original BuffClass effects monsters put on the player (good or not).
func _source_effects(good: bool) -> Array:
	var owner: Object=world()
	var service: Variant=owner.get("patch523_npc_spells") if owner!=null else null
	if not service is Object or not (service as Object).get("player_buffs") is Dictionary:return []
	var found: Array=[]
	var buffs: Dictionary=(service as Object).get("player_buffs")
	for id: Variant in buffs:
		var buff: Variant=buffs[id]
		if not buff is Dictionary:continue
		var source: Dictionary=(service as Object).catalog.row("BuffClass",int(id))
		if source.is_empty() or bool(source.get("IsGood",false))!=good or source.get("IsShownBuffIcon",true)==false or source.get("IsHide",false)==true:continue
		var title: String=desc(int(source.get("DescID",0)))
		if title.is_empty():title=str(source.get("Name",id))
		var key: String=title
		if found.any(func(r: Dictionary) -> bool: return r.key==key):key="%s #%d" % [title,int(id)]
		found.append({"key":key,"effect":{"remaining":float((buff as Dictionary).get("remaining",0.0)),"desc":desc(int(source.get("EffectDescID",0))),"source_buff_class":source,"source_snapshot":"patch523","buff_id":int(id)}})
	return found

## The worn equipment's invokes the combat runtime rolls.
func _invokes() -> Array:
	var owner: Object=world()
	if owner==null or not owner.get("equipped_items") is Dictionary or owner.get("patch523_equipment")==null or not owner.has_method("_physical_enhancement_record"):return []
	var found: Array=[]
	for kind: String in INVOKE_KINDS:
		for effect: Dictionary in EquipmentCombat.active(owner,kind):
			var option: Dictionary=effect.get("option",{})
			var chance: String="%s%%" % String.num(float(effect.get("probability",0))/10000.0,2).trim_suffix(".00")
			var title: String=str(effect.get("item_name",""))
			var text: String=""
			var spell: Dictionary={}
			match kind:
				"attack_source_spell":
					spell=Rows.row("SpellClass",int(option.get("Param1",0)))
					var spell_name: String=desc(int(spell.get("DescID",0)))
					if not spell_name.is_empty():title=spell_name
					text="%s · 공격 시 %s" % [str(effect.get("item_name","")),chance]
				"attack_fixed_damage":text="공격 시 %s · 추가 대미지 %d" % [chance,int(option.get("Param1",0))]
				"attack_weapon_scale":text="공격 시 %s · 무기 대미지 %s%%" % [chance,String.num(float(option.get("Param1",0))/10000.0,1).trim_suffix(".0")]
				"defence_flat_reduction":text="피격 시 %s · 대미지 감소 %d" % [chance,int(option.get("Param1",0))]
				"defence_fixed_counter":text="피격 시 %s · 반격" % chance
			var key: String=title
			var n: int=2
			while found.any(func(r: Dictionary) -> bool: return r.key==key):
				key="%s (%d)" % [title,n]
				n+=1
			var row: Dictionary={"remaining":-1.0,"desc":text,"invoke_kind":kind,"option_id":int(option.get("ID",0)),"instance_id":str(effect.get("instance_id",""))}
			if not spell.is_empty():row["source_spell_class"]=spell
			found.append({"key":key,"effect":row})
	return found

static func desc(id: int) -> String:
	if id<=0:return ""
	var rows: Array[Dictionary]=Rows.related("DescData_Korean","ID",id)
	return str(rows[-1].get("Description","")).replace("\r\n","\n") if not rows.is_empty() else ""

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
	var empty: bool=rows_of(tab).is_empty()
	var notice: Dictionary={"visible":empty}
	if empty and not str(NOTICES[tab]).is_empty():notice.merge({"role":"source_text","text":str(NOTICES[tab])})
	spec[str(TABS[tab][2])+"/Text_Notice"]=notice
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	_times.clear()
	_shown_keys.clear()
	var buffs: Dictionary=rows_of(tab)
	var rows: Array=[]
	for key: Variant in buffs:
		var effect: Dictionary=buffs[key] if buffs[key] is Dictionary else {}
		var spec: Dictionary={"Panel/Btn_Normal":{"activate":Callable(self,"_ignore")},"Panel/Btn_Pressed":{"exclude":true},"Panel/Btn_Disabled":{"exclude":true},
			"Btn_Normal/Label_Exp":{"role":"source_text","text":str(key)},
			"Btn_Normal/Label_Content":{"role":"source_text","text":str(effect.get("desc","")).split("\n")[0]},
			"Btn_Normal/Lable_Info":{"role":"source_text","text":remaining_text(float(effect.get("remaining",0.0)))} if float(effect.get("remaining",0.0))>=0.0 else {"visible":false},
			"Btn_Normal/Lable_Id":{"visible":false},
			"Slot/Btn":{"activate":Callable(self,"_ignore")},
			"Slot/Sp_IconSample":{"role":"source_asset_slot","visible":false}}
		for name: String in SLOT_EXCLUDED:spec["Slot/"+name]={"exclude":true}
		rows.append({"member":ROW,"spec":spec,"key":str(key),"effect":effect})
		_shown_keys.append(str(key))
	var list_names: Dictionary={"buff":"Nd_Tab_Buff/ListView_Buff","debuff":"Nd_Tab_Debuff/ListView_Debuff","spell":"Nd_Tab_Spell/ListView_Spell"}
	var placed: Dictionary=_fill_list(root,out,str(list_names[tab]),rows)
	if not placed.get("ok",false):return placed
	var icons: int=0
	for index: int in range(rows.size()):
		var scene: Node2D=placed.scenes[index]
		var row_out: Dictionary=placed.outs[index]
		if _icon(scene,row_out,rows[index].effect):icons+=1
		var time: Dictionary=_locate(scene,row_out,"Btn_Normal/Lable_Info")
		if time.get("ok",false) and float(rows[index].effect.get("remaining",0.0))>=0.0:_times.append({"key":rows[index].key,"player":time.player,"offset":time.offset})
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
	var info: Dictionary=SkillImages.describe_spell_class_row(effect.source_spell_class) if effect.get("source_spell_class") is Dictionary else SkillImages.describe_buff(effect,"OnIconID",source,record)
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
	if not is_open():return
	var buffs: Dictionary=rows_of(tab)
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
