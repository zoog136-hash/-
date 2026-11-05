extends RefCounted
## Nonvisual caller for the original UI owner. No widgets, scene construction,
## template loader, pixels or substitute screen live in this service.
const Data = preload("res://scripts/unconfirmed523/source_ui_data.gd")
var _runtime_ref: WeakRef
var runtime: Variant:
	get:
		return _runtime_ref.get_ref() if _runtime_ref != null else null
var _page: Dictionary = {}
var _actions: Dictionary = {}
var _pending: Dictionary = {}
var _sequence: int = 0
var _nonce: String = Crypto.new().generate_random_bytes(12).hex_encode()

func configure(host) -> void:
	if runtime != host: close()
	_runtime_ref = weakref(host) if host != null else null

func close() -> void:
	_page.clear()
	_actions.clear()
	_pending.clear()

func open_section(section: String, focus: Dictionary = {}) -> Dictionary:
	close()
	if not _valid_host(): return _fail("host_unavailable")
	if not runtime.DOMAIN_PATHS.has(section): return _fail("unknown_domain")
	var content: Dictionary = runtime.page(section).duplicate(true)
	var context: Dictionary = runtime.context()
	var progress: Dictionary = runtime.state.get("domains",{}).get(section,{}).duplicate(true)
	# UI owns no random stream and receives existing progress, not a save copy.
	progress.erase("rng_state")
	progress.erase("rng")
	if section == "challenge": context["active_challenge_id"] = progress.get("active",{}).get("challenge_id",0)
	var rows: Array = []
	for original: Dictionary in content.get("rows",[]):
		var row: Dictionary = original.duplicate(true)
		if not _matches_focus(row,focus,context): continue
		row["source_ui"] = Data.project(runtime.source,section,row,context)
		var action_refs: Array = []
		for action: Dictionary in row.get("actions",[]):
			_sequence += 1
			var ref: String = "%s:%d" % [_nonce,_sequence]
			_actions[ref] = {"row_id":str(row.get("id","")),"action":action.duplicate(true)}
			action_refs.append({"action_ref":ref,"data":action.duplicate(true)})
		row["action_refs"] = action_refs
		rows.append(row)
	content.rows = rows
	_page = {"schema":1,"section":section,"focus":focus.duplicate(true),"revision":int(runtime.state.revision),"fingerprint":runtime.fingerprint(),"content":content,"progress":progress,"progress_basis":"existing_domain_save_state","balances":context.get("currencies",{}).duplicate(true),"owned":context.get("owned",{}).duplicate(true)}
	return {"ok":true,"model":_page.duplicate(true)}

func snapshot() -> Dictionary:
	if not _valid_host(): close()
	return _page.duplicate(true)

func request_menu(button_id: int) -> Dictionary:
	if not _valid_host(): return _fail("host_unavailable")
	var route: Dictionary = Data.menu_route(runtime.source,button_id)
	if not route.get("ok",false): return route
	return runtime.request_presentation(str(route.domain),{"kind":str(route.focus),"native_route":route})

func request_category(key: String) -> Dictionary:
	if not _valid_host(): return _fail("host_unavailable")
	var route: Dictionary = Data.category_route(runtime.source,key)
	if not route.get("ok",false): return route
	return runtime.request_presentation(str(route.domain),{"kind":str(route.focus),"native_route":route})

func begin(action_ref: String) -> Dictionary:
	_pending.clear()
	if not _fresh(): return _fail("display_changed")
	if not _actions.has(action_ref): return _fail("unknown_action")
	var captured: Dictionary = _actions[action_ref]
	var action: Dictionary = captured.action
	if action.get("disabled",false) or action.has("choice_error"): return _fail("action_unavailable")
	if not action.get("request") is Dictionary: return _fail("action_request_missing")
	if not _still_offered(captured): return _fail("action_no_longer_offered")
	_sequence += 1
	_pending = {"token":"%s:%d" % [_nonce,_sequence],"captured":captured.duplicate(true),"request":action.request.duplicate(true)}
	return _plan()

