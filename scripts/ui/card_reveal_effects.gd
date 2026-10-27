extends Control

# Aura, card-surface lightning and particles have independent clocks. A parent
# clips only the surface pass; aura and embers remain outside the card.
const PROFILES = preload("res://scripts/ui/card_reveal_profiles.gd")
var grade: String = "희귀"
var elapsed: float = -1.0
var clock: float = 0.0
var surface: bool = false
var extra_lightning_seconds: float=0.0
var reduced_motion: bool = false
var detail_scale: float = 1.0
var intensity_scale: float = 1.0
static var light_texture: ImageTexture
static var smoke_texture: ImageTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	_ensure_textures()

static func _seed(value: float) -> float:
	return fposmod(sin(value*127.1+311.7)*43758.5453,1.0)

static func _ensure_textures() -> void:
	if light_texture != null:
		return
	var light := Image.create(96,96,false,Image.FORMAT_RGBA8)
	var smoke := Image.create(128,128,false,Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 4671
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	for y: int in range(128):
		for x: int in range(128):
			var r: float = Vector2(x-64,y-64).length()/64.0
			var n: float = noise.get_noise_2d(x,y)*0.5+0.5
			smoke.set_pixel(x,y,Color(1,1,1,clampf((n-0.22)*1.8,0,1)*pow(maxf(0,1-r),1.4)))
	for y: int in range(96):
		for x: int in range(96):
			var r: float = Vector2(x-48,y-48).length()/48.0
			light.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-r),2.0)))
	light_texture = ImageTexture.create_from_image(light)
	smoke_texture = ImageTexture.create_from_image(smoke)

func set_time(value: float, absolute_time: float) -> void:
	var refresh: bool=not surface or extra_lightning_seconds<=0 or floori(elapsed*30)!=floori(value*30)
	elapsed = value
	clock = absolute_time
	if refresh:queue_redraw()

func _glow(center: Vector2, radius: Vector2, tint: Color, alpha: float) -> void:
	if alpha > 0.001:
		draw_texture_rect(light_texture,Rect2(center-radius,radius*2.0),false,Color(tint,alpha))

func _bolt(points: PackedVector2Array, tint: Color, power: float, width: float, compact: bool=false) -> void:
	if compact:
		draw_polyline(points,Color(tint,minf(power,1.0)),width,true)
		draw_polyline(points,Color(Color("eefff7"),minf(1.0,power*.84)),maxf(.65,width*.31),true)
		return
	draw_polyline(points,Color(tint,power*0.07),width*7.0,true)
	draw_polyline(points,Color(tint,power*0.24),width*3.0,true)
	draw_polyline(points,Color(tint,minf(power,1.0)),width,true)
	draw_polyline(points,Color(Color("eefff7"),minf(1.0,power*0.84)),maxf(0.65,width*0.31),true)

func _path(a: Vector2, b: Vector2, salt: float, amount: float) -> PackedVector2Array:
	var points := PackedVector2Array([a,b])
	var pulse_id: int = int(elapsed*(30.0 if extra_lightning_seconds>0 else 55.0))
	for depth: int in range(4):
		var next := PackedVector2Array([points[0]])
		for j: int in range(points.size()-1):
			var mid: Vector2 = points[j].lerp(points[j+1],0.38+_seed(j*31+depth*53+salt+pulse_id*19)*0.24)
			mid.x += (_seed(j*71+depth*9+salt+pulse_id*43)-0.5)*amount*pow(0.48,depth)
			next.append(mid)
			next.append(points[j+1])
		points = next
	return points

func _draw() -> void:
	if light_texture == null or elapsed < -0.3 or size.x < 1:
		return
	var p: Dictionary = PROFILES.profile(grade)
	var tint: Color = PROFILES.color(grade)
	var tier: int = int(p.get("tier",0))
	if surface:
		_draw_surface(p,tint,tier)
	else:
		_draw_aura(p,tint,tier)

