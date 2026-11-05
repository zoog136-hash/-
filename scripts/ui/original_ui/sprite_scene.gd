extends Node2D
const EASING=preload("res://scripts/ui/original_ui/source_easing.gd")
## Original Node/SingleNode/Sprite and transparent noninteractive Panel scenes,
## with discrete texture/visibility tracks. Other classes/tracks are rejected.
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
var inspection_only: bool=false
var unresolved_bindings: Array[String]=[]
var _build_error: String=""

func configure(pack: RefCounted, member: String, inspect_only: bool=false) -> Dictionary:
	if not source_tree.is_empty(): return {"ok":false,"error":"already_configured"}
	unresolved_bindings.clear()
	_build_error=""
	inspection_only=inspect_only
	var tree: Dictionary=pack.scene(member)
	if tree.is_empty(): return {"ok":false,"error":"source_scene_missing"}
	var problems: Array[String]=[]
	_validate(tree.get("nodeTree",{}),problems)
	var action: Dictionary=tree.get("action",{}) if tree.get("action") is Dictionary else {}
	for timeline: Dictionary in action.get("timeLines",[]):
		if timeline.get("property") not in ["FileData","VisibleForFrame","Position","Scale","RotationSkew","Alpha","CColor","BlendFunc"]:
			problems.append("unsupported_timeline:"+str(timeline.get("property")))
		for frame: Dictionary in timeline.get("frames",[]):
			var value: Dictionary=_frame_value(frame)
			if value.is_empty(): problems.append("unsupported_frame_union")
			var expected: String={"Position":"PointFrame","Scale":"ScaleFrame","RotationSkew":"ScaleFrame","Alpha":"IntFrame","CColor":"ColorFrame","BlendFunc":"BlendFrame"}.get(str(timeline.property),"")
			if not expected.is_empty():
				if value.get("_type")!=expected: problems.append("numeric_track_type")
				if expected=="BlendFrame" and _blend(value) not in ["770:1","770:771","1:771"]: problems.append("unsupported_blend_track")
				var easing: Dictionary=value.get("easingData",{}) if value.get("easingData") is Dictionary else {}
				if int(easing.get("type",0)) not in EASING.SUPPORTED or not easing.get("points",[]).is_empty(): problems.append("unsupported_easing")
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
		_clear(); return {"ok":false,"error":_build_error if not _build_error.is_empty() else "source_texture_or_identity_missing"}
	for timeline: Dictionary in action.get("timeLines",[]):
		if not _tags.has(int(timeline.actionTag)):
			root_node.free(); _clear(); return {"ok":false,"error":"timeline_node_missing"}
		if timeline.property in ["BlendFunc","FileData"] and not _tags[int(timeline.actionTag)].has_meta("source_sprite"):
			root_node.free(); _clear(); return {"ok":false,"error":"unsupported_timeline_target"}
	add_child(root_node)
	return {"ok":true,"nodes":source_nodes.size(),"source":member,"inspection_only":inspection_only,"unresolved_bindings":unresolved_bindings.duplicate()}

