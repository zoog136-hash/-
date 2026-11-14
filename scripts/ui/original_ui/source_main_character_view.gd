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
const Equipment=preload("res://scripts/ui/original_ui/source_main_character_equipment_bindings.gd")
const EQUIP_PROJECT=1648
const EQUIP_BG=22296
const EQUIP_PAGES=21220
const PAGE_MEMBERS: Array[String]=["UI/FloatingUi/CharacterInfo_EquipSlotSet_A.csb","UI/FloatingUi/CharacterInfo_EquipSlotSet_B.csb"]
var _equipment: RefCounted
var _page_view: Node2D
var _page_index: int=0
var _page_drag: float=0.0
var _mode: String=""
var _parent: WeakRef
signal closed
signal return_to_equipment_requested
var _pack: RefCounted
var _hud: WeakRef
var _scene: Node2D
var _stats: Node2D
var _model: Dictionary={}
var _bounds: Control

func configure(pack: RefCounted, hud: Node, image_provider: Callable=Callable()) -> Dictionary:
	if pack==null or not is_instance_valid(hud):return _fail("source_character_existing_host_required")
	if pack.manifest.get("files",{}).get(PARENT,{}).get("sha256")!=PARENT_SHA or pack.manifest.get("files",{}).get(ALL,{}).get("sha256")!=ALL_SHA:return _fail("source_character_original_parent_identity_mismatch")
	_pack=pack
	_hud=weakref(hud)
	if image_provider.is_valid():
		var candidate=Equipment.new()
		if candidate.configure(pack,hud,image_provider).get("ok",false):_equipment=candidate
	return {"ok":true,"partial_source_scene":true,"complete_screen_contract":false,"equipment_page":_equipment!=null}

