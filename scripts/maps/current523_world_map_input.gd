extends Node
## Cell/input owner for the existing UI267 presenter and PR270 image adapter.
## No image loading, native UI construction, candidate auto-selection or travel.
const WALK=preload("res://scripts/maps/current523_world_map_walk.gd")
const COORDINATES=preload("res://scripts/maps/current523_world_map_coordinates.gd")
const ADAPTER_PATH: String="res://scripts/maps/source523_map_image_adapter.gd"
const IMAGE_OWNER_PATH: String="res://scripts/ui/source523_image_assets.gd"
const CONFIG_PATH: String="user://current523_world_map.cfg"
const INPUT_POLICY: String="OWN_EXISTING_WORLD_TAP10PX_PAN_V1"
const AREA_ROLE: Dictionary={"member":"UI/Map/Map_Tab_Area.csb","sha256":"709e406c6a67199fcec3b998f5ac032ce833ad0ea79e3981327dadea689ffd84","node_offset":44440,"world_image_display":true}
var _world: WeakRef
var _adapter: RefCounted
var _image_owner: Script
var _offers: Dictionary={}
var _options: Dictionary={}
var _contract_pin: String=""
var _open_field: WeakRef
var _open_offer: Dictionary={}
var _open_epoch: int=0
var _gesture: Dictionary={}
var _submission: Dictionary={}
var _nonce: int=0
var last_result: Dictionary={"ok":false,"reason":"world_map_not_registered"}

func _ready() -> void:
	get_window().focus_exited.connect(_cancel)
	get_viewport().size_changed.connect(_cancel)

func configure(world: Node, adapter: RefCounted, offered_worlds: Dictionary, options: Dictionary={}) -> Dictionary:
	if not is_instance_valid(world) or not is_instance_valid(world.hud) or not world.hud.has_method("bind_original_world_map") or not world.hud.has_signal("original_world_map_image_clicked"):return _remember(_fail("world_map_ui267_caller_dependency_required"))
	if adapter==null or not adapter.has_method("world_candidates") or not adapter.has_method("apply_field_world"):return _remember(_fail("world_map_image270_adapter_required"))
	if not ResourceLoader.exists(IMAGE_OWNER_PATH):return _remember(_fail("world_map_image270_selection_owner_required"))
	var image_owner: Script=load(IMAGE_OWNER_PATH)
	if image_owner==null:return _remember(_fail("world_map_image270_selection_owner_required"))
	var bound: Dictionary=world.hud.call("bind_original_world_map",adapter,Callable(self,"context"),Callable(self,"input"))
	if not bound.get("ok",false):return _remember(bound)
	_world=weakref(world)
	_adapter=adapter
	_image_owner=image_owner
	_offers=offered_worlds.duplicate(true)
	_options=options.duplicate(true)
	_contract_pin=str(options.get("contract_sha256",""))
	if not world.hud.is_connected("original_world_map_image_clicked",Callable(self,"_on_image_clicked")):
		world.hud.connect("original_world_map_image_clicked",Callable(self,"_on_image_clicked"))
	_open_epoch+=1
	_cancel()
	set_process(true)
	return _remember({"ok":true,"registered":true,"world_auto_selected":false,"input_policy":INPUT_POLICY,"coordinate_policy":COORDINATES.POLICY,"native_image_info_formula_confirmed":false,"ui_binding":bound,"executed_or_rendered":false})

