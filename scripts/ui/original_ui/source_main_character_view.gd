extends RefCounted
## The existing character tab caller opens the original six-value stats scope.
## Original parents, their opening clip and input nodes supply all geometry.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Stats=preload("res://scripts/ui/original_ui/source_main_character_stats_bindings.gd")
const PARENT="UI/FloatingUiScene.csb"
const PARENT_SHA="b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8"
const PROJECT=12856
const ALL="UI/FloatingUi/CharacterInfo_All.csb"
const ALL_SHA="d19edfa099c5770cf43f08bd73f9370185ac7dbccdb67b89bf39d77330527be7"
const STATS_PROJECT=1384
const CLOSE=2544
const DETAIL=4552
const DETAIL_TITLE=5020
const EQUIP_TABS: Array[int]=[16212,14056]
const STATS_TABS: Array[int]=[11168,9064]
const CHROME: Array[int]=[22036,21628,21192,20820,20424,19940,19600,19208,18868]
signal closed
signal return_to_equipment_requested
var _pack: RefCounted
var _hud: WeakRef
var _scene: Node2D
var _stats: Node2D
var _model: Dictionary={}
var _bounds: Control

func configure(pack: RefCounted, hud: Node) -> Dictionary:
	if pack==null or not is_instance_valid(hud):return _fail("source_character_existing_host_required")
	if pack.manifest.get("files",{}).get(PARENT,{}).get("sha256")!=PARENT_SHA or pack.manifest.get("files",{}).get(ALL,{}).get("sha256")!=ALL_SHA:return _fail("source_character_original_parent_identity_mismatch")
	_pack=pack
	_hud=weakref(hud)
	return {"ok":true,"partial_source_scene":true,"complete_screen_contract":false}

