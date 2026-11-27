extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 수호성 찾기 window (SkillTreeRandomOpenScene /
## SkillTree_RandomOpen) for the card choice the existing 수호성 rules keep
## pending after 활성화 (world.growth: state.pending {node, cards}, the
## failed cards of state.searches, quote / execute "choose").
## - Node_Bg: the original full-frame background from the guardian menu.
## - Card_GuidBox: one original SkillTree_Card_Default per card still in play
##   (failed cards are gone, as the rules remove them), in rows across the
##   box. The client drags a card onto Nd_DragLine; here a tap chooses it
##   (TWILIGHT 근사). The original common message box confirms the cost.
## - The result: SkillTree_Card_Result Nd_Success (the slot's name) or
##   Nd_Fail, 수호성 찾기 성공! / 실패!, and 화면을 터치하여 해당 창을 닫습니다
##   (a full-screen tap returns to the 수호성 window).
## - 나가기: back to the 수호성 window (the pending choice stays saved).
## Left empty: the drag line hint, the slot's skill icon on the result card
## (no TWILIGHT icon link), the 수호성 강화 popup
## (SkillTree_Popup_SkillEnchant: the existing view keeps 강화).
const ROOT="UI/SkillTreeRandomOpenScene.csb"
const PANEL="UI/SkillTree/SkillTree_RandomOpen.csb"
const CARD="UI/SkillTree/SkillTree_Card_Default.csb"
const RESULT="UI/SkillTree/SkillTree_Card_Result.csb"
const BACKGROUND={"path":"FullFrameUI_BG01.png","plistFile":"UI_Resource/Atlas_Texture.plist","resourceType":1}
const P="SkillTree_RandomOpen_Layout/"
const CARD_SIZE=Vector2(214.0,314.0)
const CARD_GAP: float=12.0
## pick / result
var stage: String="pick"
var slot: String=""
var group: String=""
var picked: int=-1
var won: bool=false

func required_members() -> Array[String]:
	return [ROOT,PANEL,CARD,RESULT]

func _root_member() -> String:
	return ROOT

## SkillTreeRandomOpenScene is laid out on the 1200x675 design frame.
func _root_position() -> Vector2:
	return Vector2.ZERO

func _runtime() -> Object:
	var owner: Object=world()
	var growth: Variant=owner.get("growth") if owner!=null else null
	return growth if growth is Object else null

## Opens the pending card choice; `star` is the 수호성 tab to return to.
func open(parent: Node, star: String="") -> Dictionary:
	var runtime: Object=_runtime()
	var pending: Variant=runtime.state.get("pending",{}) if runtime!=null else {}
	if not pending is Dictionary or (pending as Dictionary).is_empty():return _fail("source_guardian_find_nothing_pending")
	slot=str(pending.get("node",""))
	group=star
	stage="pick"
	picked=-1
	won=false
	return open_window(parent)

## The card indices still in play (all but the failed ones).
static func cards_in_play(state: Dictionary) -> Array[int]:
	var found: Array[int]=[]
	var pending: Dictionary=state.get("pending",{})
	if pending.is_empty():return found
	var failed: Array=state.get("searches",{}).get(str(pending.get("node","")),{}).get("failed",[])
	for index: int in range(int(pending.get("cards",0))):
		if not failed.has(index):found.append(index)
	return found

## Rows of at most `columns` cards, centred in a `box` (Cocos, y up): each
## card's centre and the shared scale.
static func card_layout(count: int, box: Vector2) -> Dictionary:
	if count<=0:return {"scale":1.0,"centres":[]}
	var columns: int=mini(count,8)
	var rows: int=int(ceil(float(count)/float(columns)))
	var scale: float=minf(1.0,minf(box.x/(float(columns)*(CARD_SIZE.x+CARD_GAP)),box.y/(float(rows)*(CARD_SIZE.y+CARD_GAP))))
	var pitch: Vector2=(CARD_SIZE+Vector2(CARD_GAP,CARD_GAP))*scale
	var centres: Array=[]
	for index: int in range(count):
		var row: int=floori(float(index)/float(columns))
		var in_row: int=mini(columns,count-row*columns)
		var column: int=index%columns
		var x: float=box.x*0.5+(float(column)-float(in_row-1)*0.5)*pitch.x
		var y: float=box.y*0.5+(float(rows-1)*0.5-float(row))*pitch.y
		centres.append(Vector2(x,y))
	return {"scale":scale,"centres":centres}

func _spec() -> Dictionary:
	var spec: Dictionary={}
	var runtime: Object=_runtime()
	var name: String=str(runtime.node(slot).get("name",slot)) if runtime!=null else slot
	var result: bool=stage=="result"
	spec["SkillTree_Popup_SkillEnchant_Layout"]={"exclude":true}
	spec[P+"Text_Title"]={"role":"source_text","text":"수호성 찾기 · %s" % name}
	spec[P+"Btn_Cancle"]={"activate":Callable(self,"_back"),"visible":not result}
	spec[P+"Nd_DragLine/SkillTree_Card_Default"]={"exclude":true}
	spec[P+"Nd_DragLine/Fx_SkillTree_Card"]={"exclude":true}
	spec[P+"Nd_DragLine/Text_Dsc"]={"visible":false}
	spec[P+"Nd_DragLine"]={"visible":not result}
	spec[P+"Fx_Start_Loop"]={"visible":not result}
	spec[P+"Fx_Start_Loop/Text_Select"]={"role":"source_text","text":"카드를 선택해주세요. (남은 카드 %d장)" % cards_in_play(runtime.state if runtime!=null else {}).size()}
	# Btn_Close carries an authored "Button" title in a font the pack does not
	# ship; a transparent full-screen catcher takes its place (_fill).
	spec[P+"Btn_Close"]={"exclude":true}
	spec[P+"Text_Close"]={"visible":result}
	spec[P+"Text_Success"]={"visible":result and won}
	spec[P+"Text_Fail"]={"visible":result and not won}
	spec[P+"Fx_Glow_Square_Fail"]={"visible":result and not won}
	spec[P+"SkillTree_Card_Result"]={"visible":result}
	spec[P+"SkillTree_Card_Result/Nd_Success"]={"visible":won}
	spec[P+"SkillTree_Card_Result/Nd_Fail"]={"visible":not won}
	spec[P+"SkillTree_Card_Result/Nd_Success/Sp_Illust_Load"]={"visible":false}
	spec[P+"SkillTree_Card_Result/Nd_Success/Sp_SkillIcon"]={"visible":false}
	spec[P+"SkillTree_Card_Result/Nd_Success/Text"]={"role":"source_text","text":name}
	spec[P+"Card_GuidBox"]={"visible":not result}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var runtime: Object=_runtime()
	var shown: int=0
	var has_background: bool=_mount_background(root,out)
	# The panel starts transparent at its first keyframe: the client's loop
	# clips (Fx_Loop while choosing, Fx_Success_Loop / Fx_Fail_Loop after).
	var panel: Node2D=_project(root,out,"SkillTree_RandomOpen_Layout")
	if panel!=null:
		if stage=="result":
			var loop: String="Fx_Success_Loop" if won else "Fx_Fail_Loop"
			var reveal: String="Fx_Open_End_Success" if won else "Fx_Open_End_Fail"
			if panel.play(reveal,false).get("ok",false):
				panel.clip_finished.connect(func(_name: String) -> void: panel.play(loop,true),CONNECT_ONE_SHOT)
			else:panel.play(loop,true)
		else:panel.play("Fx_Loop",true)
	if stage=="result":
		var card: Node2D=_project(root,out,"SkillTree_Card_Result")
		if card!=null:card.play("Fx_Success_Start" if won else "Fx_Fail_Start",false)
		var catcher:=Control.new()
		catcher.name="GuardianFindTouchClose"
		catcher.position=Vector2(-4000.0,-4000.0)
		catcher.size=Vector2(8000.0,8000.0)
		catcher.mouse_filter=Control.MOUSE_FILTER_STOP
		catcher.gui_input.connect(_touch_close)
		root.add_child(catcher)
		return {"ok":true,"stage":stage,"won":won,"cards":0,"original_background":has_background}
	var located: Dictionary=_locate(root,out,"Card_GuidBox")
	var box: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
	if not box is Node2D:return _fail("source_guardian_find_card_box_missing")
	# Cocos children sit on the panel's lower-left content origin.
	var origin: Node=(box as Node2D).get_node_or_null("SourceContentOrigin")
	if origin is Node2D:box=origin
	var in_play: Array[int]=cards_in_play(runtime.state)
	var layout: Dictionary=card_layout(in_play.size(),_node_size(out,"Card_GuidBox"))
	for position: int in range(in_play.size()):
		var index: int=in_play[position]
		var built: Dictionary=_scene_of(CARD,{"Fx_Card_Dissolve":{"exclude":true},"Btn":{"activate":Callable(self,"_pick").bind(index)},"Btn/Disable":{"visible":false}},{},"")
		if not built.get("ok",false):return built
		var at: Vector2=layout.centres[position]
		built.scene.position=Vector2(at.x,-at.y)
		built.scene.scale=Vector2.ONE*float(layout.scale)
		(box as Node2D).add_child(built.scene)
		shown+=1
	return {"ok":true,"stage":stage,"cards":shown,"scale":float(layout.scale),"original_background":has_background}

func _mount_background(root: Node2D, out: Dictionary) -> bool:
	var backdrop:=ColorRect.new()
	backdrop.name="GuardianFindBackdrop"
	backdrop.color=Color("111620")
	backdrop.position=Vector2(-200.0,-675.0)
	backdrop.size=Vector2(1600.0,675.0)
	backdrop.mouse_filter=Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)
	root.move_child(backdrop,0)
	var located: Dictionary=_locate(root,out,P+"Node_Bg")
	var texture: Texture2D=_pack.texture(BACKGROUND,true) if located.get("ok",false) else null
	if texture==null:return false
	var image:=Sprite2D.new()
	image.texture=texture
	image.scale=backdrop.size/texture.get_size()
	located.player.source_nodes[located.offset].add_child(image)
	return true

