extends RefCounted
## Own bounded map accounting. Source reset/recharge/account semantics are not inferred.
const WRITER=preload("res://scripts/skills/save_writer.gd")
const SERVER=preload("res://scripts/cards/source_collection_conditions.gd")
const CONDITIONS=preload("res://scripts/crafting/patch523_craft_conditions.gd")
const PATH="user://current523_map_time_v1.json"
const LOCK_PATH=PATH+".lock"
const REGISTRATION_PATH=PATH+".registered"
const PIN="2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
const POLICY="OWN_BOUNDED_SOURCE_LIMIT_NO_AUTO_RESET_V1"
const SCOPE_POLICY="OWN_SERVICE_REGION_WORLD_SHARED_LOCAL_CHARACTERS_V1"
const RECOVERY_POLICY="OWN_UNCLOSED_LEASE_OFFLINE_DEBIT_UNTIL_RECOVERY_OR_FIRST_EXHAUSTION_V1"
const MAX_FILE_BYTES=2*1024*1024
const MAX_SCOPES=128
const MAX_SCOPE_GROUPS=256
const MAX_TOTAL_GROUPS=4096
const MAX_REQUEST_GROUPS=64
const MAX_SAFE_INTEGER=9007199254740991
const MAX_CLOCK_MS=4102444800000
var problem: String=""
var last_result: Dictionary={}
var _pid: int=0
var _world_id: int=0
var _token: String=""
var _owned_active: bool=false
var _busy: bool=false
var _mutex_token: String=""
var _observed_clock_ms: int=0
var _seen: Dictionary={}
var _seen_signature: String=""

func configure(world: Node) -> bool:
	if not is_instance_valid(world):problem="map_time_world_unavailable";return false
	var identity: int=world.get_instance_id()
	if _owned_active and identity!=_world_id:problem="map_time_other_world_lease_active";return false
	_world_id=identity;_pid=OS.get_process_id()
	if _token.is_empty():_token=Crypto.new().generate_random_bytes(32).hex_encode()
	problem=""
	return true

func active() -> bool:
	return _owned_active

func quote(groups: Array, profile: Dictionary) -> Dictionary:
	if _world_id==0:return _remember(_result(false,"map_time_world_unavailable"))
	var request: Dictionary=_request(groups,profile)
	if not request.ok:return _remember(request)
	var clock: Dictionary=_clock()
	if not clock.ok:return _remember(clock)
	var loaded: Dictionary=_read_state(int(clock.now_ms))
	if not loaded.ok:return _remember(loaded)
	var projected: Dictionary=_project(loaded.state,int(clock.now_ms))
	if not projected.ok:return _remember(projected)
	if projected.owned and projected.charge.expired:
		return _remember(_result(false,"map_time_active_lease_expired",{"expired":true,"remaining_ms":0,"previous_lease_expired":true}))
	var ensured: Dictionary=_ensure_groups(projected.state,request,true)
	if not ensured.ok:return _remember(ensured)
	var view: Dictionary=_view(projected.state,request)
	view["orphan_recovery_projected"]=projected.orphan
	view["previous_lease_expired"]=projected.charge.expired
	view["prepared"]=not bool(ensured.added) and not bool(loaded.fresh)
	if not request.groups.is_empty() and int(view.remaining_ms)<=0:
		view["expired"]=true;return _remember(_result(false,"map_time_budget_exhausted",view))
	return _remember(_result(true,"",view))

func prepare(groups: Array, profile: Dictionary) -> Dictionary:
	return _change("prepare",0,groups,profile)

func switch_session(land_id: int, groups: Array, profile: Dictionary) -> Dictionary:
	return _change("end" if groups.is_empty() else "switch",land_id,groups,profile)

func pulse() -> bool:
	if not _owned_active:return true
	return bool(_change("pulse",0,[],{}).ok)

func end_session() -> Dictionary:
	return _change("end",0,[],{})

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and CONDITIONS.integer(value,minimum,maximum)

