extends Control

signal reveal_requested

const FX = preload("res://scripts/ui/card_reveal_effects.gd")
const PROFILES = preload("res://scripts/ui/card_reveal_profiles.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const ConfirmedChrome = preload("res://scripts/ui/card_reveal_chrome.gd")
const ATLAS = preload("res://assets/card_reveal/authored_atlas.webp")
const LIGHTNING_EARLY_SECONDS: float = 0.1
const CONFIRM_DELAY_SECONDS: float = 2.0
const DRAW_EXTRA_LIGHTNING_SECONDS: float = 2.0
var extra_lightning_seconds: float=0.0
var record: Dictionary = {}
var grade: String = "희귀"
var open_at: float = 0.6
var reel_seconds: float = 3.0
var clock: float = 0.0
var aura: Control
var surface_fx: Control
var promotion_fx: Control
var face: Control
var confirmed_chrome: Control
var art_missing: bool=false
var name_label: Label
var grade_label: Label
var grade_heading: Label
var show_grade_heading: bool = false
var reduced_motion: bool = false
var detail_scale: float = 1.0
var intensity_scale: float = 1.0
var waiting_for_press: bool = false
var reveal_button: Button

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
		if elapsed >= duration:
			_art(artwork,Vector2.ZERO)
		elif candidates.is_empty():
			draw_texture_rect(back,Rect2(Vector2.ZERO,size),false)
		else:
			# Keep visibly moving after the grade signal, then land at reveal_at.
			var position_value: float = (1-pow(1-clampf(elapsed/duration,0,1),2.0))*40.0
			var cell: int = int(floor(position_value))
			var offset: float = position_value-floor(position_value)
			for j: int in range(-1,3):
				var image: Texture2D = artwork if cell+j >= 40 else candidates[posmod(cell+j,candidates.size())]
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
	var path: String = str(record.get("image_path",""))
	if not path.is_empty() and ResourceLoader.exists(path):
		face.artwork = load(path) as Texture2D
	elif str(record.get("id","")).is_empty() and str(record.get("sourceId","")).is_empty():
		# The explicitly marked developer showcase has no awarded card identity.
		face.artwork = authored_art()
	art_missing=face.artwork==null
	var back := AtlasTexture.new()
	back.atlas = ATLAS
	var cell: Vector2 = ATLAS.get_size()/Vector2(4,3)
	back.region = Rect2(Vector2(3.13,2.045)*cell,cell*Vector2(0.74,0.86))
	face.back = back
	clip.add_child(face)
	for pass_name: String in ["GradeLightningInsideCard","PromotionLightningInsideCard"]:
		var effect: Control = FX.new()
		effect.name = pass_name
		effect.surface = true
		if pass_name == "GradeLightningInsideCard":effect.extra_lightning_seconds=extra_lightning_seconds
		effect.grade = grade
		effect.reduced_motion = reduced_motion
		effect.detail_scale = detail_scale
		effect.intensity_scale = intensity_scale
		clip.add_child(effect)
		if pass_name == "GradeLightningInsideCard":
			surface_fx = effect
		else:
			promotion_fx = effect
	var rim := Panel.new()
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.name = "MetalRim"
	var style: StyleBoxFlat = UI.box(Color.TRANSPARENT,Color("9b8a6b"),0)
	style.shadow_size = 0
	style.set_border_width_all(2)
	rim.add_theme_stylebox_override("panel",style)
	add_child(rim)
	confirmed_chrome=ConfirmedChrome.new()
	add_child(confirmed_chrome)
	confirmed_chrome.configure(grade,reduced_motion,detail_scale,intensity_scale)
	aura=confirmed_chrome.glow
	name_label = UI.label(str(record.get("name","")),17,UI.grade(grade))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(name_label)
	grade_label = UI.label(grade+(" · 원화 없음" if art_missing else ""),16,UI.grade(grade))
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(grade_label)
	grade_heading = UI.label(grade,28,PROFILES.color(grade))
	grade_heading.name = "GradeHeading"
	grade_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_heading.visible = show_grade_heading
	add_child(grade_heading)
	# Use the shared themed button for mouse, keyboard, and native touch.
	# start_reveal is idempotent if a platform also delivers an emulated event.
	reveal_button = UI.button("",func() -> void: reveal_requested.emit(),Vector2.ZERO)
	reveal_button.name = "RevealCard"
	reveal_button.tooltip_text = "카드를 눌러 뒤집기"
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		reveal_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	reveal_button.visible = waiting_for_press
	add_child(reveal_button)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if face == null:
		return
	var clip: Control = face.get_parent()
	clip.size = size
	face.size = size
	surface_fx.size = size
	promotion_fx.size = size
	(get_node("MetalRim") as Control).size = size
	confirmed_chrome.size=size
	name_label.position = Vector2(-size.x*0.2,size.y+8)
	name_label.size = Vector2(size.x*1.4,26)
	grade_label.position = Vector2(0,size.y+34)
	grade_label.size = Vector2(size.x,22)
	grade_heading.position = Vector2(-size.x*0.2,-54)
	grade_heading.size = Vector2(size.x*1.4,40)
	if reveal_button != null:
		reveal_button.size = size

func start_reveal(at_time: float) -> bool:
	if not waiting_for_press:
		return false
	waiting_for_press = false
	open_at = at_time
	reveal_button.disabled = true
	reveal_button.hide()
	return true

func lightning_at() -> float:
	return open_at+reel_seconds-LIGHTNING_EARLY_SECONDS

func reveal_at() -> float:
	return lightning_at()+CONFIRM_DELAY_SECONDS+extra_lightning_seconds

func promotion_at() -> float:
	# The second signal stays inside the anticipation, on its own clock.
	return open_at+reel_seconds+0.5

func seek(value: float, successful_fusion: bool = false) -> void:
	clock = value
	if waiting_for_press:
		face.elapsed = -1.0
		name_label.hide()
		grade_label.hide()
		# Unopened cards do not leak the result, run lightning, or redraw FX.
		return
	var local: float = clock-open_at
	var revealed: bool = clock >= reveal_at()
	face.elapsed = local
	face.duration = reveal_at()-open_at
	face.queue_redraw()
	# Shared bitmap atmosphere replaces the older persistent aura. Inside-card
	# lightning and the confirmation clock remain on their original passes.
	surface_fx.set_time(clock-lightning_at(),clock)
	# Keep the full primary sequence when the success discharge overlaps it.
	promotion_fx.set_time(clock-promotion_at() if successful_fusion else -1.0,clock)
	name_label.visible = revealed
	grade_label.visible = revealed
	var tint: Color = PROFILES.color(grade) if revealed else Color("9b8a6b")
	var rim: Panel = get_node("MetalRim")
	rim.show()
	confirmed_chrome.visible=revealed
	(rim.get_theme_stylebox("panel") as StyleBoxFlat).border_color = tint
	queue_redraw()

func set_sequence_playing(value: bool) -> void:
	if is_instance_valid(confirmed_chrome):confirmed_chrome.set_ambient_playing(value)
