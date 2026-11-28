extends Control

signal reveal_requested

const FX = preload("res://scripts/ui/card_reveal_effects.gd")
const PROFILES = preload("res://scripts/ui/card_reveal_profiles.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const ConfirmedChrome = preload("res://scripts/ui/card_reveal_chrome.gd")
const SourceCard = preload("res://scripts/ui/source_card_presentation.gd")
const SourceSurfaces = preload("res://scripts/ui/original_card_surfaces.gd")
const GradeFx = preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
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
var result_cell_illumination: bool = false
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
	var candidates: Array[Dictionary] = []
	var award_layers: Dictionary = {}
	var elapsed: float = -1.0
	var duration: float = 3.0
	var tint: Color = Color.WHITE
	var illumination: Color = Color.TRANSPARENT
	var category: String = "변신"

	func _art(texture: Texture2D, at: Vector2, portrait_bounds: Vector2) -> void:
		if texture == null:
			return
		var factor: float = 0.79 if category == "마법인형" else 0.91 if category == "성물" else 0.98
		var fitted: Vector2 = texture.get_size()*minf(portrait_bounds.x*factor/texture.get_width(),portrait_bounds.y*0.98/texture.get_height())
		draw_texture_rect(texture,Rect2(at+(size-fitted)*0.5,fitted),false)

	func _draw_reel_card(texture: Texture2D, layers: Dictionary, at: Vector2) -> void:
		if layers.is_empty():
			_art(texture,at,size)
			return
		var frame: Texture2D = layers.frame
		var background: Texture2D = layers.get("background")
		var original_size: Vector2 = frame.get_size()
		var background_size: Vector2 = layers.get("background_size",original_size)
		var extent: Vector2 = original_size.max(background_size)
		var fit: float = minf(size.x/extent.x,size.y/extent.y)
		var center: Vector2 = at+size*0.5
		if background!=null:
			var fitted_background: Vector2 = background_size*fit
			draw_texture_rect(background,Rect2(center-fitted_background*0.5,fitted_background),false,layers.background_color)
		var fitted_frame: Vector2 = original_size*fit
		draw_texture_rect(frame,Rect2(center-fitted_frame*0.5,fitted_frame),false)
		# Leave the frame visible even for portraits that fill the original slot.
		_art(texture,at,fitted_frame*0.9)

	func _draw() -> void:
		_draw_surface()
		if illumination.a > 0.0:
			draw_rect(Rect2(Vector2.ZERO,size),illumination)

	func _draw_surface() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("0a1119"))
		if elapsed < 0:
			if back!=null:draw_texture_rect(back,Rect2(Vector2.ZERO,size),false)
			return
		if elapsed >= duration:
			draw_rect(Rect2(Vector2.ZERO,size),Color(tint,0.08))
			_art(artwork,Vector2.ZERO,size)
			draw_rect(Rect2(0,size.y*0.78,size.x,size.y*0.22),Color(tint,0.12))
		elif candidates.is_empty():
			if back!=null:draw_texture_rect(back,Rect2(Vector2.ZERO,size),false)
		else:
			# Keep visibly moving after the grade signal, then land at reveal_at.
			var position_value: float = (1-pow(1-clampf(elapsed/duration,0,1),2.0))*40.0
			var cell: int = int(floor(position_value))
			var offset: float = position_value-floor(position_value)
			# The clip can intersect only these two adjacent slots.
			for j: int in range(2):
				var at := Vector2((float(j)-offset)*size.x,0)
				if cell+j >= 40:
					_draw_reel_card(artwork,award_layers,at)
				else:
					var candidate: Dictionary = candidates[(cell+j)%candidates.size()]
					_draw_reel_card(candidate.artwork,candidate.layers,at)

