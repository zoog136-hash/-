extends Node2D
const BLEND=preload("res://scripts/ui/original_ui/source_blend.gd")
const MATERIAL=preload("res://scripts/ui/original_ui/source_material.gd")
const SPRITE_BACK_BUFFER=preload("res://scripts/ui/original_ui/source_sprite_back_buffer.gd")
const EASING=preload("res://scripts/ui/original_ui/source_easing.gd")
const NODE_SCOPE=preload("res://scripts/ui/original_ui/source_node_scope.gd")
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
## Original Node/SingleNode/Sprite and transparent noninteractive Panel scenes,
## with discrete texture/visibility tracks. Other classes/tracks are rejected.
var source_pack: RefCounted
var source_member: String=""
var source_tree: Dictionary={}
var source_nodes: Dictionary={}
var _tags: Dictionary={}
var _clip: Dictionary={}
var _frame: float=0.0
var _playing: bool=false:
	set(value):
		_playing=value
		set_process(value)
var _loop: bool=false
var _texture_refs: Dictionary={}
var inspection_only: bool=false
var unresolved_bindings: Array[String]=[]
var _build_error: String=""
var _project_ancestry: Array[String]=[]
var _project_root_options: Dictionary={}
var _bindings: Dictionary={}
var excluded_audio_events: Array[Dictionary]=[]
var _entered_frames: Dictionary={}
var _audio_frame_offsets: Dictionary={}
var _resolved_assets: Dictionary={}
var _requested_source_nodes: Array[int]=[]
var _external_texture_nodes: Array[int]=[]
var _external_texture_tags: Dictionary={}

func _ready() -> void:
	# Godot enables scripts with _process before ready. Static/stopped source
	# scenes retain their nodes and pixels without an idle callback. All play,
	# inner-action and failure assignments share the setter above.
	set_process(_playing)

func configure_project(pack: RefCounted, parent_member: String, project_offset: int, bindings: Dictionary, source_nodes_scope: Array[int]=[]) -> Dictionary:
	# Mount an independently supplied original component using its actual
	# parent ProjectNode properties. Parent geometry alone does not activate
	# the parent's unrelated scenes or count them as connected.
	if not source_tree.is_empty():return {"ok":false,"error":"already_configured"}
	var parent: Dictionary=pack.scene(parent_member)
	if parent.is_empty() and pack.has_method("layout_source"):parent=pack.layout_source(parent_member)
	if parent.is_empty():return {"ok":false,"error":"source_parent_layout_missing"}
	var project: Dictionary=_node_at_offset(parent.get("nodeTree",{}),project_offset)
	if project.get("classname")!="ProjectNode":return {"ok":false,"error":"source_parent_project_missing"}
	var options: Dictionary=project.options
	var member: String=str(options.get("fileName",""))
	if member.is_empty():return {"ok":false,"error":"source_parent_project_file_missing"}
	if not member.begins_with("UI/"):member="UI/"+member
	_project_ancestry=[parent_member]
	_project_root_options=options.get("widgetOptions",options.get("nodeOptions",options)).duplicate(true)
	_requested_source_nodes=source_nodes_scope.duplicate()
	var result: Dictionary=configure(pack,member,false,bindings)
	if result.get("ok",false):
		set_meta("original_parent_project",{"member":parent_member,"sha256":parent.get("_source_sha256",""),"offset":project_offset})
	return result

func configure_nodes(pack: RefCounted, member: String, source_nodes_scope: Array[int], bindings: Dictionary) -> Dictionary:
	_requested_source_nodes=source_nodes_scope.duplicate()
	return configure(pack,member,false,bindings)

static func _node_at_offset(node: Dictionary, offset: int) -> Dictionary:
	if int(node.get("_offset",-1))==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at_offset(child,offset)
		if not found.is_empty():return found
	return {}

func configure(pack: RefCounted, member: String, inspect_only: bool=false, bindings: Dictionary={}) -> Dictionary:
	if not source_tree.is_empty(): return {"ok":false,"error":"already_configured"}
	unresolved_bindings.clear()
	excluded_audio_events.clear()
	_audio_frame_offsets.clear()
	_resolved_assets.clear()
	_build_error=""
	inspection_only=inspect_only
	_bindings=bindings.duplicate()
	_external_texture_nodes.clear()
	_external_texture_tags.clear()
	for offset: Variant in pack.manifest.get("externally_bound_texture_nodes",{}).get(member,[]):_external_texture_nodes.append(int(offset))
	if _bindings.has("frame_events") and not _bindings.frame_events is Dictionary:return {"ok":false,"error":"source_frame_event_binding_shape"}
	var tree: Dictionary=pack.scene(member)
	if tree.is_empty(): return {"ok":false,"error":"source_scene_missing"}
	if bool(tree.get("_partial_source_scene",false)):
		if _requested_source_nodes.is_empty():return {"ok":false,"error":"partial_source_requires_explicit_node_scope"}
		var allowed: Array=tree.get("_selected_source_offsets",[])
		for offset: int in _requested_source_nodes:
			if offset not in allowed:return {"ok":false,"error":"source_node_outside_pack_scope","offset":offset}
	if not _requested_source_nodes.is_empty():
		var scoped: Dictionary=NODE_SCOPE.select(tree,_requested_source_nodes)
		if not scoped.get("ok",false):return scoped
		tree=scoped.tree
	if member in _project_ancestry or _project_ancestry.size()>=32:return {"ok":false,"error":"project_recursion"}
	if not _project_root_options.is_empty():
		# CSLoader creates the referenced node, then ProjectNodeReader applies
		# the outer NodeReader properties to that same root. Do not double the
		# transform by wrapping the original root in another transformed node.
		if tree.nodeTree.classname!="Node":return {"ok":false,"error":"unsupported_project_root_class"}
		tree.nodeTree.options=_project_root_options.duplicate(true)
	# Identity-sensitive validation must use this requested source, not the
	# empty/default identity of an unconfigured renderer. Keep source_tree
	# uncommitted until validation succeeds; create no nodes on this path.
	source_pack=pack
	source_member=member
	var problems: Array[String]=[]
	_validate(tree.get("nodeTree",{}),problems)
	var action: Dictionary=tree.get("action",{}) if tree.get("action") is Dictionary else {}
	for timeline: Dictionary in action.get("timeLines",[]):
		if timeline.get("property")=="FileData" and _external_texture_tags.has(int(timeline.get("actionTag",0))):problems.append("external_texture_timeline_requires_owner_contract")
		if timeline.get("property") not in ["FileData","VisibleForFrame","Position","Scale","RotationSkew","Alpha","CColor","BlendFunc","AnchorPoint","FrameEvent","ActionValue"]:
			problems.append("unsupported_timeline:"+str(timeline.get("property")))
		for frame: Dictionary in timeline.get("frames",[]):
			var value: Dictionary=_frame_value(frame)
			if value.is_empty(): problems.append("unsupported_frame_union")
			if timeline.get("property")=="ActionValue":
				if value.get("_type")!="InnerActionFrame" or int(value.get("innerActionType",-1)) not in [0,1,2]:problems.append("unsupported_inner_action")
			if timeline.get("property")=="FrameEvent":
				if value.get("_type")!="EventFrame":problems.append("event_track_type")
				else:
					var event: Variant=_optional_dictionary(str(value.value))
					if event is Dictionary and event.size()==1 and event.get("EventSound") is String:
						excluded_audio_events.append({"frame":value.frameIndex,"value":value.value,"action_tag":timeline.actionTag})
						_audio_frame_offsets[int(value._offset)]=true
					else:
						var event_callback: Variant=_bindings.get("frame_events",{}).get(int(value._offset))
						if not event_callback is Callable or not event_callback.is_valid():
							unresolved_bindings.append("source_frame_event:"+str(value.value))
							if not inspection_only:problems.append("unconnected_source_frame_event")
			var expected: String={"Position":"PointFrame","AnchorPoint":"ScaleFrame","Scale":"ScaleFrame","RotationSkew":"ScaleFrame","Alpha":"IntFrame","CColor":"ColorFrame","BlendFunc":"BlendFrame"}.get(str(timeline.property),"")
			if not expected.is_empty():
				if value.get("_type")!=expected: problems.append("numeric_track_type")
				if expected=="BlendFrame" and _blend(value) not in BLEND.PAIRS: problems.append("unsupported_blend_track")
				var easing: Dictionary=value.get("easingData",{}) if value.get("easingData") is Dictionary else {}
				if not EASING.accepts(easing): problems.append("unsupported_easing")
			if timeline.get("property")=="FileData" and value.get("_type")!="TextureFrame": problems.append("texture_track_type")
			if timeline.get("property")=="VisibleForFrame" and value.get("_type")!="BoolFrame": problems.append("visibility_track_type")
	if not problems.is_empty():
		source_pack=null
		source_member=""
		return {"ok":false,"error":"unsupported_source_scene","details":problems}
	source_tree=tree
	# Validate every original timeline frame before creating a visible scene.
	for timeline: Dictionary in action.get("timeLines",[]):
		for frame: Dictionary in timeline.get("frames",[]):
			var value: Dictionary=_frame_value(frame)
			if value.get("_type")=="TextureFrame" and source_pack.texture(value.textureFile,true)==null:
				source_tree={}; return {"ok":false,"error":"source_texture_missing"}
	var root_node: Node2D=_build(tree.nodeTree)
	if root_node==null:
		_clear(); return {"ok":false,"error":_build_error if not _build_error.is_empty() else "source_texture_or_identity_missing"}
	for timeline: Dictionary in action.get("timeLines",[]):
		if not _tags.has(int(timeline.actionTag)):
			root_node.free(); _clear(); return {"ok":false,"error":"timeline_node_missing"}
		if timeline.property=="ActionValue":
			var target: Node2D=_tags[int(timeline.actionTag)]
			if not target.has_meta("source_project_player"):
				root_node.free();_clear();return {"ok":false,"error":"inner_action_target_missing"}
			for raw: Dictionary in timeline.frames:
				if _inner_range(target.get_meta("source_project_player"),_frame_value(raw)).is_empty():
					root_node.free();_clear();return {"ok":false,"error":"inner_action_clip_missing_or_invalid"}
		if (timeline.property=="FileData" and not _tags[int(timeline.actionTag)].has_meta("source_sprite")) or (timeline.property=="BlendFunc" and not _tags[int(timeline.actionTag)].has_meta("source_sprite") and not _tags[int(timeline.actionTag)].has_meta("source_particle")):
			root_node.free(); _clear(); return {"ok":false,"error":"unsupported_timeline_target"}
	add_child(root_node)
	_sync_source_display(self,_source_parent_display())
	return {"ok":true,"nodes":source_nodes.size(),"source":member,"inspection_only":inspection_only,"partial_source_scene":not _requested_source_nodes.is_empty(),"selected_source_offsets":_requested_source_nodes.duplicate(),"unresolved_bindings":unresolved_bindings.duplicate(),"excluded_audio_events":excluded_audio_events.duplicate(true)}

