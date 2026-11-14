extends RefCounted
## Caller glue for the existing PR270 map-image adapter, never a replacement
## image loader or coordinate projector. No old pack prerequisite or fallback.
## Map image selection and original UI target role remain explicit inputs.
const MINIMAP_MEMBER="UI/Main/Set_R_Top_MiniMapLayout.csb"
const MINIMAP_SHA256="df599c77516838bfd1b22e021b1e761343c8d1e6d649f38ef15bb0ffb5cb351f"
const MAP_NAME_TEXT=14376
const ZONE_TEXT=13992
const EXISTING_SAFE_SUFFIX=" · 안전 지역"
const MAP_SCENE="UI/MapScene.csb"
const MAP_SCENE_SHA="52334e683d2691c1f4e623933c26e6ea5f94add6485b636ad47b92e02816eafb"
const MAP_ALL="UI/Map/Map_All.csb"
const MAP_ALL_SHA="f3ed7282f1030de466fdb1c11335889e7d31218eafbed262642f5b84ca0bb46c"
const AREA="UI/Map/Map_Tab_Area.csb"
const AREA_SHA="709e406c6a67199fcec3b998f5ac032ce833ad0ea79e3981327dadea689ffd84"
const ROW="UI/Map/Map_List_Button.csb"
const ROW_SHA="a3d55dcab8f9385870916e6df5d1cd30b47f1da5417d60a764cbcffbe1e0f3f4"
const AREA_IMAGE=44440
const AREA_AUTHORED_ROW=37316
signal world_selection_changed(result: Dictionary)
signal world_image_clicked(payload: Dictionary)
const OwnerPixels=preload("res://scripts/ui/original_ui/source_asset_pixels.gd")
var _displayed_world_id: int=0
var _displayed_texture: Texture2D
var _field_map: WeakRef
var _area_scene: WeakRef
var _map_scene: WeakRef
var _dismiss_map: Callable
var _selected_world_id: int=0
var _area_role: Dictionary={}
var _pack: RefCounted
var _hud: WeakRef
var _image_adapter: RefCounted

func configure(pack: RefCounted, hud: Node, image_adapter: RefCounted=null) -> Dictionary:
	if not is_instance_valid(hud) or not hud.has_signal("map_pressed"):return _fail("source_main_map_existing_hud_entry_missing")
	if image_adapter!=null:
		for method: String in ["world_candidates","apply_field_world"]:
			if not image_adapter.has_method(method):return {"ok":false,"code":"source_main_map_existing_image_adapter_api_missing","method":method}
	_pack=pack
	_hud=weakref(hud)
	_image_adapter=image_adapter
	return {"ok":true,"requirements":requirements(),"complete_screen_contract":false}

func build_name(map_name: String, include_safe_label: bool=true) -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MINIMAP_MEMBER,{}).get("sha256","")!=MINIMAP_SHA256:return _fail("source_main_map_minimap_identity_mismatch")
	var has_zone: bool=include_safe_label and not _node_at(_pack.scene(MINIMAP_MEMBER).get("nodeTree",{}),ZONE_TEXT).is_empty()
	var model: Dictionary=_existing_name_model(map_name,has_zone)
	var scope: Array[int]=[MAP_NAME_TEXT]
	var bindings: Dictionary={MAP_NAME_TEXT:{"role":"source_text","text":model.name}}
	if has_zone:
		scope.append(ZONE_TEXT)
		bindings[ZONE_TEXT]={"role":"source_text","text":model.zone,"visible":not str(model.zone).is_empty()}
	# This is the existing owner's formatted safety suffix only, never a
	# region.type/Normal/PvP classification or UIMapWorld/image selection.
	return {"ok":true,"member":MINIMAP_MEMBER,"sha256":MINIMAP_SHA256,"source_node_offsets":scope,"bindings":bindings,"name_model":model,"safe_label_connected":has_zone,"zone_enum_mapping_inferred":false,"partial_source_scene":true,"complete_screen_contract":false,"world_image_connected":false,"unresolved_fields":requirements()}

