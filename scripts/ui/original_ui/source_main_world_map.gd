extends Node
## Original map scene presentation. Map/image owners supply the offered
## source World/label and existing input policy; this node supplies no World
## default, cell projection, movement, image resolver or replacement artwork.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Bindings=preload("res://scripts/ui/original_ui/source_main_map_bindings.gd")
signal world_image_clicked(payload: Dictionary)
var _pack: RefCounted
var _bindings: RefCounted
var _mount: WeakRef
var _context_provider: Callable
var _input_handler: Callable
var _scene: Node2D
var _area: Node2D
var _field: WeakRef
var _hud: WeakRef
var _native_buttons: Array[WeakRef]=[]
var _touch_button: WeakRef
var _button_touch: int=-1
var _scroll_touch: int=-1
var _scroll_touch_point: Vector2
var last_result: Dictionary={}
var last_input_result: Variant

func configure(pack: RefCounted, hud: Node, mount: Node2D, image_adapter: RefCounted, context_provider: Callable, input_handler: Callable) -> Dictionary:
	if pack==null or not is_instance_valid(mount):return _fail("source_world_map_original_mount_required")
	if image_adapter==null:return _fail("source_world_map_existing_image_adapter_required")
	if not context_provider.is_valid() or not input_handler.is_valid():return _fail("source_world_map_existing_context_and_input_required")
	var bindings=Bindings.new()
	var configured: Dictionary=bindings.configure(pack,hud,image_adapter)
	if not configured.get("ok",false):return configured
	_pack=pack
	_hud=weakref(hud)
	_bindings=bindings
	_mount=weakref(mount)
	_context_provider=context_provider
	_input_handler=input_handler
	_bindings.world_image_clicked.connect(func(payload: Dictionary) -> void: world_image_clicked.emit(payload))
	_bindings.world_selection_changed.connect(func(result: Dictionary) -> void: last_result["selection"]=result.duplicate(true))
	set_process(false)
	return {"ok":true,"registered":true,"source_pack_has_map_scene":pack.manifest.get("scenes",{}).has(Bindings.MAP_SCENE),"world_auto_selected":false,"complete_screen_contract":false}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func toggle() -> Dictionary:
	return close() if is_open() else open()

func open() -> Dictionary:
	if is_open():return {"ok":true,"already_open":true,"complete_screen_contract":false}
	if _bindings==null:return _remember(_fail("source_world_map_not_configured"))
	var supplied: Variant=_context_provider.call()
	if not supplied is Dictionary:return _remember(_fail("source_world_map_existing_context_invalid"))
	if supplied.has("ok") and not supplied.get("ok",false):return _remember(supplied)
	var field_map: Variant=supplied.get("field_map")
	var offered: Variant=supplied.get("offered_world_id")
	var label: Variant=supplied.get("world_label")
	var role: Variant=supplied.get("role_declaration",{})
	# Current523's actual field may be RefCounted. Keep that same Object,
	# source metadata and definition for the existing image/map owners.
	# A Node wrapper would change the contract and is not required here.
	if not field_map is Object or not is_instance_valid(field_map) or typeof(offered)!=TYPE_INT or not label is String or not role is Dictionary:return _remember(_fail("source_world_map_explicit_offered_context_required"))
	var contract: Dictionary=_bindings.build_map_scene(field_map,int(offered),label,role,{"role":"source_scroll","input":Callable(self,"_route_source_input")})
	if not contract.get("ok",false):return _remember(contract)
	var mount: Node2D=_mount.get_ref() if _mount!=null else null
	if not is_instance_valid(mount):return _remember(_fail("source_world_map_original_mount_unavailable"))
	var scene=Scene.new()
	var scope: Array[int]=[]
	scope.assign(contract.source_node_offsets)
	var configured: Dictionary=scene.configure_nodes(_pack,contract.member,scope,contract.bindings)
	if not configured.get("ok",false):
		scene.free()
		return _remember(configured)
	var child: Dictionary=scene.project_player([132,31656])
	if not child.get("ok",false):
		scene.free()
		return _remember(child)
	var area_bound: Dictionary=_bindings.bind_area_presented(child.player,field_map)
	if not area_bound.get("ok",false):
		scene.free()
		return _remember(area_bound)
	var root_bound: Dictionary=_bindings.bind_map_presented(scene,Callable(self,"_clear_presented"))
	if not root_bound.get("ok",false):
		scene.free()
		return _remember(root_bound)
	_scene=scene
	_area=child.player
	_field=weakref(field_map)
	_native_buttons.clear()
	var map_all: Dictionary=scene.project_player([132])
	# A dynamic call gets no typed literal from another script's constant.
	var row_path: Array[int]=[Bindings.AREA_AUTHORED_ROW]
	var map_row: Dictionary=child.player.project_player(row_path)
	if map_all.get("ok",false):_register_native_button(map_all.player,29552)
	if map_row.get("ok",false):
		_register_native_button(map_row.player,7440)
		_register_native_button(map_row.player,4508)
	scene.z_index=150
	mount.add_child(scene)
	if not get_window().focus_exited.is_connected(_cancel_native_input):get_window().focus_exited.connect(_cancel_native_input)
	if not get_viewport().size_changed.is_connected(_cancel_native_input):get_viewport().size_changed.connect(_cancel_native_input)
	set_process(true)
	# The original offered row is visible; it has not been selected here.
	# No image or Ratio/Base fields are inferred from current Land/map IDs.
	return _remember({"ok":true,"source_scene_presented":true,"offered_world_id":offered,"selected_world_id":0,"world_auto_selected":false,"image_applied":false,"original_ui_member":contract.member,"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":contract.area_contract.unresolved_fields})

