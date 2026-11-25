extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 카드 뽑기 result window (BMShop/BM_Gacha) for cards the
## existing rule already granted and saved: an opened card box or draw pack
## from the bag, a shop/cash-shop draw or a card ticket
## (renewal_hud.present_card_reveal without fusion, only when the UI pack
## has the members; otherwise the existing CardRevealStage). The HUD keeps
## its reveal busy state while this window is open.
## - One card: Nd_CardSet_One; up to five: Nd_CardSet_Five; more: Nd_CardSet
##   (ten cells a page). Each result is a Change_Fusion_Card cell with its
##   client prefab Change_Card_A_<grade>, its own picture and name.
## - The set's own clip deals the cells in (CardSet_One / CardSet_Five /
##   Fx_Start). Its cells name the inner clip "Fx_Start", which the card
##   scene does not list: the client picks the category clip, so the cell
##   plays Fx_Start_Change / Fx_Start_Doll / Fx_Start_HolyStuff (the card
##   back of 변신 / 마법인형 / 성물, Img_Card_Back_* of Atlas_Recovery_Card).
##   The face (Panel) stays hidden until the card is opened.
## - A tap on a card opens it: 영웅 이상 play the cell's Fx_Start_Active
##   with their grade light (source_main_card_grade_fx), the others the name
##   clip Fx_Cardname (Card_Back is off from frame 184 on). 모두 확인
##   (Nd_ButtonSet/Btn_Open) and the full-screen tap open every card of the
##   page; once all are open the full-screen tap turns the page, then closes.
##   Which clip runs for which grade and the full-screen tap opening the rest
##   are TWILIGHT 근사 (the client code is not in the data).
## - Label_Title: the opened box's name.
## Left out (no TWILIGHT feature): the roulette, 재 구매 / 재사용 / 자동 사용 /
## 합성하러 가기, the bonus slot, the collection notice, 카드교체 바로가기 and
## the skill card sets.
const Page=preload("res://scripts/ui/original_ui/source_main_change_page.gd")
const GradeFx=preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
const ROOT="UI/BMShop/BM_Gacha.csb"
const CARD="UI/Change/Change_Fusion_Card.csb"
const PER_PAGE: int=10
## Set node, cells used, the set's own bonus cell left out.
const SETS: Array=[["Nd_CardSet_One",1,""],["Nd_CardSet_Five",5,"Card_05"],["Nd_CardSet",10,"Card_10"]]
## The set's dealing clip (BM_Gacha animationList).
const DEAL={"Nd_CardSet_One":"CardSet_One","Nd_CardSet_Five":"CardSet_Five","Nd_CardSet":"Fx_Start"}
## The card back clip of each category (Change_Fusion_Card animationList).
const BACK={"변신":"Fx_Start_Change","마법인형":"Fx_Start_Doll","성물":"Fx_Start_HolyStuff"}
## The inner clip name the sets give their cells.
const SET_CELL_CLIP="Fx_Start"
const NAME_CLIP="Fx_Cardname"
## Above the other original windows (150..160) so a bag or shop rebuilt
## after the grant cannot cover it; the system message (180) is held by the
## HUD while this window is open.
const Z: int=170
var results: Array=[]
## Per result: the card has been opened (its face shown).
var opened: Array[bool]=[]
var category: String=""
var title: String=""
var page: int=0
var on_closed: Callable=Callable()
var reveal_effect: Callable

func required_members() -> Array[String]:
	var members: Array[String]=[ROOT,CARD]
	for member: String in Page.GRADE_MEMBERS.values():members.append(member)
	return members

func _root_member() -> String:
	return ROOT

## `views`: the granted cards (catalog record merged with the result: name,
## grade, ...); `done` runs when the window closes.
func open(parent: Node, views: Array, category_name: String, box_title: String="", done: Callable=Callable(), effect: Callable=Callable()) -> Dictionary:
	if views.is_empty():return _fail("source_card_gacha_empty")
	results=views.duplicate(true)
	category=category_name
	title=box_title
	page=0
	on_closed=done
	reveal_effect=effect
	opened.clear()
	opened.resize(results.size())
	opened.fill(false)
	return open_window(parent)