func refresh_name(scene: Node2D, map_name: String) -> Dictionary:
	if not is_instance_valid(scene) or scene.get("source_member")!=MINIMAP_MEMBER:return _fail("source_main_map_minimap_scene_mismatch")
	var has_zone: bool=scene.get("source_nodes").has(ZONE_TEXT)
	var model: Dictionary=_existing_name_model(map_name,has_zone)
	var result: Dictionary=scene.set_bound_text(MAP_NAME_TEXT,model.name)
	if not result.get("ok",false):return result
	if has_zone:
		result=scene.set_bound_text(ZONE_TEXT,model.zone)
		if not result.get("ok",false):
			scene.set_bound_visible(ZONE_TEXT,false)
			var restored: Dictionary=scene.set_bound_text(MAP_NAME_TEXT,map_name)
			return {"ok":restored.get("ok",false),"safe_label_connected":false,"zone_text_result":result,"full_owner_name_retained":restored.get("ok",false),"game_state_written":false}
		result=scene.set_bound_visible(ZONE_TEXT,not str(model.zone).is_empty())
		if not result.get("ok",false):return result
	return {"ok":true,"name_model":model,"safe_label_connected":has_zone,"zone_enum_mapping_inferred":false,"game_state_written":false}

static func _existing_name_model(map_name: String, separate_zone: bool) -> Dictionary:
	if separate_zone and map_name.ends_with(EXISTING_SAFE_SUFFIX):
		return {"name":map_name.trim_suffix(EXISTING_SAFE_SUFFIX),"zone":map_name.get_slice(" · ",map_name.get_slice_count(" · ")-1),"basis":"existing World._update_field_triggers set_map_name safety suffix"}
	return {"name":map_name,"zone":"","basis":"existing set_map_name string; no normal/combat/PvP label inferred"}

func world_candidates(field_map: Variant) -> Variant:
	if _image_adapter==null:return _fail("source_main_map_existing_image_adapter_required")
	# PR270 validates the explicit current523_source_field marker and Land
	# namespace. No first-candidate selection, even for a single candidate.
	return _image_adapter.call("world_candidates",field_map)

func request_map() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_main_map_existing_hud_entry_missing")
	hud.emit_signal("map_pressed")
	return {"ok":true,"emitted":true,"signal":"map_pressed","action_result_known":false}