func _result(ok: bool, reason: String="", extra: Dictionary={}) -> Dictionary:
	var result: Dictionary={"ok":ok,"reason":reason,"policy":POLICY,"scope_policy":SCOPE_POLICY,"orphan_recovery_policy":RECOVERY_POLICY,"definition_manifest_sha256":PIN,"remaining_ms":-1,"group_remaining_ms":{},"remaining_by_group":{},"active":_owned_active,"prepared":false,"committed":false,"expired":false,"save_error":OK}
	result.merge(extra,true)
	return result

func _remember(result: Dictionary) -> Dictionary:
	last_result=result.duplicate(true)
	problem=str(result.get("reason",""))
	return result

func _clock() -> Dictionary:
	var seconds: float=Time.get_unix_time_from_system()
	if not is_finite(seconds) or seconds<0 or seconds>float(MAX_CLOCK_MS)/1000.0:return _result(false,"map_time_clock_invalid")
	var now_ms: int=floori(seconds*1000.0)
	if not _integer(now_ms,0,MAX_CLOCK_MS) or now_ms<_observed_clock_ms:return _result(false,"map_time_clock_rollback")
	_observed_clock_ms=now_ms
	return {"ok":true,"now_ms":now_ms}

static func _scope_key(region: String, world_no: int) -> String:
	# Snapshot labels and character identities cannot create a fresh budget.
	return JSON.stringify([region,world_no],"",true,true).sha256_text()

static func _source_group(value: Variant) -> Dictionary:
	if not value is Dictionary or value.is_empty() or value.size()>32:return {}
	var row: Dictionary={}
	for key: Variant in value:
		if not key is String or key.is_empty() or key.length()>128 or key.to_utf8_buffer().has(0) or not _integer(value[key],-2147483648,2147483647):return {}
		row[key]=int(value[key])
	for key: String in ["ID","DescID","ContentsResetScheduleTypeID","TimeLimit","MaxRechargeTime","StartDateTimeID","EndDateTimeID","ServiceTypeID"]:
		if not row.has(key):return {}
	if row.ID<1 or row.ServiceTypeID!=13 or row.TimeLimit<1:return {}
	var text: String=JSON.stringify(row,"",true,true)
	if text.to_utf8_buffer().size()>4096:return {}
	return {"id":int(row.ID),"source_group":row,"source_group_sha256":text.sha256_text(),"initial_ms":int(row.TimeLimit)*1000}

func _request(groups: Array, profile: Dictionary) -> Dictionary:
	if groups.size()>MAX_REQUEST_GROUPS:return _result(false,"map_time_too_many_groups")
	if groups.is_empty():return {"ok":true,"groups":[],"profile":{},"scope_key":""}
	if not SERVER.valid_context(profile) or not _integer(profile.get("WorldNo"),1,2147483647):return _result(false,"map_time_server_context_required")
	var region: String=profile.ServiceRegionCode
	if region.length()>64 or region.to_utf8_buffer().has(0):return _result(false,"map_time_server_context_required")
	var selected: Dictionary={"source_snapshot":profile.source_snapshot,"ServiceRegionCode":region,"WorldNo":int(profile.WorldNo)}
	var by_id: Dictionary={}
	for value: Variant in groups:
		var group: Dictionary=_source_group(value)
		if group.is_empty():return _result(false,"map_time_source_group_invalid_or_service_type_unsupported")
		var key: String=str(group.id)
		if by_id.has(key) and by_id[key].source_group_sha256!=group.source_group_sha256:return _result(false,"map_time_source_group_conflict")
		by_id[key]=group
	var ids: Array=by_id.keys();ids.sort()
	var ordered: Array=[]
	for id: String in ids:ordered.append(by_id[id])
	return {"ok":true,"groups":ordered,"profile":selected,"scope_key":_scope_key(region,int(selected.WorldNo))}

static func _fresh(now_ms: int) -> Dictionary:
	return {"schema":1,"policy":POLICY,"scope_policy":SCOPE_POLICY,"definition_manifest_sha256":PIN,"revision":0,"clock_highwater_ms":now_ms,"scopes":{},"lease":{}}

