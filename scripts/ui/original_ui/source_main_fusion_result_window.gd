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
## - The full-screen Btn_Close turns to the next page, then closes; the top
##   Btn_Close closes.
## - 영웅 이상 results light up in their grade (source_main_card_grade_fx).
## Left out (no TWILIGHT feature): 모두 열기
## (the results are shown open), the collection notice and 카드교체 바로가기.
const GradeFx=preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
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
var _animated_pages: Dictionary = {}

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
	_animated_pages.clear()
	return open_window(parent)

func pages() -> int:
	return maxi(1,ceili(float(results.size())/float(PER_PAGE)))

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Btn_Close"]={"activate":Callable(self,"_next")}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec["PageView"]={"exclude":true}
	for name: String in ["Fx_Img_BG_Particle","Nd_ButtonSet","Nd_ButtonSet_Collection","Nd_Btn_Change","Fx_Screen"]:spec[name]={"exclude":true}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var start: int=page*PER_PAGE
	var shown: int=mini(PER_PAGE,results.size()-start)
	var animate: bool=reveal_effect.is_valid() and not _animated_pages.has(page)
	var spec: Dictionary={}
	for index: int in PER_PAGE:
		var cell: String="Panel/Card_%02d" % index
		if index>=shown:
			spec[cell]={"exclude":true}
			continue
		var card: Dictionary=results[start+index]
		GradeFx.cell_spec(self,spec,cell+"/",str(card.get("grade","")),animate)
		spec[cell+"/Text_Card_Name"]={"role":"source_text","text":str(card.get("name","")),"visible":not animate}
		spec[cell+"/Btn_Card"]={"activate":Callable(self,"_card").bind(start+index)}
	var set_out: Dictionary={}
	var built: Dictionary=_scene_of(CARD_SET,spec,set_out)
	if not built.get("ok",false):return built
	var scene: Node2D=built.scene
	scene.position=SET_ORIGIN
	root.add_child(scene)
	_center_cards(scene,set_out,shown)
	var pictures: int=0
	var lights: int=0
	for index: int in shown:
		var card: Dictionary=results[start+index]
		var cell: String="Panel/Card_%02d" % index
		var grade: String=str(card.get("grade",""))
		var face: Dictionary=GradeFx.prepare_face(self,scene,set_out,cell,card,false)
		if not face.get("ok",false):return face
		if face.picture:pictures+=1
		var settled: Callable=_reveal.bind(scene,set_out,cell,grade)
		if animate and _play_card_effect(reveal_effect,scene,set_out,cell+"/Panel",card,settled):
			GradeFx.set_visible(self,scene,set_out,cell+"/Fx_Glow",false)
			if GradeFx.available(self,grade):lights+=1
		elif bool(settled.call()):lights+=1
	if animate: _animated_pages[page] = true
	return {"ok":true,"page":page,"pages":pages(),"shown":shown,"pictures":pictures,"lights":lights,"success":success}

func _reveal(scene: Node2D, out: Dictionary, cell: String, grade: String) -> bool:
	GradeFx.finish_reel(self,scene,out,cell)
	GradeFx.set_visible(self,scene,out,cell+"/Fx_Glow",true)
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
	if index<0 or index>=results.size():return {"ok":false}
	var card: Dictionary=results[index]
	_message("%s%s · %s" % ["합성 시도 보상 · " if bool(card.get("pity_reward",false)) else "",str(card.get("grade","")),str(card.get("name",""))])
	return {"ok":true}

## The full-screen tap: the next page, then close.
func _next() -> Dictionary:
	if page+1<pages():
		page+=1
		return _stage()
	return _close_requested()

func close() -> void:
	super.close()
	var done: Callable=on_closed
	on_closed=Callable()
	reveal_effect=Callable()
	if done.is_valid():done.call()

## Only this window closes (the card window under it stays).
func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}