func _validate(node: Dictionary, problems: Array[String], parent_size: Vector2 = Vector2(-1,-1)) -> void:
	if node.get("classname") not in ["Node","SingleNode","Sprite","Panel","ListView","ProjectNode","ImageView","Text","TextBMFont","Button","LoadingBar","Particle","CheckBox","ScrollView","PageView","TextField"]:
		problems.append("unsupported_node:"+str(node.get("classname"))); return
	if not str(node.get("customClassName","")).is_empty(): problems.append("custom_class")
	var binding: Dictionary=_bindings.get(int(node.get("_offset",-1)),{})
	if binding.get("role")=="source_text_field" and node.classname!="TextField":problems.append("source_text_field_original_widget_required")
	var external: bool=int(node.get("_offset",-1)) in _external_texture_nodes
	if external and binding.get("role")!="source_asset_slot":problems.append("external_texture_owner_binding_required")
	if binding.get("role")=="source_asset_slot" and (not external or node.classname!="Sprite" or binding.get("visible")!=false):problems.append("source_asset_slot_declaration_required")
	if binding.get("role")=="source_asset":
		if node.classname not in ["Sprite","ImageView"] or not binding.get("asset_ref") is Dictionary:problems.append("source_asset_node_or_reference_missing")
	if binding.has("visible") and not binding.visible is bool:problems.append("source_visibility_value_missing")
	if binding.has("displaystate") and not binding.displaystate is bool:problems.append("source_displaystate_value_missing")
	if binding.has("selected") and not binding.selected is bool:problems.append("source_selection_value_missing")
	var direct_input: bool=binding.get("input") is Callable and binding.input.is_valid()
	if binding.has("input") and not direct_input:problems.append("source_input_callback_missing")
	if direct_input and node.classname not in ["Panel","ImageView","Text","LoadingBar","ScrollView","ListView","PageView"]:problems.append("source_input_widget_missing")
	var options: Dictionary=node.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	if widget.is_empty(): problems.append("missing_node_options"); return
	if external:_external_texture_tags[int(widget.get("actionTag",0))]=true
	if not widget.get("rotationSkew") is Array or widget.rotationSkew.size()!=2: problems.append("invalid_rotation_skew")
	if not str(widget.get("customProperty","")).is_empty() and not _known_poison_metadata(node,binding,widget) and not _loading_bar_colour_note(node,widget):
		var custom: Variant=_optional_dictionary(str(widget.customProperty))
		# Sound is excluded by the current user scope; retain exact metadata.
		# "transfer" ("true"/"false") is a client flag on Text nodes (e.g.
		# MessBoxHUD Text_Line); CSLoader keeps it as user data only, so it
		# selects no pixels, font or layout. Retain it as metadata.
		if not custom is Dictionary or custom.is_empty():problems.append("custom_property")
		else:
			for key: Variant in custom:
				if not custom[key] is String:problems.append("custom_property")
				elif key=="transfer":
					if custom[key] not in ["true","false"] or node.get("classname") not in ["Text","TextBMFont"]:problems.append("custom_property")
				# "tone" ("#rrggbb") is the client's grade colour note on a card
				# root Panel (Change_Card_A_<grade> Panel_Root); CSLoader keeps
				# it as user data only, so it selects no pixels. Retain it.
				elif key=="tone":
					if node.get("classname")!="Panel" or not RegEx.create_from_string("^#[0-9A-Fa-f]{6}$").search(custom[key]):problems.append("custom_property")
				# "textid" is the client's localisation row of the authored
				# Korean text (the Clan tabs carry it); kept as metadata only.
				elif key=="textid":
					if not str(custom[key]).is_valid_int():problems.append("custom_property")
				elif key not in ["soundid","touchsoundid"]:problems.append("custom_property")
	for field: String in ["frameEvent","callBackType","callBackName"]:
		if widget.get(field)!=null and not str(widget[field]).is_empty():
			# CSLoader locates a handler by callbackName; a serialized default
			# type (often Click) with no name supplies no callback to locate.
			# It must not block a passive original image/text node. Actual
			# buttons, touches and named callbacks retain their own guards.
			if field=="callBackType" and str(widget.get("callBackName","")).is_empty():continue
			# A frame event naming only a sound (e.g. Clan_Tab_Join_Info
			# Nd_Symbol {"EventSound":...}) plays no picture: sound is outside
			# the current scope, so the node is kept as authored.
			if field=="frameEvent":
				var event: Variant=_optional_dictionary(str(widget[field]))
				if event is Dictionary and not (event as Dictionary).is_empty() and (event as Dictionary).keys()==["EventSound"]:continue
			if inspection_only or binding.get("role") not in ["button","checkbox"]:unresolved_bindings.append(str(widget.name)+":"+field+":"+str(widget[field]))
			var connected_callback: bool=binding.get("role") in ["button","checkbox"] and ((binding.get("activate") is Callable and binding.activate.is_valid()) or binding.get("displaystate")==false)
			var declared_type: bool=field=="callBackType" and (str(widget[field])=="Click" or (str(widget[field])=="Event" and binding.get("role")=="checkbox"))
			var declared_name: bool=field=="callBackName" and str(binding.get("callback_name",""))==str(widget[field]) and str(widget.get("callBackType","")) in ["Click","Event"]
			var source_touch: bool=direct_input and ((field=="callBackType" and str(widget[field])=="Touch") or (field=="callBackName" and str(widget.get("callBackType",""))=="Touch" and str(binding.get("callback_name",""))==str(widget[field])))
			if not inspection_only and not (source_touch or (connected_callback and (declared_type or declared_name))):problems.append("unconnected_source_callback:"+field)
	if direct_input and not bool(widget.get("touchEnabled",false)):problems.append("source_input_not_declared")
	if bool(widget.get("touchEnabled",false)):
		if inspection_only or (not direct_input and binding.get("role") not in ["button","checkbox","source_scroll","source_list","consume","source_text_field"]):unresolved_bindings.append(str(widget.name)+":source_input")
		if not inspection_only and not direct_input and binding.get("role") not in ["button","checkbox","source_scroll","source_list","consume","source_text_field"]: problems.append("unconnected_source_input")
	if node.classname=="TextField":
		if binding.get("role")!="source_text_field" or not binding.get("editor") is LineEdit:problems.append("source_text_field_existing_editor_binding_required")
	if node.classname=="CheckBox":
		if inspection_only or binding.get("role")!="checkbox":unresolved_bindings.append(str(widget.name)+":original_checkbox_service_binding")
		if not inspection_only and not (binding.get("role")=="checkbox" and ((binding.get("activate") is Callable and binding.activate.is_valid()) or binding.get("displaystate")==false)):problems.append("unconnected_source_checkbox")
		if bool(widget.flipX) or bool(widget.flipY):problems.append("unverified_checkbox_flip")
	if node.classname=="Button":
		if inspection_only or binding.get("role")!="button":unresolved_bindings.append(str(widget.name)+":original_button_service_binding")
		if not inspection_only and not (binding.get("role")=="button" and ((binding.get("activate") is Callable and binding.activate.is_valid()) or binding.get("displaystate")==false)): problems.append("unconnected_source_button")
		if str(options.get("text","")).contains("\n"): problems.append("unsupported_button_text_layout")
	if node.classname in ["Text","TextBMFont"]:
		if inspection_only or binding.get("role") not in ["static_source_text","source_text"]:unresolved_bindings.append(str(widget.name)+":source_text_requires_live_binding")
		if not inspection_only and binding.get("role") not in ["static_source_text","source_text"]: problems.append("unconnected_source_text")
		if binding.get("role")=="source_text" and not binding.get("text") is String:problems.append("source_text_value_missing")
		if node.classname=="Text" and int(options.get("fontSize",0))<=0:problems.append("invalid_source_font_size")
		if node.classname=="TextBMFont" and (bool(widget.ignoreSize) or bool(widget.flipX) or bool(widget.flipY)):problems.append("unimplemented_bitmap_intrinsic_size_or_flip")
	if node.classname=="LoadingBar":
		var connected: bool=binding.get("role")=="source_percent" and (binding.get("percent") is int or binding.get("percent") is float) and is_finite(float(binding.percent))
		if binding.get("role")=="source_percent" and not connected:problems.append("source_percent_value_missing")
		if not connected:unresolved_bindings.append(str(widget.name)+":source_percent_requires_live_binding")
		if not inspection_only and not connected:problems.append("unconnected_source_percent")
	if node.classname=="ScrollView":
		var connected: bool=not bool(widget.touchEnabled) or (binding.get("role")=="source_scroll" and binding.get("input") is Callable and binding.input.is_valid())
		if not connected:unresolved_bindings.append(str(widget.name)+":original_scroll_input_binding")
		if not inspection_only and not connected:problems.append("unconnected_original_scroll_input")
		if binding.has("position") and not binding.position is Vector2:problems.append("source_scroll_position_invalid")
	if node.classname=="PageView":
		# This host supplies actual original Layout renderers explicitly. A
		# serialized page list needs its own loader contract before activation.
		if not node.get("children",[]).is_empty():problems.append("source_page_view_serialized_pages_not_connected")
		if not inspection_only and (binding.get("role")!="source_pages" or not direct_input):problems.append("unconnected_original_page_view")
	if node.classname=="ListView":
		# The caller explicitly identifies the authored rows it is consuming.
		# Merely loading a list or rendering placeholder text is not a live
		# row contract. New templates/data/selection are never manufactured.
		var row_offsets: Array=[]
		for child: Dictionary in node.get("children",[]):row_offsets.append(int(child._offset))
		var connected: bool=binding.get("role")=="source_list" and binding.get("row_offsets") is Array and binding.row_offsets==row_offsets
		if not connected:unresolved_bindings.append(str(widget.name)+":original_item_template_and_data_binding")
		if not inspection_only and not connected:problems.append("unconnected_list_content")
		if not inspection_only and bool(widget.touchEnabled) and not direct_input:problems.append("unconnected_original_list_input")
		if binding.has("position") and not binding.position is Vector2:problems.append("source_list_position_invalid")
	if node.classname=="ProjectNode":
		var connected: bool=binding.get("role")=="project" and binding.get("bindings") is Dictionary
		if binding.has("source_node_offsets"):
			if not binding.source_node_offsets is Array:problems.append("source_project_node_scope_invalid")
			else:
				for offset: Variant in binding.source_node_offsets:
					if typeof(offset)!=TYPE_INT:problems.append("source_project_node_scope_invalid")
		if not connected:unresolved_bindings.append(str(widget.name)+":project_scene_binding")
		if not inspection_only and not connected:problems.append("unconnected_project_scene")
	var layout: Dictionary=widget.get("layoutComponent",{}) if widget.get("layoutComponent") is Dictionary else {}
	for field: String in ["positionXPercentEnabled","positionYPercentEnabled","sizeXPercentEnable","sizeYPercentEnable","stretchHorizontalEnabled","stretchVerticalEnabled"]:
		if int(layout.get(field,0))!=0 and not _percent_size_baked(field,layout,widget,parent_size): problems.append("layout_constraint:"+field)
	if node.classname=="Sprite" and _blend(options) not in BLEND.PAIRS: problems.append("unsupported_blend")
	var own_size: Variant=widget.get("size")
	var child_parent: Vector2=Vector2(float(own_size[0]),float(own_size[1])) if own_size is Array and own_size.size()==2 else Vector2(-1,-1)
	for child: Dictionary in node.get("children",[]): _validate(child,problems,child_parent)