func choose(token: String, key: String, option_indices: Array) -> Dictionary:
	if _pending.is_empty() or token != str(_pending.token): return _fail("unknown_confirmation")
	if not _fresh(): _pending.clear(); return _fail("display_changed")
	var planned: Dictionary = _plan()
	if not planned.get("ok",false): return planned
	var requirement: Dictionary = {}
	for candidate: Dictionary in planned.choices:
		if str(candidate.get("key","")) == key:
			if not requirement.is_empty(): return _fail("ambiguous_choice_key")
			requirement = candidate
	if requirement.is_empty(): return _fail("unknown_choice")
	var minimum: int = int(requirement.get("min_count",requirement.get("count",1)))
	var maximum: int = int(requirement.get("max_count",requirement.get("count",1)))
	if minimum < 0 or maximum < minimum or option_indices.size() < minimum or option_indices.size() > maximum: return _fail("choice_count")
	var options: Array = requirement.get("options",[])
	var seen: Dictionary = {}
	var values: Array = []
	for index: Variant in option_indices:
		if not _integer(index) or int(index) < 0 or int(index) >= options.size() or seen.has(int(index)): return _fail("choice_index")
		seen[int(index)] = true
		var option: Variant = options[int(index)]
		if not option is Dictionary or not option.has("value"): return _fail("choice_value_missing")
		values.append(option.value)
	var request: Dictionary = _pending.request.duplicate(true)
	if key.begins_with("selection."):
		if not request.has("selection"): request.selection = {}
		if not request.selection is Dictionary: return _fail("choice_shape")
		request.selection[key.trim_prefix("selection.")] = values
	elif key == "instance_id" or requirement.get("value_shape") == "scalar":
		if values.size() != 1 or not values[0] is String or str(values[0]).is_empty(): return _fail("choice_scalar")
		request[key] = values[0]
	else:
		request[key] = values
	var before: Dictionary = _pending.request
	_pending.request = request
	var next: Dictionary = _plan()
	if not next.get("ok",false): _pending.request = before
	return next

func cancel(token: String) -> Dictionary:
	if _pending.is_empty() or token != str(_pending.token): return _fail("unknown_confirmation")
	_pending.clear()
	return {"ok":true,"cancelled":true}

func confirm(token: String) -> Dictionary:
	if _pending.is_empty() or token != str(_pending.token): return _fail("unknown_confirmation")
	if not _fresh(): _pending.clear(); return _fail("display_changed")
	var planned: Dictionary = _plan()
	if not planned.get("ok",false): return planned
	if not planned.choices.is_empty(): return _fail("choice_required")
	var held: Dictionary = _pending.duplicate(true)
	_pending.clear() # Consume the UI token before the synchronous save boundary.
	if not _still_offered(held.captured): return _fail("action_no_longer_offered")
	return runtime.execute(str(_page.section),held.request,int(_page.revision),str(_page.fingerprint))

func _plan() -> Dictionary:
	if _pending.is_empty(): return _fail("unknown_confirmation")
	var action: Dictionary = _pending.captured.action
	var result: Dictionary = {"ok":true,"choices":action.get("required_choices",[]).duplicate(true),"deferred_random":[]}
	var domain: Variant = runtime.domains.get(str(_page.section))
	if domain != null and domain.has_method("presentation_choices"):
		result = domain.presentation_choices(action,runtime.context(),_pending.request.get("selection",{}))
	if not result.get("ok",false): return result
	var unresolved: Array = []
	for requirement: Dictionary in result.get("choices",[]):
		var key: String = str(requirement.get("key",""))
		if key.is_empty(): return _fail("choice_key_missing")
		var exists: bool = _pending.request.get("selection",{}).has(key.trim_prefix("selection.")) if key.begins_with("selection.") else _pending.request.has(key)
		if not exists: unresolved.append(requirement.duplicate(true))
	return {"ok":true,"token":str(_pending.token),"section":str(_page.section),"row_id":str(_pending.captured.row_id),"action":action.duplicate(true),"request":_pending.request.duplicate(true),"choices":unresolved,"deferred_random":result.get("deferred_random",[]).duplicate(true),"ready":unresolved.is_empty()}

func _fresh() -> bool:
	return _valid_host() and not _page.is_empty() and not runtime.busy and int(runtime.state.revision) == int(_page.revision) and runtime.fingerprint() == str(_page.fingerprint)

func _valid_host() -> bool:
	return runtime != null and is_instance_valid(runtime.world)

func _still_offered(captured: Dictionary) -> bool:
	var content: Dictionary = runtime.page(str(_page.section))
	var matches: int = 0
	for row: Dictionary in content.get("rows",[]):
		if str(row.get("id","")) != str(captured.row_id): continue
		for action: Dictionary in row.get("actions",[]):
			if _same(action,captured.action) and not action.get("disabled",false): matches += 1
	return matches == 1

static func _matches_focus(row: Dictionary, focus: Dictionary, context: Dictionary) -> bool:
	var id: String = str(row.get("id",""))
	match str(focus.get("kind","")):
		"attendance":
			if not id.begins_with("attendance:"): return false
		"pass":
			if not id.begins_with("pass:") and not id.begins_with("pass-quest:"): return false
	if focus.has("item_id"):
		var item_id: int = int(focus.item_id)
		if id in ["container:%d" % item_id,"jade:%d" % item_id]: return true
		if id.begins_with("grail:"):
			return int(context.get("instances",{}).get(id.trim_prefix("grail:"),{}).get("sourceID",0)) == item_id
		return false
	return true

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == float(int(value))

static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a,"",true,true) == JSON.stringify(b,"",true,true)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"error":code}
