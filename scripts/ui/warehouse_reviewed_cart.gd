extends RefCounted
## Explicit TWILIGHT session cart. Only deliberate activation stages a row.
## Not the private native Cart controller; World owns all eligibility and saves.
const OWNER="res://scripts/ui/renewal_warehouse.gd"
var _owner: WeakRef
var _world: WeakRef
var entries: Array[Dictionary]=[]
var direction: String=""
var phase: String="idle"
var last_result: Dictionary={}
var recovery_history: Array[Dictionary]=[]
var _generation: int=0
var _quote: Dictionary={}
var _quote_context: Dictionary={}
var _dialog: WeakRef
var _touch: Dictionary={}
var _controls: Dictionary={}
var _discard_token: String=""
var _discard_generation: int=-1

func configure(owner: Control) -> Dictionary:
	if not is_instance_valid(owner) or owner.get_script()==null or owner.get_script().resource_path!=OWNER:return _fail("review_cart_actual_owner_required")
	_owner=weakref(owner);_world=weakref(owner.world)
	for field: String in ["listing","quantity","mode","action","summary"]:
		var control: Variant=owner.get(field)
		if not control is Control or not is_instance_valid(control) or not owner.is_ancestor_of(control):return _fail("review_cart_actual_controls_required")
		_controls[field]=weakref(control)
	var held: Array=owner.world.get_meta("twilight_warehouse_held_ui_carts",[])
	var resolved: Dictionary=owner.world.get_meta("twilight_warehouse_ui_recovery_discarded",{})
	for index: int in range(held.size()-1,-1,-1):
		var record: Dictionary=held[index]
		var request: String=str(record.get("last_result",{}).get("ui_request",{}).get("request_id",""))
		if record.get("world_id")!=owner.world.get_instance_id() or resolved.has(request):continue
		if record.get("phase") not in ["uncertain","restored_pending_discard"]:continue
		entries.assign(record.get("entries",[]));direction=str(record.get("direction",""));phase=str(record.phase)
		last_result=record.get("last_result",{}).duplicate(true);_quote=record.get("issued_quote",{}).duplicate(true)
		recovery_history.assign(record.get("recovery_history",[]))
		break
	owner.listing.item_activated.connect(_activated)
	owner.quantity.value_changed.connect(_quantity_changed)
	owner.tree_exiting.connect(close,CONNECT_ONE_SHOT)
	owner.visibility_changed.connect(_visibility_changed)
	return {"ok":true,"host_policy":"double activation toggles exact current row/count; changed count explicitly replaces that row; never auto-fill","original_controller_recovered":false}

func stage_current() -> Dictionary:
	var current: Dictionary=_selected()
	if not current.get("ok",false):return current
	return _stage(current.intent)

func remove_reviewed(intent: Dictionary) -> Dictionary:
	if phase in ["confirming","uncertain","restored_pending_discard"]:return _fail("review_cart_transaction_held")
	for index: int in range(entries.size()):
		if entries[index]==intent:
			entries.remove_at(index);_invalidate()
			if entries.is_empty():direction=""
			_present();return {"ok":true,"removed":true,"transaction_requested":false}
	return _fail("review_cart_exact_reviewed_entry_required")

func owner_changed() -> void:
	if phase=="review" and _quote_context==_context():_present();return
	if phase!="confirming":_invalidate()
	_present()

func _quantity_changed(_value: float) -> void:
	owner_changed()

func _activated(index: int) -> void:
	var current: Dictionary=_selected()
	if not current.get("ok",false) or current.index!=index:return
	var result: Dictionary=_stage(current.intent)
	if not result.get("ok",false):last_result=result.duplicate(true);_present()