func apply_declared_field_image(source_owner: Node, existing_view: CanvasItem, field_map: Variant, selected_world_id: Variant, role_declaration: Dictionary, source_cell: Variant=null) -> Dictionary:
	if _image_adapter==null:return _fail("source_main_map_existing_image_adapter_required")
	if typeof(selected_world_id)!=TYPE_INT or int(selected_world_id)<=0:return _fail("source_main_map_explicit_uimapworld_id_required")
	if not is_instance_valid(source_owner) or not is_instance_valid(existing_view):return _fail("source_main_map_existing_original_target_required")
	# The existing PR270 apply_field_world ABI requires Sprite2D. Do not pass
	# a different view type through a dynamic call or create another view.
	if not existing_view is Sprite2D:return _fail("source_main_map_existing_sprite_required")
	var original_sprite: Sprite2D=existing_view as Sprite2D
	if existing_view!=source_owner and not source_owner.is_ancestor_of(existing_view):return _fail("source_main_map_view_not_owned_by_original_node")
	# Caller must supply the missing original-client target-role contract. A
	# source map-like name, static preview image or empty Panel is not proof.
	if role_declaration.get("world_image_display")!=true:return _fail("source_main_map_original_image_role_declaration_required")
	var member: Variant=role_declaration.get("member")
	var offset: Variant=role_declaration.get("node_offset")
	var source_sha: Variant=role_declaration.get("sha256")
	if not member is String or member.is_empty() or typeof(offset)!=TYPE_INT or not source_sha is String or source_sha.is_empty():return _fail("source_main_map_original_image_identity_required")
	if _pack==null or _pack.manifest.get("files",{}).get(member,{}).get("sha256","")!=source_sha:return _fail("source_main_map_original_image_identity_mismatch")
	var owner_identity: Variant=source_owner.get_meta("original_ui_source",{})
	if not owner_identity is Dictionary or owner_identity.get("scene")!=member or owner_identity.get("node_offset")!=offset:return _fail("source_main_map_original_target_identity_mismatch")
	# The existing adapter alone performs World/Land/ImageInfo/Asset joins,
	# pack exclusion handling, texture assignment and provenance attachment.
	# It changes no layout, scale, anchor, click handling or selection state.
	var result: Dictionary=_image_adapter.call("apply_field_world",existing_view,field_map,int(selected_world_id),source_cell)
	var consumed: Dictionary={"ok":false,"error":"source_main_map_owner_texture_not_assigned"}
	if bool(result.get("texture_assigned",false)):
		# Shared Cocos upload conversion consumes only the map owner's exact
		# result. Missing format metadata fails; no raw asset lookup/fallback.
		consumed=OwnerPixels.consume_owner_result(result)
		original_sprite.texture=consumed.texture if consumed.get("ok",false) else null
		if consumed.get("ok",false):
			# Renderer reuses this final texture's PMA metadata instead of
			# converting the same owner PNG a second time.
			result["texture"]=consumed.texture
			original_sprite.set_meta("source523_map_image_consumption",consumed.evidence.duplicate(true))
	return {"ok":bool(result.get("ok",false)) and bool(consumed.get("ok",false)),"image_adapter_result":result,"owner_pixel_consumption":consumed,"original_role_declaration":role_declaration.duplicate(true),"image_pixel_registration_complete":false,"map_click_registration_complete":false,"complete_screen_contract":false}

func minimap_source_contract() -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MINIMAP_MEMBER,{}).get("sha256","")!=MINIMAP_SHA256:return _fail("source_main_map_minimap_identity_mismatch")
	# Retain exact source identity without treating preview/chrome as the
	# dynamic World image or inventing a map-open action for size/point/toggle.
	return {"ok":true,"member":MINIMAP_MEMBER,"sha256":MINIMAP_SHA256,"main_project_offset":21588,"source_nodes":{"map_size_panel":16604,"minimap_chrome":16260,"literal_preview_image":15012,"map_name_text":14376,"zone_text":13992,"size_button":15664,"point_button":13404,"on_button":12632,"off_button":12052},"bindings":{},"unresolved_fields":requirements(),"complete_screen_contract":false}

