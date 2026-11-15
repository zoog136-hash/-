extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 수호성 window: SkillTree_All (frame, title, close, the six
## star tabs 조우·아툰·질리언·크리스터·이실로테·케레니스, 분류 발동 스킬,
## the star's name, 수호성 초기화 with its price and tip) with the selected
## star's connection graph in ScrollView_SkillTree: every slot is the original
## SkillTree_Icon_Skill (발동·사용 스킬) or SkillTree_Icon_Bonus (능력치) at
## its SkillTreeSlot UIPosX / UIPosY cell,
## playing its original Fx_Loop_Yellow (opened), Fx_Slot_Off (closed) or
## Fx_Represent (분류 발동 스킬) clip; each prerequisite link is the
## original SkillTree_Icon_Line piece stretched and turned between the two
## slot centres (Nd_Normal when both are open). The cell pitch is not in the
## original data: data/growth/guardian_window_layout.json (TWILIGHT 추정,
## docs/GUARDIAN_WINDOW523_LAYOUT.md).
## Every rule stays with world.growth: 수호성 초기화 is its guardian_reset
## quote -> HUD confirmation -> execute; a slot tap (and a pending card choice)
## opens the existing 수호성 view on that slot, which keeps 활성화 / 카드 선택 /
## 강화 / 지정 / 시전. Left out: the slot info popup, the gauge, the message.
const ROOT="UI/SkillTree/SkillTree_All.csb"
const ICON_SKILL="UI/SkillTree/SkillTree_Icon_Skill.csb"
const ICON_BONUS="UI/SkillTree/SkillTree_Icon_Bonus.csb"
const LINE="UI/SkillTree/SkillTree_Icon_Line.csb"
const LAYOUT_PATH="res://data/growth/guardian_window_layout.json"
## growth guardian id -> original tab button (SkillTreeCategory.Name).
const STARS={"joe":"Zoewoo","atun":"Atune","gillian":"Zillian","christ":"Crister","isilote":"Ecilote","kerenis":"Kerenis"}
var selected: String="joe"
var _layout: Dictionary={}
var _graph: Node2D
var _graph_x: float=0.0
var _graph_min: float=0.0
var _graph_drag: bool=false

func required_members() -> Array[String]:
	return [ROOT,ICON_SKILL,ICON_BONUS,LINE]

func _root_member() -> String:
	return ROOT

func _runtime() -> Object:
	var owner: Object=world()
	return owner.get("growth") if owner!=null else null

static func layout() -> Dictionary:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	return parsed if parsed is Dictionary else {}

func open(parent: Node, id: String="") -> Dictionary:
	var runtime: Object=_runtime()
	if runtime==null or runtime.config.get("guardians",[]).is_empty():return _fail("source_guardian_window_runtime_unavailable")
	_layout=layout()
	if float(_layout.get("column_pitch",0))<=0.0 or float(_layout.get("row_pitch",0))<=0.0:return _fail("source_guardian_window_layout_unavailable")
	if STARS.has(id):selected=id
	_graph_x=0.0
	return open_window(parent)

func _group(runtime: Object) -> Dictionary:
	for group: Dictionary in runtime.config.guardians:
		if str(group.id)==selected:return group
	return {}

func _spec() -> Dictionary:
	var runtime: Object=_runtime()
	var group: Dictionary=_group(runtime)
	var spec: Dictionary={}
	for name: String in ["Nd_Gauge","Nd_Message","SkillTree_Popup_SkillInfo_Layout","Label_Time","Fx_Img_BG_Particle"]:spec[name]={"exclude":true}
	for id: String in STARS:
		var on: bool=id==selected
		spec["ListView_Tab/Btn_"+STARS[id]]={"activate":Callable(self,"_select").bind(id)}
		spec["ListView_Tab/Btn_"+STARS[id]+"/On"]={"visible":on}
		spec["ListView_Tab/Btn_"+STARS[id]+"/Off"]={"visible":not on}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	var representative: String=runtime.guardian_representative(int(group.get("category_id",0)))
	var rep_name: String=str(runtime.node(representative).get("name","")) if not representative.is_empty() else "미설정"
	spec["Nd_TopMenu/Label"]={"role":"source_text","text":"수호성 마법 발동 스킬 : %s (%s)" % [str(group.get("name","")),rep_name]}
	spec["Nd_TopMenu/Nd_Point/Label"]={"role":"source_text","text":_number(int(runtime.world.inventory.get("수호석",0)) if runtime.world!=null else 0)}
	spec["Nd_SkillTreeInfo/Label_Name"]={"role":"source_text","text":_spaced(str(group.get("name","")))}
	spec["Nd_SkillTreeInfo/Btn_HelpBox"]={"visible":false}
	spec["ScrollView_SkillTree"]={"role":"source_scroll","input":Callable(self,"_graph_input")}
	var offer: Dictionary=runtime.quote("guardian_reset",selected)
	var can_reset: bool=bool(offer.get("ok",false))
	# Nd_Button (authored hidden) shows once the star has a reset to offer;
	# the slot guide shares its place.
	spec["Nd_Button"]={"visible":can_reset}
	spec["Label_Guide"]={"visible":not can_reset}
	spec["Nd_Button/Btn_Reset"]={"activate":Callable(self,"_reset"),"displaystate":can_reset}
	spec["Nd_Button/Btn_Reset/Normal"]={"visible":can_reset}
	spec["Nd_Button/Btn_Reset/Disabled"]={"visible":not can_reset}
	spec["Nd_Button/Btn_Reset/Text_Price"]={"role":"source_text","text":_number(int(runtime.guardian_source.constant("InitializeCost")))}
	return spec

static func _spaced(name: String) -> String:
	return name.substr(0,1)+" "+name.substr(1,1) if name.length()==2 else name

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var runtime: Object=_runtime()
	var group: Dictionary=_group(runtime)
	var located: Dictionary=_locate(root,out,"ScrollView_SkillTree")
	if not located.get("ok",false):return located
	var scroll: Variant=located.player.source_nodes.get(located.offset)
	var content: Variant=(scroll as Node).find_child("SourceOriginalScrollContent",true,false) if is_instance_valid(scroll) else null
	if not content is Node2D:return _fail("source_guardian_window_graph_missing")
	var graph:=Node2D.new()
	graph.name="GuardianGraph"
	(content as Node2D).add_child(graph)
	var opened: Array=runtime.state.get("nodes",[])
	var representative: String=runtime.guardian_representative(int(group.get("category_id",0)))
	var centres: Dictionary={}
	var width: float=0.0
	for node: Dictionary in group.get("nodes",[]):
		centres[str(node.id)]=cell_centre(_layout,int(node.get("ui_x",1)),int(node.get("ui_y",1)))
		width=maxf(width,(centres[str(node.id)] as Vector2).x+float(_layout.column_pitch)*0.5)
	var lines: int=0
	for node: Dictionary in group.get("nodes",[]):
		for prerequisite: Variant in node.get("prerequisites",[]):
			if not centres.has(str(prerequisite)):continue
			var both: bool=opened.has(str(node.id)) and opened.has(str(prerequisite))
			var built: Dictionary=_line(centres[str(prerequisite)],centres[str(node.id)],both)
			if not built.get("ok",false):return built
			graph.add_child(built.scene)
			lines+=1
	var slots: int=0
	var clips: int=0
	for node: Dictionary in group.get("nodes",[]):
		var id: String=str(node.id)
		var skill: bool=str(node.get("kind",""))!="stat"
		var open_now: bool=opened.has(id)
		var spec: Dictionary={"Particle_1":{"exclude":true},"Particle_2":{"exclude":true}}
		spec["Btn_Icon_Skill" if skill else "Btn_Icon_Bonus"]={"activate":Callable(self,"_slot_pressed").bind(id)}
		var built: Dictionary=_scene_of(ICON_SKILL if skill else ICON_BONUS,spec,{},"")
		if not built.get("ok",false):return built
		var at: Vector2=centres[id]
		built.scene.position=Vector2(at.x,-at.y)
		graph.add_child(built.scene)
		# The slot's own clips: Fx_Represent (분류 발동 스킬), Fx_Loop_Yellow
		# (opened) or Fx_Slot_Off (closed).
		var clip: String="Fx_Represent" if id==representative else ("Fx_Loop_Yellow" if open_now else "Fx_Slot_Off")
		if built.scene.play(clip,clip!="Fx_Slot_Off").get("ok",false):clips+=1
		slots+=1
	var visible_width: float=_node_size(out,"ScrollView_SkillTree").x
	_graph=graph
	_graph_min=minf(0.0,visible_width-width)
	_graph_x=clampf(_graph_x,_graph_min,0.0)
	graph.position.x=_graph_x
	return {"ok":true,"selected":selected,"slots":slots,"clips":clips,"lines":lines,"width":width}

## Slot centre in the graph's Cocos space (x right, y up from the bottom of
## the 430-high inner area) for SkillTreeSlot UIPosX / UIPosY.
static func cell_centre(values: Dictionary, x: int, y: int) -> Vector2:
	var first: Array=values.get("first_cell_center",[59.0,43.0])
	var height: float=float(values.get("inner_height",430.0))
	return Vector2(float(first[0])+float(x-1)*float(values.column_pitch),height-(float(first[1])+float(y-1)*float(values.row_pitch)))

## The original 32x8 line piece stretched and turned from `from` to `to`.
func _line(from: Vector2, to: Vector2, opened: bool) -> Dictionary:
	var built: Dictionary=_scene_of(LINE,{"Nd_Normal":{"visible":opened},"Nd_Disable":{"visible":not opened},"Sprite_1":{"exclude":true}},{},"")
	if not built.get("ok",false):return built
	var delta: Vector2=to-from
	var scene: Node2D=built.scene
	scene.position=Vector2(from.x,-from.y)
	scene.rotation=-delta.angle()
	scene.scale=Vector2(delta.length()/float(_layout.get("line_tile_length",32.0)),1.0)
	return {"ok":true,"scene":scene}

func _graph_input(event: InputEvent) -> void:
	if not is_instance_valid(_graph):return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		_graph_drag=event.pressed
		if event.pressed:_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.x
	elif event is InputEventMouseMotion and _graph_drag:delta=event.relative.x
	if delta==0.0:return
	var scale_x: float=absf(_graph.get_global_transform_with_canvas().get_scale().x)
	if scale_x>0.0:delta/=scale_x
	_moved+=absf(delta)
	_graph_x=clampf(_graph_x+delta,_graph_min,0.0)
	_graph.position.x=_graph_x

## --- Actions ------------------------------------------------------------------

func _select(id: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	if id==selected:return {"ok":true,"same":true}
	selected=id
	_graph_x=0.0
	return _stage()

## A slot opens the existing 수호성 view on it (활성화, 카드 선택, 강화,
## 지정, 시전 and their confirmations stay there).
func _slot_pressed(id: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	return _route("open_growth_native",["guardians",selected,id])

func _reset() -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var runtime: Object=_runtime()
	var offer: Dictionary=runtime.quote("guardian_reset",selected)
	if not offer.get("ok",false):
		_message(str(offer.get("message","초기화할 수 없습니다")))
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_guardian_window_confirmation_unavailable")
	var target: String=selected
	owner.call("confirm_action","수호성 초기화",str(offer.message),"확인",func(_count: int) -> void:
		var response: Dictionary=runtime.execute("guardian_reset",target,1,int(offer.get("revision",0)),int(offer.get("day",-1)))
		_message(str(response.get("message","")))
		if is_open():_stage())
	return {"ok":true,"quoted":"guardian_reset"}
