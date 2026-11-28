extends RefCounted
## Original ToolTipScene's Skill_ToolTip_Layout (728 at 1008,345).
## Only the details with data in the selected TWILIGHT skill are shown.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const Rules=preload("res://scripts/skill_rules.gd")
const MEMBER="UI/ToolTip/ToolTip_HudType_Skill.csb"
const SHA="1d7512e791b02975dc6be141f443d5f98c746c752ab6c7717ef3998013b32dc2"
const LIST=15176
const ROW="ItemInfo/ListView_BasicInfo/Panel_set"
const POSITION=Vector2(1008.0,-345.0)
const ROW_HEIGHT=20.0
const MAX_ROWS=17
var _scene: Node2D
var _dismiss: Callable

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_dismiss=Callable()
	if is_instance_valid(previous):
		previous.hide()
		previous.queue_free()

static func available(pack: RefCounted) -> bool:
	return pack!=null and pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")==SHA and pack.manifest.get("scenes",{}).has(MEMBER)

func open(pack: RefCounted,parent: Node,record: Dictionary,hud: Node,dismiss: Callable) -> Dictionary:
	if not available(pack):
		return {"ok":false,"code":"source_skill_detail_not_in_pack"}
	if not is_instance_valid(parent) or not dismiss.is_valid() or str(record.get("name","")).is_empty():
		return {"ok":false,"code":"source_skill_detail_host_unavailable"}
	var skill: Dictionary=record
	var world: Node=hud.get_parent() if is_instance_valid(hud) else null
	if is_instance_valid(world):
		var service: Variant=world.get("original_skills")
		if service is Object and service.get("catalog") is Object:
			var resolved: Dictionary=service.catalog.resolve(record)
			if not resolved.is_empty():skill=resolved
	var rows: Array=readout(record,skill)
	var spec: Dictionary={
		"Inven_Base/Bg":{"role":"consume"},
		"Title/Label":{"role":"source_text","text":str(record.name)},
		"ItemInfo/Text_1":{"exclude":true},
		"ItemInfo/ListView_SetBuff":{"exclude":true},
		"ItemInfo/Btn_Unlock":{"exclude":true},
		"ItemInfo/Btn_Lock":{"exclude":true},
		"ItemInfo/Nd_Help":{"exclude":true},
		"ItemInfo/Nd_Target":{"exclude":true},
		"Btn_Close":{"activate":Callable(self,"_close_pressed")},
	}
	spec.merge(_row_spec(rows[0]))
	var tree=NamedTree.new(pack)
	var out: Dictionary={}
	var built: Dictionary=tree.scene_of(MEMBER,spec,out)
	if not built.get("ok",false):return built
	var next: Node2D=built.scene
	var located: Dictionary=NamedTree.locate(next,out,"ItemInfo/ListView_BasicInfo")
	var list: Variant=located.player.source_nodes.get(located.offset) if located.get("ok",false) else null
	var content: Variant=list.get_meta("source_list_content") if is_instance_valid(list) and list.has_meta("source_list_content") else null
	if not content is Node2D:
		next.free()
		return {"ok":false,"code":"source_skill_detail_list_unavailable"}
	var row_tree=NamedTree.new(pack,{MEMBER:[LIST]})
	for index: int in range(1,rows.size()):
		var row_out: Dictionary={}
		var clone: Dictionary=row_tree.scene_of(MEMBER,_row_spec(rows[index]),row_out)
		if not clone.get("ok",false):
			next.free()
			return clone
		var line: Node2D=clone.scene
		next.add_child(line)
		line.position.y=ROW_HEIGHT*index
	close()
	_scene=next
	_dismiss=dismiss
	next.position=POSITION
	next.z_index=165
	parent.add_child(next)
	return {"ok":true,"handled":true,"member":MEMBER,"rows":rows.size(),"game_state_written":false}

static func _row_spec(row: Array) -> Dictionary:
	return {ROW+"/Text_Title":{"role":"source_text","text":str(row[0])},ROW+"/Text_Desc":{"role":"source_text","text":str(row[1])},ROW+"/Btn_Help":{"exclude":true}}

static func readout(record: Dictionary,skill: Dictionary) -> Array:
	var passive: bool=Rules.is_passive(skill)
	var rows: Array=[["종류","패시브" if passive else "액티브"]]
	var job: String=str(skill.get("display_class",record.get("class","")))
	if not job.is_empty():rows.append(["클래스",job])
	if not passive:
		for field: Array in [["mp","MP"],["hp","HP"]]:
			if skill.get(field[0]) is int or skill.get(field[0]) is float:rows.append([field[1],str(int(skill[field[0]]))])
		if skill.get("cooldown") is int or skill.get("cooldown") is float:rows.append(["재사용","%.1f초" % float(skill.cooldown)])
	var description: String=str(skill.get("runtime_desc",record.get("desc",""))).replace("\r\n","\n")
	for paragraph: String in description.split("\n",false):
		while not paragraph.is_empty() and rows.size()<MAX_ROWS:
			var width: int=mini(15,paragraph.length())
			if width<paragraph.length():
				var whitespace: int=paragraph.left(width+1).rfind(" ")
				if whitespace>0:width=whitespace
			rows.append(["",paragraph.left(width)])
			paragraph=paragraph.substr(width).strip_edges()
	return rows

func _close_pressed() -> Dictionary:
	var dismiss: Callable=_dismiss
	close()
	if dismiss.is_valid():dismiss.call()
	return {"ok":true,"closed":true}