func build_area(field_map: Object, offered_world_id: int, world_label: String, role_declaration: Dictionary={}, scroll_binding: Dictionary={}) -> Dictionary:
	var identities: Dictionary=_map_identities()
	if not identities.get("ok",false):return identities
	var candidate: Dictionary=_offered_candidate(field_map,offered_world_id)
	if not candidate.get("ok",false):return candidate
	if world_label.is_empty():return _fail("source_main_map_original_world_label_required")
	_field_map=weakref(field_map)
	_area_role=role_declaration.duplicate(true)
	# One original authored row exists outside an empty ListView. Do not
	# clone it into a new list, choose the first candidate or derive page rules.
	var selected: bool=_selected_world_id==offered_world_id
	var row_scope: Array[int]=[7440,4508,7492,4560]
	var row_bindings: Dictionary={
		208:{"role":"consume"},
		7440:{"role":"button","activate":Callable(self,"select_world").bind(offered_world_id),"visible":not selected},
		4508:{"role":"button","activate":Callable(self,"select_world").bind(offered_world_id),"visible":selected},
		7492:{"role":"source_text","text":world_label},
		4560:{"role":"source_text","text":world_label}
	}
	# No Base/Field/Dungeon/Village background type or star state is inferred
	# from the World ID. The exact Label nodes replace their source test text.
	var area_bindings: Dictionary={
		41412:{"role":"consume"},
		AREA_IMAGE:{"role":"source_asset_slot","visible":false},
		AREA_AUTHORED_ROW:{"role":"project","source_node_offsets":row_scope,"bindings":row_bindings}
	}
	var unresolved: Array=[
		{"field":"additional_candidate_row_placement","empty_list_offset":37560,"authored_row_project_offset":AREA_AUTHORED_ROW},
		{"field":"original_Area_draft_to_UIMapWorld_image_role","source_member":AREA,"source_offset":AREA_IMAGE,"source_preview":"UI_Draft/V_talkingisland.png","required":"explicit caller role declaration; draft V is not World W evidence"},
		{"field":"source_cell_to_image_pixel_and_click_registration","source_fields":["Ratio","BaseLocX","BaseLocY","BasePixelX","BasePixelY"]}
	]
	if scroll_binding.get("role")=="source_scroll" and scroll_binding.get("input") is Callable and scroll_binding.input.is_valid():area_bindings[44388]=scroll_binding.duplicate(true)
	else:unresolved.append({"field":"existing_original_scroll_input","member":AREA,"offset":44388})
	return {"ok":true,"member":AREA,"sha256":AREA_SHA,"source_node_offsets":[AREA_IMAGE,AREA_AUTHORED_ROW],"bindings":area_bindings,"offered_candidate":candidate.candidate,"selected_world_id":_selected_world_id,"world_label_basis":"explicit caller localized label","role_declaration":role_declaration.duplicate(true),"draft_image_visible_before_apply":false,"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":unresolved}

func build_map_scene(field_map: Object, offered_world_id: int, world_label: String, role_declaration: Dictionary={}, scroll_binding: Dictionary={}) -> Dictionary:
	var area: Dictionary=build_area(field_map,offered_world_id,world_label,role_declaration,scroll_binding)
	if not area.get("ok",false):return area
	var all_scope: Array[int]=[35332,34904,30312,29552,29228,31656]
	var all_bindings: Dictionary={
		35332:{"role":"consume"},
		30312:{"role":"static_source_text"},
		29552:{"role":"button","activate":Callable(self,"close_map")},
		# Caller explicitly requests the source Area view; no World/Island/
		# Aden tab IDs, category types or preview On variants are guessed.
		31656:{"role":"project","visible":true,"source_node_offsets":area.source_node_offsets,"bindings":area.bindings}
	}
	var bindings: Dictionary={132:{"role":"project","source_node_offsets":all_scope,"bindings":all_bindings}}
	return {"ok":true,"member":MAP_SCENE,"sha256":MAP_SCENE_SHA,"source_node_offsets":[132],"bindings":bindings,"child_member":MAP_ALL,"child_sha256":MAP_ALL_SHA,"child_source_node_offsets":all_scope,"child_bindings":all_bindings,"area_contract":area,"native_parent":map_scene_contract(),"partial_source_scene":true,"complete_screen_contract":false}

func bind_area_presented(scene: Node2D, field_map: Object) -> Dictionary:
	# Caller passes rootScene.project_player([132,31656]).player, not the
	# native actual_root Node2D stored in source_nodes[ProjectOffset].
	if not is_instance_valid(scene) or scene.get("source_member")!=AREA or not is_instance_valid(field_map):return _fail("source_main_map_original_area_scene_required")
	if scene.get("inspection_only")==true:return _fail("source_main_map_inspection_not_game_presenter")
	var image: Dictionary=_area_target(scene)
	if not image.get("ok",false):return image
	_area_scene=weakref(scene)
	_field_map=weakref(field_map)
	_displayed_world_id=0
	_displayed_texture=null
	return {"ok":true,"selected_world_id":_selected_world_id,"image_applied":false,"explicit_selection_required":_selected_world_id==0}

