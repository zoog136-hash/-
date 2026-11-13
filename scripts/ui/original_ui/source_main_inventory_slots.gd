extends RefCounted
const Markers=preload("res://scripts/ui/original_ui/source_main_inventory_markers.gd")
## Only authored slot instances. Host declares exact owned references for those
## positions; no row repetition, pagination, sorting, asset lookup or use gesture.
const PARENT="UI/FloatingUi/Inventory_All.csb"
const PARENT_SHA="c2c021fbc49f0699f2002a3f1cb73f523c3dd629bd1df567192dcb7f4da22293"
const SET_MEMBER="UI/FloatingUi/Inventory_Slot_Set.csb"
const SET_SHA="bf01b83b8732b68348c0c54a8402f3b0a08e51369ef6ccc680b23a12310ec1e4"
const SLOT_MEMBER="UI/CommonUi/Common_Slot.csb"
const SLOT_SHA="b0153e2324de4789e3a5f1d09030f370ed109583e893247656bee5affa3520d6"
const PARENTS={56036:55712,44156:43832}
const VARIANTS={
 "Nd_Slot":{"offset":4308,"slots":[5464,5212,4972,4732]},
 "Nd_Slot_Extension":{"offset":1856,"slots":[3900,3660,3420,3180,2940,2700,2460,2212]},
 "Nd_Slot_Extension_Lock":{"offset":128,"slots":[1444,1204,964,724]}
}
const BUTTON=15728
const BACKGROUND=15316
const ICON=15012
const SELECTED=9004
const AMOUNT=6880
signal selection_changed(reference: String)
var _pack: RefCounted
var _bag: WeakRef
var _icon_binding_provider: Callable

func configure(pack: RefCounted, hud: Node, icon_binding_provider: Callable=Callable()) -> Dictionary:
	if not is_instance_valid(hud):return _fail("source_inventory_slots_hud_unavailable")
	var bag: Variant=hud.get("lineage_inventory_ui")
	if not is_instance_valid(bag):return _fail("source_inventory_slots_existing_bag_required")
	for method: String in ["_inventory_entries","_select_item","_activate_selected"]:
		if not bag.has_method(method):return {"ok":false,"code":"source_inventory_slots_existing_bag_api_missing","method":method}
	_pack=pack
	_bag=weakref(bag)
	_icon_binding_provider=icon_binding_provider
	var identity: Dictionary=_identities()
	if not identity.get("ok",false):return identity
	return {"ok":true,"configured":true,"partial_source_scene":true,"complete_screen_contract":false}

func entries() -> Dictionary:
	var bag: Object=_live_bag()
	if bag==null:return _fail("source_inventory_slots_existing_bag_unavailable")
	if bag.has_method("prepare_source_inventory_model"):bag.call("prepare_source_inventory_model")
	var offered: Variant=bag.call("_inventory_entries")
	var displayed: Variant=bag.get("legacy_rows")
	if not offered is Array or not displayed is Array:return _fail("source_inventory_slots_existing_entries_unavailable")
	# One owner snapshot serves every authored slot in this synchronous refresh.
	# Preserve opaque physical references and duplicate detection; never join by
	# name or ask the owner to regenerate/sort its complete bag for each slot.
	var owned: Array=offered.duplicate(true)
	var owned_by_reference: Dictionary={}
	var owned_reference_counts: Dictionary={}
	for entry: Dictionary in owned:
		var reference: Variant=entry.get("reference")
		if reference is String:
			owned_by_reference[reference]=entry
			owned_reference_counts[reference]=int(owned_reference_counts.get(reference,0))+1
	# Renewal's existing owner keeps its filtered acquisition order in
	# sorted_references instead of the base bag's legacy_rows. Reuse that
	# exact order and resolve entries by their opaque reference, never re-sort.
	var ordered: Variant=bag.get("sorted_references")
	if ordered is Array:
		if bag.get("inventory_grid_dirty")==true:return _fail("source_inventory_slots_current_owner_model_dirty")
		displayed=[]
		for reference: String in ordered:
			if int(owned_reference_counts.get(reference,0))!=1:return _fail("source_inventory_slots_current_order_reference_not_unique")
			displayed.append(owned_by_reference[reference])
	var displayed_reference_counts: Dictionary={}
	for row: Dictionary in displayed:
		var reference: Variant=row.get("reference")
		if reference is String:displayed_reference_counts[reference]=int(displayed_reference_counts.get(reference,0))+1
	return {"ok":true,"owned_entries":owned,"current_display_rows":displayed.duplicate(true),"owned_by_reference":owned_by_reference,"owned_reference_counts":owned_reference_counts,"displayed_reference_counts":displayed_reference_counts,"selected_reference":bag.get("selected_item"),"assignment_required":true,"partial_source_scene":true,"complete_screen_contract":false}

