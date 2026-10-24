extends Control
## Presentation only: the transaction is durable before this flip starts.
const Art = preload("res://scripts/growth/growth_art.gd")
var front: bool = false
var failed: bool = false
var selected: bool = false
var progress: float = 1.0
var playing: bool = false
var shine: float = 0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func reveal(won: bool) -> void:
	front=won; failed=not won; progress=0; playing=true
	var tween:=create_tween()
	tween.tween_property(self,"progress",1.0,.65).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self,"shine",1.0,.12)
	tween.tween_property(self,"shine",0.0,.5)
	tween.tween_callback(func() -> void: playing=false; queue_redraw())
func _process(_delta: float) -> void:
	if playing: queue_redraw()
func _draw() -> void:
	if size.x<=8 or size.y<=8: return
	var rect:=Rect2(Vector2(4,4),size-Vector2(8,8))
	var ratio: float=float(Art.card(false).get_width())/float(Art.card(false).get_height())
	var height: float=minf(rect.size.y,rect.size.x/ratio)
	var extent:=Vector2(height*ratio,height)
	var center:=size*.5
	var show_front: bool=front and (not playing or progress>=.5)
	var squash: float=absf(cos(progress*PI)) if playing else 1.0
	var tint:=Color("a8e9ff") if front else Color("d7b87c")
	if selected or shine>0:
		for i: int in range(5): draw_circle(center,extent.y*(.35+float(i)*.035),Color(tint,(.025 if selected else 0)+shine*.035))
	var draw_extent:=Vector2(extent.x*maxf(.03,squash),extent.y)
	var color:=Color(.38,.34,.42) if failed and (not playing or progress>=.5) else Color.WHITE
	draw_texture_rect(Art.card(show_front),Rect2(center-draw_extent*.5,draw_extent),false,color)
	if selected: draw_rect(Rect2(center-extent*.5-Vector2(3,3),extent+Vector2(6,6)),Color("e9cf8a"),false,2)
	if shine>0 and front:
		for i: int in range(12):
			var point:=center+Vector2.from_angle(TAU*i/12.0)*extent.y*(.22+(1-shine)*.4)
			draw_line(point-Vector2(3,0),point+Vector2(3,0),Color(tint,shine),1.5,true)
			draw_line(point-Vector2(0,3),point+Vector2(0,3),Color(tint,shine),1.5,true)
