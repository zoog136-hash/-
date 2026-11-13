extends RefCounted
## Shared mounting for the original 523 feature windows
## (source_main_*_window.gd that extend this file). A window names its
## original root member and a spec keyed by original node-name path
## suffixes; every other node of the mounted tree keeps its original record
## (texts static, buttons inert, touch panels consumed, lists empty). The
## window then fills ListViews with original row scenes. Rules, costs and
## saves stay in the existing game features; nothing here draws or
## substitutes art.
##
## Spec entries: {"exclude":true} leaves the node (and subtree) out of the
## node scope; any other keys merge into the sprite_scene binding (role,
## text, visible, activate, displaystate, percent, ...).
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
signal closed
var _pack: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _out: Dictionary={}
## List key suffix -> {content, min, value} for vertical drag scrolling.
var _scrolls: Dictionary={}
var _moved: float=0.0
var _dragging: String=""
var last_result: Dictionary={}

## Members the window cannot open without (overridden).
func required_members() -> Array[String]:
	return [_root_member()]

func _root_member() -> String:
	return ""

## Design-space position of the mounted root (Cocos y up, flipped).
func _root_position() -> Vector2:
	return Vector2(600.0,-337.5)

func _spec() -> Dictionary:
	return {}

func _fill(_root: Node2D, _out_keys: Dictionary) -> Dictionary:
	return {"ok":true}

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	for member: String in required_members():
		if not pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_window_member_missing","member":member}
	_pack=pack
	_hud=weakref(hud)
	return {"ok":true,"configured":true}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func open_window(parent: Node) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_window_host_unavailable")
	_parent=weakref(parent)
	return _stage()

func refresh() -> Dictionary:
	return _stage() if is_open() else {"ok":true,"handled":false}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_scrolls.clear()
	_dragging=""
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func hud() -> Object:
	return _hud.get_ref() if _hud!=null else null

func world() -> Object:
	var owner: Object=hud()
	return owner.get_parent() if owner is Node else null

func _stage() -> Dictionary:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if parent==null or hud()==null:return _fail("source_window_host_unavailable")
	var keep: Dictionary={}
	for key: String in _scrolls:keep[key]=float(_scrolls[key].get("value",0.0))
	_scrolls.clear()
	var out: Dictionary={}
	var built: Dictionary=_scene_of(_root_member(),_spec(),out)
	if not built.get("ok",false):
		last_result=built
		return built
	var next: Node2D=built.scene
	_out=out
	var filled: Dictionary=_fill(next,out)
	if not filled.get("ok",false):
		next.free()
		last_result=filled
		return filled
	for key: String in _scrolls:
		if keep.has(key):_scroll_to(key,float(keep[key]))
	var previous: Node2D=_scene
	next.position=_root_position()
	parent.add_child(next)
	next.z_index=150
	_scene=next
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	last_result={"ok":true,"handled":true,"member":_root_member(),"filled":filled}
	return last_result

## --- Original-tree binding ---------------------------------------------------

## {scope, bindings} for `member` mounted under `key`. `out` maps each node
## key to {chain, offset, kind, member}. `list_key` makes touch panels of a
## row scene forward drags to that list's scroll instead of consuming them.
func _bind(member: String, key: String, chain: Array, spec: Dictionary, out: Dictionary, list_key: String="") -> Dictionary:
	var tree: Dictionary=_pack.scene(member).get("nodeTree",{})
	var scope: Array[int]=[]
	var bindings: Dictionary={}
	var external: Array=_pack.manifest.get("externally_bound_texture_nodes",{}).get(member,[])
	for node: Dictionary in tree.get("children",[]):_walk(node,member,key,chain,spec,scope,bindings,external,out,list_key)
	return {"scope":scope,"bindings":bindings}