func build(parent_project_offset: int, assignments: Dictionary, scroll_binding: Dictionary={}, variant: String="Nd_Slot", current_model: Dictionary={}) -> Dictionary:
	var identity: Dictionary=_identities()
	if not identity.get("ok",false):return identity
	if not PARENTS.has(parent_project_offset):return _fail("source_inventory_slots_parent_project_unknown")
	if not VARIANTS.has(variant):return _fail("source_inventory_slots_authored_variant_unknown")
	var authored: Dictionary=VARIANTS[variant]
	var used_references: Dictionary={}
	for offset: Variant in assignments:
		if offset not in authored.slots:return {"ok":false,"code":"source_inventory_slots_unwritten_position","offset":offset}
		var reference: Variant=assignments[offset]
		if not reference is String or reference.is_empty():return _fail("source_inventory_slots_exact_reference_required")
		if used_references.has(reference):return _fail("source_inventory_slots_duplicate_owned_reference")
		used_references[reference]=true
	var model: Dictionary=current_model
	if model.is_empty() and not used_references.is_empty():model=entries()
	if not model.is_empty() and not model.get("ok",false):return model
	var set_bindings: Dictionary={}
	var set_scope: Array[int]=[]
	var unresolved: Array=[]
	var owner_results: Dictionary={}
	for offset: int in authored.slots:
		set_scope.append(offset)
		var reference: String=str(assignments.get(offset,""))
		var slot: Dictionary=_slot_binding(offset,reference,model)
		if not slot.get("ok",false):return slot
		set_bindings[offset]=slot.binding
		if slot.has("owner_result"):owner_results[offset]=slot.owner_result
		unresolved.append_array(slot.unresolved_fields)
	# The exact authored variant is selected explicitly by the host. Its
	# original parent geometry is untouched; no capacity/page rule is derived.
	set_bindings[int(authored.offset)]={"visible":true}
	var parent_bindings: Dictionary={}
	parent_bindings[parent_project_offset]={"role":"project","source_node_offsets":set_scope,"bindings":set_bindings}
	var scroll_offset: int=int(PARENTS[parent_project_offset])
	if scroll_binding.get("role")=="source_scroll" and scroll_binding.get("input") is Callable and scroll_binding.input.is_valid():
		parent_bindings[scroll_offset]=scroll_binding.duplicate(true)
	else:unresolved.append({"field":"existing_native_scroll_input_binding","offset":scroll_offset,"required":"caller source_scroll binding with existing input Callable"})
	return {"ok":true,"member":PARENT,"sha256":PARENT_SHA,"source_node_offsets":[parent_project_offset],"bindings":parent_bindings,"slot_set_member":SET_MEMBER,"slot_set_sha256":SET_SHA,"authored_variant":variant,"authored_slot_offsets":set_scope,"assignments":assignments.duplicate(true),"owner_results":owner_results,"unassigned_authored_slots":_unassigned(authored.slots,assignments),"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":unresolved,"additional_rows_or_page_rules_created":false,"use_gesture_bound":false,"rebuild_on_owned_rows_or_assignments_change":true}

