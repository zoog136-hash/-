extends RefCounted
## Own source-field/session lifecycle; host progress and transactions stay owned by Main.
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const STATIC_SPR=preload("res://scripts/maps/current523_static_spr.gd")
const POPULATION_TRANSACTION=preload("res://scripts/maps/current523_population_transaction.gd")
var _population_commit_in_progress: bool=false
var _source_population_owner: RefCounted
var _held_population_transactions: Array=[]
var _held_source_transitions: Array[Dictionary]=[]
const TRAVEL_PAYMENT=preload("res://scripts/maps/current523_map_travel_payment.gd")
const STAGED_ENCOUNTERS=preload("res://scripts/maps/current523_staged_encounters.gd")
var active: bool = false
var problem: String = ""
var settings: Dictionary = {}
var _world_ref: WeakRef
var _prior: FieldRenderer
var _prior_visible: bool = false
var _prior_mode: int = Node.PROCESS_MODE_INHERIT
var _renderer: FieldRenderer
var _notice: CanvasLayer
var source_owned: bool = false
var saving_prior_snapshot: bool = false
var _source_field: OriginalPlayableField
var _source_physics: StaticBody2D
var _prior_world: Dictionary = {}
var _paused_nodes: Array[Dictionary] = []
var _portals: RefCounted
# PR230 owns definition verification and tables. This optional bridge consumes
# copied contexts from that module; it is not a second definition catalog.
const DEFINITION_PACK_SHA256="2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
const SOURCE_TRAVEL=preload("res://scripts/maps/current523_source_travel.gd")
const ACTOR_CONTEXT=preload("res://scripts/maps/current523_map_runtime_context.gd")
const MAP_TIME=preload("res://scripts/maps/current523_map_time_pool.gd")
var _map_time: RefCounted
var _map_time_timer: Timer
var _active_entry_context: Dictionary={}
var _session_condition_identity: Dictionary={}
var _last_map_time: Dictionary={}
var _last_source_transition: Dictionary={}
# Exact held M Locations166; universal return selection is the user's own policy.
const ADEN_RETURN_LOCATION={"ID":166,"LandID":4,"X":33923,"Y":33350}
const ADEN_RETURN_POLICY="OWN_ADEN_LOCATION166_CLEAR_RING_V1"
var _source_portal_provider: RefCounted
var _source_travel_busy: bool=false
var _portal_definition_generation: int=0
const GENERIC_CATALOG=preload("res://scripts/maps/current523_source_pack.gd")
const GENERIC_TILES=preload("res://scripts/maps/current523_tile_pack.gd")
var _cached_catalog: RefCounted
var _cached_tiles: RefCounted
var _catalog_loads: int=0
var _tile_metadata_loads: int=0

func _catalog_for(options: Dictionary) -> RefCounted:
	if _cached_catalog!=null and _cached_catalog.matches_manifest(options.raw_root,options.source_manifest_sha256): return _cached_catalog
	var candidate:=GENERIC_CATALOG.new()
	if not candidate.load_catalog(options.raw_root,options.source_manifest_sha256): problem=candidate.problem; return null
	_cached_catalog=candidate; _catalog_loads+=1
	return candidate

func _tiles_for(options: Dictionary) -> RefCounted:
	if _cached_tiles!=null and _cached_tiles.matches_manifest(options.tile_root,options.tile_manifest_sha256): return _cached_tiles
	var candidate:=GENERIC_TILES.new()
	if not candidate.load_pack(options.tile_root,options.tile_manifest_sha256): problem=candidate.problem; return null
	_cached_tiles=candidate; _tile_metadata_loads+=1
	return candidate

func input_cache_metrics() -> Dictionary:
	return {"source_catalog_loads":_catalog_loads,"tile_catalog_loads":_tile_metadata_loads,"tile_cache_size":_cached_tiles.cache_size() if _cached_tiles!=null else 0}

func configure(world: Node) -> void:
	_world_ref = weakref(world)
	_map_time=MAP_TIME.new()
	_map_time.configure(world)

func _world() -> Node:
	return _world_ref.get_ref() as Node if _world_ref != null else null

func _actor_state(world: Node, options: Dictionary={}) -> Dictionary:
	var result: Dictionary=ACTOR_CONTEXT.capture(world)
	result["map_open_policy"]=options.get("map_open_policy",settings.get("map_open_policy",OPTIONS.OWN_ALWAYS_OPEN_V1))
	return result

func _condition_identity(state: Dictionary) -> Dictionary:
	var result: Dictionary=ACTOR_CONTEXT.identity(state)
	result["map_open_policy"]=state.get("map_open_policy",OPTIONS.OWN_ALWAYS_OPEN_V1)
	return result

static func _always_open(state: Dictionary) -> bool:
	return state.get("map_open_policy",OPTIONS.OWN_ALWAYS_OPEN_V1)==OPTIONS.OWN_ALWAYS_OPEN_V1

func _always_open_quote() -> Dictionary:
	return {"ok":true,"policy":OPTIONS.OWN_ALWAYS_OPEN_V1,"remaining_ms":-1,"group_remaining_ms":{},"remaining_by_group":{},"unlimited":true,"time_conditions_waived":true,"lease_settlement_required":_map_time!=null and _map_time.active()}

func _time_groups(context: Dictionary, only_land: int=-1) -> Dictionary:
	if context.get("map_open_policy")==OPTIONS.OWN_ALWAYS_OPEN_V1:return {"ok":true,"groups":[]}
	var conditions: Variant=context.get("land_time_conditions")
	if not conditions is Array:return {"ok":false,"reason":"map_time_definition_context_missing"}
	var by_id: Dictionary={}
	for condition: Variant in conditions:
		if not condition is Dictionary or not condition.get("row") is Dictionary or not condition.get("calendar") is Dictionary:
			return {"ok":false,"reason":"map_time_definition_context_invalid"}
		if only_land>=0 and condition.get("land_id")!=only_land:continue
		var row: Dictionary=condition.row
		var group: Variant=condition.calendar.get("group")
		if not group is Dictionary or not SOURCE_TRAVEL._uint(group.get("ID"),2147483647) or group.ID<1 or row.get("LandTimeLimitGroupID")!=group.ID or row.get("LandID")!=condition.get("land_id"):
			return {"ok":false,"reason":"map_time_group_reference_invalid"}
		var key: String=str(int(group.ID))
		if by_id.has(key) and by_id[key]!=group:return {"ok":false,"reason":"map_time_group_definition_conflict"}
		by_id[key]=group.duplicate(true)
	return {"ok":true,"groups":by_id.values()}

func _with_map_time_quote(context: Dictionary, actor_state: Dictionary, policy: String="") -> Dictionary:
	var result: Dictionary=context.duplicate(true)
	result["map_open_policy"]=actor_state.get("map_open_policy",OPTIONS.OWN_ALWAYS_OPEN_V1)
	var groups: Dictionary=_time_groups(result)
	var quote: Dictionary={"ok":false,"reason":groups.get("reason","map_time_owner_unavailable")}
	var chosen_policy: String=policy if not policy.is_empty() else str(settings.get("map_time_policy",OPTIONS.OWN_MAP_TIME))
	if _always_open(actor_state):quote=_always_open_quote()
	elif groups.get("ok",false) and _map_time!=null:
		if not groups.groups.is_empty() and chosen_policy!=OPTIONS.OWN_MAP_TIME:quote={"ok":false,"reason":"own_map_time_policy_disabled","policy":chosen_policy}
		else:quote=_map_time.quote(groups.groups,actor_state.get("server_profile",{}))
	result["own_map_time"]=quote.duplicate(true)
	var holds: Array=[]
	if context.get("map_open_policy")!=result.map_open_policy:
		holds.append({"reason":"map_open_policy_context_mismatch"})
	for hold: Variant in result.get("source_travel_holds",[]):
		# Clear only the elapsed-time ownership hold. Dates, weekly conditions,
		# attributes, fees and native trigger semantics are separate contracts.
		if hold is Dictionary and hold.get("reason")=="native_land_time_pool_owner_required" and quote.get("ok",false):continue
		holds.append(hold)
	if not quote.get("ok",false):holds.append({"reason":"own_map_time_unavailable","detail":quote.duplicate(true)})
	result.source_travel_holds=holds
	result.source_travel_hold="native_definition_conditions_require_policy" if not holds.is_empty() else ""
	return result

func _entry_context(land_id: int, asset: String, source_cell: Vector2i, actor_state: Dictionary, time_policy: String="") -> Dictionary:
	if _source_portal_provider==null or not _source_portal_provider.has_method("land_entry_context_for_actor_state"):
		return {"source_travel_hold":"map_entry_definition_provider_required"}
	var raw: Variant=_source_portal_provider.call("land_entry_context_for_actor_state",land_id,asset,actor_state,source_cell)
	if not raw is Dictionary or raw.get("definition_manifest_sha256")!=DEFINITION_PACK_SHA256 or not raw.get("Land") is Dictionary or raw.Land.get("ID")!=land_id or raw.Land.get("AssetPath")!=asset or raw.get("source_cell")!=[source_cell.x,source_cell.y]:
		return {"source_travel_hold":"map_entry_definition_identity_invalid"}
	var result: Dictionary=_with_map_time_quote(raw,actor_state,time_policy)
	result["runtime_condition_identity"]=_condition_identity(actor_state)
	return result

func _prepare_map_session(context: Dictionary, actor_state: Dictionary) -> bool:
	if not str(context.get("source_travel_hold","map_entry_definition_missing")).is_empty():
		problem="원문 지역 조건 보류: "+str(context.get("source_travel_hold"));return false
	if _always_open(actor_state):
		if _map_time==null:problem="이전 맵 시간 세션의 종료 소비자가 없습니다.";return false
		# The transition settles the old lease after its checkpoint succeeds.
		_last_map_time=_always_open_quote();return true
	var groups: Dictionary=_time_groups(context)
	if not groups.get("ok",false) or _map_time==null:
		problem="맵 시간그룹 소비자가 없습니다.";return false
	_last_map_time=_map_time.prepare(groups.groups,actor_state.get("server_profile",{}))
	if not _last_map_time.get("ok",false):
		problem="맵 시간 등록 보류: "+str(_last_map_time.get("reason","unknown"));return false
	return true

func _switch_map_session(land_id: int, context: Dictionary, actor_state: Dictionary, previous_options: Dictionary) -> bool:
	var groups: Dictionary=_time_groups(context)
	if not groups.get("ok",false) or _map_time==null:
		problem="맵 시간 전환 입력을 사용할 수 없습니다."
		if OPTIONS.write(previous_options)!=OK:problem+=" · 이전 위치 설정 복원 실패"
		return false
	_last_map_time=_map_time.switch_session(land_id,groups.get("groups",[]),actor_state.get("server_profile",{}))
	if not _last_map_time.get("ok",false):
		problem="맵 시간 세션 전환 보류: "+str(_last_map_time.get("reason","unknown"))
		if OPTIONS.write(previous_options)!=OK:problem+=" · 이전 위치 설정 복원도 실패했습니다. 현재 필드는 보존합니다."
		return false
	_active_entry_context=context.duplicate(true)
	_session_condition_identity=_condition_identity(actor_state)
	return true

func _start_map_time_monitor(world: Node) -> void:
	if not is_instance_valid(_map_time_timer):
		_map_time_timer=Timer.new()
		_map_time_timer.name="Current523MapTimeMonitor"
		_map_time_timer.process_mode=Node.PROCESS_MODE_ALWAYS
		# Own monitoring cadence, not a native M tick or reset interval.
		_map_time_timer.wait_time=1.0
		_map_time_timer.timeout.connect(_map_time_tick)
		world.add_child(_map_time_timer)
	_map_time_timer.start()

func _map_time_tick() -> void:
	if not active or not source_owned or settings.get("navigation_profile")!=OPTIONS.GENERIC:return
	var world: Node=_world()
	if not is_instance_valid(world) or _source_travel_busy or saving_prior_snapshot:return
	var state: Dictionary=_actor_state(world)
	var identity: Dictionary=_condition_identity(state)
	var reason: String=""
	if identity.get("server_profile")!=_session_condition_identity.get("server_profile"):
		reason="서버 문맥이 바뀌어 원문 맵 세션을 종료합니다."
	elif identity!=_session_condition_identity:
		var cell: Vector2i=_source_field.world_to_cell(world.player.global_position)+_source_field.coordinates.origin
		var context: Dictionary=_entry_context(int(settings.native_land_id),str(_source_field.get("source_asset")),cell,state)
		if not str(context.get("source_travel_hold","missing")).is_empty():reason="현재 지역의 원문 조건이 변경되거나 미확인 상태입니다."
		else:_active_entry_context=context;_session_condition_identity=identity
	if not _always_open(state):
		for condition: Dictionary in _active_entry_context.get("land_time_conditions",[]):
			var calendar: Dictionary=condition.get("calendar",{})
			if calendar.get("status")=="open":
				var window: Dictionary=calendar.get("window",{})
				if not str(state.get("calendar_hold","missing")).is_empty() or state.now_unix<window.get("start_unix",0) or state.now_unix>=window.get("end_unix",0):reason="원문 지역의 기간이 종료되거나 달력 문맥을 사용할 수 없습니다."
	if _map_time!=null and _map_time.active():
		if _always_open(state):
			_last_map_time=_map_time.end_session()
			if not _last_map_time.get("ok",false):reason="이전 맵 시간 세션의 종료 정산을 저장할 수 없습니다."
		elif not _map_time.pulse():reason="맵 잔여시간이 만료되었거나 시간 저장을 계속할 수 없습니다."
	if not reason.is_empty():world.call("close_current523_aden_play",false,reason)