func _validate(node: Dictionary, problems: Array[String]) -> void:
	if node.get("classname") not in ["Node","SingleNode","Sprite","Panel","ListView","ProjectNode","ImageView","Text","Button"]:
		problems.append("unsupported_node:"+str(node.get("classname"))); return
	if not str(node.get("customClassName","")).is_empty(): problems.append("custom_class")
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	if widget.is_empty(): problems.append("missing_node_options"); return
	if not widget.get("rotationSkew") is Array or widget.rotationSkew.size()!=2: problems.append("invalid_rotation_skew")
	if not str(widget.get("customProperty","")).is_empty(): problems.append("custom_property")
	for field: String in ["frameEvent","callBackType","callBackName"]:
		if widget.get(field)!=null and not str(widget[field]).is_empty():
			unresolved_bindings.append(str(widget.name)+":"+field+":"+str(widget[field]))
			if not inspection_only: problems.append("unconnected_source_callback:"+field)
	if bool(widget.get("touchEnabled",false)):
		unresolved_bindings.append(str(widget.name)+":source_input")
		if not inspection_only: problems.append("unconnected_source_input")
	if node.classname=="Button":
		unresolved_bindings.append(str(widget.name)+":original_button_service_binding")
		if not inspection_only: problems.append("unconnected_source_button")
		if str(options.get("text","")).contains("\n") or int(options.get("shadowBlurRadius",0))!=0: problems.append("unsupported_button_text_layout_or_blur")
	if node.classname=="Text":
		unresolved_bindings.append(str(widget.name)+":source_text_requires_live_binding")
		if not inspection_only: problems.append("unconnected_source_text")
		if str(options.get("text","")).contains("\n") or int(options.get("shadowBlurRadius",0))!=0: problems.append("unsupported_text_layout_or_blur")
		if int(options.get("fontSize",0))<=0: problems.append("invalid_source_font_size")
	if node.classname=="ListView":
		# Inspection preserves an empty original container, not a working list.
		# Populating it without source row/caller contracts would invent UI.
		unresolved_bindings.append(str(widget.name)+":original_item_template_and_data_binding")
		if not inspection_only or not node.get("children",[]).is_empty(): problems.append("unconnected_list_content")
	if node.classname=="ProjectNode":
		unresolved_bindings.append(str(widget.name)+":project_scene_binding")
		if not inspection_only or not str(options.get("fileName","")).is_empty(): problems.append("unconnected_project_scene")
	if node.classname in ["Panel","ListView"]:
		if (int(options.get("colorType",0))!=0 and int(options.get("bgColorOpacity",0))!=0) or not str(options.get("backGroundImageData",{}).get("path","")).is_empty(): problems.append("unsupported_panel_background")
		if bool(options.get("backGroundScale9Enabled",false)): problems.append("unsupported_panel_scale9")
	var layout: Dictionary=widget.get("layoutComponent",{}) if widget.get("layoutComponent") is Dictionary else {}
	for field: String in ["positionXPercentEnabled","positionYPercentEnabled","sizeXPercentEnable","sizeYPercentEnable","stretchHorizontalEnabled","stretchVerticalEnabled"]:
		if int(layout.get(field,0))!=0: problems.append("layout_constraint:"+field)
	if node.classname=="Sprite" and _blend(options) not in ["770:1","770:771","1:771"]: problems.append("unsupported_blend")
	for child: Dictionary in node.get("children",[]): _validate(child,problems)

func _build(source: Dictionary) -> Node2D:
	var options: Dictionary=source.options
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var node:=Node2D.new()
	node.name=str(widget.name)
	node.set_meta("source_scale",widget.scale.duplicate())
	node.set_meta("source_rotation",widget.rotationSkew.duplicate())
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
	if source.classname=="Button":
		var button=preload("res://scripts/ui/original_ui/source_button.gd").new()
		var configured: Dictionary=button.configure(source_pack,options)
		if not configured.ok:
			_build_error=str(configured.error)+":"+str(widget.name)
			button.free();node.free();return null
		origin.add_child(button)
		node.set_meta("source_button",button)
	if source.classname=="Text":
		var font_value: FontFile=source_pack.font(options.fontResource)
		if font_value==null:
			_build_error="original_font_unavailable:"+str(widget.name); node.free(); return null
		var text_value: String=str(options.text)
		for index: int in range(text_value.length()):
			if not text_value[index].strip_edges().is_empty() and not font_value.has_char(text_value.unicode_at(index)):
				_build_error="original_font_glyph_missing:"+str(widget.name); node.free(); return null
		var label=preload("res://scripts/ui/original_ui/source_text.gd").new()
		label.name="OriginalText"
		label.configure(font_value,options,Vector2(widget.size[0],widget.size[1]))
		origin.add_child(label)
	if source.classname=="ImageView":
		var texture: Texture2D=source_pack.texture(options.fileNameData)
		if texture==null: node.free(); return null
		var picture: Control
		if bool(options.scale9Enabled):
			var nine=preload("res://scripts/ui/original_ui/source_scale9.gd").new()
			var configured: Dictionary=nine.configure(texture,Vector2(widget.size[0],widget.size[1]),options.capInsets)
			if not configured.ok:
				_build_error=str(configured.error)+":"+str(widget.name)
				nine.free(); node.free(); return null
			picture=nine
		else:
			var flat:=TextureRect.new()
			flat.texture=texture
			flat.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			flat.stretch_mode=TextureRect.STRETCH_SCALE
			picture=flat
		picture.name="OriginalImage"
		picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		picture.size=Vector2(widget.size[0],widget.size[1])
		picture.position=Vector2(0,-float(widget.size[1]))
		if bool(widget.flipX): picture.scale.x=-1; picture.position.x=float(widget.size[0])
		if bool(widget.flipY): picture.scale.y=-1; picture.position.y=0
		origin.add_child(picture)
		node.set_meta("source_image",picture)
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
		material_value.blend_mode=_blend_mode(options)
		sprite.material=material_value
		origin.add_child(sprite)
		node.set_meta("source_sprite",sprite)
		node.set_meta("source_anchor",widget.anchorPoint)
		node.set_meta("source_origin",origin)
		_texture_refs[int(source._offset)]=options.fileNameData.duplicate(true)
	var child_origin: Node=origin
	if source.classname in ["Panel","ListView"] and bool(options.clipEnabled):
		# The original transparent Panel clips its children to the source size.
		# Control uses top-left coordinates; restore Cocos' bottom-left origin
		# inside it before adding source children. No replacement pixels.
		var clip:=Control.new()
		clip.name="SourceClipRect"
		clip.position=Vector2(0,-float(widget.size[1]))
		clip.size=Vector2(widget.size[0],widget.size[1])
		clip.clip_contents=true
		clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
		origin.add_child(clip)
		var clipped_origin:=Node2D.new()
		clipped_origin.name="SourceClippedOrigin"
		clipped_origin.position.y=float(widget.size[1])
		clip.add_child(clipped_origin)
		child_origin=clipped_origin
	for child: Dictionary in source.children:
		var built: Node2D=_build(child)
		if built==null: node.free(); return null
		child_origin.add_child(built)
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

