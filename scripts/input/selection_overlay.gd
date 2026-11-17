extends Control
var selection_rect: Rect2
var active: bool = false
func _draw() -> void:
	# Self-drawn TWILIGHT artwork is not shown (user rule 2026-11-17: no
	# self-made images; without an original 523 resource this stays empty).
	return
	if active:
		draw_rect(selection_rect,Color(0.9,0.78,0.5,0.12),true)
		draw_rect(selection_rect,Color(0.95,0.84,0.56,0.95),false,2.0)
