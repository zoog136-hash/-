extends RefCounted
## The original 523 domination stone window: DominationStoneScene with
## DominationStone_All (frame, 지배석/합성/분해/퀘스트 tabs, title, close, help),
## its Tab_Power (three List_Stone slots, Power_Effect lists), Tab_Fusion
## (FusionBox slots, grade checks, 일괄 등록/초기화/합성 시작) and Tab_Quest
## (tower, floor and quest ListViews with the original row scenes, refresh and
## accept buttons). HelpBox_DominationStone is the help overlay and
## MainMenu_DominationStone the menu tile. Every rule, roll, cost and save
## stays in world.domination_stones (scripts/domination); this file only
## mounts original nodes and routes their buttons.
## Not connected (reported): the stone inventory panel (its CSB names
## QuickSlotEdit_SlotSet, absent from the 523 client), the dismantle tab
## (shard amounts are not in the tables) and the probability popup.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const InventoryImages=preload("res://scripts/ui/original_ui/source_main_inventory_images.gd")
const SRC=preload("res://scripts/domination/domination_stone_source.gd")
const ROOT="UI/DominationStoneScene.csb"
const ALL="UI/DominationStone/DominationStone_All.csb"
const TAB_POWER="UI/DominationStone/DominationStone_Tab_Power.csb"
const TAB_FUSION="UI/DominationStone/DominationStone_Tab_Fusion.csb"
const TAB_QUEST="UI/DominationStone/DominationStone_Tab_Quest.csb"
const POWER_EFFECT="UI/DominationStone/DominationStone_Power_Effect.csb"
const ROW_BASIC="UI/DominationStone/DominationStone_List_BasicEffect_Text.csb"
const ROW_OPTION="UI/DominationStone/DominationStone_List_OptionEffect_Text.csb"
const ROW_TOWER="UI/DominationStone/DominationStone_Quest_List_Tower.csb"
const ROW_FLOOR="UI/DominationStone/DominationStone_Quest_List_Floor.csb"
const ROW_QUEST="UI/DominationStone/DominationStone_Quest_List_Quest.csb"
const MENU_TILE="UI/CsbFile/MainMenu/MainMenu_DominationStone.csb"
const HELP="UI/CsbFile/Help/HelpBox_DominationStone.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
const SLOT_BUTTON=15728
const SLOT_BACKGROUND=15316
const SLOT_ICON=15012
## Common_Slot keeps its button, frame and item picture only.
const MEMBER_SCOPES={SLOT:[SLOT_BUTTON,SLOT_BACKGROUND,SLOT_ICON]}
const REQUIRED: Array[String]=[ROOT,ROW_BASIC,ROW_OPTION,ROW_TOWER,ROW_FLOOR,ROW_QUEST]
const HELP_PAGES: int=6
## Key prefixes of the mounted original tree (names of the original nodes).
const P_ALL="DominationStone_All_Layout/"
const P_POWER="DominationStone_All_Layout/DominationStone_Tab_Power/"
const P_FUSION="DominationStone_All_Layout/DominationStone_Tab_Fusion/Nd_Fusion/"
const P_QUEST="DominationStone_All_Layout/DominationStone_Tab_Quest/Nd_Quest/"
const FUSION_SLOT="DominationStone_FusionBox/Nd_Fusion/Nd_Fusion_Slot/DominationStone_Fusion_Slot_0%d"
## Fusion grade checks (labels 희귀 / 영웅 / 전설) by original node name.
const GRADE_CHECKS={"Nd_CheckBox_Unique":3,"Nd_CheckBox_Legend":4,"Nd_CheckBox_Epic":5}
signal closed
var _pack: RefCounted
var _hud: WeakRef
var _world: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _help: Node2D
var _help_page: int=0
var _tab: String="power"
var _fusion: Array[String]=[]
var _grades: Dictionary={3:true,4:false,5:false}
var _result: Dictionary={}
var _tower: int=-1
var _floor: int=-1
var _quest_slot: int=1
var last_result: Dictionary={}
## Original buttons shown in their disabled state this stage (suffix -> true).
var _disabled: Dictionary={}
## Node keys of the mounted window (for tests and image updates).
var _last_out: Dictionary={}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_domination_window_member_missing","member":member}
	_pack=pack
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node, world: Node) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(world) or world.get("domination_stones")==null:return _fail("source_domination_window_host_unavailable")
	_parent=weakref(parent)
	_world=weakref(world)
	_fusion.clear()
	_result={}
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	_close_help()
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func _runtime() -> Object:
	var world: Object=_world.get_ref() if _world!=null else null
	return world.get("domination_stones") if world!=null else null

## --- Generic original-tree binding --------------------------------------

## {scope, bindings} for `member` mounted under `key`: every node keeps its
## original record; spec entries (by original node-name path suffix) supply
## the live roles and visibility. `out` maps each key to {chain, offset}.
func _bind(member: String, key: String, chain: Array, spec: Dictionary, out: Dictionary) -> Dictionary:
	var tree: Dictionary=_pack.scene(member).get("nodeTree",{})
	var scope: Array[int]=[]
	var bindings: Dictionary={}
	var external: Array=_pack.manifest.get("externally_bound_texture_nodes",{}).get(member,[])
	var roots: Array=[]
	if MEMBER_SCOPES.has(member):
		for offset: int in MEMBER_SCOPES[member]:roots.append(Scene._node_at_offset(tree,offset))
	else:roots=tree.get("children",[])
	for node: Dictionary in roots:_walk(node,key,chain,spec,scope,bindings,external,out)
	return {"scope":scope,"bindings":bindings}

