extends RefCounted
## Two original PageViews, each displaying the existing game's current page
## through the original five-slot Layout. No page count, gesture or use policy.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Bindings=preload("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
const ROOT="UI/QuickSlotScene.csb"
const ROOT_SHA="a62e6450247e2ae8e4c0e0588417d443fe08a45c54606c6050d267528b33ceff"
const ALL="UI/Main/Hud_QuickSlot_All.csb"
const ALL_SHA="670667993e83ff50068ec78156818f009972ba81ac30d162abfbe127be999088"
const PROJECT=3572
const PAGE_VIEWS: Array[int]=[2260,1732]
const PANEL=124
const BUTTON=20348
const ICON=18488
var _pack: RefCounted
var _hud: WeakRef
var _parent: WeakRef
var _bindings: RefCounted
var _scene: Node2D
var _hits: Dictionary={}
var _pages: Array[Control]=[]
var _identity: Array=[]
var _busy: bool=false

func configure(pack: RefCounted, hud: Node, image_provider: Callable) -> Dictionary:
	if pack==null or not is_instance_valid(hud):return _fail("source_quickslot_existing_host_required")
	for spec: Array in [[ROOT,ROOT_SHA],[ALL,ALL_SHA]]:
		if pack.manifest.get("files",{}).get(spec[0],{}).get("sha256")!=spec[1]:return _fail("source_quickslot_original_parent_identity_mismatch")
	_pack=pack
	_hud=weakref(hud)
	_bindings=Bindings.new()
	return _bindings.configure(pack,hud,image_provider)

func open(parent: Node) -> Dictionary:
	if not is_instance_valid(parent):return _fail("source_quickslot_existing_canvas_required")
	_parent=weakref(parent)
	return _stage(parent)

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion() and _scene.is_inside_tree()

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_hits.clear()
	_pages.clear()
	_identity.clear()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func refresh() -> Dictionary:
	if _busy:return {"ok":true,"handled":is_open(),"refresh_pending":true}
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if parent==null:return _fail("source_quickslot_canvas_unavailable")
	var model: Dictionary=_bindings.snapshot()
	if not model.get("ok",false):return _decline(model)
	if not is_open() or not _matches_identity(model):return _stage(parent)
	for row: Dictionary in model.rows:
		var hit: Dictionary=_hits.get(int(row.visible_index),{})
		if hit.is_empty():return _decline(_fail("source_quickslot_registered_slot_unavailable"))
		var result: Dictionary=_bindings.refresh_slot(hit.native_slot_scene,row)
		if not result.get("ok",false):return _decline(result)
	return {"ok":true,"handled":true,"partial_source_scene":true,"complete_screen_contract":false}

func hit_at(viewport_point: Vector2) -> Dictionary:
	if not is_open() or not viewport_point.is_finite():return {}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return {}
	for visible: int in _hits:
		var hit: Dictionary=_hits[visible]
		if not _contains(hit.control,viewport_point) or not _contains(_pages[int(visible/5)],viewport_point):continue
		# A game update may precede the next UI refresh. Never start a gesture
		# with a newly selected page/entry behind stale original pixels.
		var entries: Variant=hud.get("quickslot_entries")
		if not entries is Array or int(hud.call("quickslot_index",visible))!=int(hit.slot) or int(hit.slot)>=entries.size() or entries[int(hit.slot)]!=hit.entry:return {}
		var world: Node=hud.get_parent()
		var current: Variant=world.get("quickslots") if world!=null else null
		if not current is Array or int(hit.slot)>=current.size() or current[int(hit.slot)]!=hit.entry:return {}
		return hit.duplicate(true)
	return {}

func control_for(visible_index: int) -> Control:
	return _hits.get(visible_index,{}).get("control") if is_open() else null

func blocks_point(viewport_point: Vector2) -> bool:
	if not is_open():return false
	for control: Control in _pages:
		if _contains(control,viewport_point):return true
	return false

