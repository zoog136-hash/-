extends Control
## Static source target region; animation effects await their source timeline.
const SKIN=preload("res://scripts/ui/source_skill_awakening_skin.gd")
var portrait: Texture2D
var layers: Array[Dictionary]=[]
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	for name_value: String in ["Img_MagicRing","Img_Plus","Img_Bg_Itme"]:
		var entry: Dictionary=SKIN.node(name_value)
		var original: Texture2D=SKIN.texture(entry)
		if original!=null:layers.append({"texture":original,"bounds":entry.bounds_y_up,"alpha":float(entry.alpha)/255.0})
	resized.connect(queue_redraw)
func source_rect(bounds: Array) -> Rect2:
	# Crop the original400x170 upper skill area, retaining exact card/slot centers.
	return Rect2((float(bounds[0])+380.0)/400.0*size.x,(163.0-float(bounds[1])-float(bounds[3]))/170.0*size.y,float(bounds[2])/400.0*size.x,float(bounds[3])/170.0*size.y)
func _draw() -> void:
	for layer: Dictionary in layers:draw_texture_rect(layer.texture,source_rect(layer.bounds),false,Color(1,1,1,layer.alpha))
	if portrait!=null:draw_texture_rect(portrait,source_rect([-325.0,6.0,110.0,134.0]),false)
