extends Control

# Authored, bounded CanvasItem animation for Compatibility / Android.
# Receives a committed result: no RNG, inventory writes, or transaction callbacks.
signal finished
const UI = preload("res://scripts/ui/renewal_theme.gd")
const CHARGE = preload("res://assets/enhancement/charge.wav")
const SUCCESS = preload("res://assets/enhancement/success.wav")
const FAILURE = preload("res://assets/enhancement/failure.wav")
const REVEAL_AT: float = 1.85
const SETTLE_AT: float = 3.45
const DESIGN = Vector2(1000,640)
const CENTER = Vector2(500,270)
const BLUE = Color("69caff")
const GOLD = Color("ffe3a1")
const AMBER = Color("f7a641")
const HOT_GOLD = Color("fff5c9")
var reduced_motion: bool = false
var low_detail: bool = false
var intensity: float = 0.85
var silent: bool = false
var clock: float = 0.0
var result: String = "maintain"
var item_name: String = ""
var from_level: int = 0
var to_level: int = 0
var item_texture: Texture2D
var playing: bool = false
var revealed: bool = false
var closed: bool = false
var board: Control
var heading: Label
var item_label: Label
var level_label: Label
var result_label: Label
var note: Label
var skip_button: Button
var confirm_button: Button
var sound: AudioStreamPlayer
var design_offset: Vector2
var design_scale: float = 1.0

func _ready() -> void:
	name = "EnhancementReveal"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	theme = UI.make_theme()
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	heading = _label("장비 강화",28,UI.GOLD,Rect2(80,28,840,48))
	item_label = _label("",20,UI.TEXT,Rect2(70,372,860,40))
	item_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	level_label = _label("",30,UI.GOLD,Rect2(340,318,320,45))
	result_label = _label("",32,BLUE,Rect2(70,418,860,52))
	note = _label("마력이 장비에 모이고 있습니다",17,UI.MUTED,Rect2(70,477,860,42))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skip_button = UI.button("연출 건너뛰기",skip_to_result,Vector2(180,52))
	skip_button.name = "SkipEnhancement"
	board.add_child(skip_button)
	skip_button.position = Vector2(302,554)
	skip_button.size = Vector2(180,52)
	confirm_button = UI.button("확인",close_reveal,Vector2(180,52))
	confirm_button.name = "ConfirmEnhancement"
	board.add_child(confirm_button)
	confirm_button.position = Vector2(518,554)
	confirm_button.size = Vector2(180,52)
	confirm_button.disabled = true
	sound = AudioStreamPlayer.new()
	sound.volume_db = -12
	add_child(sound)
	resized.connect(_fit)
	_fit()
	grab_focus()

func _label(value: String, font_size: int, tint: Color, rect: Rect2) -> Label:
	var label: Label = UI.label(value,font_size,tint)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label

func present(outcome: String, display_name: String, before: int, after: int, texture: Texture2D) -> void:
	result = outcome if outcome in ["success","maintain","decrease","destroy"] else "maintain"
	item_name = display_name
	from_level = before
	to_level = after
	item_texture = texture
	clock = 0.0
	revealed = false
	closed = false
	playing = true
	item_label.text = display_name
	level_label.text = "+%d" % from_level
	result_label.text = ""
	_play(CHARGE)
	queue_redraw()

func _fit() -> void:
	design_scale = maxf(0.01,minf(size.x/DESIGN.x,size.y/DESIGN.y))
	design_offset = (size-DESIGN*design_scale)*0.5
	board.position = design_offset
	board.scale = Vector2.ONE*design_scale
	board.size = DESIGN
	queue_redraw()

func _process(delta: float) -> void:
	if not playing or closed: return
	clock = minf(SETTLE_AT,clock+maxf(0.0,delta))
	if clock >= REVEAL_AT and not revealed:
		_reveal()
	if clock >= SETTLE_AT:
		playing = false
	queue_redraw()

