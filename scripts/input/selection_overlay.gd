extends Control
var selection_rect: Rect2
var active: bool = false
func _draw() -> void:
	if active:
		draw_rect(selection_rect,Color(0.9,0.78,0.5,0.12),true)
		draw_rect(selection_rect,Color(0.95,0.84,0.56,0.95),false,2.0)