func bind_map_presented(scene: Node2D, dismiss_presenter: Callable=Callable()) -> Dictionary:
	if not is_instance_valid(scene) or scene.get("source_member") not in [MAP_SCENE,MAP_ALL]:return _fail("source_main_map_original_root_scene_required")
	if scene.get("inspection_only")==true:return _fail("source_main_map_inspection_not_game_presenter")
	_map_scene=weakref(scene)
	_dismiss_map=dismiss_presenter
	return {"ok":true}

func select_world(world_id: int, source_cell: Variant=null) -> Dictionary:
	var field_map: Object=_field_map.get_ref() if _field_map!=null else null
	if field_map==null:return _fail("source_main_map_current_field_required")
	var offered: Dictionary=_offered_candidate(field_map,world_id)
	if not offered.get("ok",false):return offered
	_selected_world_id=world_id
	_displayed_world_id=0
	_displayed_texture=null
	var selected: Dictionary={"ok":true,"selected_world_id":world_id,"world_namespace":"UIMapWorld.ID","candidate":offered.candidate,"image_applied":false,"image_pixel_registration_complete":false,"map_click_registration_complete":false}
	var scene: Object=_area_scene.get_ref() if _area_scene!=null else null
	if scene!=null:
		# Selection never leaves a previous World's pixels visible as a fallback.
		scene.set_bound_visible(AREA_IMAGE,false)
		var marked: Dictionary=_mark_authored_row(scene)
		if not marked.get("ok",false):selected["row_update_result"]=marked
	if not _valid_area_role(_area_role):
		selected["unresolved_field"]="original_Area_draft_to_UIMapWorld_image_role_declaration"
		world_selection_changed.emit(selected.duplicate(true))
		return selected
	if scene==null:return _fail("source_main_map_original_area_not_presented")
	var target: Dictionary=_area_target(scene)
	if not target.get("ok",false):return target
	# Only the existing PR270 adapter performs any source relation/image work.
	var applied: Dictionary=apply_declared_field_image(target.owner,target.sprite,field_map,world_id,_area_role,source_cell)
	var image_result: Dictionary=applied.get("image_adapter_result",{})
	var consumed: Dictionary=applied.get("owner_pixel_consumption",{"ok":false,"error":"source_main_map_owner_texture_not_assigned"})
	var source_asset_result: Dictionary={"ok":false,"error":"source_main_map_source_asset_slot_api_missing"}
	if scene.has_method("set_bound_source_asset_result"):
		# The renderer owns original native dimensions, Cocos anchor,
		# material and displayed color after accepting the real owner result.
		source_asset_result=scene.set_bound_source_asset_result(AREA_IMAGE,image_result)
	var visible: bool=bool(source_asset_result.get("ok",false)) and bool(source_asset_result.get("texture_assigned",false)) and source_asset_result.get("texture") is Texture2D
	var shown: Dictionary=scene.set_bound_visible(AREA_IMAGE,visible)
	selected["image_applied"]=visible and bool(shown.get("ok",false))
	if selected.image_applied:
		_displayed_world_id=world_id
		_displayed_texture=target.sprite.texture
	selected["image_adapter_result"]=image_result
	selected["owner_pixel_consumption"]=consumed
	selected["source_asset_result"]=source_asset_result
	selected["apply_result"]=applied
	selected["image_visibility_result"]=shown
	world_selection_changed.emit(selected.duplicate(true))
	return selected