func _reveal() -> void:
	revealed = true
	confirm_button.disabled = false
	skip_button.disabled = true
	confirm_button.grab_focus()
	match result:
		"success":
			result_label.text = "강화 성공"
			result_label.add_theme_color_override("font_color",HOT_GOLD)
			level_label.text = "+%d" % to_level
			note.text = "+%d → +%d  ·  강화 수치가 상승했습니다" % [from_level,to_level]
		"destroy":
			result_label.text = "강화 실패 · 장비 소실"
			result_label.add_theme_color_override("font_color",Color("f18167"))
			level_label.text = ""
			note.text = "강화한 장비가 소실되었습니다"
		"decrease":
			result_label.text = "강화 실패 · 수치 하락"
			result_label.add_theme_color_override("font_color",Color("b7a1d7"))
			level_label.text = "+%d" % to_level
			note.text = "+%d → +%d  ·  장비는 보존되었습니다" % [from_level,to_level]
		_:
			result_label.text = "강화 실패 · 수치 유지"
			result_label.add_theme_color_override("font_color",Color("a9b9c9"))
			note.text = "강화 수치와 장비가 보존되었습니다"
	_play(SUCCESS if result == "success" else FAILURE)

func skip_to_result() -> void:
	if closed or revealed: return
	_reveal()
	clock = SETTLE_AT
	playing = false
	queue_redraw()

func close_reveal() -> void:
	if closed or not revealed: return
	closed = true
	playing = false
	sound.stop()
	# Hide immediately so rapid input cannot hit the old overlay during deferred free.
	hide()
	finished.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if closed or not is_visible_in_tree(): return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			if revealed: close_reveal()
			else: skip_to_result()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		# GUI must receive pointer events for the two buttons. Full-screen STOP
		# consumes them before the world's unhandled input path.
		pass

func _unhandled_input(_event: InputEvent) -> void:
	# GUI handles Tab/Enter and controller focus first; remaining gameplay keys
	# and pointer events cannot reach the world while the result is displayed.
	if not closed and is_visible_in_tree():
		get_viewport().set_input_as_handled()

func _play(stream: AudioStream) -> void:
	if silent: return
	sound.stream = stream
	sound.play()

func _glow(center: Vector2, radius: float, tint: Color, alpha: float) -> void:
	var layers: int = 5 if low_detail else 10
	for j: int in range(layers,0,-1):
		var fraction: float = float(j)/float(layers)
		draw_circle(center,radius*fraction,Color(tint,alpha*(1.0-fraction*0.8)/float(layers)*2.4))

func _stroke(a: Vector2, b: Vector2, tint: Color, alpha: float, width: float = 1.0) -> void:
	if not low_detail:
		draw_line(a,b,Color(tint,alpha*0.10),width*8.0,true)
		draw_line(a,b,Color(tint,alpha*0.24),width*3.5,true)
	draw_line(a,b,Color(tint,alpha),width,true)

