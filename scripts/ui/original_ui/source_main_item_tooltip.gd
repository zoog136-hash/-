extends RefCounted
## The original 523 item information popup (UI/ToolTip/ToolTip_CommonType.csb)
## for one tap on a bag item (user request 2026-11-20: the original client
## opens this popup instead of TWILIGHT's small name label with "◆").
## Shown: the original item name (Title/Label) in its original grade color
## (Grade.ColorID -> ColorTable), the original icon in the popup's own
## Common_Slot, and the original description (ItemClass.StoryDescID /
## UseDescID from DescData_Korean) in ListView_BasicInfo. The popup's
## acquisition, probability and deletion controls use the selected item's
## available actions. The probability flag belongs to its original ItemClass.
## A pack that admits the whole original bag tooltip (ToolTipScene's
## Inventory_ToolTip_Layout, UI/ToolTip/ToolTip_HudType_Right.csb) uses it
## instead, at its authored ToolTipScene position: the same name, values,
## description, 안전강화 label, 획득처 (ToolTip_Button/ItemDrop_On) and
## Btn_Close. Older packs that scope only its name header keep CommonType.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const NativeIcons=preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd")
const IDENTITY=preload("res://scripts/ui/source523_item_identity.gd")
const GRADE=preload("res://scripts/loot/current523_item_grade.gd")
const MEMBER="UI/ToolTip/ToolTip_CommonType.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
## Common_Slot: Btn, Sp_SlotBg, Sp_IconSample only.
const MEMBER_SCOPES={SLOT:[15728,15316,15012]}
## Online / unconnected controls of the popup.
const HIDDEN: Array[String]=["Fx_Popup_LeftUp","Fx_Popup_RightBottom","SetBuff_On","SetBuff_Off","BasicInfo","Nd_Btn_Collection","Nd_Btn","Btn_Compare","ListView_SetBuff","Nd_List_Location","ND_ItemList/Text_Amount"]
const POSITION=Vector2(600.0,-337.5)
const DETAIL_MEMBER="UI/ToolTip/ToolTip_HudType_Right.csb"
## ToolTipScene Inventory_ToolTip_Layout (ProjectNode 1012) at (1008, 345).
const DETAIL_POSITION=Vector2(1008.0,-345.0)
## ItemInfo/ListView_BasicInfo (269 high, itemMargin 0) and its 20-high
## Panel_set; ToolTip_Button (the side buttons).
const DETAIL_LIST_OFFSET: int=39440
const DETAIL_BUTTONS_OFFSET: int=1640
const DETAIL_ROW_STEP: float=20.0
const DETAIL_MAX_ROWS: int=13
## Side buttons and info parts the bag tooltip does not connect (online
## trade, set and collection pages, repair, dissolve, compare, lock).
const DETAIL_HIDDEN: Array[String]=["ItemInfo/ListView_SetBuff","ItemInfo/Nd_Unlock","ItemInfo/Nd_Lock",
	"ToolTip_Button/BasicInfo","ToolTip_Button/Collection_On","ToolTip_Button/Collection_Off","ToolTip_Button/SetBuff_On","ToolTip_Button/SetBuff_Off",
	"ToolTip_Button/Enchant_On","ToolTip_Button/Enchant_Off","ToolTip_Button/Solution_On","ToolTip_Button/Solution_Off",
	"ToolTip_Button/Repair_On","ToolTip_Button/Repair_Off","ToolTip_Button/Business_On","ToolTip_Button/Business_Off",
	"ToolTip_Button/Business_ Possible","ToolTip_Button/Business_Add","ToolTip_Button/Restraint",
	"ToolTip_Button/Registration_On","ToolTip_Button/Registration_Off","ToolTip_Button/ItemDrop_Off",
	"ToolTip_Button/Compare_On","ToolTip_Button/Compare_Off","Icon_Set/Warehouse_On","Icon_Set/Warehouse_Off"]
## ListView_BasicInfo is 195 high; a Panel_set row is 20 plus the list's
## itemMargin 3.
const ROW_STEP: float=23.0
const MAX_ROWS: int=8
const LIST_OFFSET: int=35388
const Z_INDEX: int=165
var _pack: RefCounted
var _tree: RefCounted
var _scene: Node2D
var _out: Dictionary={}
var reference: String=""
var last_result: Dictionary={}
var last_rows_problem: String=""
var _closer: Node
## The popup now shown: MEMBER, or DETAIL_MEMBER for a bag item when the
## pack has the whole bag tooltip.
var member: String=MEMBER
var _detail_available: bool=false

