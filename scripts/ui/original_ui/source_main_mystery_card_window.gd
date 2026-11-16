extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The original 523 미스터리 카드 합성 window (MysteryCardScene /
## MysteryCard_All) over the existing mystery card item use
## (world.monsterbook523_runtime.item_use: its spec names the deck and the
## labelled 영웅 / 희귀 weights, use() rolls, awards the card and saves).
## - Title and notice: 변신 / 마법인형 (성물 reuses the 변신 texts with its name).
## - The four Recovery_Card grade cards (희귀 / 영웅 / 전설 / 신화): TWILIGHT's
##   mystery card has one draw, 영웅 with the configured weight and else
##   희귀, so only the 영웅 card is 선택 가능 (TWILIGHT 근사: a failed 영웅
##   challenge gives a 희귀 card, as the original notice says); a tap uses one
##   card through the existing use().
## - 확률 보기: the item use's own label (the configured weights and pool).
## Left empty (no TWILIGHT feature): the 희귀 / 전설 / 신화 challenges
## (선택 불가) and the card select effect.
const ROOT="UI/MysteryCardScene.csb"
const PANEL="UI/MysteryCard/MysteryCard_All.csb"
const GRADE_CARD="UI/Recovery/Recovery_Card.csb"
const P="MysteryCard_All_Layout/"
## MysteryCard_All grade card ProjectNodes -> the Recovery_Card node they show.
const BUTTONS={"Btn_Unique":"Nd_Unique","Btn_Legend":"Nd_Legend","Btn_Epic":"Nd__Epic","Btn_Mythical":"Nd_Myth"}
## Recovery_Card grade node -> original GradeID (희귀 3, 영웅 4, 전설 5, 신화 32).
const GRADE_NODES={"Nd_Unique":3,"Nd_Legend":4,"Nd__Epic":5,"Nd_Myth":32}
const GRADE_NAMES={3:"희귀",4:"영웅",5:"전설",32:"신화"}
const CARD_IMAGES={"변신":"Img_Card_Change","마법인형":"Img_Card_Doll","성물":"Img_Card_HolyStuff"}
## The one challenge TWILIGHT's mystery draw has (TWILIGHT 근사).
const CHALLENGE_GRADE: int=4
var item_name: String=""
var last_use: Dictionary={}

func required_members() -> Array[String]:
	return [ROOT,PANEL,GRADE_CARD]

func _root_member() -> String:
	return ROOT

## MysteryCardScene is laid out on the 1200x675 design frame.
func _root_position() -> Vector2:
	return Vector2.ZERO

static func _item_use(owner: Object) -> Object:
	var live: Variant=owner.get("monsterbook523_runtime") if owner!=null else null
	var use: Variant=live.get("item_use") if live is Object else null
	return use if use is Object else null

## The mystery spec of owned item `name` ({} when it is not a usable mystery card).
static func mystery_action(owner: Object, name: String) -> Dictionary:
	var use: Object=_item_use(owner)
	var live: Variant=owner.get("monsterbook523_runtime") if owner!=null else null
	if use==null or not live is Object or live.get("catalog")==null:return {}
	var record: Variant=live.catalog.export_state().get("source_items",{}).get(name,{})
	if not record is Dictionary or (record as Dictionary).is_empty():return {}
	var action: Dictionary=use.spec(record)
	return action if str(action.get("kind",""))=="mystery" else {}

static func owned_count(owner: Object, name: String) -> int:
	var inventory: Variant=owner.get("inventory") if owner!=null else null
	return int(inventory.get(name,0)) if inventory is Dictionary else 0

func open(parent: Node, name: String) -> Dictionary:
	if mystery_action(world(),name).is_empty():return _fail("source_mystery_card_item_unavailable")
	item_name=name
	last_use={}
	return open_window(parent)

func _spec() -> Dictionary:
	var spec: Dictionary={}
	var action: Dictionary=mystery_action(world(),item_name)
	var category: String=str(action.get("category","변신"))
	var doll: bool=category=="마법인형"
	spec[P+"Nd_TopMenu/Btn_Close"]={"activate":Callable(self,"_close_requested")}
	spec[P+"Nd_Title/Text_Title"]={"visible":not doll,"role":"source_text","text":"미스터리 카드 %s 합성 · %d장" % [category,owned_count(world(),item_name)]}
	spec[P+"Nd_Title/Text_Title_MagicDoll"]={"visible":doll,"role":"source_text","text":"미스터리 카드 마법인형 합성 · %d장" % owned_count(world(),item_name)}
	spec[P+"Label_Notice"]={"visible":not doll,"role":"source_text","text":"※ 합성 실패 시 도전 하위 등급의 %s 중 1종을 획득합니다." % category}
	spec[P+"Label_Notice_MagicDoll"]={"visible":doll}
	for button: String in BUTTONS:
		var shown: String=BUTTONS[button]
		var id: int=int(GRADE_NODES[shown])
		var selectable: bool=id==CHALLENGE_GRADE
		var p: String=P+button+"/"
		spec[p+"Btn_Card"]={"activate":Callable(self,"_challenge").bind(id)}
		spec[p+"Btn_Card/Fx_CardSelect"]={"exclude":true}
		spec[p+"Btn_Probability"]={"activate":Callable(self,"_probability").bind(id)}
		for node: String in GRADE_NODES:
			if node!=shown:spec[p+"Btn_Card/"+node]={"exclude":true}
		spec[p+"Btn_Card/"+shown]={"visible":true}
		spec[p+"Btn_Card/"+shown+"/Label_Grade"]={"role":"source_text","text":"%s %s" % [GRADE_NAMES[id],category]}
		for name: String in CARD_IMAGES:spec[p+"Btn_Card/"+shown+"/"+str(CARD_IMAGES[name])]={"visible":name==category}
		spec[p+"Btn_Card/Nd_Label/Label_Select"]={"visible":selectable}
		spec[p+"Btn_Card/Nd_Label/Label_Disabled"]={"visible":not selectable}
	return spec

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	# Recovery_Card's own state clips: Normal (선택 가능) / Disabled (선택 불가).
	var states: int=0
	for button: String in BUTTONS:
		var located: Dictionary=_locate(root,out,button)
		var node: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
		var nested: Variant=(node as Node).get_meta("source_project_player") if node is Node and (node as Node).has_meta("source_project_player") else null
		if nested is Node2D and nested.play("Normal" if int(GRADE_NODES[BUTTONS[button]])==CHALLENGE_GRADE else "Disabled",false).get("ok",false):states+=1
	return {"states":states,"ok":true,"item":item_name,"count":owned_count(world(),item_name),"challenge":CHALLENGE_GRADE}

## Uses one mystery card through the existing item use (a 영웅 challenge).
func _challenge(grade_id: int) -> Dictionary:
	if grade_id!=CHALLENGE_GRADE:
		_message("%s 등급은 선택할 수 없습니다" % str(GRADE_NAMES.get(grade_id,"")))
		return {"ok":false,"handled":true,"code":"source_mystery_card_grade_unavailable"}
	var use: Object=_item_use(world())
	if use==null:return _fail("source_mystery_card_item_use_unavailable")
	last_use=use.use(item_name)
	if not last_use.get("ok",false):
		_message(str(last_use.get("message","처리하지 못했습니다")))
		return {"ok":false,"handled":true,"use":last_use}
	var card: Dictionary={}
	for entry: Variant in last_use.get("results",[]):
		if entry is Dictionary and str(entry.get("kind",""))=="card":card=entry
	var won: bool=str(card.get("grade",""))==GRADE_NAMES[CHALLENGE_GRADE]
	_message(("영웅 합성 성공 · %s" if won else "영웅 합성 실패 · 희귀 %s 획득") % str(card.get("name","")))
	if owned_count(world(),item_name)<=0:
		_close_requested()
		return {"ok":true,"handled":true,"use":last_use,"won":won,"closed":true}
	var staged: Dictionary=_stage()
	staged["use"]=last_use
	staged["won"]=won
	return staged

func _probability(grade_id: int) -> Dictionary:
	var action: Dictionary=mystery_action(world(),item_name)
	_message(str(action.get("label","")) if grade_id==CHALLENGE_GRADE else "%s 등급은 선택할 수 없습니다" % str(GRADE_NAMES.get(grade_id,"")))
	return {"ok":true,"handled":true}