func _draw() -> void:
	if not is_instance_valid(board): return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.012,0.018,0.029,0.96))
	draw_set_transform(design_offset,0,Vector2.ONE*design_scale)
	var amount: float = clampf(intensity,0.0,1.5)
	var charge: float = clampf(clock/REVEAL_AT,0.0,1.0)
	var age: float = maxf(0.0,clock-REVEAL_AT)
	var tier: float = clampf(float(maxi(from_level,to_level)-5)/8.0,0.0,1.0)
	# Warm gold builds during charging and breaks into a wide radial flare on success.
	# Failure hues are kept distinct only after the committed result is revealed.
	var tint: Color = GOLD
	if revealed and result != "success":
		tint = Color("f26943") if result == "destroy" else Color("9a88b7")
	var pulse: float = 0.6+charge*0.4 if not revealed else exp(-age*2.4)
	var motion: float = 0.0 if reduced_motion else 1.0
	# Draw the warm fan BEHIND the item, not as thin rotating circles.
	if not revealed:
		_golden_charge(charge,amount)
	elif result == "success":
		_golden_burst(age,tier,amount)
	else:
		_glow(CENTER,160.0,tint,exp(-age*2.4)*0.21*amount)
	# A quiet metal border and fine engraving keep the item readable between flashes.
	draw_rect(Rect2(36,16,928,610),Color("4e4437"),false,1.0)
	for side: float in [-1.0,1.0]:
		_stroke(Vector2(500+side*65,104),Vector2(500+side*330,104),GOLD,0.4)
		_stroke(Vector2(500+side*65,524),Vector2(500+side*330,524),GOLD,0.4)
	var orbit: float = clock*0.34*motion
	var rect := Rect2(CENTER-Vector2(66,66),Vector2(132,132))
	draw_rect(rect,Color("090f1c"))
	for i: int in range(3):
		draw_rect(rect.grow(float(i)*3.0),Color(tint,(0.6 if i == 0 else 0.10)*amount),false,2.0)
	var icon_alpha: float = 1.0
	if revealed and result == "destroy": icon_alpha = 1.0-clampf(age/0.55,0.0,1.0)
	var shake := Vector2.ZERO
	if not reduced_motion and revealed and age < 0.3:
		shake = Vector2(sin(age*130.0),cos(age*96.0))*exp(-age*15.0)*3.0*amount
	if item_texture != null:
		var available := Vector2(96,96)
		var natural: Vector2 = item_texture.get_size()
		var icon_size: Vector2 = natural*minf(available.x/maxf(1,natural.x),available.y/maxf(1,natural.y))
		draw_texture_rect(item_texture,Rect2(CENTER-icon_size*0.5+shake,icon_size),false,Color(1,1,1,icon_alpha))
	if not revealed:
		# Inward motes, moving frame highlights, and a tightening light seal.
		var count: int = 14 if low_detail else 30
		for i: int in range(count):
			var phase: float = fposmod(charge*1.65+float(i)*0.618,1.0)
			var angle: float = float(i)*2.399+orbit
			var radial: float = lerpf(236,55,phase) if not reduced_motion else 154.0
			var point: Vector2 = CENTER+Vector2.from_angle(angle)*radial
			_glow(point,5.0,tint,sin(phase*PI)*0.7*amount)
			if not reduced_motion: _stroke(point,point+Vector2.from_angle(angle)*12.0,tint,sin(phase*PI)*0.5*amount)
		var seal: float = lerpf(100.0,68.0,charge) if not reduced_motion else 74.0
		draw_rect(Rect2(CENTER-Vector2.ONE*seal,Vector2.ONE*seal*2),Color(GOLD,charge*0.5*amount),false,2.0)
		if not reduced_motion:
			_stroke(CENTER+Vector2(-66,66-charge*132),CENTER+Vector2(66,66-charge*132),Color.WHITE,charge*0.75*amount,1.5)
	elif result == "success":
		_success(age,tier,amount)
	elif result == "destroy":
		_destroy(age,amount)
	elif result == "decrease":
		for i: int in range(5):
			var start := CENTER+Vector2(float(i-2)*26,-45+age*60*motion)
			_stroke(start,start+Vector2(0,48),tint,exp(-age*2)*amount,2)
	else:
		# A failed attempt subsides instead of ending with another empty ring.
		for i: int in range(6 if low_detail else 12):
			var direction := Vector2.from_angle(float(i)*TAU/12.0+0.22)
			var p: Vector2 = CENTER+direction*(70.0+age*32.0*motion)
			_stroke(p,p+direction*9.0,tint,exp(-age*3.0)*0.42*amount,1.5)
	draw_set_transform(Vector2.ZERO)

# Original TWILIGHT procedural glow: no proprietary XP Hero or Lineage art is embedded.
# One bright impact, broad translucent amber shafts, hot white core, then distant
# gold debris. These are CanvasItem polygons, not expanding circular outline rings.
func _golden_charge(charge: float, amount: float) -> void:
	var strength: float = (0.10+pow(charge,2.0)*0.34)*amount
	var count: int = 8 if low_detail else 15
	var motion: float = 0.0 if reduced_motion else 1.0
	for i: int in range(count):
		var angle: float = float(i)*TAU/float(count)+clock*0.18*motion
		var direction: Vector2 = Vector2.from_angle(angle)
		var perpendicular: Vector2 = Vector2(-direction.y,direction.x)
		var reach: float = 175.0+float(i%5)*21.0
		var far: Vector2 = CENTER+direction*reach
		var left: Vector2 = CENTER+direction*59.0-perpendicular*4.0
		var right: Vector2 = CENTER+direction*59.0+perpendicular*4.0
		draw_colored_polygon(PackedVector2Array([left,far-perpendicular*13.0,right,far+perpendicular*13.0]),Color(AMBER,strength*0.27))
	_glow(CENTER,135.0,HOT_GOLD,strength*0.40)


