extends RefCounted
## The original 523 help popup: HelpBoxLayout (the dimmed full-screen
## Black_BG and the invisible full-screen Btn_Close above it, which closes the
## popup on a tap outside the help) with one
## window's own help member on top. Paged help (Panel_1..Panel_N under the
## member, the client's Btn_Left / Btn_Right) shows one panel at a time and
## stays on the first / last page at the ends; a single-page help is shown
## whole. Every text and picture is the member's own original record.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const StageReads=preload("res://scripts/ui/original_ui/source_stage_tree_reads.gd")
const LAYOUT="UI/CsbFile/Help/HelpBoxLayout.csb"
## Help members of the connected windows (kept here so the UI pack builder
## packs them; a window passes its own).
const REFINE="UI/CsbFile/Help/HelpBox_Refine.csb"
const TOTEM="UI/CsbFile/Help/HelpBox_Totem.csb"
const ELIXIR="UI/CsbFile/Help/HelpBox_Elixir.csb"
const DISPATCH="UI/CsbFile/Help/HelpBox_Change_Dispatch.csb"
const ORIM="UI/CsbFile/Help/HelpBox_Mission_TracesOrim.csb"
const TITLE="UI/Title/Title_Popup_Help.csb"
const SYMBOL="UI/Symbol/Symbol_Popup_Help.csb"
## The popup sits on the design centre, above the original windows (z 150).
const POSITION=Vector2(600.0,-337.5)
const Z_INDEX: int=160
var _pack: RefCounted
var _tree: RefCounted
var _parent: WeakRef
var _member: String=""
var _pages: Array[String]=[]
var _page: int=0
var _scene: Node2D
var last_result: Dictionary={}

func configure(pack: RefCounted) -> Dictionary:
	if pack==null:return _fail("source_help_box_pack_unavailable")
	_pack=pack
	_tree=NamedTree.new(pack)
	return {"ok":true}

## True when `member` (and the layout) are in the pack.
func available(member: String) -> bool:
	return _pack!=null and _pack.manifest.get("scenes",{}).has(LAYOUT) and _pack.manifest.get("scenes",{}).has(member)

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func page() -> int:
	return _page

func page_count() -> int:
	return maxi(1,_pages.size())

## Opens `member` under `parent` (the original windows' coordinates).
func open(parent: Node, member: String) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_help_box_host_unavailable")
	if not available(member):return _fail("source_help_box_member_missing")
	_parent=weakref(parent)
	_member=member
	var reads: Dictionary={}
	_pages=_page_names(member,reads)
	_page=0
	return _stage(reads)

func close() -> Dictionary:
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	return {"ok":true,"closed":true}

func step(delta: int) -> Dictionary:
	if not is_open():return {"ok":true,"handled":false}
	var next: int=clampi(_page+delta,0,page_count()-1)
	if next==_page:return {"ok":true,"page":_page+1,"pages":page_count()}
	_page=next
	return _stage()

## Panel_<n> nodes of the member, in page order.
func _page_names(member: String, reads: Dictionary={}) -> Array[String]:
	var found: Dictionary={}
	_collect(StageReads.node_tree(_pack,member,reads),found)
	var names: Array[String]=[]
	for index: int in range(1,found.size()+1):
		if not found.has(index):break
		names.append("Panel_%d" % index)
	return names

## Names of the member's custom-size Text nodes whose original text has
## several lines.
func _wrapped_texts(member: String, reads: Dictionary={}) -> Array[String]:
	var names: Array[String]=[]
	_collect_wrapped(StageReads.node_tree(_pack,member,reads),names)
	return names

static func _collect_wrapped(node: Dictionary, names: Array[String]) -> void:
	var options: Dictionary=node.get("options",{}) if node.get("options") is Dictionary else {}
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",{}))
	if node.get("classname")=="Text" and bool(options.get("isCustomSize",false)) and str(options.get("text","")).contains("\n"):
		var name: String=str(widget.get("name",""))
		if not name.is_empty() and name not in names:names.append(name)
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_collect_wrapped(child,names)

static func _collect(node: Dictionary, found: Dictionary) -> void:
	var options: Dictionary=node.get("options",{}) if node.get("options") is Dictionary else {}
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",{}))
	var name: String=str(widget.get("name",""))
	if name.begins_with("Panel_") and name.trim_prefix("Panel_").is_valid_int():found[int(name.trim_prefix("Panel_"))]=true
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_collect(child,found)

func _stage(reads: Dictionary={}) -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if parent==null:return _fail("source_help_box_host_unavailable")
	var close_action: Callable=Callable(self,"close")
	var layout: Dictionary=_tree.scene_of(LAYOUT,{"Black_BG":{"role":"consume"},"Btn_Close":{"activate":close_action}},{})
	if not layout.get("ok",false):
		last_result=layout
		return layout
	var spec: Dictionary={}
	# Multi-line custom-size help texts wrap the way Cocos does (Label_Message).
	for name: String in _wrapped_texts(_member,reads):spec[name]={"cocos_wrap":true}
	for index: int in range(_pages.size()):spec[_pages[index]]={"visible":index==_page}
	spec["Btn_Left"]={"activate":Callable(self,"step").bind(-1)}
	spec["Btn_Right"]={"activate":Callable(self,"step").bind(1)}
	var help: Dictionary=_tree.scene_of(_member,spec,{},reads)
	if not help.get("ok",false):
		layout.scene.free()
		last_result=help
		return help
	var next: Node2D=layout.scene
	next.add_child(help.scene)
	next.position=POSITION
	next.z_index=Z_INDEX
	var previous: Node2D=_scene
	parent.add_child(next)
	_scene=next
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":_member,"page":_page+1,"pages":page_count()}
	return last_result

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