func input(event: InputEvent) -> void:
	# The retained native-touch list emits selection on release, not activation.
	# This separate, explicit host double-tap gesture never changes its selection
	# or consumes its event. Recheck the captured physical/source row on release.
	var owner: Object=_live()
	if owner==null:return
	var listing: ItemList=owner.listing
	if event is InputEventScreenTouch and event.device!=InputEvent.DEVICE_ID_EMULATION and event.pressed:
		_touch.clear()
		if not event.double_tap or event.canceled or _has_modal(owner):return
		if owner.hud.has_method("blocks_keyboard_input") and owner.hud.blocks_keyboard_input():return
		if owner.hud.has_method("original_source_pointer_capture_blocked") and owner.hud.original_source_pointer_capture_blocked(event.position):return
		var point: Vector2=listing.get_global_transform_with_canvas().affine_inverse()*event.position
		if not Rect2(Vector2.ZERO,listing.size).has_point(point):return
		var current: Dictionary=_selected()
		if not current.get("ok",false) or listing.get_item_at_position(point,true)!=current.index:return
		_touch={"finger":event.index,"origin":event.position,"index":current.index,"intent":current.intent.duplicate(true),"direction":current.direction,"generation":_generation,"dragged":false}
	elif event is InputEventScreenDrag and not _touch.is_empty() and event.index==_touch.finger:
		if event.position.distance_to(_touch.origin)>10.0:_touch.dragged=true
	elif event is InputEventScreenTouch and not _touch.is_empty() and event.index==_touch.finger and not event.pressed:
		var captured: Dictionary=_touch.duplicate(true);_touch.clear()
		var point: Vector2=listing.get_global_transform_with_canvas().affine_inverse()*event.position
		if event.canceled or captured.dragged or event.position.distance_to(captured.origin)>10.0 or not Rect2(Vector2.ZERO,listing.size).has_point(point) or listing.get_item_at_position(point,true)!=captured.index or _has_modal(owner):return
		# Native selection may reset the editor to1 after this same gesture.
		# Stage only the exact count deliberately captured from the selected row,
		# after deferred native selection has completed; never infer a quantity.
		call_deferred("_released_activation",captured)

func _released_activation(captured: Dictionary) -> void:
	var current: Dictionary=_selected(int(captured.intent.quantity))
	if not current.get("ok",false) or current.index!=captured.index or current.direction!=captured.direction or current.intent!=captured.intent:return
	var result: Dictionary=_stage(current.intent)
	if not result.get("ok",false):last_result=result.duplicate(true);_present()

func _stage(intent: Dictionary) -> Dictionary:
	if phase=="restored_pending_discard":return request_discard_after_restored_load()
	if phase in ["confirming","uncertain"]:return _fail("review_cart_transaction_or_recovery_held")
	var owner: Object=_live()
	if owner==null:return _fail("review_cart_live_owner_required")
	var actual_direction: String="deposit" if owner.mode.selected==0 else "withdraw"
	if not entries.is_empty() and direction!=actual_direction:return _fail("review_cart_mixed_direction_rejected")
	var problem: Dictionary=_validate_intent(intent,actual_direction)
	if not problem.get("ok",false):return problem
	for index: int in range(entries.size()):
		if _key(entries[index])!=_key(intent):continue
		if entries[index]==intent:entries.remove_at(index)
		else:entries[index]=intent.duplicate(true)
		_invalidate();direction=actual_direction if not entries.is_empty() else "";_present()
		return {"ok":true,"reviewed_entries":entries.duplicate(true),"transaction_requested":false}
	entries.append(intent.duplicate(true));direction=actual_direction;_invalidate();_present()
	return {"ok":true,"reviewed_entries":entries.duplicate(true),"transaction_requested":false}

func snapshot() -> Dictionary:
	var world: Object=_world.get_ref() if _world!=null else null
	return {"ok":true,"world_id":world.get_instance_id() if is_instance_valid(world) else 0,"direction":direction,"entries":entries.duplicate(true),"phase":phase,"last_result":last_result.duplicate(true),"issued_quote":_quote.duplicate(true),"recovery_history":recovery_history.duplicate(true),"generation":_generation,"original_controller_recovered":false,"all_means":"only these explicitly staged reviewed entries"}

func available(actual_direction: String) -> bool:
	var owner: Object=_live()
	if owner==null or phase!="idle" or entries.is_empty() or direction!=actual_direction or actual_direction!=("deposit" if owner.mode.selected==0 else "withdraw") or not owner.world.has_method("quote_warehouse_batch") or not owner.world.has_method("confirm_warehouse_batch"):return false
	var batch: Variant=owner.world.get("_explicit_warehouse_batch")
	return is_instance_valid(batch) and batch.get("busy")==false and batch.get("uncertain")==false