func _stage() -> Dictionary:
	var result: Dictionary=super._stage()
	if is_open():_scene.z_index=Z
	return result

func is_opened(index: int) -> bool:
	return index>=0 and index<opened.size() and opened[index]

func _size_opened() -> void:
	if opened.size()!=results.size():
		opened.resize(results.size())

## True when every card of the current page is open.
func page_open() -> bool:
	for index: int in range(page*PER_PAGE,mini(results.size(),(page+1)*PER_PAGE)):
		if not is_opened(index):return false
	return true

static func back_clip(card_category: String) -> String:
	return str(BACK.get(card_category,BACK["변신"]))

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
	if page_open():spec["Nd_ButtonSet/Btn_Open"]={"exclude":true}
	else:spec["Nd_ButtonSet/Btn_Open"]={"visible":true,"activate":Callable(self,"open_all")}
	spec["Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in ["Payment","Btn_Repeat","Btn_Retry","Btn_Auto","Btn_Auto_Stop","Btn_Fusion","Nd_Option"]:spec["Nd_ButtonSet/"+name]={"exclude":true}
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
			var grade: String=str(card.get("grade",""))
			var opened_card: bool=is_opened(start+index)
			GradeFx.cell_spec(self,spec,key,grade,not opened_card)
			if not opened_card:
				# Fx_Glow holds Card_Back; the outline lights only once open.
				spec.erase(key+"Fx_Glow")
			spec[key+"Text_Card_Name"]={"role":"source_text","text":str(card.get("name","")),"visible":opened_card}
			spec[key+"Btn_Card"]={"activate":Callable(self,"open_card").bind(start+index)}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var chosen: Array=_card_set()
	var node: String=str(chosen[0])
	var start: int=page*PER_PAGE
	var pictures: int=0
	var lights: int=0
	var shown: int=0
	var backs: int=0
	for index: int in range(mini(int(chosen[1]),results.size()-start)):
		var card: Dictionary=results[start+index]
		var cell: String="%s/Card_%02d" % [node,index]
		shown+=1
		var face: Dictionary=GradeFx.prepare_face(self,root,out,cell,card,is_opened(start+index))
		if not face.get("ok",false):return face
		if face.picture:pictures+=1
		if is_opened(start+index):
			if _reveal(root,out,cell,card).get("lit",false):lights+=1
		elif _show_back(root,out,cell,str(card.get("category",category))):backs+=1
	# The set deals its cells in; each cell then holds its card back.
	var dealing: bool=backs>0 and root.play(str(DEAL[node]),false).get("ok",false)
	return {"ok":true,"set":node,"page":page,"pages":pages(),"shown":shown,"pictures":pictures,"lights":lights,"backs":backs,"dealing":dealing}

## Readies the closed cell at `cell`: the face hidden, the set's "Fx_Start"
## resolved to the category's card back clip.
func _show_back(root: Node2D, out: Dictionary, cell: String, card_category: String) -> bool:
	_set_visible(root,out,cell+"/Panel",false)
	var nested: Node2D=GradeFx.project(self,root,out,cell)
	if nested==null:return false
	var clip: String=back_clip(card_category)
	var list: Array=nested.source_tree.get("animationList",[])
	var found: Dictionary={}
	for entry: Dictionary in list:
		if entry.name==SET_CELL_CLIP:return true
		if entry.name==clip:found=entry
	if found.is_empty():return false
	var alias: Dictionary=found.duplicate(true)
	alias["name"]=SET_CELL_CLIP
	alias["twilight_alias_of"]=clip
	list.append(alias)
	return true

## Shows the face of the cell at `cell`: {lit}.
func _reveal(root: Node2D, out: Dictionary, cell: String, card: Dictionary) -> Dictionary:
	GradeFx.finish_reel(self,root,out,cell)
	GradeFx.set_visible(self,root,out,cell+"/Fx_Glow",true)
	var grade: String=str(card.get("grade",""))
	var lit: Dictionary=GradeFx.light(self,root,out,cell,grade,not reveal_effect.is_valid())
	if not lit.get("lit",false):
		# Text_Card_Name stays transparent until the client's Fx_Cardname
		# clip; Card_Back is off from frame 184 on.
		var nested: Node2D=GradeFx.project(self,root,out,cell)
		if nested!=null:nested.play(NAME_CLIP,false)
	return lit

func _set_visible(root: Node2D, out: Dictionary, suffix: String, value: bool) -> void:
	var located: Dictionary=_locate(root,out,suffix)
	if not located.get("ok",false):return
	var node: Variant=located.player.source_nodes.get(located.offset)
	if node is CanvasItem:(node as CanvasItem).visible=value

## --- Actions --------------------------------------------------------------------

## A tap on a card: opens it once (an open card does nothing).
func open_card(index: int) -> Dictionary:
	if index<page*PER_PAGE or index>=mini(results.size(),(page+1)*PER_PAGE):return {"ok":false}
	if is_opened(index):return {"ok":true,"opened":false}
	_size_opened()
	_finish_deal()
	opened[index]=true
	var lit: Dictionary={}
	if is_open():
		var cell: String="%s/Card_%02d" % [str(_card_set()[0]),index-page*PER_PAGE]
		var card: Dictionary = results[index]
		var settled: Callable = _reveal.bind(_scene, _out, cell, card)
		if _play_card_effect(reveal_effect, _scene, _out, cell + "/Panel", card, settled):
			_start_reel(cell)
			lit = {"lit": GradeFx.available(self, str(card.get("grade", "")))}
		else:
			lit = settled.call()
	if page_open():_set_visible(_scene,_out,"Nd_ButtonSet/Btn_Open",false)
	return {"ok":true,"opened":true,"lit":bool(lit.get("lit",false))}

func _start_reel(cell: String) -> void:
	var nested: Node2D=GradeFx.project(self,_scene,_out,cell)
	if nested!=null:nested.stop()
	var back: Node2D=GradeFx.cell_node(self,_scene,_out,cell+"/Fx_Glow/Card_Back")
	if back!=null and back.has_meta("source_sprite"):
		var sprite:=back.get_meta("source_sprite") as Sprite2D
		var panel: Node2D=GradeFx.cell_node(self,_scene,_out,cell+"/Panel")
		var reel: Node=panel.get_node_or_null("SourceContentOrigin/CardRevealEffect") if panel!=null else null
		if sprite!=null and sprite.texture!=null and reel!=null and reel.has_method("set_native_card_back"):
			reel.set_native_card_back(sprite.texture)
	GradeFx.set_visible(self,_scene,_out,cell+"/Fx_Glow",false)

## 모두 확인: opens every closed card of the page.
func open_all() -> Dictionary:
	var count: int=0
	var lit: int=0
	for index: int in range(page*PER_PAGE,mini(results.size(),(page+1)*PER_PAGE)):
		var result: Dictionary=open_card(index)
		if result.get("opened",false):count+=1
		if result.get("lit",false):lit+=1
	return {"ok":true,"opened":count,"lit":lit}

## Ends the set's dealing clip at its last frame, so every cell has entered
## its card back before one is opened (a later cell entry would close it).
func _finish_deal() -> void:
	if not is_open() or not _scene.has_method("playback_status"):return
	var status: Dictionary=_scene.playback_status()
	if not bool(status.get("playing",false)):return
	for clip: Dictionary in _scene.source_tree.get("animationList",[]):
		if clip.name==str(status.get("clip","")):
			_scene.seek_frame(float(clip.endIndex))
			break
	_scene.stop()

## The full-screen tap: opens the page's closed cards first, then the next
## page, then close.
func _next() -> Dictionary:
	if not page_open():return open_all()
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

func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true}