func open(value: Dictionary) -> bool:
	problem = ""
	if active: problem = "아덴 실험 플레이가 이미 실행 중입니다."; return false
	var world: Node = _world()
	if value.get("navigation_profile") in [OPTIONS.SOURCE,OPTIONS.GENERIC]: return _open_source(value)
	problem = OPTIONS.qualify(world)
	if not problem.is_empty(): return false
	if bool(world.get("current523_aden_review_active")): problem = "원문 검토를 닫은 뒤 실험 플레이를 시작해 주세요."; return false
	var options: Dictionary = OPTIONS.validate(value)
	if options.is_empty() or not options.enabled or options.navigation_profile != OPTIONS.LEGACY:
		problem = "기존 TWILIGHT 통행(자체 설정)을 선택해 주세요."; return false
	var prior: Variant = world.get("field_renderer")
	if not is_instance_valid(prior) or not prior is FieldRenderer:
		problem = "복귀할 기존 지도 표시가 없습니다."; return false
	var candidate = RENDERER.new()
	candidate.name = "Current523AdenPlayRenderer"
	candidate.process_mode = Node.PROCESS_MODE_DISABLED
	candidate.hide()
	world.add_child(candidate)
	if not candidate.try_configure(world.get("field_map"), world.get("player"), options.raw_root, options.tile_root, Vector2(options.offset_x, options.offset_y)):
		problem = candidate.problem
		candidate.queue_free()
		return false
	if OPTIONS.write(options) != OK:
		problem = "실험 플레이 설정을 저장하지 못했습니다. 기존 지도를 유지합니다."
		candidate.queue_free()
		return false
	_prior = prior
	_prior_visible = _prior.visible
	_prior_mode = _prior.process_mode
	_prior.hide()
	_prior.process_mode = Node.PROCESS_MODE_DISABLED
	_renderer = candidate
	world.set("field_renderer", candidate)
	settings = options
	active = true
	candidate.safe_return_requested.connect(_renderer_problem.bind(candidate))
	candidate.process_mode = Node.PROCESS_MODE_INHERIT
	candidate.show()
	_build_notice(world)
	return true

func close(remember_disabled: bool = true) -> bool:
	problem=""
	if source_owned: return _close_source(remember_disabled)
	var saved: bool = true
	if remember_disabled:
		var options: Dictionary = OPTIONS.read()
		options.enabled = false
		saved = OPTIONS.write(options) == OK
		if not saved:problem="자동 시작 해제 설정을 저장하지 못했습니다."
	var world: Node = _world()
	if is_instance_valid(world) and is_instance_valid(_prior): world.set("field_renderer", _prior)
	if is_instance_valid(_renderer):
		_renderer.hide()
		_renderer.process_mode = Node.PROCESS_MODE_DISABLED
		_renderer.queue_free()
	if is_instance_valid(_prior):
		_prior.visible = _prior_visible
		_prior.process_mode = _prior_mode
	if is_instance_valid(_notice): _notice.queue_free()
	_renderer = null; _prior = null; _notice = null
	active = false
	return saved

func apply_options(value: Dictionary) -> bool:
	problem = ""
	var options: Dictionary = OPTIONS.validate(value)
	if not active or options.is_empty() or not options.enabled or options.navigation_profile != settings.navigation_profile:
		problem = "실행 중인 자체 통행 설정이 아닙니다."; return false
	# Changing resource roots requires a new validated entry, not an in-place swap.
	if options.raw_root != settings.raw_root or options.tile_root != settings.tile_root:
		problem = "원본 팩을 바꾸려면 실험 플레이를 종료해 주세요."; return false
	if settings.navigation_profile==OPTIONS.GENERIC:
		for key: String in ["source_manifest_sha256","tile_manifest_sha256","native_land_id"]:
			if options.get(key)!=settings.get(key): problem="지역과 원본 검증 정보를 바꾸려면 원문 플레이를 종료해 주세요."; return false
	if source_owned and (options.allowed_raw_words != settings.allowed_raw_words or options.portal_contract != settings.portal_contract or options.get("path_search_limit",8192)!=settings.get("path_search_limit",8192) or options.get("aden_inferred_placement_enabled",true)!=settings.get("aden_inferred_placement_enabled",true)):
		problem = "통행 및 경로 설정과 포탈 팩을 바꾸려면 원문 플레이를 종료해 주세요."; return false
	if source_owned and options.map_time_policy!=settings.get("map_time_policy",OPTIONS.OWN_MAP_TIME):
		problem="맵 시간정책을 바꾸려면 원문 플레이를 종료해 주세요.";return false
	if source_owned and options.map_open_policy!=settings.get("map_open_policy",OPTIONS.OWN_ALWAYS_OPEN_V1):
		problem="맵 개방정책을 바꾸려면 원문 플레이를 종료해 주세요.";return false
	if source_owned: options.source_position = _source_checkpoint().source_position
	var previous_delta := Vector2(settings.offset_x, settings.offset_y)
	if not bool(_renderer.call("set_visual_delta", Vector2(options.offset_x, options.offset_y))):
		problem = str(_renderer.get("problem"))
		if problem.is_empty(): problem = "현재 영역에 표시 보정을 적용할 수 없습니다."
		return false
	if OPTIONS.write(options) != OK:
		_renderer.call("set_visual_delta", previous_delta)
		problem = "표시 보정을 저장하지 못했습니다. 이전 보정을 유지합니다."
		return false
	settings = options
	return true

func apply_static_spr_options(value: Dictionary) -> bool:
	problem=""
	var checked: Dictionary=STATIC_SPR.validate(value)
	if checked.is_empty():problem="정적 SPR 설정 형식이 올바르지 않습니다.";return false
	if _source_travel_busy or saving_prior_snapshot:
		problem="맵 이동 또는 저장이 끝난 뒤 SPR 설정을 적용해 주세요.";return false
	if not active:
		if STATIC_SPR.save_options(checked)!=OK:problem="SPR 설정을 저장하지 못했습니다.";return false
		return true
	var world: Node=_world()
	if not is_instance_valid(world) or not is_instance_valid(_renderer) or world.get("field_renderer")!=_renderer or not _renderer.has_method("prepare_static_spr_options") or not _renderer.has_method("commit_static_spr_options"):
		problem="현재 지도 표시 소비자가 바뀌어 SPR 설정을 적용하지 않았습니다.";return false
	_source_travel_busy=true
	var prepared: Dictionary=_renderer.call("prepare_static_spr_options",checked)
	if not prepared.get("ok",false):
		problem=str(prepared.get("problem","SPR 원문 소비자를 연결하지 못했습니다."))
		_source_travel_busy=false;return false
	if STATIC_SPR.save_options(checked)!=OK:
		if is_instance_valid(prepared.get("candidate")):prepared.candidate.free()
		problem="SPR 설정을 저장하지 못해 기존 표시를 유지합니다."
		_source_travel_busy=false;return false
	_renderer.call("commit_static_spr_options",prepared)
	_source_travel_busy=false
	return true

func metrics() -> Dictionary:
	var result: Dictionary=_renderer.call("frame_metrics") if active and is_instance_valid(_renderer) else {}
	result["own_map_time"]=_last_map_time.duplicate(true)
	result["own_map_time_active"]=_map_time!=null and _map_time.active()
	result["map_open_policy"]=settings.get("map_open_policy",OPTIONS.OWN_ALWAYS_OPEN_V1)
	if active and source_owned and settings.get("navigation_profile")==OPTIONS.GENERIC and _map_time!=null:
		if _always_open(settings):result.own_map_time=_always_open_quote()
		else:
			var groups: Dictionary=_time_groups(_active_entry_context)
			if groups.get("ok",false):result.own_map_time=_map_time.quote(groups.groups,_session_condition_identity.get("server_profile",{}))
	return result

func _renderer_problem(message: String, sender: FieldRenderer) -> void:
	_deferred_return.call_deferred(message, sender.get_instance_id())

func _deferred_return(message: String, sender_id: int) -> void:
	var world: Node = _world()
	if active and is_instance_valid(_renderer) and sender_id == _renderer.get_instance_id() and is_instance_valid(world): world.call("close_current523_aden_play", false, message)

func _build_notice(world: Node) -> void:
	_notice = CanvasLayer.new()
	_notice.name = "Current523AdenPlayNotice"
	_notice.layer = 18
	world.add_child(_notice)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 106)
	_notice.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var label: Label = UI.label("아덴 M 타일 실험 플레이\n통행: 기존 TWILIGHT 자체 설정 · M 좌표/발/충돌 미확정", 14, UI.TEXT)
	if source_owned: label.text = str(_source_field.data.map_name)+"\nS32 속성 기반 자체 통행 · M 원작 판정 미확정"
	if source_owned and _always_open(settings):label.text+="\n상시 오픈 자체정책 · 기간·요일·대기·시간 한도 미적용"
	elif source_owned and _map_time!=null and _map_time.active():label.text+="\nM 원문 한도 차감 · 자체 시간정책: 자동 초기화/충전 없음"
	row.add_child(label)
	var button: Button = UI.button("기존 지도로 복귀", _return_pressed, Vector2(150, 42))
	button.name = "ReturnFromAdenPlayButton"
	row.add_child(button)

func _return_pressed() -> void:
	var world: Node = _world()
	if is_instance_valid(world): world.call("close_current523_aden_play")

