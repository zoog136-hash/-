extends RefCounted
## The original 523 오림의 흔적 level-up skill choice: Hud_TracesOrim_Skill
## ("새로운 스킬을 선택해주세요.", three Panel_Orim cards in its ListView,
## 새로고침 with its price). Each offered card (world.dungeon_play.orim_status)
## shows its OrimsTrailSpellClass name, the group's description text, the
## level it reaches and its OrimsTrailSpellType node (공격 / 유틸리티 / 보상 /
## 시너지); 결 정 runs dungeon_play.choose_skill and 새로고침 dungeon_play.reroll
## (cost from OrimsTrailRerollCurrencyCost). Every rule and save stays in
## scripts/dungeons/dungeon_play_service.gd and scripts/orim523.
## Left empty (no binding data): the card's skill picture (no icon column in
## the Orim spell tables), the owned-skill slot group (Hud_Orim_SkillSlotGroup)
## and the probability button.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const ROOT="UI/Main/Hud_TracesOrim_Skill.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const MEMBER_SCOPES={SLOT:[15728,15316]}
const CARDS: Array[String]=["Panel_Orim_01","Panel_Orim_02","Panel_Orim_03"]
## OrimsTrailSpellType.Name -> the card's Nd_Type node and slot frame.
## (523 OrimsTrailSpellType names Attack / Utility / Reward / Synergy; the
## Korean names are accepted as well.)
const TYPES={"Attack":["Nd_Attack","Skill_Attack","Label_Level_Attack"],"Utility":["Nd_Utility","Skill_Utility","Label_Level_Utility"],"Reward":["Nd_Reward","",""],"Synergy":["Nd_Synergy","Skill_Synergy","Label_Level_Synergy"],
	"공격":["Nd_Attack","Skill_Attack","Label_Level_Attack"],"유틸리티":["Nd_Utility","Skill_Utility","Label_Level_Utility"],"보상":["Nd_Reward","",""],"시너지":["Nd_Synergy","Skill_Synergy","Label_Level_Synergy"]}
## The reroll currency the authored 새로고침 price sprite belongs to (다이아).
const PRICE_CURRENCY: int=4
var _pack: RefCounted
var _tree: RefCounted
var _world: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _signature: String=""
var last_result: Dictionary={}

func configure(pack: RefCounted) -> Dictionary:
	if not pack.manifest.get("scenes",{}).has(ROOT):return {"ok":false,"handled":false,"code":"source_orim_skill_window_member_missing","member":ROOT}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

