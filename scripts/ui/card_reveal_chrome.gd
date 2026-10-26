extends Control

# The confirmed face uses the same cached art/materials as native catalogs.
# No card awards, selection, timing, texture copies or per-frame nodes here.
const Chrome=preload("res://scripts/ui/catalog_card_chrome.gd")
var rank: int=0
var reduced_motion: bool=false
var low_detail: bool=false
var ambient_playing: bool=true
var glow: Control
var metal: Control

func configure(grade: String, reduced: bool, detail: float, intensity: float) -> void:
	name="ConfirmedCardChrome"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	rank=maxi(0,Chrome.GRADES.find(grade))
	reduced_motion=reduced
	low_detail=detail<0.8
	glow=_layer("SameGradeAura")
	glow.modulate.a=clampf(intensity,0.0,1.5)
	glow.draw.connect(func() -> void:glow.draw_rect(Rect2(Vector2.ZERO,glow.size),Color.WHITE))
	metal=_layer("PaintedCardBorder")
	metal.draw.connect(func() -> void:metal.draw_texture_rect(Chrome.texture_for(rank),Rect2(Vector2.ZERO,metal.size),false))
	_apply_materials()
	hide()

func _layer(label: String) -> Control:
	var layer:=Control.new()
	layer.name=label
	layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return layer

func _apply_materials() -> void:
	var still: bool=reduced_motion or not ambient_playing
	glow.material=Chrome.material_for(rank,true,false,still,low_detail)
	metal.material=Chrome.material_for(rank,false,false,still,low_detail)
	glow.queue_redraw()
	metal.queue_redraw()

func set_ambient_playing(value: bool) -> void:
	if ambient_playing==value:return
	ambient_playing=value
	_apply_materials()