func _document_problem(state: Variant) -> String:
	if not state is Dictionary or state.get("schema")!=1 or state.get("policy")!=POLICY or state.get("scope_policy")!=SCOPE_POLICY:return "map_time_state_invalid"
	if state.get("definition_manifest_sha256")!=PIN:return "map_time_definition_identity_mismatch"
	if not _integer(state.get("revision"),0,MAX_SAFE_INTEGER-1) or not _integer(state.get("clock_highwater_ms"),0,MAX_CLOCK_MS) or not state.get("scopes") is Dictionary or state.scopes.size()>MAX_SCOPES or not state.get("lease") is Dictionary:return "map_time_state_invalid"
	var total: int=0
	for key: Variant in state.scopes:
		var scope: Variant=state.scopes[key]
		if not key is String or not scope is Dictionary or not scope.get("ServiceRegionCode") is String or scope.ServiceRegionCode.is_empty() or scope.ServiceRegionCode.length()>64 or scope.ServiceRegionCode.to_utf8_buffer().has(0) or not _integer(scope.get("WorldNo"),1,2147483647):return "map_time_scope_invalid"
		if key!=_scope_key(scope.ServiceRegionCode,int(scope.WorldNo)) or not scope.get("groups") is Dictionary or scope.groups.size()>MAX_SCOPE_GROUPS:return "map_time_scope_invalid"
		total+=scope.groups.size()
		if total>MAX_TOTAL_GROUPS:return "map_time_state_too_large"
		for group_key: Variant in scope.groups:
			var stored: Variant=scope.groups[group_key]
			if not group_key is String or not stored is Dictionary:return "map_time_group_invalid"
			var source: Dictionary=_source_group(stored.get("source_group"))
			if source.is_empty() or group_key!=str(source.id) or stored.get("source_group_sha256")!=source.source_group_sha256 or stored.get("initial_ms")!=source.initial_ms or not _integer(stored.get("remaining_ms"),0,int(source.initial_ms)):return "map_time_group_definition_or_budget_invalid"
	var lease: Dictionary=state.lease
	if lease.is_empty():return ""
	if not _integer(lease.get("owner_pid"),1,2147483647) or not _integer(lease.get("world_instance_id"),1,MAX_SAFE_INTEGER) or not lease.get("owner_token") is String or lease.owner_token.length()!=64 or not lease.owner_token.is_valid_hex_number(false):return "map_time_lease_invalid"
	if not lease.get("scope_key") is String or not state.scopes.has(lease.scope_key) or not _integer(lease.get("land_id"),0,2147483647) or not _integer(lease.get("started_at_ms"),0,int(state.clock_highwater_ms)) or not _integer(lease.get("charged_through_ms"),int(lease.started_at_ms),int(state.clock_highwater_ms)):return "map_time_lease_invalid"
	if not lease.get("server_profile") is Dictionary or not SERVER.valid_context(lease.server_profile) or not _integer(lease.server_profile.get("WorldNo"),1,2147483647) or lease.scope_key!=_scope_key(lease.server_profile.ServiceRegionCode,int(lease.server_profile.WorldNo)):return "map_time_lease_invalid"
	if not lease.get("group_ids") is Array or lease.group_ids.is_empty() or lease.group_ids.size()>MAX_REQUEST_GROUPS:return "map_time_lease_invalid"
	var seen: Dictionary={}
	for id: Variant in lease.group_ids:
		if not _integer(id,1,2147483647) or seen.has(str(int(id))) or not state.scopes[lease.scope_key].groups.has(str(int(id))):return "map_time_lease_invalid"
		seen[str(int(id))]=true
	return ""

