extends RefCounted
## Authored skill-details controls and tooltip fields for the actual skill owner.
## No skill selection, casting, learning, cooldown, image lookup or save logic.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const MEMBER="UI/FloatingUi/Skill_All.csb"
const SHA="5f2f800c5e461c372cc2b9de13b9c742f9879115fb1028c937668f054e00f099"
const PARENT="UI/FloatingUiScene.csb"
const PARENT_SHA="b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8"
const PROJECT=10236
const SEARCH=11160
const NORMAL=12120
const DISABLED=11212
const OFFSETS: Array[int]=[11160,12172,11264]
const TIP="UI/ToolTip/ToolTip_HudType_Skill.csb"
const TIP_SHA="1d7512e791b02975dc6be141f443d5f98c746c752ab6c7717ef3998013b32dc2"
const TIP_PARENT="UI/ToolTipScene.csb"
const TIP_PARENT_SHA="9304dcb5730fba9a155f73a291a6e87f96768156cee972929b003386e3904a1d"
const TIP_PROJECT=728
const TIP_OFFSETS: Array[int]=[18856,18428,16328,15964,316]
var _pack: RefCounted
var _owner: WeakRef
var _scene: Node2D
var _tip: Node2D
var _tip_id: String=""
var _enabled: bool=false
var _mount_attempted: bool=false
var last_result: Dictionary={}

func configure(pack: RefCounted, owner: Control) -> Dictionary:
	close()
	if not is_instance_valid(owner):return _fail("source_skill_existing_owner_required")
	for spec: Array in [[MEMBER,SHA,OFFSETS],[TIP,TIP_SHA,TIP_OFFSETS]]:
		if pack==null or pack.manifest.get("files",{}).get(spec[0],{}).get("sha256")!=spec[1]:return _fail("source_skill_original_component_identity_required")
		var tree: Dictionary=pack.scene(spec[0])
		for offset: int in spec[2]:
			if _node_at(tree.get("nodeTree",{}),offset).is_empty():return _fail("source_skill_original_scope_required")
	for spec: Array in [[PARENT,PARENT_SHA],[TIP_PARENT,TIP_PARENT_SHA]]:
		if pack.manifest.get("files",{}).get(spec[0],{}).get("sha256")!=spec[1] or pack.layout_source(spec[0]).get("_source_sha256")!=spec[1]:return _fail("source_skill_original_parent_identity_required")
	_pack=pack
	_owner=weakref(owner)
	owner.visibility_changed.connect(_visibility_changed)
	owner.tree_exiting.connect(close)
	return {"ok":true,"configured":true,"partial_source_scene":true}

func refresh(parent: Node) -> Dictionary:
	var model: Dictionary=_model()
	if not model.get("ok",false):close();return model
	if not is_instance_valid(parent):return _fail("source_skill_actual_mount_required")
	if not is_instance_valid(_scene):
		if _mount_attempted:return last_result.duplicate(true)
		_mount_attempted=true
		var next:=Scene.new()
		var bindings: Dictionary={SEARCH:{"role":"button","activate":Callable(self,"open_detail"),"displaystate":model.selected},NORMAL:{"visible":model.selected},DISABLED:{"visible":not model.selected},12172:{"role":"static_source_text"},11264:{"role":"static_source_text"}}
		var result: Dictionary=next.configure_project(_pack,PARENT,PROJECT,bindings,OFFSETS)
		if not result.get("ok",false):next.free();last_result=result;return result
		result=next.activate_authored_component_opacity()
		if not result.get("ok",false):next.free();last_result=result;return result
		parent.add_child(next)
		_scene=next
		_enabled=model.selected
	if _enabled!=model.selected:
		var result: Dictionary=_scene.set_bound_displaystate(SEARCH,model.selected)
		if result.get("ok",false):result=_scene.set_bound_visible(NORMAL,model.selected)
		if result.get("ok",false):result=_scene.set_bound_visible(DISABLED,not model.selected)
		if not result.get("ok",false):close();return result
		_enabled=model.selected
	if is_instance_valid(_tip):
		if not model.selected or model.id!=_tip_id:close_detail()
		else:
			var result: Dictionary=_tip.set_bound_text(18428,model.name)
			if result.get("ok",false):result=_tip.set_bound_text(16328,model.class_text)
			if result.get("ok",false):result=_tip.set_bound_visible(15228,not model.class_text.is_empty())
			if not result.get("ok",false):close_detail();return result
	last_result={"ok":true,"handled":true,"selected_id":model.id,"details_enabled":model.selected,"tooltip_open":is_instance_valid(_tip),"source_layout_retained":true,"game_state_written":false,"partial_source_scene":true,"complete_screen_contract":false}
	return last_result.duplicate(true)