func review(actual_direction: String) -> Dictionary:
	if not available(actual_direction):return _fail("review_cart_nonempty_actual_direction_and_batch_api_required")
	var owner: Object=_live()
	if _has_modal(owner):return _fail("review_cart_existing_confirmation_busy")
	for intent: Dictionary in entries:
		var checked: Dictionary=_validate_intent(intent,direction)
		if not checked.get("ok",false):return checked
	var context: Dictionary=_context()
	var expected: Array=entries.duplicate(true)
	var offered: Variant=owner.world.call("quote_warehouse_batch",direction,expected)
	if not offered is Dictionary or not offered.get("ok",false):return _refusal(offered)
	if not offered.get("quote_id") is String or offered.quote_id.is_empty() or offered.get("entries")!=expected or offered.get("direction")!=direction or offered.get("atomic")!=true or offered.get("save_count")!=1 or offered.get("confirmation_required")!=true or offered.get("transfer_limit_per_entry")!=99 or offered.get("cost_policy")!="existing_single_transfer_no_added_fee" or offered.get("native_partial_partition_supported")!=false:return _fail("review_cart_incompatible_quote_contract")
	if context!=_context():return _fail("review_cart_changed_during_quote")
	_quote=offered.duplicate(true);_quote_context=context;phase="review"
	var request_id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	_review_page(0,_generation,request_id)
	return {"ok":true,"quote_id":offered.quote_id,"review_pages":entries.size(),"confirmation_required":true,"confirm_called":false}

func _review_page(index: int, generation: int, request_id: String) -> void:
	if not _review_live(generation):return
	var owner: Object=_live()
	if _has_modal(owner):_invalidate();_present();return
	if index>=_quote.entries.size():
		var total: int=0
		for intent: Dictionary in _quote.entries:total+=int(intent.quantity)
		var body: String="%s · 검토한 %d개 항목 / 수량 합계 %d\n원자 저장 1회 · 현재 검토 목록만 이동\n취소/닫기는 이동하지 않습니다." % [_direction_label(direction),_quote.entries.size(),total]
		var dialog: Control=owner.hud.confirm_action("검토 목록 이동 확인",body,"검토 목록 이동",func(_amount: int) -> void:_confirm(generation,request_id))
		_watch_dialog(dialog,generation)
		return
	var intent: Dictionary=_quote.entries[index].duplicate(true)
	# One full source/physical identity per existing confirmation page avoids
	# truncating an unknown-length mixed cart into a representative summary.
	var body: String="%s · %d / %d\n%s ×%d\n원문 ID: %s\n실물 ID: %s\n이 항목은 아직 이동하지 않았습니다." % [_direction_label(direction),index+1,_quote.entries.size(),intent.item_name,intent.quantity,intent.source_id,intent.instance_id if not intent.instance_id.is_empty() else "비물리 묶음"]
	var dialog: Control=owner.hud.confirm_action("창고 검토 목록",body,"다음",func(_amount: int) -> void:_review_page(index+1,generation,request_id))
	# This existing cancellation control explicitly removes this reviewed row.
	# Escape/closing merely invalidates review and retains the cart.
	dialog.cancel_button.text="이 항목 빼기"
	dialog.cancel_button.pressed.connect(func() -> void:remove_reviewed(intent),CONNECT_ONE_SHOT)
	_watch_dialog(dialog,generation)

func _watch_dialog(dialog: Control, generation: int) -> void:
	_dialog=weakref(dialog)
	dialog.tree_exited.connect(_dialog_closed.bind(_dialog,generation),CONNECT_ONE_SHOT)

func _dialog_closed(reference: WeakRef, generation: int) -> void:
	if _dialog!=reference:return
	_dialog=null
	if phase=="review" and generation==_generation:_invalidate();_present()

