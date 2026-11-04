extends RefCounted
## One-shot host maintenance at an existing, verified local portal.
## Native M schedule/arrival conditions are not inferred by this adapter.
const DAY = preload("res://scripts/quests/quest_service.gd")
var internal_mode_change: bool = false
var reconnect_wait: bool = false
var next_automatic_check_ms: int = 0
var owner_reference: WeakRef
var owner:
	get: return owner_reference.get_ref() if owner_reference != null else null
var world: Node
var paused: bool = false
var status: String = ""
var deadline_ms: int = 0
var walking_target: Vector2 = Vector2.INF
var test_unix_time: Callable

func configure(service) -> void:
	owner_reference = weakref(service)
	world = service.world

static func valid(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if raw.is_empty(): return true
	for key: String in ["armed","deposit","sell"]:
		if not raw.get(key) is bool: return false
	for key: String in ["map_id","portal_id","rules_sha"]:
		if not raw.get(key) is String: return false
	for key: String in ["revision","run_id","completed_run_id","armed_unix","completed_unix","timeout_seconds"]:
		var value: Variant = raw.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or value < 0 or value > 9007199254740991.0: return false
	if not valid_automatic(raw.get("automatic",{})): return false
	if raw.run_id < raw.completed_run_id or raw.timeout_seconds < 1 or raw.timeout_seconds > 600: return false
	if raw.armed and (raw.run_id <= raw.completed_run_id or raw.map_id.is_empty() or raw.portal_id.is_empty() or not (raw.deposit or raw.sell)): return false
	return true

static func valid_automatic(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if raw.is_empty(): return true
	if raw.get("mode") != "twilight_existing_auto_day_once_v1": return false
	if not raw.get("enabled") is bool or not raw.get("resume_auto") is bool or not raw.get("scope") is String or raw.scope.length() != 64 or not raw.scope.is_valid_hex_number(): return false
	for key: String in ["configured_day","last_started_day","last_completed_day","run_day"]:
		var value: Variant = raw.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(float(value)) or value < (-1 if key != "configured_day" else 0) or value > 9007199254740991.0: return false
	return raw.last_completed_day <= raw.last_started_day

func _scope(state: Dictionary) -> String:
	return JSON.stringify(owner._canonical([state.get("deposit",[]),state.get("sell",[]),state.get("source_only",false),state.get("native_prices",{}),owner.source_rules.fingerprint()])).sha256_text()

func mode_changed(enabled: bool) -> void:
	if internal_mode_change: return
	next_automatic_check_ms = 0
	if settings().armed:
		_pause("AUTO 모드를 직접 변경해 정비를 중지했습니다. 다시 확인해주세요")
	elif enabled:
		reconnect_wait = false
		paused = false

func _set_auto(enabled: bool) -> void:
	internal_mode_change = true
	world.player.set_auto_enabled(enabled)
	internal_mode_change = false

func automatic_enabled() -> bool:
	return bool(settings().get("automatic",{}).get("enabled",false))

func try_automatic() -> bool:
	var local: Dictionary = settings()
	if local.armed: return not paused
	var automatic: Dictionary = local.get("automatic",{})
	if not automatic.get("enabled",false) or paused or reconnect_wait or owner.busy or not world.player.auto_enabled: return false
	if Time.get_ticks_msec() < next_automatic_check_ms: return false
	next_automatic_check_ms = Time.get_ticks_msec()+500
	var now: int = _now()
	var today: int = DAY.korean_daily_key(now)
	if today <= int(automatic.last_started_day): return false
	if now < int(local.completed_unix) or now < int(local.armed_unix) or today < int(automatic.configured_day): _pause("시계 역행으로 자동 정비를 중지했습니다"); return false
	if str(world.active_map_id) != str(local.map_id) or automatic.scope != _scope(owner.state) or local.rules_sha != owner.source_rules.fingerprint(): _pause("자동 정비의 맵·대상·규칙이 변경됐습니다. 다시 확인해주세요"); return false
	var contract: Dictionary = _portal_contract(_find_portal(str(local.portal_id)))
	if not contract.get("ok",false) or int(contract.get("revision",-1)) != int(local.revision): _pause("자동 정비 이동진·지도 계약이 변경됐습니다. 다시 확인해주세요"); return false
	if world.player.has_manual_movement() or world.hp <= 0 or world.player.is_stunned() or world.player.is_feared() or world.player.is_held(): return false
	if world.get("hud") != null and world.hud.has_method("blocks_keyboard_input") and world.hud.blocks_keyboard_input(): return false
	var plan: Dictionary = preview(bool(local.deposit),bool(local.sell))
	if not plan.get("ok",false): _pause(str(plan.get("reason","자동 정비 확인 필요"))); return false
	if plan.cart.is_empty(): return false
	var result: Dictionary = arm(str(local.portal_id),bool(local.deposit),bool(local.sell),int(local.timeout_seconds),true,{"run":true})
	if not result.get("ok",false): _pause(str(result.get("reason","자동 정비 시작 실패"))); return false
	return true

func disable_automatic() -> Dictionary:
	var next: Dictionary = owner.state.duplicate(true)
	var local: Dictionary = settings()
	if local.has("automatic"): local.automatic["enabled"] = false
	local["armed"] = false
	next["maintenance"] = local
	return owner.save_settings(next)

func fresh() -> Dictionary:
	return {"armed":false,"deposit":true,"sell":true,"map_id":"","portal_id":"","revision":0,"rules_sha":"","run_id":0,"completed_run_id":0,"armed_unix":0,"completed_unix":0,"timeout_seconds":120}

func settings() -> Dictionary:
	return owner.state.get("maintenance",fresh()).duplicate(true)

func _now() -> int:
	return int(test_unix_time.call()) if test_unix_time.is_valid() else int(Time.get_unix_time_from_system())

func on_restore() -> void:
	reset_session()
	reconnect_wait = automatic_enabled()
	if settings().armed:
		paused = true
		status = "저장된 정비는 재시작 후 다시 확인해야 합니다"

func reset_session() -> void:
	_stop_walk()
	deadline_ms = 0
	paused = false
	status = ""
	next_automatic_check_ms = 0

func _stop_walk() -> void:
	# Only stop a route that this controller actually started and still owns.
	if walking_target.is_finite() and is_instance_valid(world) and is_instance_valid(world.get("player")):
		var path: PackedVector2Array = world.player.click_path
		if not path.is_empty() and path[path.size()-1].distance_to(walking_target) <= 6.0:
			world.player.clear_click_path()
			world.player.velocity = Vector2.ZERO
	walking_target = Vector2.INF

func _pause(message: String) -> void:
	if paused: return
	paused = true
	status = message
	_stop_walk()
	if world.get("hud") != null: world.hud.show_message(message)

func tick() -> void:
	var local: Dictionary = owner.state.get("maintenance",{})
	if not local.get("armed",false) or paused: return
	if deadline_ms > 0 and Time.get_ticks_msec() > deadline_ms: _pause("자체 대기 시간이 지나 정비를 중지했습니다")
	elif _now() < int(local.armed_unix): _pause("시계가 뒤로 변경되어 정비를 중지했습니다")

func portals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world.get("field_map") == null: return result
	for portal: Dictionary in world.field_map.data.get("portal",[]):
		if _portal_contract(portal).get("ok",false): result.append(portal.duplicate(true))
	return result

func _portal_contract(portal: Dictionary) -> Dictionary:
	var field = world.get("field_map")
	if field == null or not bool(field.get_meta("source_map84",false)): return _fail("현재 지도에 검증된 로컬 이동진이 없습니다")
	if portal.has("target_source") or str(portal.get("target_map","")) != str(world.active_map_id): return _fail("이동 좌표가 확인된 같은 맵 이동진만 지원합니다")
	var revision: int = int(field.data.get("layout_revision",0))
	if int(portal.get("target_layout_revision",-1)) != revision: return _fail("이동진의 지도 버전이 다릅니다")
	for key: String in ["position","target_position"]:
		var raw: Variant = portal.get(key)
		if not raw is Array or raw.size() != 2: return _fail("이동진 위치가 확인되지 않았습니다")
		for value: Variant in raw:
			if not (value is int or value is float) or not is_finite(float(value)): return _fail("이동진 좌표가 유효하지 않습니다")
		var point := Vector2(float(raw[0]),float(raw[1]))
		if not field.point_clear(point,4.0): return _fail("이동진 바닥·충돌 확인이 필요합니다")
	var radius: float = float(portal.get("radius",0))
	if not is_finite(radius) or radius <= 0: return _fail("이동진 진입 범위를 확인할 수 없습니다")
	if world.level < int(portal.get("min_level",0)) or (int(portal.get("max_level",0)) > 0 and world.level > int(portal.max_level)): return _fail("이동진 입장 레벨이 맞지 않습니다")
	return {"ok":true,"revision":revision,"position":Vector2(portal.position[0],portal.position[1]),"target":Vector2(portal.target_position[0],portal.target_position[1]),"radius":radius}

func _find_portal(id: String) -> Dictionary:
	if world.get("field_map") == null: return {}
	for portal: Dictionary in world.field_map.data.get("portal",[]):
		if str(portal.get("id","")) == id: return portal
	return {}

func safe_walk(path: PackedVector2Array, target_id: String) -> bool:
	# Reuse the authoritative path, but never walk through another active gate
	# merely because its floor is traversable. Do not invent an alternate route.
	for portal: Dictionary in world.field_map.data.get("portal",[]):
		if str(portal.get("id","")) == target_id: continue
		var raw: Variant = portal.get("position",[])
		if not raw is Array or raw.size() != 2: continue
		var point := Vector2(float(raw[0]),float(raw[1]))
		var radius: float = float(portal.get("radius",0))
		if not point.is_finite() or not is_finite(radius) or radius <= 0: continue
		# SourceField's direct routes contain only the destination, so the first
		# segment must start at the player rather than at path[0].
		var previous: Vector2 = world.player.global_position
		for waypoint: Vector2 in path:
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,previous,waypoint)) < radius+4.0: return false
			previous = waypoint
	return true

