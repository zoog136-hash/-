extends RefCounted
## UI callbacks for the existing PR264 source_ui_service ABI. No transactions,
## reward choices, costs, save state or RNG are implemented here.
signal action_result(result: Dictionary)
signal closed
var _service: WeakRef
var _model: Dictionary={}
var _token: String=""
var _pending_plan: Dictionary={}
var _active: bool=false

func bind_prepared(service: Object, model: Dictionary) -> Dictionary:
	if _active:return {"ok":false,"code":"source_session_already_bound"}
	if not is_instance_valid(service):return {"ok":false,"code":"source_service_unavailable"}
	for method: String in ["snapshot","begin","choose","confirm","cancel","close"]:
		if not service.has_method(method):return {"ok":false,"code":"source_service_abi_missing","method":method}
	_service=weakref(service)
	_model=model.duplicate(true)
	_active=true
	return {"ok":true}

func snapshot() -> Dictionary:
	return _model.duplicate(true) if _active else {}

func action_callback(row_id: String, action_ref: String) -> Callable:
	# Bind only the opaque reference supplied for this exact original row.
	var matches: int=0
	for row: Dictionary in _model.get("content",{}).get("rows",[]):
		if str(row.get("id",""))!=row_id:continue
		for action: Dictionary in row.get("action_refs",[]):
			if str(action.get("action_ref",""))==action_ref:matches+=1
	return Callable(self,"begin").bind(action_ref) if _active and matches==1 else Callable()

func action_binding(row_id: String, action_ref: String) -> Dictionary:
	var found: Array[Dictionary]=[]
	for row: Dictionary in _model.get("content",{}).get("rows",[]):
		if str(row.get("id",""))!=row_id:continue
		for action: Dictionary in row.get("action_refs",[]):
			if str(action.get("action_ref",""))==action_ref:found.append(action)
	if not _active or found.size()!=1:return {"ok":false,"code":"source_action_not_in_model"}
	var data: Dictionary=found[0].get("data",{})
	# These are the service's supplied availability fields, not UI-owned
	# eligibility, dummy classification, price or progress calculations.
	var unavailable: bool=bool(data.get("disabled",false)) or data.has("choice_error")
	return {"ok":true,"binding":{"role":"button","displaystate":not unavailable,"activate":Callable() if unavailable else Callable(self,"begin").bind(action_ref)},"data":data.duplicate(true)}

func begin(action_ref: String) -> Dictionary:
	var service: Object=_live_service()
	if service==null:return _unavailable()
	# begin() owns invalidation of an earlier confirmation and all freshness
	# checks. The UI does not construct a request from labels or numeric IDs.
	_token=""
	_pending_plan.clear()
	var result: Dictionary=service.call("begin",action_ref)
	if bool(result.get("ok",false)):
		_token=str(result.get("token",""))
		_pending_plan=result.duplicate(true)
	action_result.emit(result.duplicate(true))
	return result

func pending_plan() -> Dictionary:
	# Original popup/choice callers capture this opaque service token. An old
	# popup must never operate on a newer begin() merely because it is visible.
	return _pending_plan.duplicate(true) if _active and not _token.is_empty() else {}

func choose(key: String, option_indices: Array) -> Dictionary:
	return choose_pending(_token,key,option_indices)

func choose_pending(token: String, key: String, option_indices: Array) -> Dictionary:
	var service: Object=_live_service()
	if service==null:return _unavailable()
	if token.is_empty() or token!=_token:return {"ok":false,"code":"source_confirmation_not_current"}
	var result: Dictionary=service.call("choose",token,key,option_indices.duplicate())
	if bool(result.get("ok",false)):_pending_plan=result.duplicate(true)
	action_result.emit(result.duplicate(true))
	return result

func confirm() -> Dictionary:
	return confirm_pending(_token)

func confirm_pending(token: String) -> Dictionary:
	var service: Object=_live_service()
	if service==null:return _unavailable()
	if token.is_empty() or token!=_token:return {"ok":false,"code":"source_confirmation_not_current"}
	# The service consumes its token before runtime.execute's single save.
	# Return failures verbatim; no UI retry, reward or substitute result.
	# For a ready service plan, clear the local copy before the synchronous
	# call too. Save failure does not make a consumed confirmation reusable.
	# Unresolved choices remain the service's responsibility and retain their
	# token so its existing choice_required response can be handled.
	if bool(_pending_plan.get("ready",false)):
		_token=""
		_pending_plan.clear()
	var result: Dictionary=service.call("confirm",token)
	action_result.emit(result.duplicate(true))
	return result

func cancel() -> Dictionary:
	return cancel_pending(_token)

func cancel_pending(token: String) -> Dictionary:
	var service: Object=_live_service()
	if service==null:return _unavailable()
	if token.is_empty() or token!=_token:return {"ok":false,"code":"source_confirmation_not_current"}
	_token=""
	_pending_plan.clear()
	var result: Dictionary=service.call("cancel",token)
	action_result.emit(result.duplicate(true))
	return result

func close() -> Dictionary:
	var service: Object=_live_service()
	invalidate()
	if service!=null:service.call("close")
	closed.emit()
	return {"ok":true,"closed":true} if service!=null else _unavailable()

func abandon() -> void:
	# Teardown may follow a replacement presenter. Cancel only this exact
	# pending token; never close a newer model owned by another presentation.
	var service: Object=_live_service()
	var token: String=_token
	invalidate()
	if service!=null and not token.is_empty():service.call("cancel",token)

func invalidate() -> void:
	# Replacing a displayed scene must not close the newer model that the
	# runtime has already prepared before calling the presentation adapter.
	_active=false
	_token=""
	_pending_plan.clear()
	_model.clear()
	_service=null

func _live_service() -> Object:
	return _service.get_ref() if _active and _service!=null else null

static func _unavailable() -> Dictionary:
	return {"ok":false,"code":"source_session_closed"}
