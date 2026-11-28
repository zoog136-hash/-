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
## The info panel lists the star's opened slots (SkillTree_Text_Buff01: name
## and effect, Lv) in ListView_1. A slot tap opens the original slot info
## popup (SkillTree_Popup_SkillInfo_Layout): name, Lv, cost, prerequisites,
## effect and detail lines (SkillTree_Text_02 in ListView_Info), the
## 수호성 마법발동 스킬 설정 ON / OFF of an opened skill slot, 닫기 and 활성화.
## Every rule stays with world.growth: 수호성 초기화, 활성화 and 대표 지정 are
## its quote -> HUD confirmation -> execute; the card choice after 활성화 opens
## the original 수호성 찾기 window (source_main_guardian_find_window). An
## opened passive skill can enter the original 강화 window. The existing
## view also provides the cast action for equipped active guardian skills.
const ROOT="UI/SkillTree/SkillTree_All.csb"
const ICON_SKILL="UI/SkillTree/SkillTree_Icon_Skill.csb"
const ICON_BONUS="UI/SkillTree/SkillTree_Icon_Bonus.csb"
const LINE="UI/SkillTree/SkillTree_Icon_Line.csb"
const INFO_ROW="UI/SkillTree/SkillTree_Text_02.csb"
const EFFECT_ROW="UI/SkillTree/SkillTree_Text_Buff01.csb"
const POPUP="SkillTree_Popup_SkillInfo_Layout"
const GrowthView=preload("res://scripts/growth/growth_view.gd")
const LAYOUT_PATH="res://data/growth/guardian_window_layout.json"
## growth guardian id -> original tab button (SkillTreeCategory.Name).
const STARS={"joe":"Zoewoo","atun":"Atune","gillian":"Zillian","christ":"Crister","isilote":"Ecilote","kerenis":"Kerenis"}
var selected: String="joe"
## The slot whose info popup is open ("" = closed).
var info: String=""
var _layout: Dictionary={}
var _graph: Node2D
var _graph_rows: Array=[]
var _graph_inputs: Array=[]
var _graph_summary: Dictionary={}
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
	info=""
	return open_window(parent)

func _group(runtime: Object) -> Dictionary:
	for group: Dictionary in runtime.config.guardians:
		if str(group.id)==selected:return group
	return {}

func _spec() -> Dictionary:
	var runtime: Object=_runtime()
	var group: Dictionary=_group(runtime)
	var spec: Dictionary={}
	for name: String in ["Nd_Gauge","Nd_Message","Label_Time","Fx_Img_BG_Particle"]:spec[name]={"exclude":true}
	if info.is_empty() or not _rows_available():spec[POPUP]={"exclude":true}
	else:_popup_spec(runtime,spec)
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
	var rows: Array=group.get("nodes",[])
	var owned: Array=runtime.state.get("nodes",[])
	var opened: Dictionary={}
	for row: Dictionary in rows:
		if owned.has(row.id):opened[row.id]=true
	var representative: String=runtime.guardian_representative(int(group.get("category_id",0)))
	var inputs: Array=[selected,opened,representative,_layout,_pack.get_instance_id()]
	var reuse: bool=is_open() and is_instance_valid(_graph) and is_same(_graph_rows,rows) and _graph_inputs==inputs
	var graph: Node2D=_graph
	var summary: Dictionary=_graph_summary
	if not reuse:
		graph=Node2D.new()
		graph.name="GuardianGraph"
		(content as Node2D).add_child(graph)
		summary=_fill_graph(graph,rows,opened,representative)
		if not summary.get("ok",false):return summary
	var effects: int=-1
	if _rows_available():
		var listed: Dictionary=_fill_list(root,out,"Nd_SkillTreeInfo/ListView_1",_effect_rows(runtime,group))
		if not listed.get("ok",false):return listed
		effects=int(listed.rows)
		if not info.is_empty():
			var lines_info: Dictionary=_fill_list(root,out,POPUP+"/Nd_SkillInfo/Nd_Skill/ListView_Info",_info_rows(runtime,info))
			if not lines_info.get("ok",false):return lines_info
	# A slot popup changes the details, not the graph. Keep the live
	# scroll position and move the existing graph after the new detail bound.
	if reuse:graph.reparent(content,false)
	_graph=graph
	_graph_rows=rows
	_graph_inputs=inputs
	_graph_summary=summary
	_graph_min=minf(0.0,_node_size(out,"ScrollView_SkillTree").x-float(summary.width))
	_graph_x=clampf(_graph_x,_graph_min,0.0)
	graph.position.x=_graph_x
	return {"ok":true,"selected":selected,"slots":summary.slots,"clips":summary.clips,"lines":summary.lines,
		"width":summary.width,"effects":effects,"info":info}