func _open_source(value: Dictionary) -> bool:
	var world: Node = _world()
	var options: Dictionary = OPTIONS.validate(value)
	if world == null or options.is_empty() or not options.enabled:
		problem = "원문 플레이 설정이 올바르지 않습니다."; return false
	if bool(world.get("current523_aden_review_active")) or str(world.get("active_map_id")) != "aden_world":
		problem = "아덴에서 원문 검토를 닫은 뒤 시작해 주세요."; return false
	var prior_field: Variant = world.get("field_map")
	var prior_renderer: Variant = world.get("field_renderer")
	if not prior_field is OriginalPlayableField or not is_instance_valid(prior_renderer) or not is_instance_valid(world.get("player")):
		problem = "복귀할 지도와 캐릭터를 확인하지 못했습니다."; return false
	var generic: bool=options.navigation_profile==OPTIONS.GENERIC
	var catalog: RefCounted=_catalog_for(options) if generic else null
	if generic and catalog==null: return false
	var script: Script = load("res://scripts/maps/current523_source_field.gd" if generic else "res://scripts/maps/current523_aden_source_field.gd")
	var proposed: OriginalPlayableField = script.new()
	var interpretation: Dictionary={"allowed_raw_words":options.allowed_raw_words,"path_search_limit":options.get("path_search_limit",8192),"aden_inferred_placement_enabled":options.get("aden_inferred_placement_enabled",true)}
	var configured: bool=proposed.call("configure_verified_catalog",catalog,options.source_manifest_sha256,options.native_land_id,interpretation) if generic else proposed.call("configure_current523",options.raw_root,interpretation)
	if not configured:
		problem = str(proposed.get("problem")); proposed.close(); return false
	var source_position: Array = options.source_position
	if generic and source_position.is_empty():
		problem="선택한 논리 Land의 원문 입장 좌표를 지정해 주세요. 다른 지도의 좌표를 재사용하지 않습니다."; proposed.close(); return false
	if source_position.is_empty(): source_position = prior_field.coordinates.source_components(world.player.global_position)
	var position: Vector2 = proposed.coordinates.components_to_world(source_position)
	if not proposed.point_clear(position,4):
		problem = "선택한 원문 위치는 자체 통행에서 거부됩니다. 원본 좌표를 임의로 바꾸지 않았습니다."; proposed.close(); return false
	var entry_context: Dictionary={}
	var actor_state: Dictionary={}
	if generic:
		actor_state=_actor_state(world,options)
		var entry_cell: Vector2i=proposed.world_to_cell(position)+proposed.coordinates.origin
		entry_context=_entry_context(int(options.native_land_id),str(proposed.get("source_asset")),entry_cell,actor_state,str(options.map_time_policy))
		if not str(entry_context.get("source_travel_hold","missing")).is_empty():
			problem="선택한 지역의 원문 조건 보류: "+str(entry_context.get("source_travel_hold"));proposed.close();return false
	proposed.data.spawn_position = [position.x,position.y]
	var tiles: RefCounted=_tiles_for(options) if generic else null
	if generic and tiles==null: proposed.close(); return false
	var actor_position: Vector2 = world.player.global_position
	var camera: Camera2D = world.player.camera
	var old_camera: Dictionary = {"left":camera.limit_left,"top":camera.limit_top,"right":camera.limit_right,"bottom":camera.limit_bottom}
	# Validate presentation at the proposed source position before publishing state.
	world.player.global_position = position
	camera.limit_left = floori(proposed.bounds.position.x); camera.limit_top = floori(proposed.bounds.position.y)
	camera.limit_right = ceili(proposed.bounds.end.x); camera.limit_bottom = ceili(proposed.bounds.end.y)
	camera.reset_smoothing(); camera.force_update_scroll()
	var candidate = RENDERER.new()
	candidate.name = "Current523AdenSourceRenderer"
	candidate.process_mode = Node.PROCESS_MODE_DISABLED; candidate.hide()
	world.add_child(candidate)
	var valid: bool = candidate.try_configure(proposed,world.player,options.raw_root,options.tile_root,Vector2(options.offset_x,options.offset_y),str(options.get("tile_manifest_sha256","")),catalog,tiles)
	world.player.global_position = actor_position
	camera.limit_left = old_camera.left; camera.limit_top = old_camera.top; camera.limit_right = old_camera.right; camera.limit_bottom = old_camera.bottom
	camera.reset_smoothing(); camera.force_update_scroll()
	if not valid:
		problem = candidate.problem; candidate.queue_free(); proposed.close(); return false
	if generic:
		actor_state=_actor_state(world,options)
		entry_context=_entry_context(int(options.native_land_id),str(proposed.get("source_asset")),proposed.world_to_cell(position)+proposed.coordinates.origin,actor_state,str(options.map_time_policy))
		if not _prepare_map_session(entry_context,actor_state):candidate.queue_free();proposed.close();return false
	options.source_position = source_position
	var previous_options: Dictionary=OPTIONS.read()
	if OPTIONS.write(options) != OK:
		problem = "원문 플레이 설정을 저장하지 못했습니다."; candidate.queue_free(); proposed.close(); return false
	if generic and not _switch_map_session(int(options.native_land_id),entry_context,actor_state,previous_options):
		candidate.queue_free();proposed.close();return false
	_prior = prior_renderer; _prior_visible = _prior.visible; _prior_mode = _prior.process_mode
	_prior_world = {"field":prior_field,"monsters_root":world.monsters_root,"field_population":world.field_population,"original_population":world.original_population,"physics":world.field_physics,"position":actor_position,"world_size":world.world_size,"astar":world.astar,"camera":old_camera,"physics_layer":world.field_physics.collision_layer if is_instance_valid(world.field_physics) else 0,"physics_mode":world.field_physics.process_mode if is_instance_valid(world.field_physics) else Node.PROCESS_MODE_INHERIT}
	_source_field = proposed
	if is_instance_valid(world.field_physics):
		world.field_physics.collision_layer = 0
		world.field_physics.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in [world.monsters_root,world.field_population,world.field_population.boss_hud]:
		if not is_instance_valid(node): continue
		_paused_nodes.append({"node":node,"mode":node.process_mode,"visible":bool(node.get("visible")) if node is CanvasItem or node is CanvasLayer else false})
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is CanvasItem or node is CanvasLayer: node.set("visible",false)
	world.ground_loot.hide_map()
	world.loot_pickup.map_changed()
	world.manual_route_pending_target = Vector2.INF
	world._clear_combat_actions(); world._clear_skill_charge()
	if is_instance_valid(world.world_interactions):
		world.world_interactions.cancel_gesture(); world.world_interactions.clear_selection()
	world.player.clear_click_path(); world.player.set_touch_vector(Vector2.ZERO); world.player.velocity = Vector2.ZERO
	world.player.set_auto_enabled(false)
	world.selected_monster = null; world.auto_target = null; world.pending_ground_pickup = null
	_prior.hide(); _prior.process_mode = Node.PROCESS_MODE_DISABLED
	world.field_map = proposed; world.world_size = proposed.bounds.size; world.astar = proposed.astar
	world.player.global_position = position
	camera.limit_left = floori(proposed.bounds.position.x); camera.limit_top = floori(proposed.bounds.position.y)
	camera.limit_right = ceili(proposed.bounds.end.x); camera.limit_bottom = ceili(proposed.bounds.end.y)
	camera.reset_smoothing(); camera.force_update_scroll()
	_source_physics = proposed.build_physics(world); world.field_physics = _source_physics
	_renderer = candidate; world.field_renderer = candidate
	settings = options; source_owned = true; active = true
	candidate.safe_return_requested.connect(_renderer_problem.bind(candidate))
	candidate.process_mode = Node.PROCESS_MODE_INHERIT; candidate.show()
	world.field_minimap.configure(world,proposed)
	world.region_id=""
	world.hud.set_map_name(str(proposed.data.map_name))
	_build_notice(world)
	_load_portals()
	if world.has_method("_refresh_regional_return_slots"):world.call("_refresh_regional_return_slots")
	if generic:_start_map_time_monitor(world)
	if generic:_prepare_selected_npc_environment(proposed,position)
	return true

func _close_source(remember_disabled: bool) -> bool:
	var world: Node = _world()
	if _population_commit_in_progress:
		problem="원문 population 저장·취소 처리 중이므로 현재 소유 상태를 보존합니다.";return false
	if not _held_source_transitions.is_empty() or not _held_population_transactions.is_empty() or (_source_population_owner!=null and _source_population_owner.post_save_hold()):
		problem="population 저장/등록 결과가 미확정이라 정상 저장 불러오기가 필요합니다.";return false
	var saved: bool = true
	if is_instance_valid(_map_time_timer):
		_map_time_timer.stop();_map_time_timer.queue_free();_map_time_timer=null
	if _map_time!=null and _map_time.active():
		_last_map_time=_map_time.end_session()
		if not _last_map_time.get("ok",false):
			saved=false;problem="기존 지도로 복귀했지만 맵 시간 종료 저장이 실패했습니다. 남은 세션은 보수적으로 복구합니다."
	_active_entry_context.clear();_session_condition_identity.clear()
	if remember_disabled:
		var options: Dictionary = _source_checkpoint()
		options.enabled = false
		var options_saved: bool=OPTIONS.write(options)==OK
		if not options_saved:problem+=(" · " if not problem.is_empty() else "")+"자동 시작 해제 설정을 저장하지 못했습니다."
		saved = options_saved and saved
	if is_instance_valid(_renderer):
		_renderer.hide(); _renderer.process_mode = Node.PROCESS_MODE_DISABLED; _renderer.queue_free()
	if is_instance_valid(_source_physics):
		_source_physics.collision_layer = 0; _source_physics.queue_free()
	if is_instance_valid(world) and not _prior_world.is_empty():
		# Source fields share the preserved host map ID; it cannot invalidate
		# a held pointer by itself when returning to another field/camera.
		if is_instance_valid(world.world_interactions): world.world_interactions.cancel_gesture()
		if _source_population_owner!=null:
			_prior_world.original_population.import_state(world.original_population.export_state())
			world.monsters_root=_prior_world.monsters_root;world.field_population=_prior_world.field_population;world.original_population=_prior_world.original_population
			_source_population_owner.dispose_replaced();_source_population_owner=null
		world.field_map = _prior_world.field; world.field_physics = _prior_world.physics
		world.world_size = _prior_world.world_size; world.astar = _prior_world.astar
		world.player.global_position = _prior_world.position
		world.player.clear_click_path(); world.player.set_touch_vector(Vector2.ZERO); world.player.velocity = Vector2.ZERO
		var camera: Camera2D = world.player.camera
		camera.limit_left = _prior_world.camera.left; camera.limit_top = _prior_world.camera.top
		camera.limit_right = _prior_world.camera.right; camera.limit_bottom = _prior_world.camera.bottom
		camera.reset_smoothing(); camera.force_update_scroll()
		if is_instance_valid(world.field_physics):
			world.field_physics.collision_layer = _prior_world.physics_layer
			world.field_physics.process_mode = _prior_world.physics_mode
		world.field_renderer = _prior
		if is_instance_valid(_prior): _prior.visible = _prior_visible; _prior.process_mode = _prior_mode
		for row: Dictionary in _paused_nodes:
			if not is_instance_valid(row.node): continue
			row.node.process_mode = row.mode
			if row.node is CanvasItem or row.node is CanvasLayer: row.node.set("visible",row.visible)
		world.ground_loot.activate(str(world.active_map_id))
		if world.is_inside_tree() and not world.is_queued_for_deletion():
			if world.field_population.get("field")==null: world.field_population.configure(world,world.field_map)
			world.field_minimap.configure(world,world.field_map)
			world.region_id=""
			world.hud.set_map_name(str(world.field_map.region_at(world.player.global_position).get("name",world.active_map.get("name",""))))
	if _source_field != null: _source_field.close()
	if is_instance_valid(_notice): _notice.queue_free()
	_renderer = null; _source_physics = null; _source_field = null; _prior = null; _notice = null; _portals = null
	_prior_world.clear(); _paused_nodes.clear()
	source_owned = false; active = false
	if is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and world.has_method("_refresh_regional_return_slots"):
		world.call("_refresh_regional_return_slots")
	return saved

func _source_checkpoint() -> Dictionary:
	var result: Dictionary = settings.duplicate(true)
	var world: Node = _world()
	if source_owned and is_instance_valid(world) and _source_field.walkable(world.player.global_position): result.source_position = _source_field.coordinates.source_components(world.player.global_position)
	return result

func save_source_progress(quiet: bool, collection_override: Dictionary) -> Error:
	# Existing progress commits through its original writer and spatial identity.
	# The source cursor is separate; it cannot overwrite the old map's coordinates.
	var world: Node = _world()
	var time_failed: bool=false
	if _map_time!=null and _map_time.active():
		if _always_open(settings):
			_last_map_time=_map_time.end_session()
			time_failed=not _last_map_time.get("ok",false)
		else:time_failed=not _map_time.pulse()
	var checkpoint: Dictionary = _source_checkpoint()
	var position: Vector2 = world.player.global_position
	world.field_map = _prior_world.field; world.field_physics = _prior_world.physics; world.field_renderer = _prior
	world.player.global_position = _prior_world.position
	saving_prior_snapshot = true
	var result: Error = world.call("_save_game",quiet,collection_override)
	saving_prior_snapshot = false
	world.field_map = _source_field; world.field_physics = _source_physics; world.field_renderer = _renderer
	world.player.global_position = position
	if result == OK:
		if OPTIONS.write(checkpoint) == OK: settings = checkpoint
		else:
			problem = "진행도는 저장했지만 원문 위치 설정은 저장하지 못했습니다."
			world.hud.show_message(problem)
	if time_failed and is_instance_valid(_renderer):
		# The item/progression transaction keeps its actual result; a time-ledger
		# error cannot turn a committed transaction into a refundable failure.
		_renderer_problem("맵 시간 차감을 저장할 수 없어 기존 지도로 복귀합니다.",_renderer)
	# Never report an already committed item transaction as failed: callers could refund twice.
	return result

func _load_portals() -> void:
	if settings.navigation_profile==OPTIONS.GENERIC or settings.portal_contract.is_empty(): return
	var script: Script = load("res://scripts/maps/current523_aden_source_portals.gd")
	if script == null: return
	var catalog: RefCounted = script.new()
	if catalog.call("load_contract",settings.portal_contract): _portals = catalog
	else: problem = str(catalog.get("problem"))

func portal_evidence() -> Array:
	if source_owned and settings.navigation_profile==OPTIONS.GENERIC:
		if _source_portal_provider==null: return []
		var rows: Variant=_source_portal_provider.call("portal_evidence_for_land",int(settings.native_land_id),str(_source_field.get("source_asset")))
		if not rows is Array: return []
		var result: Array=[]
		for row: Variant in rows:
			if not row is Dictionary or not SOURCE_TRAVEL._uint(row.get("ID"),2147483647): continue
			var id: int=int(row.ID)
			var context: Dictionary=portal_context(id)
			if not context.has("Portal") or not context.has("TargetTerritory"): continue
			var portal: Dictionary=context.Portal
			var territory: Dictionary=context.TargetTerritory
			if int(portal.get("ID",-1))!=id or int(portal.get("SourceLandID",-1))!=int(settings.native_land_id): continue
			var point: Variant=null
			if territory.get("StartX")==territory.get("EndX") and territory.get("StartY")==territory.get("EndY"): point=[territory.StartX,territory.StartY]
			var inactive_names: Array[String]=[]
			for item: Dictionary in context.get("declared_inactive_restrictions",[]):
				var label: String=str(item.type.Name)+"=false"
				if not inactive_names.has(label): inactive_names.append(label)
			var level_notes: Array[String]=[]
			level_notes.append("수동 포탈 자체 비용: %d 아데나 · 원작 요금 아님"%int(settings.get("portal_fee_adena",OPTIONS.OWN_MANUAL_PORTAL_FEE_ADENA)))
			for condition: Dictionary in context.get("actor_level_conditions",[]):
				level_notes.append("%s %s=%d · 현재%d · %s"%[str(condition.get("side","")),str(condition.type.Name),int(condition.threshold),int(condition.actor_level),"충족" if bool(condition.fulfilled) else "미충족"])
			var calendar_notes: Array[String]=[]
			for condition: Dictionary in context.get("land_time_conditions",[]):
				var own_time: Dictionary=context.get("own_map_time",{})
				var calendar: Dictionary=condition.get("calendar",{})
				var group: Dictionary=calendar.get("group",{})
				var group_id: int=int(group.get("ID",-1))
				var remaining: Variant=own_time.get("group_remaining_ms",{}).get(str(group_id))
				var time_note: String="시간 소비 보류: "+str(own_time.get("reason","missing"))
				if context.get("map_open_policy")==OPTIONS.OWN_ALWAYS_OPEN_V1:time_note="상시 오픈 자체정책 · 기간·요일·대기·시간 한도 미적용"
				elif own_time.get("ok",false) and remaining!=null:time_note="자체 공유 한도 %.1f초 · 자동 초기화/충전 없음"%(float(remaining)/1000.0)
				calendar_notes.append("Land%d · 시간그룹%d 달력:%s · %s"%[int(condition.land_id),group_id,str(calendar.get("status","missing")),time_note])
			result.append({"declared_inactive_restrictions":inactive_names,"actor_level_notes":level_notes,"calendar_notes":calendar_notes,"configured_arrival_policy":settings.get("portal_landing_policy","EXACT_POINT_ONLY"),"target_declared_bounds":[territory.StartX,territory.StartY,territory.EndX,territory.EndY],"id":id,"source_position":[portal.SourceX,portal.SourceY],"landing_position":point,"target_land_id":territory.LandID,"activation_candidate":false,"activation_mode":"TWILIGHT_OWN_MANUAL_DECLARED_POINT_V1","definition_hold":context.get("source_travel_hold",""),"definition_owner":context.get("definition_owner","CALLER_SUPPLIED"),"navigation_ticket":_navigation_ticket_for_context(id,context),"native_m_rules_verified":false})
		return result
	var legacy: Array=[]
	if source_owned and _portals!=null:
		for row: Dictionary in _portals.call("portal_evidence"):legacy.append(_legacy_portal_fee_context(row))
	return legacy

