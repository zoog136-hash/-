extends Node2D
class_name TwilightCombatFlights

## Flight lifetime is independent of the visual budget. Never drop a damage callback
## because the screen is busy. Weak targets cannot hit a newly selected enemy.
var flights: Array[Dictionary] = []
var available: Array[Dictionary] = []
var generation: int = 0
const MAX_POOL: int = 128
var resolved_count: int = 0
var visual_limit: int = 64

func _ready() -> void:
	set_physics_process(false)

func launch(origin: Vector2, target: Node2D, kind: String, impact: Callable, speed: float = 1100.0, delay: float = 0.0, options: Dictionary = {}) -> void:
	if not is_instance_valid(target): return
	var record: Dictionary = available.pop_back() if not available.is_empty() else {}
	record.merge({"position":origin, "previous":origin, "target":weakref(target), "kind":kind,
		"callback":impact, "speed":speed, "age":-maxf(0.0, delay)})
	record.merge(options,true)
	flights.append(record)
	set_physics_process(true)

func _retire(index: int) -> Callable:
	var flight: Dictionary = flights[index]
	var callback: Callable = flight.callback
	flights.remove_at(index)
	flight.clear()
	if available.size() < MAX_POOL: available.append(flight)
	return callback

func clear() -> void:
	generation += 1
	for i: int in range(flights.size() - 1, -1, -1): _retire(i)
	set_physics_process(false)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var batch_generation: int = generation
	for i: int in range(flights.size() - 1, -1, -1):
		if batch_generation != generation: break
		if i >= flights.size(): continue
		var flight: Dictionary = flights[i]
		var target: Node2D = flight.target.get_ref() as Node2D
		if not is_instance_valid(target) or not target.is_inside_tree() or (target is TwilightMonster and target.dead):
			_retire(i)
			continue
		flight.age += delta
		if flight.age < 0.0: continue
		if flight.kind == "timed":
			var timed_callback: Callable = _retire(i)
			if timed_callback.is_valid(): timed_callback.call()
			continue
		if flight.age > 3.0:
			_retire(i)
			continue
		var end: Vector2 = target.combat_hit_position() if target.has_method("combat_hit_position") else target.global_position + Vector2(0, -24)
		if flight.has("aim"): end = flight.aim
		flight.previous = flight.position
		flight.position = (flight.position as Vector2).move_toward(end, float(flight.speed) * delta)
		var obstruction: Callable = flight.get("obstruction",Callable())
		if obstruction.is_valid() and not obstruction.call(flight.previous,flight.position):
			_retire(i)
			continue
		if (flight.position as Vector2).distance_squared_to(end) <= 0.25:
			if flight.has("aim") and end.distance_to(target.combat_hit_position())>float(flight.get("hit_radius",28.)):
				_retire(i)
				continue
			var callback: Callable = _retire(i)
			resolved_count += 1
			if callback.is_valid(): callback.call()
	queue_redraw()
	if flights.is_empty(): set_physics_process(false)

func _draw() -> void:
	for i: int in range(mini(visual_limit, flights.size())):
		var flight: Dictionary = flights[i]
		if flight.age < 0.0 or flight.kind == "timed": continue
		var tip: Vector2 = to_local(flight.position)
		var direction: Vector2 = (flight.position as Vector2) - (flight.previous as Vector2)
		direction = direction.normalized()
		var color: Color = flight.get("color",Color(0.5, 0.75, 1.0) if flight.kind == "magic" else Color(1.0, 0.85, 0.5))
		draw_line(tip - direction * 18.0, tip, color, 2.0, true)
		if flight.kind == "magic": draw_circle(tip, 3.5, color)
		else:
			draw_line(tip, tip - direction.rotated(0.5) * 6.0, color, 1.5, true)
			draw_line(tip, tip - direction.rotated(-0.5) * 6.0, color, 1.5, true)