func viewport_to_world_image_pixel(viewport_point: Vector2) -> Dictionary:
	# Registration is against the final actually displayed Sprite2D, after
	# original ancestors, source scroll placement and canvas transforms.
	if not viewport_point.is_finite():return _fail("source_main_map_viewport_point_invalid")
	if _selected_world_id<=0 or _displayed_world_id!=_selected_world_id or _displayed_texture==null:return _fail("source_main_map_selected_image_not_displayed")
	var scene: Object=_area_scene.get_ref() if _area_scene!=null else null
	if scene==null or not scene.is_inside_tree():return _fail("source_main_map_original_area_not_presented")
	var scroll_point: Dictionary=_visible_scroll_point(scene,viewport_point)
	if not scroll_point.get("ok",false):return scroll_point
	var target: Dictionary=_area_target(scene)
	if not target.get("ok",false):return target
	var sprite: Sprite2D=target.sprite
	if sprite.texture!=_displayed_texture or not sprite.is_visible_in_tree():return _fail("source_main_map_displayed_texture_changed_or_hidden")
	if sprite.hframes!=1 or sprite.vframes!=1 or sprite.frame!=0:return _fail("source_main_map_sprite_frames_unsupported")
	if sprite.region_enabled:return _fail("source_main_map_sprite_region_unsupported")
	var metadata: Variant=sprite.get_meta("source523_map_image",{})
	if not metadata is Dictionary or metadata.get("source_map_relation")!="explicit_world_image_asset":return _fail("source_main_map_verified_image_metadata_missing")
	var provenance: Variant=metadata.get("provenance")
	if not provenance is Dictionary:return _fail("source_main_map_verified_image_provenance_missing")
	var relation: Variant=provenance.get("source_map_relation")
	if not relation is Dictionary:return _fail("source_main_map_verified_image_relation_missing")
	var world_record: Variant=relation.get("world",{}).get("raw")
	var image_info: Variant=relation.get("image_info",{}).get("raw")
	if not world_record is Dictionary or world_record.get("ID")!=_displayed_world_id or not image_info is Dictionary:return _fail("source_main_map_displayed_world_metadata_mismatch")
	var native_transform: Transform2D=sprite.get_global_transform_with_canvas()
	var determinant: float=native_transform.determinant()
	if not native_transform.x.is_finite() or not native_transform.y.is_finite() or not native_transform.origin.is_finite() or not is_finite(determinant) or is_zero_approx(determinant):return _fail("source_main_map_sprite_transform_not_invertible")
	var local_point: Vector2=native_transform.affine_inverse()*viewport_point
	if not local_point.is_finite():return _fail("source_main_map_sprite_local_point_invalid")
	var texture_size:=Vector2(sprite.texture.get_width(),sprite.texture.get_height())
	if texture_size.x<=0 or texture_size.y<=0:return _fail("source_main_map_texture_extent_invalid")
	# get_rect includes this native Sprite's centered/offset properties. Full
	# single-frame texture dimensions are required; unsupported regions above
	# are never silently treated as the entire source image.
	var rectangle: Rect2=sprite.get_rect()
	if not rectangle.size.is_equal_approx(texture_size):return _fail("source_main_map_native_sprite_extent_mismatch")
	if not rectangle.has_point(local_point):return _fail("source_main_map_point_outside_displayed_image")
	var display_pixel: Vector2=local_point-rectangle.position
	var raw_pixel: Vector2=display_pixel
	# Continuous pixel-edge coordinates, not guessed texel centers. A flipped
	# leading edge can equal width/height; no clamping or cell conversion occurs.
	if sprite.flip_h:raw_pixel.x=texture_size.x-display_pixel.x
	if sprite.flip_v:raw_pixel.y=texture_size.y-display_pixel.y
	return {"ok":true,"world_id":_displayed_world_id,"world_namespace":"UIMapWorld.ID","raw_pixel":raw_pixel,"display_pixel":display_pixel,"pixel_space":"intrinsic_texture_top_left_x_right_y_down","pixel_coordinate_convention":"continuous_edges_before_display_flips","display_pixel_space":"displayed_sprite_rect_top_left_x_right_y_down","texture_size":texture_size,"texture_bounds":Rect2(Vector2.ZERO,texture_size),"viewport_point":viewport_point,"sprite_local_point":local_point,"sprite_local_rect":rectangle,"sprite_centered":sprite.centered,"sprite_offset":sprite.offset,"flip_h":sprite.flip_h,"flip_v":sprite.flip_v,"original_ui_source":target.owner.get_meta("original_ui_source",{}).duplicate(true),"source_world":world_record.duplicate(true),"source_image_info":image_info.duplicate(true),"verified_image_metadata":metadata.duplicate(true),"owner_pixel_consumption":sprite.get_meta("source523_map_image_consumption",{}).duplicate(true),"native_texture_pixel_registration_complete":true,"original_scroll_viewport":scroll_point,"image_info_axes_or_units_assumed":false,"source_cell_projection_applied":false,"map_click_movement_performed":false}

