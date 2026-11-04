extends Node2D
## TWILIGHT geometry indicator; never presented as an original M effect.
var radius: float = 96
var box: bool = true
var warning: bool = true
func contains_world(point: Vector2) -> bool:
	var local: Vector2 = to_local(point)
	return Rect2(Vector2(-radius,-radius),Vector2.ONE*radius*2).has_point(local) if box else local.length_squared() <= radius*radius
func _draw() -> void:
	var color := Color(.95,.64,.12,.2) if warning else Color(.95,.18,.12,.25)
	if box:
		draw_rect(Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2),color)
		draw_rect(Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2),Color(color,.9),false,2)
	else:
		draw_circle(Vector2.ZERO,radius,color)
		draw_arc(Vector2.ZERO,radius,0,TAU,48,Color(color,.9),2)
	draw_string(ThemeDB.fallback_font,Vector2(-radius,0),"TWILIGHT 예고" if warning else "TWILIGHT 지속효과",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