func _walk(node: Dictionary, member: String, parent_key: String, chain: Array, spec: Dictionary, scope: Array[int], bindings: Dictionary, external: Array, out: Dictionary, list_key: String) -> void:
	if node.is_empty():return
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var offset: int=int(node.get("_offset",-1))
	var key: String=parent_key+"/"+str(widget.get("name",""))
	var kind: String=str(node.get("classname",""))
	for pattern: String in spec:
		if key.ends_with("/"+pattern) and bool(spec[pattern].get("exclude",false)):return
	scope.append(offset)
	var touch: bool=bool(widget.get("touchEnabled",false))
	var binding: Dictionary={}
	match kind:
		"ProjectNode":
			var child_member: String=str(options.get("fileName",""))
			if not child_member.begins_with("UI/"):child_member="UI/"+child_member
			var next_chain: Array=chain.duplicate()
			next_chain.append(offset)
			var child: Dictionary=_bind(child_member,key,next_chain,spec,out,list_key)
			binding={"role":"project","source_node_offsets":child.scope,"bindings":child.bindings}
		"Button":
			binding={"role":"button","activate":Callable(self,"_ignore")}
			if not str(widget.get("callBackName","")).is_empty():binding["callback_name"]=str(widget.callBackName)
		"CheckBox":binding={"role":"checkbox","displaystate":false}
		"Text","TextBMFont":binding={"role":"static_source_text"}
		"ListView":
			var rows: Array=[]
			for row: Dictionary in node.get("children",[]):rows.append(int(row.get("_offset",-1)))
			binding={"role":"source_list","row_offsets":rows}
			if touch:binding["input"]=Callable(self,"_list_input").bind(list_key if not list_key.is_empty() else key)
		"ScrollView":
			if touch:binding={"role":"source_scroll","input":Callable(self,"_ignore_input")}
		"LoadingBar":binding={"role":"source_percent","percent":0.0}
	if offset in external and kind=="Sprite":binding={"role":"source_asset_slot","visible":false}
	elif touch and not binding.has("role") and kind!="ProjectNode":
		if not list_key.is_empty() and kind in ["Panel","ImageView"]:binding["input"]=Callable(self,"_list_input").bind(list_key)
		else:binding["role"]="consume"
	for pattern: String in spec:
		if key.ends_with("/"+pattern):binding.merge(spec[pattern],true)
	if not binding.is_empty():bindings[offset]=binding
	out[key]={"chain":chain,"offset":offset,"kind":kind,"member":member}
	if kind=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_walk(child,member,key,chain,spec,scope,bindings,external,out,list_key)

## The player owning the node at `suffix` and its offset.
static func _locate(root: Node2D, out: Dictionary, suffix: String) -> Dictionary:
	for key: String in out:
		if not key.ends_with("/"+suffix):continue
		var entry: Dictionary=out[key]
		var player: Dictionary=root.project_player(entry.chain) if not (entry.chain as Array).is_empty() else {"ok":true,"player":root}
		if not player.get("ok",false):return player
		return {"ok":true,"player":player.player,"offset":int(entry.offset),"key":key,"member":str(entry.member)}
	return {"ok":false,"error":"source_window_node_missing","suffix":suffix}

func _scene_of(member: String, spec: Dictionary, out: Dictionary, list_key: String="") -> Dictionary:
	var bound: Dictionary=_bind(member,"",[],spec,out,list_key)
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(_pack,member,bound.scope,bound.bindings)
	if not result.get("ok",false):
		scene.free()
		result["member"]=member
		return result
	return {"ok":true,"scene":scene}

## The original size of the node at `suffix`.
func _node_size(out: Dictionary, suffix: String) -> Vector2:
	for key: String in out:
		if not key.ends_with("/"+suffix):continue
		var node: Dictionary=Scene._node_at_offset(_pack.scene(str(out[key].member)).get("nodeTree",{}),int(out[key].offset))
		var options: Dictionary=node.get("options",{})
		var size: Array=options.get("widgetOptions",options.get("nodeOptions",{})).get("size",[0,0])
		return Vector2(float(size[0]),float(size[1]))
	return Vector2.ZERO