func _rollback_problem(state: Dictionary, signature: String) -> String:
	if _seen.is_empty():return ""
	if state.revision<_seen.revision or state.clock_highwater_ms<_seen.clock_highwater_ms:return "map_time_state_rollback"
	if state.revision==_seen.revision and signature!=_seen_signature:return "map_time_state_changed_without_revision"
	for scope_key: String in _seen.scopes:
		if not state.scopes.has(scope_key):return "map_time_registered_budget_missing"
		for id: String in _seen.scopes[scope_key].groups:
			var old: Dictionary=_seen.scopes[scope_key].groups[id]
			var current: Dictionary=state.scopes[scope_key].groups.get(id,{})
			if current.is_empty() or current.source_group_sha256!=old.source_group_sha256 or current.initial_ms!=old.initial_ms or current.remaining_ms>old.remaining_ms:return "map_time_registered_budget_rollback"
	return ""

func _observe(state: Dictionary, signature: String) -> void:
	_seen=state.duplicate(true);_seen_signature=signature
	_observed_clock_ms=maxi(_observed_clock_ms,int(state.clock_highwater_ms))

func _read_state(now_ms: int) -> Dictionary:
	if not FileAccess.file_exists(PATH):
		if DirAccess.dir_exists_absolute(REGISTRATION_PATH) or not _seen.is_empty():return _result(false,"map_time_registered_state_missing")
		return {"ok":true,"state":_fresh(now_ms),"fresh":true}
	var file:=FileAccess.open(PATH,FileAccess.READ)
	if file==null:return _result(false,"map_time_state_read_failed",{"save_error":FileAccess.get_open_error()})
	if file.get_length()<2 or file.get_length()>MAX_FILE_BYTES:file.close();return _result(false,"map_time_state_size_invalid")
	var text: String=file.get_as_text();file.close()
	var parser:=JSON.new()
	if parser.parse(text)!=OK:return _result(false,"map_time_state_corrupt")
	var state: Variant=parser.data
	var reason: String=_document_problem(state)
	if not reason.is_empty():return _result(false,reason)
	if now_ms<int(state.clock_highwater_ms):return _result(false,"map_time_clock_rollback")
	var signature: String=text.sha256_text()
	reason=_head_problem(state,signature)
	if not reason.is_empty():return _result(false,reason)
	reason=_rollback_problem(state,signature)
	if not reason.is_empty():return _result(false,reason)
	_observe(state,signature)
	return {"ok":true,"state":state,"fresh":false}

func _head_problem(state: Dictionary, signature: String) -> String:
	var file:=FileAccess.open(REGISTRATION_PATH.path_join("head.json"),FileAccess.READ)
	if file==null:return "map_time_registration_head_missing"
	if file.get_length()<2 or file.get_length()>4096:file.close();return "map_time_registration_head_invalid"
	var head: Variant=JSON.parse_string(file.get_as_text());file.close()
	if not head is Dictionary or head.get("schema")!=1 or head.get("policy")!=POLICY or head.get("definition_manifest_sha256")!=PIN:return "map_time_registration_head_invalid"
	if head.get("revision")!=state.revision or head.get("clock_highwater_ms")!=state.clock_highwater_ms or head.get("state_sha256")!=signature:return "map_time_registration_head_mismatch_or_rollback"
	return ""

func _owns(lease: Dictionary) -> bool:
	return not lease.is_empty() and lease.owner_pid==_pid and lease.owner_token==_token and lease.world_instance_id==_world_id

static func _charge(state: Dictionary, now_ms: int) -> Dictionary:
	var lease: Dictionary=state.lease
	var groups: Dictionary=state.scopes[lease.scope_key].groups
	var remaining: int=MAX_SAFE_INTEGER
	for id: Variant in lease.group_ids:remaining=mini(remaining,int(groups[str(int(id))].remaining_ms))
	var elapsed: int=now_ms-int(lease.charged_through_ms)
	var charged: int=mini(elapsed,remaining)
	for id: Variant in lease.group_ids:groups[str(int(id))].remaining_ms=int(groups[str(int(id))].remaining_ms)-charged
	var expired: bool=elapsed>=remaining
	if expired:state.lease={}
	else:state.lease.charged_through_ms=now_ms
	return {"elapsed_ms":elapsed,"charged_ms":charged,"expired":expired}