## A percent size whose authored size already equals parent size x percent (the
## editor's own result, e.g. NpcDialogue_All Text_TalkEnd) draws unchanged in a
## fixed-size parent; any other percent/stretch constraint stays unsupported.
static func _percent_size_baked(field: String, layout: Dictionary, widget: Dictionary, parent_size: Vector2) -> bool:
	if field not in ["sizeXPercentEnable","sizeYPercentEnable"] or parent_size.x<=0 or parent_size.y<=0: return false
	var size: Variant=widget.get("size")
	if not size is Array or size.size()!=2: return false
	var axis: int=0 if field=="sizeXPercentEnable" else 1
	var percent: float=float(layout.get("sizeXPercent" if axis==0 else "sizeYPercent",-1.0))
	return percent>0.0 and absf(float(size[axis])-parent_size[axis]*percent)<=0.5

## A LoadingBar's designer colour note (e.g. Change_Popup_Dispatch_Info
## Bar_HP " Red:#D80900 Sky:#29D6FF gray:#7F7F7F") is plain user data for
## CSLoader; it selects no pixels, texture or percent. Retain it as metadata.
static func _loading_bar_colour_note(node: Dictionary, widget: Dictionary) -> bool:
	if node.get("classname")!="LoadingBar":return false
	return RegEx.create_from_string("^\\s*([A-Za-z]+:#[0-9A-Fa-f]{6}\\s*)+$").search(str(widget.get("customProperty","")))!=null

func _known_poison_metadata(node: Dictionary, binding: Dictionary, widget: Dictionary) -> bool:
	if _text_line_spacing_metadata(node,widget):return true
	# Cocos3.6 NodeReader stores this exact UserData in ObjectExtensionData;
	# it does not select/render these alternate colors. Preserve raw metadata
	# and the actual serialized green color; allow no general custom shader.
	const PALETTE=" Red:#D80900 Sky:#29D6FF gray:#7F7F7F"
	return source_member=="UI/Main/Hud_CharInfo.csb" and source_pack.manifest.get("files",{}).get(source_member,{}).get("sha256","")=="9532ebdf565004332c1a566ee9f7fbf839aaa580b2db3600a187633820c7d805" and node.get("_offset")==39796 and node.classname=="LoadingBar" and str(widget.get("customProperty",""))==PALETTE and binding.get("stock_custom_property_metadata")==PALETTE and binding.get("role")=="source_percent"