func _golden_burst(age: float, tier: float, amount: float) -> void:
	# The burst peaks at the EXACT existing reveal boundary: no reward timing
	# or committed enhancement outcome is changed.
	var motion: float = 0.0 if reduced_motion else 1.0
	var burst_fade: float = exp(-age*(3.2 if reduced_motion else 1.65))
	var reach_growth: float = minf(1.0,age/0.62)
	var shafts: int = 9 if low_detail else 27
	for i: int in range(shafts):
		var angle: float = float(i)*TAU/float(shafts)+0.14
		var direction: Vector2 = Vector2.from_angle(angle)
		var side: Vector2 = Vector2(-direction.y,direction.x)
		var reach: float = (235.0+float(i%7)*53.0)*(1.0+0.40*reach_growth*motion)*(1.0+0.13*tier)
		var half_width: float = 21.0+reach*(0.064+0.013*float(i%3))
		var root: Vector2 = CENTER+direction*28.0
		var tip: Vector2 = CENTER+direction*reach
		# Wide translucent beam, then a narrower, brighter inner shaft.
		draw_colored_polygon(PackedVector2Array([
			root-side*11.0,tip-side*half_width,tip+side*half_width,root+side*11.0
		]),Color(AMBER,clampf((0.20+0.08*float(i%4==0))*burst_fade*amount,0.0,1.0)))
		if i%2 == 0:
			draw_colored_polygon(PackedVector2Array([
				root-side*3.0,tip-side*half_width*0.25,tip+side*half_width*0.25,root+side*3.0
			]),Color(HOT_GOLD,clampf(0.23*burst_fade*amount,0.0,1.0)))
	# A broad amber wash and concentrated white-hot light read as an explosion,
	# instead of the former two rotating outlines with tiny ticks.
	_glow(CENTER,292.0+reach_growth*60.0*motion,AMBER,0.88*burst_fade*amount)
	_glow(CENTER,178.0+reach_growth*26.0*motion,GOLD,0.90*burst_fade*amount)
	_glow(CENTER,92.0,HOT_GOLD,0.98*burst_fade*amount)
	if not reduced_motion:
		var cross: float = 1.0-minf(1.0,age/0.50)
		_stroke(CENTER-Vector2(350.0,0),CENTER+Vector2(350.0,0),HOT_GOLD,cross*0.70*amount,4.0)
		_stroke(CENTER-Vector2(0,205.0),CENTER+Vector2(0,205.0),GOLD,cross*0.48*amount,2.0)


func _success(age: float, tier: float, amount: float) -> void:
	# Small sparks and a brief lens flare appear IN FRONT of the item; the large
	# beams above are behind it so its original icon remains visible.
	var fade: float = exp(-age*2.5)*(0.38 if reduced_motion else 1.0)
	var motion: float = 0.0 if reduced_motion else 1.0
	var count: int = 13 if low_detail else 36
	for i: int in range(count):
		var angle: float = float(i)*2.3999632
		var direction: Vector2 = Vector2.from_angle(angle)
		var distance: float = (84.0+float(i%5)*14.0)+age*(135.0+float(i%7)*28.0)*motion
		var point: Vector2 = CENTER+direction*distance
		var alpha: float = fade*(0.66+0.05*float(i%4))*amount
		_stroke(point,point+direction*(3.0 if reduced_motion else 14.0+float(i%5)*4.0+tier*10.0),HOT_GOLD if i%3==0 else GOLD,alpha,2.0)
	if age < 0.35:
		_glow(CENTER,53.0,HOT_GOLD,0.28*(1.0-age/0.35)*amount)
	if age < 1.0 and not reduced_motion:
		var sweep: float = lerpf(-64.0,64.0,clampf(age/1.0,0.0,1.0))
		_stroke(CENTER+Vector2(sweep-12.0,-62.0),CENTER+Vector2(sweep+12.0,62.0),HOT_GOLD,sinf(age*PI)*0.75*amount,3.0)
	draw_rect(Rect2(CENTER-Vector2.ONE*70.0,Vector2.ONE*140.0),Color(GOLD,(0.28+tier*0.30)*amount),false,1.5)

func _destroy(age: float, amount: float) -> void:
	var tint := Color("ff794c")
	var fade: float = exp(-age*2.8)*amount
	var shards: int = 9 if low_detail else 18
	for i: int in range(shards):
		var direction := Vector2.from_angle(float(i)*2.399)
		var origin: Vector2 = CENTER+direction*22
		var point: Vector2 = origin+direction*(age*100 if not reduced_motion else 32.0)
		_stroke(point,point+direction.rotated(0.6)*18,tint,fade,2)
		_stroke(CENTER+direction*8,CENTER+direction*62,tint,fade,1)
	_glow(CENTER,94,tint,fade*0.5)
	# Smoke collapses into an empty slot; only destroy hides the item.
	if not reduced_motion:
		for i: int in range(5):
			var smoke := CENTER+Vector2(sin(float(i)*2.7)*25,-age*40-float(i)*12)
			draw_circle(smoke,15+age*12,Color(0.055,0.047,0.055,fade*0.5))
