extends RefCounted

## A miss on verified static terrain can be reused while its geometry and
## actor positions stay the same. Actor eligibility is checked by the caller.
const MAX_MISSES := 8

var _root: Node2D
var _context: Array = []
var _misses: Dictionary = {}
var _coverage := Rect2()

func prepare(world: Node, origin: Vector2) -> bool:
	var epoch: int = world._static_auto_route_epoch() if world.has_method("_static_auto_route_epoch") else 0
	if epoch == 0 or not origin.is_finite():
		if is_instance_valid(_root): clear()
		return false
	var root: Node2D = world.monsters_root
	if is_instance_valid(_root) and _root != root: clear()
	var context: Array = [root.get_instance_id(), world.field_map.get_instance_id(), epoch,
		world.combat_generation, origin, root.global_transform]
	if context != _context:
		_context = context
		_misses.clear()
	return true

func has_miss(geometry: Array) -> bool:
	return _misses.has(geometry)

func remember(root: Node2D, actors: Array[Node], geometry: Array, bounds: Rect2) -> void:
	if not is_instance_valid(_root):
		_root = root
		root.child_entered_tree.connect(_watch_actor)
		root.child_exiting_tree.connect(_unwatch_actor)
		root.tree_exiting.connect(clear)
		for child: Node in actors: _watch_actor(child)
	if _misses.size() >= MAX_MISSES: _misses.clear()
	_coverage = bounds if _misses.is_empty() else _coverage.merge(bounds)
	_misses[geometry] = true

func clear_if_unused() -> void:
	if _misses.is_empty() and is_instance_valid(_root): clear()

func _watch_actor(child: Node) -> void:
	if not child is TwilightMonster: return
	child.auto_area_miss_observer = self
	child.set_notify_local_transform(true)
	actor_moved(child)

func _unwatch_actor(child: Node) -> void:
	if not child is TwilightMonster or child.auto_area_miss_observer != self: return
	child.auto_area_miss_observer = null
	child.set_notify_local_transform(false)

func actor_moved(actor: TwilightMonster) -> void:
	# A departure cannot turn a geometric miss into a hit. A spawn or move
	# into the union of the cached ranges must be tested again next pulse.
	if not _misses.is_empty() and _coverage.has_point(actor.global_position): _misses.clear()

func clear() -> void:
	if is_instance_valid(_root):
		_root.child_entered_tree.disconnect(_watch_actor)
		_root.child_exiting_tree.disconnect(_unwatch_actor)
		_root.tree_exiting.disconnect(clear)
		for child: Node in _root.get_children(): _unwatch_actor(child)
	_root = null
	_context.clear()
	_misses.clear()