func _build(source: Dictionary) -> Node2D:
	var options: Dictionary=source.options
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	if source.classname in ["Panel","ListView","ScrollView","PageView"] and bool(options.get("backGroundScale9Enabled",false)):
		widget=widget.duplicate(true)
		widget.size=options.scale9Size.duplicate()
	if source.classname=="ProjectNode" and not str(options.get("fileName","")).is_empty():
		var member: String=str(options.fileName)
		if not member.begins_with("UI/"):member="UI/"+member
		var nested=get_script().new()
		nested._project_ancestry=_project_ancestry.duplicate()
		nested._project_ancestry.append(source_member)
		nested._project_root_options=widget.duplicate(true)
		var project_binding: Dictionary=_bindings.get(int(source._offset),{})
		if project_binding.has("visible"):nested._project_root_options.visible=project_binding.visible
		# A nested original ProjectNode can consume an explicit partial child
		# scope. The native parent properties still apply to that child's root.
		# Omitting this field retains ordinary whole-child strict loading.
		if project_binding.get("source_node_offsets") is Array:
			nested._requested_source_nodes.assign(project_binding.source_node_offsets)
		var result: Dictionary=nested.configure(source_pack,member,inspection_only,_bindings.get(int(source._offset),{}).get("bindings",{}))
		if not result.ok:
			_build_error="project_scene_rejected:"+member+":"+str(result)
			nested.free();return null
		# The original loader initially pauses the inner action at frame zero.
		nested.set_meta("source_inner_action_speed",float(options.innerActionSpeed))
		nested.seek_frame(0.0)
		nested.stop()
		var actual_root: Node2D=nested.get_child(0)
		source_nodes[int(source._offset)]=actual_root
		var action_tag: int=int(widget.actionTag)
		if action_tag!=0:
			if _tags.has(action_tag):nested.free();return null
			_tags[action_tag]=actual_root
		actual_root.set_meta("source_project_player",nested)
		actual_root.set_meta("original_project_source",{"scene":source_member,"node_offset":int(source._offset),"child_scene":member})
		for unresolved: String in nested.unresolved_bindings:unresolved_bindings.append(member+":"+unresolved)
		var child_origin: Node=actual_root.get_node("SourceContentOrigin")
		for child: Dictionary in source.get("children",[]):
			var built: Node2D=_build(child)
			if built==null:nested.free();return null
			child_origin.add_child(built)
		return nested
	var node:=Node2D.new()
	node.name=str(widget.name)
	node.set_meta("source_size",widget.size.duplicate())
	node.set_meta("original_custom_property",str(widget.get("customProperty","")))
	node.set_meta("source_scale",widget.scale.duplicate())
	node.set_meta("source_rotation",widget.rotationSkew.duplicate())
	# CCNode::getNodeToParentTransform with the Y axis reflected for Godot.
	# Preserve the two distinct serialized rotation/skew angles.
	var rx: float=deg_to_rad(float(widget.rotationSkew[0]))
	var ry: float=deg_to_rad(float(widget.rotationSkew[1]))
	var sx: float=float(widget.scale[0])
	var sy: float=float(widget.scale[1])
	node.transform=Transform2D(Vector2(cos(ry)*sx,sin(ry)*sx),Vector2(-sin(rx)*sy,cos(rx)*sy),Vector2(widget.position[0],-widget.position[1]))
	node.visible=bool(_bindings.get(int(source._offset),{}).get("visible",widget.visible))
	node.z_index=int(widget.zOrder)
	var color: Array=widget.color
	node.modulate=Color.WHITE
	node.set_meta("source_rgba",[int(color[1]),int(color[2]),int(color[3]),int(widget.alpha)])
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
	if not inspection_only and _bindings.get(int(source._offset),{}).get("role")=="consume":
		var input_area:=Control.new()
		input_area.position=Vector2(0,-float(widget.size[1]))
		input_area.size=Vector2(widget.size[0],widget.size[1])
		input_area.mouse_filter=Control.MOUSE_FILTER_STOP
		origin.add_child(input_area)
	var direct_binding: Dictionary=_bindings.get(int(source._offset),{})
	if not inspection_only and source.classname not in ["ScrollView","PageView"] and direct_binding.get("input") is Callable and direct_binding.input.is_valid():
		var input_area:=Control.new()
		input_area.name="OriginalSourceInput"
		input_area.position=Vector2(0,-float(widget.size[1]))
		input_area.size=Vector2(widget.size[0],widget.size[1])
		input_area.mouse_filter=Control.MOUSE_FILTER_STOP
		input_area.gui_input.connect(direct_binding.input)
		origin.add_child(input_area)
	if source.classname=="CheckBox":
		var checkbox=preload("res://scripts/ui/original_ui/source_checkbox.gd").new()
		var configured: Dictionary=checkbox.configure(source_pack,options)
		if not configured.ok:
			_build_error=str(configured.error);checkbox.free();node.free();return null
		origin.add_child(checkbox)
		node.set_meta("source_checkbox",checkbox)
		var binding: Dictionary=_bindings.get(int(source._offset),{})
		if binding.has("displaystate"):checkbox.set_source_state("normal" if binding.displaystate else "disabled")
		if binding.has("selected"):checkbox.set_selected(binding.selected)
		if not inspection_only and binding.get("role")=="checkbox" and binding.get("activate") is Callable and binding.activate.is_valid():checkbox.bind_activation(binding.activate,Vector2(widget.size[0],widget.size[1]),bool(widget.touchEnabled))
	if source.classname=="Button":
		var button=preload("res://scripts/ui/original_ui/source_button.gd").new()
		# A caller may supply the live title of an authored button title.
		var button_options: Dictionary=options
		var title_binding: Variant=_bindings.get(int(source._offset),{}).get("title")
		if title_binding is String and not str(options.get("text","")).is_empty():
			button_options=options.duplicate()
			button_options.text=title_binding
		var configured: Dictionary=button.configure(source_pack,button_options,_original_button_title_stays_invisible(widget))
		if not configured.ok:
			_build_error=str(configured.error)+":"+str(widget.name)
			button.free();node.free();return null
		origin.add_child(button)
		node.set_meta("source_button",button)
		var binding: Dictionary=_bindings.get(int(source._offset),{})
		if binding.has("displaystate"):button.set_source_state("normal" if binding.displaystate else "disabled")
		if not inspection_only and binding.get("role")=="button" and binding.get("activate") is Callable and binding.activate.is_valid():button.bind_activation(binding.activate,Vector2(widget.size[0],widget.size[1]),bool(widget.touchEnabled))
	if source.classname=="Particle":
		var emitter=preload("res://scripts/ui/original_ui/source_particle.gd").new()
		var configured: Dictionary=emitter.configure(source_pack,options)
		if not configured.ok:
			_build_error=str(configured.error);emitter.free();node.free();return null
		origin.add_child(emitter)
		node.set_meta("source_particle",emitter)
	if source.classname=="LoadingBar":
		var bar=preload("res://scripts/ui/original_ui/source_loading_bar.gd").new()
		var percent_binding: Dictionary=_bindings.get(int(source._offset),{})
		var percent_options: Dictionary=options.duplicate(true)
		if percent_binding.get("role")=="source_percent":percent_options.percent=percent_binding.percent
		var configured: Dictionary=bar.configure(source_pack,percent_options)
		if not configured.ok:
			_build_error=str(configured.error);bar.free();node.free();return null
		origin.add_child(bar)
		node.set_meta("source_loading_bar",bar)
	if source.classname=="TextField":
		var field_binding: Dictionary=_bindings.get(int(source._offset),{})
		var field_font: FontFile=source_pack.font(options.fontResource)
		var field=preload("res://scripts/ui/original_ui/source_text_field.gd").new()
		var prepared: Dictionary=field.configure(field_font,options,Vector2(widget.size[0],widget.size[1]),field_binding.get("editor"))
		if not prepared.get("ok",false):
			_build_error=str(prepared.get("error"));field.free();node.free();return null
		origin.add_child(field)
		node.set_meta("source_text_field",field)
	if source.classname=="Text":
		var font_value: FontFile=source_pack.font(options.fontResource)
		if font_value==null and str(options.fontResource.get("path","")).is_empty() and source_pack.has_method("declared_system_font"):
			font_value=source_pack.declared_system_font(str(options.get("fontName","")))
		if font_value==null:
			_build_error="original_font_unavailable:"+str(widget.name); node.free(); return null
		var text_binding: Dictionary=_bindings.get(int(source._offset),{})
		var text_value: String=str(text_binding.text) if text_binding.get("role")=="source_text" else str(options.text)
		for index: int in range(text_value.length()):
			if not text_value[index].strip_edges().is_empty() and not font_value.has_char(text_value.unicode_at(index)):
				_build_error="original_font_glyph_missing:"+str(widget.name); node.free(); return null
		var label=preload("res://scripts/ui/original_ui/source_text.gd").new()
		label.name="OriginalText"
		node.set_meta("source_text",label)
		var text_options: Dictionary=options.duplicate(true)
		text_options.text=text_value
		text_options["_cocos_wrap"]=text_binding.get("cocos_wrap",false)
		var text_custom: Variant=_optional_dictionary(str(widget.get("customProperty","")))
		if text_custom is Dictionary and text_custom.get("linespacing") is Dictionary:text_options["_line_spacing"]=float(text_custom.linespacing.get("kr",0))
		# A plain number (Hud_TracesOrim_Skill card text) is one spacing for every language.
		elif text_custom is Dictionary and typeof(text_custom.get("linespacing")) in [TYPE_INT,TYPE_FLOAT]:text_options["_line_spacing"]=float(text_custom.linespacing)
		var text_result: Dictionary=label.configure(font_value,text_options,Vector2(widget.size[0],widget.size[1]))
		if not text_result.ok:
			_build_error=str(text_result.error)+":"+str(widget.name);label.free();node.free();return null
		origin.add_child(label)
	if source.classname=="TextBMFont":
		var font_result: Dictionary=source_pack.bitmap_font(options.fileNameData)
		if not font_result.get("ok",false):
			_build_error=str(font_result.get("error","source_bitmap_font_unavailable"))+":"+str(widget.name)
			node.free();return null
		var text_binding: Dictionary=_bindings.get(int(source._offset),{})
		var text_options: Dictionary=options.duplicate(true)
		if text_binding.get("role")=="source_text":text_options.text=text_binding.text
		var label=preload("res://scripts/ui/original_ui/source_bitmap_text.gd").new()
		var configured: Dictionary=label.configure(font_result.font_data,text_options,Vector2(widget.size[0],widget.size[1]))
		if not configured.get("ok",false):
			_build_error=str(configured.get("error","source_bitmap_text_unavailable"))+":"+str(widget.name)
			label.free();node.free();return null
		label.name="OriginalBitmapText"
		origin.add_child(label)
		node.set_meta("source_bitmap_text",label)
	var bound_texture: Texture2D
	if source.classname in ["ImageView","Sprite"]:
		bound_texture=_node_texture(source,options.fileNameData)
		var excluded: bool=bool(_resolved_assets.get(int(source._offset),{}).get("excluded_from_connection",false))
		var pending: bool=_bindings.get(int(source._offset),{}).get("role")=="source_asset_slot"
		if bound_texture==null and not excluded and not pending:node.free();return null
		if excluded:node.set_meta("source_asset_excluded",true)
		if pending:
			node.set_meta("source_asset_slot",true)
			node.set_meta("source_asset_pending",true)
	if source.classname=="ImageView" and bound_texture!=null:
		var texture: Texture2D=bound_texture
		var picture: Control
		if bool(options.scale9Enabled):
			var nine=preload("res://scripts/ui/original_ui/source_scale9.gd").new()
			# A caller may stretch a scale-9 panel to its live content (the
			# client sizes list cards to their rows); the anchor is kept.
			var nine_size: Variant=_bindings.get(int(source._offset),{}).get("size")
			var configured: Dictionary=nine.configure(texture,nine_size if nine_size is Vector2 else Vector2(widget.size[0],widget.size[1]),options.capInsets)
			if not configured.ok:
				_build_error=str(configured.error)+":"+str(widget.name)
				nine.free(); node.free(); return null
			picture=nine
		else:
			var flat:=TextureRect.new()
			flat.texture=texture
			flat.material=MATERIAL.original_default(texture)
			if flat.material==null:
				_build_error="original_material_unavailable";flat.free();node.free();return null
			flat.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			flat.stretch_mode=TextureRect.STRETCH_SCALE
			picture=flat
		picture.name="OriginalImage"
		picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		picture.size=Vector2(widget.size[0],widget.size[1])
		picture.position=Vector2(0,-float(widget.size[1]))
		# A stretched scale-9 panel keeps its authored top-left and grows
		# right / down (list cards sized to their rows).
		var stretched: Variant=_bindings.get(int(source._offset),{}).get("size")
		if stretched is Vector2 and bool(options.scale9Enabled):picture.size=stretched
		if bool(widget.flipX): picture.scale.x=-1; picture.position.x=float(widget.size[0])
		if bool(widget.flipY): picture.scale.y=-1; picture.position.y=0
		origin.add_child(picture)
		node.set_meta("source_image",picture)
	if source.classname=="Sprite":
		var texture: Texture2D=bound_texture
		var sprite:=Sprite2D.new()
		sprite.name="OriginalPixels"
		sprite.texture=texture
		sprite.centered=false
		sprite.position.y=-texture.get_height() if texture!=null else -float(widget.size[1])
		sprite.flip_h=bool(widget.flipX)
		sprite.flip_v=bool(widget.flipY)
		if texture!=null:sprite.material=BLEND.material(texture,_blend(options))
		if texture!=null and sprite.material==null:
			_build_error="original_material_unavailable";sprite.free();node.free();return null
		node.set_meta("source_blend",_blend(options))
		var destination:=SPRITE_BACK_BUFFER.new()
		origin.add_child(destination)
		origin.add_child(sprite)
		destination.track(sprite)
		node.set_meta("source_sprite",sprite)
		node.set_meta("source_anchor",widget.anchorPoint)
		node.set_meta("source_origin",origin)
		if texture!=null and _bindings.get(int(source._offset),{}).get("role")=="source_asset":origin.position=Vector2(-float(widget.anchorPoint[0])*texture.get_width(),float(widget.anchorPoint[1])*texture.get_height())
		_texture_refs[int(source._offset)]=options.fileNameData.duplicate(true)
	if _resolved_assets.has(int(source._offset)) and not bool(_resolved_assets[int(source._offset)].get("pending_original_pixels",false)):node.set_meta("source523_original_asset",_resolved_assets[int(source._offset)].duplicate(true))
	var child_origin: Node=origin
	if source.classname in ["Panel","ListView","ScrollView","PageView"] and bool(options.clipEnabled):
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
	if source.classname in ["Panel","ListView","ScrollView","PageView"]:
		var background=preload("res://scripts/ui/original_ui/source_panel.gd").new()
		var configured: Dictionary=background.configure(source_pack,options,Vector2(widget.size[0],widget.size[1]))
		if not configured.ok:
			_build_error=str(configured.error);background.free();node.free();return null
		child_origin.add_child(background)
		node.set_meta("source_panel",background)
	if source.classname=="ScrollView":
		var scroll=preload("res://scripts/ui/original_ui/source_scroll.gd").new()
		scroll.configure(options,Vector2(widget.size[0],widget.size[1]))
		child_origin.add_child(scroll)
		node.set_meta("source_scroll",scroll)
		var scroll_binding: Dictionary=_bindings.get(int(source._offset),{})
		if scroll_binding.has("position"):
			var positioned: Dictionary=scroll.set_source_position(scroll_binding.position)
			if not positioned.ok:_build_error=str(positioned.error);node.free();return null
		if not inspection_only and bool(widget.touchEnabled):scroll.bind_input(scroll_binding.input)
		child_origin=scroll.content
	if source.classname=="PageView" and not inspection_only:
		var pages=preload("res://scripts/ui/original_ui/source_page_view.gd").new()
		var configured: Dictionary=pages.configure(Vector2(widget.size[0],widget.size[1]),direct_binding.input)
		if not configured.get("ok",false):
			_build_error=str(configured.get("error","source_page_view_configuration_failed"));pages.free();node.free();return null
		child_origin.add_child(pages)
		node.set_meta("source_pages",pages)
	var list_items: Array[Dictionary]=[]
	var list_nodes: Array[Node2D]=[]
	if source.classname=="ListView":
		var inner:=Node2D.new()
		inner.name="SourceOriginalListRows"
		child_origin.add_child(inner)
		child_origin=inner
		node.set_meta("source_list_content",inner)
	for child: Dictionary in source.children:
		var built: Node2D=_build(child)
		if built==null: node.free(); return null
		child_origin.add_child(built)
		if source.classname=="ListView":
			# CSLoader inserts Widget children as custom items. A non-Widget
			# child requires its exact loader semantics before it can render.
			if child.classname not in ["Panel","ListView","ImageView","Button","Text","TextBMFont","LoadingBar"]:
				_build_error="unverified_original_list_child:"+str(child.classname);node.free();return null
			var item_options: Dictionary=child.options.get("widgetOptions",child.options)
			list_items.append({"size":built.get_meta("source_size"),"anchor":item_options.anchorPoint,"ignore_size":bool(item_options.ignoreSize)})
			list_nodes.append(built)
	if not list_items.is_empty():
		var arranged: Dictionary=preload("res://scripts/ui/original_ui/source_list_layout.gd").arrange(options,Vector2(widget.size[0],widget.size[1]),list_items)
		if not arranged.ok:
			_build_error=str(arranged.error);node.free();return null
		child_origin.position=arranged.inner_position
		for index: int in range(list_nodes.size()):
			list_nodes[index].position=arranged.positions[index]
			list_nodes[index].z_index=index
		node.set_meta("source_list_layout",arranged)
	if source.classname=="ListView":
		var list_binding: Dictionary=_bindings.get(int(source._offset),{})
		if list_binding.has("position"):
			var position_value: Vector2=list_binding.position
			if not position_value.is_finite():_build_error="source_list_position_invalid";node.free();return null
			child_origin.position=Vector2(position_value.x,-position_value.y)
	return node