## Shows (or refreshes) the choice for the current offer; closes it when the
## run offers no card.
func show(parent: Node, world: Node) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world) or world.get("dungeon_play")==null:return _fail("source_orim_skill_window_host_unavailable")
	_parent=weakref(parent)
	_world=weakref(world)
	var info: Dictionary=world.dungeon_play.orim_status()
	var active: bool=not info.is_empty() and str(world.dungeon_play.state.active.get("status",""))=="active"
	if not active or (info.get("cards",[]) as Array).is_empty():
		close()
		return {"ok":true,"handled":false,"closed":true}
	var signature: String=JSON.stringify([info.cards,info.rerolls,info.reroll_cost])
	if is_open() and signature==_signature:return last_result
	var cards: Array=info.cards
	var spec: Dictionary={
		"Nd_SlotGroup":{"exclude":true},"Nd_Probability":{"exclude":true},
		"Fx_RefreshCircle":{"exclude":true},"Nd_Flash":{"exclude":true},"Nd_Flash01":{"exclude":true},
		"lens_Flare_05_2_0_0":{"exclude":true},"lens_Flare_05_2_0":{"exclude":true},
		"WinBg/Particle":{"exclude":true},
		# Fx_Reward_Top carries frame events with no value (no rule): not mounted.
		"Fx_Reward_Top":{"exclude":true},
		"ListView":{"role":"source_list","input":Callable(_tree,"_ignore_input")},
	}
	var model: Dictionary=world.dungeon_play.orim_model()
	for index: int in range(CARDS.size()):
		var key: String=CARDS[index]+"/"
		var card: Dictionary=cards[index] if index<cards.size() else {}
		spec[key+"Panel_Fx"]={"exclude":true}
		spec[key+"Fx_Frame_Glow"]={"exclude":true}
		spec[key+"Nd_Skill_Info/Panel_Fx"]={"exclude":true}
		if card.is_empty():
			spec[CARDS[index]]={"visible":false}
			continue
		var owned: int=_owned_level(info,int(card.group))
		var next_level: int=owned+1 if owned>=0 else 0
		var maximum: int=int(model.get("groups",{}).get(int(card.group),{}).get("max_level",-1))
		# How a SpellLevel (0 = first learn) is captioned is not in the tables:
		# only the authored "Lv.Max" caption is shown, on the card that maxes it.
		var at_max: bool=maximum>=0 and next_level>=maximum
		var type: Array=TYPES.get(str(card.type),[])
		var synergy: bool=str(card.type) in ["Synergy","시너지"]
		spec[key+"Nd_Skill_Info/Label_SkillName"]={"role":"source_text","text":str(card.name)}
		spec[key+"Nd_Skill_Info/Nd_SkillInfo/Label_SkilInfo_Basic"]={"role":"source_text","text":str(card.desc),"cocos_wrap":true}
		spec[key+"Nd_Skill_Info/Nd_SkillInfo/Label_SkilInfo_Full"]={"visible":false}
		spec[key+"Nd_Skill_Info/Label_Level"]={"visible":at_max and not synergy}
		spec[key+"Nd_Skill_Info/Label_Level_Synergy"]={"visible":at_max and synergy}
		for node_name: String in ["Nd_Attack","Nd_Utility","Nd_Reward","Nd_Synergy"]:
			spec[key+"Nd_Type/"+node_name]={"visible":not type.is_empty() and str(type[0])==node_name}
		# The card's Hud_Orim_SkillSlot: its type frame; no picture or level overlay.
		var slot: String=key+"Nd_Skill_Info/Panel_Slot/Common_Slot/"
		spec[slot+"Panel_Lv"]={"visible":false}
		for frame: String in ["Skill_Attack","Skill_Utility","Skill_Synergy","Skill_Max","Skill_Max_Synergy","Skill_Disabled"]:
			spec[slot+"Nd_Type/"+frame]={"visible":type.size()>1 and str(type[1])==frame}
		spec[key+"Sp_New"]={"visible":owned<0}
		spec[key+"Sp_Hidden"]={"visible":false}
		spec[key+"Btn_Choice"]={"activate":Callable(self,"_choose").bind(int(card.group))}
	var cost: int=int(info.get("reroll_cost",-1))
	var can_reroll: bool=cost>0
	spec["Nd_Refresh/Btn_Refresh"]={"activate":Callable(self,"_reroll"),"displaystate":can_reroll}
	spec["Nd_Refresh/Btn_Refresh/Normal"]={"visible":can_reroll}
	spec["Nd_Refresh/Btn_Refresh/Disabled"]={"visible":not can_reroll}
	spec["Nd_Refresh/Btn_Refresh/Normal/Label"]={"role":"source_text","text":"새로고침"}
	spec["Nd_Refresh/Btn_Refresh/Disabled/Label"]={"role":"source_text","text":"새로고침"}
	var currency: int=int(world.dungeon_play.state.get("settings",{}).get("reroll_currency",0))
	spec["Nd_Refresh/Nd_Pay"]={"visible":can_reroll and currency==PRICE_CURRENCY}
	spec["Nd_Refresh/Nd_Pay/Text_Price"]={"role":"source_text","text":str(cost)}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	# The end state of the authored opening clip (Fx_On 5-90).
	next.seek_frame(90.0)
	var previous: Node2D=_scene
	next.position=Vector2(600.0,-337.5)
	parent.add_child(next)
	next.z_index=140
	_scene=next
	_signature=signature
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"cards":cards.size(),"reroll_cost":cost,"reroll_price_shown":can_reroll and currency==PRICE_CURRENCY}
	return last_result

static func _owned_level(info: Dictionary, group: int) -> int:
	for skill: Dictionary in info.get("skills",[]):
		if int(skill.group)==group:return int(skill.level)
	return -1

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_signature=""
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func _choose(group: int) -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_orim_skill_window_host_unavailable")
	var result: Dictionary=world.dungeon_play.choose_skill(group)
	if world.get("hud")!=null:world.hud.show_message(("스킬 습득: "+str(result.get("name",""))) if result.get("ok",false) else str(result.get("reason","")))
	_refresh_after()
	return result

func _reroll() -> Dictionary:
	var world: Node=_world.get_ref() if _world!=null else null
	if world==null:return _fail("source_orim_skill_window_host_unavailable")
	var result: Dictionary=world.dungeon_play.reroll()
	if not result.get("ok",false) and world.get("hud")!=null:world.hud.show_message(str(result.get("reason","다시 고르기 실패")))
	_refresh_after()
	return result

func _refresh_after() -> void:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var world: Node=_world.get_ref() if _world!=null else null
	_signature=""
	if parent!=null and world!=null:show.call_deferred(parent,world)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
