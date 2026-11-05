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
	if not is_instance_valid(field_map) or not field_map is Node or typeof(offered)!=TYPE_INT or not label is String or not role is Dictionary:return _remember(_fail("source_world_map_explicit_offered_context_required"))
	var contract: Dictionary=_bindings.build_map_scene(field_map,int(offered),label,role,{"role":"source_scroll","input":Callable(self,"_route_source_input")})
	if not contract.get("ok",false):return _remember(contract)
	var mount: Node2D=_mount.get_ref() if _mount!=null else null
	if not is_instance_valid(mount):return _remember(_fail("source_world_map_original_mount_unavailable"))
	var scene=Scene.new()
	var configured: Dictionary=scene.configure_nodes(_pack,contract.member,contract.source_node_offsets,contract.bindings)
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
	scene.z_index=150
	mount.add_child(scene)
	set_process(true)
	# The original offered row is visible; it has not been selected here.
	# No image or Ratio/Base fields are inferred from current Land/map IDs.
	return _remember({"ok":true,"source_scene_presented":true,"offered_world_id":offered,"selected_world_id":0,"world_auto_selected":false,"image_applied":false,"original_ui_member":contract.member,"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":contract.area_contract.unresolved_fields})

func _route_source_input(event: InputEvent) -> void:
	if not is_open() or not is_instance_valid(_area) or not _input_handler.is_valid():return
	var context: Dictionary={"map_ui":self,"event_space":"original_scroll_input_control_local","source_member":Bindings.AREA,"source_scroll_offset":44388,"cell_projection_performed":false}
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		var node: Node2D=_area.source_nodes.get(44388)
		var scroll: Variant=node.get_meta("source_scroll",null) if node!=null else null
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

func close() -> Dictionary:
	if _bindings!=null:_bindings.close_map()
	_clear_presented()
	return _remember({"ok":true,"closed":true,"game_state_written":false})

func _clear_presented() -> void:
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