func _node_texture(source: Dictionary, original_reference: Dictionary) -> Texture2D:
	var binding: Dictionary=_bindings.get(int(source._offset),{})
	if binding.get("role")=="source_asset_slot":
		_resolved_assets[int(source._offset)]={"pending_original_pixels":true}
		return null
	if binding.get("role")!="source_asset":return source_pack.texture(original_reference,true)
	var resolved: Dictionary=preload("res://scripts/ui/original_ui/source_asset_pixels.gd").resolve(binding.asset_ref)
	if not resolved.get("ok",false):
		_build_error=str(resolved.get("error","source_image_unavailable"))
		return null
	_resolved_assets[int(source._offset)]=resolved.evidence
	return resolved.texture

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
	_entered_frames.clear()
	_seek_frame(frame_number)

func _seek_frame(frame_number: float) -> void:
	_frame=frame_number
	var action: Dictionary=source_tree.get("action",{}) if source_tree.get("action") is Dictionary else {}
	for timeline: Dictionary in action.get("timeLines",[]):
		var selected: Dictionary={}
		var following: Dictionary={}
		# Read live frames once. Keep the last equal predecessor and first
		# equal successor, including unordered serialized timelines.
		for raw: Dictionary in timeline.frames:
			var value: Dictionary=_frame_value(raw)
			var at: float=float(value.frameIndex)
			if at<=frame_number:
				if selected.is_empty() or at>=float(selected.frameIndex): selected=value
			elif at>frame_number and (following.is_empty() or at<float(following.frameIndex)): following=value
		if selected.is_empty(): continue
		var ratio: float=0.0
		if not following.is_empty() and bool(selected.get("tween",false)):
			ratio=clampf((frame_number-float(selected.frameIndex))/(float(following.frameIndex)-float(selected.frameIndex)),0.0,1.0)
			var easing: Dictionary=selected.get("easingData",{}) if selected.get("easingData") is Dictionary else {}
			ratio=EASING.sample(int(easing.get("type",0)),ratio,easing.get("points",[]))
		else: following=selected
		var target: Node2D=_tags.get(int(timeline.actionTag))
		if target==null: continue
		# An original-owner dummy declaration omits pixels, not its source
		# node or unrelated controls. A later texture/blend track cannot revive
		# that excluded resource by displaying a source sample instead.
		if bool(target.get_meta("source_asset_excluded",false)) and timeline.property in ["FileData","BlendFunc"]:continue
		if timeline.property=="FrameEvent":
			var key: int=int(timeline._offset)
			if _entered_frames.get(key,-1)!=int(selected._offset):
				_entered_frames[key]=int(selected._offset)
				var event_callback: Variant=_bindings.get("frame_events",{}).get(int(selected._offset))
				var in_clip: bool=int(selected.frameIndex)>=int(_clip.get("startIndex",0)) and int(selected.frameIndex)<=int(_clip.get("endIndex",action.get("duration",0)))
				if not inspection_only and is_inside_tree() and in_clip and not _audio_frame_offsets.has(int(selected._offset)) and event_callback is Callable and event_callback.is_valid():
					event_callback.call(str(selected.value))
					if is_queued_for_deletion():return
		elif timeline.property=="ActionValue":
			var key: int=int(timeline._offset)
			if _entered_frames.get(key,-1)!=int(selected._offset):
				_entered_frames[key]=int(selected._offset)
				var nested: Node2D=target.get_meta("source_project_player")
				var span: Dictionary=_inner_range(nested,selected)
				nested._clip=span
				nested._loop=int(selected.innerActionType)==0
				nested.seek_frame(float(span.startIndex))
				nested._playing=int(selected.innerActionType)!=2
		elif timeline.property=="Position":
			var a: Array=selected.postion
			var b: Array=following.postion
			target.position=Vector2(lerpf(a[0],b[0],ratio),-lerpf(a[1],b[1],ratio))
		elif timeline.property=="CColor":
			var a: Array=selected.color
			var b: Array=following.color
			# Cocos ColorFrame affects RGB; the separate Alpha track owns opacity.
			var rgba: Array=target.get_meta("source_rgba")
			target.set_meta("source_rgba",[int(lerpf(a[1],b[1],ratio)),int(lerpf(a[2],b[2],ratio)),int(lerpf(a[3],b[3],ratio)),rgba[3]])
		elif timeline.property=="BlendFunc":
			if target.has_meta("source_sprite"):
				var sprite: Sprite2D=target.get_meta("source_sprite")
				if str(target.get_meta("source_blend"))!=_blend(selected):
					sprite.material=BLEND.material(sprite.texture,_blend(selected))
					target.set_meta("source_blend",_blend(selected))
			elif target.has_meta("source_particle"):
				target.get_meta("source_particle").set_source_blend(_blend(selected))
		elif timeline.property=="AnchorPoint":
			# CCFrame::AnchorPointFrame::onEnter is discrete, without tweening.
			var anchor: Array=selected.scale
			var extent: Array=target.get_meta("source_size")
			if target.has_meta("source_sprite"):
				var texture: Texture2D=target.get_meta("source_sprite").texture
				if texture!=null:extent=[texture.get_width(),texture.get_height()]
			target.set_meta("source_anchor",anchor.duplicate())
			target.get_node("SourceContentOrigin").position=Vector2(-float(anchor[0])*float(extent[0]),float(anchor[1])*float(extent[1]))
		elif timeline.property=="Alpha":
			var rgba: Array=target.get_meta("source_rgba")
			rgba[3]=int(lerpf(float(selected.value),float(following.value),ratio))
			target.set_meta("source_rgba",rgba)
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
			var texture: Texture2D=source_pack.texture(selected.textureFile,true)
			if texture==null: _playing=false; return
			if sprite.texture!=texture:
				sprite.texture=texture
				sprite.material=BLEND.material(texture,str(target.get_meta("source_blend")))
			sprite.position.y=-texture.get_height()
			var anchor: Array=target.get_meta("source_anchor")
			var origin: Node2D=target.get_meta("source_origin")
			origin.position=Vector2(-float(anchor[0])*texture.get_width(),float(anchor[1])*texture.get_height())

	_sync_source_display(self,_source_parent_display())

