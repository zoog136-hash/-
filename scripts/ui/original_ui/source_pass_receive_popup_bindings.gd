extends RefCounted
## The received CSB has empty callback names. Its labels alone do not
## establish a service contract: the presenter must declare both operations.
const MEMBER="UI/Pass/Pass_Popup_Receive_All.csb"
const SHA256="102c3a6b766c3ba3682d7c02fac9b5dbf77d9a75c7b31e852ff3c9402339003a"
const CANCEL=2004
const CONFIRM=1260
var _session: WeakRef
var _dismiss: Callable
var _active: bool=false
var _token: String=""

func build(pack: RefCounted, session: RefCounted, remaining: Dictionary, declared_operations: Dictionary, dismiss_popup: Callable) -> Dictionary:
	if _active:return {"ok":false,"code":"source_pass_popup_already_bound"}
	if pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return {"ok":false,"code":"source_pass_popup_identity_mismatch"}
	var model: Dictionary=session.snapshot()
	if model.get("section")!="events" or model.get("focus",{}).get("kind")!="pass":return {"ok":false,"code":"source_pass_popup_model_mismatch"}
	# This declaration is supplied by the caller that presents the pending
	# confirmation. Never infer it from a reward label or automatically begin.
	if declared_operations.size()!=2 or declared_operations.get(CANCEL)!="cancel" or declared_operations.get(CONFIRM)!="confirm":
		return {"ok":false,"code":"source_pass_popup_operation_contract_required","required_operations":{CANCEL:"cancel",CONFIRM:"confirm"},"complete_screen_contract":false}
	if not dismiss_popup.is_valid():return {"ok":false,"code":"source_pass_popup_dismiss_callback_required"}
	# Capture the pending service confirmation, not the session's future
	# current token. A replaced popup cannot confirm/cancel the next action.
	if not session.has_method("pending_plan") or not session.has_method("confirm_pending") or not session.has_method("cancel_pending"):return {"ok":false,"code":"source_pass_popup_pending_abi_required"}
	var pending: Dictionary=session.pending_plan()
	_token=str(pending.get("token",""))
	_session=weakref(session)
	_dismiss=dismiss_popup
	_active=true
	var bindings: Dictionary=remaining.duplicate(true)
	# These source ProjectNodes have empty fileName; preserve their slots.
	for offset: int in [456,220]:
		if not bindings.has(offset):bindings[offset]={"role":"project","bindings":{}}
	bindings[CANCEL]={"role":"button","activate":Callable(self,"cancel")}
	bindings[CONFIRM]={"role":"button","activate":Callable(self,"confirm")}
	# A hidden source popup may be configured before begin(). Its existing
	# caller binds the pending token when it actually presents this popup;
	# configuring its buttons never starts an action or makes it visible.
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"bindings":bindings,"pending_bound":not _token.is_empty(),"complete_screen_contract":false}

func bind_pending() -> Dictionary:
	var session: Object=_session.get_ref() if _active and _session!=null else null
	_token=""
	if session==null:return {"ok":false,"code":"source_pass_popup_inactive"}
	var pending: Dictionary=session.pending_plan()
	_token=str(pending.get("token",""))
	if _token.is_empty():return {"ok":false,"code":"source_pass_popup_pending_confirmation_required"}
	return {"ok":true,"plan":pending,"transaction_performed":false}

func cancel() -> Dictionary:
	return _operate("cancel")

func confirm() -> Dictionary:
	return _operate("confirm")

func invalidate() -> void:
	# Presenter must invalidate when replacing this popup or its pending
	# confirmation. Teardown itself never closes/cancels another session.
	_active=false
	_session=null
	_dismiss=Callable()
	_token=""

func _operate(method: String) -> Dictionary:
	var session: Object=_session.get_ref() if _active and _session!=null else null
	if session==null:return {"ok":false,"code":"source_pass_popup_inactive"}
	if _token.is_empty():return {"ok":false,"code":"source_pass_popup_pending_confirmation_required"}
	var operated_token: String=_token
	var result: Dictionary=session.call(method+"_pending",operated_token)
	# action_result listeners may replace this popup during the synchronous
	# service call. Do not dismiss/invalidate that newer presentation.
	if not _active or _token!=operated_token:return result
	if result.get("code")=="source_confirmation_not_current":_token=""
	elif result.get("ok",false):
		var dismiss: Callable=_dismiss
		_token=""
		if dismiss.is_valid():dismiss.call()
	return result