func _walk(node: Dictionary, parent_key: String, chain: Array, spec: Dictionary, scope: Array[int], bindings: Dictionary, external: Array, out: Dictionary) -> void:
	if node.is_empty():return
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var offset: int=int(node.get("_offset",-1))
	var key: String=parent_key+"/"+str(widget.get("name",""))
	var kind: String=str(node.get("classname",""))
	# An excluded node (and its subtree) is left out of the node scope.
	for pattern: String in spec:
		if key.ends_with("/"+pattern) and bool(spec[pattern].get("exclude",false)):return
	scope.append(offset)
	var binding: Dictionary={}
	match kind:
		"ProjectNode":
			var member: String=str(options.get("fileName",""))
			if not member.begins_with("UI/"):member="UI/"+member
			var next_chain: Array=chain.duplicate()
			next_chain.append(offset)
			var child: Dictionary=_bind(member,key,next_chain,spec,out)
			binding={"role":"project","source_node_offsets":child.scope,"bindings":child.bindings}
		"Button":
			binding={"role":"button","activate":Callable(self,"_ignore")}
			if not str(widget.get("callBackName","")).is_empty():binding["callback_name"]=str(widget.callBackName)
		"CheckBox":binding={"role":"checkbox","displaystate":false}
		"Text","TextBMFont":binding={"role":"static_source_text"}
		"ListView":
			var rows: Array=[]
			for row: Dictionary in node.get("children",[]):rows.append(int(row.get("_offset",-1)))
			binding={"role":"source_list","row_offsets":rows,"input":Callable(self,"_ignore_input")}
		"ScrollView":
			if bool(widget.get("touchEnabled",false)):binding={"role":"source_scroll","input":Callable(self,"_ignore_input")}
		"LoadingBar":binding={"role":"source_percent","percent":0.0}
	if offset in external and kind=="Sprite":binding={"role":"source_asset_slot","visible":false}
	elif bool(widget.get("touchEnabled",false)) and not binding.has("role") and kind!="ProjectNode":binding["role"]="consume"
	for pattern: String in spec:
		if key.ends_with("/"+pattern):binding.merge(spec[pattern],true)
	if not binding.is_empty():bindings[offset]=binding
	out[key]={"chain":chain,"offset":offset,"kind":kind}
	if kind=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_walk(child,key,chain,spec,scope,bindings,external,out)

## The player owning `key` and the node offset in it.
static func _locate(root: Node2D, out: Dictionary, suffix: String) -> Dictionary:
	for key: String in out:
		if not key.ends_with("/"+suffix):continue
		var entry: Dictionary=out[key]
		var player: Dictionary=root.project_player(entry.chain) if not (entry.chain as Array).is_empty() else {"ok":true,"player":root}
		if not player.get("ok",false):return player
		return {"ok":true,"player":player.player,"offset":int(entry.offset),"key":key}
	return {"ok":false,"error":"source_domination_node_missing","suffix":suffix}

func _scene_of(member: String, spec: Dictionary, out: Dictionary) -> Dictionary:
	var bound: Dictionary=_bind(member,"",[],spec,out)
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,member,bound.scope,bound.bindings)
	if not result.get("ok",false):
		scene.free()
		return result
	return {"ok":true,"scene":scene}

## Places an original row scene top-down in a ListView's content (Cocos y up,
## content origin at the list's lower-left).
func _add_row(content: Node2D, member: String, row: Node2D, index: int, list_size: Vector2, gap: float=0.0) -> void:
	var tree: Dictionary=_pack.scene(member).get("nodeTree",{})
	var panel: Dictionary=(tree.get("children",[]) as Array)[0] if not (tree.get("children",[]) as Array).is_empty() else {}
	var widget: Dictionary=panel.get("options",{}).get("widgetOptions",{})
	var size: Array=widget.get("size",[0,0])
	var position: Array=widget.get("position",[0,0])
	var anchor: Array=widget.get("anchorPoint",[0,0])
	var height: float=float(size[1])
	var bottom: float=list_size.y-(height+gap)*float(index+1)
	var x: float=(list_size.x-float(size[0]))*0.5-(float(position[0])-float(anchor[0])*float(size[0]))
	var y: float=bottom-(float(position[1])-float(anchor[1])*float(size[1]))
	row.position=Vector2(x,-y)
	content.add_child(row)

static func _list_size(out: Dictionary, pack: RefCounted, member: String, suffix: String) -> Vector2:
	for key: String in out:
		if not key.ends_with("/"+suffix):continue
		var node: Dictionary=Scene._node_at_offset(pack.scene(member).get("nodeTree",{}),int(out[key].offset))
		var size: Array=node.get("options",{}).get("widgetOptions",{}).get("size",[0,0])
		return Vector2(float(size[0]),float(size[1]))
	return Vector2.ZERO

## --- Stage --------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var runtime: Object=_runtime()
	if parent==null or runtime==null:return _fail("source_domination_window_host_unavailable")
	_disabled.clear()
	var spec: Dictionary=_all_spec()
	match _tab:
		"power":spec.merge(_power_spec(runtime))
		"fusion":spec.merge(_fusion_spec(runtime))
		"quest":spec.merge(_quest_spec(runtime))
	for suffix: String in _disabled:
		var entry: Dictionary=spec.get(suffix,{})
		entry["displaystate"]=not bool(_disabled[suffix])
		spec[suffix]=entry
	var out: Dictionary={}
	var built: Dictionary=_scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var filled: Dictionary={"ok":true}
	match _tab:
		"power":filled=_fill_power(next,out,runtime)
		"fusion":filled=_fill_fusion(next,out,runtime)
		"quest":filled=_fill_quest(next,out,runtime)
	if not filled.get("ok",false):
		next.free()
		last_result=filled
		return filled
	var previous: Node2D=_scene
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"tab":_tab,"filled":filled}
	return last_result