func _fill_graph(graph: Node2D, rows: Array, opened: Dictionary, representative: String) -> Dictionary:
	var centres: Dictionary={}
	var width: float=0.0
	for node: Dictionary in rows:
		centres[str(node.id)]=cell_centre(_layout,int(node.get("ui_x",1)),int(node.get("ui_y",1)))
		width=maxf(width,(centres[str(node.id)] as Vector2).x+float(_layout.column_pitch)*0.5)
	var lines: int=0
	for node: Dictionary in rows:
		for prerequisite: Variant in node.get("prerequisites",[]):
			if not centres.has(str(prerequisite)):continue
			var both: bool=opened.has(str(node.id)) and opened.has(str(prerequisite))
			var built: Dictionary=_line(centres[str(prerequisite)],centres[str(node.id)],both)
			if not built.get("ok",false):return built
			graph.add_child(built.scene)
			lines+=1
	var slots: int=0
	var clips: int=0
	for node: Dictionary in rows:
		var id: String=str(node.id)
		var skill: bool=str(node.get("kind",""))!="stat"
		var open_now: bool=opened.has(id)
		var spec: Dictionary={"Particle_1":{"exclude":true},"Particle_2":{"exclude":true}}
		var button_name: String="Btn_Icon_Skill" if skill else "Btn_Icon_Bonus"
		spec[button_name]={"activate":Callable(self,"_slot_pressed").bind(id)}
		var slot_nodes: Dictionary={}
		var built: Dictionary=_scene_of(ICON_SKILL if skill else ICON_BONUS,spec,slot_nodes)
		if not built.get("ok",false):return built
		var located_button: Dictionary=_locate(built.scene,slot_nodes,button_name)
		if located_button.get("ok",false):
			var button_node: Node=located_button.player.source_nodes.get(located_button.offset)
			if is_instance_valid(button_node) and button_node.has_meta("source_button"):
				var button: Object=button_node.get_meta("source_button")
				if is_instance_valid(button):button.set_meta(Router.DRAG_META,Callable(self,"_graph_input"))
		var at: Vector2=centres[id]
		built.scene.position=Vector2(at.x,-at.y)
		graph.add_child(built.scene)
		# The slot's own clips: Fx_Represent (분류 발동 스킬), Fx_Loop_Yellow
		# (opened) or Fx_Slot_Off (closed).
		var clip: String="Fx_Represent" if id==representative else ("Fx_Loop_Yellow" if open_now else "Fx_Slot_Off")
		if built.scene.play(clip,clip!="Fx_Slot_Off").get("ok",false):clips+=1
		slots+=1
	return {"ok":true,"slots":slots,"clips":clips,"lines":lines,"width":width}

## The row members of the effect list and the popup (absent in older packs).
func _rows_available() -> bool:
	var scenes: Dictionary=_pack.manifest.get("scenes",{}) if _pack!=null else {}
	return scenes.has(INFO_ROW) and scenes.has(EFFECT_ROW)

## ListView_1: the star's opened slots, one SkillTree_Text_Buff01 each.
func _effect_rows(runtime: Object, group: Dictionary) -> Array:
	var opened: Array=runtime.state.get("nodes",[])
	var rows: Array=[]
	for node: Dictionary in group.get("nodes",[]):
		var id: String=str(node.id)
		if not opened.has(id):continue
		# A skill slot by its name, an ability slot by its current effect.
		var effect: Dictionary=runtime.guardian_source.effects(id,runtime.guardian_level(id)) if runtime.guardian_source.has_node(id) else {}
		var text: String=GrowthView.effect_text(runtime,effect) if str(node.get("kind",""))=="stat" and not effect.is_empty() else str(node.get("name",id))
		rows.append({"member":EFFECT_ROW,"spec":{"Nd_Effect/On":{"visible":true},"Nd_Effect/Off":{"visible":false},
			"On/Label_Dsc":{"role":"source_text","text":text},"On/Label_Level":{"role":"source_text","text":"Lv.%d" % runtime.guardian_level(id),"visible":int(node.get("max_level",0))>0}}})
	return rows

