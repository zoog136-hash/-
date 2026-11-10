extends Node2D
## Mechanical Cocos2d-x 3.6 UIPageView layout from the supplied engine contract:
## updateAllPagesPosition: page.position=((index-currentIndex)*viewportWidth,0).
## Source: cocos/ui/UIPageView.cpp, cocos2d-x-3.6. No gesture, animation or
## gameplay page policy is implemented. Equal-size original Layouts only.
var _extent: Vector2
var _input_callback: Callable
var _input_area: Control
var _configured: bool=false
var _current_page_index: int=0
var _pages: Dictionary={}

func configure(extent: Vector2, input_callback: Callable) -> Dictionary:
	if _configured:return _fail("source_page_view_already_configured")
	if not extent.is_finite() or extent.x<=0 or extent.y<=0:return _fail("source_page_view_extent_invalid")
	if not input_callback.is_valid():return _fail("source_page_view_existing_input_callback_required")
	_extent=extent
	_input_callback=input_callback
	_input_area=Control.new()
	_input_area.name="OriginalPageViewInput"
	_input_area.position=Vector2(0,-extent.y)
	_input_area.size=extent
	_input_area.mouse_filter=Control.MOUSE_FILTER_STOP
	_input_area.gui_input.connect(_forward_input)
	add_child(_input_area)
	_configured=true
	return {"ok":true,"extent":_extent,"current_page_index":_current_page_index}

func register_original_page(source_renderer: Node2D, panel_offset: int, index: int) -> Dictionary:
	if not _configured:return _fail("source_page_view_not_configured")
	if index<0 or _pages.has(index):return _fail("source_page_view_page_index_invalid_or_registered")
	for page: Dictionary in _pages.values():
		if page.renderer==source_renderer:return _fail("source_page_view_renderer_already_registered")
	var inspected: Dictionary=_original_page(source_renderer,panel_offset)
	if not inspected.get("ok",false):return inspected
	var live: Dictionary=_live_pages()
	if not live.get("ok",false):return live
	if source_renderer.get_parent()!=null and source_renderer.get_parent()!=self:return _fail("source_page_view_renderer_has_another_parent")
	var panel: Node2D=inspected.panel
	var record: Dictionary={"renderer":source_renderer,"panel":panel,"panel_offset":panel_offset,"index":index,"anchor":inspected.anchor,"source_member":inspected.source_member,"original_source_position":inspected.original_source_position,"original_native_position":panel.position,"had_metadata":panel.has_meta("source_page_view_layout"),"previous_metadata":panel.get_meta("source_page_view_layout",null)}
	# All failure paths above leave registered pages and this original intact.
	if source_renderer.get_parent()==null:add_child(source_renderer)
	_pages[index]=record
	_apply_layout()
	# The transparent hit rectangle stays above the original renderers; its
	# caller owns actual input and may register it with existing PointerTransfer.
	move_child(_input_area,get_child_count()-1)
	return {"ok":true,"index":index,"panel_offset":panel_offset,"source_member":inspected.source_member,"engine_source_position":Vector2((index-_current_page_index)*_extent.x,0),"source_fields_modified":false}

func set_page_index(index: int) -> Dictionary:
	if not _configured:return _fail("source_page_view_not_configured")
	if not _pages.has(index):return _fail("source_page_view_page_not_registered")
	var live: Dictionary=_live_pages()
	if not live.get("ok",false):return live
	_current_page_index=index
	_apply_layout()
	return {"ok":true,"current_page_index":index,"registered_page_indices":_pages.keys(),"game_page_policy_applied":false}

func input_control() -> Control:
	return _input_area

func clear_pages() -> void:
	# Explicit teardown restores each caller-owned original. It never frees
	# source renderers, raw CSBs, slot nodes or unrelated resources.
	for page: Dictionary in _pages.values():
		var panel: Variant=page.panel
		if is_instance_valid(panel):
			panel.position=page.original_native_position
			if page.had_metadata:panel.set_meta("source_page_view_layout",page.previous_metadata)
			else:panel.remove_meta("source_page_view_layout")
		var renderer: Variant=page.renderer
		if is_instance_valid(renderer) and renderer.get_parent()==self:remove_child(renderer)
	_pages.clear()
	_current_page_index=0