func _project(state: Dictionary, now_ms: int) -> Dictionary:
	var next: Dictionary=state.duplicate(true)
	var lease: Dictionary=next.lease
	var own: bool=_owns(lease)
	if _owned_active and not own:return _result(false,"map_time_owned_lease_missing_or_changed")
	if lease.is_empty():return {"ok":true,"state":next,"owned":false,"orphan":false,"charge":{"expired":false,"charged_ms":0,"elapsed_ms":0}}
	if not own and OS.is_process_running(int(lease.owner_pid)):return _result(false,"map_time_other_live_process_or_world_lease")
	var charge: Dictionary=_charge(next,now_ms)
	if not own:next.lease={}
	return {"ok":true,"state":next,"owned":own,"orphan":not own,"charge":charge}

func _ensure_groups(state: Dictionary, request: Dictionary, allow_new: bool) -> Dictionary:
	if request.groups.is_empty():return {"ok":true,"added":false}
	var added: bool=false
	if not state.scopes.has(request.scope_key):
		if not allow_new:return _result(false,"map_time_groups_not_prepared")
		if state.scopes.size()>=MAX_SCOPES:return _result(false,"map_time_scope_limit")
		state.scopes[request.scope_key]={"ServiceRegionCode":request.profile.ServiceRegionCode,"WorldNo":request.profile.WorldNo,"groups":{}}
	var stored: Dictionary=state.scopes[request.scope_key].groups
	var total: int=0
	for scope: Dictionary in state.scopes.values():total+=scope.groups.size()
	for group: Dictionary in request.groups:
		var key: String=str(group.id)
		if stored.has(key):
			if stored[key].source_group_sha256!=group.source_group_sha256 or stored[key].source_group!=group.source_group or stored[key].initial_ms!=group.initial_ms:return _result(false,"map_time_source_group_definition_mismatch")
			continue
		if not allow_new:return _result(false,"map_time_groups_not_prepared")
		if stored.size()>=MAX_SCOPE_GROUPS or total>=MAX_TOTAL_GROUPS:return _result(false,"map_time_group_limit")
		stored[key]={"source_group":group.source_group.duplicate(true),"source_group_sha256":group.source_group_sha256,"initial_ms":group.initial_ms,"remaining_ms":group.initial_ms}
		added=true;total+=1
	return {"ok":true,"added":added}

func _view(state: Dictionary, request: Dictionary) -> Dictionary:
	var balances: Dictionary={}
	var remaining: int=-1
	var source_groups: Array=[]
	for group: Dictionary in request.groups:
		var balance: int=int(state.scopes[request.scope_key].groups[str(group.id)].remaining_ms)
		balances[str(group.id)]=balance
		remaining=balance if remaining<0 else mini(remaining,balance)
		source_groups.append(group.source_group.duplicate(true))
	return {"remaining_ms":remaining,"group_remaining_ms":balances,"remaining_by_group":balances.duplicate(true),"source_groups":source_groups,"scope_key":request.scope_key,"server_profile":request.profile.duplicate(true),"no_requested_time_group":request.groups.is_empty()}