func _legacy_portal_fee_context(value: Dictionary) -> Dictionary:
	var result: Dictionary=value.duplicate(true)
	result["own_portal_fee_adena"]=int(settings.get("portal_fee_adena",OPTIONS.OWN_MANUAL_PORTAL_FEE_ADENA))
	result["actor_level_notes"]=["수동 포탈 자체 비용: %d 아데나 · 원작 요금 아님"%result.own_portal_fee_adena]
	return result

func portal_context(id: int) -> Dictionary:
	if source_owned and settings.navigation_profile==OPTIONS.GENERIC:
		if _source_portal_provider==null: return {}
		var context: Variant
		var world: Node=_world()
		var actor_state: Dictionary=_actor_state(world)
		if _source_portal_provider.has_method("portal_context_for_actor_state") and is_instance_valid(world):
			context=_source_portal_provider.call("portal_context_for_actor_state",int(settings.native_land_id),str(_source_field.get("source_asset")),id,actor_state)
		elif _source_portal_provider.has_method("portal_context_for_actor") and is_instance_valid(world):
			# Authoritative current game state, never a level supplied by the UI.
			context=_source_portal_provider.call("portal_context_for_actor",int(settings.native_land_id),str(_source_field.get("source_asset")),id,world.get("level"))
		else:context=_source_portal_provider.call("portal_context_for_land",int(settings.native_land_id),str(_source_field.get("source_asset")),id)
		if context is Dictionary:
			context=_with_map_time_quote(context,actor_state)
			context["runtime_condition_identity"]=_condition_identity(actor_state)
		return context.duplicate(true) if context is Dictionary and _source_context_shape(context) else {}
	if source_owned and _portals!=null:
		var legacy: Dictionary=_portals.call("portal_context",id)
		return _legacy_portal_fee_context(legacy) if not legacy.is_empty() else {}
	return {}

func use_source_portal(id: int) -> bool:
	if source_owned and settings.navigation_profile==OPTIONS.GENERIC: return _use_generic_source_portal(id)
	var world: Node = _world()
	problem = ""
	if not source_owned or not active or _portals == null:
		problem = "검증된 원문 포탈 팩이 없습니다."; return false
	if int(world.hp)<=0 or world.player.movement_locked or world.player.is_stunned() or world.player.is_held() or world.player.is_feared() or not world.charge_skill.is_empty():
		problem = "현재 이동 상태에서는 포탈을 사용할 수 없습니다."; return false
	if float(world.portal_cooldown)>0:
		problem = "이동 직후에는 잠시 뒤 다시 사용해 주세요."; return false
	var source: Vector2i = _source_field.world_to_cell(world.player.global_position)+_source_field.coordinates.origin
	var target: Dictionary = _portals.call("activation_target",id,source,_source_field)
	if not target.get("ok",false):
		var reasons: Dictionary = {"portal_contract_unavailable":"포탈 계약이 없습니다.","portal_endpoint_evidence_incomplete":"원문 출발·도착 근거 또는 대상 필드가 부족해 보류합니다.","actor_not_at_declared_portal":"선언된 포탈 출발 셀에서 사용해 주세요.","source_field_unavailable":"원문 필드가 없습니다.","source_endpoint_blocked":"출발 셀이 자체 통행에서 차단됩니다.","target_endpoint_blocked":"도착 셀이 자체 통행에서 차단됩니다."}
		problem = str(reasons.get(str(target.get("reason")),"포탈의 양쪽 필드를 확인하지 못했습니다.")); return false
	var destination: Vector2i = target.target_position
	var prior_position: Vector2 = world.player.global_position
	var prior_options: Dictionary=OPTIONS.read()
	var quote: Dictionary=TRAVEL_PAYMENT.quote(world,int(settings.get("portal_fee_adena",OPTIONS.OWN_MANUAL_PORTAL_FEE_ADENA)))
	if not quote.get("ok",false):problem=str(quote.get("reason","이동 비용 보류"));return false
	world.player.global_position = _source_field.coordinates.to_world(Vector2(destination))
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	_renderer.refresh_visible()
	if not str(_renderer.get("problem")).is_empty():
		world.player.global_position = prior_position
		world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
		problem = "포탈 도착 화면을 확인하지 못해 출발 위치를 보존합니다."; return false
	var checkpoint: Dictionary=_source_checkpoint()
	if OPTIONS.write(checkpoint)!=OK:
		world.player.global_position=prior_position
		world.player.camera.reset_smoothing();world.player.camera.force_update_scroll();_renderer.refresh_visible()
		problem="목적지 위치를 저장하지 못해 이동 비용을 쓰지 않았습니다.";return false
	var previous_auto: bool=world.player.auto_enabled
	world.player.set_auto_enabled(false)
	if not quote.changes.is_empty():
		var payment: Dictionary=TRAVEL_PAYMENT.commit(world,quote.changes)
		if not payment.get("ok",false):
			problem=str(payment.get("reason","이동 저장 실패"))
			if not payment.get("uncertain",false):
				world.player.set_auto_enabled(previous_auto)
				world.player.global_position=prior_position
				world.player.camera.reset_smoothing();world.player.camera.force_update_scroll();_renderer.refresh_visible()
				if OPTIONS.write(prior_options)!=OK:_renderer_problem("포탈 저장 실패 후 위치 설정 복원이 미확정이라 안전 복귀합니다.",_renderer)
			return false
		world.set("gold",int(quote.changes.gold));world.call("_update_hud")
	settings=checkpoint
	world.player.clear_click_path(); world.player.velocity = Vector2.ZERO; world.player.set_touch_vector(Vector2.ZERO)
	world.portal_cooldown = 2.0
	return true

func bind_source_portal_provider(provider: RefCounted, verified_manifest_sha256: String) -> bool:
	# The caller is PR230's verified definition loader, not arbitrary JSON input.
	# Comparing this pin does not authenticate an untrusted provider by itself.
	if _source_travel_busy: return false
	if active and source_owned and settings.get("navigation_profile")==OPTIONS.GENERIC:
		problem="원문 맵 세션을 종료한 뒤 정의 제공자를 변경해 주세요.";return false
	if provider==null:
		_portal_definition_generation+=1
		_source_portal_provider=null; return true
	if verified_manifest_sha256!=DEFINITION_PACK_SHA256 or not provider.has_method("portal_evidence_for_land") or not provider.has_method("portal_context_for_land"):
		problem="검증된 523 포탈 정의 제공자의 연결 계약이 필요합니다."; return false
	_source_portal_provider=provider
	_portal_definition_generation+=1
	return true

func portal_navigation_ticket(id: int) -> Dictionary:
	return _navigation_ticket_for_context(id,portal_context(id))

func _navigation_ticket_for_context(id: int, context: Dictionary) -> Dictionary:
	# Ephemeral UI request identity, never an admission/activation decision.
	var world: Node=_world()
	if not active or not source_owned or settings.get("navigation_profile")!=OPTIONS.GENERIC or _source_field==null or _source_portal_provider==null or not is_instance_valid(world): return {}
	if world.field_map!=_source_field or world.field_renderer!=_renderer or world.field_physics!=_source_physics: return {}
	if not _source_context_shape(context) or context.Portal.ID!=id or context.SourceLand!=_source_field.get("native_land") or context.Portal.SourceLandID!=context.SourceLand.ID: return {}
	return {"field_instance":_source_field.get_instance_id(),"definition_generation":_portal_definition_generation,"portal":context.Portal.duplicate(true),"source_manifest_sha256":settings.source_manifest_sha256,"actor_position":world.player.global_position,"actor_condition_level":context.get("actor_condition_level",null),"runtime_condition_identity":context.get("runtime_condition_identity",{}).duplicate(true),"own_portal_fee_adena":int(settings.get("portal_fee_adena",OPTIONS.OWN_MANUAL_PORTAL_FEE_ADENA))}

func walk_to_source_portal(id: int, ticket: Dictionary) -> bool:
	problem=""
	var world: Node=_world()
	if ticket.is_empty() or ticket!=portal_navigation_ticket(id):
		problem="지도·원문 정의·캐릭터 위치가 바뀌었습니다. 포탈 목록을 새로 열어 주세요."; return false
	if _source_travel_busy or int(world.hp)<=0 or world.player.movement_locked or world.player.auto_enabled or world.player.is_stunned() or world.player.is_held() or world.player.is_feared() or not world.charge_skill.is_empty():
		problem="현재 이동 상태에서는 원문 출발점으로 걸어갈 수 없습니다."; return false
	var cell:=Vector2i(int(ticket.portal.SourceX),int(ticket.portal.SourceY))
	if _source_field.world_to_cell(world.player.global_position)+_source_field.coordinates.origin==cell:
		problem="이미 원문 출발 셀에 있습니다. 자동 포탈 활성은 수행하지 않습니다."; return false
	var target: Vector2=_source_field.coordinates.to_world(Vector2(cell))
	if not _source_field.point_clear(target,4.0):
		problem="원문 출발 셀이 현재 자체 통행에서 차단됩니다."; return false
	var route: PackedVector2Array=world.find_world_path(world.player.global_position,target)
	if route.is_empty() or route[route.size()-1]!=target:
		problem="원문 출발점까지 확인된 보행 경로가 없습니다. 자체 검색 한도: %d셀. 설정에서 한도를 조절할 수 있습니다." % int(settings.get("path_search_limit",8192)); return false
	if ticket!=portal_navigation_ticket(id):
		problem="경로 확인 중 지도·원문 정의·캐릭터 위치가 바뀌었습니다."; return false
	# All checks precede the only movement write. No position/save/fee/portal use.
	world.player.set_manual_click_path(route,target)
	return true

func _use_generic_source_portal(id: int) -> bool:
	problem=""
	var world: Node=_world()
	if _source_travel_busy or not active or not source_owned or _source_portal_provider==null or not is_instance_valid(world):
		problem="검증된 원문 포탈 정의 연결이 없습니다."; return false
	if int(world.hp)<=0 or world.player.movement_locked or world.player.is_stunned() or world.player.is_held() or world.player.is_feared() or not world.charge_skill.is_empty() or float(world.portal_cooldown)>0:
		problem="현재 이동 상태에서는 자체 수동 포탈을 사용할 수 없습니다."; return false
	_source_travel_busy=true
	var quote: Dictionary=TRAVEL_PAYMENT.quote(world,int(settings.get("portal_fee_adena",OPTIONS.OWN_MANUAL_PORTAL_FEE_ADENA)))
	if not quote.get("ok",false):problem=str(quote.get("reason","이동 비용 보류"));_source_travel_busy=false;return false
	var result: bool=_prepare_generic_source_travel(id,world,quote.changes)
	_source_travel_busy=false
	return result

