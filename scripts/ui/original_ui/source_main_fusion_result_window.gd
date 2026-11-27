extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 합성 결과 window (Change_Fusion_All) for a card fusion the
## existing rule already rolled and saved (renewal_hud.present_card_reveal
## with is_fusion, only when the UI pack has the members; every other reveal
## keeps the existing CardRevealStage). The HUD keeps its reveal busy state
## while this window is open, exactly as for the stage.
## - Change_Fusion_CardSet pages (ten Change_Fusion_Card cells, the PageView
##   area): each result shows its client prefab Change_Card_A_<grade> with
##   its own picture and the card name (Text_Card_Name); the pity reward
##   comes last as in the existing reveal.
## - Individual taps turn cards over. Once the page has opened, the
##   full-screen Btn_Close advances or closes. The top Btn_Close closes.
## - 영웅 이상 results light up in their grade (source_main_card_grade_fx).
const GradeFx=preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
const Gacha=preload("res://scripts/ui/original_ui/source_main_card_gacha_window.gd")
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const ROOT="UI/Change/Change_Fusion_All.csb"
const CARD_SET="UI/Change/Change_Fusion_CardSet.csb"
const CARD="UI/Change/Change_Fusion_Card.csb"
const PER_PAGE: int=10
const PER_ROW: int=5
## Change_Fusion_CardSet's 1200x675 panel over the centred PageView.
const SET_ORIGIN=Vector2(-600.0,337.5)
var results: Array=[]
var category: String=""
var success: bool=false
var page: int=0
## Called once when the window closes (the HUD's reveal guard).
var on_closed: Callable=Callable()
var reveal_effect: Callable
var _revealed: Dictionary = {}
var _opening: Dictionary = {}
var _opening_all: bool = false
var _cells: Node2D
var _cell_out: Dictionary = {}

func required_members() -> Array[String]:
	var members: Array[String]=[ROOT,CARD_SET,CARD]
	for member: String in GradeFx.Page.GRADE_MEMBERS.values():members.append(member)
	return members

func _root_member() -> String:
	return ROOT

## `views`: the reveal's result cards (catalog record merged with the
## result: name, grade, ...); `done` runs when the window closes.
func open(parent: Node, views: Array, category_name: String, succeeded: bool, done: Callable=Callable(), effect: Callable=Callable()) -> Dictionary:
	if views.is_empty():return _fail("source_fusion_result_empty")
	results=views.duplicate(true)
	category=category_name
	success=succeeded
	page=0
	on_closed=done
	reveal_effect=effect
	_revealed.clear()
	_opening.clear()
	_opening_all=false
	return open_window(parent)

func pages() -> int:
	return maxi(1,ceili(float(results.size())/float(PER_PAGE)))

func is_revealed(index: int) -> bool:
	return _revealed.has(index)

func _page_revealed() -> bool:
	for index: int in range(page*PER_PAGE,mini(results.size(),(page+1)*PER_PAGE)):
		if not is_revealed(index):return false
	return true

