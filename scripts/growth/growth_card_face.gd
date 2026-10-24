extends Control
## Static card state. No inferred flip animation or automatic outcome.
const Art = preload("res://scripts/growth/growth_art.gd")
var failed: bool = false
var selected: bool = false
var success: bool = false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	if size.x<=8 or size.y<=8: return
	var ratio: float=float(Art.card(false).get_width())/float(Art.card(false).get_height())
	var height: float=minf(size.y-8,(size.x-8)/ratio)
	var extent:=Vector2(height*ratio,height)
	var rect:=Rect2((size-extent)*.5,extent)
	draw_texture_rect(Art.card(false),rect,false,Color(.28,.25,.32,.6) if failed else Color.WHITE)
	if selected:
		var tint:=Color("8ddbe2") if success else Color("b08c91")
		draw_rect(rect.grow(3),tint,false,2)
