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
	# Only the original card picture is drawn; the self-made glows, failure
	# cross and placeholder frame were removed (no self-made images).
	if authored_art:
		draw_texture_rect(original,rect,false,Color(.27,.26,.31,.65) if failed else Color.WHITE)