func refresh_slot(slot_scene: Node2D, reference: String, current_model: Dictionary={}) -> Dictionary:
	if not is_instance_valid(slot_scene) or str(slot_scene.get("source_member"))!=SLOT_MEMBER:return _fail("source_inventory_slots_original_scene_required")
	if not slot_scene.has_method("set_bound_visible") or not slot_scene.has_method("set_bound_text"):return _fail("source_inventory_slots_existing_scene_api_missing")
	var identity: Dictionary=_identities()
	if not identity.get("ok",false):return identity
	if reference.is_empty():return slot_scene.set_bound_visible(SELECTED,false)
	var owned: Dictionary=_resolve_reference(reference,current_model)
	if not owned.get("ok",false):
		owned["scope_rebuild_required"]=true
		return owned
	if typeof(owned.entry.get("amount"))!=TYPE_INT:return _fail("source_inventory_slots_existing_amount_required")
	var result: Dictionary=slot_scene.set_bound_text(AMOUNT,str(owned.entry.amount))
	if not result.get("ok",false):return result
	result=slot_scene.set_bound_visible(AMOUNT,true)
	if not result.get("ok",false):return result
	result=slot_scene.set_bound_visible(SELECTED,_live_bag().get("selected_item")==reference)
	if not result.get("ok",false):return result
	var markers: Dictionary=Markers.build(_live_bag(),owned.entry)
	if not markers.get("ok",false):return markers
	for offset: int in markers.source_node_offsets:
		if not slot_scene.get("source_nodes").has(offset):continue
		result=slot_scene.set_bound_visible(offset,bool(markers.bindings[offset].visible))
		if not result.get("ok",false):return result
	return {"ok":true,"reference":reference,"partial_source_scene":true,"game_state_written":false}

func select_reference(reference: String) -> Dictionary:
	var owned: Dictionary=_resolve_reference(reference)
	if not owned.get("ok",false):return owned
	var bag: Object=_live_bag()
	if bag==null:return _fail("source_inventory_slots_existing_bag_unavailable")
	bag.call("_select_item",reference)
	selection_changed.emit(reference)
	return {"ok":true,"selected_reference":reference,"use_requested":false,"game_transaction_performed":false}

func activate_existing_selection(reference: String) -> Dictionary:
	# Exposed for the host's existing select/use flow only. No original
	# double-click contract exists here, so slot clicks never call this method.
	var owned: Dictionary=_resolve_reference(reference)
	if not owned.get("ok",false):return owned
	var bag: Object=_live_bag()
	if bag==null or bag.get("selected_item")!=reference:return _fail("source_inventory_slots_existing_selection_required")
	bag.call("_activate_selected")
	return {"ok":true,"emitted":true,"reference":reference,"action_result_known":false}