func open_detail() -> Dictionary:
	var model: Dictionary=_model()
	if not model.get("ok",false) or not model.get("selected",false) or not is_instance_valid(_scene) or not _scene.is_inside_tree() or _scene.is_queued_for_deletion():return _fail("source_skill_actual_selected_detail_required")
	close_detail()
	var next:=Scene.new()
	var bindings: Dictionary={256:{"visible":true},18428:{"role":"source_text","text":model.name},15176:{"role":"source_list","row_offsets":[15228],"input":Callable(self,"_consume_class_list")},15228:{"visible":not model.class_text.is_empty()},15964:{"role":"static_source_text"},16328:{"role":"source_text","text":model.class_text},316:{"role":"button","activate":Callable(self,"close_detail")}}
	var result: Dictionary=next.configure_project(_pack,TIP_PARENT,TIP_PROJECT,bindings,TIP_OFFSETS)
	if not result.get("ok",false):next.free();last_result=result;return result
	result=next.activate_authored_component_opacity()
	if not result.get("ok",false):next.free();last_result=result;return result
	_scene.get_parent().add_child(next)
	next.z_index=_scene.z_index+1
	_tip=next
	_tip_id=model.id
	return {"ok":true,"opened":true,"selected_id":_tip_id,"name_and_class_connected":true,"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false}

func close_detail() -> Dictionary:
	var previous: Node2D=_tip
	_tip=null
	_tip_id=""
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():previous.hide();previous.queue_free()
	return {"ok":true,"closed":true,"selection_changed":false,"game_state_written":false}

func presentation() -> Dictionary:
	var scenes: Array=[]
	if is_instance_valid(_scene):scenes.append(_scene)
	if is_instance_valid(_tip):scenes.append(_tip)
	return {"additional_scenes":scenes,"foreground_scenes":[_tip] if is_instance_valid(_tip) else [],"selected_id":_tip_id,"partial_source_scene":true,"complete_screen_contract":false}

func blocks_point(point: Vector2) -> bool:
	if not point.is_finite():return false
	for scene: Node2D in presentation().additional_scenes:
		for offset: int in [SEARCH,316]:
			var node: Variant=scene.source_nodes.get(offset)
			var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) else null
			var control: Variant=button.get("_input_area") if is_instance_valid(button) else null
			if control is Control and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point):return true
	if is_instance_valid(_tip):
		var list: Variant=_tip.source_nodes.get(15176)
		var control: Variant=list.get_node_or_null("SourceContentOrigin/OriginalSourceInput") if is_instance_valid(list) else null
		if control is Control and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point):return true
	return false

func close() -> void:
	close_detail()
	var owner: Object=_owner.get_ref() if _owner!=null else null
	if is_instance_valid(owner):
		if owner.visibility_changed.is_connected(_visibility_changed):owner.visibility_changed.disconnect(_visibility_changed)
		if owner.tree_exiting.is_connected(close):owner.tree_exiting.disconnect(close)
	_owner=null
	_pack=null
	var previous: Node2D=_scene
	_scene=null
	_mount_attempted=false
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():previous.hide();previous.queue_free()

func _visibility_changed() -> void:
	var model: Dictionary=_model()
	if not model.get("ok",false):close()

func _model() -> Dictionary:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	if not owner is Control or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_visible_in_tree():return _fail("source_skill_live_owner_required")
	var script: Script=owner.get_script()
	var hud: Variant=owner.get("hud")
	var workspace: Variant=hud.get("workspace") if is_instance_valid(hud) else null
	if script==null or script.resource_path!="res://scripts/ui/renewal_skills.gd" or not workspace is Control or not workspace.is_ancestor_of(owner) or hud.get("active_section")!="skills":return _fail("source_skill_actual_workspace_owner_required")
	var record: Variant=owner.get("selected")
	var rows: Variant=owner.get("filtered")
	if not record is Dictionary or not rows is Array:return _fail("source_skill_existing_selection_model_required")
	if record.is_empty():return {"ok":true,"selected":false,"id":"","name":"","class_text":""}
	var id: Variant=record.get("id")
	if not id is String or id.is_empty():return {"ok":true,"selected":false,"id":"","name":"","class_text":"","selection_status":"source_skill_existing_selected_id_required"}
	var matches: Array=[]
	for row: Dictionary in rows:
		if row.get("id")==id:matches.append(row)
	if matches.size()!=1 or matches[0]!=record or not record.get("name") is String or record.name.is_empty():return {"ok":true,"selected":false,"id":"","name":"","class_text":"","selection_status":"source_skill_unique_actual_selected_row_required"}
	var class_text: String=record["class"] if record.get("class") is String else ""
	return {"ok":true,"selected":true,"id":id,"name":record.name,"class_text":class_text,"record":record.duplicate(true)}

func _consume_class_list(_event: InputEvent) -> void:
	if is_instance_valid(_tip) and _tip.is_inside_tree():_tip.get_viewport().set_input_as_handled()

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
