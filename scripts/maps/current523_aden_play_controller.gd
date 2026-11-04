extends RefCounted
## Changes presentation only. Existing field/navigation/body/combat stay owned by Main.
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
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

func configure(world: Node) -> void:
	_world_ref = weakref(world)

func _world() -> Node:
	return _world_ref.get_ref() as Node if _world_ref != null else null

func open(value: Dictionary) -> bool:
	problem = ""
	if active: problem = "아덴 실험 플레이가 이미 실행 중입니다."; return false
	var world: Node = _world()
	if value.get("navigation_profile") == OPTIONS.SOURCE: return _open_source(value)
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
	if source_owned: return _close_source(remember_disabled)
	var saved: bool = true
	if remember_disabled:
		var options: Dictionary = OPTIONS.read()
		options.enabled = false
		saved = OPTIONS.write(options) == OK
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
	if source_owned and (options.allowed_raw_words != settings.allowed_raw_words or options.portal_contract != settings.portal_contract):
		problem = "통행 해석과 포탈 팩을 바꾸려면 원문 플레이를 종료해 주세요."; return false
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

func metrics() -> Dictionary:
	return _renderer.call("frame_metrics") if active and is_instance_valid(_renderer) else {}

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
	if source_owned: label.text = "아덴 523 원문 플레이\nS32 속성 기반 자체 통행 · M 원작 판정 미확정"
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
	var script: Script = load("res://scripts/maps/current523_aden_source_field.gd")
	var proposed: OriginalPlayableField = script.new()
	if not proposed.call("configure_current523", options.raw_root, {"allowed_raw_words":options.allowed_raw_words}):
		problem = str(proposed.get("problem")); proposed.close(); return false
	var source_position: Array = options.source_position
	if source_position.is_empty(): source_position = prior_field.coordinates.source_components(world.player.global_position)
	var position: Vector2 = proposed.coordinates.components_to_world(source_position)
	if not proposed.point_clear(position,4):
		problem = "선택한 원문 위치는 자체 통행에서 거부됩니다. 원본 좌표를 임의로 바꾸지 않았습니다."; proposed.close(); return false
	proposed.data.spawn_position = [position.x,position.y]
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
	var valid: bool = candidate.try_configure(proposed,world.player,options.raw_root,options.tile_root,Vector2(options.offset_x,options.offset_y))
	world.player.global_position = actor_position
	camera.limit_left = old_camera.left; camera.limit_top = old_camera.top; camera.limit_right = old_camera.right; camera.limit_bottom = old_camera.bottom
	camera.reset_smoothing(); camera.force_update_scroll()
	if not valid:
		problem = candidate.problem; candidate.queue_free(); proposed.close(); return false
	options.source_position = source_position
	if OPTIONS.write(options) != OK:
		problem = "원문 플레이 설정을 저장하지 못했습니다."; candidate.queue_free(); proposed.close(); return false
	_prior = prior_renderer; _prior_visible = _prior.visible; _prior_mode = _prior.process_mode
	_prior_world = {"field":prior_field,"physics":world.field_physics,"position":actor_position,"world_size":world.world_size,"astar":world.astar,"camera":old_camera,"physics_layer":world.field_physics.collision_layer if is_instance_valid(world.field_physics) else 0,"physics_mode":world.field_physics.process_mode if is_instance_valid(world.field_physics) else Node.PROCESS_MODE_INHERIT}
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
	_build_notice(world)
	_load_portals()
	return true

func _close_source(remember_disabled: bool) -> bool:
	var world: Node = _world()
	var saved: bool = true
	if remember_disabled:
		var options: Dictionary = _source_checkpoint()
		options.enabled = false
		saved = OPTIONS.write(options) == OK
	if is_instance_valid(_renderer):
		_renderer.hide(); _renderer.process_mode = Node.PROCESS_MODE_DISABLED; _renderer.queue_free()
	if is_instance_valid(_source_physics):
		_source_physics.collision_layer = 0; _source_physics.queue_free()
	if is_instance_valid(world) and not _prior_world.is_empty():
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
	if _source_field != null: _source_field.close()
	if is_instance_valid(_notice): _notice.queue_free()
	_renderer = null; _source_physics = null; _source_field = null; _prior = null; _notice = null; _portals = null
	_prior_world.clear(); _paused_nodes.clear()
	source_owned = false; active = false
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
	# Never report an already committed item transaction as failed: callers could refund twice.
	return result

func _load_portals() -> void:
	if settings.portal_contract.is_empty(): return
	var script: Script = load("res://scripts/maps/current523_aden_source_portals.gd")
	if script == null: return
	var catalog: RefCounted = script.new()
	if catalog.call("load_contract",settings.portal_contract): _portals = catalog
	else: problem = str(catalog.get("problem"))

func portal_evidence() -> Array:
	return _portals.call("portal_evidence") if source_owned and _portals != null else []

func portal_context(id: int) -> Dictionary:
	return _portals.call("portal_context",id) if source_owned and _portals != null else {}

func use_source_portal(id: int) -> bool:
	var world: Node = _world()
	problem = ""
	if not source_owned or not active or _portals == null:
		problem = "검증된 원문 포탈 팩이 없습니다."; return false
	if world.player.auto_enabled or world.player.is_stunned() or world.player.is_held() or not world.charge_skill.is_empty():
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
	world.player.global_position = _source_field.coordinates.to_world(Vector2(destination))
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	_renderer.refresh_visible()
	if not str(_renderer.get("problem")).is_empty():
		world.player.global_position = prior_position
		world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
		problem = "포탈 도착 화면을 확인하지 못해 출발 위치를 보존합니다."; return false
	world.player.clear_click_path(); world.player.velocity = Vector2.ZERO; world.player.set_touch_vector(Vector2.ZERO)
	world.portal_cooldown = 2.0
	return true
