extends RefCounted
## The original 523 상세 능력치 window (CharacterInfo_StatInfo_Detail): STR /
## DEX / CON / INT / WIS cards on the left, the other statistics (ETC) on the
## right, one CharacterInfo_StatInfo_Detail_List card per group with one
## CharacterInfo_StatInfo_Detail_Text line per statistic. Groups, labels and
## values are the existing status sheet's (status_detail_sheet /
## renewal_status over hud.character_state).
## Left inert or empty (no rule here): 즐겨찾기 (bookmark stars and the
## bookmark filter), the stat tooltips.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const Sheet=preload("res://scripts/ui/status_detail_sheet.gd")
const Status=preload("res://scripts/ui/renewal_status.gd")
const ROOT="UI/FloatingUi/CharacterInfo_StatInfo_Detail.csb"
const CARD="UI/FloatingUi/CharacterInfo_StatInfo_Detail_List.csb"
const LINE="UI/FloatingUi/CharacterInfo_StatInfo_Detail_Text.csb"
const REQUIRED: Array[String]=[ROOT,CARD,LINE]
## CharacterInfo_StatInfo_Detail_Layout in FloatingUiScene (766, 345).
const LAYOUT_POSITION=Vector2(766.0,-345.0)
const P="CharacterInfo_StatInfo_Detail/"
## The card authors one 33 px line under its 37 px title; ListView_Left /
## _Right space the cards by their itemMargin (6).
const CARD_HEAD: float=37.0
const LINE_HEIGHT: float=33.0
const CARD_GAP: float=6.0
const PERCENT: Array[String]=["attack_speed_bonus","move_speed_bonus","skill_cooldown_reduction","melee_critical","ranged_critical","magic_critical"]
signal closed
var _pack: RefCounted
var _tree: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _columns: Dictionary={}
var _last_out: Dictionary={}
var last_result: Dictionary={}

## One column's cards and its drag scroll.
class Column extends RefCounted:
	var content: Node2D
	var y: float=0.0
	var minimum: float=0.0
	var drag: bool=false

	func bind(list_content: Node2D, view_height: float, cards_height: float) -> void:
		content=list_content
		minimum=minf(0.0,view_height-cards_height)
		y=clampf(y,minimum,0.0)
		content.position.y=y

	func input(event: InputEvent) -> void:
		if not is_instance_valid(content):return
		if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
			drag=event.pressed
			return
		var delta: float=0.0
		if event is InputEventScreenDrag:delta=event.relative.y
		elif event is InputEventMouseMotion and drag:delta=event.relative.y
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			delta=60.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
		if delta==0.0:return
		var scale_y: float=absf(content.get_global_transform_with_canvas().get_scale().y)
		if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
		y=clampf(content.position.y+delta,minimum,0.0)
		content.position.y=y

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in REQUIRED:
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_stat_detail_window_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack)
	_hud=weakref(hud)
	_columns={"left":Column.new(),"right":Column.new()}
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open(parent: Node) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_stat_detail_window_host_unavailable")
	_parent=weakref(parent)
	for column: Column in _columns.values():column.y=0.0
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func node_keys() -> Dictionary:
	return _last_out

## --- Model ------------------------------------------------------------------

## [{code, rows:[[label, value]]}] per column, as the status sheet groups them.
static func groups(state: Dictionary) -> Dictionary:
	var specs: Dictionary={}
	for group: String in Status.GROUPS:
		for spec: Array in Status.GROUPS[group]:specs[str(spec[0])]=spec
	var left: Array=[]
	var used: Dictionary={}
	for attribute: String in Sheet.ATTRIBUTES:
		var rows: Array=[]
		for key: String in Sheet.ATTRIBUTES[attribute]:
			if state.has(key) and specs.has(key):
				rows.append([str(specs[key][1]),value_text(key,state[key])])
				used[key]=true
		if not rows.is_empty():left.append({"code":attribute,"rows":rows})
	var ordered: Array=Sheet.OTHER_ORDER.duplicate()
	for key: String in specs:
		if not ordered.has(key):ordered.append(key)
	var other: Array=[]
	for key: String in ordered:
		if state.has(key) and specs.has(key) and not used.has(key):other.append([str(specs[key][1]),value_text(key,state[key])])
	var right: Array=[{"code":"ETC","rows":other}] if not other.is_empty() else []
	return {"left":left,"right":right}

## The status sheet's number text.
static func value_text(key: String, number: Variant) -> String:
	var suffix: String="%" if key in PERCENT else "초" if key=="attack_interval" else ""
	return ("%.1f" % float(number) if number is float else str(number))+suffix

