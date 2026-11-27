extends RefCounted

## Automatic casts need to know if an eligible actor is nearby. Track the
## active monster root once and update cells on actor movement or reparenting.
## Actual hits still use the live combat query at the attack marker.
const CELL_SIZE := 128.0
const QUERY_LIMIT := 8
const SIGHT_LIMIT := 128
const HITCH := preload("res://scripts/boot/frame_hitch_log.gd")

var _root: Node2D
var _actor_cells: Dictionary = {}
var _pending_moves: Dictionary[TwilightMonster, bool] = {}
var _cells: Dictionary[Vector2i, Dictionary] = {}
var _queries: Dictionary[Rect2i, Array] = {}
var _query_coverage := Rect2i()
var _last_query_area := Rect2i()
var _root_transform := Transform2D.IDENTITY
var _sight_field: int = 0
var _sight_epoch: int = 0
var _sight_combat: int = 0
var _sight_origin := Vector2.INF
var _sight: Dictionary[Vector2, bool] = {}
var _stationary_misses: Dictionary = {}
var _miss_coverage := Rect2i()

func candidates(root: Node2D, bounds: Rect2) -> Array:
	if not is_instance_valid(root): return []
	if root != _root: _watch(root)
	_apply_position_updates()
	if _cells.is_empty(): return []
	# Cell membership is local to the monster parent. Querying in its current
	# transform also covers a translated or scaled parent without reindexing it.
	var transform: Transform2D = root.global_transform
	if transform != _root_transform:
		_root_transform = transform
		_stationary_misses.clear()
	if is_zero_approx(transform.determinant()):
		_last_query_area = Rect2i()
		return _ordered_actors(_actor_cells)
	# Round outward for the coarse query. The caller applies the exact
	# geometry to every candidate it receives.
	var local_bounds: Rect2 = (transform.affine_inverse() * bounds).grow(0.5)
	var first := _cell(local_bounds.position)
	var last := _cell(local_bounds.end)
	var area := Rect2i(first, last - first + Vector2i.ONE)
	_last_query_area = area
	if _queries.has(area): return _queries[area]
	var result: Array = []
	# For a wide skill or a nearly empty field, inspect occupied cells only.
	if int(area.size.x) * int(area.size.y) > _cells.size():
		for cell: Vector2i in _cells:
			if area.has_point(cell): _append_cell(result, cell)
	else:
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				_append_cell(result, Vector2i(x, y))
	result.sort_custom(_scene_order)
	if _queries.size() >= QUERY_LIMIT: _queries.clear()
	_query_coverage = area if _queries.is_empty() else _query_coverage.merge(area)
	_queries[area] = result
	return result

func _append_cell(result: Array, cell: Vector2i) -> void:
	if not _cells.has(cell): return
	for actor: Node2D in _cells[cell]: result.append(actor)

func _ordered_actors(actors: Dictionary) -> Array:
	var result: Array = actors.keys()
	result.sort_custom(_scene_order)
	return result

func _scene_order(a: Node, b: Node) -> bool:
	return a.get_index() < b.get_index()

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))

func _watch(root: Node2D) -> void:
	clear()
	_root = root
	root.child_entered_tree.connect(_enter)
	root.child_exiting_tree.connect(_leave)
	root.child_order_changed.connect(_queries_changed)
	root.tree_exiting.connect(clear)
	HITCH.count("skill.area_index_root_scans")
	for child: Node in root.get_children(): _enter(child)

func _queries_changed() -> void:
	_queries.clear()

func _enter(child: Node) -> void:
	if not child is TwilightMonster: return
	_actor_cells[child] = null
	child.auto_area_tracker = self
	child.set_notify_local_transform(true)
	_update_position(child)

func _leave(child: Node) -> void:
	if not _actor_cells.has(child): return
	var cell: Variant = _actor_cells[child]
	if cell is Vector2i: _invalidate_geometry(cell)
	_remove_cell(child, cell)
	_actor_cells.erase(child)
	_pending_moves.erase(child)
	_stop_tracking(child)