func _random_clear_portal_landing(world: Node, target: OriginalPlayableField, bounds: Array) -> Dictionary:
	if bounds.size()!=4 or not world.get("rng") is RandomNumberGenerator:return {"ok":false,"reason":"declared_bounds_and_host_rng_required"}
	for value: Variant in bounds:
		if not SOURCE_TRAVEL._uint(value,65535):return {"ok":false,"reason":"invalid_declared_bounds"}
	var width: int=int(bounds[2])-int(bounds[0])+1
	var height: int=int(bounds[3])-int(bounds[1])+1
	if width<1 or height<1 or width*height>4096:return {"ok":false,"reason":"declared_region_exceeds_existing_search_budget"}
	var rng=RandomNumberGenerator.new();rng.seed=world.rng.seed;rng.state=world.rng.state
	var before: Dictionary={"seed":world.rng.seed,"state":world.rng.state}
	var selected: Vector2i;var count: int=0
	for y: int in range(int(bounds[1]),int(bounds[3])+1):
		for x: int in range(int(bounds[0]),int(bounds[2])+1):
			var cell:=Vector2i(x,y)
			var info: Dictionary=target.source_cell_info(cell)
			if info.get("status")=="source_integrity_failure":return {"ok":false,"reason":"source_integrity_failure"}
			if info.get("walkable")!=true:continue
			var point: Vector2=target.coordinates.to_world(Vector2(cell))
			if not target.walkable(point) or not target.point_clear(point,4.0):continue
			# Current actors are usable only for the same logical Land. Cross-Land
			# candidates remain held until their staged target occupancy is adopted.
			if target.get("native_land") == _source_field.get("native_land") and not world._teleport_landing_clear(point):continue
			count+=1
			if rng.randi_range(1,count)==1:selected=cell
	if count==0:return {"ok":false,"reason":"no_confirmed_clear_declared_cell"}
	return {"ok":true,"source_cell":selected,"candidate_count":count,"selection_policy":"OWN_RANDOM_CLEAR_IN_DECLARED_REGION_V1","rng_receipt":{"before":before,"after_state":rng.state},"native_landing_rule_verified":false}

func _prepare_generic_source_travel(id: int,world: Node,save_changes: Dictionary={}) -> bool:
	var context: Dictionary=portal_context(id)
	if not context.has("Portal") or not context.Portal is Dictionary or int(context.Portal.get("ID",-1))!=id or not context.has("TargetLand") or not context.TargetLand is Dictionary:
		problem="포탈의 원문 정의를 확인하지 못했습니다."; return false
	var script: Script=load("res://scripts/maps/current523_source_field.gd")
	var proposed: OriginalPlayableField=script.new()
	var options: Dictionary=settings.duplicate(true)
	var target_id: int=int(context.TargetLand.get("ID",-1))
	var catalog: RefCounted=_catalog_for(options)
	if catalog==null: proposed.close(); return false
	if not proposed.configure_verified_catalog(catalog,options.source_manifest_sha256,target_id,{"allowed_raw_words":options.allowed_raw_words,"path_search_limit":options.get("path_search_limit",8192),"aden_inferred_placement_enabled":options.get("aden_inferred_placement_enabled",true)}):
		problem="대상 원문 필드 보류: "+str(proposed.problem); proposed.close(); return false
	var territory: Dictionary=context.TargetTerritory
	var landing_rng: Dictionary={}
	if (territory.StartX!=territory.EndX or territory.StartY!=territory.EndY) and options.get("portal_landing_policy","EXACT_POINT_ONLY")=="OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1":
		if not _source_portal_provider.has_method("portal_context_for_actor_at_landing") and not _source_portal_provider.has_method("portal_context_for_actor_state_at_landing"):
			problem="면적 도착 셀의 원문 조건을 연결할 정의 제공자가 없습니다.";proposed.close();return false
		var bounds: Array=[territory.StartX,territory.StartY,territory.EndX,territory.EndY]
		var landing: Dictionary=_random_clear_portal_landing(world,proposed,bounds)
		if not landing.get("ok",false):
			problem="선언 영역 안의 자체 안전 착지 보류: "+str(landing.get("reason","unknown"));proposed.close();return false
		var selected_context: Variant
		if _source_portal_provider.has_method("portal_context_for_actor_state_at_landing"):
			selected_context=_source_portal_provider.call("portal_context_for_actor_state_at_landing",int(settings.native_land_id),str(_source_field.get("source_asset")),id,_actor_state(world),landing.source_cell,"OWN_RANDOM_CLEAR_IN_DECLARED_REGION_V1")
		else:selected_context=_source_portal_provider.call("portal_context_for_actor_at_landing",int(settings.native_land_id),str(_source_field.get("source_asset")),id,world.get("level"),landing.source_cell,"OWN_RANDOM_CLEAR_IN_DECLARED_REGION_V1")
		if not selected_context is Dictionary or not _source_context_shape(selected_context):
			problem="선택한 도착 셀의 원문 조건을 읽지 못했습니다.";proposed.close();return false
		for key: String in ["Portal","SourceLand","TargetTerritory","TargetLand"]:
			if selected_context[key]!=context[key]:
				problem="착지 준비 중 원문 포탈 선언이 바뀌었습니다.";proposed.close();return false
		context=_with_map_time_quote(selected_context,_actor_state(world))
		landing_rng=landing.rng_receipt
	var source_cell: Vector2i=_source_field.world_to_cell(world.player.global_position)+_source_field.coordinates.origin
	var plan: Dictionary=SOURCE_TRAVEL.plan(context,_source_field.get("_raw"),_source_field,proposed,source_cell,str(options.source_manifest_sha256))
	if not plan.get("ok",false):
		problem="자체 수동 이동 보류: "+str(plan.get("reason","unknown")); proposed.close(); return false
	context["own_landing_rng"]=landing_rng
	return _commit_source_destination(world,proposed,options,plan.target_position,catalog,context,id,save_changes)

func _aden_return_point(field: OriginalPlayableField, radius: int) -> Dictionary:
	var center:=Vector2i(ADEN_RETURN_LOCATION.X,ADEN_RETURN_LOCATION.Y)
	for ring: int in range(radius+1):
		for y: int in range(center.y-ring,center.y+ring+1):
			for x: int in range(center.x-ring,center.x+ring+1):
				if maxi(absi(x-center.x),absi(y-center.y))!=ring:continue
				var cell:=Vector2i(x,y)
				var info: Dictionary=field.call("source_cell_info",cell)
				if info.get("status")!="allowed" or info.get("walkable")!=true:continue
				var position: Vector2=field.coordinates.to_world(Vector2(cell))
				if field.point_clear(position,4.0):return {"ok":true,"source_cell":cell,"position":position,"ring":ring}
	return {"ok":false,"reason":"아덴 원문 귀환점 주변에 자체 통행에서 확인된 착지 셀이 없습니다."}

func return_to_aden(save_changes: Dictionary={}) -> Dictionary:
	problem="";_last_source_transition={"ok":false,"saved":false,"uncertain":false}
	var world: Node=_world()
	if _source_travel_busy or not active or not source_owned or not is_instance_valid(world):
		return {"ok":false,"saved":false,"reason":"현재 원문 맵의 귀환 소비자가 없습니다."}
	var permitted: Dictionary=TRAVEL_PAYMENT.quote(world,0)
	if not permitted.get("ok",false):return permitted
	if int(world.hp)<=0 or world.player.movement_locked or world.player.is_stunned() or world.player.is_held() or world.player.is_feared() or not world.charge_skill.is_empty() or float(world.portal_cooldown)>0:
		return {"ok":false,"saved":false,"reason":"현재 이동 상태에서는 아덴으로 귀환할 수 없습니다."}
	_source_travel_busy=true
	var completed: bool=false
	if settings.navigation_profile==OPTIONS.GENERIC:
		var current_cell: Vector2i=_source_field.world_to_cell(world.player.global_position)+_source_field.coordinates.origin
		var departure: Dictionary=_entry_context(int(settings.native_land_id),str(_source_field.get("source_asset")),current_cell,_actor_state(world))
		if not str(departure.get("source_travel_hold","missing")).is_empty():
			problem="현재 원문 지역의 이동 제한으로 귀환을 보류합니다."
			_source_travel_busy=false
			return {"ok":false,"saved":false,"handled":true,"reason":problem}
		var catalog: RefCounted=_catalog_for(settings)
		if catalog!=null:
			var script: Script=load("res://scripts/maps/current523_source_field.gd")
			var proposed: OriginalPlayableField=script.new()
			if proposed.configure_verified_catalog(catalog,settings.source_manifest_sha256,4,{"allowed_raw_words":settings.allowed_raw_words,"path_search_limit":settings.get("path_search_limit",8192),"aden_inferred_placement_enabled":settings.get("aden_inferred_placement_enabled",true)}):
				var landing: Dictionary=_aden_return_point(proposed,int(settings.get("aden_return_radius",8)))
				if landing.get("ok",false):completed=_commit_source_destination(world,proposed,settings.duplicate(true),landing.source_cell,catalog,{},-1,save_changes)
				else:problem=str(landing.reason);proposed.close()
			else:problem=str(proposed.get("problem"));proposed.close()
	else:completed=_return_within_aden(world,save_changes)
	_source_travel_busy=false
	var result: Dictionary=_last_source_transition.duplicate(true)
	result.merge({"ok":completed,"handled":true,"policy":ADEN_RETURN_POLICY,"source_location":ADEN_RETURN_LOCATION.duplicate(true),"native_return_relation_verified":false,"reason":"아덴으로 귀환했습니다 · 자체 지정 목적지" if completed else problem},true)
	return result

func _return_within_aden(world: Node,save_changes: Dictionary) -> bool:
	var landing: Dictionary=_aden_return_point(_source_field,int(settings.get("aden_return_radius",8)))
	if not landing.get("ok",false):problem=str(landing.reason);return false
	var old_position: Vector2=world.player.global_position
	var previous_options: Dictionary=OPTIONS.read()
	world.player.global_position=landing.position
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	_renderer.refresh_visible()
	if not str(_renderer.get("problem")).is_empty():
		world.player.global_position=old_position;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		problem="아덴 귀환 화면을 준비하지 못했습니다.";return false
	var checkpoint: Dictionary=_source_checkpoint()
	if OPTIONS.write(checkpoint)!=OK:
		world.player.global_position=old_position;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		_renderer.refresh_visible();problem="아덴 귀환 위치를 저장하지 못했습니다.";return false
	var payment: Dictionary={"ok":true,"saved":false,"uncertain":false}
	if not save_changes.is_empty():payment=TRAVEL_PAYMENT.commit(world,save_changes)
	_last_source_transition=payment.duplicate(true)
	if not payment.get("ok",false) and not payment.get("uncertain",false):
		world.player.global_position=old_position;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		_renderer.refresh_visible()
		if OPTIONS.write(previous_options)!=OK:_renderer_problem("귀환 저장 실패 후 위치 복원이 미확정이라 안전 복귀합니다.",_renderer)
		problem=str(payment.get("reason","귀환 저장 실패"));return false
	settings=checkpoint
	world.player.clear_click_path();world.player.set_touch_vector(Vector2.ZERO);world.player.velocity=Vector2.ZERO
	if is_instance_valid(world.world_interactions):world.world_interactions.cancel_gesture()
	world.portal_cooldown=2.0
	if payment.get("uncertain",false):problem=str(payment.reason);return false
	if save_changes.has("gold"):world.set("gold",int(save_changes.gold))
	return true

func _commit_source_destination(world: Node,proposed: OriginalPlayableField,options: Dictionary,destination: Vector2i,catalog: RefCounted,context: Dictionary={},id: int=-1,save_changes: Dictionary={},precommit_guard: Callable=Callable()) -> bool:
	var transaction: RefCounted
	if int(proposed.get("native_land").ID)!=int(settings.get("native_land_id",-1)):
		var prepared: Dictionary=_prepare_cross_land_encounter_specs(world,proposed,destination,context,id,save_changes)
		transaction=prepared.get("transaction")
		if transaction==null:
			_last_source_transition={"ok":false,"saved":false,"uncertain":false,"code":"TARGET_SOURCE_POPULATION_HELD","encounter_preparation":prepared}
			problem=str(prepared.get("reason","원문 target population 준비 보류"));proposed.close();return false
	if transaction!=null:_population_commit_in_progress=true
	var completed: bool=_commit_source_destination_impl(world,proposed,options,destination,catalog,context,id,save_changes,precommit_guard,transaction)
	if transaction!=null:
		if transaction.state=="FINISHED" or transaction.post_save_hold():
			var prior_owner: RefCounted=_source_population_owner
			_source_population_owner=transaction
			if prior_owner!=null:
				if transaction.state=="FINISHED":prior_owner.dispose_replaced()
				else:_held_population_transactions.append(prior_owner)
		else:
			var restored: Dictionary={"ok":true} if transaction.state=="RESTORED" else (transaction.describe() if transaction.state=="RESTORE_CONFLICT" else transaction.rollback())
			if restored.get("ok")!=true:
				world.set("source_save_blocked",true);_held_population_transactions.append(transaction)
			_last_source_transition["population_disposition"]=transaction.describe()
	if transaction!=null:_population_commit_in_progress=false
	return completed