func configure_from_settings(world: Node, path: String=CONFIG_PATH) -> Dictionary:
	var config:=ConfigFile.new()
	var error: Error=config.load(path)
	if error==ERR_FILE_NOT_FOUND:return _remember({"ok":true,"selected":false,"reason":"world_map_private_settings_not_selected"})
	if error!=OK:return _remember(_fail("world_map_private_settings_unreadable"))
	if config.get_value("world_map","enabled",false)!=true:return _remember({"ok":true,"selected":false})
	if not ResourceLoader.exists(ADAPTER_PATH):return _remember(_fail("world_map_image270_adapter_dependency_required"))
	if not is_instance_valid(world.hud) or not world.hud.has_method("bind_original_world_map"):return _remember(_fail("world_map_ui267_caller_dependency_required"))
	var contract_path: Variant=config.get_value("world_map","contract_path","")
	var pin: Variant=config.get_value("world_map","contract_sha256","")
	var offers: Variant=config.get_value("world_map","offered_worlds",{})
	if not contract_path is String or not pin is String or not offers is Dictionary:return _remember(_fail("world_map_private_selection_invalid"))
	var adapter_script: Script=load(ADAPTER_PATH)
	if adapter_script==null or not adapter_script.can_instantiate():return _remember(_fail("world_map_image270_adapter_unavailable"))
	var adapter: RefCounted=adapter_script.new()
	var opened: Dictionary=adapter.call("open_contract",contract_path,pin)
	if not opened.get("ok",false):return _remember(opened)
	return configure(world,adapter,offers,{"contract_sha256":pin,"coordinate_policy":config.get_value("world_map","coordinate_policy",COORDINATES.POLICY),"ratio_scale":config.get_value("world_map","ratio_scale",1.0),"source_anchor_offset":config.get_value("world_map","source_anchor_offset",[0.5,0.5])})

func context() -> Dictionary:
	# Called by the actual presenter on each open. The explicit private offer
	# identifies the authored row; the native row button still selects it.
	_cancel()
	_open_epoch+=1
	_open_field=null
	_open_offer={}
	var world: Node=_world.get_ref() if _world!=null else null
	if not is_instance_valid(world) or _adapter==null:return _fail("world_map_current_owner_unavailable")
	var field: RefCounted=world.field_map
	var offered: Dictionary=_offer(field)
	if not offered.get("ok",false):return offered
	if WALK.ticket(world,field).is_empty():return _fail("world_map_live_source_session_required")
	_open_field=weakref(field)
	_open_offer=offered
	return {"ok":true,"field_map":field,"offered_world_id":offered.world_id,"world_label":offered.label,"role_declaration":AREA_ROLE.duplicate(true)}

func _offer(field: RefCounted) -> Dictionary:
	if field==null or field.get_meta("current523_source_field",false)!=true:return _fail("world_map_mobile_source_field_required")
	var definition: Variant=field.get("definition")
	if not definition is Dictionary or not _uint(definition.get("source_map_id")):return _fail("world_map_land_identity_required")
	var offer: Variant=_offers.get(str(int(definition.source_map_id)))
	if not offer is Dictionary or not _uint(offer.get("world_id")) or offer.world_id==0:return _fail("world_map_explicit_private_world_offer_required")
	var candidates: Dictionary=_adapter.call("world_candidates",field)
	if not candidates.get("ok",false):return candidates
	if candidates.get("provenance",{}).get("map_contract_sha256")!=_contract_pin:return _fail("world_map_relation_selection_changed")
	var matches: Array=[]
	for candidate: Variant in candidates.get("candidates",[]):
		if candidate is Dictionary and candidate.get("world_namespace")=="UIMapWorld.ID" and candidate.get("world_id")==offer.world_id:matches.append(candidate)
	if matches.size()!=1:return _fail("world_map_exact_offered_world_required")
	var source: Variant=matches[0].get("source_world",{}).get("raw")
	if not source is Dictionary or source.get("LandID")!=definition.source_map_id or source.get("ID")!=offer.world_id:return _fail("world_map_offer_source_relation_mismatch")
	var label: Variant=offer.get("label",source.get("Name"))
	if not label is String or label.is_empty():return _fail("world_map_actual_source_label_required")
	return {"ok":true,"world_id":int(offer.world_id),"label":label,"source_world":source.duplicate(true),"map_contract_sha256":_contract_pin}