func _confirm(generation: int, request_id: String) -> Dictionary:
	if not _review_live(generation):return _fail("review_cart_confirmation_invalidated")
	var owner: Object=_live()
	var quote_id: String=_quote.quote_id
	var reviewed: Array=_quote.entries.duplicate(true)
	phase="confirming" # Re-entry/duplicate callback cannot call World twice.
	# A close triggered during the owner call must retain this exact request,
	# not the previous receipt. It is still unknown until World returns.
	last_result={"ok":false,"code":"confirmation_in_progress","saved":null,"ui_confirmed_success":false,"ui_request":{"quote_id":quote_id,"request_id":request_id,"reviewed_entries":reviewed.duplicate(true),"direction":direction}}
	var result: Variant=owner.world.call("confirm_warehouse_batch",quote_id,request_id)
	if not result is Dictionary:
		result={"ok":false,"code":"save_outcome_uncertain","saved":null,"save_confirmed":false,"retry_allowed":false,"quote_id":quote_id,"request_id":request_id}
	last_result=result.duplicate(true)
	last_result["ui_request"]={"quote_id":quote_id,"request_id":request_id,"reviewed_entries":reviewed.duplicate(true),"direction":direction}
	last_result["ui_confirmed_success"]=false
	if result.get("ok",false) and result.get("saved")==true and result.get("save_confirmed")==true and result.get("live_adopted")==true and result.get("quote_id")==quote_id and result.get("request_id")==request_id and result.get("entries")==reviewed and result.get("direction")==direction and result.get("save_count")==1:
		last_result["ui_confirmed_success"]=true
		entries.clear();direction="";phase="idle";_invalidate();_present()
		_persist_closed_completion()
		return result
	var known_no_save: bool=result.get("ok")==false and result.get("saved")==false and result.get("save_attempted",false)==false
	if not known_no_save:
		phase="uncertain" # Keep entries, quote, request and receipt; never retry.
		last_result["ui_held_reviewed_entries"]=reviewed
	else:phase="idle";_invalidate()
	_present();_persist_closed_completion();return last_result.duplicate(true)

static func accept_successful_owner_load(world: Node, receipt: Dictionary) -> Dictionary:
	# Integration calls this only with its real accepted_load result, at the
	# successful load's final boundary. No save/confirm/quote is called here.
	if not is_instance_valid(world) or receipt.get("ok")!=true or receipt.get("owner_load_accepted")!=true or receipt.get("pending_intent_replayed")!=false or typeof(receipt.get("invalidated_quotes"))!=TYPE_INT or receipt.invalidated_quotes<0:return _fail("review_cart_actual_successful_load_receipt_required")
	var batch: Variant=world.get("_explicit_warehouse_batch")
	if not batch is RefCounted or not is_instance_valid(batch) or batch.get_script()==null or batch.get_script().resource_path!="res://scripts/warehouse/explicit_warehouse_batch.gd" or batch.get("busy")!=false or batch.get("uncertain")!=false:return _fail("review_cart_actual_restored_batch_owner_required")
	var held_value: Variant=world.get_meta("twilight_warehouse_held_ui_carts",[])
	if not held_value is Array:return _fail("review_cart_held_session_metadata_shape_required")
	var held: Array=held_value.duplicate(true)
	var updated: int=0
	for index: int in range(held.size()):
		var record: Variant=held[index]
		if not record is Dictionary or record.get("world_id")!=world.get_instance_id() or record.get("phase") not in ["confirming","uncertain"]:continue
		if not record.get("entries") is Array or not record.get("last_result") is Dictionary or not record.get("issued_quote") is Dictionary or not record.get("recovery_history",[]) is Array:return _fail("review_cart_closed_snapshot_shape_required")
		var history: Array=record.get("recovery_history",[]).duplicate(true)
		history.append({"result":record.get("last_result",{}).duplicate(true),"entries":record.get("entries",[]).duplicate(true),"issued_quote":record.get("issued_quote",{}).duplicate(true),"prior_phase":record.phase,"accepted_load":receipt.duplicate(true)})
		record["recovery_history"]=history
		record["phase"]="restored_pending_discard"
		record["issued_quote"]={}
		record["generation"]=int(record.get("generation",0))+1
		# Entries and last_result, including saved:null, are unchanged.
		held[index]=record;updated+=1
	world.set_meta("twilight_warehouse_held_ui_carts",held)
	var live_result: Dictionary={"ok":true,"active_cart_present":false}
	var hud: Variant=world.get("hud")
	var view: Variant=hud.get("transaction_view") if is_instance_valid(hud) else null
	if view is Control and is_instance_valid(view) and not view.is_queued_for_deletion() and view.get_script()!=null and view.get_script().resource_path==OWNER and view.get("world")==world:
		var cart: Variant=view.get("reviewed_batch")
		if cart is RefCounted and is_instance_valid(cart) and cart.get_script()!=null and cart.get_script().resource_path=="res://scripts/ui/warehouse_reviewed_cart.gd":
			live_result=cart.accepted_owner_load(world,receipt)
	return {"ok":true,"closed_session_snapshots_prepared":updated,"live_cart_result":live_result,"old_requests_resubmitted":false,"old_saved_null_reinterpreted":false,"explicit_discard_still_required":true,"game_state_written":false}

