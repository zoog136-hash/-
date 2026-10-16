extends Node2D
var field: PlayableField

func _draw() -> void:
	if field==null: return
	for shape: Dictionary in field.blockers:
		var color:=Color(.96,.23,.26,.38)
		if str(shape.shape)=="polygon": draw_colored_polygon(shape.polygon,color)
		elif str(shape.shape)=="circle": draw_circle(shape.vcenter,float(shape.radius),color)
		else: draw_rect(shape.vrect,color)
	if field is AuthoredRemakeField and field.collision_stream!=null:
		draw_rect(field.collision_stream.required_bounds(),Color(.2,.9,1,.9),false,3)
