extends RefCounted
## The authored inventory input bar borrows the bag's existing query editor.
## Source result rows and the source cancel/clear action are not inferred.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const PARENT="UI/FloatingUiScene.csb"
const PARENT_SHA="b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8"
const INVENTORY="UI/FloatingUi/Inventory_All.csb"
const INVENTORY_SHA="c2c021fbc49f0699f2002a3f1cb73f523c3dd629bd1df567192dcb7f4da22293"
const MEMBER="UI/FloatingUi/Inventory_Popup_Keypad.csb"
const SHA256="3892e910ad1c6b3e04714f26402ed171a98a08fe3e7e97362cd4fe07a79478d5"
const FIELD=1472
const SOURCE_OFFSETS: Array[int]=[8316,7940,7556,5072,6444,6020,5524,5132,2808,3996,3604,3216,2868,2424,2040,1472]
var _pack: RefCounted
var _bag: WeakRef
var _scene: Node2D
var _renderer: Node2D
var _field: Node2D
var _bounds: Control
var _parent: WeakRef
var last_result: Dictionary={}
var _crafting: bool=false
var _editor_property: String="search_line"
var _member: String=MEMBER
var _member_sha: String=SHA256

func configure(pack: RefCounted, bag: Control) -> Dictionary:
	if not is_instance_valid(bag) or not bag.has_method("_on_search_changed") or not bag.get("search_line") is LineEdit:return _fail("source_inventory_search_existing_owner_required")
	for pair: Array in [[PARENT,PARENT_SHA],[INVENTORY,INVENTORY_SHA],[MEMBER,SHA256]]:
		if pack==null or pack.manifest.get("files",{}).get(pair[0],{}).get("sha256","")!=pair[1]:return _fail("source_inventory_search_original_identity_required")
	if not pack.manifest.get("scenes",{}).has(MEMBER):return _fail("source_inventory_search_original_scope_required")
	_pack=pack
	_bag=weakref(bag)
	_crafting=false;_editor_property="search_line";_member=MEMBER;_member_sha=SHA256
	return {"ok":true,"partial_source_scene":true,"complete_screen_contract":false}

func configure_crafting(pack: RefCounted, owner: Control) -> Dictionary:
	var script: Script=owner.get_script() if is_instance_valid(owner) else null
	if script==null or script.resource_path!="res://scripts/ui/renewal_crafting.gd" or not owner.has_method("_rebuild_listing") or not owner.get("name_filter") is LineEdit:return _fail("source_craft_search_existing_owner_required")
	if not owner.get("name_filter").editable:return _fail("source_craft_search_existing_editor_not_editable")
	for pair: Array in [["UI/ProductionScene.csb","cae6672733b914c0143fe376574e73012b0cd628113002693f0639c877f47328"],["UI/Production/Production_All.csb","328546745405eac58203853570d76e07d9cc95477ac4ecd701d786651e3786ec"],["UI/Production/Production_Popup_Keypad.csb","e4203840af58b4feebc832c4059c1a819f5348085ee3f5b6ecf5a3eb05f82aa8"]]:
		if pack==null or pack.manifest.get("files",{}).get(pair[0],{}).get("sha256")!=pair[1]:return _fail("source_craft_search_original_identity_required")
	_pack=pack;_bag=weakref(owner)
	_crafting=true;_editor_property="name_filter"
	_member="UI/Production/Production_Popup_Keypad.csb"
	_member_sha="e4203840af58b4feebc832c4059c1a819f5348085ee3f5b6ecf5a3eb05f82aa8"
	return {"ok":true,"partial_source_scene":true,"complete_screen_contract":false}