func input(event: InputEvent, supplied: Dictionary) -> Dictionary:
	if event.device==InputEvent.DEVICE_ID_EMULATION:return {"ok":true,"ignored_emulated_event":true}
	var ui: Variant=supplied.get("map_ui")
	if not is_instance_valid(ui) or not ui.has_method("is_open") or not ui.call("is_open") or supplied.get("event_space")!="original_scroll_input_control_local":
		_cancel();return _fail("world_map_actual_presenter_input_required")
	var world: Node=_world.get_ref() if _world!=null else null
	var field: RefCounted=_open_field.get_ref() if _open_field!=null else null
	if not is_instance_valid(world) or field==null or world.field_map!=field or _offer(field)!=_open_offer:
		_cancel();return _fail("world_map_open_field_or_offer_changed")
	var point: Variant=supplied.get("viewport_point")
	if not point is Vector2 or not point.is_finite():return _fail("world_map_actual_viewport_point_required")
	var pressed: bool=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed or event is InputEventScreenTouch and event.pressed and not event.canceled
	if pressed:
		if not _gesture.is_empty():return _fail("world_map_pointer_already_active")
		var ticket: Dictionary=WALK.ticket(world,field)
		var pixel: Dictionary=ui.call("image_pixel_at",point)
		var geometry: Dictionary=ui.call("scroll_geometry")
		var image_pack: int=_image_pack_identity()
		if ticket.is_empty() or not pixel.get("ok",false) or not geometry.get("ok",false) or image_pack==0:return pixel if not pixel.get("ok",false) else _fail("world_map_current_walk_or_scroll_unavailable")
		if pixel.get("world_namespace")!="UIMapWorld.ID" or pixel.get("world_id")!=_open_offer.world_id:return _fail("world_map_explicit_selected_offer_required")
		_gesture={"pointer":event.index if event is InputEventScreenTouch else -1,"origin":point,"ui":weakref(ui),"epoch":_open_epoch,"ticket":ticket,"image_identity":_pixel_identity(pixel),"image_pack":image_pack,"geometry":geometry,"dragging":false}
		return {"ok":true,"pressed":true,"input_policy":INPUT_POLICY}
	if _gesture.is_empty():return {"ok":true,"ignored_without_press":true}
	if not _current_gesture(world,field,ui):_cancel();return _fail("world_map_stale_gesture")
	if event is InputEventScreenTouch and event.index==_gesture.pointer and event.canceled:_cancel();return {"ok":true,"canceled":true}
	var move: bool=event is InputEventMouseMotion and _gesture.pointer==-1 or event is InputEventScreenDrag and event.index==_gesture.pointer
	var released: bool=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and _gesture.pointer==-1 or event is InputEventScreenTouch and not event.pressed and event.index==_gesture.pointer
	if not move and not released:return {"ok":true,"ignored_other_pointer":true}
	# Reuse the existing world-input tap threshold, explicitly an OWN gesture.
	if point.distance_to(_gesture.origin)>=10.0:_gesture.dragging=true
	if _gesture.dragging:
		var geometry: Dictionary=_gesture.geometry
		var transform: Variant=geometry.get("input_to_viewport")
		var start: Variant=geometry.get("content_position")
		if not transform is Transform2D or not start is Vector2 or not is_finite(transform.determinant()) or is_zero_approx(transform.determinant()):_cancel();return _fail("world_map_original_scroll_transform_invalid")
		var inverse: Transform2D=transform.affine_inverse()
		var delta: Vector2=inverse*point-inverse*Vector2(_gesture.origin)
		var scrolled: Dictionary=ui.call("set_scroll_position",start+Vector2(delta.x,-delta.y))
		if released or not scrolled.get("ok",false):_cancel()
		return scrolled
	if not released:return {"ok":true,"pressed":true}
	var pixel: Dictionary=ui.call("image_pixel_at",point)
	if not pixel.get("ok",false) or _pixel_identity(pixel)!=_gesture.image_identity:_cancel();return _fail("world_map_selected_image_changed_during_click")
	_nonce+=1
	_submission={"nonce":_nonce,"ticket":_gesture.ticket,"epoch":_open_epoch,"field":weakref(field),"pixel_identity":_gesture.image_identity,"image_pack":_gesture.image_pack}
	_gesture={}
	_remember(_fail("world_map_click_not_consumed"))
	var submitted: Dictionary=ui.call("submit_world_image_click",point,{"owner":"current523_world_map_input","nonce":_nonce,"event_class":event.get_class(),"input_policy":INPUT_POLICY})
	_submission={}
	return {"ok":submitted.get("ok",false) and last_result.get("ok",false),"pixel_submission":submitted,"movement":last_result.duplicate(true)}

