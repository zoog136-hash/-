extends Control

# Passive surface below window content. Fixed draw budget, resize-only redraw;
# no input, layout minimum, animation, shader or intermediate render target.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x<24 or size.y<24:return
	# The same fixed title plate spans every connected screen. No animated
	# decoration or secondary viewport is needed for the chrome.
	var width: float=size.x-20
	for band: int in range(12):
		var t: float=float(band)/12.0
		draw_rect(Rect2(10,10+band*4,width,4),Color(.30-.12*t,.23-.10*t,.15-.07*t,.68))
	draw_line(Vector2(12,63),Vector2(size.x-12,63),Color("0a0806"),2)
	draw_line(Vector2(12,65),Vector2(size.x-12,65),Color(.74,.61,.39,.45),1)
	draw_line(Vector2(16,11),Vector2(size.x-16,11),Color(.9,.78,.56,.22),1)
	for x: float in [18.,size.x-18]:
		draw_line(Vector2(x,74),Vector2(x,size.y-18),Color(.48,.38,.25,.10),1)