func _node_options(out: Dictionary, suffix: String) -> Dictionary:
	for key: String in out:
		if key.ends_with("/"+suffix):return Scene._node_at_offset(_pack.scene(str(out[key].member)).get("nodeTree",{}),int(out[key].offset)).get("options",{})
	return {}

## {ok, content, size} of the ListView at `suffix`.
func _list(root: Node2D, out: Dictionary, suffix: String) -> Dictionary:
	var located: Dictionary=_locate(root,out,suffix)
	if not located.get("ok",false):return located
	var node: Node2D=located.player.source_nodes.get(located.offset)
	var content: Variant=node.get_meta("source_list_content",null) if is_instance_valid(node) else null
	if not content is Node2D:return _fail("source_window_list_content_missing")
	return {"ok":true,"content":content,"size":_node_size(out,suffix),"key":located.key}

## The first (root) panel of an original row member: size and origin offset.
func _row_geometry(member: String) -> Dictionary:
	var tree: Dictionary=_pack.scene(member).get("nodeTree",{})
	var children: Array=tree.get("children",[])
	var panel: Dictionary=children[0] if not children.is_empty() else {}
	var options: Dictionary=panel.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",{}))
	var size: Array=widget.get("size",[0,0])
	var position: Array=widget.get("position",[0,0])
	var anchor: Array=widget.get("anchorPoint",[0,0])
	return {"size":Vector2(float(size[0]),float(size[1])),"origin":Vector2(float(position[0])-float(anchor[0])*float(size[0]),float(position[1])-float(anchor[1])*float(size[1]))}

## Places a row scene so its root panel's lower-left sits at `bottom_left`
## (Cocos list content space, y up).
static func _place(content: Node2D, scene: Node2D, geometry: Dictionary, bottom_left: Vector2) -> void:
	var at: Vector2=bottom_left-(geometry.origin as Vector2)
	scene.position=Vector2(at.x,-at.y)
	content.add_child(scene)

## Builds `rows` ([{member, spec}]) top-down (or left to right) in the list
## at `suffix`; returns {ok, rows, scenes, outs}. Vertical lists scroll.
func _fill_list(root: Node2D, out: Dictionary, suffix: String, rows: Array, gap: float=NAN, horizontal: bool=false, columns: int=1) -> Dictionary:
	var list: Dictionary=_list(root,out,suffix)
	if not list.get("ok",false):return list
	# The ListView's own itemMargin unless the caller names the spacing.
	if is_nan(gap):gap=float(_node_options(out,suffix).get("itemMargin",0))
	var size: Vector2=list.size
	var y: float=size.y
	var scenes: Array[Node2D]=[]
	var outs: Array[Dictionary]=[]
	var x: float=0.0
	var line_height: float=0.0
	var column: int=0
	for row: Dictionary in rows:
		var member: String=str(row.member)
		var row_out: Dictionary={}
		var built: Dictionary=_scene_of(member,row.get("spec",{}),row_out,"" if horizontal else str(list.key))
		if not built.get("ok",false):return built
		var geometry: Dictionary=_row_geometry(member)
		var extent: Vector2=geometry.size
		if horizontal:
			_place(list.content,built.scene,geometry,Vector2(x,size.y-extent.y))
			x+=extent.x+gap
		else:
			var width: float=extent.x*float(columns)+gap*float(columns-1)
			var left: float=(size.x-width)*0.5+float(column)*(extent.x+gap)
			_place(list.content,built.scene,geometry,Vector2(left,y-extent.y))
			line_height=maxf(line_height,extent.y)
			column+=1
			if column>=columns:
				column=0
				y-=line_height+gap
				line_height=0.0
		scenes.append(built.scene)
		outs.append(row_out)
	if column>0:y-=line_height+gap
	if not horizontal:
		var used: float=size.y-y-gap
		_scrolls[str(list.key)]={"content":list.content,"min":minf(0.0,size.y-used),"value":0.0}
	return {"ok":true,"rows":rows.size(),"scenes":scenes,"outs":outs}