func _process(delta: float) -> void:
	if not _playing or _clip.is_empty(): return
	var started: int=FRAME_HITCH.now()
	var nested: int=FRAME_HITCH.nested()
	_advance_playback(delta)
	FRAME_HITCH.add_self("ui_animation",started,nested)

func _advance_playback(delta: float) -> void:
	# Cocos ActionTimeline uses a 60-frame clock; source speed is preserved.
	var speed_value: float=float(get_meta("source_inner_action_speed",source_tree.get("action",{}).get("speed",1.0)))
	var next: float=_frame+delta*60.0*speed_value
	# Upstream ActionTimeline::step resets to the start at >= end; it does
	# not carry a late frame's overshoot into the next loop.
	if next>=float(_clip.endIndex):
		if _loop and int(_clip.endIndex)>int(_clip.startIndex):
			next=float(_clip.startIndex)
			_entered_frames.clear()
		else: next=float(_clip.endIndex); _playing=false
	_seek_frame(next)

func _original_button_title_stays_invisible(widget: Dictionary) -> bool:
	# Pack JSON numbers arrive as floats; the original fields are integers.
	if not _whole(widget.get("alpha")) or int(widget.alpha)!=0 or not _whole(widget.get("actionTag")) or int(widget.actionTag)==0:return false
	var action: Variant=source_tree.get("action",{})
	if action==null:return true
	if not action is Dictionary:return false
	for timeline: Dictionary in action.get("timeLines",[]):
		if int(timeline.get("actionTag",0))!=int(widget.actionTag) or timeline.get("property")!="Alpha":continue
		var frames: Variant=timeline.get("frames")
		if not frames is Array or frames.is_empty():return false
		for frame: Dictionary in frames:
			var value: Dictionary=_frame_value(frame)
			if value.get("_type")!="IntFrame" or not _whole(value.get("value")) or int(value.value)!=0:return false
	return true

static func _whole(value: Variant) -> bool:
	return typeof(value)==TYPE_INT or (typeof(value)==TYPE_FLOAT and value==floorf(value))

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
	_resolved_assets.clear()

static func _blend(options: Dictionary) -> String:
	var value: Variant=options.get("blendFunc")
	if not value is Array or value.size()!=2: return ""
	return str(int(value[0]))+":"+str(int(value[1]))

## Korean-client Text line spacing ({"linespacing":{"kr":n,...}} or a plain
## {"linespacing":n}, optionally with sound ids): source_text applies the
## "kr" value (or the number) between lines.
static func _text_line_spacing_metadata(node: Dictionary, widget: Dictionary) -> bool:
	if node.get("classname")!="Text":return false
	var custom: Variant=_optional_dictionary(str(widget.get("customProperty","")))
	if not custom is Dictionary or not custom.has("linespacing"):return false
	if typeof(custom.linespacing) in [TYPE_INT,TYPE_FLOAT]:pass
	elif not custom.linespacing is Dictionary or typeof(custom.linespacing.get("kr",0)) not in [TYPE_INT,TYPE_FLOAT]:return false
	for key: Variant in custom:
		if key!="linespacing" and (key not in ["soundid","touchsoundid"] or not custom[key] is String):return false
	return true

static func _optional_dictionary(text: String) -> Variant:
	var parser:=JSON.new()
	if parser.parse(text)!=OK:return null
	return parser.data

func _inner_range(nested: Node2D, frame: Dictionary) -> Dictionary:
	if int(frame.innerActionType)==2:
		return {"name":"source_single_frame","startIndex":int(frame.singleFrameIndex),"endIndex":int(frame.singleFrameIndex)} if int(frame.singleFrameIndex)>=0 else {}
	var name_value: String=str(frame.currentAniamtionName)
	var span: Dictionary={}
	if name_value=="-- ALL --":
		span={"name":name_value,"startIndex":0,"endIndex":int(nested.source_tree.action.duration)}
	else:
		for clip: Dictionary in nested.source_tree.animationList:
			if clip.name==name_value:span=clip.duplicate(true);break
	if span.is_empty():return {}
	# InnerActionFrame limits the child range by the remaining parent duration.
	var difference: int=int(source_tree.action.duration)-int(frame.frameIndex)-int(span.endIndex)+int(span.startIndex)
	if difference<0:span.endIndex+=difference
	if int(span.endIndex)<int(span.startIndex):return {}
	return span

func _source_parent_display() -> Color:
	var ancestor: Node=get_parent()
	while ancestor!=null:
		if ancestor.has_meta("source_display_color"):return ancestor.get_meta("source_display_color")
		ancestor=ancestor.get_parent()
	return Color.WHITE
