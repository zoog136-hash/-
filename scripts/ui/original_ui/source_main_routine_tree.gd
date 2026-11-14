extends RefCounted
## Generic original-tree binding for the 523 routine (Quest_Tab_Mission) and
## to-do board (StatusBoard_All) windows: every node of a member is mounted
## with its original record; a spec keyed by original node-name path suffix
## supplies live roles, texts, visibility and button actions. Texts keep the
## original string unless the spec gives one. Same scheme as
## source_main_domination_stone_window.gd.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const InventoryImages=preload("res://scripts/ui/original_ui/source_main_inventory_images.gd")
const SLOT="UI/CommonUi/Common_Slot.csb"
const SLOT_BUTTON=15728
const SLOT_BACKGROUND=15316
const SLOT_ICON=15012
## Common_Slot keeps its button, frame and item picture only.
const MEMBER_SCOPES={SLOT:[SLOT_BUTTON,SLOT_BACKGROUND,SLOT_ICON]}
var pack: RefCounted
var hud: WeakRef

func _init(source_pack: RefCounted, owner_hud: Node) -> void:
	pack=source_pack
	hud=weakref(owner_hud)

## {scope, bindings} for `member` mounted under `key`. `out` maps each node
## key to {chain, offset, kind}.
func bind(member: String, key: String, chain: Array, spec: Dictionary, out: Dictionary) -> Dictionary:
	var tree: Dictionary=pack.scene(member).get("nodeTree",{})
	var scope: Array[int]=[]
	var bindings: Dictionary={}
	var external: Array=pack.manifest.get("externally_bound_texture_nodes",{}).get(member,[])
	var roots: Array=[]
	if MEMBER_SCOPES.has(member):
		for offset: int in MEMBER_SCOPES[member]:roots.append(Scene._node_at_offset(tree,offset))
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
	# An empty ProjectNode (no original file) has nothing to mount.
	if kind=="ProjectNode" and str(options.get("fileName","")).is_empty():return
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
		"Button":
			binding={"role":"button","activate":Callable(self,"_ignore")}
			if not str(widget.get("callBackName","")).is_empty():binding["callback_name"]=str(widget.callBackName)
		"CheckBox":binding={"role":"checkbox","displaystate":false}
		"Text","TextBMFont":binding={"role":"static_source_text"}
		"ListView":
			var rows: Array=[]
			for row: Dictionary in node.get("children",[]):rows.append(int(row.get("_offset",-1)))
			binding={"role":"source_list","row_offsets":rows,"input":Callable(self,"_ignore_input")}
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

## The player owning the node whose key ends with `suffix`, and its offset.
static func locate(root: Node2D, out: Dictionary, suffix: String) -> Dictionary:
	for key: String in out:
		if not key.ends_with("/"+suffix):continue
		var entry: Dictionary=out[key]
		var player: Dictionary=root.project_player(entry.chain) if not (entry.chain as Array).is_empty() else {"ok":true,"player":root}
		if not player.get("ok",false):return player
		return {"ok":true,"player":player.player,"offset":int(entry.offset),"key":key}
	return {"ok":false,"error":"source_routine_node_missing","suffix":suffix}

func scene_of(member: String, spec: Dictionary, out: Dictionary) -> Dictionary:
	var bound: Dictionary=bind(member,"",[],spec,out)
	var scene:=Scene.new()
	var result: Dictionary=scene.configure_nodes(pack,member,bound.scope,bound.bindings)
	if not result.get("ok",false):
		scene.free()
		return result
	return {"ok":true,"scene":scene}

## The content node of a mounted ListView and its original size.
func list_content(root: Node2D, out: Dictionary, member: String, suffix: String) -> Dictionary:
	var list: Dictionary=locate(root,out,suffix)
	if not list.get("ok",false):return list
	var node: Node2D=list.player.source_nodes.get(list.offset)
	var content: Variant=(node.get_meta("source_list_content") if node.has_meta("source_list_content") else null) if is_instance_valid(node) else null
	if not content is Node2D:return {"ok":false,"error":"source_routine_list_content_missing","suffix":suffix}
	var size: Vector2=Vector2.ZERO
	for key: String in out:
		if key==list.key:
			var raw: Dictionary=Scene._node_at_offset(pack.scene(member).get("nodeTree",{}),int(out[key].offset))
			var value: Array=raw.get("options",{}).get("widgetOptions",{}).get("size",[0,0])
			size=Vector2(float(value[0]),float(value[1]))
	return {"ok":true,"content":content,"size":size}

## Places an original row scene top-down in a ListView's content (Cocos y up,
## content origin at the list's lower-left).
func add_row(content: Node2D, member: String, row: Node2D, index: int, list_size: Vector2, gap: float=0.0) -> void:
	var tree: Dictionary=pack.scene(member).get("nodeTree",{})
	var panel: Dictionary=(tree.get("children",[]) as Array)[0] if not (tree.get("children",[]) as Array).is_empty() else {}
	var widget: Dictionary=panel.get("options",{}).get("widgetOptions",{})
	var size: Array=widget.get("size",[0,0])
	var position: Array=widget.get("position",[0,0])
	var anchor: Array=widget.get("anchorPoint",[0,0])
	var height: float=float(size[1])
	var bottom: float=list_size.y-(height+gap)*float(index+1)
	var x: float=(list_size.x-float(size[0]))*0.5-(float(position[0])-float(anchor[0])*float(size[0]))
	var y: float=bottom-(float(position[1])-float(anchor[1])*float(size[1]))
	row.position=Vector2(x,-y)
	content.add_child(row)

## Original item picture into a Common_Slot icon node.
func picture(player: Node2D, offset: int, record: Dictionary) -> bool:
	var owner: Node=hud.get_ref() if hud!=null else null
	if owner==null or record.is_empty():return false
	var name: String=str(record.get("name",""))
	var context: Dictionary={"member":SLOT,"node_offset":SLOT_ICON,"reference":name}
	context["source_slot_contract"]=Scene.external_scene_slot_contract(pack,SLOT,SLOT_ICON)
	var resolved: Dictionary=InventoryImages.resolve_owned(owner,{"name":name,"reference":name,"record":record},context)
	if not resolved.get("ok",false):return false
	var uploaded: Dictionary=player.set_bound_source_visual_result(offset,resolved)
	if not uploaded.get("ok",false):return false
	return player.set_bound_visible(offset,true).get("ok",false)

func _ignore() -> Dictionary:
	return {"ok":true,"handled":false}

func _ignore_input(_event: InputEvent) -> void:
	pass