func _visible_scroll_point(area: Object, viewport_point: Vector2) -> Dictionary:
	var nodes: Dictionary=area.get("source_nodes")
	var node: Node2D=nodes.get(44388)
	var scroll: Variant=(node.get_meta("source_scroll") if node.has_meta("source_scroll") else null) if node!=null else null
	var control: Control=scroll.input_control() if is_instance_valid(scroll) and scroll.has_method("input_control") else null
	if control==null or not control.is_visible_in_tree():return _fail("source_main_map_original_scroll_viewport_missing")
	var parent: Node=control
	while parent!=null:
		if parent is Control and (parent==control or parent.clip_contents):
			var transform: Transform2D=parent.get_global_transform_with_canvas()
			if not is_finite(transform.determinant()) or is_zero_approx(transform.determinant()):return _fail("source_main_map_scroll_transform_not_invertible")
			var local: Vector2=transform.affine_inverse()*viewport_point
			if not local.is_finite() or not Rect2(Vector2.ZERO,parent.size).has_point(local):return _fail("source_main_map_point_outside_visible_scroll_viewport")
		parent=parent.get_parent()
	return {"ok":true,"source_scroll_offset":44388,"input_extent":control.size,"viewport_point":viewport_point}

func submit_world_image_click(viewport_point: Vector2, caller_event_metadata: Dictionary={}) -> Dictionary:
	# The existing input controller supplies an actual viewport point. This
	# method is not installed as a new ScrollView gesture/click interpretation.
	var pixel: Dictionary=viewport_to_world_image_pixel(viewport_point)
	if not pixel.get("ok",false):return pixel
	pixel["caller_event_metadata"]=caller_event_metadata.duplicate(true)
	world_image_clicked.emit(pixel.duplicate(true))
	pixel["emitted"]=true
	return pixel

func close_map() -> Dictionary:
	var scene: Object=_map_scene.get_ref() if _map_scene!=null else null
	_map_scene=null
	_area_scene=null
	_field_map=null
	_selected_world_id=0
	_displayed_world_id=0
	_displayed_texture=null
	if is_instance_valid(scene):scene.queue_free()
	if _dismiss_map.is_valid():_dismiss_map.call()
	return {"ok":true,"closed":true,"game_state_written":false}

func map_scene_contract() -> Dictionary:
	var identity: Dictionary=_map_identities()
	if not identity.get("ok",false):return identity
	var tree: Dictionary=_original_tree(MAP_SCENE)
	var parent: Dictionary=_node_at(tree.get("nodeTree",{}),132)
	if parent.get("classname")!="ProjectNode" or parent.get("options",{}).get("fileName")!="Map/Map_All.csb":return _fail("source_main_map_original_parent_project_mismatch")
	return {"ok":true,"member":MAP_SCENE,"sha256":MAP_SCENE_SHA,"root_offset":tree.nodeTree.get("_offset"),"root_options":tree.nodeTree.get("options",{}).duplicate(true),"project_offset":132,"project_options":parent.options.duplicate(true),"design_extent":Vector2(1200,675),"animation_clips":tree.get("animationList",[]).duplicate(true),"partial_source_scene":true,"complete_screen_contract":false}

