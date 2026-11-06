extends Control
## Existing TWILIGHT card art; UI551 property timelines are applied by the view.
const Art = preload("res://scripts/growth/growth_art.gd")
var failed: bool = false
var selected: bool = false
var success: bool = false
var authored_art: bool = true
var highlight: float = 0.0:
	set(value):
		highlight=value
		queue_redraw()
var feedback_tween: Tween

func set_interaction(active: bool) -> void:
	if failed or selected or not is_inside_tree(): return
	if is_instance_valid(feedback_tween): feedback_tween.kill()
	feedback_tween=create_tween()
	feedback_tween.tween_property(self,"highlight",1.0 if active else 0.0,.12)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	if size.x<=8 or size.y<=8: return
	var original: Texture2D=Art.card(false)
	if original==null:
		set_meta("original_growth_card",{"status":"source_card_decoration_role_pending"})
		return
	var ratio: float=float(original.get_width())/float(original.get_height())
	var height: float=minf(size.y-8,(size.x-8)/ratio)
	var extent:=Vector2(height*ratio,height)
	var rect:=Rect2((size-extent)*.5,extent)
	if not failed:
		for i: int in range(3):
			draw_rect(rect.grow(3+i*2),Color("d8be82",highlight*(.045-i*.01)),false,2)
	if authored_art:
		draw_texture_rect(original,rect,false,Color(.27,.26,.31,.65) if failed else Color.WHITE.lerp(Color(1.15,1.1,.98),highlight))
	else:
		draw_rect(rect,Color("172434"))
		draw_rect(rect,Color("897454"),false,1)
	if failed:
		var center: Vector2=rect.get_center()
		draw_circle(center,13,Color(.03,.025,.035,.86))
		draw_line(center-Vector2(5,5),center+Vector2(5,5),Color("8b7476"),2,true)
		draw_line(center+Vector2(-5,5),center+Vector2(5,-5),Color("8b7476"),2,true)
	if selected:
		var tint:=Color("a2e4dd") if success else Color("977779")
		draw_rect(rect.grow(2),Color(tint,.8),false,1)
		if success:
			for i: int in range(3): draw_rect(rect.grow(4+i*2),Color(tint,.12-i*.03),false,2)
			var center: Vector2=rect.get_center()
			draw_line(center-Vector2(0,9),center+Vector2(0,9),Color("fff3c8"),2,true)
			draw_line(center-Vector2(6,0),center+Vector2(6,0),Color("fff3c8"),1,true)