func _commit_source_destination_impl(world: Node,proposed: OriginalPlayableField,options: Dictionary,destination: Vector2i,catalog: RefCounted,context: Dictionary={},id: int=-1,save_changes: Dictionary={},precommit_guard: Callable=Callable(), transaction: RefCounted=null) -> bool:
	_last_source_transition={"ok":false,"saved":false,"uncertain":false}
	var target_id: int=int(proposed.get("native_land").ID)
	var position: Vector2=proposed.coordinates.to_world(Vector2(destination))
	proposed.data.spawn_position=[position.x,position.y]
	var tiles: RefCounted=_tiles_for(options)
	if tiles==null: proposed.close(); return false
	var previous_position: Vector2=world.player.global_position
	var camera: Camera2D=world.player.camera
	var previous_camera: Dictionary={"left":camera.limit_left,"top":camera.limit_top,"right":camera.limit_right,"bottom":camera.limit_bottom}
	var candidate=RENDERER.new()
	candidate.name="Current523GenericTravelRenderer"
	candidate.process_mode=Node.PROCESS_MODE_DISABLED; candidate.hide(); world.add_child(candidate)
	var valid: bool=candidate.try_configure(proposed,world.player,options.raw_root,options.tile_root,Vector2(options.offset_x,options.offset_y),str(options.tile_manifest_sha256),catalog,tiles,position)
	if not valid:
		problem="도착 화면 확인 실패: "+str(candidate.problem); candidate.queue_free(); proposed.close(); return false
	var actor_state: Dictionary=_actor_state(world)
	# Rendering may take wall time. Consume the current source AND target
	# conditions again before committing a transition across a date boundary.
	if id>=0:
		var final_context: Variant
		if _source_portal_provider.has_method("portal_context_for_actor_state_at_landing"):
			final_context=_source_portal_provider.call("portal_context_for_actor_state_at_landing",int(settings.native_land_id),str(_source_field.get("source_asset")),id,actor_state,destination,str(context.get("own_arrival_policy","EXACT_POINT_ONLY")))
		else:final_context=portal_context(id)
		if not final_context is Dictionary or not _source_context_shape(final_context):
			problem="이동 준비 중 포탈 조건을 사용할 수 없게 되었습니다.";candidate.queue_free();proposed.close();return false
		for key: String in ["Portal","SourceLand","TargetTerritory","TargetLand"]:
			if final_context[key]!=context[key]:
				problem="이동 준비 중 원문 포탈 선언이 바뀌었습니다.";candidate.queue_free();proposed.close();return false
		final_context=_with_map_time_quote(final_context,actor_state)
		if not str(final_context.get("source_travel_hold","missing")).is_empty():
			problem="이동 직전 원문 조건 또는 잔여시간이 보류되었습니다.";candidate.queue_free();proposed.close();return false
	var entry_context: Dictionary=_entry_context(target_id,str(proposed.get("source_asset")),destination,actor_state)
	if precommit_guard.is_valid() and not precommit_guard.call():
		problem="도착 준비 중 원문 일정·비용·위치·조건이 바뀌었습니다.";candidate.queue_free();proposed.close();return false
	var landing_rng: Dictionary=context.get("own_landing_rng",{})
	if not proposed.walkable(position) or not proposed.point_clear(position,4.0) or (transaction==null and not world._teleport_landing_clear(position)):
		problem="이동 직전 도착 셀의 통행·점유가 바뀌었습니다.";candidate.queue_free();proposed.close();return false
	if not landing_rng.is_empty() and (world.rng.seed!=landing_rng.before.seed or world.rng.state!=landing_rng.before.state):
		problem="이동 준비 중 랜덤 선택 입력이 바뀌었습니다.";candidate.queue_free();proposed.close();return false
	if not _prepare_map_session(entry_context,actor_state):candidate.queue_free();proposed.close();return false
	var physics: StaticBody2D=proposed.build_physics(world)
	physics.collision_layer=0; physics.process_mode=Node.PROCESS_MODE_DISABLED
	options.native_land_id=target_id; options.source_position=[destination.x+0.5,destination.y+0.5]
	var previous_options: Dictionary=OPTIONS.read()
	var previous_settings: Dictionary=settings.duplicate(true)
	var previous_entry: Dictionary=_active_entry_context.duplicate(true)
	var previous_state: Dictionary=_actor_state(world)
	if transaction!=null:
		var registered: Dictionary=transaction.register_and_prepare()
		if registered.get("ok")!=true:
			problem=str(registered.get("reason","target_population_preparation_failed"));candidate.queue_free();physics.queue_free();proposed.close();return false
	if transaction!=null:
		var fresh_route: Dictionary=_registered_cross_land_route(world,transaction,context,id,destination,save_changes)
		if fresh_route.get("ok")!=true:
			transaction.record_registered_route_rejection(fresh_route)
			problem=str(fresh_route.get("reason","registered_route_changed"));candidate.queue_free();physics.queue_free();proposed.close();return false
		entry_context=fresh_route.entry_context
		actor_state=_actor_state(world)
		if not _prepare_map_session(entry_context,actor_state):candidate.queue_free();physics.queue_free();proposed.close();return false
	if transaction!=null:
		var attempt: Dictionary=transaction.begin_transition_attempt()
		if attempt.get("ok")!=true:
			problem=str(attempt.get("reason","transition_attempt_not_authorized"));candidate.queue_free();physics.queue_free();proposed.close();return false
		transaction.note_transition_attempt("options_write_attempted")
	if OPTIONS.write(options)!=OK:
		problem="목적지 위치를 저장하지 못해 현재 원문 필드를 보존합니다."
		candidate.queue_free(); physics.queue_free(); proposed.close(); return false
	if transaction!=null:transaction.note_transition_attempt("session_switch_attempted")
	if not _switch_map_session(target_id,entry_context,actor_state,previous_options):
		candidate.queue_free();physics.queue_free();proposed.close();return false
	if transaction!=null:
		var final_route: Dictionary=_registered_cross_land_route(world,transaction,context,id,destination,save_changes)
		if final_route.get("ok")!=true:
			var reverted: bool=OPTIONS.write(previous_options)==OK
			if not previous_entry.is_empty() and _prepare_map_session(previous_entry,previous_state):reverted=_switch_map_session(int(previous_settings.native_land_id),previous_entry,previous_state,previous_options) and reverted
			else:reverted=false
			problem=str(final_route.get("reason","final_route_changed"))
			if not reverted:world.set("source_save_blocked",true)
			candidate.queue_free();physics.queue_free();proposed.close();return false
	# All fallible validation and the atomic checkpoint precede the commit.
	# The initial host snapshot/paused actors are retained across every hop.
	var previous_field: OriginalPlayableField=_source_field
	var previous_renderer: FieldRenderer=_renderer
	var previous_physics: StaticBody2D=_source_physics
	var previous_display: Dictionary={"visible":previous_renderer.visible,"mode":previous_renderer.process_mode,"layer":previous_physics.collision_layer,"physics_mode":previous_physics.process_mode}
	previous_renderer.hide(); previous_renderer.process_mode=Node.PROCESS_MODE_DISABLED
	previous_physics.collision_layer=0; previous_physics.process_mode=Node.PROCESS_MODE_DISABLED
	# User policy: stop hunting only at the actual accepted transition boundary.
	var previous_auto: bool=world.player.auto_enabled
	world.player.set_auto_enabled(false)
	if not landing_rng.is_empty():world.rng.state=landing_rng.after_state
	if transaction!=null:transaction.note_transition_attempt("owner_adoption_attempted")
	_source_field=proposed; _renderer=candidate; _source_physics=physics; settings=options
	world.field_map=proposed; world.field_renderer=candidate; world.field_physics=physics
	world.world_size=proposed.bounds.size; world.astar=proposed.astar
	world.player.clear_click_path(); world.player.set_touch_vector(Vector2.ZERO); world.player.velocity=Vector2.ZERO
	if is_instance_valid(world.world_interactions): world.world_interactions.cancel_gesture()
	world.player.global_position=position
	camera.limit_left=floori(proposed.bounds.position.x); camera.limit_top=floori(proposed.bounds.position.y)
	camera.limit_right=ceili(proposed.bounds.end.x); camera.limit_bottom=ceili(proposed.bounds.end.y)
	camera.reset_smoothing(); camera.force_update_scroll()
	var prior_population_field: PlayableField=world.field_population.field
	var adopted: Dictionary={"ok":true}
	if not candidate.activate_prepared_view():adopted={"ok":false,"reason":"prepared_target_view_activation_failed"}
	elif transaction!=null:adopted=transaction.adopt()
	elif _source_population_owner!=null:world.field_population.field=proposed
	var payment: Dictionary={"ok":true,"saved":false,"uncertain":false}
	if adopted.get("ok")!=true:payment={"ok":false,"saved":false,"uncertain":false,"reason":adopted.get("reason","target_population_adoption_failed")}
	elif transaction!=null:
		var save_observation: Dictionary=transaction.begin_save_observation()
		if save_observation.get("ok")!=true:payment={"ok":false,"saved":false,"uncertain":false,"reason":save_observation.get("reason","population_save_owner_not_ready")}
		else:
			transaction.note_transition_attempt("save_attempted")
			payment=TRAVEL_PAYMENT.commit(world,save_changes)
	elif not save_changes.is_empty():payment=TRAVEL_PAYMENT.commit(world,save_changes)
	_last_source_transition=payment.duplicate(true)
	if not payment.get("ok",false) and not payment.get("uncertain",false):
		problem=str(payment.get("reason","이동 저장 실패"))
		if transaction!=null:
			var restored_population: Dictionary=transaction.rollback()
			_last_source_transition["population_restore"]=restored_population
			if restored_population.get("ok")!=true:
				world.set("source_save_blocked",true);previous_auto=false
				if restored_population.get("population_restored")!=true:
					_last_source_transition["uncertain"]=true
					_held_source_transitions.append({"field":previous_field,"renderer":previous_renderer,"physics":previous_physics,"settings":previous_settings,"position":previous_position,"camera":previous_camera,"population":transaction})
					problem="population 소유권 복구 충돌 · 현재 상태 보존 및 정상 저장 불러오기 필요";return false
		elif _source_population_owner!=null:world.field_population.field=prior_population_field
		world.player.set_auto_enabled(previous_auto)
		if not landing_rng.is_empty():world.rng.state=landing_rng.before.state
		_source_field=previous_field;_renderer=previous_renderer;_source_physics=previous_physics;settings=previous_settings
		world.field_map=previous_field;world.field_renderer=previous_renderer;world.field_physics=previous_physics
		world.world_size=previous_field.bounds.size;world.astar=previous_field.astar
		world.player.global_position=previous_position
		camera.limit_left=previous_camera.left;camera.limit_top=previous_camera.top;camera.limit_right=previous_camera.right;camera.limit_bottom=previous_camera.bottom
		camera.reset_smoothing();camera.force_update_scroll()
		previous_renderer.process_mode=previous_display.mode;previous_renderer.visible=previous_display.visible
		previous_physics.collision_layer=previous_display.layer;previous_physics.process_mode=previous_display.physics_mode
		candidate.queue_free();physics.queue_free();proposed.close()
		var saved_problem: String=problem
		var restored: bool=OPTIONS.write(previous_options)==OK
		if not previous_entry.is_empty() and _prepare_map_session(previous_entry,previous_state):
			restored=_switch_map_session(int(previous_settings.native_land_id),previous_entry,previous_state,previous_options) and restored
		else:restored=false
		problem=saved_problem
		if not restored:
			if transaction!=null:world.set("source_save_blocked",true)
			_renderer_problem("이동 저장 복원 중 시간/위치 상태를 계속할 수 없어 안전 복귀합니다.",previous_renderer)
		return false
	if payment.get("ok",false) and save_changes.has("gold"):world.set("gold",int(save_changes.gold))
	var population_finish: Dictionary={"ok":true}
	if transaction!=null:
		population_finish=transaction.finish(payment)
		_last_source_transition["population_finish"]=population_finish
		if population_finish.get("ok")!=true:world.set("source_save_blocked",true)
	physics.collision_layer=4; physics.process_mode=Node.PROCESS_MODE_INHERIT
	candidate.safe_return_requested.connect(_renderer_problem.bind(candidate))
	candidate.process_mode=Node.PROCESS_MODE_INHERIT; candidate.show()
	world.field_minimap.configure(world,proposed); world.region_id=""; world.hud.set_map_name(str(proposed.data.map_name))
	if is_instance_valid(_notice): _notice.queue_free()
	_build_notice(world)
	_start_map_time_monitor(world)
	world.portal_cooldown=2.0
	if transaction!=null and (payment.get("uncertain",false) or population_finish.get("ok")!=true):
		_held_source_transitions.append({"field":previous_field,"renderer":previous_renderer,"physics":previous_physics,"settings":previous_settings,"position":previous_position,"camera":previous_camera,"population":transaction})
	else:
		previous_renderer.queue_free(); previous_physics.queue_free(); previous_field.close()
	if world.has_method("_refresh_regional_return_slots"):world.call("_refresh_regional_return_slots")
	if payment.get("uncertain",false):
		problem=str(payment.get("reason","이동 저장 결과 미확정 · 정상 저장 불러오기 필요"));return false
	if population_finish.get("ok")!=true:
		problem=str(population_finish.get("reason","population 등록 종료 결과 확인 필요"));return false
	if save_changes.has("gold"):world.call("_update_hud")
	_last_source_transition["ok"]=true
	_prepare_selected_npc_environment(proposed,position)
	return true

