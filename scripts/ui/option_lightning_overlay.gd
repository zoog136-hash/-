extends Control
const ART = preload("res://scripts/cards/option_lightning_art.gd")
var clock: float = 0.0
var reduced_motion: bool = false
var intensity: float = 0.85
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ART.make_material("영웅")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
func sync(grade: String, seconds: float, reduced: bool, strength: float) -> void:
	clock = seconds
	reduced_motion = reduced
	intensity = strength
	if material is ShaderMaterial: material.set_shader_parameter("grade_color", ART.color_for(grade))
	queue_redraw()
func _draw() -> void:
	if intensity <= 0.0: return
	var frame: int = ART.frame_at(clock, reduced_motion)
	if frame >= 0:
		draw_texture_rect_region(ART.ATLAS, Rect2(Vector2(-6,-6), size + Vector2(12,12)), ART.source_rect(frame), Color(1,1,1,intensity * (0.35 if reduced_motion else 0.85)))
