extends Node2D

var radius: Vector2 = Vector2(18, 5)

func _ready() -> void:
	z_index = -1
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, radius.y / maxf(1.0, radius.x)))
	draw_circle(Vector2.ZERO, radius.x, Color(0.025, 0.03, 0.04, 0.3))