func preview(do_store: bool, do_sell: bool) -> Dictionary:
	if not do_store and not do_sell: return _fail("보관 또는 판매를 선택해 주세요")
	var base: Dictionary = {}
	var cart: Array = []
	var skipped: Array = []
	var payment: int = 0
	for mode: String in ["deposit","sell"]:
		if (mode == "deposit" and not do_store) or (mode == "sell" and not do_sell): continue
		var plan: Dictionary = owner.preview(mode,base)
		if not plan.get("ok",false): return plan
		base = plan.override
		cart.append_array(plan.cart)
		skipped.append_array(plan.skipped)
		payment += int(plan.payment)
	return {"ok":true,"cart":cart,"skipped":skipped,"payment":payment,"override":base,"stamp":owner._stamp("maintenance")}

func arm(portal_id: String, do_store: bool, do_sell: bool, timeout_seconds: int, walk: bool = true, automatic_options: Dictionary = {}) -> Dictionary:
	if owner.busy or timeout_seconds < 1 or timeout_seconds > 600: return _fail("정비 설정이 유효하지 않습니다")
	var old: Dictionary = settings()
	var now: int = _now()
	if now < int(old.completed_unix) or now < int(old.armed_unix): return _fail("시계 역행 확인 후 다시 설정해 주세요")
	var portal: Dictionary = _find_portal(portal_id)
	var contract: Dictionary = _portal_contract(portal)
	if not contract.get("ok",false): return contract
	if world.hp <= 0 or world.player.is_stunned() or world.player.is_feared() or world.player.is_held(): return _fail("이동 불가 상태에서는 정비 이동을 시작할 수 없습니다")
	var position: Vector2 = contract.position
	if world.player.global_position.distance_to(position) > float(contract.radius):
		var path: PackedVector2Array = world.find_world_path(world.player.global_position,position)
		if path.is_empty() or path[path.size()-1].distance_to(position) > 6.0: return _fail("현재 위치에서 이동진까지의 경로가 없습니다")
		if not safe_walk(path,portal_id): return _fail("다른 이동진을 지나는 경로입니다. 먼저 가까운 안전 지점으로 이동해주세요")
	var plan: Dictionary = preview(do_store,do_sell)
	if not plan.get("ok",false): return plan
	var next: Dictionary = owner.state.duplicate(true)
	var order: Dictionary = old.duplicate(true)
	order.merge({"armed":true,"deposit":do_store,"sell":do_sell,"map_id":str(world.active_map_id),"portal_id":portal_id,"revision":int(contract.revision),"rules_sha":owner.source_rules.fingerprint(),"run_id":int(old.run_id)+1,"completed_run_id":int(old.completed_run_id),"armed_unix":now,"completed_unix":int(old.completed_unix),"timeout_seconds":timeout_seconds},true)
	next["maintenance"] = order
	var previous: Dictionary = old.get("automatic",{})
	var today: int = DAY.korean_daily_key(now)
	var automatic: Dictionary = previous.duplicate(true)
	automatic.merge({"mode":"twilight_existing_auto_day_once_v1","enabled":false,"resume_auto":false,"scope":_scope(owner.state),"configured_day":today,"last_started_day":int(previous.get("last_started_day",-1)),"last_completed_day":int(previous.get("last_completed_day",-1)),"run_day":-1},true)
	var setup: bool = automatic_options.get("setup",false)
	if setup:
		automatic["enabled"] = true
		automatic["resume_auto"] = bool(automatic_options.get("resume_auto",false))
		next.maintenance["armed"] = false
	elif automatic_options.get("run",false):
		if not previous.get("enabled",false) or today <= int(previous.last_started_day) or previous.scope != _scope(owner.state): return _fail("오늘 실행했거나 자동 정비 조건이 변경됐습니다")
		automatic = previous.duplicate(true)
		automatic["last_started_day"] = today
		automatic["run_day"] = today
	next.maintenance["automatic"] = automatic
	var saved: Dictionary = owner.save_settings(next,true)
	if not saved.get("ok",false): return saved
	reset_session()
	reconnect_wait = false
	if setup:
		status = "AUTO 중 게임 날짜당 1회 자동 정비 대기 · 이동 비용0"
		return {"ok":true}
	deadline_ms = Time.get_ticks_msec()+timeout_seconds*1000
	status = "이동진 진입 전 한 번 정비 대기"
	if automatic_options.get("run",false): _set_auto(false)
	if walk and world.player.global_position.distance_to(position) >= float(contract.radius):
		walking_target = position
		_set_auto(false)
		world._set_click_destination(position)
		if world.player.click_path.is_empty():
			_pause("이동 경로 준비가 중지됐습니다. 다시 확인해 주세요")
			return _fail(status)
	return {"ok":true}

