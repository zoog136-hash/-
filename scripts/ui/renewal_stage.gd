extends Control

# Static, original engraved geometry; no timer, shader or gameplay work.
var accent: Color = Color("b99a63")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var center := Vector2(size.x*.5,size.y*.60)
	var radius: float = minf(size.x*.42,size.y*.52)
	draw_rect(Rect2(Vector2.ZERO,size),Color("0a0d12"))
	for step: int in range(18,0,-1):
		var t: float = float(step)/18.0
		draw_circle(center,radius*t,Color(accent,.012*(1.0-t)))
	for r: float in [.72,.90,1.0]:
		draw_arc(center,radius*r,0,TAU,72,Color(accent,.14),1,true)
	for i: int in range(12):
		var axis := Vector2.from_angle(TAU*float(i)/12.0)
		draw_line(center+axis*radius*.91,center+axis*radius*.98,Color(accent,.28),1,true)
	draw_line(Vector2(12,12),Vector2(size.x-12,12),Color(accent,.22),1)
	draw_line(Vector2(12,size.y-12),Vector2(size.x-12,size.y-12),Color(accent,.22),1)