func stop() -> void:
	# Freeze the current original frame; do not clear or replace its pixels.
	_playing=false

func playback_status() -> Dictionary:
	return {"playing":_playing,"frame":_frame,"loop":_loop,"source":source_member,"clip":str(_clip.get("name","")),"inspection_only":inspection_only}

func seek_frame(frame_number: float) -> void:
	_frame=frame_number
	var action: Dictionary=source_tree.get("action",{}) if source_tree.get("action") is Dictionary else {}
	for timeline: Dictionary in action.get("timeLines",[]):
		var selected: Dictionary={}
		for raw: Dictionary in timeline.frames:
			var value: Dictionary=_frame_value(raw)
			if float(value.frameIndex)<=frame_number and (selected.is_empty() or float(value.frameIndex)>=float(selected.frameIndex)): selected=value
		if selected.is_empty(): continue
		var following: Dictionary={}
		for raw: Dictionary in timeline.frames:
			var value: Dictionary=_frame_value(raw)
			if float(value.frameIndex)>float(selected.frameIndex) and (following.is_empty() or float(value.frameIndex)<float(following.frameIndex)): following=value
		var ratio: float=0.0
		if not following.is_empty() and bool(selected.get("tween",false)):
			ratio=clampf((frame_number-float(selected.frameIndex))/(float(following.frameIndex)-float(selected.frameIndex)),0.0,1.0)
			var easing: Dictionary=selected.get("easingData",{}) if selected.get("easingData") is Dictionary else {}
			ratio=EASING.sample(int(easing.get("type",0)),ratio)
		else: following=selected
		var target: Node2D=_tags.get(int(timeline.actionTag))
		if target==null: continue
		if timeline.property=="Position":
			var a: Array=selected.postion
			var b: Array=following.postion
			target.position=Vector2(lerpf(a[0],b[0],ratio),-lerpf(a[1],b[1],ratio))
		elif timeline.property=="CColor":
			var a: Array=selected.color
			var b: Array=following.color
			# Cocos ColorFrame affects RGB; the separate Alpha track owns opacity.
			target.modulate=Color(float(int(lerpf(a[1],b[1],ratio)))/255.0,float(int(lerpf(a[2],b[2],ratio)))/255.0,float(int(lerpf(a[3],b[3],ratio)))/255.0,target.modulate.a)
		elif timeline.property=="BlendFunc":
			if target.has_meta("source_sprite"):
				var sprite: Sprite2D=target.get_meta("source_sprite")
				sprite.material.blend_mode=_blend_mode(selected)
		elif timeline.property=="Alpha":
			target.modulate.a=float(int(lerpf(float(selected.value),float(following.value),ratio)))/255.0
		elif timeline.property in ["Scale","RotationSkew"]:
			var a: Array=selected.scale
			var b: Array=following.scale
			target.set_meta("source_scale" if timeline.property=="Scale" else "source_rotation",[lerpf(a[0],b[0],ratio),lerpf(a[1],b[1],ratio)])
			var scale_value: Array=target.get_meta("source_scale")
			var rotation_value: Array=target.get_meta("source_rotation")
			var rx: float=deg_to_rad(float(rotation_value[0]))
			var ry: float=deg_to_rad(float(rotation_value[1]))
			target.transform=Transform2D(Vector2(cos(ry)*scale_value[0],sin(ry)*scale_value[0]),Vector2(-sin(rx)*scale_value[1],cos(rx)*scale_value[1]),target.position)
		elif timeline.property=="VisibleForFrame": target.visible=bool(selected.value)
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

func _blend_mode(value: Dictionary) -> int:
	match _blend(value):
		"770:1": return CanvasItemMaterial.BLEND_MODE_ADD
		"1:771": return CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return CanvasItemMaterial.BLEND_MODE_MIX