func _register_native_button(renderer: Node2D, offset: int) -> void:
	var node: Variant=renderer.get("source_nodes").get(offset)
	var button: Variant=(node.get_meta("source_button") if node.has_meta("source_button") else null) if is_instance_valid(node) else null
	if is_instance_valid(button) and button.has_method("handle_native_touch"):_native_buttons.append(weakref(button))

func _input(event: InputEvent) -> void:
	if not is_open() or not _scene.is_visible_in_tree() or (not event is InputEventScreenTouch and not event is InputEventScreenDrag):return
	if _native_touch_blocked():
		_cancel_native_input()
		return
	var captured: Object=_touch_button.get_ref() if _touch_button!=null else null
	if captured!=null:
		if event.index==_button_touch:
			captured.call("handle_native_touch",event,event.position)
			if event is InputEventScreenTouch and not event.pressed:
				_touch_button=null
				_button_touch=-1
		get_viewport().set_input_as_handled()
		return
	if _scroll_touch>=0:
		if event.index==_scroll_touch:
			_scroll_touch_point=event.position
			_forward_native_scroll(event)
			if event is InputEventScreenTouch and not event.pressed:_scroll_touch=-1
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventScreenTouch or not event.pressed or event.canceled:return
	for reference: WeakRef in _native_buttons:
		var button: Object=reference.get_ref()
		if button==null:continue
		var accepted: Dictionary=button.call("handle_native_touch",event,event.position)
		if not accepted.get("handled",false):continue
		_touch_button=weakref(button)
		_button_touch=event.index
		get_viewport().set_input_as_handled()
		return
	var control: Control=_scroll_control()
	if control!=null and _inside_source_control(control,event.position):
		_scroll_touch=event.index
		_scroll_touch_point=event.position
		_forward_native_scroll(event)
		get_viewport().set_input_as_handled()

func _forward_native_scroll(event: InputEvent) -> void:
	var control: Control=_scroll_control()
	if control==null:return
	var inverse: Transform2D=control.get_global_transform_with_canvas().affine_inverse()
	var local: Variant=event.duplicate()
	local.position=inverse*event.position
	if local is InputEventScreenDrag:
		local.relative=inverse.basis_xform(event.relative)
		local.velocity=inverse.basis_xform(event.velocity)
	# Same callback/context as mouse GUI input; the existing map owner keeps
	# native finger identity, click/drag decisions and cell/movement policy.
	_route_source_input(local)

func _scroll_control() -> Control:
	if not is_instance_valid(_area):return null
	var node: Variant=_area.get("source_nodes").get(44388)
	var scroll: Variant=(node.get_meta("source_scroll") if node.has_meta("source_scroll") else null) if is_instance_valid(node) else null
	return scroll.input_control() if is_instance_valid(scroll) and scroll.has_method("input_control") else null

func _native_touch_blocked() -> bool:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var root: Node=hud.get_node_or_null("Root") if hud!=null else null
	if root==null:return true
	for child: Node in root.get_children():
		if child.name=="TwilightConfirmation" and child is CanvasItem and child.is_visible_in_tree() and not child.is_queued_for_deletion():return true
	return false

func _cancel_native_input() -> void:
	_touch_button=null
	_button_touch=-1
	for reference: WeakRef in _native_buttons:
		var button: Object=reference.get_ref()
		if button!=null:button.call("cancel_native_touch")
	if _scroll_touch>=0:
		var canceled:=InputEventScreenTouch.new()
		canceled.index=_scroll_touch
		canceled.position=_scroll_touch_point
		canceled.pressed=false
		canceled.canceled=true
		_scroll_touch=-1
		if is_open():_forward_native_scroll(canceled)

