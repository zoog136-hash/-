extends RefCounted
## Name-path binding of a whole original scene (the domination window's
## generic binder, shared): every node of the member (and of its nested
## ProjectNodes) keeps its original record and is listed in the node scope;
## spec entries keyed by an original node-name path suffix supply the live
## roles, texts and visibility. Buttons without a spec stay inert, touch
## widgets swallow their touch, texts keep their original static text.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
var pack: RefCounted
var member_scopes: Dictionary={}

func _init(source_pack: RefCounted, scopes: Dictionary={}) -> void:
	pack=source_pack
	member_scopes=scopes

func _ignore() -> Dictionary:
	return {"ok":true}

func _ignore_input(_event: InputEvent) -> void:
	pass

func bind(member: String, key: String, chain: Array, spec: Dictionary, out: Dictionary) -> Dictionary:
	var tree: Dictionary=pack.scene(member).get("nodeTree",{})
	var scope: Array[int]=[]
	var bindings: Dictionary={}
	var external: Array=pack.manifest.get("externally_bound_texture_nodes",{}).get(member,[])
	var roots: Array=[]
	if member_scopes.has(member):
		for offset: int in member_scopes[member]:roots.append(Scene._node_at_offset(tree,offset))
	else:roots=tree.get("children",[])
	for node: Dictionary in roots:_walk(node,key,chain,spec,scope,bindings,external,out)
	return {"scope":scope,"bindings":bindings}

func _walk(node: Dictionary, parent_key: String, chain: Array, spec: Dictionary, scope: Array[int], bindings: Dictionary, external: Array, out: Dictionary) -> void:
	if node.is_empty():return
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var offset: int=int(node.get("_offset",-1))
	var key: String=parent_key+"/"+str(widget.get("name",""))
	var kind: String=str(node.get("classname",""))
	for pattern: String in spec:
		if key.ends_with("/"+pattern) and bool(spec[pattern].get("exclude",false)):return
	scope.append(offset)
	var binding: Dictionary={}
	match kind:
		"ProjectNode":
			var member: String=str(options.get("fileName",""))
			if not member.begins_with("UI/"):member="UI/"+member
			var next_chain: Array=chain.duplicate()
			next_chain.append(offset)
			var child: Dictionary=bind(member,key,next_chain,spec,out)
			binding={"role":"project","source_node_offsets":child.scope,"bindings":child.bindings}
		"Button":binding={"role":"button","activate":Callable(self,"_ignore")}
		"CheckBox":binding={"role":"checkbox","displaystate":false}
		"Text","TextBMFont":binding={"role":"static_source_text"}
		"ListView":
			var rows: Array=[]
			for row: Dictionary in node.get("children",[]):rows.append(int(row.get("_offset",-1)))
			binding={"role":"source_list","row_offsets":rows}
			# Only a touch-enabled list takes input (a list inside a
			# ScrollView leaves the touch to the ScrollView).
			if bool(widget.get("touchEnabled",false)):binding["input"]=Callable(self,"_ignore_input")
		"ScrollView":
			if bool(widget.get("touchEnabled",false)):binding={"role":"source_scroll","input":Callable(self,"_ignore_input")}
		"LoadingBar":binding={"role":"source_percent","percent":0.0}
	if offset in external and kind=="Sprite":binding={"role":"source_asset_slot","visible":false}
	elif bool(widget.get("touchEnabled",false)) and not binding.has("role") and kind!="ProjectNode":binding["role"]="consume"
	for pattern: String in spec:
		if key.ends_with("/"+pattern):binding.merge(spec[pattern],true)
	if not binding.is_empty():bindings[offset]=binding
	out[key]={"chain":chain,"offset":offset,"kind":kind}
	if kind=="ProjectNode":return
	for child: Dictionary in node.get("children",[]):_walk(child,key,chain,spec,scope,bindings,external,out)

## The player owning `suffix` and the node offset in it.
static func locate(root: Node2D, out: Dictionary, suffix: String) -> Dictionary:
	for key: String in out:
		if not key.ends_with("/"+suffix):continue
		var entry: Dictionary=out[key]
		var player: Dictionary=root.project_player(entry.chain) if not (entry.chain as Array).is_empty() else {"ok":true,"player":root}
		if not player.get("ok",false):return player
		return {"ok":true,"player":player.player,"offset":int(entry.offset),"key":key}
	return {"ok":false,"error":"source_named_node_missing","suffix":suffix}

func scene_of(member: String, spec: Dictionary, out: Dictionary) -> Dictionary:
	var bound: Dictionary=bind(member,"",[],spec,out)
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(pack,member,bound.scope,bound.bindings)
	if not result.get("ok",false):
		scene.free()
		return result
	return {"ok":true,"scene":scene}

## The first child panel of a row scene: {size, position, anchor}.
func row_panel(member: String) -> Dictionary:
	var tree: Dictionary=pack.scene(member).get("nodeTree",{})
	var panel: Dictionary=(tree.get("children",[]) as Array)[0] if not (tree.get("children",[]) as Array).is_empty() else {}
	var widget: Dictionary=panel.get("options",{}).get("widgetOptions",{})
	return {"size":widget.get("size",[0,0]),"position":widget.get("position",[0,0]),"anchor":widget.get("anchorPoint",[0,0])}

## Places an original row scene top-down in a ListView's content (Cocos y up,
## content origin at the list's lower-left), centred horizontally.
func add_row(content: Node2D, member: String, row: Node2D, index: int, list_size: Vector2, gap: float=0.0) -> float:
	var panel: Dictionary=row_panel(member)
	var size: Array=panel.size
	var position: Array=panel.position
	var anchor: Array=panel.anchor
	var height: float=float(size[1])
	var bottom: float=list_size.y-(height+gap)*float(index+1)
	var x: float=(list_size.x-float(size[0]))*0.5-(float(position[0])-float(anchor[0])*float(size[0]))
	var y: float=bottom-(float(position[1])-float(anchor[1])*float(size[1]))
	row.position=Vector2(x,-y)
	content.add_child(row)
	return height+gap

static func list_size(out: Dictionary, source_pack: RefCounted, member: String, suffix: String) -> Vector2:
	for key: String in out:
		if not key.ends_with("/"+suffix):continue
		var node: Dictionary=Scene._node_at_offset(source_pack.scene(member).get("nodeTree",{}),int(out[key].offset))
		var size: Array=node.get("options",{}).get("widgetOptions",{}).get("size",[0,0])
		return Vector2(float(size[0]),float(size[1]))
	return Vector2.ZERO

## Original UI pack texture (unchanged original PNG of the pack) as an
## asset-slot owner result for set_bound_source_visual_result.
static func pack_picture(source_pack: RefCounted, path: String) -> Dictionary:
	var texture: Texture2D=source_pack.texture({"path":path,"resourceType":0},true) if source_pack!=null else null
	if texture==null:return {"ok":false,"status":"source_pack_texture_missing","path":path}
	return {"ok":true,"texture":texture,"status":"original_ui_pack_png","provenance":{"member":{"path":"UI/"+path,"format":"PNG"},"pack_manifest_sha256":str(source_pack.manifest_sha256)}}