func cancel() -> Dictionary:
	var next: Dictionary = owner.state.duplicate(true)
	var local: Dictionary = settings()
	local["armed"] = false
	next["maintenance"] = local
	return owner.save_settings(next)

func before_portal(portal_id: String) -> Dictionary:
	var local: Dictionary = settings()
	if not local.armed: return {"ok":true,"performed":false}
	if str(world.active_map_id) != str(local.map_id) or portal_id != str(local.portal_id):
		_pause("다른 이동을 선택해 정비를 일시 중지했습니다")
		return {"ok":true,"performed":false}
	tick()
	if paused: return _fail(status)
	if int(local.run_id) <= int(local.completed_run_id) or local.rules_sha != owner.source_rules.fingerprint(): return _fail("정비 설정·규칙이 바뀌었습니다. 다시 확인해 주세요")
	var contract: Dictionary = _portal_contract(_find_portal(portal_id))
	if not contract.get("ok",false) or int(contract.get("revision",-1)) != int(local.revision): return _fail("지도·이동진 버전이 변경되었습니다")
	if world.player.global_position.distance_to(contract.position) >= float(contract.radius): return _fail("이동진에 도착한 뒤 정비할 수 있습니다")
	if world.hp <= 0 or world.player.is_stunned() or world.player.is_feared() or world.player.is_held(): return _fail("이동 불가 상태에서는 정비할 수 없습니다")
	var plan: Dictionary = preview(bool(local.deposit),bool(local.sell))
	if not plan.get("ok",false):
		_pause(str(plan.get("reason","정비할 수 없습니다")))
		return plan
	if plan.stamp != owner._stamp("maintenance"): return _fail("정비 소지품이 변경되었습니다")
	local["armed"] = false
	local["completed_run_id"] = int(local.run_id)
	local["completed_unix"] = _now()
	var automatic: Dictionary = local.get("automatic",{})
	var resume: bool = automatic.get("enabled",false) and int(automatic.get("run_day",-1)) >= 0 and automatic.get("resume_auto",false)
	if not automatic.is_empty() and int(automatic.run_day) >= 0:
		automatic["last_completed_day"] = int(automatic.run_day)
		automatic["scope"] = _scope(plan.override[owner.KEY])
		automatic["run_day"] = -1
		local["automatic"] = automatic
	plan.override[owner.KEY]["maintenance"] = local
	var result: Dictionary = owner.commit_plan(plan)
	if not result.get("ok",false):
		_pause(str(result.get("reason","정비 저장 실패")))
		return result
	reset_session()
	status = "정비 완료 · 이동진 이용"
	return {"ok":true,"performed":true,"resume_auto":resume}

func after_portal(result: Dictionary) -> void:
	if result.get("performed",false) and result.get("resume_auto",false) and world.hp > 0 and not world.player.is_stunned() and not world.player.is_feared() and not world.player.is_held(): _set_auto(true)

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}