func _stop_tracking(actor: TwilightMonster) -> void:
	if actor.auto_area_tracker != self: return
	actor.auto_area_tracker = null
	actor.set_notify_local_transform(false)

func queue_position_update(actor: TwilightMonster) -> void:
	# Only the first movement between queries needs a notification. The query
	# reads the actor's latest position before consulting any cached geometry.
	actor.set_notify_local_transform(false)
	_pending_moves[actor] = true

func _apply_position_updates() -> void:
	if _pending_moves.is_empty(): return
	HITCH.count("skill.area_index_position_updates", _pending_moves.size())
	for actor: TwilightMonster in _pending_moves:
		_update_position(actor)
		actor.set_notify_local_transform(true)
	_pending_moves.clear()

func _update_position(actor: TwilightMonster) -> void:
	# Exact geometry can change inside a cell without changing its roster.
	var before: Variant = _actor_cells[actor]
	if before is Vector2i: _invalidate_geometry(before)
	var point: Vector2 = actor.position
	if not point.is_finite():
		_remove_cell(actor, before)
		_actor_cells[actor] = null
		return
	var cell := _cell(point)
	if before == cell: return
	_invalidate_geometry(cell)
	_remove_cell(actor, before)
	var occupants: Dictionary = _cells.get_or_add(cell, {})
	occupants[actor] = true
	_actor_cells[actor] = cell
	if not _queries.is_empty() and _query_coverage.has_point(cell): _queries.clear()

func _invalidate_geometry(cell: Vector2i) -> void:
	if not _stationary_misses.is_empty() and _miss_coverage.has_point(cell): _stationary_misses.clear()

func _remove_cell(actor: Node, cell: Variant) -> void:
	if not cell is Vector2i or not _cells.has(cell): return
	var occupants: Dictionary = _cells[cell]
	occupants.erase(actor)
	if occupants.is_empty(): _cells.erase(cell)
	if not _queries.is_empty() and _query_coverage.has_point(cell): _queries.clear()

func prepare_sight(world: Node, origin: Vector2) -> void:
	# Only the same verified, immutable 523 terrain can share exact endpoints.
	# Live doors, local grids and other navigation keep their ordinary checks.
	var epoch: int = int(world._static_auto_route_epoch()) if world.has_method("_static_auto_route_epoch") else 0
	var field_id: int = world.field_map.get_instance_id() if epoch != 0 else 0
	var combat: int = int(world.combat_generation) if epoch != 0 else 0
	if epoch != _sight_epoch or field_id != _sight_field or combat != _sight_combat or origin != _sight_origin:
		_sight.clear()
		_stationary_misses.clear()
		_sight_epoch = epoch
		_sight_field = field_id
		_sight_combat = combat
		_sight_origin = origin

func can_remember_geometry() -> bool:
	return _sight_epoch != 0 and _last_query_area.has_area()

func geometry_missed(key: Array) -> bool:
	return _stationary_misses.has(key)

func remember_geometry_miss(key: Array) -> void:
	if _stationary_misses.size() >= QUERY_LIMIT: _stationary_misses.clear()
	_miss_coverage = _last_query_area if _stationary_misses.is_empty() else _miss_coverage.merge(_last_query_area)
	_stationary_misses[key] = true

func visible_to(world: Node, point: Vector2) -> bool:
	if _sight_epoch != 0 and _sight.has(point): return _sight[point]
	var visible: bool = world._has_line_of_sight_world(_sight_origin, point)
	if _sight_epoch != 0 and _sight.size() < SIGHT_LIMIT: _sight[point] = visible
	return visible

func clear() -> void:
	if is_instance_valid(_root):
		_root.child_entered_tree.disconnect(_enter)
		_root.child_exiting_tree.disconnect(_leave)
		_root.child_order_changed.disconnect(_queries_changed)
		_root.tree_exiting.disconnect(clear)
	_root = null
	for actor: Node in _actor_cells:
		if is_instance_valid(actor): _stop_tracking(actor)
	_actor_cells.clear()
	_pending_moves.clear()
	_cells.clear()
	_queries.clear()
	_sight.clear()
	_stationary_misses.clear()
	_sight_epoch = 0
