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
## Left out (no TWILIGHT feature): the roulette, 모두 열기
## (the results are shown open), the collection notice and 카드교체 바로가기.
const Page=preload("res://scripts/ui/original_ui/source_main_change_page.gd")
const Presentation=preload("res://scripts/ui/source_card_presentation.gd")
const GradeFx=preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
const ROOT="UI/Change/Change_Fusion_All.csb"
const CARD_SET="UI/Change/Change_Fusion_CardSet.csb"
const CARD="UI/Change/Change_Fusion_Card.csb"
const PER_PAGE: int=10
## Change_Fusion_CardSet's 1200x675 panel over the centred PageView.
const SET_ORIGIN=Vector2(-600.0,337.5)
var results: Array=[]
var category: String=""
var success: bool=false
var page: int=0
## Called once when the window closes (the HUD's reveal guard).
var on_closed: Callable=Callable()

func required_members() -> Array[String]:
	var members: Array[String]=[ROOT,CARD_SET,CARD]
	for member: String in Page.GRADE_MEMBERS.values():members.append(member)
	return members

func _root_member() -> String:
	return ROOT

## `views`: the reveal's result cards (catalog record merged with the
## result: name, grade, ...); `done` runs when the window closes.
func open(parent: Node, views: Array, category_name: String, succeeded: bool, done: Callable=Callable()) -> Dictionary:
	if views.is_empty():return _fail("source_fusion_result_empty")
	results=views.duplicate(true)
	category=category_name
	success=succeeded
	page=0
	on_closed=done
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
	var spec: Dictionary={}
	for index: int in range(PER_PAGE):
		var key: String="Panel/Card_%02d/" % index
		if start+index>=results.size():
			spec["Panel/Card_%02d" % index]={"exclude":true}
			continue
		var card: Dictionary=results[start+index]
		GradeFx.cell_spec(self,spec,key,str(card.get("grade","")))
		spec[key+"Text_Card_Name"]={"role":"source_text","text":str(card.get("name",""))}
		spec[key+"Btn_Card"]={"activate":Callable(self,"_card").bind(start+index)}
	var set_out: Dictionary={}
	var built: Dictionary=_scene_of(CARD_SET,spec,set_out)
	if not built.get("ok",false):return built
	var scene: Node2D=built.scene
	scene.position=SET_ORIGIN
	root.add_child(scene)
	var pictures: int=0
	var shown: int=0
	var lights: int=0
	for index: int in range(mini(PER_PAGE,results.size()-start)):
		var card: Dictionary=results[start+index]
		# Text_Card_Name stays transparent until the client's Fx_Cardname clip;
		# 영웅 이상 first light up in their grade (source_main_card_grade_fx).
		var lit: Dictionary=GradeFx.light(self,scene,set_out,"Panel/Card_%02d" % index,str(card.get("grade","")))
		if lit.get("lit",false):lights+=1
		else:
			var nested: Node2D=_project(scene,set_out,"Panel/Card_%02d" % index)
			if nested!=null:nested.play("Fx_Cardname",false)
		var located: Dictionary=_locate(scene,set_out,"Panel/Card_%02d/Panel" % index)
		var cell: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
		shown+=1
		var grade: String=str(card.get("grade",""))
		if not cell is Node2D or not Page.GRADE_MEMBERS.has(grade):continue
		var prefab_out: Dictionary={}
		var prefab: Dictionary=_scene_of(str(Page.GRADE_MEMBERS[grade]),_prefab_spec(),prefab_out)
		if not prefab.get("ok",false):return prefab
		(cell as Node2D).add_child(prefab.scene)
		if _prefab_picture(prefab.scene,prefab_out,card):pictures+=1
	return {"ok":true,"page":page,"pages":pages(),"shown":shown,"pictures":pictures,"lights":lights,"success":success}

## The nested player of the ProjectNode at `suffix`.
func _project(root: Node2D, out: Dictionary, suffix: String) -> Node2D:
	var located: Dictionary=_locate(root,out,suffix)
	if not located.get("ok",false):return null
	var node: Node=located.player.source_nodes.get(located.offset)
	var nested: Variant=node.get_meta("source_project_player") if node!=null and node.has_meta("source_project_player") else null
	return nested if nested is Node2D else null

static func _prefab_spec() -> Dictionary:
	return {"Panel_Root":{"role":"consume"},"Panel_Root/CB_Check":{"exclude":true},"Nd_Character/CardSample":{"role":"source_asset_slot","visible":false},
		"Nd_Character/CardSample_A":{"exclude":true},"Panel_Root/Panel_Fx":{"exclude":true},"Panel_Root/Sp_Lock":{"exclude":true},"Panel_Root/Nd_Attribute":{"exclude":true}}

func _prefab_picture(scene: Node2D, out: Dictionary, raw: Dictionary) -> bool:
	var card: Dictionary=_locate(scene,out,"Nd_Character/CardSample")
	if not card.get("ok",false):return false
	var detail: Dictionary=Presentation.detail(raw,true,false)
	if detail.get("status","")!="original" or not detail.get("texture") is Texture2D:return false
	return _show_picture(card.player,card.offset,{"ok":true,"texture":detail.texture,"provenance":detail.get("provenance",{}).duplicate(true),"role":str(detail.get("role",""))})

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
	if done.is_valid():done.call()

## Only this window closes (the card window under it stays).
func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}
