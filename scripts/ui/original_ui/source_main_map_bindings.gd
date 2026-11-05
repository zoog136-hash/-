extends RefCounted
## Caller glue for the existing PR270 map-image adapter, never a replacement
## image loader or coordinate projector. No old pack prerequisite or fallback.
## Map image selection and original UI target role remain explicit inputs.
const MINIMAP_MEMBER="UI/Main/Set_R_Top_MiniMapLayout.csb"
const MINIMAP_SHA256="df599c77516838bfd1b22e021b1e761343c8d1e6d649f38ef15bb0ffb5cb351f"
var _pack: RefCounted
var _hud: WeakRef
var _image_adapter: RefCounted

func configure(pack: RefCounted, hud: Node, image_adapter: RefCounted) -> Dictionary:
	if not is_instance_valid(hud) or not hud.has_signal("map_pressed"):return _fail("source_main_map_existing_hud_entry_missing")
	if image_adapter==null:return _fail("source_main_map_existing_image_adapter_required")
	for method: String in ["world_candidates","apply_field_world"]:
		if not image_adapter.has_method(method):return {"ok":false,"code":"source_main_map_existing_image_adapter_api_missing","method":method}
	_pack=pack
	_hud=weakref(hud)
	_image_adapter=image_adapter
	return {"ok":true,"requirements":requirements(),"complete_screen_contract":false}

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
	return {"ok":result.get("ok",false),"image_adapter_result":result,"original_role_declaration":role_declaration.duplicate(true),"image_pixel_registration_complete":false,"map_click_registration_complete":false,"complete_screen_contract":false}

func minimap_source_contract() -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MINIMAP_MEMBER,{}).get("sha256","")!=MINIMAP_SHA256:return _fail("source_main_map_minimap_identity_mismatch")
	# Retain exact source identity without treating preview/chrome as the
	# dynamic World image or inventing a map-open action for size/point/toggle.
	return {"ok":true,"member":MINIMAP_MEMBER,"sha256":MINIMAP_SHA256,"main_project_offset":21588,"source_nodes":{"map_size_panel":16604,"minimap_chrome":16260,"literal_preview_image":15012,"map_name_text":14376,"zone_text":13992,"size_button":15664,"point_button":13404,"on_button":12632,"off_button":12052},"bindings":{},"unresolved_fields":requirements(),"complete_screen_contract":false}

static func requirements() -> Array:
	return [
		{"field":"selected_UIMapWorld.ID","basis":"explicit_caller_selection_from_world_candidates","land_id_is_not_world_id":true},
		{"field":"original_image_display_node_role","required_declaration":["member","sha256","node_offset","world_image_display=true"],"requires_existing_original_owner_and_view":true},
		{"field":"original_map_entry_button_contract","existing_callback":"request_map","minimap_size_point_on_off_are_not_map_entry_evidence":true},
		{"field":"source_cell_to_ImageInfo_pixel_registration","source_fields":["Ratio","BaseLocX","BaseLocY","BasePixelX","BasePixelY"],"missing":["axes","units","application_formula","image_rectangle","click_registration"]}
	]

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