func _on_image_clicked(pixel: Dictionary) -> void:
	if _submission.is_empty():return
	var submission: Dictionary=_submission
	_submission={}
	var event: Variant=pixel.get("caller_event_metadata")
	if not event is Dictionary or event.get("owner")!="current523_world_map_input" or event.get("nonce")!=submission.nonce:return
	var world: Node=_world.get_ref() if _world!=null else null
	var field: RefCounted=submission.field.get_ref()
	if not is_instance_valid(world) or field==null or world.field_map!=field or submission.epoch!=_open_epoch or _offer(field)!=_open_offer or submission.image_pack!=_image_pack_identity() or _pixel_identity(pixel)!=submission.pixel_identity:
		_remember(_fail("world_map_stale_click"));return
	var metadata: Variant=pixel.get("verified_image_metadata")
	var provenance: Variant=metadata.get("provenance") if metadata is Dictionary else null
	var relation: Variant=provenance.get("source_map_relation") if provenance is Dictionary else null
	if not relation is Dictionary or provenance.get("map_contract_sha256")!=_contract_pin or relation.get("world",{}).get("raw")!=_open_offer.source_world or relation.get("image_info",{}).get("raw")!=pixel.get("source_image_info") or pixel.get("source_world")!=_open_offer.source_world:
		_remember(_fail("world_map_click_source_relation_changed"));return
	var projected: Dictionary=COORDINATES.project(field,pixel,_options)
	if not projected.get("ok",false):_remember(projected);return
	var result: Dictionary=WALK.request(world,field,projected.source_components,submission.ticket)
	result["coordinate_registration"]=projected
	_remember(result)
	if world.hud.has_method("show_message"):
		world.hud.call("show_message","자체 지도 좌표 정책으로 보행합니다." if result.get("ok",false) else "지도 이동 보류: "+str(result.get("reason","world_map_walk_unavailable")))

func _current_gesture(world: Node, field: RefCounted, ui: Object) -> bool:
	return _gesture.get("epoch")==_open_epoch and _gesture.ui.get_ref()==ui and ui.call("is_open") and _gesture.get("image_pack")==_image_pack_identity() and _gesture.get("ticket")==WALK.ticket(world,field)

func _image_pack_identity() -> int:
	var pack: Variant=_image_owner.call("active") if _image_owner!=null else null
	return pack.get_instance_id() if pack is RefCounted else 0

static func _pixel_identity(pixel: Dictionary) -> Dictionary:
	return {"world_id":pixel.get("world_id"),"world_namespace":pixel.get("world_namespace"),"source_world":pixel.get("source_world"),"source_image_info":pixel.get("source_image_info"),"texture_size":pixel.get("texture_size"),"verified_image_metadata":pixel.get("verified_image_metadata"),"original_ui_source":pixel.get("original_ui_source")}

static func _uint(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=0 and float(value)<=2147483647

func _process(_delta: float) -> void:
	if _gesture.is_empty():return
	var ui: Object=_gesture.ui.get_ref()
	var world: Node=_world.get_ref() if _world!=null else null
	var field: RefCounted=_open_field.get_ref() if _open_field!=null else null
	if not is_instance_valid(ui) or not is_instance_valid(world) or field==null or world.field_map!=field or not _current_gesture(world,field,ui):_cancel()

func _cancel() -> void:
	_gesture={}
	_submission={}

func _exit_tree() -> void:
	_cancel()
	var world: Node=_world.get_ref() if _world!=null else null
	if is_instance_valid(world) and is_instance_valid(world.hud) and world.hud.is_connected("original_world_map_image_clicked",Callable(self,"_on_image_clicked")):
		world.hud.disconnect("original_world_map_image_clicked",Callable(self,"_on_image_clicked"))

func _remember(result: Dictionary) -> Dictionary:
	last_result=result.duplicate(true)
	return result

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"game_state_written":false}