func _slot_binding(offset: int, reference: String, current_model: Dictionary) -> Dictionary:
	var scope: Array[int]=[BUTTON,BACKGROUND,SELECTED]
	var bindings: Dictionary={BUTTON:{"role":"button","displaystate":false,"activate":Callable()},SELECTED:{"visible":false}}
	var unresolved: Array=[]
	if not reference.is_empty():
		var owned: Dictionary=_resolve_reference(reference,current_model)
		if not owned.get("ok",false):return owned
		var entry: Dictionary=owned.entry
		if typeof(entry.get("amount"))!=TYPE_INT:return _fail("source_inventory_slots_existing_amount_required")
		var markers: Dictionary=Markers.build(_live_bag(),entry)
		if not markers.get("ok",false):return markers
		var allowed: Variant=_pack.manifest.get("node_scopes",{}).get(SLOT_MEMBER)
		for marker_offset: int in markers.source_node_offsets:
			if allowed is Array and not allowed.has(marker_offset):
				unresolved.append({"field":"original_item_marker_outside_selected_pack_scope","offset":marker_offset})
				continue
			scope.append(marker_offset)
			bindings[marker_offset]=markers.bindings[marker_offset].duplicate(true)
		unresolved.append_array(markers.unresolved_markers)
		bindings[BUTTON]={"role":"button","activate":Callable(self,"select_reference").bind(reference)}
		bindings[SELECTED]={"visible":_live_bag().get("selected_item")==reference}
		scope.append(AMOUNT)
		# Text_Amount is preview-hidden. An actual owned entry supplies its
		# amount before making this existing original text node visible.
		bindings[AMOUNT]={"role":"source_text","text":str(entry.amount),"visible":true}
		if not _icon_binding_provider.is_valid():return {"ok":false,"handled":false,"code":"source_inventory_slots_existing_icon_provider_required","reference":reference,"slot_project_offset":offset}
		# The current image owner provides pixels/provenance, not an asset-ref
		# for a second lookup. Native renderer handles its existing upload API.
		var supplied: Variant=_icon_binding_provider.call(entry.duplicate(true),{"member":SLOT_MEMBER,"node_offset":ICON,"slot_project_offset":offset,"reference":reference})
		if not supplied is Dictionary:return _fail("source_inventory_slots_existing_owner_result_invalid")
		if not supplied.get("ok",false) or (not supplied.get("texture") is Texture2D and not supplied.get("source_scene_descriptor") is Dictionary):
			# An item with no original picture keeps its original slot with
			# the picture left empty (nothing drawn or substituted); one such
			# item no longer sends the whole bag back to the TWILIGHT bag.
			unresolved.append({"field":"owned_original_icon_unavailable","reference":reference,"code":str(supplied.get("code",supplied.get("reason","")))})
			return {"ok":true,"binding":{"role":"project","source_node_offsets":scope,"bindings":bindings},"icon_missing":true,"unresolved_fields":unresolved}
		scope.append(ICON)
		bindings[ICON]={"role":"source_asset_slot","visible":false}
		return {"ok":true,"binding":{"role":"project","source_node_offsets":scope,"bindings":bindings},"owner_result":supplied,"unresolved_fields":unresolved}
	return {"ok":true,"binding":{"role":"project","source_node_offsets":scope,"bindings":bindings},"unresolved_fields":unresolved}

func _resolve_reference(reference: String, current_model: Dictionary={}) -> Dictionary:
	# Actions use a fresh snapshot by default, so stale hits still recheck live
	# ownership/filtering. Only a single synchronous presentation shares one.
	var current: Dictionary=entries() if current_model.is_empty() else current_model
	if not current.get("ok",false):return current
	if reference.is_empty() or int(current.owned_reference_counts.get(reference,0))!=1:return _fail("source_inventory_slots_current_owned_reference_not_unique")
	if int(current.displayed_reference_counts.get(reference,0))!=1:return _fail("source_inventory_slots_reference_not_in_current_bag_filter")
	return {"ok":true,"entry":current.owned_by_reference[reference].duplicate(true)}

func _identities() -> Dictionary:
	if _pack==null:return _fail("source_inventory_slots_source_pack_required")
	for expected: Array in [[PARENT,PARENT_SHA],[SET_MEMBER,SET_SHA],[SLOT_MEMBER,SLOT_SHA]]:
		if _pack.manifest.get("files",{}).get(expected[0],{}).get("sha256","")!=expected[1]:return {"ok":false,"code":"source_inventory_slots_original_identity_mismatch","member":expected[0]}
	return {"ok":true}

func _live_bag() -> Object:
	return _bag.get_ref() if _bag!=null else null

static func _unassigned(slots: Array, assignments: Dictionary) -> Array:
	var result: Array=[]
	for offset: int in slots:
		if not assignments.has(offset):result.append(offset)
	return result

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
