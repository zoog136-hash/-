extends Control

# Lightweight original vector frame. It follows the shared window's full
# rectangle and only redraws after a resize; never steals tap/drag input.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 72.0 or size.y < 62.0:
		return
	var outer := Color("654a2c")
	var gold := Color("d4b47a")
	var shine := Color("f2d9a1")
	var dim := Color("80653f")
	var extent := size - Vector2(5,5)
	for y: int in range(16,70,3):
		var inset: float = 15+float((y*13)%19)
		draw_line(Vector2(inset,y),Vector2(size.x-inset,y),Color(shine,.014 if y%2 == 0 else .008),1)
	draw_rect(Rect2(Vector2(2,2),extent-Vector2(2,2)),Color(outer,.85),false,1)
	draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),Color(gold,.26),false,1)
	draw_line(Vector2(27,6),Vector2(size.x-27,6),Color(shine,.42),1)
	draw_line(Vector2(27,size.y-6),Vector2(size.x-27,size.y-6),Color(outer,.55),1)
	for cx: float in [10.0,size.x-10.0]:
		for cy: float in [10.0,size.y-10.0]:
			var sx: float = 1.0 if cx < size.x * .5 else -1.0
			var sy: float = 1.0 if cy < size.y * .5 else -1.0
			draw_line(Vector2(cx,cy),Vector2(cx+sx*21,cy),gold,2)
			draw_line(Vector2(cx,cy),Vector2(cx,cy+sy*19),dim,2)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx,cy-4),Vector2(cx+4,cy),Vector2(cx,cy+4),Vector2(cx-4,cy)
			]),shine)
			draw_line(Vector2(cx+sx*6,cy+sy*6),Vector2(cx+sx*15,cy+sy*15),Color(gold,.50),1)