func _project(root: Node2D, out: Dictionary, suffix: String) -> Node2D:
	var located: Dictionary=_locate(root,out,suffix)
	if not located.get("ok",false):return null
	var node: Node=located.player.source_nodes.get(located.offset)
	var nested: Variant=node.get_meta("source_project_player") if node!=null and node.has_meta("source_project_player") else null
	return nested if nested is Node2D else null

## A card tap: the existing quote; a 수호석 cost is confirmed first.
func _pick(index: int) -> Dictionary:
	if stage!="pick":return {"ok":true,"ignored":true}
	var runtime: Object=_runtime()
	if runtime==null:return _fail("source_guardian_find_runtime_unavailable")
	var offer: Dictionary=runtime.quote("choose","",index)
	if not offer.get("ok",false):
		_message(str(offer.get("message","선택할 수 없는 카드입니다")))
		return {"ok":false,"handled":true,"offer":offer}
	if not runtime.guardian_source.has_node(slot):return _choose(index,offer)
	var owner: Object=hud()
	if owner==null or not owner.has_method("confirm_action"):return _fail("source_guardian_find_confirmation_unavailable")
	var scene: Node2D=_scene
	var confirm: String="confirm_source_action" if owner.has_method("confirm_source_action") else "confirm_action"
	owner.call(confirm,"수호성 찾기",str(offer.get("message","")),"확인",func(_count: int) -> void:
		if is_open() and _scene==scene:_choose(index,offer))
	return {"ok":true,"handled":true,"quoted":"choose"}

func _choose(index: int, offer: Dictionary) -> Dictionary:
	if stage!="pick" or not is_open():return {"ok":false,"handled":true}
	var runtime: Object=_runtime()
	var response: Dictionary=runtime.execute("choose","",index,int(offer.get("revision",0)),int(offer.get("day",-1)))
	if not response.get("ok",false):
		_message(str(response.get("message","처리하지 못했습니다")))
		return {"ok":false,"handled":true,"response":response}
	picked=index
	won=(runtime.state.get("nodes",[]) as Array).has(slot)
	stage="result"
	_message(str(response.get("message","")))
	if not is_open():return {"ok":true,"handled":true,"won":won}
	var staged: Dictionary=_stage()
	staged["won"]=won
	return staged

func _touch_close(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT)) and not event.pressed:
		_back.call_deferred()

## 나가기 / the result's full-screen close: back to the 수호성 window.
func _back() -> Dictionary:
	var owner: Object=hud()
	var controller: Variant=owner.get("original_main_ui_controller") if owner!=null else null
	if is_instance_valid(controller) and controller.has_method("try_open_feature_window"):
		var opened: Dictionary=controller.try_open_feature_window("guardians",[group])
		if opened.get("handled",false):return opened
	return _close_requested()