func _registered_cross_land_route(world: Node, transaction: RefCounted, context: Dictionary, id: int, destination: Vector2i, save_changes: Dictionary) -> Dictionary:
	var request: Dictionary=transaction.stage.selected_request()
	var host: Dictionary=request.get("host_transition",{})
	var actor_state: Dictionary=_actor_state(world)
	if host.get("definition_generation")!=_portal_definition_generation or host.get("conditions")!=_condition_identity(actor_state) or host.get("source_settings")!=settings:return {"ok":false,"reason":"selected_source_conditions_changed"}
	var stale: Dictionary=transaction.revalidate_registered()
	if stale.get("ok")!=true:return stale
	if not _source_portal_provider.has_method("portal_context_for_actor_state_at_landing"):return {"ok":false,"reason":"actual_selected_landing_receiver_required"}
	var fresh: Variant=_source_portal_provider.call("portal_context_for_actor_state_at_landing",int(settings.native_land_id),str(_source_field.get("source_asset")),id,actor_state,destination,str(context.get("own_arrival_policy","EXACT_POINT_ONLY")))
	if not fresh is Dictionary or not _source_context_shape(fresh):return {"ok":false,"reason":"current_original_portal_context_unavailable"}
	for key: String in ["Portal","SourceLand","TargetTerritory","TargetLand"]:
		if fresh.get(key)!=context.get(key):return {"ok":false,"reason":"original_portal_endpoints_changed"}
	fresh=_with_map_time_quote(fresh,actor_state)
	if not str(fresh.get("source_travel_hold","missing")).is_empty():return {"ok":false,"reason":"current_original_portal_conditions_held"}
	var quote: Dictionary=TRAVEL_PAYMENT.quote(world,int(settings.get("portal_fee_adena",OPTIONS.OWN_MANUAL_PORTAL_FEE_ADENA)))
	if quote.get("ok")!=true or quote.get("changes")!=save_changes or host.get("save_changes")!=save_changes:return {"ok":false,"reason":"current_route_cost_or_save_owner_changed"}
	var target: RefCounted=transaction.stage.field
	var entry: Dictionary=_entry_context(int(target.get("native_land").ID),str(target.get("source_asset")),destination,actor_state)
	return {"ok":true,"entry_context":entry}

func _prepare_cross_land_encounter_specs(world: Node, proposed: OriginalPlayableField, destination: Vector2i, context: Dictionary, id: int, save_changes: Dictionary) -> Dictionary:
	# Real travel caller, before any live renderer/field/player/cost mutation.
	# Use the actual data-owner batch receipt; registration is deferred until
	# complete target population/media/save adoption exists.
	if id<0 or not _source_context_shape(context):return {"state":"HELD","activation_ready":false,"reason":"explicit_original_portal_endpoints_required"}
	if _source_portal_provider==null or not _source_portal_provider.has_method("source_population_definition_for_land"):return {"state":"HELD","activation_ready":false,"reason":"target_definition_owner_required"}
	var generation: int=_portal_definition_generation
	var conditions: Dictionary=_condition_identity(_actor_state(world))
	var native_land: Dictionary=proposed.get("native_land")
	var definition: Variant=_source_portal_provider.call("source_population_definition_for_land",int(native_land.ID),str(native_land.AssetPath))
	if not definition is RefCounted:return {"state":"HELD","activation_ready":false,"reason":"target_original_definition_unavailable"}
	var request: Dictionary=context.duplicate(true)
	request["host_transition"]={"definition_generation":generation,"conditions":conditions,"save_changes":save_changes.duplicate(true),"source_settings":settings.duplicate(true)}
	var stage=STAGED_ENCOUNTERS.new()
	var prepared: bool=stage.prepare(world,proposed,definition,destination,request)
	var batch: Dictionary={}
	var bodies: Dictionary={}
	var result: Dictionary=stage.describe()
	result["prepared"]=prepared
	if prepared:
		var batch_request: Dictionary=stage.actor_batch_request()
		result["explicit_encounter_records_for_data_owner"]=batch_request.get("records",[]).size()
		var service: Variant=world.get("patch523_npc_spells")
		var npc_catalog: Variant=service.get("catalog") if service is Object else null
		if npc_catalog is RefCounted and npc_catalog.has_method("prepare_actor_batch"):
			batch=npc_catalog.prepare_actor_batch(batch_request.records,proposed,world,world.get("field_population"),str(batch_request.expected_npc_model_sha256))
			result["batch_prepared"]=batch.get("ok")==true
			result["batch_reason"]=batch.get("reason","")
			if batch.get("ok")==true:
				bodies=stage.materialize_actor_bodies(world,batch)
				result["actor_body_preparation"]=bodies
				result["prepared_model_sha256"]=batch.get("prepared_model_sha256","")
				result["catalog_changed"]=false
		else:result["batch_reason"]="exact_data_batch_owner_not_installed"

		var fresh: Dictionary=portal_context(id)
		if _source_portal_provider.has_method("portal_context_for_actor_state_at_landing"):
			fresh=_source_portal_provider.call("portal_context_for_actor_state_at_landing",int(settings.native_land_id),str(_source_field.get("source_asset")),id,_actor_state(world),destination,str(context.get("own_arrival_policy","EXACT_POINT_ONLY")))
		var endpoints_match: bool=_source_context_shape(fresh) and fresh.get("source_travel_hold")==""
		for key: String in ["Portal","SourceLand","TargetTerritory","TargetLand"]:
			if fresh.get(key)!=context.get(key):endpoints_match=false
		var quote: Dictionary=TRAVEL_PAYMENT.quote(world,int(settings.get("portal_fee_adena",OPTIONS.OWN_MANUAL_PORTAL_FEE_ADENA)))
		result["source_preconditions_unchanged"]=generation==_portal_definition_generation and conditions==_condition_identity(_actor_state(world)) and endpoints_match and quote.get("ok")==true and quote.get("changes")==save_changes
		result["stale_check"]=stage.revalidate(world,proposed,definition,destination,request)
	if prepared and result.get("source_preconditions_unchanged")==true and result.get("stale_check",{}).get("ok")==true and batch.get("ok")==true and bodies.get("ok")==true:
		var transaction=POPULATION_TRANSACTION.new()
		if transaction.configure(world,stage,batch):
			result["transaction"]=transaction;result["reason"]="";return result
	result["prepared_stage"]=stage.describe()
	# Only the detached specification/body container is owned here. The travel caller closes
	# its private target field after rejection; current actors remain untouched.
	stage.discard()
	result["discard_state"]=stage.state
	return result

func _source_context_shape(context: Dictionary) -> bool:
	for name: String in ["Portal","SourceLand","TargetTerritory","TargetLand"]:
		if not context.get(name) is Dictionary: return false
	var portal: Dictionary=context.Portal
	var territory: Dictionary=context.TargetTerritory
	for key: String in ["ID","SourceLandID","AssetID","TargetTerritoryID"]:
		if not SOURCE_TRAVEL._uint(portal.get(key),2147483647): return false
	for key: String in ["SourceX","SourceY"]:
		if not SOURCE_TRAVEL._uint(portal.get(key),65535): return false
	for key: String in ["ID","LandID","DescID"]:
		if not SOURCE_TRAVEL._uint(territory.get(key),2147483647): return false
	for key: String in ["StartX","StartY","EndX","EndY"]:
		if not SOURCE_TRAVEL._uint(territory.get(key),65535): return false
	for land: Dictionary in [context.SourceLand,context.TargetLand]:
		if not SOURCE_TRAVEL._uint(land.get("ID"),2147483647) or not land.get("AssetPath") is String: return false
	return true

func source_geographic_contract() -> Dictionary:
	if not active or not source_owned or settings.get("navigation_profile")!=OPTIONS.GENERIC or _source_field==null: return {}
	var world: Node=_world()
	if not is_instance_valid(world) or world.field_map!=_source_field: return {}
	var contract: Dictionary=_source_field.call("source_geographic_contract")
	contract.current_source_components=_source_field.coordinates.source_components(world.player.global_position)
	return contract

# Existing AutoSchedule caller selects an exact typed landing relation. This
# OWN adapter is same-Land only; it is neither a Portal nor automatic admission.
func assess_source_schedule(definition: Dictionary) -> Dictionary:
	var world: Node=_world()
	if not definition.get("ok",false):return definition
	if not active or not source_owned or settings.get("navigation_profile")!=OPTIONS.GENERIC or not is_instance_valid(world) or world.field_map!=_source_field:return {"ok":false,"reason":"현재 원문 필드가 필요합니다."}
	var local: Dictionary=world.auto_hunting_local.get_settings()
	if not local.enabled or not world.auto_hunting_local.problem.is_empty():return {"ok":false,"reason":"기존 자체 이동 설정을 켜 주세요."}
	if int(world.hp)<=0 or world.player.movement_locked or world.player.is_stunned() or world.player.is_held() or world.player.is_feared() or not world.charge_skill.is_empty() or float(world.portal_cooldown)>0:return {"ok":false,"reason":"현재 이동 상태에서는 사용할 수 없습니다."}
	if int(definition.get("currency_id",-1))!=1:return {"ok":false,"reason":"원문 필드의 이 호출은 아데나 결제만 연결돼 있습니다."}
	var landing: Dictionary=definition.landing
	if landing.land!=_source_field.get("native_land") or landing.territory.get("LandID")!=landing.land.ID:return {"ok":false,"reason":"현재와 같은 원문 Land의 명시 착지만 지원합니다."}
	var actor_state: Dictionary=_actor_state(world)
	var source_cell: Vector2i=_source_field.world_to_cell(world.player.global_position)+_source_field.coordinates.origin
	var departure: Dictionary=_entry_context(int(landing.land.ID),str(landing.land.AssetPath),source_cell,actor_state)
	if not str(departure.get("source_travel_hold","missing")).is_empty():return {"ok":false,"reason":"출발 원문 조건 보류: "+str(departure.source_travel_hold)}
	var bounds: Rect2i=world.AUTO_HUNTING_LOCAL.territory_bounds(landing.territory,bool(local.end_inclusive))
	if not bounds.has_area():return {"ok":false,"reason":"선택한 끝 좌표 정책에서 도착 영역이 비어 있습니다."}
	if bounds.has_point(source_cell):return {"ok":false,"reason":"이미 선택한 도착 영역 안에 있습니다. 비용을 소모하지 않습니다."}
	var selected: Dictionary=world.AUTO_HUNTING_LOCAL.find_cell(_source_field,bounds,str(local.search_order),func(point: Vector2) -> bool:
		if not _source_field.point_clear(point,4.0) or not world._teleport_landing_clear(point):return false
		var cell: Vector2i=_source_field.world_to_cell(point)+_source_field.coordinates.origin
		var conditions: Dictionary=_entry_context(int(landing.land.ID),str(landing.land.AssetPath),cell,actor_state)
		return str(conditions.get("source_travel_hold","missing")).is_empty())
	if not selected.get("ok",false):return selected
	var payment: Dictionary=TRAVEL_PAYMENT.quote(world,int(definition.price))
	if not payment.get("ok",false):return payment
	var result: Dictionary=definition.duplicate(true)
	result.merge(selected,true)
	result["policy"]="OWN_SAME_SOURCE_LAND_SCHEDULE_V1"
	result["native_activation_verified"]=false
	result["reason"]="현재 원문 Land 내 자체 착지 · 원본 비용 %d 아데나"%int(definition.price)
	result["navigation_ticket"]={"field":_source_field.get_instance_id(),"definition_generation":_portal_definition_generation,"position":world.player.global_position,"wallet_gold":world.gold,"source_settings":settings.duplicate(true),"local_settings":local,"definition":definition.duplicate(true)}
	return result

func move_source_schedule(definition: Dictionary) -> Dictionary:
	if _source_travel_busy:return {"ok":false,"reason":"기존 원문 이동 처리 중입니다."}
	var quote: Dictionary=assess_source_schedule(definition)
	if not quote.get("ok",false):return quote
	var world: Node=_world()
	var held: Dictionary=quote.duplicate(true)
	var options: Dictionary=settings.duplicate(true)
	var catalog: RefCounted=_catalog_for(options)
	if catalog==null:return {"ok":false,"reason":problem}
	var proposed: OriginalPlayableField=load("res://scripts/maps/current523_source_field.gd").new()
	if not proposed.configure_verified_catalog(catalog,str(options.source_manifest_sha256),int(options.native_land_id),_source_field.policy.duplicate(true)):
		var reason: String=str(proposed.problem);proposed.close();return {"ok":false,"reason":reason}
	var payment: Dictionary=TRAVEL_PAYMENT.quote(world,int(quote.price))
	if not payment.get("ok",false):proposed.close();return payment
	# The existing source transaction owns cursor, renderer, rollback and save.
	# Requote the original caller after render preparation, before any commit.
	var guard: Callable=func() -> bool:
		var fresh_definition: Dictionary=world.auto_hunting_schedule.request_definition(int(definition.schedule_id),int(definition.landing_link_id),int(world.level),int(world.gold))
		var fresh: Dictionary=assess_source_schedule(fresh_definition)
		return fresh==held
	_source_travel_busy=true
	var completed: bool=_commit_source_destination(world,proposed,options,quote.source_cell,catalog,{},-1,payment.changes,guard)
	_source_travel_busy=false
	var result: Dictionary=_last_source_transition.duplicate(true)
	result.merge({"ok":completed,"policy":quote.policy,"reason":"원문 도착 영역으로 이동했습니다 · 자체 착지" if completed else problem},true)
	return result