## Repeats an authored ListView row (a template with no row member of its
## own, e.g. "ListView_Effect/Panel_set") once per spec: each copy is the
## template's own subtree (with its ancestors) of `member`, shifted down by
## `step` per row and added to `host` at `origin`. Copies past `limit` rows
## are not built (the list's own height).
func _repeat_template(host: Node2D, member: String, template_suffix: String, specs: Array, step: float, origin: Vector2, limit: int) -> Dictionary:
	var probe: Dictionary={}
	_bind(member,"",[],{},probe)
	var template: int=-1
	for key: String in probe:
		if key.ends_with("/"+template_suffix):template=int(probe[key].offset)
	if template<0:return _fail("source_window_template_missing")
	var scope: Array[int]=[]
	_collect_subtree(Scene._node_at_offset(_pack.scene(member).get("nodeTree",{}),template),scope)
	var built: int=0
	for index: int in range(mini(specs.size(),limit)):
		var bound: Dictionary=_bind(member,"",[],specs[index],{})
		var scene:=Scene.new()
		var result: Dictionary=scene.configure_nodes(_pack,member,scope,bound.bindings)
		if not result.get("ok",false):
			scene.free()
			return result
		scene.position=origin+Vector2(0.0,step*float(index))
		host.add_child(scene)
		built+=1
	return {"ok":true,"rows":built}

static func _collect_subtree(node: Dictionary, result: Array[int]) -> void:
	if node.is_empty():return
	result.append(int(node.get("_offset",-1)))
	if node.get("classname")=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_collect_subtree(child,result)

func _scroll_to(key: String, value: float) -> void:
	var state: Dictionary=_scrolls.get(key,{})
	if state.is_empty() or not is_instance_valid(state.content):return
	state.value=clampf(value,float(state.min),0.0)
	(state.content as Node2D).position.y=float(state.value)

## True while the current press has moved like a list drag (row taps ignore it).
func _dragged() -> bool:
	return absf(_moved)>12.0

func _list_input(event: InputEvent, key: String) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT):
		if event.pressed:
			_dragging=key
			_moved=0.0
		elif _dragging==key:_dragging=""
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _dragging==key:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=120.0*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0 or not _scrolls.has(key):return
	var content: Node2D=_scrolls[key].content
	if not is_instance_valid(content):return
	var scale_y: float=absf(content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not event is InputEventMouseButton:delta/=scale_y
	_moved+=delta
	_scroll_to(key,float(_scrolls[key].value)+delta)

## Uploads an owner-resolved original picture into a source_asset_slot.
static func _show_picture(player: Node2D, offset: int, owner: Dictionary) -> bool:
	if not owner.get("ok",false):return false
	var uploaded: Dictionary=player.set_bound_source_visual_result(offset,owner)
	return uploaded.get("ok",false) and player.set_bound_visible(offset,true).get("ok",false)

## --- Shared -------------------------------------------------------------------

func _message(text: String) -> void:
	var owner: Object=hud()
	if owner!=null and owner.has_method("show_message"):owner.call("show_message",text)

func _notify(result: Dictionary, success: String="") -> void:
	if result.get("ok",false):
		if not success.is_empty():_message(success)
	else:_message(str(result.get("error",result.get("message","실패"))))

func _ignore() -> Dictionary:
	return {"ok":true}

func _ignore_input(_event: InputEvent) -> void:
	pass

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true}

## Closes this window and runs an existing HUD action (another window).
func _route(method: String, args: Array=[]) -> Dictionary:
	var owner: Object=hud()
	close()
	if owner!=null and owner.has_method(method):owner.callv(method,args)
	return {"ok":true,"routed":method}

static func _number(value: int) -> String:
	var digits: String=str(absi(value))
	var parts: PackedStringArray=[]
	while digits.length()>3:
		parts.insert(0,digits.right(3))
		digits=digits.left(digits.length()-3)
	parts.insert(0,digits)
	return ("-" if value<0 else "")+",".join(parts)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