func _original_page(renderer: Node2D, panel_offset: int) -> Dictionary:
	if not is_instance_valid(renderer) or renderer.is_queued_for_deletion():return _fail("source_page_view_original_renderer_required")
	var script: Script=renderer.get_script()
	if script==null or script.resource_path!="res://scripts/ui/original_ui/sprite_scene.gd":return _fail("source_page_view_actual_source_renderer_required")
	if not renderer.transform.is_equal_approx(Transform2D.IDENTITY):return _fail("source_page_view_renderer_wrapper_not_identity")
	var tree: Variant=renderer.get("source_tree")
	var nodes: Variant=renderer.get("source_nodes")
	var pack: Variant=renderer.get("source_pack")
	var member: Variant=renderer.get("source_member")
	if not tree is Dictionary or not nodes is Dictionary or pack==null or not member is String or member.is_empty():return _fail("source_page_view_loaded_original_required")
	var declared_sha: Variant=pack.manifest.get("files",{}).get(member,{}).get("sha256")
	if not declared_sha is String or declared_sha.is_empty() or tree.get("_source_sha256")!=declared_sha:return _fail("source_page_view_original_identity_missing")
	var root: Variant=tree.get("nodeTree")
	if not root is Dictionary or root.get("classname")!="Node":return _fail("source_page_view_original_root_required")
	var root_widget: Dictionary=_widget(root)
	if not _identity_widget(root_widget) or not _vector(root_widget.get("position"),Vector2.ZERO) or not _vector(root_widget.get("size"),Vector2.ZERO):return _fail("source_page_view_original_root_not_identity")
	var actual_root: Variant=nodes.get(int(root.get("_offset",-1)))
	if not actual_root is Node2D or not actual_root.transform.is_equal_approx(Transform2D.IDENTITY):return _fail("source_page_view_actual_root_not_identity")
	var raw_panel: Dictionary={}
	var matches: int=0
	for child: Dictionary in root.get("children",[]):
		if child.get("_offset")==panel_offset:
			raw_panel=child
			matches+=1
	if matches!=1 or raw_panel.get("classname")!="Panel":return _fail("source_page_view_direct_original_panel_required")
	var widget: Dictionary=_widget(raw_panel)
	# Cocos PageView.addPage keeps the Layout's anchor. Its layout pass
	# changes position and size only; an authored .5 anchor is not anchor0.
	if not _unrotated_widget(widget):return _fail("source_page_view_panel_scale_rotation_unsupported")
	var anchor: Variant=widget.get("anchorPoint")
	if not anchor is Array or anchor.size()!=2 or not Vector2(float(anchor[0]),float(anchor[1])).is_finite():return _fail("source_page_view_original_panel_anchor_missing")
	if not _vector(widget.get("size"),_extent):return _fail("source_page_view_original_page_size_differs")
	var panel: Variant=nodes.get(panel_offset)
	if not panel is Node2D or not _vector(panel.get_meta("source_size",null),_extent):return _fail("source_page_view_actual_panel_size_differs")
	var identity: Variant=panel.get_meta("original_ui_source",{})
	if not identity is Dictionary or identity.get("scene")!=member or identity.get("node_offset")!=panel_offset:return _fail("source_page_view_panel_identity_mismatch")
	var origin: Node=actual_root.get_node_or_null("SourceContentOrigin")
	if not origin is Node2D or not origin.transform.is_equal_approx(Transform2D.IDENTITY) or panel.get_parent()!=origin:return _fail("source_page_view_original_panel_hierarchy_unsupported")
	var source_position: Variant=widget.get("position")
	if not source_position is Array or source_position.size()!=2:return _fail("source_page_view_original_panel_position_missing")
	var native_position:=Vector2(float(source_position[0]),-float(source_position[1]))
	if not panel.transform.x.is_equal_approx(Vector2.RIGHT) or not panel.transform.y.is_equal_approx(Vector2.DOWN) or not panel.position.is_equal_approx(native_position):return _fail("source_page_view_actual_panel_transform_changed")
	var panel_origin: Node=panel.get_node_or_null("SourceContentOrigin")
	var authored_origin:=Vector2(-float(anchor[0])*_extent.x,float(anchor[1])*_extent.y)
	if not panel_origin is Node2D or not panel_origin.transform.is_equal_approx(Transform2D(0.0,authored_origin)):return _fail("source_page_view_original_panel_anchor_changed")
	return {"ok":true,"panel":panel,"source_member":member,"original_source_position":Vector2(float(source_position[0]),float(source_position[1])),"anchor":Vector2(float(anchor[0]),float(anchor[1]))}

func _live_pages() -> Dictionary:
	for page: Dictionary in _pages.values():
		if not is_instance_valid(page.renderer) or not is_instance_valid(page.panel) or page.renderer.is_queued_for_deletion() or page.panel.is_queued_for_deletion():return _fail("source_page_view_registered_original_unavailable")
		if page.renderer.get_parent()!=self:return _fail("source_page_view_registered_renderer_reparented")
	return {"ok":true}

func _apply_layout() -> void:
	for page: Dictionary in _pages.values():
		var source_position:=Vector2((int(page.index)-_current_page_index)*_extent.x,0)
		# The page is laid out by its lower-left corner inside the view; an
		# authored centre anchor (the equipment pages use 0.5,0.5) puts the
		# anchor point half a page in, so the whole page fills the view.
		var anchor: Vector2=page.get("anchor",Vector2.ZERO)
		var native_position:=Vector2(source_position.x+anchor.x*_extent.x,-source_position.y-anchor.y*_extent.y)
		page.panel.position=native_position
		page.panel.set_meta("source_page_view_layout",{"source_member":page.source_member,"panel_offset":page.panel_offset,"index":page.index,"current_page_index":_current_page_index,"original_source_position":page.original_source_position,"original_native_position":page.original_native_position,"engine_source_position":source_position,"engine_native_position":native_position,"viewport_size":_extent,"source_size_unchanged":true,"layout_basis":"Cocos2d-x3.6 UIPageView.updateAllPagesPosition/updateAllPagesSize(equal size)"})

func _forward_input(event: InputEvent) -> void:
	if _input_callback.is_valid():_input_callback.call(event)
	_input_area.accept_event()

static func _widget(node: Dictionary) -> Dictionary:
	var options: Dictionary=node.get("options",{})
	return options.get("widgetOptions",options.get("nodeOptions",options))

static func _identity_widget(widget: Dictionary) -> bool:
	return _vector(widget.get("anchorPoint"),Vector2.ZERO) and _unrotated_widget(widget)

static func _unrotated_widget(widget: Dictionary) -> bool:
	return _vector(widget.get("scale"),Vector2.ONE) and _vector(widget.get("rotationSkew"),Vector2.ZERO) and not bool(widget.get("flipX",false)) and not bool(widget.get("flipY",false))

static func _vector(value: Variant, expected: Vector2) -> bool:
	return value is Array and value.size()==2 and Vector2(float(value[0]),float(value[1])).is_equal_approx(expected)

static func _fail(error: String) -> Dictionary:
	return {"ok":false,"error":error}
