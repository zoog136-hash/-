extends Node2D
class_name TwilightCombatFlights

## Flight lifetime is independent of the visual budget. Never drop a damage callback
## because the screen is busy. Weak targets cannot hit a newly selected enemy.
var flights: Array[Dictionary] = []
var resolved_count: int = 0
var visual_limit: int = 64

func launch(origin: Vector2, target: Node2D, kind: String, impact: Callable, speed: float = 1100.0) -> void:
	if not is_instance_valid(target): return
	flights.append({"position":origin, "previous":origin, "target":weakref(target), "kind":kind,
		"callback":impact, "speed":speed, "age":0.0})

func clear() -> void:
	flights.clear()
	queue_redraw()

func _physics_process(delta: float) -> void:
	for i: int in range(flights.size() - 1, -1, -1):
		var flight: Dictionary = flights[i]
		var target: Node2D = flight.target.get_ref() as Node2D
		if not is_instance_valid(target) or not target.is_inside_tree() or (target is TwilightMonster and target.dead):
			flights.remove_at(i)
			continue
		flight.age += delta
		if flight.age > 3.0:
			flights.remove_at(i)
			continue
		var end: Vector2 = target.combat_hit_position() if target.has_method("combat_hit_position") else target.global_position + Vector2(0, -24)
		flight.previous = flight.position
		flight.position = (flight.position as Vector2).move_toward(end, float(flight.speed) * delta)
		if (flight.position as Vector2).distance_squared_to(end) <= 0.25:
			flights.remove_at(i) # retire before calling potentially reentrant combat code
			resolved_count += 1
			var callback: Callable = flight.callback
			if callback.is_valid(): callback.call()
	if not flights.is_empty(): queue_redraw()
	elif resolved_count > 0: queue_redraw()

func _draw() -> void:
	for i: int in range(mini(visual_limit, flights.size())):
		var flight: Dictionary = flights[i]
		var tip: Vector2 = to_local(flight.position)
		var direction: Vector2 = (flight.position as Vector2) - (flight.previous as Vector2)
		direction = direction.normalized()
		var color: Color = Color(0.5, 0.75, 1.0) if flight.kind == "magic" else Color(1.0, 0.85, 0.5)
		draw_line(tip - direction * 18.0, tip, color, 2.0, true)
		if flight.kind == "magic": draw_circle(tip, 3.5, color)
		else:
			draw_line(tip, tip - direction.rotated(0.5) * 6.0, color, 1.5, true)
			draw_line(tip, tip - direction.rotated(-0.5) * 6.0, color, 1.5, true)
