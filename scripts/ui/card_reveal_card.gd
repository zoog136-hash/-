extends Control

const FX = preload("res://scripts/ui/card_reveal_effects.gd")
const PROFILES = preload("res://scripts/ui/card_reveal_profiles.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const ATLAS = preload("res://assets/card_reveal/authored_atlas.webp")
var record: Dictionary = {}
var grade: String = "희귀"
var open_at: float = 0.6
var reel_seconds: float = 3.0
var clock: float = 0.0
var aura: Control
var surface_fx: Control
var face: Control
var name_label: Label
var grade_label: Label
var grade_heading: Label
var show_grade_heading: bool = false
var reduced_motion: bool = false
var detail_scale: float = 1.0
var intensity_scale: float = 1.0

class Face extends Control:
	var artwork: Texture2D
	var back: Texture2D
	var candidates: Array[Texture2D] = []
	var elapsed: float = -1.0
	var duration: float = 3.0
	var tint: Color = Color.WHITE
	var category: String = "변신"

	func _art(texture: Texture2D, at: Vector2) -> void:
		if texture == null:
			return
		var factor: float = 0.79 if category == "마법인형" else 0.91 if category == "성물" else 0.98
		var fitted: Vector2 = texture.get_size()*minf(size.x*factor/texture.get_width(),size.y*0.98/texture.get_height())
		draw_texture_rect(texture,Rect2(at+(size-fitted)*0.5,fitted),false)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("0a1119"))
		if elapsed < 0:
			draw_texture_rect(back,Rect2(Vector2.ZERO,size),false)
			return
		draw_rect(Rect2(Vector2.ZERO,size),Color(tint,0.08))
		if elapsed >= duration or candidates.is_empty():
			_art(artwork,Vector2.ZERO)
		else:
			var position_value: float = (1-pow(1-clampf(elapsed/duration,0,1),3.4))*24.0
			var cell: int = int(floor(position_value))
			var offset: float = position_value-floor(position_value)
			for j: int in range(-1,3):
				var image: Texture2D = artwork if cell+j >= 24 else candidates[posmod(cell+j,candidates.size())]
				_art(image,Vector2((float(j)-offset)*size.x,0))
		# Surface reflection follows the result color and leaves the figure legible.
		draw_rect(Rect2(0,size.y*0.78,size.x,size.y*0.22),Color(tint,0.12))

static func authored_art(index: int = 4) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = ATLAS
	var cell: Vector2 = ATLAS.get_size()/Vector2(4,3)
	result.region = Rect2(Vector2(index%4,index/4)*cell+Vector2(2,2),cell-Vector2(4,4))
	return result

func configure(value: Dictionary, candidates: Array[Texture2D], category: String) -> void:
	record = value.duplicate(true)
	grade = str(record.get("grade","일반"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura = FX.new()
	aura.grade = grade
	aura.reduced_motion = reduced_motion
	aura.detail_scale = detail_scale
	aura.intensity_scale = intensity_scale
	add_child(aura)
	var clip := Control.new()
	clip.name = "CardSurfaceClip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	face = Face.new()
	face.category = category
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.candidates = candidates
	face.tint = PROFILES.color(grade)
	face.artwork = authored_art()
	var path: String = str(record.get("image_path",""))
	if not path.is_empty() and ResourceLoader.exists(path):
		face.artwork = load(path) as Texture2D
	var back := AtlasTexture.new()
	back.atlas = ATLAS
	var cell: Vector2 = ATLAS.get_size()/Vector2(4,3)
	back.region = Rect2(Vector2(3.13,2.045)*cell,cell*Vector2(0.74,0.86))
	face.back = back
	clip.add_child(face)
	surface_fx = FX.new()
	surface_fx.name = "GradeLightningInsideCard"
	surface_fx.surface = true
	surface_fx.grade = grade
	surface_fx.reduced_motion = reduced_motion
	surface_fx.detail_scale = detail_scale
	surface_fx.intensity_scale = intensity_scale
	clip.add_child(surface_fx)
	var rim := Panel.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.name = "MetalRim"
	var style: StyleBoxFlat = UI.box(Color.TRANSPARENT,Color("9b8a6b"),0)
	style.shadow_size = 0
	style.set_border_width_all(2)
	rim.add_theme_stylebox_override("panel",style)
	add_child(rim)
	name_label = UI.label(str(record.get("name","")),17,PROFILES.color(grade))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(name_label)
	grade_label = UI.label(grade,16,PROFILES.color(grade))
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(grade_label)
	grade_heading = UI.label(grade,28,PROFILES.color(grade))
	grade_heading.name = "GradeHeading"
	grade_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_heading.visible = show_grade_heading
	add_child(grade_heading)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if face == null:
		return
	aura.position = Vector2(-size.x*0.5,-size.y/3.0)
	aura.size = Vector2(size.x*2.0,size.y/0.6)
	var clip: Control = face.get_parent()
	clip.size = size
	face.size = size
	surface_fx.size = size
	(get_node("MetalRim") as Control).size = size
	name_label.position = Vector2(-size.x*0.2,size.y+8)
	name_label.size = Vector2(size.x*1.4,26)
	grade_label.position = Vector2(0,size.y+34)
	grade_label.size = Vector2(size.x,22)
	grade_heading.position = Vector2(-size.x*0.2,-54)
	grade_heading.size = Vector2(size.x*1.4,40)

func seek(value: float) -> void:
	clock = value
	var local: float = clock-open_at
	face.elapsed = local
	face.duration = reel_seconds
	face.queue_redraw()
	aura.set_time(local-reel_seconds,clock)
	surface_fx.set_time(local-reel_seconds+0.1,clock)
	var revealed: bool = local >= reel_seconds
	name_label.visible = revealed
	grade_label.visible = revealed
	var tint: Color = PROFILES.color(grade) if revealed else Color("9b8a6b")
	var rim: Panel = get_node("MetalRim")
	(rim.get_theme_stylebox("panel") as StyleBoxFlat).border_color = tint
	queue_redraw()