func source_bookmark_status() -> Dictionary:
	var world: Node=_world()
	if not active or not source_owned or settings.get("navigation_profile")!=OPTIONS.GENERIC or not is_instance_valid(world) or world.field_map!=_source_field:return {"ok":false,"reason":"정확한 현재 원문 지역이 필요합니다."}
	if _source_portal_provider==null or not _source_portal_provider.has_method("bookmark_context_for_land"):return {"ok":false,"reason":"원문 기억 제한 소비자가 필요합니다."}
	var cell: Vector2i=_source_field.world_to_cell(world.player.global_position)+_source_field.coordinates.origin
	var result: Dictionary=_source_portal_provider.call("bookmark_context_for_land",int(settings.native_land_id),str(_source_field.get("source_asset")),cell)
	if result.get("definition_manifest_sha256")!=DEFINITION_PACK_SHA256 or result.get("Land")!=_source_field.get("native_land") or result.get("source_cell")!=[cell.x,cell.y]:return {"ok":false,"reason":"원문 기억 제한의 지역·좌표 신원이 맞지 않습니다."}
	return result

func source_bookmark_destination_status(point: Vector2) -> Dictionary:
	var world: Node=_world()
	if not active or not source_owned or settings.get("navigation_profile")!=OPTIONS.GENERIC or not is_instance_valid(world) or world.field_map!=_source_field or _source_travel_busy:return {"ok":false,"reason":"현재 원문 기억 장소 이동 문맥이 유효하지 않습니다."}
	if not point.is_finite() or not _source_field.point_clear(point,4.0) or not world._teleport_landing_clear(point):return {"ok":false,"reason":"기억한 원문 위치의 통행·점유 검사를 통과하지 못했습니다."}
	var state: Dictionary=_actor_state(world)
	for position: Vector2 in [world.player.global_position,point]:
		var cell: Vector2i=_source_field.world_to_cell(position)+_source_field.coordinates.origin
		var context: Dictionary=_entry_context(int(settings.native_land_id),str(_source_field.get("source_asset")),cell,state)
		if not str(context.get("source_travel_hold","missing")).is_empty():return {"ok":false,"reason":"기억 장소 출발·도착의 원문 지역 조건이 보류됩니다."}
	return {"ok":true,"native_admission_verified":false,"reason":"같은 원문 Land의 기존 기억 이동 소비자 · 자체 통행/입장 정책"}

func _prepare_selected_npc_environment(field: OriginalPlayableField, point: Vector2) -> void:
	# One quote at the committed selected-field boundary, never per actor/frame.
	if field!=_source_field or not active or not source_owned or field.get_meta("current523_generic_field",false)!=true:return
	var world: Node=_world()
	if not is_instance_valid(world) or world.field_map!=field or world.player.global_position!=point:return
	var selection: Dictionary={"ok":false,"reason":"NPC 지역 선택 제공자가 필요합니다."}
	if _source_portal_provider!=null and _source_portal_provider.has_method("npc_environment_selection_for_land"):
		var native_land: Dictionary=field.get("native_land")
		var location: Dictionary=field.call("source_region_context",point,native_land)
		if not location.is_empty():
			var offered: Variant=_source_portal_provider.call("npc_environment_selection_for_land",int(native_land.ID),str(native_land.AssetPath))
			if offered is Dictionary and offered.get("ok")==true and offered.get("schema")=="twilight.map.npc-environment-selection.v1" and offered.get("Land")==native_land and offered.get("land_id")==native_land.ID and offered.get("asset_path")==native_land.AssetPath and offered.get("definition_manifest_sha256")==DEFINITION_PACK_SHA256:
				selection=offered.duplicate(true)
				selection["selected_field_instance"]=field.get_instance_id()
				selection["definition_generation"]=_portal_definition_generation
				selection["source_location"]=location.source_location.duplicate(true)
			else:selection={"ok":false,"reason":"NPC 지역 선택의 원문 신원이 일치하지 않습니다."}
		else:selection={"ok":false,"reason":"NPC 지역 선택의 소스 셀 신원이 필요합니다."}
	# Registration is optional input readiness, never map/spawn/effect permission.
	field.set_meta("current523_npc_environment_selection",selection)
	var admission: Dictionary={"ok":false,"reason":str(selection.get("reason","NPC 지역 선택이 보류됩니다."))}
	if selection.get("ok")==true:admission=_admit_selected_npc_environment(world,field,selection)
	field.set_meta("current523_npc_environment_admission",admission)

func _admit_selected_npc_environment(world: Node, field: OriginalPlayableField, selection: Dictionary) -> Dictionary:
	var service: Variant=world.get("patch523_npc_spells")
	var catalog: Variant=service.get("catalog") if service is Object else null
	if not catalog is Object:return {"ok":false,"reason":"NPC 지역 입력 카탈로그가 필요합니다."}
	for method: String in ["build_land_environment","adopt_land_environment","registered_land_environment"]:
		if not catalog.has_method(method):return {"ok":false,"reason":"PR282의 실제 지역 생산·채택 ABI가 필요합니다."}
	if catalog.get("source_available")!=true or catalog.get("source_mode")!="current523_original":return {"ok":false,"reason":"기존 NPC 원문 입력이 먼저 준비되어야 합니다."}
	var identity: Dictionary=catalog.get("source_identity").duplicate(true)
	var model: String=str(catalog.get("source_model_sha256"))
	var actors: Dictionary=catalog.get("admitted_source_identities").duplicate(true)
	var generation: int=int(world.get("combat_generation"))
	var expected: Dictionary={"land_id":selection.land_id,"asset_path":selection.asset_path,"land_attribute_ids":selection.land_attribute_ids.duplicate()}
	var candidate: Variant=catalog.call("build_land_environment",int(selection.land_id),selection.asset_path,selection.land_attribute_ids.duplicate())
	if not candidate is Dictionary or candidate.is_empty():return {"ok":false,"reason":str(catalog.get("environment_error"))}
	if candidate.get("kind")!="patch523_npc_land_environment_input" or candidate.get("schema")!=1 or candidate.get("input_kind")!="twilight.current523.land-environment-input.v1" or candidate.get("source_snapshot")!="patch523" or candidate.get("source_archive_sha256")!=catalog.SOURCE_SHA or candidate.get("source_archive_identity")!=identity or candidate.get("selection")!=expected or not candidate.get("tables") is Dictionary:return {"ok":false,"reason":"생산된 NPC 지역 입력의 원문 신원이 다릅니다."}
	# Compare the actual producer closure to the selected production map rows.
	if candidate.tables.get("Land",{}).get(str(selection.land_id),{}).get("row")!=selection.Land or candidate.tables.get("LandAttributeType",{}).get("504",{}).get("row")!=selection.type:return {"ok":false,"reason":"NPC 지역 생산 입력과 지도 Land/속성 선언이 다릅니다."}
	if candidate.tables.get("Unit",{}).get("16",{}).get("row",{}).get("Name")!="BuffClassID":return {"ok":false,"reason":"NpcBuff 단위의 원문 참조가 다릅니다."}
	for attribute: Dictionary in selection.attributes:
		if candidate.tables.get("LandAttribute",{}).get(str(attribute.ID),{}).get("row")!=attribute:return {"ok":false,"reason":"NPC 지역 생산 입력의 선택 속성이 다릅니다."}
	for id: int in selection.territories:
		if candidate.tables.get("Territories",{}).get(str(id),{}).get("row")!=selection.territories[id]:return {"ok":false,"reason":"NPC 지역 생산 입력의 원문 영역이 다릅니다."}
	if world.field_map!=field or _source_field!=field or _portal_definition_generation!=selection.definition_generation or catalog.get("source_identity")!=identity:return {"ok":false,"reason":"NPC 지역 생산 중 선택 필드·원문 신원이 바뀌었습니다."}
	var receipt: Variant=catalog.call("adopt_land_environment",candidate)
	if not receipt is Dictionary or receipt.get("ok")!=true:return {"ok":false,"reason":str(receipt.get("reason","NPC 지역 입력 채택 실패")) if receipt is Dictionary else "NPC 지역 입력 채택 응답이 없습니다."}
	if receipt.get("npc_admission_changed")!=false or catalog.get("source_model_sha256")!=model or catalog.get("admitted_source_identities")!=actors or int(world.get("combat_generation"))!=generation:return {"ok":false,"reason":"NPC 지역 채택이 기존 개체 신원을 보존하지 못했습니다."}
	var registered: Variant=catalog.call("registered_land_environment",int(selection.land_id),selection.asset_path)
	if not registered is Dictionary or registered.is_empty():return {"ok":false,"reason":"채택 후 NPC 지역 등록 신원을 읽을 수 없습니다."}
	for key: String in registered:
		if receipt.get(key)!=registered[key]:return {"ok":false,"reason":"채택 결과와 실제 NPC 지역 등록 신원이 다릅니다."}
	if registered.get("kind")!="twilight.current523.registered-land-environment.v1" or registered.get("selection")!=expected or registered.get("land")!=selection.Land or registered.get("source_archive_identity")!=identity or registered.get("npc_model_sha256")!=model:return {"ok":false,"reason":"실제 NPC 지역 등록의 선택·원문 신원이 다릅니다."}
	var input_sha: String=JSON.stringify(candidate,"",true,true).sha256_text()
	var registry_sha: Variant=registered.get("environment_registry_sha256")
	if registered.get("environment_input_sha256")!=input_sha or not registry_sha is String or registry_sha.length()!=64 or not registry_sha.is_valid_hex_number(false) or registry_sha!=catalog.get("environment_model_sha256") or registered.get("environment_revision")!=catalog.get("environment_revision"):return {"ok":false,"reason":"NPC 지역 입력·등록 해시가 유효하지 않습니다."}
	return {"ok":true,"field_instance":field.get_instance_id(),"definition_generation":selection.definition_generation,"receipt":registered.duplicate(true)}

func source_spell_cast_status(spell_id: int) -> Dictionary:
	var world: Node=_world()
	if not active or not source_owned or settings.get("navigation_profile")!=OPTIONS.GENERIC:return {"ok":true,"applicable":false}
	if not is_instance_valid(world) or world.field_map!=_source_field or _source_travel_busy:return {"ok":false,"reason":"현재 원문 시전 지역 문맥이 유효하지 않습니다."}
	if _source_portal_provider==null or not _source_portal_provider.has_method("spell_cast_context_for_land"):return {"ok":false,"reason":"원문 지역 스킬 제한 소비자가 필요합니다."}
	var location: Dictionary=_source_field.death_source_context(world.player.global_position)
	if location.is_empty():return {"ok":false,"reason":"현재 소스 셀의 원문 위치를 확인할 수 없습니다."}
	var xy: Array=location.source_location.source_cell
	var cell:=Vector2i(xy[0],xy[1])
	var result: Dictionary=_source_portal_provider.call("spell_cast_context_for_land",int(settings.native_land_id),str(_source_field.get("source_asset")),cell,spell_id)
	if result.get("ok")!=true:return result
	if result.get("definition_manifest_sha256")!=DEFINITION_PACK_SHA256 or result.get("Land")!=_source_field.get("native_land") or result.get("source_cell")!=xy or result.get("spell_id")!=spell_id:return {"ok":false,"reason":"원문 스킬 제한의 지역·좌표·스킬 신원이 맞지 않습니다."}
	result["applicable"]=true
	return result

func source_hunt_experience_rule() -> Dictionary:
	var world: Node=_world()
	if not active or not source_owned or settings.get("navigation_profile")!=OPTIONS.GENERIC or not is_instance_valid(world) or world.field_map!=_source_field:return {"ok":false}
	# Use the pinned admitted-context snapshot; reward processing does not
	# reopen a pack or turn a transient read error into a new XP decision.
	if _active_entry_context.get("definition_manifest_sha256")!=DEFINITION_PACK_SHA256 or _active_entry_context.get("Land")!=_source_field.get("native_land") or not _active_entry_context.get("non_admission_attributes") is Array:return {"ok":false}
	var applied: Array=[]
	var suppressed: bool=false
	for entry: Dictionary in _active_entry_context.non_admission_attributes:
		if entry.type.get("ID")!=612:continue
		if entry.type.get("Name")!="NoExperience" or entry.type.get("UnitID")!=20 or entry.row.get("LandID")!=int(settings.native_land_id) or entry.row.get("TerritoryID")!=0:return {"ok":false}
		applied.append(entry.duplicate(true))
		if entry.row.Value==1:suppressed=true
	return {"ok":true,"suppress_hunt_experience":suppressed,"rows":applied,"land_id":int(settings.native_land_id),"definition_manifest_sha256":DEFINITION_PACK_SHA256,"consumer_scope":"EXISTING_HUNT_EXPERIENCE_ONLY"}