func _stage() -> Dictionary:
	var result: Dictionary=super._stage()
	if is_open():_scene.z_index=Gacha.Z
	return result

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Btn_Close"]={"activate":Callable(self,"_next")}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["FullFrameType_A/Img_bg1"]={"touch_enabled":false}
	spec["PageView"]={"exclude":true}
	for name: String in ["Fx_Img_BG_Particle","Nd_ButtonSet_Collection","Nd_Btn_Change","Fx_Screen"]:spec[name]={"exclude":true}
	for child: String in ["Payment","Btn_Repeat","Btn_Retry","Btn_Auto","Btn_Auto_Stop","Btn_Fusion","Nd_Option","Label_Title"]:
		spec["Nd_ButtonSet/"+child]={"exclude":true}
	spec["Nd_ButtonSet/Btn_Open"]={"visible":not _page_revealed(),"activate":Callable(self,"_open_all")}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var start: int=page*PER_PAGE
	var shown: int=mini(PER_PAGE,results.size()-start)
	# The page's background touch belongs to the outer Btn_Close. The
	# authored CardSet panel holds the cards and does not swallow that tap.
	var spec: Dictionary={"Panel":{"touch_enabled":false}}
	for index: int in PER_PAGE:
		var cell: String="Panel/Card_%02d" % index
		if index>=shown:
			spec[cell]={"exclude":true}
			continue
		var card: Dictionary=results[start+index]
		var opened: bool=is_revealed(start+index)
		GradeFx.cell_spec(self,spec,cell+"/",str(card.get("grade","")),not opened)
		if not opened:
			spec.erase(cell+"/Fx_Glow")
			var outline: String=cell+"/Fx_Outline_Front"
			if spec.has(outline) and not spec[outline].get("exclude",false):
				spec[outline]["defer_until_shown"]=true
		var label: String=str(card.get("name",""))
		if card.get("pity_reward",false):label="보상 · "+label
		spec[cell+"/Text_Card_Name"]={"role":"source_text","text":label,"visible":opened}
		spec[cell+"/Btn_Card"]={"activate":Callable(self,"_card").bind(start+index)}
	var set_out: Dictionary={}
	var built: Dictionary=_scene_of(CARD_SET,spec,set_out)
	if not built.get("ok",false):return built
	var scene: Node2D=built.scene
	scene.position=SET_ORIGIN
	_center_cards(scene,set_out,shown)
	var pictures: int=0
	var lights: int=0
	var backs: int=0
	for index: int in shown:
		var card: Dictionary=results[start+index]
		var cell: String="Panel/Card_%02d" % index
		var grade: String=str(card.get("grade",""))
		if is_revealed(start+index):
			var face: Dictionary=GradeFx.prepare_face(self,scene,set_out,cell,card,false)
			if not face.get("ok",false):
				scene.free()
				return face
			if face.picture:pictures+=1
			if _reveal(scene,set_out,cell,grade):lights+=1
		else:
			GradeFx.set_visible(self,scene,set_out,cell+"/Panel",false)
			var nested: Node2D=GradeFx.project(self,scene,set_out,cell)
			if nested!=null and nested.play(Gacha.back_clip(category),false).get("ok",false):backs+=1
	var title: Node2D=GradeFx.cell_node(self,root,out,"Nd_Title")
	if title==null:
		root.add_child(scene)
	else:
		# Use the authored PageView's layer, between the backdrop and controls.
		var layer: Node2D=title.get_parent()
		scene.transform=layer.global_transform.affine_inverse()*root.global_transform*scene.transform
		layer.add_child(scene)
		layer.move_child(scene,title.get_index())
	_cells=scene
	_cell_out=set_out
	_opening.clear()
	_opening_all=false
	return {"ok":true,"page":page,"pages":pages(),"shown":shown,"backs":backs,"pictures":pictures,"lights":lights,"success":success}

func _reveal(scene: Node2D, out: Dictionary, cell: String, grade: String) -> bool:
	GradeFx.finish_reel(self,scene,out,cell)
	GradeFx.set_visible(self,scene,out,cell+"/Fx_Glow",true)
	GradeFx.set_visible(self,scene,out,cell+"/Fx_Glow/Card_Back",false)
	# The success discharge runs during the reel. Both outcomes get the
	# result-grade flash, name and outline when they settle.
	var lit: Dictionary = GradeFx.light(self,scene,out,cell,grade,false)
	if lit.get("lit", false): return true
	var nested: Node2D=GradeFx.project(self,scene,out,cell)
	if nested!=null:GradeFx.chain(nested,GradeFx.CELL_CLIP,"Fx_Cardname")
	return false