func _draw_surface(p: Dictionary, tint: Color, tier: int) -> void:
	var burst: float = PROFILES.pulse(grade,elapsed,extra_lightning_seconds)
	if reduced_motion:
		burst *= 0.20
	if burst < 0.008:
		return
	var power: float = burst*detail_scale*intensity_scale
	var center: Vector2 = size*Vector2(0.5,0.43)
	draw_rect(Rect2(Vector2.ZERO,size),Color(tint,minf(0.38,power*0.15)))
	_glow(center,size*Vector2(0.78,0.76),tint,minf(0.82,power*0.62))
	var pulse_id: int = int(elapsed*(30.0 if extra_lightning_seconds>0 else 55.0))
	var count: int = int(p.get("bolts",1))
	var enhanced: bool=extra_lightning_seconds>0
	var forks: int=int(p.get("branches",0))
	if enhanced:
		count=maxi(1,ceili(count*clampf(detail_scale,.25,1.0)))
		forks=mini(8,forks+2)
		# At most 56 paths per card, fewer in mobile/multi-card mode.
		forks=mini(forks,maxi(1,int(56.0*clampf(detail_scale,.25,1.0))/count-1))
	var thickness: float=1.65 if enhanced else 1.0
	if reduced_motion:
		count = 1
		if enhanced:forks=1
	for bolt: int in range(count):
		var top := Vector2(size.x*(0.12+_seed(27+bolt*19+pulse_id)*0.76),size.y*0.02)
		var foot := Vector2(size.x*(0.16+_seed(92+bolt*7+pulse_id)*0.68),size.y*(0.73+_seed(bolt+8)*0.22))
		var points: PackedVector2Array = _path(top,foot,bolt*113,size.x*0.62)
		var alpha: float = power*(0.96 if bolt == 0 else 0.57)
		_bolt(points,tint,alpha,maxf(1.2,size.x*0.013)*thickness)
		for fork: int in range(forks):
			var origin: Vector2 = points[3+(bolt*3+fork*5)%11]
			var direction: float = 1.0 if (bolt+fork)%2 else -1.0
			var end: Vector2 = origin+Vector2(direction*size.x*(0.20+fork*0.045),size.y*(0.10+fork*0.025))
			_bolt(_path(origin,end,513+bolt+fork*33,size.x*0.18),tint,alpha*0.65/(1+fork*0.15),maxf(0.8,size.x*0.006)*thickness,enhanced)
	_glow(center,size*Vector2(0.40,0.34),Color("fffdef"),minf(0.34,burst*0.24))
	if tier >= 3:
		for j: int in range(int(p.get("flare",0))):
			var at: Vector2 = size*Vector2(_seed(j+51),fposmod(_seed(j+72)+elapsed*0.4,1.0))
			draw_line(at,at+Vector2(size.x*0.03,-size.y*(0.1+_seed(j+5)*0.18)*burst),Color(tint,power*0.46),1.3,true)

func _draw_aura(p: Dictionary, tint: Color, tier: int) -> void:
	var card: Rect2 = Rect2(size*Vector2(0.25,0.20),size*Vector2(0.5,0.6))
	var strength: float = smoothstep(-0.12,0.35,elapsed)*(0.24+tier*0.19)*detail_scale*intensity_scale
	if strength <= 0:
		return
	var c: Vector2 = card.get_center()
	_glow(c,card.size*Vector2(0.9+tier*0.06,0.86),tint,0.32*strength)
	var count: int = int(float(p.get("smoke",12))*detail_scale)
	for i: int in range(count):
		var phase: float = fposmod(clock*(0.21+_seed(i+12)*0.09)+_seed(i+71),1.0)
		var side: float = 1 if i%2 else -1
		var at: Vector2 = Vector2(c.x+side*card.size.x*(0.41+_seed(i+103)*0.11)+sin(clock*1.6+i*0.94)*card.size.x*0.055,card.end.y+card.size.y*0.12-phase*card.size.y*1.45)
		var extent: Vector2 = card.size.x*Vector2(0.52,0.69)*(1+_seed(i+204)*0.6)*(1+phase*0.3)
		draw_set_transform(at,sin(clock*0.3+i)*0.8)
		draw_texture_rect(smoke_texture,Rect2(-extent*0.5,extent),false,Color(tint,sin(phase*PI)*(0.09+_seed(i+42)*0.19)*strength))
	draw_set_transform(Vector2.ZERO)
	# Particle emission and disappearance are independent of lightning pulses.
	if elapsed >= 0.0 and elapsed <= 2.2 and not reduced_motion:
		for i: int in range(int(float(p.get("embers",14))*detail_scale)):
			var angle: float = _seed(i+90)*TAU
			var speed: float = 20+_seed(i+7)*card.size.x*0.8
			var at: Vector2 = c+Vector2(cos(angle),sin(angle))*elapsed*speed+Vector2(0,-elapsed*elapsed*32)
			var a: float = pow(1-elapsed/2.2,2)*_seed(i+22)*0.85
			_glow(at,Vector2(4,4),tint,a*0.42)
			draw_circle(at,0.7+_seed(i+62)*1.3,Color(tint,a))
