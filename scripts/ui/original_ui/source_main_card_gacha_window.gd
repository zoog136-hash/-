extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 카드 뽑기 result window (BMShop/BM_Gacha) for cards the
## existing rule already granted and saved: an opened card box or draw pack
## (renewal_hud.present_card_reveal without fusion, only when the UI pack
## has the members; otherwise the existing CardRevealStage). The HUD keeps
## its reveal busy state while this window is open.
## - One card: Nd_CardSet_One; up to five: Nd_CardSet_Five; more: Nd_CardSet
##   (ten cells a page; the full-screen tap turns the page). Each result is a
##   Change_Fusion_Card cell with its client prefab Change_Card_A_<grade>,
##   its own picture and name; 영웅 이상 light up in their grade
##   (source_main_card_grade_fx).
## - Label_Title: the opened box's name.
## Left out (no TWILIGHT feature): the roulette and the set clips (the
## results are shown open), 재 구매 / 재사용 / 자동 사용 / 합성하러 가기, the
## bonus slot, the collection notice, 카드교체 바로가기 and the skill card sets.
const Page=preload("res://scripts/ui/original_ui/source_main_change_page.gd")
const Presentation=preload("res://scripts/ui/source_card_presentation.gd")
const GradeFx=preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
const ROOT="UI/BMShop/BM_Gacha.csb"
const CARD="UI/Change/Change_Fusion_Card.csb"
const PER_PAGE: int=10
## Set node, cells used, the set's own bonus cell left out.
const SETS: Array=[["Nd_CardSet_One",1,""],["Nd_CardSet_Five",5,"Card_05"],["Nd_CardSet",10,"Card_10"]]
var results: Array=[]
var category: String=""
var title: String=""
var page: int=0
var on_closed: Callable=Callable()

func required_members() -> Array[String]:
	var members: Array[String]=[ROOT,CARD]
	for member: String in Page.GRADE_MEMBERS.values():members.append(member)
	return members

func _root_member() -> String:
	return ROOT

## `views`: the granted cards (catalog record merged with the result: name,
## grade, ...); `done` runs when the window closes.
func open(parent: Node, views: Array, category_name: String, box_title: String="", done: Callable=Callable()) -> Dictionary:
	if views.is_empty():return _fail("source_card_gacha_empty")
	results=views.duplicate(true)
	category=category_name
	title=box_title
	page=0
	on_closed=done
	return open_window(parent)

func pages() -> int:
	return maxi(1,ceili(float(results.size())/float(PER_PAGE)))

## [set node, cells, bonus cell] for the current page.
func _card_set() -> Array:
	var count: int=mini(PER_PAGE,results.size()-page*PER_PAGE)
	for entry: Array in SETS:
		if count<=int(entry[1]):return entry
	return SETS[SETS.size()-1]

func _spec() -> Dictionary:
	var spec: Dictionary={}
	spec["Btn_Close"]={"activate":Callable(self,"_next")}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in ["Payment","Btn_Repeat","Btn_Retry","Btn_Auto","Btn_Auto_Stop","Btn_Open","Btn_Fusion","Nd_Option"]:spec["Nd_ButtonSet/"+name]={"exclude":true}
	if title.is_empty():spec["Nd_ButtonSet/Label_Title"]={"exclude":true}
	else:spec["Nd_ButtonSet/Label_Title"]={"role":"source_text","text":title}
	for name: String in ["FullFrameType_A/Fx_Img_BG_Particle","Nd_ButtonSet_Collection","Nd_Btn_Change","Fx_Screen","Nd_SkillCardSet","Nd_SkillCardSet_One","Nd_SkillCardSet_Five"]:spec[name]={"exclude":true}
	var chosen: Array=_card_set()
	var start: int=page*PER_PAGE
	for entry: Array in SETS:
		var node: String=str(entry[0])
		if entry!=chosen:
			spec[node]={"exclude":true}
			continue
		spec[node]={"visible":true}
		for extra: String in ["Nd_Bonus","Fx_Card_Recall"]:
			if node!="Nd_CardSet_One":spec[node+"/"+extra]={"exclude":true}
		if not str(entry[2]).is_empty():spec[node+"/"+str(entry[2])]={"exclude":true}
		for index: int in range(int(entry[1])):
			var key: String="%s/Card_%02d/" % [node,index]
			if start+index>=results.size():
				spec[key.trim_suffix("/")]={"exclude":true}
				continue
			var card: Dictionary=results[start+index]
			GradeFx.cell_spec(self,spec,key,str(card.get("grade","")))
			spec[key+"Text_Card_Name"]={"role":"source_text","text":str(card.get("name",""))}
			spec[key+"Btn_Card"]={"activate":Callable(self,"_card").bind(start+index)}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var chosen: Array=_card_set()
	var node: String=str(chosen[0])
	var start: int=page*PER_PAGE
	var pictures: int=0
	var lights: int=0
	var shown: int=0
	for index: int in range(mini(int(chosen[1]),results.size()-start)):
		var card: Dictionary=results[start+index]
		var cell: String="%s/Card_%02d" % [node,index]
		shown+=1
		var lit: Dictionary=GradeFx.light(self,root,out,cell,str(card.get("grade","")))
		if lit.get("lit",false):lights+=1
		else:
			# Text_Card_Name stays transparent until the client's Fx_Cardname clip.
			var nested: Node2D=GradeFx.project(self,root,out,cell)
			if nested!=null:nested.play("Fx_Cardname",false)
		var grade: String=str(card.get("grade",""))
		var located: Dictionary=_locate(root,out,cell+"/Panel")
		var host: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
		if not host is Node2D or not Page.GRADE_MEMBERS.has(grade):continue
		var prefab_out: Dictionary={}
		var prefab: Dictionary=_scene_of(str(Page.GRADE_MEMBERS[grade]),_prefab_spec(),prefab_out)
		if not prefab.get("ok",false):return prefab
		(host as Node2D).add_child(prefab.scene)
		if _prefab_picture(prefab.scene,prefab_out,card):pictures+=1
	return {"ok":true,"set":node,"page":page,"pages":pages(),"shown":shown,"pictures":pictures,"lights":lights}

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
	_message("%s%s · %s" % ["뽑기 보상 · " if bool(card.get("pity_reward",false)) else "",str(card.get("grade","")),str(card.get("name",""))])
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

func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}
