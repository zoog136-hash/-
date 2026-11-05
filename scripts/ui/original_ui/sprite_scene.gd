extends Node2D
## Original Node/SingleNode/Sprite scenes and their discrete texture/visibility
## tracks. Unsupported UI classes/tracks are rejected, never drawn as substitutes.
var source_pack: RefCounted
var source_member: String=""
var source_tree: Dictionary={}
var source_nodes: Dictionary={}
var _tags: Dictionary={}
var _clip: Dictionary={}
var _frame: float=0.0
var _playing: bool=false
var _loop: bool=false
var _texture_refs: Dictionary={}

func configure(pack: RefCounted, member: String) -> Dictionary:
	if not source_tree.is_empty(): return {"ok":false,"error":"already_configured"}
	var tree: Dictionary=pack.scene(member)
	if tree.is_empty(): return {"ok":false,"error":"source_scene_missing"}
	var problems: Array[String]=[]
	_validate(tree.get("nodeTree",{}),problems)
	var action: Dictionary=tree.get("action",{}) if tree.get("action") is Dictionary else {}
	for timeline: Dictionary in action.get("timeLines",[]):
		if timeline.get("property") not in ["FileData","VisibleForFrame"]:
			problems.append("unsupported_timeline:"+str(timeline.get("property")))
		for frame: Dictionary in timeline.get("frames",[]):
			var value: Dictionary=_frame_value(frame)
			if value.is_empty(): problems.append("unsupported_frame_union")
			if timeline.get("property")=="FileData" and value.get("_type")!="TextureFrame": problems.append("texture_track_type")
			if timeline.get("property")=="VisibleForFrame" and value.get("_type")!="BoolFrame": problems.append("visibility_track_type")
	if not problems.is_empty(): return {"ok":false,"error":"unsupported_source_scene","details":problems}
	source_pack=pack
	source_member=member
	source_tree=tree
	# Validate every original timeline frame before creating a visible scene.
	for timeline: Dictionary in action.get("timeLines",[]):
		for frame: Dictionary in timeline.get("frames",[]):
			var value: Dictionary=_frame_value(frame)
			if value.get("_type")=="TextureFrame" and source_pack.texture(value.textureFile)==null:
				source_tree={}; return {"ok":false,"error":"source_texture_missing"}
	var root_node: Node2D=_build(tree.nodeTree)
	if root_node==null:
		_clear(); return {"ok":false,"error":"source_texture_or_identity_missing"}
	for timeline: Dictionary in action.get("timeLines",[]):
		if not _tags.has(int(timeline.actionTag)):
			root_node.free(); _clear(); return {"ok":false,"error":"timeline_node_missing"}
	add_child(root_node)
	return {"ok":true,"nodes":source_nodes.size(),"source":member}

func _validate(node: Dictionary, problems: Array[String]) -> void:
	if node.get("classname") not in ["Node","SingleNode","Sprite"]:
		problems.append("unsupported_node:"+str(node.get("classname"))); return
	if not str(node.get("customClassName","")).is_empty(): problems.append("custom_class")
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("nodeOptions",options)
	if widget.is_empty(): problems.append("missing_node_options"); return
	if not widget.get("rotationSkew") is Array or widget.rotationSkew.size()!=2: problems.append("invalid_rotation_skew")
	if not str(widget.get("customProperty","")).is_empty(): problems.append("custom_property")
	var layout: Dictionary=widget.get("layoutComponent",{}) if widget.get("layoutComponent") is Dictionary else {}
	for field: String in ["positionXPercentEnabled","positionYPercentEnabled","sizeXPercentEnable","sizeYPercentEnable","stretchHorizontalEnabled","stretchVerticalEnabled"]:
		if int(layout.get(field,0))!=0: problems.append("layout_constraint:"+field)
	if node.classname=="Sprite" and _blend(options) not in ["770:1","770:771","1:771"]: problems.append("unsupported_blend")
	for child: Dictionary in node.get("children",[]): _validate(child,problems)