func _change(kind: String, land_id: int, groups: Array, profile: Dictionary) -> Dictionary:
	if _world_id==0:return _remember(_result(false,"map_time_world_unavailable"))
	if _busy:return _remember(_result(false,"map_time_operation_busy"))
	var request: Dictionary=_request(groups,profile)
	if not request.ok:return _remember(request)
	if kind=="switch" and not _integer(land_id,0,2147483647):return _remember(_result(false,"map_time_land_invalid"))
	_busy=true
	var locked: Dictionary=_acquire_mutex()
	if not locked.ok:_busy=false;return _remember(locked)
	var clock: Dictionary=_clock()
	if not clock.ok:return _finish(clock)
	var now_ms: int=int(clock.now_ms)
	var loaded: Dictionary=_read_state(now_ms)
	if not loaded.ok:return _finish(loaded)
	var projected: Dictionary=_project(loaded.state,now_ms)
	if not projected.ok:return _finish(projected)
	var next: Dictionary=projected.state
	if kind in ["prepare","switch"] and projected.owned and projected.charge.expired:return _finish(_result(false,"map_time_active_lease_expired",{"expired":true,"remaining_ms":0}))
	if kind in ["prepare","switch"]:
		var ensured: Dictionary=_ensure_groups(next,request,kind=="prepare")
		if not ensured.ok:return _finish(ensured)
		var target: Dictionary=_view(next,request)
		if not request.groups.is_empty() and int(target.remaining_ms)<=0:
			target["expired"]=true;return _finish(_result(false,"map_time_budget_exhausted",target))
	if kind=="switch":
		var ids: Array=[]
		for group: Dictionary in request.groups:ids.append(int(group.id))
		next.lease={"owner_pid":_pid,"owner_token":_token,"world_instance_id":_world_id,"scope_key":request.scope_key,"land_id":land_id,"group_ids":ids,"server_profile":request.profile.duplicate(true),"started_at_ms":now_ms,"charged_through_ms":now_ms}
	elif kind=="end":next.lease={}
	if loaded.fresh and request.groups.is_empty() and loaded.state.lease.is_empty():return _finish(_result(true,"",_view(next,request)))
	if kind=="end" and loaded.state.lease.is_empty():return _finish(_result(true,"",_view(next,request)))
	if not _integer(next.revision,0,MAX_SAFE_INTEGER-2):return _finish(_result(false,"map_time_revision_exhausted"))
	next.revision=int(next.revision)+1;next.clock_highwater_ms=now_ms
	var reason: String=_document_problem(next)
	if not reason.is_empty():return _finish(_result(false,reason))
	var text: String=JSON.stringify(next,"",true,true)
	if text.to_utf8_buffer().size()>MAX_FILE_BYTES:return _finish(_result(false,"map_time_state_too_large"))
	if not DirAccess.dir_exists_absolute(REGISTRATION_PATH):
		var registration_error: Error=DirAccess.make_dir_absolute(REGISTRATION_PATH)
		if registration_error!=OK:return _finish(_result(false,"map_time_registration_failed",{"save_error":registration_error}))
	# Advance the head first: an interrupted replacement holds rather than refunds.
	var signature: String=text.sha256_text()
	var error: Error=WRITER.write(REGISTRATION_PATH.path_join("head.json"),{"schema":1,"policy":POLICY,"definition_manifest_sha256":PIN,"revision":next.revision,"clock_highwater_ms":now_ms,"state_sha256":signature})
	if error!=OK:return _finish(_result(false,"map_time_registration_head_save_failed",{"save_error":error}))
	error=WRITER.write_text(PATH,text)
	if error!=OK:return _finish(_result(false,"map_time_save_failed",{"save_error":error}))
	_observe(next,signature)
	_owned_active=_owns(next.lease)
	var view: Dictionary=_view(next,request)
	view.merge({"active":_owned_active,"prepared":kind=="prepare","committed":true,"recovered_orphan":projected.orphan,"previous_lease_expired":projected.charge.expired,"charged_ms":projected.charge.charged_ms},true)
	if kind=="pulse" and projected.charge.expired:
		view["expired"]=true;view["remaining_ms"]=0;return _finish(_result(false,"map_time_active_lease_expired",view))
	return _finish(_result(true,"",view))

func _mutex_owner() -> Dictionary:
	var file:=FileAccess.open(LOCK_PATH.path_join("owner.json"),FileAccess.READ)
	if file==null:return {}
	if file.get_length()<2 or file.get_length()>4096:file.close();return {}
	var value: Variant=JSON.parse_string(file.get_as_text());file.close()
	if not value is Dictionary or not _integer(value.get("pid"),1,2147483647) or not _integer(value.get("world_id"),1,MAX_SAFE_INTEGER) or not value.get("token") is String or value.token.length()!=64 or not value.token.is_valid_hex_number(false):return {}
	return value