func open_stats(parent: Node) -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null or not is_instance_valid(parent):return _fail("source_character_original_mount_unavailable")
	var side: Variant=hud.get("lineage_side_ui")
	var current_page: Variant=side.get("stats_page") if is_instance_valid(side) else null
	if not current_page is Control or not current_page.visible:return _fail("source_character_existing_stats_tab_selection_required")
	var owner_actions: Dictionary=_owner_actions_supported(hud)
	if not owner_actions.get("ok",false):return owner_actions
	var contract: Dictionary=Stats.build(_pack,hud)
	if not contract.get("ok",false):return contract
	if not hud.has_method("open_detailed_status"):return _fail("source_character_existing_detail_caller_required")
	contract.source_node_offsets.append(DETAIL)
	contract.source_node_offsets.append(DETAIL_TITLE)
	contract.bindings[DETAIL]={"role":"button","activate":Callable(self,"_detail_requested")}
	contract.bindings[DETAIL_TITLE]={"role":"static_source_text"}
	if is_open():return refresh()
	var scope: Array[int]=CHROME.duplicate()
	scope.append(CLOSE)
	scope.append(STATS_PROJECT)
	var bindings: Dictionary={22036:{"role":"consume"},CLOSE:{"role":"button","activate":Callable(self,"_close_requested")},STATS_PROJECT:{"role":"project","visible":true,"source_node_offsets":contract.source_node_offsets,"bindings":contract.bindings}}
	for pair: Array in [[EQUIP_TABS,[16612,14460]],[STATS_TABS,[11568,9464]]]:
		var is_stats: bool=pair[0]==STATS_TABS
		for index: int in range(2):
			var offset: int=pair[0][index]
			scope.append(offset)
			scope.append(pair[1][index])
			bindings[offset]={"role":"button","visible":is_stats if index==0 else not is_stats,"activate":Callable(self,"_stats_requested") if is_stats else Callable(self,"_equipment_requested")}
			bindings[pair[1][index]]={"role":"static_source_text"}
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,PARENT,[PROJECT],{PROJECT:{"role":"project","source_node_offsets":scope,"bindings":bindings}})
	if not result.get("ok",false):next.free();return result
	var child: Dictionary=next.project_player([PROJECT,STATS_PROJECT])
	if not child.get("ok",false):next.free();return child
	var all: Dictionary=next.project_player([PROJECT])
	if not all.get("ok",false):next.free();return all
	var background: Variant=all.player.get("source_nodes").get(22036)
	var bounds: Control
	if is_instance_valid(background):
		var origin: Node=background.get_node_or_null("SourceContentOrigin")
		if origin!=null:
			for node: Node in origin.get_children():
				if node is Control and node.mouse_filter==Control.MOUSE_FILTER_STOP:bounds=node;break
	if bounds==null:next.free();return _fail("source_character_original_background_input_missing")
	# This is the actual source parent clip for CharacterInfo_All_Layout.
	# CharacterInfo_StatInfo_On belongs to another parent layout; it is not
	# selected merely because its name contains StatInfo.
	result=next.play("CharacterInfo_All_On",false)
	if not result.get("ok",false):next.free();return result
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_stats=child.player
	_bounds=bounds
	_model=contract["values"].duplicate(true)
	var fields: Array=Stats.FIELDS.duplicate()
	if contract.get("dth_source_connected",false):fields.append("dth")
	return {"ok":true,"handled":true,"member":ALL,"tab":"stats","bound_fields":fields,"dth_source_connected":contract.get("dth_source_connected",false),"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false,"unresolved_fields":["LFE_Elixir_detail_contracts","DTH requires original active scope and actual host integer","equipment class/mode to page selection and remaining slot aliases","nickname and other original character modes"]}

func refresh() -> Dictionary:
	if not is_open():return _fail("source_character_stats_not_open")
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var owner_actions: Dictionary=_owner_actions_supported(hud)
	if not owner_actions.get("ok",false):close();return owner_actions
	var model: Dictionary=Stats.snapshot(hud)
	if not model.get("ok",false):close();return model
	if model["values"]==_model:return {"ok":true,"handled":true,"read_only":true,"partial_source_scene":true}
	var result: Dictionary=Stats.refresh(_stats,hud)
	if not result.get("ok",false):close();return result
	_model=result["values"].duplicate(true)
	return result

func presentation() -> Dictionary:
	return {"scene":_scene,"gesture_bounds":_bounds,"partial_source_scene":true}

func blocks_point(point: Vector2) -> bool:
	if not is_open() or not is_instance_valid(_bounds) or not _bounds.is_visible_in_tree() or not point.is_finite():return false
	var local: Vector2=_bounds.get_global_transform_with_canvas().affine_inverse()*point
	return Rect2(Vector2.ZERO,_bounds.size).has_point(local)

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_stats=null
	_bounds=null
	_model.clear()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true,"game_state_written":false}

func _equipment_requested() -> Dictionary:
	close()
	return_to_equipment_requested.emit()
	return {"ok":true,"existing_equipment_caller_requested":true,"game_state_written":false}

func _stats_requested() -> Dictionary:
	return refresh()

func _detail_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null or not hud.has_method("open_detailed_status"):return _fail("source_character_existing_detail_caller_unavailable")
	hud.call("open_detailed_status")
	return {"ok":true,"existing_detail_caller_requested":true,"game_state_written":false}

static func _owner_actions_supported(hud: Object) -> Dictionary:
	if not is_instance_valid(hud):return _fail("source_character_existing_host_unavailable")
	var state: Variant=hud.get("character_state")
	if not state is Dictionary or typeof(state.get("stat_points"))!=TYPE_INT:return _fail("source_character_existing_stat_points_required")
	# The existing owner exposes spending when points are available. Until
	# the original Normal/Pressed button action is established, retain that
	# actual input path instead of hiding it behind this read-only scope.
	if state.stat_points!=0:return _fail("source_character_original_stat_spending_action_unestablished")
	return {"ok":true}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