## Keep the authored spacing. Center partial rows in the same PageView;
## a single row uses its vertical center as well.
func _center_cards(scene: Node2D, out: Dictionary, count: int) -> void:
	for start: int in range(0,count,PER_ROW):
		var end: int=mini(start+PER_ROW,count)
		var first: Node2D=GradeFx.cell_node(self,scene,out,"Panel/Card_%02d" % start)
		var last: Node2D=GradeFx.cell_node(self,scene,out,"Panel/Card_%02d" % (end-1))
		if first==null or last==null:continue
		var dx: float=0.0 if end-start==PER_ROW else -SET_ORIGIN.x-(first.position.x+last.position.x)*0.5
		var dy: float=-SET_ORIGIN.y-first.position.y if count<=PER_ROW else 0.0
		for index: int in range(start,end):
			var card: Node2D=GradeFx.cell_node(self,scene,out,"Panel/Card_%02d" % index)
			if card!=null:card.position+=Vector2(dx,dy)

## --- Actions --------------------------------------------------------------------

func _card(index: int) -> Dictionary:
	if index<page*PER_PAGE or index>=mini(results.size(),(page+1)*PER_PAGE) or not is_instance_valid(_cells):return {"ok":false}
	if _opening.has(index) or is_revealed(index):return {"ok":true,"opened":false}
	var card: Dictionary=results[index]
	var cell: String="Panel/Card_%02d" % (index-page*PER_PAGE)
	var scene: Node2D=_cells
	var out: Dictionary=_cell_out
	var started: int=FRAME_HITCH.now()
	var face: Dictionary=GradeFx.prepare_face(self,scene,out,cell,card,false)
	FRAME_HITCH.detail("fusion.face_prepare",started)
	if not face.get("ok",false):
		if hud()!=null:hud().show_message("원본 결과 카드 표시 실패 · 다시 시도하세요")
		return face
	var settled: Callable=func() -> void:
		if not is_instance_valid(scene) or scene!=_cells:return
		_opening.erase(index)
		_revealed[index]=true
		_reveal(scene,out,cell,str(card.get("grade","")))
		if _page_revealed():GradeFx.set_visible(self,_scene,_out,"Nd_ButtonSet/Btn_Open",false)
	_opening[index]=true
	if _play_card_effect(reveal_effect,scene,out,cell+"/Panel",card,settled):
		GradeFx.start_reel(self,scene,out,cell)
	else:
		settled.call()
	return {"ok":true,"opened":true}

func _open_all() -> Dictionary:
	if not is_instance_valid(_cells):return {"ok":false}
	if not _opening_all:
		var first: int=page*PER_PAGE
		var end: int=mini(results.size(),first+PER_PAGE)
		_opening_all=true
		_open_all_on_frames.call_deferred(_cells.get_instance_id(),first,end)
	return {"ok":true}

func _open_all_on_frames(scene_id: int, first: int, end: int) -> void:
	var tree: SceneTree=Engine.get_main_loop()
	for index: int in range(first,end):
		await tree.process_frame
		if not is_instance_valid(_cells) or _cells.get_instance_id()!=scene_id or _cells.is_queued_for_deletion():return
		_card(index)
	_opening_all=false

## The full-screen tap: the next page, then close.
func _next() -> Dictionary:
	if not _page_revealed():return {"ok":true,"waiting":true}
	if page+1<pages():
		var previous: Node2D=_cells
		page+=1
		# The outer window and its Next/Close wiring stay mounted.
		var previous_trees: Variant=_stage_trees
		_stage_trees={}
		var filled: Dictionary=_fill(_scene,_out)
		_stage_trees=previous_trees
		if not filled.get("ok",false):
			page-=1
			return filled
		if is_instance_valid(previous):
			previous.hide()
			previous.queue_free()
		GradeFx.set_visible(self,_scene,_out,"Nd_ButtonSet/Btn_Open",true)
		last_result={"ok":true,"handled":true,"member":ROOT,"filled":filled}
		return last_result
	return _close_requested()

func close() -> void:
	super.close()
	_cells=null
	_cell_out={}
	_opening.clear()
	_opening_all=false
	var done: Callable=on_closed
	on_closed=Callable()
	reveal_effect=Callable()
	if done.is_valid():done.call()

## Only this window closes (the card window under it stays).
func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}
