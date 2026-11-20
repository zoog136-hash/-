extends RefCounted
## The original 523 item information popup (UI/ToolTip/ToolTip_CommonType.csb)
## for one tap on a bag item (user request 2026-11-20: the original client
## opens this popup instead of TWILIGHT's small name label with "◆").
## Shown: the original item name (Title/Label) in its original grade color
## (Grade.ColorID -> ColorTable), the original icon in the popup's own
## Common_Slot, and the original description (ItemClass.StoryDescID /
## UseDescID from DescData_Korean) in ListView_BasicInfo. The popup's
## exchange/delete/warehouse/safe-enchant/probability/collection/registration/
## set-effect controls belong to online or unconnected systems and are not
## shown. Nothing here changes an item.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const SourceImages=preload("res://scripts/ui/source523_image_assets.gd")
const IDENTITY=preload("res://scripts/ui/source523_item_identity.gd")
const GRADE=preload("res://scripts/loot/current523_item_grade.gd")
const MEMBER="UI/ToolTip/ToolTip_CommonType.csb"
const SLOT="UI/CommonUi/Common_Slot.csb"
## Common_Slot: Btn, Sp_SlotBg, Sp_IconSample only.
const MEMBER_SCOPES={SLOT:[15728,15316,15012]}
## Online / unconnected controls of the popup.
const HIDDEN: Array[String]=["Fx_Popup_LeftUp","Fx_Popup_RightBottom","Icon_Set","SetBuff_On","SetBuff_Off","BasicInfo","Nd_Btn_Collection","Nd_Btn","Btn_Compare","ListView_SetBuff","Nd_List_Location","ND_ItemList/Text_Amount"]
const POSITION=Vector2(600.0,-337.5)
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

func configure(pack: RefCounted) -> Dictionary:
	for member: String in [MEMBER,SLOT]:
		if pack==null or not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_item_tooltip_member_missing","member":member}
	_pack=pack
	_tree=NamedTree.new(pack,MEMBER_SCOPES)
	return {"ok":true,"configured":true}

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
func open(parent: Node, item_reference: String, title: String, item_class_id: int, grade_id: int, record: Dictionary={}) -> Dictionary:
	if not is_instance_valid(parent) or title.is_empty():return {"ok":false,"handled":false,"code":"source_item_tooltip_input_invalid"}
	var spec: Dictionary={}
	for name: String in HIDDEN:spec[name]={"exclude":true}
	spec["ItemInfo/Img_Title"]={"visible":false}
	spec["ItemInfo/Text_1"]={"visible":false}
	spec["ItemInfo/Text_1_0"]={"visible":false}
	var title_spec: Dictionary={"role":"source_text","text":title}
	var color: Dictionary=GRADE.color_info({"source_grade_id":grade_id}) if grade_id>0 else {}
	if color.get("ok",false):
		var tint: Color=color.color
		title_spec["color"]=[int(round(tint.r*255.0)),int(round(tint.g*255.0)),int(round(tint.b*255.0))]
	spec["Title/Label"]=title_spec
	var values: Array=stat_rows(record)
	if values.is_empty():values=stat_rows(native_record(item_class_id))
	var story: String=description(item_class_id) if item_class_id>0 else ""
	var rows: Array=values+text_rows(story)
	rows=rows.slice(0,MAX_ROWS)
	var body: String=story
	spec["ListView_BasicInfo/Panel_set/Text_Compare"]={"visible":false}
	spec["ListView_BasicInfo/Panel_set"]={"visible":not rows.is_empty()}
	spec["ListView_BasicInfo/Panel_set/Text_Title"]={"role":"source_text","text":str(rows[0][0]) if not rows.is_empty() else ""}
	spec["ListView_BasicInfo/Panel_set/Text_Desc"]={"role":"source_text","text":str(rows[0][1]) if not rows.is_empty() else ""}
	spec["ND_ItemList/Slot/Sp_IconSample"]={"role":"source_asset_slot","visible":false}
	var out: Dictionary={}
	var built: Dictionary=_tree.scene_of(MEMBER,spec,out)
	if not built.get("ok",false):
		last_result=built
		return built
	close()
	var next: Node2D=built.scene
	next.position=POSITION
	next.z_index=Z_INDEX
	parent.add_child(next)
	_scene=next
	_out=out
	reference=item_reference
	var extra: int=_add_rows(rows.slice(1))
	var picture: bool=false
	if item_class_id>0:
		var located: Dictionary=NamedTree.locate(_scene,_out,"ND_ItemList/Slot/Sp_IconSample")
		var info: Dictionary=SourceImages.describe_item_class(item_class_id,title)
		if located.get("ok",false) and info.get("texture") is Texture2D:
			var owner: Dictionary={"ok":true,"texture":info.texture,"status":str(info.get("status","")),"provenance":info.get("provenance",{})}
			picture=located.player.set_bound_source_visual_result(located.offset,owner).get("ok",false) and located.player.set_bound_visible(located.offset,true).get("ok",false)
	last_result={"ok":true,"handled":true,"member":MEMBER,"reference":item_reference,"title":title,"item_class_id":item_class_id,"grade_color":color.get("hex",""),"description":body,"rows":rows,"extra_rows":extra,"rows_problem":last_rows_problem,"picture":picture}
	return last_result

## Further rows: the same original Panel_set (its own Text_Title/Text_Desc),
## stacked under the first one with the list's item margin.
func _add_rows(rows: Array) -> int:
	if rows.is_empty() or not is_open():return 0
	# Each further row is the original ListView_BasicInfo with its Panel_set
	# (same member, same coordinates) moved down by one list step.
	var row_tree: RefCounted=NamedTree.new(_pack,{MEMBER:[LIST_OFFSET]})
	var added: int=0
	for index: int in rows.size():
		var out: Dictionary={}
		var built: Dictionary=row_tree.scene_of(MEMBER,{"ListView_BasicInfo/Panel_set/Text_Compare":{"visible":false},"ListView_BasicInfo/Panel_set/Text_Title":{"role":"source_text","text":str(rows[index][0])},"ListView_BasicInfo/Panel_set/Text_Desc":{"role":"source_text","text":str(rows[index][1])}},out)
		if not built.get("ok",false):
			last_rows_problem=str(built.get("error",built.get("code","")))+str(built.get("details",""))
			break
		var row: Node2D=built.scene
		_scene.add_child(row)
		row.position=Vector2(0.0,ROW_STEP*float(index+1))
		added+=1
	return added

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_out={}
	reference=""
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