func _sync_source_display(node: Node, inherited: Color) -> void:
	var display: Color=inherited
	if node.has_meta("source_rgba"):
		var rgba: Array=node.get_meta("source_rgba")
		# NodeReader enables both cascades. CCNode truncates each 8-bit level.
		display=Color(float(int(rgba[0]*inherited.r8/255.0))/255.0,float(int(rgba[1]*inherited.g8/255.0))/255.0,float(int(rgba[2]*inherited.b8/255.0))/255.0,float(int(rgba[3]*inherited.a8/255.0))/255.0)
		node.set_meta("source_display_color",display)
		if node.has_meta("source_sprite"):MATERIAL.bind_display(node.get_meta("source_sprite"),display)
		if node.has_meta("source_image"):MATERIAL.bind_tree_display(node.get_meta("source_image"),display)
		if node.has_meta("source_loading_bar"):MATERIAL.bind_tree_display(node.get_meta("source_loading_bar"),display)
		if node.has_meta("source_panel"):node.get_meta("source_panel").set_source_display(display)
		if node.has_meta("source_text"):node.get_meta("source_text").modulate=display
		if node.has_meta("source_text_field"):node.get_meta("source_text_field").modulate=display
		if node.has_meta("source_bitmap_text"):node.get_meta("source_bitmap_text").set_source_display(display)
		if node.has_meta("source_checkbox"):node.get_meta("source_checkbox").set_source_display(display)
		if node.has_meta("source_button"):node.get_meta("source_button").set_source_display(display)
	for child: Node in node.get_children():_sync_source_display(child,display)


func project_player(project_offsets: Array) -> Dictionary:
	# Untyped: callers pass literals of untyped consts (typed Array[int] rejected them).
	# Exact offsets keep repeated child CSBs distinct. Callers can update
	# their declared live fields/popups without searching by display labels
	# or creating an alternate node tree. An empty path denotes this root.
	var player: Variant=self
	for raw_offset: Variant in project_offsets:
		var offset: int = int(raw_offset)
		if player._bindings.get(offset,{}).get("role")!="project":return {"ok":false,"error":"source_project_binding_missing","offset":offset}
		var node: Node2D=player.source_nodes.get(offset)
		if not is_instance_valid(node) or not node.has_meta("source_project_player"):return {"ok":false,"error":"source_project_player_missing","offset":offset}
		player=node.get_meta("source_project_player")
		if not is_instance_valid(player) or player.is_queued_for_deletion():return {"ok":false,"error":"source_project_player_unavailable","offset":offset}
	return {"ok":true,"player":player,"source":player.source_member,"inspection_only":player.inspection_only}

func set_bound_text(source_offset: int, value: String) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	if node==null or _bindings.get(source_offset,{}).get("role")!="source_text":return {"ok":false,"error":"source_text_binding_missing"}
	if node.has_meta("source_bitmap_text"):return node.get_meta("source_bitmap_text").set_source_text(value)
	if not node.has_meta("source_text"):return {"ok":false,"error":"source_text_binding_missing"}
	return node.get_meta("source_text").set_source_text(value)

func set_bound_percent(source_offset: int, value: float) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	if node==null or _bindings.get(source_offset,{}).get("role")!="source_percent" or not node.has_meta("source_loading_bar") or not is_finite(value):return {"ok":false,"error":"source_percent_binding_missing"}
	node.get_meta("source_loading_bar").set_source_percent(value)
	return {"ok":true}

func set_bound_visible(source_offset: int, value: bool) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	if node==null or not _bindings.get(source_offset,{}).has("visible"):return {"ok":false,"error":"source_visibility_binding_missing"}
	if value and node.get_meta("source_asset_slot",false):
		var sprite: Sprite2D=node.get_meta("source_sprite",null)
		var scene: Variant=node.get_meta("source_asset_scene") if node.has_meta("source_asset_scene") else null
		var scene_ready: bool=is_instance_valid(scene) and not scene.is_queued_for_deletion() and scene.get_parent()==node
		if sprite==null or (sprite.texture==null and not scene_ready) or node.get_meta("source_asset_pending",true):return {"ok":false,"error":"source_asset_slot_original_pixels_required"}
	node.visible=value
	return {"ok":true}

func activate_authored_component_opacity() -> Dictionary:
	# An actual screen owner may open the referenced component in its own
	# serialized root opacity, instead of the enclosing editor ProjectNode's
	# preview opacity. Take no caller-supplied alpha or animation policy.
	if inspection_only or source_pack==null or source_tree.is_empty() or _project_root_options.is_empty():return {"ok":false,"error":"source_project_component_required"}
	var original: Dictionary=source_pack.layout_source(source_member)
	if original.is_empty():original=source_pack.scene(source_member)
	var sha: String=str(source_pack.manifest.get("files",{}).get(source_member,{}).get("sha256",""))
	if sha.is_empty() or original.get("_source_sha256")!=sha:return {"ok":false,"error":"source_component_identity_required"}
	var raw: Dictionary=original.get("nodeTree",{})
	if raw.get("classname")!="Node" or raw.get("_offset")!=source_tree.get("nodeTree",{}).get("_offset"):return {"ok":false,"error":"source_component_original_root_required"}
	var options: Dictionary=raw.get("options",{})
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var alpha: Variant=widget.get("alpha")
	# A whole-number opacity read back as a float is the same original value.
	if not _whole(alpha) or int(alpha)<0 or int(alpha)>255:return {"ok":false,"error":"source_component_original_opacity_required"}
	alpha=int(alpha)
	var root: Variant=source_nodes.get(int(raw._offset))
	if not root is Node2D or root.get_meta("original_ui_source",{}).get("scene")!=source_member:return {"ok":false,"error":"source_component_loaded_root_required"}
	var rgba: Array=root.get_meta("source_rgba",[])
	if rgba.size()!=4:return {"ok":false,"error":"source_component_display_state_required"}
	rgba=rgba.duplicate();rgba[3]=alpha
	root.set_meta("source_rgba",rgba)
	root.set_meta("source_component_opacity_activation",{"member":source_member,"sha256":sha,"authored_component_alpha":alpha,"parent_preview_alpha":_project_root_options.get("alpha"),"animation_policy_inferred":false})
	_sync_source_display(self,_source_parent_display())
	return {"ok":true,"authored_component_alpha":alpha,"animation_policy_inferred":false,"source_fields_modified":false}

func set_bound_source_asset_result(source_offset: int, owner_result: Dictionary) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	if node==null or _bindings.get(source_offset,{}).get("role")!="source_asset_slot" or not node.has_meta("source_sprite"):return {"ok":false,"error":"source_asset_slot_binding_missing"}
	var sprite: Sprite2D=node.get_meta("source_sprite")
	_detach_source_scene(node)
	var consumed: Dictionary=preload("res://scripts/ui/original_ui/source_asset_pixels.gd").consume_owner_result(owner_result)
	if not consumed.get("ok",false) or consumed.get("texture")==null:
		sprite.texture=null
		node.visible=false
		node.set_meta("source_asset_pending",true)
		return consumed
	var texture: Texture2D=consumed.texture
	var material: ShaderMaterial=BLEND.material(texture,node.get_meta("source_blend"))
	if material==null:
		sprite.texture=null
		node.visible=false
		node.set_meta("source_asset_pending",true)
		return {"ok":false,"error":"original_material_unavailable"}
	# Sprite content size follows its actual source texture. Preserve the
	# serialized node position/scale/anchor; no guessed image fit or map ratio.
	sprite.texture=texture
	sprite.material=material
	sprite.position.y=-texture.get_height()
	var anchor: Array=node.get_meta("source_anchor")
	var origin: Node2D=node.get_meta("source_origin")
	origin.position=Vector2(-float(anchor[0])*texture.get_width(),float(anchor[1])*texture.get_height())
	node.set_meta("source_runtime_texture_size",texture.get_size())
	node.set_meta("source523_original_asset",consumed.evidence.duplicate(true))
	node.set_meta("source_asset_pending",false)
	_resolved_assets[source_offset]=consumed.evidence.duplicate(true)
	MATERIAL.bind_display(sprite,node.get_meta("source_display_color",Color.WHITE))
	return {"ok":true,"texture_assigned":true,"texture":texture,"evidence":consumed.evidence,"original_node_transform_retained":true,"image_info_registration_complete":false}

static func external_scene_slot_contract(pack: RefCounted, member: String, source_offset: int) -> Dictionary:
	if pack==null or source_offset not in pack.manifest.get("externally_bound_texture_nodes",{}).get(member,[]):return {"ok":false,"error":"source_asset_slot_declaration_required"}
	var tree: Dictionary=pack.layout_source(member)
	if tree.is_empty():tree=pack.scene(member)
	var raw: Dictionary=_node_at_offset(tree.get("nodeTree",{}),source_offset)
	if raw.get("classname")!="Sprite":return {"ok":false,"error":"source_asset_slot_original_sprite_required"}
	var options: Dictionary=raw.options
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	var position: Array=widget.position
	var anchor: Array=widget.anchorPoint
	var size: Array=widget.size
	var identity: Dictionary={"member":member,"source_sha256":tree.get("_source_sha256"),"node_offset":source_offset}
	return {"ok":true,"schema":"twilight-native-icon-scene-slot-v1","member":member,"source_sha256":tree.get("_source_sha256"),"manifest_sha256":pack.manifest_sha256,"node_offset":source_offset,"registration_space":"authored_sprite_anchor","original_widget_options":widget.duplicate(true),"original_blend_func":options.get("blendFunc").duplicate(),"stable_component_target":identity,"ui_target_declared_by_original":true,"ui_attachment_frame":{"parent":"actual_source_nodes_entry","node_offset":source_offset,"source_position":position.duplicate(),"source_axes":"x_right_y_up","native_position":Vector2(float(position[0]),-float(position[1])),"native_axes":"x_right_y_down","authored_anchor":anchor.duplicate(),"authored_size":size.duplicate(),"native_preview_content_origin":Vector2(-float(anchor[0])*float(size[0]),float(anchor[1])*float(size[1])),"scene_parent_is_preview_content_origin":false,"root_relation_to_csb_origin_confirmed":false},"fit_or_offset_inferred":false,"original_client_registration_confirmed":false}