## The client's popup has no X: a tap outside its panel closes it. The tap
## is not consumed (the input is never marked handled), so the button, item or slot
## under the finger still gets it; a tap inside the panel keeps it open.
class OutsideCloser extends Node:
	var popup: WeakRef
	var panel: WeakRef
	var _pressed_outside: bool=false
	func _input(event: InputEvent) -> void:
		var touch: bool=event is InputEventScreenTouch or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index==MOUSE_BUTTON_LEFT)
		if not touch:return
		var viewport: Viewport=get_viewport()
		var to_canvas: Transform2D=viewport.get_final_transform().affine_inverse() if viewport!=null else Transform2D.IDENTITY
		var outside: bool=not panel_rect().has_point(to_canvas*(event as InputEvent).position)
		if event.pressed:
			_pressed_outside=outside
			return
		if outside and _pressed_outside:_close.call_deferred()
		_pressed_outside=false
	## The popup's Bg panel in canvas coordinates (empty when gone).
	func panel_rect() -> Rect2:
		var node: Variant=panel.get_ref() if panel!=null else null
		if not node is Node2D or not is_instance_valid(node):return Rect2()
		var size: Array=(node as Node2D).get_meta("source_size",[0,0])
		var origin: Node2D=(node as Node2D).get_node_or_null("SourceContentOrigin")
		var xf: Transform2D=(origin if origin!=null else node as Node2D).get_global_transform_with_canvas()
		return Rect2(xf*Vector2(0.0,-float(size[1])),xf.basis_xform(Vector2(float(size[0]),float(size[1])))).abs()
	func _close() -> void:
		var owner: Variant=popup.get_ref() if popup!=null else null
		# Only the popup this closer belongs to (another item may have opened since).
		if owner!=null and owner.get("_scene")==get_parent():owner.call("close")

const OUTSIDE_PANEL: String="Bg/Bg"
const DETAIL_OUTSIDE_PANEL: String="Inven_Base/Bg"

## Whether `pack` admits the whole original bag tooltip (its info list and
## side buttons), not only the name/lock header scope.
static func detail_supported(pack: RefCounted) -> bool:
	if pack==null or not pack.manifest.get("scenes",{}).has(DETAIL_MEMBER):return false
	var tree: Dictionary=pack.scene(DETAIL_MEMBER)
	var root: Dictionary=tree.get("nodeTree",{})
	return not _offset_node(root,DETAIL_LIST_OFFSET).is_empty() and not _offset_node(root,DETAIL_BUTTONS_OFFSET).is_empty()

static func _offset_node(node: Dictionary, offset: int) -> Dictionary:
	if int(node.get("_offset",-1))==offset:return node
	for child: Variant in node.get("children",[]):
		if child is Dictionary:
			var found: Dictionary=_offset_node(child,offset)
			if not found.is_empty():return found
	return {}

func configure(pack: RefCounted) -> Dictionary:
	for member: String in [MEMBER,SLOT]:
		if pack==null or not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_item_tooltip_member_missing","member":member}
	_pack=pack
	_detail_available=detail_supported(pack)
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	return {"ok":true,"configured":true,"bag_detail":_detail_available}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

## The original description text of an ItemClass (StoryDescID, then
## UseDescID), with the client's CRLF line breaks.
static func description(item_class_id: int) -> String:
	var row: Dictionary=IDENTITY.row(item_class_id)
	var lines: PackedStringArray=[]
	for field: String in ["StoryDescID","UseDescID"]:
		var id: Variant=row.get(field)
		if not (id is int or id is float) or int(id)<=1:continue
		var text: String=str(IDENTITY.SOURCE.row("DescData_Korean",int(id)).get("Description","")).replace("\r\n","\n").replace("\r","\n").strip_edges()
		if not text.is_empty() and not lines.has(text):lines.append(text)
	return "\n".join(lines)

## Basic values of an equipment record (the game's own record fields, which
## come from the original ItemBonus rows): [[title, value], ...].
static func stat_rows(record: Dictionary) -> Array:
	var rows: Array=[]
	if record.has("small_damage") or record.has("large_damage"):rows.append(["대미지","%d / %d" % [int(record.get("small_damage",0)),int(record.get("large_damage",0))]])
	for pair: Array in [["def","AC","%d"],["hit","명중","+%d"],["additionalDamage","추가 대미지","+%d"],["hpFlat","최대 HP","+%d"],["mpFlat","최대 MP","+%d"],["mr","마법 방어","+%d"],["strFlat","STR","+%d"],["dexFlat","DEX","+%d"],["conFlat","CON","+%d"],["intFlat","INT","+%d"],["wisFlat","WIS","+%d"],["damage_reduction","대미지 리덕션","+%d"]]:
		var value: Variant=record.get(pair[0])
		if (value is int or value is float) and int(value)!=0:rows.append([pair[1],str(pair[2]) % int(value)])
	return rows