func _persist_closed_completion() -> void:
	if _live()!=null:return
	var world: Object=_world.get_ref() if _world!=null else null
	var request: String=str(last_result.get("ui_request",{}).get("request_id",""))
	if not is_instance_valid(world) or request.is_empty():return
	var value: Variant=world.get_meta("twilight_warehouse_held_ui_carts",[])
	if not value is Array:return
	var held: Array=value.duplicate(true)
	for index: int in range(held.size()):
		var previous: Variant=held[index]
		if not previous is Dictionary:continue
		if previous.get("world_id")!=world.get_instance_id() or previous.get("last_result",{}).get("ui_request",{}).get("request_id")!=request:continue
		var completed: Dictionary=snapshot()
		completed["completion_prior_snapshot"]=previous.duplicate(true)
		held[index]=completed
	world.set_meta("twilight_warehouse_held_ui_carts",held)

func accepted_owner_load(world: Node, receipt: Dictionary) -> Dictionary:
	var owner: Object=_live()
	if owner==null or world!=_world.get_ref() or owner.world!=world or receipt.get("ok")!=true or receipt.get("owner_load_accepted")!=true or receipt.get("pending_intent_replayed")!=false or typeof(receipt.get("invalidated_quotes"))!=TYPE_INT or receipt.invalidated_quotes<0:return _fail("review_cart_successful_actual_owner_load_receipt_required")
	var batch: Variant=world.get("_explicit_warehouse_batch")
	if not batch is RefCounted or not is_instance_valid(batch) or batch.get_script()==null or batch.get_script().resource_path!="res://scripts/warehouse/explicit_warehouse_batch.gd" or batch.get("busy")!=false or batch.get("uncertain")!=false:return _fail("review_cart_restored_owner_still_held")
	if phase=="uncertain":
		recovery_history.append({"result":last_result.duplicate(true),"entries":entries.duplicate(true),"issued_quote":_quote.duplicate(true),"accepted_load":receipt.duplicate(true)})
		phase="restored_pending_discard"
	else:_invalidate()
	_quote.clear();_quote_context.clear();_generation+=1
	_present()
	return {"ok":true,"old_requests_resubmitted":false,"old_saved_null_reinterpreted":false,"explicit_discard_required":phase=="restored_pending_discard"}

func discard_after_restored_load(ticket: String="") -> Dictionary:
	if phase!="restored_pending_discard" or ticket.is_empty() or ticket!=_discard_token or _discard_generation!=_generation or _live()==null:return _fail("review_cart_accepted_load_and_explicit_discard_required")
	_discard_token="";_discard_generation=-1
	# Caller invokes this only after explicit player approval; recovery_history
	# and last_result preserve old outcome evidence independently of the cart.
	var world: Object=_world.get_ref() if _world!=null else null
	if not is_instance_valid(world):return _fail("review_cart_actual_restored_world_required")
	var resolved: Dictionary=world.get_meta("twilight_warehouse_ui_recovery_discarded",{}).duplicate(true)
	resolved[str(last_result.get("ui_request",{}).get("request_id",""))]={"session_intents_discarded":true,"saved_outcome_changed":false}
	world.set_meta("twilight_warehouse_ui_recovery_discarded",resolved)
	entries.clear();direction="";phase="idle";_invalidate();_present()
	return {"ok":true,"session_intents_discarded":true,"old_requests_resubmitted":false,"saved_outcome_changed":false}

