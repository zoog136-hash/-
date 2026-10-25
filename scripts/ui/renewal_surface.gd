extends Control

# Passive surface below window content. Fixed draw budget, resize-only redraw;
# no input, layout minimum, animation, shader or intermediate render target.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 8 or size.y < 8:
		return
	var bounds := Rect2(Vector2.ZERO,size)
	draw_rect(bounds,Color(0.025,0.022,0.019,0.12))
	# Unequal narrow bands suggest worn brushed material at restrained contrast.
	for band: int in range(12):
		var y: float = size.y*float(band)/12.0
		var alpha: float = 0.025*(1.0-float(band)/12.0)
		draw_rect(Rect2(0,y,size.x,size.y/12.0+1),Color(0.85,0.79,0.67,alpha))
	for line: int in range(mini(32,int(size.y/14.0))):
		var y: float = 9.0+float(line)*14.0
		draw_line(Vector2(3,y),Vector2(size.x-3,y),Color(0,0,0,0.055),1)
	draw_line(Vector2(1,1),Vector2(size.x-1,1),Color(0.76,0.68,0.55,0.12),1)
	draw_line(Vector2(1,1),Vector2(1,size.y-1),Color(0.76,0.68,0.55,0.08),1)
	draw_line(Vector2(1,size.y-1),Vector2(size.x-1,size.y-1),Color(0,0,0,0.4),1)
	draw_line(Vector2(size.x-1,1),Vector2(size.x-1,size.y-1),Color(0,0,0,0.4),1)