func _stage(parent: Node) -> Dictionary:
	_busy=true
	var model: Dictionary=_bindings.snapshot()
	if not model.get("ok",false):return _decline(model)
	var contracts: Array[Dictionary]=[]
	for group: int in range(PAGE_VIEWS.size()):
		var contract: Dictionary=_bindings.build_group(group)
		if not contract.get("ok",false):return _decline(contract)
		contracts.append(contract)
	var root_bindings: Dictionary={PROJECT:{"role":"project","source_node_offsets":PAGE_VIEWS,"bindings":{}}}
	for offset: int in PAGE_VIEWS:
		root_bindings[PROJECT].bindings[offset]={"role":"source_pages","input":Callable(self,"_page_input")}
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,ROOT,[PROJECT],root_bindings)
	if not result.get("ok",false):return _reject(next,result)
	var all: Dictionary=next.project_player([PROJECT])
	if not all.get("ok",false):return _reject(next,all)
	var hits: Dictionary={}
	var page_inputs: Array[Control]=[]
	for group: int in range(contracts.size()):
		var contract: Dictionary=contracts[group]
		var page_node: Variant=all.player.get("source_nodes").get(PAGE_VIEWS[group])
		var pages: Variant=(page_node.get_meta("source_pages") if page_node.has_meta("source_pages") else null) if is_instance_valid(page_node) else null
		if not is_instance_valid(pages):return _reject(next,_fail("source_quickslot_original_page_view_unavailable"))
		var scope: Array[int]=[]
		scope.assign(contract.source_node_offsets)
		var page:=Scene.new()
		result=page.configure_nodes(_pack,contract.member,scope,contract.bindings)
		if not result.get("ok",false):page.free();return _reject(next,result)
		result=pages.register_original_page(page,PANEL,int(model.pages[group]))
		if not result.get("ok",false):page.free();return _reject(next,result)
		result=pages.set_page_index(int(model.pages[group]))
		if not result.get("ok",false):return _reject(next,result)
		page_inputs.append(pages.input_control())
		for index: int in range(contract.rows.size()):
			var row: Dictionary=contract.rows[index]
			var offset: int=contract.slot_project_offsets[index]
			var slot: Dictionary=page.project_player([offset])
			if not slot.get("ok",false):return _reject(next,slot)
			var texture: Texture2D
			if not row.entry.is_empty():
				var uploaded: Dictionary=slot.player.set_bound_source_visual_result(ICON,contract.owner_results[offset])
				if not uploaded.get("ok",false) or (not uploaded.get("texture_assigned",false) and not uploaded.get("source_scene_assigned",false)):return _reject(next,uploaded)
				texture=uploaded.get("texture")
				result=slot.player.set_bound_visible(ICON,true)
				if not result.get("ok",false):return _reject(next,result)
			var button_node: Variant=slot.player.get("source_nodes").get(BUTTON)
			var button: Variant=(button_node.get_meta("source_button") if button_node.has_meta("source_button") else null) if is_instance_valid(button_node) else null
			var control: Variant=button.get("_input_area") if is_instance_valid(button) else null
			if not control is Control:return _reject(next,_fail("source_quickslot_original_slot_control_unavailable"))
			hits[int(row.visible_index)]={"from":"quick","slot":row.absolute_index,"visible":row.visible_index,"entry":row.entry.duplicate(true),"texture":texture,"control":control,"source_native":true,"native_slot_scene":slot.player}
	# Nothing is hidden until both complete current groups and every filled
	# icon have been accepted. Only the current game page is materialized.
	var previous: Node2D=_scene
	for visible: int in hits:
		var old: Dictionary=_hits.get(visible,{})
		if old.is_empty() or old.get("slot")!=hits[visible].slot or not is_instance_valid(old.get("native_slot_scene")):continue
		var old_entry: Dictionary=old.entry.duplicate(true)
		var new_entry: Dictionary=hits[visible].entry.duplicate(true)
		old_entry.erase("auto")
		new_entry.erase("auto")
		if old_entry!=new_entry:continue
		hits[visible].native_slot_scene.reuse_bound_source_scene_from(ICON,old.native_slot_scene,ICON)
	parent.add_child(next)
	_scene=next
	_hits=hits
	_pages=page_inputs
	_identity=_model_identity(model)
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():previous.hide();previous.queue_free()
	_busy=false
	return {"ok":true,"handled":true,"visible_slots":hits.size(),"current_pages":model.pages.duplicate(),"page_layout_basis":"Cocos2d-x3.6 UIPageView","host_template_registration":true,"original_client_registration_sequence_confirmed":false,"partial_source_scene":true,"complete_screen_contract":false}

func _page_input(_event: InputEvent) -> void:
	# PointerTransfer owns actual capture, page swipe, hold, assignment and use.
	pass

func _reject(next: Node2D, result: Dictionary) -> Dictionary:
	next.free()
	return _decline(result)

func _decline(result: Dictionary) -> Dictionary:
	_busy=false
	close()
	var declined: Dictionary=result.duplicate(true)
	declined["handled"]=false
	return declined

static func _model_identity(model: Dictionary) -> Array:
	var identity: Array=[model.pages.duplicate()]
	for row: Dictionary in model.rows:identity.append([row.visible_index,row.absolute_index,row.entry.duplicate(true)])
	return identity

func _matches_identity(model: Dictionary) -> bool:
	# _identity owns the deep snapshot taken when the scene was staged. Compare
	# the fresh validated model directly; unchanged refreshes need no second
	# deep copy of every entry or retained copy of the unused presentation rows.
	if _identity.size()!=model.rows.size()+1 or _identity[0]!=model.pages:return false
	for index: int in range(model.rows.size()):
		var row: Dictionary=model.rows[index]
		var previous: Array=_identity[index+1]
		if previous[0]!=row.visible_index or previous[1]!=row.absolute_index or previous[2]!=row.entry:return false
	return true

static func _contains(control: Control, point: Vector2) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