func request_discard_after_restored_load() -> Dictionary:
	var owner: Object=_live()
	if owner==null or phase!="restored_pending_discard" or _has_modal(owner):return _fail("review_cart_explicit_recovery_discard_unavailable")
	_discard_token=Crypto.new().generate_random_bytes(16).hex_encode();_discard_generation=_generation
	var ticket: String=_discard_token
	owner.hud.confirm_action("이전 창고 검토 카트", "정상 불러오기가 수락됐습니다.\n이전 저장 결과는 미확정 그대로 보존됩니다.\n이전 검토 목록만 비우며 이동·환불·재실행하지 않습니다.","검토 카트 비우기",func(_amount: int) -> void:discard_after_restored_load(ticket))
	return {"ok":true,"explicit_discard_confirmation_opened":true,"transaction_requested":false}

func _review_live(generation: int) -> bool:
	if phase!="review" or _quote.is_empty() or generation!=_generation or _quote_context!=_context():
		if phase=="review":_invalidate();_present()
		return false
	for intent: Dictionary in entries:
		if not _validate_intent(intent,direction).get("ok",false):_invalidate();_present();return false
	return true

func _selected(explicit_quantity: int=-1) -> Dictionary:
	var owner: Object=_live()
	if owner==null or _has_modal(owner):return _fail("review_cart_live_unobscured_owner_required")
	var index: Variant=owner.selected_index
	if typeof(index)!=TYPE_INT or index<0 or index>=owner.entries.size() or index>=owner.listing.item_count or owner.listing.get_selected_items()!=PackedInt32Array([index]) or owner.mode.selected not in [0,1]:return _fail("review_cart_actual_selected_row_required")
	var row: Dictionary=owner.entries[index]
	var count: float=float(explicit_quantity) if explicit_quantity>=0 else owner.quantity.value
	if not is_finite(count) or count!=floor(count) or count<1 or count>99 or count<owner.quantity.min_value or count>owner.quantity.max_value or count>int(row.get("count",0)):return _fail("review_cart_exact_quantity_required")
	var record: Variant=row.get("record")
	if not record is Dictionary or not record.get("sourceId") is String or record.sourceId.is_empty() or not row.get("instance_id") is String:return _fail("review_cart_exact_original_row_identity_required")
	var intent: Dictionary={"item_name":row.name,"source_id":record.sourceId,"instance_id":row.instance_id,"quantity":int(count),"record":record.duplicate(true)}
	var actual_direction: String="deposit" if owner.mode.selected==0 else "withdraw"
	var checked: Dictionary=_validate_intent(intent,actual_direction)
	if not checked.get("ok",false):return checked
	return {"ok":true,"index":index,"direction":actual_direction,"intent":intent}

func _validate_intent(intent: Dictionary, actual_direction: String) -> Dictionary:
	var owner: Object=_live()
	if owner==null or actual_direction not in ["deposit","withdraw"]:return _fail("review_cart_live_direction_required")
	if not intent.get("item_name") is String or not intent.get("source_id") is String or intent.source_id.is_empty() or not intent.get("instance_id") is String or not intent.get("record") is Dictionary or typeof(intent.get("quantity"))!=TYPE_INT or intent.quantity<1 or intent.quantity>99:return _fail("review_cart_exact_intent_required")
	var catalog: Dictionary=owner.world.call("_find_catalog_item_record",intent.item_name)
	if catalog!=intent.record or catalog.get("sourceId")!=intent.source_id:return _fail("review_cart_catalog_or_source_changed")
	var physical: Dictionary=owner.world.item_instances if actual_direction=="deposit" else owner.world.warehouse.instances
	var counts: Dictionary=owner.world.inventory if actual_direction=="deposit" else owner.world.warehouse.stacks
	if typeof(counts.get(intent.item_name))!=TYPE_INT or int(counts[intent.item_name])<intent.quantity:return _fail("review_cart_current_owned_quantity_changed")
	if not intent.instance_id.is_empty():
		var instance: Variant=physical.get(intent.instance_id)
		if not instance is Dictionary or instance.get("name")!=intent.item_name or instance.get("record")!=intent.record:return _fail("review_cart_current_physical_source_changed")
	return {"ok":true}