func open(parent: Node) -> Dictionary:
	if is_open():return {"ok":true,"handled":true}
	var bag: Object=_bag.get_ref() if _bag!=null else null
	if not is_instance_valid(parent) or bag==null:return _fail("source_inventory_search_actual_parent_and_owner_required")
	var editor: Variant=bag.get(_editor_property)
	if not editor is LineEdit or not is_instance_valid(editor):return _fail("source_inventory_search_existing_editor_unavailable")
	var bindings: Dictionary={8316:{"role":"consume"},7556:{"role":"consume"},FIELD:{"role":"source_text_field","editor":editor},5072:{"role":"button","activate":Callable(self,"apply_query")},2808:{"role":"button","activate":Callable(self,"_close_requested")},5132:{"role":"static_source_text"},2868:{"role":"static_source_text"}}
	var next:=Scene.new()
	var result: Dictionary
	if _crafting:result=next.configure_project(_pack,"UI/ProductionScene.csb",132,{628:{"role":"project","visible":true,"source_node_offsets":SOURCE_OFFSETS.duplicate(),"bindings":bindings}},[628])
	else:result=next.configure_nodes(_pack,PARENT,[1572],{1572:{"role":"project","source_node_offsets":[728],"bindings":{728:{"role":"project","visible":true,"source_node_offsets":SOURCE_OFFSETS.duplicate(),"bindings":bindings}}}})
	if not result.get("ok",false):next.free();return result
	var project_path: Array[int]=[628] if _crafting else [1572,728]
	var nested: Dictionary=next.project_player(project_path)
	if not nested.get("ok",false):next.free();return nested
	var renderer: Node2D=nested.player
	var field_node: Variant=renderer.get("source_nodes").get(FIELD)
	var field: Variant=(field_node.get_meta("source_text_field") if field_node.has_meta("source_text_field") else null) if is_instance_valid(field_node) else null
	var bounds: Control=_consume_control(renderer,8316)
	if not is_instance_valid(field) or bounds==null:next.free();return _fail("source_inventory_search_original_input_mount_required")
	# Same original inventory parent end state; popup visibility is an
	# explicit response to its own original search entry button, not autoplay.
	if _crafting:
		result=next.activate_authored_component_opacity()
		if result.get("ok",false):result=renderer.activate_authored_component_opacity()
		if not result.get("ok",false):next.free();return result
	else:next.seek_frame(17.0)
	parent.add_child(next)
	next.z_index=151
	_scene=next
	_renderer=renderer
	_field=field
	_bounds=bounds
	result=field.attach_editor()
	if not result.get("ok",false):close();return result
	field.unsupported_input.connect(_unsupported_input)
	parent.tree_exiting.connect(close,CONNECT_ONE_SHOT)
	_parent=weakref(parent)
	last_result={"ok":true,"handled":true,"member":_member,"sha256":_member_sha,"source_project":628 if _crafting else 728,"source_field":FIELD,"same_existing_editor":true,"owner_live_filter_preserved":true,"source_result_rows_connected":false,"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false}
	return last_result.duplicate(true)

func apply_query() -> Dictionary:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	var editor: Control=input_control()
	if bag==null or not is_instance_valid(editor) or editor!=bag.get(_editor_property):return _fail("source_inventory_search_actual_query_owner_required")
	if _crafting:
		var hud: Variant=bag.get("hud")
		var workspace: Variant=hud.get("workspace") if is_instance_valid(hud) else null
		if not is_instance_valid(hud) or hud.get("active_section")!="crafting" or not workspace is Control or not workspace.is_ancestor_of(bag) or not bag.is_visible_in_tree():return _fail("source_craft_search_current_owner_changed")
	if editor.has_method("apply_ime"):editor.call("apply_ime")
	if not is_open():return _fail("source_inventory_search_original_input_became_unavailable")
	# Keep the owner's live text_changed path; explicit Search applies the
	# same current query. No replacement filter, sort or close policy.
	if _crafting:bag.call("_rebuild_listing")
	else:bag.call("_on_search_changed",editor.text)
	return {"ok":true,"owner_callback_invoked":true,"query":editor.text,"game_state_written":false}

func input_control() -> Control:
	return _field.input_control() if is_instance_valid(_field) else null

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion() and _scene.is_inside_tree()

func blocks_point(point: Vector2) -> bool:
	return _contains(_bounds,point) if is_open() else false

func focus_input_at(point: Vector2) -> bool:
	var editor: Control=input_control()
	if not _contains(editor,point):return false
	editor.grab_focus()
	if editor.has_method("edit"):editor.call("edit")
	return true

func presentation() -> Dictionary:
	return {"scene":_scene,"renderer":_renderer,"editor":input_control(),"gesture_bounds":_bounds,"partial_source_scene":true,"complete_screen_contract":false}

func close() -> void:
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if is_instance_valid(parent) and parent.tree_exiting.is_connected(close):parent.tree_exiting.disconnect(close)
	_parent=null
	if is_instance_valid(_field):_field.release_editor()
	_field=null
	_renderer=null
	_bounds=null
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func _close_requested() -> Dictionary:
	close()
	return {"ok":true,"closed":true,"query_reset":false,"game_state_written":false}

func _unsupported_input(reason: Dictionary) -> void:
	last_result=reason.duplicate(true)
	close()

static func _consume_control(renderer: Node2D, offset: int) -> Control:
	var node: Variant=renderer.get("source_nodes").get(offset)
	var origin: Node=node.get_node_or_null("SourceContentOrigin") if is_instance_valid(node) else null
	if origin!=null:
		for child: Node in origin.get_children():
			if child is Control and child.mouse_filter==Control.MOUSE_FILTER_STOP:return child
	return null

static func _contains(control: Control, point: Vector2) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree() or not point.is_finite():return false
	return Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
