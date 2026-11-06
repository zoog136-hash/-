extends Control
const ART = preload("res://scripts/cards/option_lightning_art.gd")
var clock: float = 0.0
var reduced_motion: bool = false
var intensity: float = 0.85
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("original_option_lightning",{"status":"source_effect_role_pending","legacy_visual_excluded":true})
	material = ART.make_material("영웅")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
func sync(grade: String, seconds: float, reduced: bool, strength: float) -> void:
	clock = seconds
	reduced_motion = reduced
	intensity = strength
	if material is ShaderMaterial: material.set_shader_parameter("grade_color", ART.color_for(grade))
	queue_redraw()
func _draw() -> void:
	# Optional decoration only; never paint a substitute effect.
	return