static func _inside_source_control(control: Control, point: Vector2) -> bool:
	if not control.is_visible_in_tree() or not Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point):return false
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents and not Rect2(Vector2.ZERO,parent.size).has_point(parent.get_global_transform_with_canvas().affine_inverse()*point):return false
		parent=parent.get_parent()
	return true

func _route_source_input(event: InputEvent) -> void:
	if not is_open() or not is_instance_valid(_area) or not _input_handler.is_valid():return
	var context: Dictionary={"map_ui":self,"event_space":"original_scroll_input_control_local","source_member":Bindings.AREA,"source_scroll_offset":44388,"scroll_geometry":scroll_geometry(),"cell_projection_performed":false}
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		var node: Node2D=_area.get("source_nodes").get(44388)
		var scroll: Variant=(node.get_meta("source_scroll") if node.has_meta("source_scroll") else null) if node!=null else null
		var control: Control=scroll.input_control() if is_instance_valid(scroll) and scroll.has_method("input_control") else null
		if control==null:
			last_input_result=_fail("source_world_map_original_input_extent_missing")
			return
		var viewport_point: Vector2=control.get_global_transform_with_canvas()*event.position
		context["viewport_point"]=viewport_point
		context["world_image_pixel"]=_bindings.viewport_to_world_image_pixel(viewport_point)
	# Existing map owner decides click/drag/release and may call submit below
	# or set_scroll_position. The UI does not manufacture another gesture.
	last_input_result=_input_handler.call(event,context)

func image_pixel_at(viewport_point: Vector2) -> Dictionary:
	if _bindings==null:return _fail("source_world_map_not_configured")
	return _bindings.viewport_to_world_image_pixel(viewport_point)

func select_offered_world(world_id: int, source_cell: Variant=null) -> Dictionary:
	if not is_open() or world_id!=last_result.get("offered_world_id"):return _fail("source_world_map_current_authored_offer_required")
	# Only an explicit caller selection. Open() never invokes this method.
	return _bindings.select_world(world_id,source_cell)

func submit_world_image_click(viewport_point: Vector2, actual_event_metadata: Dictionary={}) -> Dictionary:
	if _bindings==null:return _fail("source_world_map_not_configured")
	return _bindings.submit_world_image_click(viewport_point,actual_event_metadata)

func set_scroll_position(source_position: Vector2) -> Dictionary:
	if not is_instance_valid(_area):return _fail("source_world_map_original_area_unavailable")
	return _area.set_bound_scroll_position(44388,source_position)

func scroll_geometry() -> Dictionary:
	if not is_instance_valid(_area):return _fail("source_world_map_original_area_unavailable")
	var node: Node2D=_area.get("source_nodes").get(44388)
	var scroll: Variant=(node.get_meta("source_scroll") if node.has_meta("source_scroll") else null) if node!=null else null
	var control: Control=scroll.input_control() if is_instance_valid(scroll) and scroll.has_method("input_control") else null
	if control==null or not is_instance_valid(scroll.content):return _fail("source_world_map_original_input_extent_missing")
	return {"ok":true,"source_member":Bindings.AREA,"source_scroll_offset":44388,"viewport_extent":control.size,"input_local_space":"control_top_left_x_right_y_down","input_to_viewport":control.get_global_transform_with_canvas(),"authored_inner_size":scroll.original_inner_size,"content_position":Vector2(scroll.content.position.x,-scroll.content.position.y),"content_position_space":"cocos_parent_x_right_y_up","cell_projection_performed":false}

func close() -> Dictionary:
	if _bindings!=null:_bindings.close_map()
	_clear_presented()
	return _remember({"ok":true,"closed":true,"game_state_written":false})

func _clear_presented() -> void:
	_cancel_native_input()
	_native_buttons.clear()
	if is_inside_tree():
		if get_window().focus_exited.is_connected(_cancel_native_input):get_window().focus_exited.disconnect(_cancel_native_input)
		if get_viewport().size_changed.is_connected(_cancel_native_input):get_viewport().size_changed.disconnect(_cancel_native_input)
	if is_instance_valid(_scene):
		_scene.visible=false
		_scene.process_mode=Node.PROCESS_MODE_DISABLED
		_scene.queue_free()
	_scene=null
	_area=null
	_field=null
	set_process(false)

func _process(_delta: float) -> void:
	if _field==null or not is_instance_valid(_field.get_ref()):close()

func _exit_tree() -> void:
	close()

func _remember(result: Dictionary) -> Dictionary:
	last_result=result.duplicate(true)
	return result

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