func _reclaim_dead_mutex(owner: Dictionary) -> Error:
	# A guard serializes stale-lock reclamation. An interrupted guard stays held.
	var guard: String=LOCK_PATH.path_join("reclaim")
	var error: Error=DirAccess.make_dir_absolute(guard)
	if error!=OK:return error
	var token: String=Crypto.new().generate_random_bytes(32).hex_encode()
	error=WRITER.write(guard.path_join("owner.json"),{"pid":_pid,"token":token,"world_id":_world_id})
	if error!=OK:return error
	var current: Dictionary=_mutex_owner()
	if current!=owner or current.is_empty() or OS.is_process_running(int(current.pid)):
		DirAccess.remove_absolute(guard.path_join("owner.json"));DirAccess.remove_absolute(guard)
		return ERR_BUSY
	for path: String in [LOCK_PATH.path_join("owner.json.tmp"),LOCK_PATH.path_join("owner.json"),guard.path_join("owner.json.tmp"),guard.path_join("owner.json")]:
		if FileAccess.file_exists(path):
			error=DirAccess.remove_absolute(path)
			if error!=OK:return error
	error=DirAccess.remove_absolute(guard)
	return DirAccess.remove_absolute(LOCK_PATH) if error==OK else error

func _acquire_mutex() -> Dictionary:
	if not _mutex_token.is_empty():
		var cleanup: Error=_release_mutex()
		if cleanup!=OK:return _result(false,"map_time_mutex_cleanup_required",{"save_error":cleanup})
	var error: Error=DirAccess.make_dir_absolute(LOCK_PATH)
	if error!=OK:
		if not DirAccess.dir_exists_absolute(LOCK_PATH):return _result(false,"map_time_mutex_create_failed",{"save_error":error})
		var owner: Dictionary=_mutex_owner()
		if owner.is_empty():return _result(false,"map_time_mutex_owner_unconfirmed")
		if OS.is_process_running(int(owner.pid)):return _result(false,"map_time_mutex_held_by_live_process")
		error=_reclaim_dead_mutex(owner)
		if error!=OK:return _result(false,"map_time_stale_mutex_reclaim_held",{"save_error":error})
		error=DirAccess.make_dir_absolute(LOCK_PATH)
		if error!=OK:return _result(false,"map_time_mutex_busy",{"save_error":error})
	_mutex_token=Crypto.new().generate_random_bytes(32).hex_encode()
	error=WRITER.write(LOCK_PATH.path_join("owner.json"),{"pid":_pid,"token":_mutex_token,"owner_token":_token,"world_id":_world_id})
	if error!=OK:
		_release_mutex();return _result(false,"map_time_mutex_owner_save_failed",{"save_error":error})
	return {"ok":true}

func _release_mutex() -> Error:
	if _mutex_token.is_empty():return OK
	if not DirAccess.dir_exists_absolute(LOCK_PATH):_mutex_token="";return OK
	var owner_path: String=LOCK_PATH.path_join("owner.json")
	if FileAccess.file_exists(owner_path):
		var owner: Dictionary=_mutex_owner()
		if owner.is_empty() or owner.pid!=_pid or owner.token!=_mutex_token or owner.world_id!=_world_id:return ERR_BUSY
	for path: String in [owner_path+".tmp",owner_path]:
		if FileAccess.file_exists(path):
			var remove_error: Error=DirAccess.remove_absolute(path)
			if remove_error!=OK:return remove_error
	var directory_error: Error=DirAccess.remove_absolute(LOCK_PATH)
	if directory_error==OK:_mutex_token=""
	return directory_error

func _finish(result: Dictionary) -> Dictionary:
	var error: Error=_release_mutex()
	_busy=false
	# A completed ledger replacement remains completed if mutex cleanup fails.
	if error!=OK:result["mutex_release_error"]=error
	return _remember(result)