## --- Stage ------------------------------------------------------------------

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if parent==null or hud==null:return _fail("source_stat_detail_window_host_unavailable")
	var state: Variant=hud.get("character_state")
	var model: Dictionary=groups(state if state is Dictionary else {})
	var spec: Dictionary={}
	spec[P+"Btn_Close"]={"activate":Callable(self,"_close_requested")}
	for name: String in ["Btn_BookMarkOn","Btn_BookMarkOff"]:spec[P+name]={"exclude":true}
	spec[P+"Nd_Bg/Label_Notice"]={"visible":false}
	spec[P+"Nd_Bg/Label_Notice_Left"]={"visible":(model.left as Array).is_empty()}
	spec[P+"Nd_Bg/Label_Notice_Right"]={"visible":(model.right as Array).is_empty()}
	spec[P+"ScrollView"]={"role":"source_scroll","input":Callable(_columns.left,"input")}
	spec[P+"ScrollView_2"]={"role":"source_scroll","input":Callable(_columns.right,"input")}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(ROOT,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	var counts: Dictionary={}
	for side: String in ["left","right"]:
		var filled: Dictionary=_fill(next,out,side,model[side])
		if not filled.get("ok",false):
			next.free()
			last_result=filled
			return filled
		counts[side]=filled.lines
	var previous: Node2D=_scene
	next.position=LAYOUT_POSITION
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_last_out=out
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":ROOT,"left_cards":(model.left as Array).size(),"right_cards":(model.right as Array).size(),"left_lines":counts.left,"right_lines":counts.right}
	return last_result

func _fill(root: Node2D, out: Dictionary, side: String, cards: Array) -> Dictionary:
	var suffix: String=P+("ScrollView/ListView_Left" if side=="left" else "ScrollView_2/ListView_Right")
	var list: Dictionary=NamedTree.locate(root,out,suffix)
	var node: Variant=list.player.source_nodes.get(list.offset) if list.get("ok",false) else null
	var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) and node.has_meta("source_list_content") else null
	if not content is Node2D:return _fail("source_stat_detail_window_list_content_missing")
	var size: Vector2=NamedTree.list_size(out,_pack,ROOT,suffix.trim_prefix(P))
	var panel: Dictionary=_tree.row_panel(CARD)
	var top: float=0.0
	var lines: int=0
	for card: Dictionary in cards:
		var rows: Array=card.rows
		var extra: float=LINE_HEIGHT*float(maxi(0,rows.size()-1))
		var card_spec: Dictionary={
			"Panel_List":{"input":Callable(_columns[side],"input")},
			"Panel_List/Bg":{"size":Vector2(374.0,70.0+extra)},
			"Panel_List/Nd_Title/Text_Title":{"role":"source_text","text":str(card.code)},
			"Panel_List/Btn_AllCheckBox":{"exclude":true},
		}
		var card_out: Dictionary={}
		var built: Dictionary=_tree.scene_of(CARD,card_spec,card_out)
		if not built.get("ok",false):return built
		var scene: Node2D=built.scene
		# Placed top-down like add_row, with each card's grown height.
		var w: float=float(panel.size[0])
		var h: float=float(panel.size[1])
		var bottom: float=size.y-(top+h)
		scene.position=Vector2((size.x-w)*0.5-(float(panel.position[0])-float(panel.anchor[0])*w),-(bottom-(float(panel.position[1])-float(panel.anchor[1])*h)))
		content.add_child(scene)
		var text_list: Dictionary=NamedTree.locate(scene,card_out,"Panel_List/ListView_Text")
		var text_node: Variant=text_list.player.source_nodes.get(text_list.offset) if text_list.get("ok",false) else null
		var text_content: Variant=text_node.get_meta("source_list_content",null) if is_instance_valid(text_node) and text_node.has_meta("source_list_content") else null
		if not text_content is Node2D:return _fail("source_stat_detail_window_line_content_missing")
		var text_size: Vector2=NamedTree.list_size(card_out,_pack,CARD,"Panel_List/ListView_Text")
		for index: int in range(rows.size()):
			var line: Dictionary=_tree.scene_of(LINE,{
				"Panel_Text":{"input":Callable(_columns[side],"input")},
				"Panel_Text/Text_Stat":{"role":"source_text","text":str(rows[index][0])},
				"Panel_Text/Text_Value":{"role":"source_text","text":str(rows[index][1])},
				"Panel_Text/Btn_CheckBox":{"exclude":true},
			},{})
			if not line.get("ok",false):return line
			_tree.add_row(text_content,LINE,line.scene,index,text_size)
			lines+=1
		top+=h+extra+CARD_GAP
	(_columns[side] as Column).bind(content,size.y,top)
	return {"ok":true,"lines":lines}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