func _all_spec() -> Dictionary:
	var spec: Dictionary={}
	var tabs: Dictionary={"power":"Btn_Power","fusion":"Btn_Fusion","quest":"Btn_Quest"}
	for tab: String in tabs:
		spec[P_ALL+"Nd_TabMenu/"+tabs[tab]+"_On"]={"visible":_tab==tab,"activate":Callable(self,"_select_tab").bind(tab)}
		spec[P_ALL+"Nd_TabMenu/"+tabs[tab]+"_Off"]={"visible":_tab!=tab,"activate":Callable(self,"_select_tab").bind(tab)}
	spec[P_ALL+"Nd_TabMenu/Btn_Disassemble_On"]={"visible":false}
	spec[P_ALL+"Nd_TabMenu/Btn_Disassemble_Off"]={"visible":true,"activate":Callable(self,"_dismantle")}
	spec[P_ALL+"Nd_TabMenu/Sprite_New1"]={"visible":false}
	spec[P_ALL+"Nd_TabMenu/Sprite_New2"]={"visible":false}
	spec[P_ALL+"Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec[P_ALL+"Btn_HelpBox"]={"activate":Callable(self,"_open_help")}
	spec[P_ALL+"DominationStone_Tab_Power"]={"visible":_tab=="power"}
	spec[P_ALL+"DominationStone_Tab_Fusion"]={"visible":_tab=="fusion"}
	spec[P_ALL+"DominationStone_Tab_Quest"]={"visible":_tab=="quest"}
	# Roulette_Fx (an EventSound frame-event node; sound is out of scope) is
	# not mounted; the Roulette shows the merge result in its first slot.
	spec[P_FUSION+"DominationStone_Fusion_Roulette_Fx"]={"exclude":true}
	return spec

## --- 지배석 tab ------------------------------------------------------------

func _power_spec(runtime: Object) -> Dictionary:
	var spec: Dictionary={}
	var set_state: Dictionary=runtime.active_set()
	for index: int in range(3):
		var stone: String=P_POWER+"DominationStone_List_Stone0%d/Node/" % (index+1)
		var entry: Dictionary=runtime.slot(index)
		# Stone glow and slot visibility follow the original clips (_fill_power).
		spec[stone+"Nd_Stone/Nd_Lock"]={"visible":not runtime.slot_unlocked(index)}
		spec[stone+"Btn"]={"activate":Callable(self,"_stone_tapped").bind(index)}
		spec[stone+"DominationStone_Slot/Panel/Common_Slot/Btn"]={"activate":Callable(self,"_stone_tapped").bind(index)}
		spec[stone+"DominationStone_Slot/Panel/Common_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		spec[stone+"DominationStone_Slot/Panel/Common_Slot/Sp_SlotBg"]={"visible":not entry.is_empty()}
	var info: String="DominationStone_Power_Effect/Nd_Power_Info/"
	spec[P_POWER+info+"Nd_BasicEffect/Label_Title"]={"role":"source_text","text":str(set_state.get("title","")) if set_state.get("active",false) else "장착 효과"}
	spec[P_POWER+info+"Nd_OptionEffect/Label_Title"]={"role":"source_text","text":"%s · %s" % [str(set_state.name),str(SRC.GRADE_NAMES.get(int(set_state.grade),""))] if set_state.get("active",false) else "권능 비활성"}
	spec[P_POWER+"Nd_Probability/Btn_Probability"]={"activate":Callable(self,"_power_probability")}
	return spec

func _fill_power(root: Node2D, out: Dictionary, runtime: Object) -> Dictionary:
	var pictures: int=0
	var clips: Array[String]=[]
	for index: int in range(3):
		# The original List_Stone clips: Fx_Stone_On_Loop with a stone in the
		# slot, Fx_Stone_Loop for an open empty slot (a locked one stays still).
		var stone: Dictionary=_locate(root,out,"DominationStone_Tab_Power/DominationStone_List_Stone0%d" % (index+1))
		if not stone.get("ok",false):continue
		var holder: Node2D=stone.player.source_nodes.get(stone.offset)
		var player: Variant=holder.get_meta("source_project_player",null) if is_instance_valid(holder) else null
		if player==null:continue
		var clip: String="Fx_Stone_On_Loop" if not runtime.slot(index).is_empty() else ("Fx_Stone_Loop" if runtime.slot_unlocked(index) else "")
		if not clip.is_empty() and player.play(clip,true).get("ok",false):clips.append(clip)
	for index: int in range(3):
		var entry: Dictionary=runtime.slot(index)
		if entry.is_empty():continue
		var located: Dictionary=_locate(root,out,"DominationStone_List_Stone0%d/Node/DominationStone_Slot/Panel/Common_Slot/Sp_IconSample" % (index+1))
		if located.get("ok",false) and _picture(located.player,located.offset,entry.record):pictures+=1
	# Equipped stone effects (the item rows) and the active set's original rows.
	var basic: Array[String]=[]
	var mr: int=0
	var xp: float=0.0
	var equipped: int=0
	for index: int in range(3):
		var entry: Dictionary=runtime.slot(index)
		if entry.is_empty():continue
		equipped+=1
		mr+=int(entry.record.get("mr",0))
		xp+=float(entry.record.get("xp",0.0))
	basic.append("장착 %d / %d (해금 %s)" % [equipped,runtime.slot_count(),"·".join(PackedStringArray(SRC.SLOT_LEVELS.map(func(v: int) -> String: return str(v))))])
	if mr!=0:basic.append("마법 방어 +%d" % mr)
	if xp!=0.0:basic.append("경험치 획득 +%s%%" % String.num(xp*100.0,2))
	var set_state: Dictionary=runtime.active_set()
	var options: Array[String]=[]
	if set_state.get("active",false):
		for row: Dictionary in set_state.entries:
			if row.type=="FixedDesc" and not str(row.get("text","")).is_empty():options.append(str(row.text))
		options.append("※ 발동·지배 몬스터 효과는 표시만 합니다")
	elif int(set_state.get("equipped",0))==3:
		options.append("같은 종류의 지배석 3종을 장착하면 권능이 활성화됩니다")
	else:
		options.append("지배석 슬롯을 터치하여 가방의 지배석을 장착합니다")
	var info: String="DominationStone_Power_Effect/Nd_Power_Info/"
	var placed: int=0
	for pair: Array in [[info+"Nd_BasicEffect/ListView",ROW_BASIC,basic,"Panel_BasicEffect/Text_List"],[info+"Nd_OptionEffect/ListView",ROW_OPTION,options,"Panel_OptionEffect/Text_List"]]:
		var list: Dictionary=_locate(root,out,str(pair[0]))
		if not list.get("ok",false):return list
		var node: Node2D=list.player.source_nodes.get(list.offset)
		var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) else null
		if not content is Node2D:return _fail("source_domination_list_content_missing")
		var size: Vector2=_list_size(out,_pack,POWER_EFFECT,str(pair[0]))
		var lines: Array=pair[2]
		for index: int in range(lines.size()):
			var row_out: Dictionary={}
			var row: Dictionary=_scene_of(str(pair[1]),{str(pair[3]):{"role":"source_text","text":str(lines[index]),"cocos_wrap":str(pair[1])==ROW_OPTION}},row_out)
			if not row.get("ok",false):return row
			_add_row(content,str(pair[1]),row.scene,index,size)
			placed+=1
	return {"ok":true,"pictures":pictures,"rows":placed,"set":set_state.get("active",false),"clips":clips}

func _picture(player: Node2D, offset: int, record: Dictionary) -> bool:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or record.is_empty():return false
	var name: String=str(record.get("name",""))
	var context: Dictionary={"member":SLOT,"node_offset":SLOT_ICON,"reference":name}
	context["source_slot_contract"]=Scene.external_scene_slot_contract(_pack,SLOT,SLOT_ICON)
	var owner: Dictionary=InventoryImages.resolve_owned(hud,{"name":name,"reference":name,"record":record},context)
	if not owner.get("ok",false):return false
	var uploaded: Dictionary=player.set_bound_source_visual_result(offset,owner)
	if not uploaded.get("ok",false):return false
	return player.set_bound_visible(offset,true).get("ok",false)

func _stone_tapped(index: int) -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null:return _fail("source_domination_window_host_unavailable")
	var result: Dictionary
	if not runtime.slot(index).is_empty():result=runtime.unequip(index)
	elif not runtime.slot_unlocked(index):result={"ok":false,"error":"지배석 슬롯 %d은 %d레벨에 해금됩니다" % [index+1,SRC.SLOT_LEVELS[index]]}
	else:
		# The original inventory panel is not connected: the first bag stone of
		# the kind already equipped (else the first stone) is equipped.
		var kind: int=-1
		for other: int in range(3):
			var entry: Dictionary=runtime.slot(other)
			if not entry.is_empty() and not entry.info.is_empty():kind=int(entry.info.group)
		var stones: Array[Dictionary]=runtime.bag_stones()
		var chosen: Dictionary={}
		for stone: Dictionary in stones:
			if kind<0 or int(stone.info.group)==kind:
				if chosen.is_empty() or int(stone.info.grade)>int(chosen.info.grade):chosen=stone
		if chosen.is_empty() and not stones.is_empty():chosen=stones[0]
		result=runtime.equip(str(chosen.instance_id),index) if not chosen.is_empty() else {"ok":false,"error":"가방에 장착할 지배석이 없습니다"}
	_notify(result,"지배석 장착 변경")
	_stage()
	return result

func _power_probability() -> Dictionary:
	var runtime: Object=_runtime()
	var set_state: Dictionary=runtime.active_set() if runtime!=null else {}
	var lines: PackedStringArray=[]
	for row: Dictionary in set_state.get("entries",[]):
		if row.type=="InvokeOption":lines.append("원본 발동 확률 %s%% (InvokeOption %d)" % [String.num(float(row.probability_raw)/10000.0,2),int(row.target)])
	_message("권능 비활성" if lines.is_empty() else " · ".join(lines))
	return {"ok":true}

## --- 합성 tab --------------------------------------------------------------

func _fusion_spec(runtime: Object) -> Dictionary:
	var spec: Dictionary={}
	var showing_result: bool=not _result.is_empty()
	for index: int in range(SRC.MERGE_MAX):
		var slot_key: String=P_FUSION+(FUSION_SLOT % (index+1))+"/Nd_Slot/"
		spec[slot_key+"Panel_Shining"]={"visible":false}
		spec[slot_key+"Nd_Fx"]={"visible":false}
		spec[slot_key+"Common_Slot/Btn"]={"activate":Callable(self,"_fusion_remove").bind(index)}
		spec[slot_key+"Common_Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
		var filled: bool=index<_fusion.size() and not showing_result
		spec[slot_key+"Common_Slot/Sp_SlotBg"]={"visible":filled}
	spec[P_FUSION+"DominationStone_FusionBox/Nd_Fusion/Nd_Fusion_Slot/Fx_FusionBox_FullSlot"]={"visible":_fusion.size()==SRC.MERGE_MAX}
	for fx: String in ["Nd_Spark_01","Nd_Spark_02","Nd_Spark_03","Fx_Seet_Lightning_Bottom","Fx_Seet_Lightning_Top"]:
		spec[P_FUSION+"DominationStone_FusionBox/Nd_Fusion/Panel_Gear/"+fx]={"visible":false}
	spec[P_FUSION+"Btn_Probability"]={"activate":Callable(self,"_fusion_probability")}
	for check: String in GRADE_CHECKS:
		var grade: int=GRADE_CHECKS[check]
		var on: bool=bool(_grades.get(grade,false))
		spec[P_FUSION+"Nd_GradeButton/"+check+"/Btn_Off"]={"visible":not on,"activate":Callable(self,"_toggle_grade").bind(grade)}
		spec[P_FUSION+"Nd_GradeButton/"+check+"/Btn_On"]={"visible":on,"activate":Callable(self,"_toggle_grade").bind(grade)}
		spec[P_FUSION+"Nd_GradeButton/"+check+"/Sp_Light"]={"visible":on}
	var quote: Dictionary=runtime.merge_quote(_fusion) if _fusion.size()>=SRC.MERGE_MIN else {}
	var can_merge: bool=quote.get("ok",false) and not showing_result
	spec[P_FUSION+"Nd_Btn_Fusion"]={"visible":not showing_result}
	spec[P_FUSION+"Nd_Btn_Fusion/Btn_Fusion"]={"activate":Callable(self,"_merge")}
	spec[P_FUSION+"Nd_Btn_Fusion/Btn_Fusion/Normal"]={"visible":can_merge}
	spec[P_FUSION+"Nd_Btn_Fusion/Btn_Fusion/Disabled"]={"visible":not can_merge}
	# The tables name no merge price: the original amount display stays hidden.
	for part: String in ["Bg_Amount","Label_Amount","Icon"]:spec[P_FUSION+"Nd_Btn_Fusion/Btn_Fusion/Normal/"+part]={"visible":false}
	spec[P_FUSION+"Nd_Btn_Fusion/Btn_Fusion/Normal/Fx_Active"]={"visible":can_merge}
	_disabled[P_FUSION+"Nd_Btn_Fusion/Btn_Fusion"]=not can_merge
	spec[P_FUSION+"Nd_Btn_Ok"]={"visible":showing_result}
	var roulette: String=P_FUSION+"DominationStone_Fusion_Roulette/Nd_Slot/"
	spec[P_FUSION+"DominationStone_Fusion_Roulette"]={"visible":showing_result}
	for index: int in range(1,6):spec[roulette+"Panel_Mask/Nd_Roulette/Common_Slot_%d" % index]={"visible":false}
	spec[roulette+"Panel_Mask/Nd_Roulette/Common_Slot_0/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	spec[roulette+"Panel_Shining"]={"visible":false}
	spec[roulette+"Nd_Fx"]={"visible":false}
	spec[roulette+"Nd_Name/Label_Name"]={"role":"source_text","text":"%s [%s]" % [str(_result.get("name","")).get_slice(" · ",0),str(SRC.GRADE_NAMES.get(int(_result.get("grade",0)),""))] if showing_result else ""}
	spec[P_FUSION+"Nd_Btn_Ok/Btn_Ok"]={"activate":Callable(self,"_clear_result")}
	spec[P_FUSION+"Nd_Btn_Ok/Btn_Ok/Disabled"]={"visible":false}
	var can_register: bool=not showing_result and _fusion.size()<SRC.MERGE_MAX
	spec[P_FUSION+"Btn_Registration"]={"activate":Callable(self,"_bulk_register")}
	spec[P_FUSION+"Btn_Registration/Normal"]={"visible":can_register}
	spec[P_FUSION+"Btn_Registration/Disabled"]={"visible":not can_register}
	_disabled[P_FUSION+"Btn_Registration"]=not can_register
	var can_clear: bool=not _fusion.is_empty() and not showing_result
	spec[P_FUSION+"Btn_Cancelation"]={"activate":Callable(self,"_clear_fusion")}
	spec[P_FUSION+"Btn_Cancelation/Normal"]={"visible":can_clear}
	spec[P_FUSION+"Btn_Cancelation/Disabled"]={"visible":not can_clear}
	_disabled[P_FUSION+"Btn_Cancelation"]=not can_clear
	spec[P_FUSION+"Nd__Touch"]={"visible":false}
	spec[P_FUSION+"Nd_Fx"]={"visible":false}
	return spec

func _fill_fusion(root: Node2D, out: Dictionary, runtime: Object) -> Dictionary:
	var pictures: int=0
	var world: Object=_world.get_ref()
	var records: Array[Dictionary]=[]
	if not _result.is_empty():
		var located: Dictionary=_locate(root,out,"Nd_Roulette/Common_Slot_0/Sp_IconSample")
		if located.get("ok",false) and _picture(located.player,located.offset,_result.get("record",{})):pictures+=1
	else:
		for id: String in _fusion:records.append(runtime._record_of(id))
	for index: int in range(mini(records.size(),SRC.MERGE_MAX)):
		if records[index].is_empty():continue
		var located: Dictionary=_locate(root,out,(FUSION_SLOT % (index+1))+"/Nd_Slot/Common_Slot/Sp_IconSample")
		if located.get("ok",false) and _picture(located.player,located.offset,records[index]):pictures+=1
	# The original Tab_Fusion "Ok_On" clip brings in the 확인 button.
	var clip: String=""
	if not _result.is_empty():
		var tab: Dictionary=_locate(root,out,"DominationStone_All_Layout/DominationStone_Tab_Fusion")
		var holder: Node2D=tab.player.source_nodes.get(tab.offset) if tab.get("ok",false) else null
		var player: Variant=holder.get_meta("source_project_player",null) if is_instance_valid(holder) else null
		if player!=null and player.play("Ok_On",false).get("ok",false):clip="Ok_On"
	return {"ok":true,"pictures":pictures,"registered":_fusion.size(),"result":not _result.is_empty(),"world":world!=null,"clip":clip}

func _bulk_register() -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null or not _result.is_empty():return {"ok":false}
	var added: int=0
	for stone: Dictionary in runtime.bag_stones():
		if _fusion.size()>=SRC.MERGE_MAX:break
		if stone.locked or int(stone.info.merge_price)<=0 or not bool(_grades.get(int(stone.info.grade),false)) or str(stone.instance_id) in _fusion:continue
		_fusion.append(str(stone.instance_id))
		added+=1
	if added==0:_message("등록할 지배석이 없습니다 (장착·잠금 제외, 선택한 등급만)")
	_stage()
	return {"ok":true,"added":added,"registered":_fusion.size()}

func _fusion_remove(index: int) -> Dictionary:
	if _result.is_empty() and index<_fusion.size():_fusion.remove_at(index)
	_stage()
	return {"ok":true,"registered":_fusion.size()}

func _clear_fusion() -> Dictionary:
	_fusion.clear()
	_stage()
	return {"ok":true}

func _toggle_grade(grade: int) -> Dictionary:
	_grades[grade]=not bool(_grades.get(grade,false))
	_stage()
	return {"ok":true,"grades":_grades.duplicate()}

func _fusion_probability() -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null:return {"ok":false}
	var quote: Dictionary=runtime.merge_quote(_fusion)
	if not quote.get("ok",false):
		_message(str(quote.get("error","")))
		return quote
	var parts: PackedStringArray=[]
	for pair: Array in quote.grades:parts.append("%s %s%%" % [str(SRC.GRADE_NAMES.get(int(pair[0]),pair[0])),String.num(float(pair[1])/10000.0,2)])
	var text: String="합성 가격 %d · %s" % [int(quote.price)," · ".join(parts)]
	if int(quote.same_group)>0:text+=" · 같은 종류 유지 %s%%" % String.num(float(quote.same_group_probability_raw)/10000.0,2)
	_message(text)
	return quote

func _merge() -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null:return {"ok":false}
	var result: Dictionary=runtime.merge(_fusion)
	if result.get("ok",false):
		var world: Object=_world.get_ref()
		result["record"]=runtime._record_of(str(result.instance_id)) if not str(result.instance_id).is_empty() else world._catalog_item_from_source_id("m523:item:%d" % int(result.item_class_id))
		_result=result
		_fusion.clear()
		_message("합성 결과: %s [%s]" % [str(result.name),str(SRC.GRADE_NAMES.get(int(result.grade),""))])
	else:_notify(result,"")
	_stage()
	return result

func _clear_result() -> Dictionary:
	_result={}
	_stage()
	return {"ok":true}

## --- 퀘스트 tab ------------------------------------------------------------

func _quest_spec(runtime: Object) -> Dictionary:
	var spec: Dictionary={}
	# Default selection: the first floor of the first tower.
	var board: Array[Dictionary]=runtime.board()
	var floor_ok: bool=false
	for floor: Dictionary in board:
		if int(floor.floor_id)==_floor and int(floor.tower)==_tower:floor_ok=true
	if not floor_ok:
		for floor: Dictionary in board:
			if _tower<0:_tower=int(floor.tower)
			if int(floor.tower)==_tower:
				_floor=int(floor.floor_id)
				break
	var accepted: Dictionary=runtime.state.get("accepted",{})
	var cost: Dictionary=runtime.next_reroll_cost()
	var total: int=(runtime.contract().get("reroll",[]) as Array).size()
	var left: int=maxi(0,total-int(runtime.state.get("rerolls",0)))
	var can_reroll: bool=accepted.is_empty() and not cost.is_empty() and _floor>0
	for state: String in ["Normal","Disabled"]:
		var button: String=P_QUEST+"Nd_List_Quest/Btn_Refresh/"+state+"/"
		spec[button+"Label_Money"]={"role":"source_text","text":_number(int(cost.get("amount",0))) if not cost.is_empty() else "-"}
		spec[button+"Label"]={"role":"source_text","text":"새로 고침(%d)" % left}
		spec[button+"Sp_Icon"]={"visible":int(cost.get("currency_id",0))==4}
	spec[P_QUEST+"Nd_List_Quest/Btn_Refresh"]={"activate":Callable(self,"_reroll")}
	spec[P_QUEST+"Nd_List_Quest/Btn_Refresh/Normal"]={"visible":can_reroll}
	spec[P_QUEST+"Nd_List_Quest/Btn_Refresh/Disabled"]={"visible":not can_reroll}
	_disabled[P_QUEST+"Nd_List_Quest/Btn_Refresh"]=not can_reroll
	var can_accept: bool=accepted.is_empty() and _floor>0
	spec[P_QUEST+"Nd_List_Quest/Btn_Quest"]={"activate":Callable(self,"_accept")}
	spec[P_QUEST+"Nd_List_Quest/Btn_Quest/Normal"]={"visible":can_accept}
	spec[P_QUEST+"Nd_List_Quest/Btn_Quest/Disabled"]={"visible":not can_accept}
	_disabled[P_QUEST+"Nd_List_Quest/Btn_Quest"]=not can_accept
	spec[P_QUEST+"Nd_List_Quest/Btn_Reward"]={"visible":false}
	spec[P_QUEST+"Nd_List_Quest/Btn_Complete"]={"visible":false}
	var days: int=maxi(1,7-posmod(floori(float(runtime._now()+4*3600)/86400.0)-runtime.week_key(runtime._now()),7))
	spec[P_QUEST+"Nd_List_Quest/Label_Time"]={"role":"source_text","text":"%d일" % days}
	spec[P_QUEST+"Nd_List_Quest/Label_Time_R"]={"visible":false}
	spec[P_QUEST+"Nd_List_Quest/Label_Title"]={"role":"source_text","text":"퀘스트 선택" if accepted.is_empty() else "이번 주 수락한 퀘스트"}
	var reward_count: int=_selected_rewards(runtime).size()
	for index: int in range(1,6):
		spec[P_QUEST+"Nd_List_Reward/Quest_Slot_Set/Slot_%d/Sp_SlotBg" % index]={"visible":index<=reward_count}
	return spec

func _selected_rewards(runtime: Object) -> Array:
	for floor: Dictionary in runtime.board():
		if int(floor.floor_id)!=_floor:continue
		for slot: Dictionary in floor.slots:
			if int(slot.slot)==_quest_slot:return slot.quest.get("rewards",[])
	return []

func _fill_quest(root: Node2D, out: Dictionary, runtime: Object) -> Dictionary:
	var board: Array[Dictionary]=runtime.board()
	var c: Dictionary=runtime.contract()
	if board.is_empty():return {"ok":true,"floors":0}
	var towers: Array[int]=[]
	for floor: Dictionary in board:
		if int(floor.tower) not in towers:towers.append(int(floor.tower))
	if _tower not in towers:_tower=towers[0]
	var floors: Array[Dictionary]=[]
	for floor: Dictionary in board:
		if int(floor.tower)==_tower:floors.append(floor)
	var selected: Dictionary={}
	for floor: Dictionary in floors:
		if int(floor.floor_id)==_floor:selected=floor
	if selected.is_empty():
		selected=floors[0]
		_floor=int(selected.floor_id)
	var accepted: Dictionary=runtime.state.get("accepted",{})
	if not accepted.is_empty() and int(accepted.floor_id)==_floor:_quest_slot=int(accepted.slot)
	var lists: Dictionary={"Nd_List_Tower/ListView_Tower":[],"Nd_List_Floor/ListView_Floor":[],"Nd_List_Quest/ListView_Quest":[]}
	var placed: Dictionary={}
	for list_suffix: String in lists:
		var list: Dictionary=_locate(root,out,"Nd_Quest/"+list_suffix)
		if not list.get("ok",false):return list
		var node: Node2D=list.player.source_nodes.get(list.offset)
		var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) else null
		if not content is Node2D:return _fail("source_domination_list_content_missing")
		var size: Vector2=_list_size(out,_pack,TAB_QUEST,"Nd_Quest/"+list_suffix)
		var rows: Array[Dictionary]=[]
		match list_suffix:
			"Nd_List_Tower/ListView_Tower":
				for tower: int in towers:
					var on: bool=tower==_tower
					var name: String=str(c.towers.get(tower,{}).get("name",""))
					rows.append({"member":ROW_TOWER,"spec":{"Panel/Btn_Normal":{"visible":not on,"activate":Callable(self,"_select_tower").bind(tower)},"Panel/Btn_Pressed":{"visible":on,"activate":Callable(self,"_select_tower").bind(tower)},"Btn_Normal/Label":{"role":"source_text","text":name},"Btn_Pressed/Label":{"role":"source_text","text":name},"Panel/Sp_New":{"visible":false}}})
			"Nd_List_Floor/ListView_Floor":
				for floor: Dictionary in floors:
					var on: bool=int(floor.floor_id)==_floor
					var done: bool=not accepted.is_empty() and int(accepted.floor_id)==int(floor.floor_id)
					rows.append({"member":ROW_FLOOR,"spec":{"Panel/Label_Number":{"role":"source_text","text":"%d층" % int(floor.floor)},"Panel/Btn_Select":{"activate":Callable(self,"_select_floor").bind(int(floor.floor_id))},"Panel/Img_Select":{"visible":on},"Panel/Fx_Glow":{"visible":false},"Panel/Panel_Mask":{"visible":false},"Panel/Sp_New":{"visible":done}}})
			"Nd_List_Quest/ListView_Quest":
				for slot: Dictionary in selected.slots:
					var quest: Dictionary=slot.quest
					var is_accepted: bool=not accepted.is_empty() and int(accepted.quest_id)==int(quest.get("quest_id",-1)) and int(accepted.floor_id)==_floor
					var other_accepted: bool=not accepted.is_empty() and not is_accepted
					var on: bool=int(slot.slot)==_quest_slot
					var title: String=str(quest.get("title",""))
					var goal_parts: PackedStringArray=[]
					for goal: Dictionary in quest.get("goals",[]):goal_parts.append("%s (0/%d)" % [str(goal.text),int(goal.amount)])
					var detail: String=" · ".join(goal_parts) if not goal_parts.is_empty() else str(quest.get("level_text",""))
					detail+=" · "+str(quest.get("level_text",""))+(" · 수락함" if is_accepted else "")
					var row_spec: Dictionary={"Panel/Nd_Normal":{"visible":not other_accepted and not is_accepted},"Panel/Nd_Disabled":{"visible":other_accepted},"Panel/Nd_Complete":{"visible":is_accepted},"Nd_Disabled/Label_Fail":{"visible":false},"Nd_Complete/Label_Complete":{"visible":false},"Panel/Nd_CheckBox":{"visible":on},"Panel/Btn_Select":{"activate":Callable(self,"_select_quest").bind(int(slot.slot))},"Panel/Img_Select":{"visible":on},"Panel/Fx_Glow":{"visible":false},"Panel/Panel_Mask":{"visible":false}}
					for state: String in ["Nd_Normal","Nd_Disabled","Nd_Complete"]:
						row_spec[state+"/Label"]={"role":"source_text","text":title}
						row_spec[state+"/Label_Amount"]={"role":"source_text","text":detail}
					rows.append({"member":ROW_QUEST,"spec":row_spec})
		for index: int in range(rows.size()):
			var built: Dictionary=_scene_of(str(rows[index].member),rows[index].spec,{})
			if not built.get("ok",false):return built
			_add_row(content,str(rows[index].member),built.scene,index,size,3.0)
		placed[list_suffix]=rows.size()
	# Reward items of the selected quest (original Quest_Slot_Set slots).
	var quest: Dictionary={}
	for slot: Dictionary in selected.slots:
		if int(slot.slot)==_quest_slot:quest=slot.quest
	var world: Object=_world.get_ref()
	var pictures: int=0
	var rewards: Array=quest.get("rewards",[])
	for index: int in range(mini(rewards.size(),5)):
		var record: Dictionary=world._catalog_item_from_source_id("m523:item:%d" % int(rewards[index].item_class_id)) if world!=null else {}
		var located: Dictionary=_locate(root,out,"Quest_Slot_Set/Slot_%d/Sp_IconSample" % (index+1))
		if located.get("ok",false) and _picture(located.player,located.offset,record):pictures+=1
	return {"ok":true,"towers":towers.size(),"floors":floors.size(),"rows":placed,"floor_id":_floor,"slot":_quest_slot,"reward_pictures":pictures}

func _select_tower(tower: int) -> Dictionary:
	_tower=tower
	_floor=-1
	_stage()
	return {"ok":true,"tower":tower}

func _select_floor(floor_id: int) -> Dictionary:
	_floor=floor_id
	_stage()
	return {"ok":true,"floor_id":floor_id}

func _select_quest(slot: int) -> Dictionary:
	_quest_slot=slot
	_stage()
	return {"ok":true,"slot":slot}

func _reroll() -> Dictionary:
	var runtime: Object=_runtime()
	var result: Dictionary=runtime.reroll(_floor) if runtime!=null else {"ok":false}
	_notify(result,"퀘스트 새로고침")
	_stage()
	return result

func _accept() -> Dictionary:
	var runtime: Object=_runtime()
	var result: Dictionary=runtime.accept(_floor,_quest_slot) if runtime!=null else {"ok":false}
	if result.get("ok",false):_message("퀘스트 수락: %s (원본 퀘스트 진행·보상 연결 대기)" % str(result.get("title","")))
	else:_notify(result,"")
	_stage()
	return result

static func _number(value: int) -> String:
	var digits: String=str(absi(value))
	var parts: PackedStringArray=[]
	while digits.length()>3:
		parts.insert(0,digits.right(3))
		digits=digits.left(digits.length()-3)
	parts.insert(0,digits)
	return ("-" if value<0 else "")+",".join(parts)

## --- Help, menu tile, shared ---------------------------------------------

func _open_help() -> Dictionary:
	_help_page=0
	return _stage_help()

func _stage_help() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if parent==null:return _fail("source_domination_window_host_unavailable")
	var spec: Dictionary={"Nd/Btn_Left":{"activate":Callable(self,"_help_step").bind(-1)},"Nd/Btn_Right":{"activate":Callable(self,"_help_step").bind(1)}}
	for page: int in range(HELP_PAGES):spec["Nd/Nd_Page/Panel_%d" % (page+1)]={"visible":page==_help_page}
	var built: Dictionary=_scene_of(HELP,spec,{})
	if not built.get("ok",false):return built
	_close_help()
	_help=built.scene
	_help.position=Vector2(600.0,-337.5)
	_help.z_index=160
	parent.add_child(_help)
	return {"ok":true,"help_page":_help_page+1}

func _help_step(delta: int) -> Dictionary:
	_help_page+=delta
	if _help_page<0 or _help_page>=HELP_PAGES:
		_close_help()
		return {"ok":true,"help_closed":true}
	return _stage_help()

func _close_help() -> void:
	if is_instance_valid(_help) and not _help.is_queued_for_deletion():
		_help.hide()
		_help.queue_free()
	_help=null

## The original MainMenu_DominationStone tile for the existing menu grid.
func menu_tile(activate: Callable) -> Dictionary:
	if _pack==null or not _pack.manifest.get("scenes",{}).has(MENU_TILE):return _fail("source_domination_menu_tile_missing")
	return _scene_of(MENU_TILE,{"Panel/Button":{"activate":activate},"Panel/Sp_Event":{"visible":false},"Panel/Sp_New":{"visible":false},"Panel/Img_Disabled":{"visible":false}},{})

func _select_tab(tab: String) -> Dictionary:
	_tab=tab
	_close_help()
	_stage()
	return {"ok":true,"tab":tab}

func _dismantle() -> Dictionary:
	_message("분해: 원본 표에 지배석 파편 수량이 없어 연결하지 않았습니다")
	return {"ok":false,"error":"dismantle_not_in_tables"}

func _notify(result: Dictionary, success: String) -> void:
	if result.get("ok",false):
		if not success.is_empty():_message(success)
	else:_message(str(result.get("error","실패")))

func _message(text: String) -> void:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud!=null and hud.has_method("show_message"):hud.call("show_message",text)

func _ignore() -> Dictionary:
	return {"ok":true}

func _ignore_input(_event: InputEvent) -> void:
	pass

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