## The slot info popup: title, buttons and the representative ON / OFF.
func _popup_spec(runtime: Object, spec: Dictionary) -> void:
	var row: Dictionary=runtime.node(info)
	var opened: bool=(runtime.state.get("nodes",[]) as Array).has(info)
	var skill: bool=str(row.get("kind",""))!="stat"
	spec[POPUP]={"visible":true}
	for name: String in ["Fx_Popup_RightBottom","Fx_Popup_LeftUp","Nd_Skill/Common_Slot","Nd_Skill/Label_Probability"]:spec[POPUP+"/"+name if not name.begins_with("Nd_Skill") else name]={"exclude":true}
	spec[POPUP+"/Btn_Close"]={"activate":Callable(self,"_close_info")}
	# The authored touch on the popup title only keeps taps inside the popup.
	spec["Nd_SkillInfo/Label_Title"]={"input":Callable(self,"_ignore_input")}
	spec["Nd_SkillInfo/Btn_No"]={"activate":Callable(self,"_close_info")}
	var name: String=str(row.get("name",info))
	if int(row.get("max_level",0))>0:name+="  Lv.%d / %d" % [runtime.guardian_level(info),int(row.max_level)]
	spec["Nd_Skill/Label_SkillName"]={"role":"source_text","text":name}
	# Opened slots use the same authored info popup for 강화 or 시전.
	var activate: Dictionary=runtime.quote("activate",info) if not opened else {}
	var ok: bool=opened or bool(activate.get("ok",false))
	var label: String="활성화"
	if opened:
		if str(row.get("kind",""))=="active":label="사용 스킬 시전"
		else:label="수호성 강화" if int(row.get("max_level",0))>runtime.guardian_level(info) else "수호성 정보"
	spec["Nd_SkillInfo/Btn_Ok"]={"activate":Callable(self,"_info_ok"),"displaystate":ok}
	spec["Btn_Ok/Normal"]={"visible":ok}
	spec["Btn_Ok/Disabled"]={"visible":not ok}
	spec["Btn_Ok/Normal/Label"]={"role":"source_text","text":label}
	spec["Btn_Ok/Disabled/Label"]={"role":"source_text","text":label}
	# 수호성 마법발동 스킬 설정 (분류 발동 스킬) for an opened skill slot.
	var represent: bool=opened and skill
	var current: bool=runtime.guardian_representative(int(row.get("category_id",0)))==info
	spec["Nd_Skill/Nd_Represent"]={"visible":represent}
	spec["Nd_On/Btn_Active_On"]={"visible":current,"activate":Callable(self,"_ignore")}
	spec["Nd_On/Btn_Active_Off"]={"visible":not current,"activate":Callable(self,"_represent")}
	spec["Nd_Off/Btn_Inactive_On"]={"visible":not current,"activate":Callable(self,"_ignore")}
	spec["Nd_Off/Btn_Inactive_Off"]={"visible":current,"activate":Callable(self,"_ignore")}

## ListView_Info: the slot's lines from the existing guardian source, one
## SkillTree_Text_02 (title + description) each.
func _info_rows(runtime: Object, id: String) -> Array:
	var row: Dictionary=runtime.node(id)
	var lines: Array=[]
	var level: int=runtime.guardian_level(id)
	if runtime.guardian_source.has_node(id):
		lines.append(["비용","1회 수호석 %d개 · 카드 %d장" % [int(row.get("cost",0)),int(row.get("cards",0))]])
		var previous: Array[String]=[]
		for prerequisite: Variant in row.get("prerequisites",[]):previous.append(str(runtime.node(str(prerequisite)).get("name","")))
		lines.append(["선행","없음" if previous.is_empty() else " → ".join(previous)])
		lines.append(["능력치",GrowthView.effect_text(runtime,runtime.guardian_source.effects(id,level))])
		var detail: String=runtime.guardian_source.detail(id,level)
		if not detail.is_empty():lines.append(["효과",detail])
		if int(row.get("max_level",0))>level:lines.append(["다음 강화",runtime.guardian_source.detail(id,level+1)])
	var rows: Array=[]
	for line: Array in lines:
		rows.append({"member":INFO_ROW,"spec":{"Nd_Skill":{"visible":true},"Nd_Bonus":{"visible":false},
			"Nd_Skill/Text_Title":{"role":"source_text","text":str(line[0])},"Nd_Skill/Text_Desc":{"role":"source_text","text":str(line[1])}}})
	return rows

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
	if id==selected:return {"ok":true,"same":true}
	selected=id
	_graph_x=0.0
	return _stage()

## A slot opens its original info popup or resumes its pending card choice.
func _slot_pressed(id: String) -> Dictionary:
	if _dragged():return {"ok":true,"ignored_after_drag":true}
	var runtime: Object=_runtime()
	var pending: Dictionary=runtime.state.get("pending",{})
	if not pending.is_empty():
		if str(pending.get("node",""))==id:return _find(selected)
		_message("진행 중인 수호성 카드 선택을 먼저 완료하세요.")
		return _fail("source_guardian_window_card_pending")
	if not _rows_available():
		_message("원본 수호성 정보를 표시할 수 없습니다.")
		return _fail("source_guardian_window_info_unavailable")
	info=id
	return _stage()

func _close_info() -> Dictionary:
	info=""
	return _stage()

