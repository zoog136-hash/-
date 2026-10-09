extends Control

# Native vector ornament. No raster generation, uploads or per-frame work.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var bronze := Color("8f744d")
	var gold := Color("d0ac6d")
	draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color(bronze,.5),false,1)
	draw_line(Vector2(22,5),Vector2(size.x-22,5),Color(gold,.35),1)
	for x: float in [8.0,size.x-8.0]:
		for y: float in [8.0,size.y-8.0]:
			var sx: float = 1 if x < size.x*.5 else -1
			var sy: float = 1 if y < size.y*.5 else -1
			draw_line(Vector2(x,y),Vector2(x+sx*17,y),gold,2)
			draw_line(Vector2(x,y),Vector2(x,y+sy*17),bronze,2)
			draw_colored_polygon(PackedVector2Array([Vector2(x,y-3),Vector2(x+3,y),Vector2(x,y+3),Vector2(x-3,y)]),gold)