## The original equipment tab: CharacterInfo_All with its EquipInfo page and
## the two original slot pages (EquipSlotSet_A/B) in the EquipInfo PageView.
## Each slot shows the TWILIGHT item equipped in its physical slot; tapping
## one runs the existing equipment button (unequip/detail as before).
func open_equipment(parent: Node) -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null or not is_instance_valid(parent):return _fail("source_character_original_mount_unavailable")
	if _equipment==null:return _fail("source_character_original_equipment_unavailable")
	for member: String in PAGE_MEMBERS:
		if not _pack.manifest.get("scenes",{}).has(member):return _fail("source_character_original_equipment_page_missing")
	var contracts: Array[Dictionary]=[]
	for member: String in PAGE_MEMBERS:
		var contract: Dictionary=_equipment.build(member)
		if not contract.get("ok",false):return contract
		contracts.append(contract)
	close()
	var scope: Array[int]=CHROME.duplicate()
	scope.append(CLOSE)
	scope.append(EQUIP_PROJECT)
	var bindings: Dictionary={22036:{"role":"consume"},CLOSE:{"role":"button","activate":Callable(self,"_close_requested")},EQUIP_PROJECT:{"role":"project","visible":true,"source_node_offsets":[EQUIP_BG,EQUIP_PAGES],"bindings":{EQUIP_PAGES:{"role":"source_pages","input":Callable(self,"_page_input")}}}}
	for pair: Array in [[EQUIP_TABS,[16612,14460]],[STATS_TABS,[11568,9464]]]:
		var is_equipment: bool=pair[0]==EQUIP_TABS
		for index: int in range(2):
			var offset: int=pair[0][index]
			scope.append(offset)
			scope.append(pair[1][index])
			bindings[offset]={"role":"button","visible":is_equipment if index==0 else not is_equipment,"activate":Callable(self,"_equipment_tab_requested") if is_equipment else Callable(self,"_stats_tab_requested")}
			bindings[pair[1][index]]={"role":"static_source_text"}
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,PARENT,[PROJECT],{PROJECT:{"role":"project","source_node_offsets":scope,"bindings":bindings}})
	if not result.get("ok",false):next.free();return result
	var info: Dictionary=next.project_player([PROJECT,EQUIP_PROJECT])
	if not info.get("ok",false):next.free();return info
	var page_node: Variant=info.player.get("source_nodes").get(EQUIP_PAGES)
	var pages: Variant=(page_node.get_meta("source_pages") if page_node.has_meta("source_pages") else null) if is_instance_valid(page_node) else null
	if not is_instance_valid(pages):next.free();return _fail("source_character_original_page_view_unavailable")
	for index: int in range(contracts.size()):
		var contract: Dictionary=contracts[index]
		var page_scope: Array[int]=[]
		page_scope.assign(contract.source_node_offsets)
		page_scope.append(int(contract.panel_offset))
		var page:=Scene.new()
		result=page.configure_nodes(_pack,contract.member,page_scope,contract.bindings)
		if not result.get("ok",false):page.free();next.free();return result
		result=pages.register_original_page(page,int(contract.panel_offset),index)
		if not result.get("ok",false):page.free();next.free();return result
		for offset: Variant in contract.owner_results:
			var slot: Dictionary=page.project_player([int(offset)])
			if not slot.get("ok",false):next.free();return slot
			var uploaded: Dictionary=slot.player.set_bound_source_visual_result(Equipment.ICON,contract.owner_results[offset])
			if not uploaded.get("ok",false):next.free();return uploaded
			result=slot.player.set_bound_visible(Equipment.ICON,true)
			if not result.get("ok",false):next.free();return result
	_page_index=clampi(_page_index,0,contracts.size()-1)
	pages.set_page_index(_page_index)
	var all: Dictionary=next.project_player([PROJECT])
	if not all.get("ok",false):next.free();return all
	var bounds: Control=_background_input(all.player)
	if bounds==null:next.free();return _fail("source_character_original_background_input_missing")
	result=next.play("CharacterInfo_All_On",false)
	if not result.get("ok",false):next.free();return result
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_bounds=bounds
	_page_view=pages
	_mode="equipment"
	_parent=weakref(parent)
	return {"ok":true,"handled":true,"member":ALL,"tab":"equipment","pages":PAGE_MEMBERS.duplicate(),"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false}

static func _background_input(all_player: Node) -> Control:
	var background: Variant=all_player.get("source_nodes").get(22036)
	if not is_instance_valid(background):return null
	var origin: Node=background.get_node_or_null("SourceContentOrigin")
	if origin==null:return null
	for node: Node in origin.get_children():
		if node is Control and node.mouse_filter==Control.MOUSE_FILTER_STOP:return node
	return null

func _page_input(event: InputEvent) -> void:
	if not is_instance_valid(_page_view):return
	if (event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT)) and event.pressed:
		_page_drag=0.0
		return
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT):
		_page_drag+=event.relative.x
		if absf(_page_drag)>=60.0:
			var next_index: int=_page_index+(1 if _page_drag<0.0 else -1)
			_page_drag=0.0
			if next_index>=0 and next_index<PAGE_MEMBERS.size() and _page_view.set_page_index(next_index).get("ok",false):_page_index=next_index

func _equipment_tab_requested() -> Dictionary:
	return {"ok":true,"handled":true}

func _stats_tab_requested() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var parent: Object=_parent.get_ref() if _parent!=null else null
	var side: Variant=hud.get("lineage_side_ui") if hud!=null else null
	if is_instance_valid(side) and side.has_method("_show_stats_page"):side.call("_show_stats_page")
	close()
	var opened: Dictionary=open_stats(parent) if parent!=null else _fail("source_character_original_mount_unavailable")
	# The stats page refuses while stat points can be spent: show the existing
	# character window on its stats tab instead.
	if not opened.get("handled",false) and hud!=null and hud.has_method("open_character"):hud.call("open_character")
	return opened

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
	if is_open() and _mode=="stats":return refresh()
	close()
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
	_mode="stats"
	_parent=weakref(parent)
	_model=contract["values"].duplicate(true)
	return {"ok":true,"handled":true,"member":ALL,"tab":"stats","bound_fields":Stats.FIELDS.duplicate(),"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false,"unresolved_fields":["LFE_DTH_Elixir_detail_contracts","equipment class/mode to page selection and remaining slot aliases","nickname and other original character modes"]}

func refresh() -> Dictionary:
	if not is_open():return _fail("source_character_stats_not_open")
	if _mode=="equipment":
		var parent: Object=_parent.get_ref() if _parent!=null else null
		return open_equipment(parent) if parent!=null else _fail("source_character_original_mount_unavailable")
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
	_page_view=null
	_mode=""
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