func _build(source: Dictionary) -> Node2D:
	var options: Dictionary=source.options
	var widget: Dictionary=options.get("nodeOptions",options)
	var node:=Node2D.new()
	node.name=str(widget.name)
	# CCNode::getNodeToParentTransform with the Y axis reflected for Godot.
	# Preserve the two distinct serialized rotation/skew angles.
	var rx: float=deg_to_rad(float(widget.rotationSkew[0]))
	var ry: float=deg_to_rad(float(widget.rotationSkew[1]))
	var sx: float=float(widget.scale[0])
	var sy: float=float(widget.scale[1])
	node.transform=Transform2D(Vector2(cos(ry)*sx,sin(ry)*sx),Vector2(-sin(rx)*sy,cos(rx)*sy),Vector2(widget.position[0],-widget.position[1]))
	node.visible=bool(widget.visible)
	node.z_index=int(widget.zOrder)
	var color: Array=widget.color
	node.modulate=Color(float(color[1])/255.0,float(color[2])/255.0,float(color[3])/255.0,float(widget.alpha)/255.0)
	node.set_meta("original_ui_source",{"scene":source_member,"node_offset":int(source._offset),"manifest_sha256":source_pack.manifest_sha256})
	source_nodes[int(source._offset)]=node
	var tag: int=int(widget.actionTag)
	if tag!=0:
		if _tags.has(tag): node.free(); return null
		_tags[tag]=node
	var origin:=Node2D.new()
	origin.name="SourceContentOrigin"
	origin.position=Vector2(-float(widget.anchorPoint[0])*float(widget.size[0]),float(widget.anchorPoint[1])*float(widget.size[1]))
	node.add_child(origin)
	if source.classname=="Sprite":
		var texture: Texture2D=source_pack.texture(options.fileNameData)
		if texture==null: node.free(); return null
		var sprite:=Sprite2D.new()
		sprite.name="OriginalPixels"
		sprite.texture=texture
		sprite.centered=false
		sprite.position.y=-texture.get_height()
		sprite.flip_h=bool(widget.flipX)
		sprite.flip_v=bool(widget.flipY)
		var material_value:=CanvasItemMaterial.new()
		material_value.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD if _blend(options)=="770:1" else CanvasItemMaterial.BLEND_MODE_MIX
		sprite.material=material_value
		origin.add_child(sprite)
		node.set_meta("source_sprite",sprite)
		node.set_meta("source_anchor",widget.anchorPoint)
		node.set_meta("source_origin",origin)
		_texture_refs[int(source._offset)]=options.fileNameData.duplicate(true)
	for child: Dictionary in source.children:
		var built: Node2D=_build(child)
		if built==null: node.free(); return null
		origin.add_child(built)
	return node

func play(source_clip: String, repeat: bool=false) -> Dictionary:
	for clip: Dictionary in source_tree.get("animationList",[]):
		if clip.name==source_clip:
			_clip=clip.duplicate(true)
			_loop=repeat
			_playing=true
			seek_frame(float(clip.startIndex))
			return {"ok":true}
	return {"ok":false,"error":"source_clip_missing"}

func seek_frame(frame_number: float) -> void:
	_frame=frame_number
	var action: Dictionary=source_tree.get("action",{}) if source_tree.get("action") is Dictionary else {}
	for timeline: Dictionary in action.get("timeLines",[]):
		var selected: Dictionary={}
		for raw: Dictionary in timeline.frames:
			var value: Dictionary=_frame_value(raw)
			if float(value.frameIndex)<=frame_number and (selected.is_empty() or float(value.frameIndex)>=float(selected.frameIndex)): selected=value
		if selected.is_empty(): continue
		var target: Node2D=_tags.get(int(timeline.actionTag))
		if target==null: continue
		if timeline.property=="VisibleForFrame": target.visible=bool(selected.value)
		elif timeline.property=="FileData" and target.has_meta("source_sprite"):
			var sprite: Sprite2D=target.get_meta("source_sprite")
			var texture: Texture2D=source_pack.texture(selected.textureFile)
			if texture==null: _playing=false; return
			sprite.texture=texture
			sprite.position.y=-texture.get_height()
			var anchor: Array=target.get_meta("source_anchor")
			var origin: Node2D=target.get_meta("source_origin")
			origin.position=Vector2(-float(anchor[0])*texture.get_width(),float(anchor[1])*texture.get_height())

func _process(delta: float) -> void:
	if not _playing or _clip.is_empty(): return
	# Cocos ActionTimeline uses a 60-frame clock; source speed is preserved.
	var speed_value: float=float(source_tree.get("action",{}).get("speed",1.0))
	var next: float=_frame+delta*60.0*speed_value
	# Upstream ActionTimeline::step resets to the start at >= end; it does
	# not carry a late frame's overshoot into the next loop.
	if next>=float(_clip.endIndex):
		if _loop and int(_clip.endIndex)>int(_clip.startIndex): next=float(_clip.startIndex)
		else: next=float(_clip.endIndex); _playing=false
	seek_frame(next)

static func _frame_value(raw: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key: String in ["pointFrame","scaleFrame","colorFrame","textureFrame","eventFrame","intFrame","boolFrame","innerActionFrame","blendFrame"]:
		if raw.get(key) is Dictionary:
			if not result.is_empty(): return {}
			result=raw[key]
	return result

func _clear() -> void:
	source_tree.clear()
	source_nodes.clear()
	_tags.clear()
	_texture_refs.clear()

static func _blend(options: Dictionary) -> String:
	var value: Variant=options.get("blendFunc")
	if not value is Array or value.size()!=2: return ""
	return str(int(value[0]))+":"+str(int(value[1]))