static func stats(record: Dictionary) -> String:
	var lines: PackedStringArray=[]
	for row: Array in stat_rows(record):lines.append("%s %s" % [row[0],row[1]])
	return "\n".join(lines)

## Description lines for the popup's rows (at most `width` characters each).
static func text_rows(text: String, width: int=20) -> Array:
	var rows: Array=[]
	for paragraph: String in text.split("\n",false):
		var line: String=""
		for word: String in paragraph.strip_edges().split(" ",false):
			if not line.is_empty() and (line+" "+word).length()>width:
				rows.append(["",line]);line=word
			else:line=word if line.is_empty() else line+" "+word
		if not line.is_empty():rows.append(["",line])
	return rows

## The game record of an original ItemClass (the drop definitions' native
## record) for its values, or {}.
static func native_record(item_class_id: int) -> Dictionary:
	if item_class_id<=0:return {}
	var drops: Script=load("res://scripts/loot/patch523_monster_drops.gd")
	var definition: Variant=drops.call("definition_id",str(item_class_id))
	return definition.get("native_record",{}) if definition is Dictionary else {}

## Opens the popup for a bag entry. `title` is the shown name (enhancement
## prefix and blessing included), `item_class_id` its original ItemClass.
## `bag_item`: the selected bag entry (the original bag tooltip when admitted).
func open(parent: Node, item_reference: String, title: String, item_class_id: int, grade_id: int, record: Dictionary={}, actions: Dictionary={}, hud: Node=null, bag_item: bool=false) -> Dictionary:
	if not is_instance_valid(parent) or title.is_empty():return {"ok":false,"handled":false,"code":"source_item_tooltip_input_invalid"}
	# The bag tooltip's Icon_Set buttons (Com_Btn_TypeB, cap insets past the
	# frame) cannot be drawn faithfully, so it carries no 확률정보 / 삭제 icon:
	# a box with disclosed probability keeps the common popup, deletion stays
	# on the bag's own original Btn_Delete and 획득처 is ToolTip_Button.
	var detail: bool=bag_item and _detail_available and not (actions.get("probability",Callable()) as Callable).is_valid()
	var shown: String=DETAIL_MEMBER if detail else MEMBER
	var spec: Dictionary={}
	for name: String in (DETAIL_HIDDEN if detail else HIDDEN):spec[name]={"exclude":true}
	var callbacks: Dictionary={} if detail else {"Del":actions.get("delete",Callable()),"Detail":actions.get("acquisition",Callable()),"Probability":actions.get("probability",Callable())}
	# Detail and Probability occupy the same authored button position.
	# An eligible bag uses Probability in that slot.
	if (callbacks.get("Probability",Callable()) as Callable).is_valid():callbacks.erase("Detail")
	var safe_level: int=int(actions.get("safe_level",-1))
	if safe_level<0 and not callbacks.values().any(func(action: Callable) -> bool: return action.is_valid()):spec["Icon_Set"]={"exclude":true}
	else:
		for group: String in ["Business","Del","Warehouse","Probability","Detail"]:
			var action: Callable=callbacks.get(group,Callable())
			spec["Icon_Set/"+group+"_Off"]={"exclude":true}
			if action.is_valid():
				spec["Icon_Set/"+group+"_On"]={"visible":true}
				# These original buttons are caller-configured: Del_On is
				# preview-visible with touchEnabled off, Detail_On starts hidden.
				spec["Icon_Set/"+group+"_On/Btn_Icon"]={"activate":action,"touch_enabled":true}
			else:spec["Icon_Set/"+group+"_On"]={"exclude":true}
		# 안전강화 is a label and original state image, with no Button in the
		# CSB. Use the same normal-scroll source rule as the actual forge.
		spec["Icon_Set/Enchant_On"]={"visible":true} if safe_level>0 else {"exclude":true}
		spec["Icon_Set/Enchant_Off"]={"visible":true} if safe_level==0 else {"exclude":true}
		if safe_level>0:spec["Icon_Set/Enchant_On/Text_Enchant"]={"role":"source_text","text":"+%d" % safe_level}
	if not detail:spec["ItemInfo/Img_Title"]={"visible":false}
	spec["ItemInfo/Text_1"]={"visible":false}
	spec["ItemInfo/Text_1_0"]={"visible":false}
	if detail:
		# 획득처 (ItemDrop_On) is the same acquisition action as Detail_On.
		var acquisition: Callable=actions.get("acquisition",Callable())
		if acquisition.is_valid():spec["ToolTip_Button/ItemDrop_On/Button"]={"activate":acquisition}
		else:spec["ToolTip_Button/ItemDrop_On"]={"exclude":true}
		spec["Btn_Close"]={"activate":Callable(self,"_close_pressed")}
	var title_spec: Dictionary={"role":"source_text","text":title}
	var color: Dictionary=GRADE.color_info({"source_grade_id":grade_id}) if grade_id>0 else {}
	if color.get("ok",false):
		var tint: Color=color.color
		title_spec["color"]=[int(round(tint.r*255.0)),int(round(tint.g*255.0)),int(round(tint.b*255.0))]
	spec["Title/Label"]=title_spec
	var values: Array=stat_rows(record)
	if values.is_empty():values=stat_rows(native_record(item_class_id))
	var story: String=description(item_class_id) if item_class_id>0 else ""
	var rows: Array=values+text_rows(story,28 if detail else 20)
	rows=rows.slice(0,DETAIL_MAX_ROWS if detail else MAX_ROWS)
	var body: String=story
	spec["ListView_BasicInfo/Panel_set/Text_Compare"]={"visible":false}
	spec["ListView_BasicInfo/Panel_set"]={"visible":not rows.is_empty()}
	spec["ListView_BasicInfo/Panel_set/Text_Title"]={"role":"source_text","text":str(rows[0][0]) if not rows.is_empty() else ""}
	spec["ListView_BasicInfo/Panel_set/Text_Desc"]={"role":"source_text","text":str(rows[0][1]) if not rows.is_empty() else ""}
	if not detail:spec["ND_ItemList/Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(shown,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	close()
	member=shown
	var next: Node2D=built.scene
	next.position=DETAIL_POSITION if detail else POSITION
	next.z_index=Z_INDEX
	parent.add_child(next)
	_scene=next
	_out=out
	reference=item_reference
	var extra: int=_add_rows(rows.slice(1))
	var picture: bool=false
	if item_class_id>0 and not detail:
		var located: Dictionary=NamedTree.locate(_scene,_out,"ND_ItemList/Slot/Sp_IconSample")
		var info: Dictionary=SourceImages.describe_item_class(item_class_id,title)
		if located.get("ok",false):
			picture=NativeIcons.show_item(located.player,located.offset,info,hud)
	var closer: bool=_attach_outside_closer()
	last_result={"ok":true,"handled":true,"outside_close":closer,"member":member,"reference":item_reference,"title":title,"item_class_id":item_class_id,"grade_color":color.get("hex",""),"description":body,"rows":rows,"extra_rows":extra,"rows_problem":last_rows_problem,"picture":picture}
	return last_result

func _attach_outside_closer() -> bool:
	var located: Dictionary=NamedTree.locate(_scene,_out,DETAIL_OUTSIDE_PANEL if member==DETAIL_MEMBER else OUTSIDE_PANEL)
	if not located.get("ok",false):return false
	var node: Variant=located.player.source_nodes.get(located.offset)
	if not node is Node2D:return false
	var closer:=OutsideCloser.new()
	closer.name="ItemTooltipOutsideClose"
	closer.popup=weakref(self)
	closer.panel=weakref(node)
	_scene.add_child(closer)
	_closer=closer
	return true

func blocks_point(point: Vector2) -> bool:
	return is_open() and is_instance_valid(_closer) and _closer.panel_rect().has_point(point)

## Further rows: the same original Panel_set (its own Text_Title/Text_Desc),
## stacked under the first one with the list's item margin.
func _add_rows(rows: Array) -> int:
	if rows.is_empty() or not is_open():return 0
	# Each further row is the original ListView_BasicInfo with its Panel_set
	# (same member, same coordinates) moved down by one list step.
	var detail: bool=member==DETAIL_MEMBER
	var row_tree: RefCounted=NamedTree.new(_pack,{member:[DETAIL_LIST_OFFSET if detail else LIST_OFFSET]})
	var added: int=0
	for index: int in rows.size():
		var out: Dictionary={}
		var built: Dictionary=row_tree.scene_of(member,{"ListView_BasicInfo/Panel_set/Text_Compare":{"visible":false},"ListView_BasicInfo/Panel_set/Text_Title":{"role":"source_text","text":str(rows[index][0])},"ListView_BasicInfo/Panel_set/Text_Desc":{"role":"source_text","text":str(rows[index][1])}},out)
		if not built.get("ok",false):
			last_rows_problem=str(built.get("error",built.get("code","")))+str(built.get("details",""))
			break
		var row: Node2D=built.scene
		_scene.add_child(row)
		row.position=Vector2(0.0,(DETAIL_ROW_STEP if detail else ROW_STEP)*float(index+1))
		added+=1
	return added

func _close_pressed() -> Dictionary:
	close()
	return {"ok":true,"closed":true}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_closer=null
	_out={}
	reference=""
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