func configure(value: Dictionary, candidates: Array[Texture2D], category: String, source_candidate_records: Array = [],
		fusion_pack: RefCounted = null, layers_by_grade: Dictionary = {}) -> void:
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
	if SourceCard.native(record):
		var candidate_assets: Array = []
		for candidate: Variant in source_candidate_records:
			var original_candidate: Dictionary = SourceCard.detail(candidate,true,false) if candidate is Dictionary else {"status":"missing","reason":"source_candidate_record_required","texture":null}
			var texture: Texture2D = original_candidate.get("texture") as Texture2D
			if texture!=null or fusion_pack==null:
				var layers: Dictionary = _reel_layers(fusion_pack,str(candidate.get("grade","")),layers_by_grade) if fusion_pack!=null else {}
				face.candidates.append({"artwork":texture,"layers":layers})
			var candidate_evidence: Dictionary = original_candidate.duplicate(true)
			candidate_evidence.erase("texture")
			candidate_evidence["card_id"] = SourceCard.CARDS.card_id(candidate) if candidate is Dictionary else ""
			candidate_assets.append(candidate_evidence)
		face.set_meta("source_candidate_assets",candidate_assets)
	else:
		face.set_meta("source_candidate_assets",{"status":"source_card_identity_required"})
	face.tint = PROFILES.color(grade)
	if SourceCard.native(record):
		# The settled award uses the same portrait role as the reel candidates.
		var original: Dictionary = SourceCard.detail(record, true, false)
		face.artwork = original.get("texture") as Texture2D
		if face.artwork!=null and fusion_pack!=null:face.award_layers=_reel_layers(fusion_pack,grade,layers_by_grade)
		var evidence: Dictionary = original.duplicate(true)
		evidence.erase("texture")
		evidence["card_id"] = SourceCard.CARDS.card_id(record)
		face.set_meta("original_card_asset",evidence)
	elif category == "스킬 카드" and int(record.get("item_class_id",0)) > 0:
		var book: Dictionary = SourceCard.IMAGES523.describe_item_class(int(record.item_class_id), str(record.get("name","")))
		face.artwork = book.get("texture") as Texture2D
		var evidence: Dictionary = book.duplicate()
		evidence.erase("texture")
		face.set_meta("original_card_asset",evidence)
	else:
		face.set_meta("original_card_asset",{"status":"source_card_identity_required","texture":null})
	art_missing=face.artwork==null
	var back: Dictionary=SourceSurfaces.resolve("reveal_back",record)
	face.back=back.get("texture") as Texture2D
	var back_evidence: Dictionary=back.duplicate();back_evidence.erase("texture")
	face.set_meta("original_card_back",back_evidence)
	clip.add_child(face)
	if not result_cell_illumination:
		surface_fx = _add_surface(clip,"GradeLightningInsideCard",extra_lightning_seconds)
		promotion_fx = _add_surface(clip,"PromotionLightningInsideCard",0.0)
		var rim:=Panel.new()
		rim.mouse_filter=Control.MOUSE_FILTER_IGNORE
		rim.name="MetalRim"
		var style: StyleBoxFlat=UI.box(Color.TRANSPARENT,PROFILES.color(grade),0)
		style.shadow_size=0
		style.set_border_width_all(2)
		rim.add_theme_stylebox_override("panel",style)
		rim.hide()
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

static func _reel_layers(pack: RefCounted, grade: String, layers_by_grade: Dictionary) -> Dictionary:
	if not layers_by_grade.has(grade):layers_by_grade[grade]=GradeFx.card_face_layers(pack,grade)
	return layers_by_grade[grade]

func _add_surface(clip: Control,pass_name: String,extra: float) -> Control:
	var effect: Control=FX.new()
	effect.name=pass_name
	effect.surface=true
	effect.extra_lightning_seconds=extra
	effect.grade=grade
	effect.reduced_motion=reduced_motion
	effect.detail_scale=detail_scale
	effect.intensity_scale=intensity_scale
	clip.add_child(effect)
	return effect

## Reuse the finished deal's category-specific back when the original
## portraits for the reel are unavailable.
func set_native_card_back(texture: Texture2D) -> void:
	if face.back==null:
		face.back=texture
		face.queue_redraw()

func _fit() -> void:
	if face == null:
		return
	var clip: Control = face.get_parent()
	clip.size = size
	face.size = size
	if surface_fx!=null:surface_fx.size=size
	if promotion_fx!=null:promotion_fx.size=size
	var rim: Control=get_node_or_null("MetalRim")
	if rim!=null:rim.size=size
	if confirmed_chrome!=null:confirmed_chrome.size=size
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

func light_color(successful_fusion: bool) -> Color:
	if reduced_motion or waiting_for_press: return Color.TRANSPARENT
	var power: float = PROFILES.pulse(grade, clock-lightning_at(), extra_lightning_seconds)
	if successful_fusion:
		power += PROFILES.pulse(grade, clock-promotion_at())
	return Color(PROFILES.color(grade),minf(0.055,power*0.023*intensity_scale)) if power > 0.03 else Color.TRANSPARENT

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
	if result_cell_illumination:
		face.illumination = light_color(successful_fusion)
	face.queue_redraw()
	# Shared bitmap atmosphere replaces the older persistent aura. Inside-card
	# lightning and the confirmation clock remain on their original passes.
	if surface_fx!=null:surface_fx.set_time(clock-lightning_at(),clock)
	# Keep the full primary sequence when the success discharge overlaps it.
	if promotion_fx!=null:promotion_fx.set_time(clock-promotion_at() if successful_fusion else -1.0,clock)
	name_label.visible = revealed
	grade_label.visible = revealed
	var rim: Panel = get_node_or_null("MetalRim")
	if rim!=null:rim.visible=revealed
	if confirmed_chrome!=null:confirmed_chrome.visible=revealed
	queue_redraw()

func set_sequence_playing(value: bool) -> void:
	if is_instance_valid(confirmed_chrome):confirmed_chrome.set_ambient_playing(value)