func _offered_candidate(field_map: Object, world_id: int) -> Dictionary:
	if not is_instance_valid(field_map):return _fail("source_main_map_current_field_required")
	var offered: Variant=world_candidates(field_map)
	if not offered is Dictionary or not offered.get("ok",false):return offered if offered is Dictionary else _fail("source_main_map_candidates_invalid")
	var matches: Array=[]
	for candidate: Dictionary in offered.get("candidates",[]):
		if candidate.get("world_id")==world_id and candidate.get("world_namespace")=="UIMapWorld.ID":matches.append(candidate)
	if world_id<=0 or matches.size()!=1:return _fail("source_main_map_world_not_unique_offered_candidate")
	return {"ok":true,"candidate":matches[0].duplicate(true),"provenance":offered.get("provenance",{}).duplicate(true)}

func _area_target(scene: Node2D) -> Dictionary:
	var nodes: Variant=scene.get("source_nodes")
	if not nodes is Dictionary:return _fail("source_main_map_original_area_nodes_missing")
	var owner: Variant=nodes.get(AREA_IMAGE)
	if not is_instance_valid(owner):return _fail("source_main_map_original_area_image_node_missing")
	var sprite: Variant=(owner.get_meta("source_sprite") if owner.has_meta("source_sprite") else null)
	if not sprite is Sprite2D or not owner.is_ancestor_of(sprite):return _fail("source_main_map_original_area_sprite_missing")
	return {"ok":true,"owner":owner,"sprite":sprite}

func _mark_authored_row(area_scene: Node2D) -> Dictionary:
	if not area_scene.has_method("project_player"):return _fail("source_main_map_project_player_api_missing")
	var row_path: Array[int]=[AREA_AUTHORED_ROW]
	var nested: Dictionary=area_scene.project_player(row_path)
	if not nested.get("ok",false):return nested
	var row: Variant=nested.get("player")
	if not is_instance_valid(row) or not row.has_method("set_bound_visible"):return _fail("source_main_map_original_authored_row_missing")
	var normal: Dictionary=row.set_bound_visible(7440,false)
	if not normal.get("ok",false):return normal
	return row.set_bound_visible(4508,true)

func _map_identities() -> Dictionary:
	if _pack==null:return _fail("source_main_map_source_pack_required")
	for expected: Array in [[MAP_SCENE,MAP_SCENE_SHA],[MAP_ALL,MAP_ALL_SHA],[AREA,AREA_SHA],[ROW,ROW_SHA]]:
		if _pack.manifest.get("files",{}).get(expected[0],{}).get("sha256","")!=expected[1]:return {"ok":false,"code":"source_main_map_original_identity_mismatch","member":expected[0]}
	return {"ok":true}

func _original_tree(member: String) -> Dictionary:
	return _layout_or_scene(member)

static func _valid_area_role(role: Dictionary) -> bool:
	return role.get("world_image_display")==true and role.get("member")==AREA and role.get("sha256")==AREA_SHA and role.get("node_offset")==AREA_IMAGE

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

static func requirements() -> Array:
	return [
		{"field":"selected_UIMapWorld.ID","basis":"explicit_caller_selection_from_world_candidates","land_id_is_not_world_id":true},
		{"field":"original_image_display_node_role","required_declaration":["member","sha256","node_offset","world_image_display=true"],"requires_existing_original_owner_and_view":true},
		{"field":"original_map_entry_button_contract","existing_callback":"request_map","minimap_size_point_on_off_are_not_map_entry_evidence":true},
		{"field":"source_cell_to_ImageInfo_pixel_registration","source_fields":["Ratio","BaseLocX","BaseLocY","BasePixelX","BasePixelY"],"missing":["axes","units","application_formula","image_rectangle","click_registration"]}
	]

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}

## A member listed in layout_sources (parent reference geometry) is read from
## there; every other member is an ordinary pack scene. layout_source() returns
## {} for scenes, which used to fail every original window as "layout missing".
func _layout_or_scene(member: String) -> Dictionary:
	var tree: Dictionary=_pack.call("layout_source",member) if _pack.has_method("layout_source") else {}
	return tree if tree.get("nodeTree") is Dictionary else _pack.scene(member)