func _context() -> Dictionary:
	var owner: Object=_live()
	if owner==null:return {}
	return {"owner":owner.get_instance_id(),"world":owner.world.get_instance_id(),"mode":owner.mode.selected,"selection":owner.selected_index,"quantity":owner.quantity.value,"rows":owner.entries.duplicate(true),"entries":entries.duplicate(true),"direction":direction}

func _live() -> Object:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	var world: Object=_world.get_ref() if _world!=null else null
	if not is_instance_valid(owner) or not is_instance_valid(world) or owner.world!=world or owner.is_queued_for_deletion() or not owner.is_inside_tree() or not owner.is_visible_in_tree():return null
	if not is_instance_valid(owner.hud) or owner.hud.get("active_section")!="warehouse":return null
	var active: Variant=owner.hud.get("transaction_view")
	if is_instance_valid(active) and active!=owner:return null
	if owner.get_script()==null or owner.get_script().resource_path!=OWNER:return null
	for field: String in _controls:
		var control: Object=_controls[field].get_ref()
		if not is_instance_valid(control) or owner.get(field)!=control or control.is_queued_for_deletion() or not owner.is_ancestor_of(control):return null
	return owner

static func _has_modal(owner: Object) -> bool:
	var root: Node=owner.hud.get_node_or_null("Root")
	if root!=null:
		for child: Node in root.get_children():
			if child.name=="TwilightConfirmation" and not child.is_queued_for_deletion():return true
	return false

func _invalidate() -> void:
	if phase in ["confirming","uncertain","restored_pending_discard"]:return
	_generation+=1;_quote.clear();_quote_context.clear();phase="idle"
	var dialog: Object=_dialog.get_ref() if _dialog!=null else null
	_dialog=null
	if is_instance_valid(dialog) and not dialog.is_queued_for_deletion():dialog.dismiss()

func _refusal(result: Variant) -> Dictionary:
	last_result=result.duplicate(true) if result is Dictionary else _fail("review_cart_quote_invalid_response")
	_present();return last_result.duplicate(true)

func _present() -> void:
	var owner: Object=_live()
	if owner==null or not is_instance_valid(owner.summary):return
	var lines: PackedStringArray=["TWILIGHT 검토 카트 · 더블클릭/Enter 또는 선택 행 더블탭: 담기·같은 수량 빼기", "기존 보관/찾기 버튼은 단일 이동 유지 · 원본 모두 버튼은 아래 목록만 처리"]
	for intent: Dictionary in entries:lines.append("%s · %s ×%d · %s · %s" % [_direction_label(direction),intent.item_name,intent.quantity,intent.source_id,intent.instance_id if not intent.instance_id.is_empty() else "비물리 묶음"])
	if entries.is_empty():lines.append("검토 카트 비어 있음 · 자동 담기 없음")
	if not owner.world.has_method("quote_warehouse_batch") or not owner.world.has_method("confirm_warehouse_batch"):lines.append("원자 배치 수신자 코드 미통합 · 검토만 가능")
	if phase=="uncertain":lines.append("저장 결과 미확정 · 카트/영수증 보존 · 재시도 금지 · 정상 불러오기 필요")
	elif phase=="restored_pending_discard":lines.append("정상 불러오기 수락 · 과거 결과는 미확정 유지 · 명시적 카트 비우기 필요")
	elif not last_result.get("ok",true):lines.append(str(last_result.get("reason",last_result.get("code","검토 필요"))))
	owner.summary.text="\n".join(lines)

func close() -> void:
	_touch.clear()
	if phase in ["confirming","uncertain","restored_pending_discard"]:
		var world: Object=_world.get_ref() if _world!=null else null
		if is_instance_valid(world):
			var held: Array=world.get_meta("twilight_warehouse_held_ui_carts",[])
			var record: Dictionary=snapshot()
			if not held.has(record):held.append(record)
			world.set_meta("twilight_warehouse_held_ui_carts",held)
	else:_invalidate()

func _visibility_changed() -> void:
	if _live()==null:close()
	else:_present()

static func _key(intent: Dictionary) -> String:
	return "physical:"+str(intent.instance_id) if not str(intent.instance_id).is_empty() else "source:"+str(intent.source_id)

static func _direction_label(value: String) -> String:
	return "맡기기" if value=="deposit" else "찾기"

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"saved":false,"transaction_requested":false}