## 활성화: quote -> confirmation -> execute. An opened passive skill can
## enter the authored 강화 screen when the selected pack provides it.
func _info_ok() -> Dictionary:
	var runtime: Object=_runtime()
	var id: String=info
	if id.is_empty():return _fail("source_guardian_window_slot_unselected")
	if (runtime.state.get("nodes",[]) as Array).has(id):
		var row: Dictionary=runtime.node(id)
		if row.get("kind","")=="active":return _cast(id)
		if int(row.get("max_level",0))<=runtime.guardian_level(id):return _close_info()
		return _open_guardian_step("guardian_enchant",[selected,id],"수호성 강화")
	if str((runtime.state.get("pending",{}) as Dictionary).get("node",""))==id:
		info=""
		return _find(selected)
	var offer: Dictionary=runtime.quote("activate",id)
	if not offer.get("ok",false):
		_message(str(offer.get("message","활성화할 수 없습니다")))
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_guardian_window_confirmation_unavailable")
	var group: String=selected
	var confirm: String="confirm_source_action" if owner.has_method("confirm_source_action") else "confirm_action"
	owner.call(confirm,"수호성 활성화",str(offer.message),"확인",func(_count: int) -> void:
		var response: Dictionary=runtime.execute("activate",id,1,int(offer.get("revision",0)),int(offer.get("day",-1)))
		_message(str(response.get("message","")))
		info=""
		if response.get("ok",false) and not (runtime.state.get("pending",{}) as Dictionary).is_empty():_find(group)
		elif is_open():_stage())
	return {"ok":true,"quoted":"activate"}

func _find(group: String) -> Dictionary:
	return _open_guardian_step("guardian_find",[group],"수호성 찾기")

func _open_guardian_step(key: String, arguments: Array, title: String) -> Dictionary:
	var owner: Object=hud()
	var controller: Variant=owner.get("original_main_ui_controller") if owner!=null else null
	if is_instance_valid(controller) and controller.has_method("try_open_feature_window"):
		var opened: Dictionary=controller.try_open_feature_window(key,arguments)
		if opened.get("handled",false):return opened
	_message("원본 %s 화면을 열 수 없습니다." % title)
	return _fail("source_%s_window_unavailable" % key)

func _cast(id: String) -> Dictionary:
	var runtime: Object=_runtime()
	var offer: Dictionary=runtime.quote("guardian_cast",id)
	if not offer.get("ok",false):
		_message(str(offer.get("message","사용 스킬을 시전할 수 없습니다")))
		return _fail("source_guardian_cast_refused")
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_source_action"):return _fail("source_guardian_window_confirmation_unavailable")
	var accept:=func(_count: int) -> void:
		var response: Dictionary=runtime.execute("guardian_cast",id,1,int(offer.get("revision",0)),int(offer.get("day",-1)))
		_message(str(response.get("message","")))
		if is_open():_stage()
	var review: Variant=owner.call("confirm_source_action","수호성 스킬 시전",str(offer.message),"시전",accept)
	return {"ok":true,"quoted":"guardian_cast"} if is_instance_valid(review) else _fail("source_guardian_window_confirmation_unavailable")

## 수호성 마법발동 스킬 설정 ON: the existing representative action.
func _represent() -> Dictionary:
	var runtime: Object=_runtime()
	var id: String=info
	var offer: Dictionary=runtime.quote("representative",id)
	if not offer.get("ok",false):
		_message(str(offer.get("message","지정할 수 없습니다")))
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_guardian_window_confirmation_unavailable")
	var confirm: String="confirm_source_action" if owner.has_method("confirm_source_action") else "confirm_action"
	owner.call(confirm,"분류 발동 스킬 지정",str(offer.message),"확인",func(_count: int) -> void:
		var response: Dictionary=runtime.execute("representative",id,1,int(offer.get("revision",0)),int(offer.get("day",-1)))
		_message(str(response.get("message","")))
		if is_open():_stage())
	return {"ok":true,"quoted":"representative"}

func _reset() -> Dictionary:
	var runtime: Object=_runtime()
	var offer: Dictionary=runtime.quote("guardian_reset",selected)
	if not offer.get("ok",false):
		_message(str(offer.get("message","초기화할 수 없습니다")))
		return {"ok":false}
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_guardian_window_confirmation_unavailable")
	var target: String=selected
	var confirm: String="confirm_source_action" if owner.has_method("confirm_source_action") else "confirm_action"
	owner.call(confirm,"수호성 초기화",str(offer.message),"확인",func(_count: int) -> void:
		var response: Dictionary=runtime.execute("guardian_reset",target,1,int(offer.get("revision",0)),int(offer.get("day",-1)))
		_message(str(response.get("message","")))
		if is_open():_stage())
	return {"ok":true,"quoted":"guardian_reset"}