func set_bound_source_visual_result(source_offset: int, owner_result: Dictionary) -> Dictionary:
	if owner_result.get("source_scene_descriptor") is Dictionary:return set_bound_source_scene_result(source_offset,owner_result.source_scene_descriptor)
	return set_bound_source_asset_result(source_offset,owner_result)

func set_bound_source_scene_result(source_offset: int, descriptor: Dictionary) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	if node==null or _bindings.get(source_offset,{}).get("role")!="source_asset_slot" or not node.has_meta("source_sprite"):return {"ok":false,"error":"source_asset_slot_binding_missing"}
	var registration: Variant=descriptor.get("registration")
	if not registration is Dictionary:return {"ok":false,"error":"source_scene_original_target_registration_required"}
	var target: Variant=registration.get("target")
	var contract: Dictionary=external_scene_slot_contract(source_pack,source_member,source_offset)
	if not contract.get("ok",false):return contract
	if not target is Dictionary or target.get("member")!=source_member or target.get("source_sha256")!=contract.source_sha256 or target.get("manifest_sha256")!=source_pack.manifest_sha256 or target.get("node_offset")!=source_offset:return {"ok":false,"error":"source_scene_original_target_registration_required","slot_contract":contract}
	var prepared: Dictionary=preload("res://scripts/ui/original_ui/source_asset_scene.gd").prepare(descriptor)
	if not prepared.get("ok",false):return prepared
	var player: Node2D=prepared.player
	# This is the exact authored Sprite anchor node, not its preview texture's
	# bottom-left origin. The owner must prove this registration explicitly.
	# Both the target transform and the identity original CSB root are retained.
	_detach_source_scene(node)
	var sprite: Sprite2D=node.get_meta("source_sprite")
	sprite.texture=null
	node.add_child(player)
	node.set_meta("source_asset_scene",player)
	node.set_meta("source_asset_scene_bindings",descriptor.get("bindings",{}).duplicate(true))
	node.set_meta("source_asset_pending",false)
	var evidence: Dictionary=prepared.duplicate(true)
	evidence.erase("player")
	evidence["target"]=contract
	node.set_meta("source_asset_scene_evidence",evidence)
	_sync_source_display(player,node.get_meta("source_display_color",Color.WHITE))
	return {"ok":true,"source_scene_assigned":true,"player":player,"texture":null,"evidence":evidence,"original_node_transform_retained":true,"runtime_rendering_verified":false}

func bound_source_scene(source_offset: int) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	var player: Variant=node.get_meta("source_asset_scene",null) if node!=null else null
	if not is_instance_valid(player) or player.is_queued_for_deletion():return {"ok":false,"error":"source_asset_scene_not_attached"}
	return {"ok":true,"player":player,"evidence":node.get_meta("source_asset_scene_evidence",{}).duplicate(true)}

func clear_bound_source_scene(source_offset: int) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	if node==null:return {"ok":false,"error":"source_asset_slot_binding_missing"}
	_detach_source_scene(node)
	node.set_meta("source_asset_pending",true)
	node.visible=false
	return {"ok":true,"detached":true,"game_state_written":false}

func reuse_bound_source_scene_from(source_offset: int, previous_renderer: Node2D, previous_offset: int) -> Dictionary:
	# Called only at the final presenter commit for the same existing owned
	# reference/game slot. Keep the actual timeline and particle state rather
	# than inventing a restart or reconstructing it from a copied frame number.
	if not is_instance_valid(previous_renderer) or previous_renderer==self or not previous_renderer.has_method("bound_source_scene"):return {"ok":false,"reused":false}
	var current: Dictionary=bound_source_scene(source_offset)
	var previous: Dictionary=previous_renderer.bound_source_scene(previous_offset)
	if not current.get("ok",false) or not previous.get("ok",false):return {"ok":false,"reused":false}
	for field: String in ["member","manifest_sha256","source_sha256","registration","playback"]:
		if current.evidence.get(field)!=previous.evidence.get(field):return {"ok":false,"reused":false,"reason":"source_scene_descriptor_changed"}
	var node: Node2D=source_nodes.get(source_offset)
	var old_node: Node2D=previous_renderer.get("source_nodes").get(previous_offset)
	var player: Node2D=previous.player
	if node==null or old_node==null or player.get_parent()!=old_node or not player.transform.is_equal_approx(Transform2D.IDENTITY):return {"ok":false,"reused":false}
	var bindings: Dictionary=node.get_meta("source_asset_scene_bindings",{})
	if bindings!=old_node.get_meta("source_asset_scene_bindings",{}):return {"ok":false,"reused":false,"reason":"source_scene_bindings_changed"}
	_detach_source_scene(node)
	old_node.remove_meta("source_asset_scene")
	old_node.remove_meta("source_asset_scene_evidence")
	if old_node.has_meta("source_asset_scene_bindings"):old_node.remove_meta("source_asset_scene_bindings")
	old_node.set_meta("source_asset_pending",true)
	old_node.remove_child(player)
	node.add_child(player)
	node.set_meta("source_asset_scene",player)
	node.set_meta("source_asset_scene_bindings",bindings)
	node.set_meta("source_asset_scene_evidence",previous.evidence.duplicate(true))
	node.set_meta("source_asset_pending",false)
	_sync_source_display(player,node.get_meta("source_display_color",Color.WHITE))
	return {"ok":true,"reused":true,"player":player,"play_restarted":false,"same_player_instance":true,"runtime_preservation_verified":false}

static func _detach_source_scene(node: Node2D) -> void:
	var player: Variant=node.get_meta("source_asset_scene") if node.has_meta("source_asset_scene") else null
	if is_instance_valid(player):
		player.stop()
		player.process_mode=Node.PROCESS_MODE_DISABLED
		if player.get_parent()==node:node.remove_child(player)
		player.queue_free()
	if node.has_meta("source_asset_scene"):node.remove_meta("source_asset_scene")
	if node.has_meta("source_asset_scene_evidence"):node.remove_meta("source_asset_scene_evidence")
	if node.has_meta("source_asset_scene_bindings"):node.remove_meta("source_asset_scene_bindings")

func set_bound_scroll_position(source_offset: int, value: Vector2) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	if node==null or _bindings.get(source_offset,{}).get("role")!="source_scroll" or not node.has_meta("source_scroll"):return {"ok":false,"error":"source_scroll_binding_missing"}
	return node.get_meta("source_scroll").set_source_position(value)

func set_bound_list_position(source_offset: int, value: Vector2) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	if node==null or _bindings.get(source_offset,{}).get("role")!="source_list" or not node.has_meta("source_list_content") or not value.is_finite():return {"ok":false,"error":"source_list_binding_missing"}
	# As with ScrollView, coordinates come from the original caller. No
	# replacement momentum, drag thresholds or row selection are introduced.
	var content: Node2D=node.get_meta("source_list_content")
	content.position=Vector2(value.x,-value.y)
	return {"ok":true}

func set_bound_displaystate(source_offset: int, value: bool) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	var binding: Dictionary=_bindings.get(source_offset,{})
	if node==null or not binding.has("displaystate"):return {"ok":false,"error":"source_displaystate_binding_missing"}
	if value and not (binding.get("activate") is Callable and binding.activate.is_valid()):return {"ok":false,"error":"source_activation_binding_missing"}
	if binding.get("role")=="button" and node.has_meta("source_button"):return node.get_meta("source_button").set_source_state("normal" if value else "disabled")
	if binding.get("role")=="checkbox" and node.has_meta("source_checkbox"):return node.get_meta("source_checkbox").set_source_state("normal" if value else "disabled")
	return {"ok":false,"error":"source_displaystate_binding_missing"}

func set_bound_selected_state(source_offset: int, value: bool) -> Dictionary:
	var node: Node2D=source_nodes.get(source_offset)
	var binding: Dictionary=_bindings.get(source_offset,{})
	if node==null or binding.get("role")!="checkbox" or not binding.has("selected") or not node.has_meta("source_checkbox"):return {"ok":false,"error":"source_selection_binding_missing"}
	return node.get_meta("source_checkbox").set_selected(value)
