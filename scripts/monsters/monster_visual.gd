extends Node2D
class_name TwilightMonsterVisual

var actor: TwilightMonster
var visual: Dictionary = {}
var special: Dictionary = {}
var warning_center: Vector2 = Vector2.ZERO
var warning_aim: Vector2 = Vector2.RIGHT
var warning_progress: float = 0.0
var warning_active: bool = false
var original_source: bool = false

const GEOMETRY = preload("res://scripts/monsters/boss_geometry.gd")
const IMPACT = preload("res://scripts/animation/impact_visuals.gd")
var effect_age: float = -1.0
var effect_duration: float = 0.48
var warning_sequence: int = -1
var warning_outline := PackedVector2Array()
var effect_outline := PackedVector2Array()
var effect_center: Vector2
var effect_aim: Vector2
var effect_kind: String = ""
var effect_radius: float = 0.0
var effect_texture: Texture2D
var effect_body: Transform2D
var color := Color(1.0, 0.42, 0.18)
var effect_scale: float = 1.0
var impacts = IMPACT.new()
static var detail_frame: int = -1
static var detail_count: int = 0
const DETAIL_LIMIT: int = 8

func reset_presentation() -> void:
	effect_age = -1.0
	warning_sequence = -1
	warning_outline.clear()
	effect_outline.clear()
	effect_texture = null
	var settings: Dictionary = actor.motion.profile.presentation
	color = Color(str(settings.get("effect_color", visual.get("accent", "ed893e"))))
	effect_scale = clampf(float(settings.get("effect_scale", 1.0)), 0.5, 1.6)
	impacts.prepare()

func prepare_warning() -> void:
	warning_sequence = actor.motion.sequence
	warning_outline = GEOMETRY.outline(str(special.get("kind", "nova")), float(special.get("radius", 200)), warning_aim)
	queue_redraw()

func release_special() -> void:
	# Called only by the existing successful special-release marker, not by draw.
	warning_active = false
	effect_age = 0.0
	effect_center = warning_center
	effect_aim = warning_aim
	effect_kind = str(special.get("kind", "nova"))
	effect_radius = float(special.get("radius", 200))
	effect_outline = warning_outline
	# Snapshot the facing and pose once; recovery must not animate the trail.
	effect_texture = actor.sprite.texture
	effect_body = actor.sprite.transform.scaled_local(Vector2(-1.0 if actor.sprite.flip_h else 1.0, -1.0 if actor.sprite.flip_v else 1.0))
	queue_redraw()

func tick(delta: float) -> void:
	if warning_active and (actor.dead or not actor.motion.active or actor.motion.sequence != warning_sequence):
		warning_active = false
		queue_redraw()
	if actor.dead:
		effect_age = -1.0
	elif effect_age >= 0.0:
		effect_age += maxf(0.0, delta)
		if effect_age >= effect_duration: effect_age = -1.0
		queue_redraw()

func update_pose() -> void:
	if not is_instance_valid(actor): return
	var material := actor.sprite.material as ShaderMaterial
	if material != null and material.shader == preload("res://scripts/monsters/monster_body.gdshader"):
		material.set_shader_parameter("gait", actor.motion.stride_phase / PI)
		material.set_shader_parameter("move_amount", minf(1.0, actor.motion.locomotion_weight) if not actor.motion.active and not actor.dead else 0.0)
		material.set_shader_parameter("strike", IMPACT.swing_envelope(actor.motion.visual_progress, actor.motion.attack_hit_ratio) if actor.motion.active else 0.0)
		material.set_shader_parameter("facing", float(actor.motion.facing8))
		material.set_shader_parameter("body_mode", 1.0 if actor.motion.profile.body_kind == "beast" else (2.0 if actor.motion.profile.body_kind in ["flying", "spirit", "special"] else 0.0))
		# Native directions are selected by ActorMotion, never warped into fake views.
		var facing_scale: float = .94 if actor.motion.facing8 in [2,6] else (.97 if actor.motion.facing8 % 2 == 1 else 1.0)
		actor.sprite.scale.x *= facing_scale * float(visual.get("width",1.0))
	queue_redraw()

func _shape(points: PackedVector2Array, center: Vector2, tint: Color, fill: float) -> void:
	if points.size() < 3: return
	draw_set_transform(center)
	draw_colored_polygon(points, Color(tint, fill))
	var edge: PackedVector2Array = points.duplicate()
	edge.append(points[0])
	draw_polyline(edge, tint, 2.0, true)
	draw_set_transform(Vector2.ZERO)

func _draw_warning() -> void:
	var center: Vector2 = to_local(warning_center)
	var p: float = warning_progress
	if not warning_outline.is_empty():
		_shape(warning_outline, center, Color(1.0, .55, .22, .78), .06 + .10 * p)
	else:
		# Summon and volley have no area hit. A compact ritual/aim glyph must not
		# pretend that their old radius parameter describes a damaging circle.
		draw_arc(center, 28.0, 0.0, TAU, 32, Color(color, .65), 1.7, true)
		if str(special.get("kind", "")) == "volley":
			draw_line(center, center + warning_aim * 72.0, Color(color, .8), 2.0, true)
	draw_arc(center, 24.0, -PI * .5, -PI * .5 + TAU * p, 32, Color(1.0, .85, .48, .9), 2.5, true)
	# Charge light stays on the torso; the ground boundary stays world anchored.
	impacts.halo(self, Vector2(0, -actor.visual_height * .5), Vector2.ONE * (26.0 + p * 18.0) * effect_scale, Color(color, .12 + .22 * p))

func _draw_release() -> void:
	var p: float = clampf(effect_age / effect_duration, 0.0, 1.0)
	var alpha: float = (1.0 - p) * (1.0 - p)
	var center: Vector2 = to_local(effect_center)
	_shape(effect_outline, center, Color(color, alpha * .8), alpha * .09)
	match effect_kind:
		"beam", "charge":
			var length: float = effect_radius * 2.0
			if effect_kind == "beam":
				draw_line(center, center + effect_aim * length, Color(color, alpha * .8), 12.0 * (1.0 - p), true)
				draw_line(center, center + effect_aim * length, Color(1.0, .96, .83, alpha), 3.0, true)
			else:
				# Frozen copies of the existing body form a short dash trail. No nodes.
				if effect_texture != null:
					for i: int in range(3):
						var point: Vector2 = effect_center.lerp(actor.global_position, float(i + 1) / 4.0)
						var pose: Transform2D = effect_body
						pose.origin += to_local(point)
						draw_set_transform_matrix(pose)
						draw_texture(effect_texture, -effect_texture.get_size() * .5, Color(color, alpha * .16))
						draw_set_transform(Vector2.ZERO)
		"cone":
			var r: float = effect_radius * 2.0 * (.20 + .80 * p)
			draw_arc(center, r, effect_aim.angle() - GEOMETRY.HALF_ANGLE, effect_aim.angle() + GEOMETRY.HALF_ANGLE, 32, Color(color, alpha), 4.0, true)
		"summon":
			for radius: float in [26.0, 40.0]:
				draw_arc(center, radius * (1.0 + p * .4), p, TAU + p, 32, Color(color, alpha), 2.0, true)
			for i: int in range(6):
				var ray: Vector2 = Vector2.from_angle(float(i) * TAU / 6.0)
				draw_line(center + ray * 22.0, center + ray * 44.0, Color(color, alpha), 2.0, true)
		"volley":
			# Release glints only; CombatFlights still owns all three real arrows.
			for i: int in range(3):
				var flash: float = maxf(0.0, 1.0 - absf(effect_age - float(i) * .14) / .08)
				impacts.beam(self, Vector2(0, -actor.visual_height * .5) + effect_aim * 24.0, effect_aim, 18.0, 2.0, Color(color, flash))
		"drain":
			for i: int in range(8):
				var ray: Vector2 = Vector2.from_angle(float(i) * TAU / 8.0 + p)
				draw_line(center + ray * effect_radius * (1.0 - p), center + ray * effect_radius * maxf(0.0, .8 - p), Color(color, alpha), 2.5, true)
		_:
			draw_arc(center, effect_radius * (.15 + .85 * p), 0.0, TAU, 48, Color(color, alpha), 4.0, true)
	impacts.halo(self, center, Vector2.ONE * 64.0 * effect_scale, Color(color, alpha * .45))

func _draw() -> void:
	if not is_instance_valid(actor): return
	var bounds: Rect2 = get_viewport_rect().grow(maxf(actor.visual_height, float(special.get("radius", 0)) * 2.0 + 32.0))
	var canvas: Transform2D = get_global_transform_with_canvas()
	if not bounds.has_point(canvas.origin) and (effect_age < 0.0 or not bounds.has_point(canvas * to_local(effect_center))): return
	var frame: int = Engine.get_process_frames()
	if frame != detail_frame:
		detail_frame = frame
		detail_count = 0
	if warning_active: _draw_warning()
	if effect_age >= 0.0:
		if detail_count < DETAIL_LIMIT:
			detail_count += 1
			_draw_release()
		else:
			_shape(effect_outline, to_local(effect_center), Color(color, .35 * (1.0 - effect_age / effect_duration)), .03)
	if actor.is_boss and not actor.dead and actor.motion.hit_clock > 0.0 and actor.motion.hit_strength > 1.0:
		var p: float = 1.0 - actor.motion.hit_clock / actor.motion.hit_duration
		draw_arc(Vector2(0, -actor.visual_height * .35), actor.visual_height * (.18 + .12 * p), 0.0, TAU, 24, Color(1.0, .79, .45, (1.0 - p) * .45), 1.5, true)
	if actor.dead and actor.is_boss:
		var p: float = clampf(actor.motion.death_clock, 0.0, 1.0)
		var alpha: float = sin(p * PI) * .45
		var rise: float = -1.0 if str(actor.motion.profile.presentation.get("death_animation", "collapse")) == "dissolve" else .25
		draw_arc(Vector2.ZERO, actor.visual_height * (.25 + p * .35), 0.0, TAU, 40, Color(color, alpha), 2.0, true)
		for i: int in range(6):
			var ray: Vector2 = Vector2.from_angle(float(i) * TAU / 6.0)
			draw_circle(ray * actor.visual_height * p * .4 + Vector2(0, p * 28.0 * rise), 1.7, Color(color, alpha))
	if actor.dead: return
	# Source-only normal monsters must not acquire the old invented weapons
	# and crests. Boss warning geometry remains above this early return.
	if original_source or actor.motion.frame_source != null: return
	# The dedicated ritual/charge renderer owns special presentation. Do not
	# draw a second generic sword or purple staff ring over the same cast.
	if actor.motion.active and actor.motion.action_role == "special": return
	var body: String = str(visual.get("body",""))
	var height: float = actor.visual_height
	var accent := Color(str(visual.get("accent","c4aa64")))
	var origin := Vector2(0,-height*.54)
	# Small species-specific heraldry augments original bodies, rather than replacing
	# them with a shape. Gear participates in the same strike marker as damage.
	if body in ["dark_knight","commander","orc","orc_captain","skeleton","bandit","mage"]:
		var crest: int = int(visual.get("crest",0))
		for i: int in range(crest+1):
			draw_line(Vector2(-7+i*3,-height*.80),Vector2(-7+i*3,-height*.88-float(crest)),accent,1.7,true)
	if actor.motion.active:
		var aim: Vector2 = actor.motion.direction
		var p: float = actor.motion.visual_progress
		var strike: float = IMPACT.swing_envelope(p, actor.motion.attack_hit_ratio)
		var swing_phase: float = .65 * clampf(p / actor.motion.attack_hit_ratio, 0.0, 1.0) if p <= actor.motion.attack_hit_ratio else .65 + .35 * (p - actor.motion.attack_hit_ratio) / (1.0 - actor.motion.attack_hit_ratio)
		var weapon: String = str(visual.get("weapon","claws"))
		if weapon in ["sword","axe"]:
			var swing: Vector2 = aim.rotated(lerpf(-1.5,.85,swing_phase))
			var grip: Vector2 = origin+swing*height*.22
			var tip: Vector2 = origin+swing*height*.60
			draw_line(grip,tip,Color(.88,.9,.91),3. if weapon=="sword" else 5.,true)
			draw_line(grip-swing.orthogonal()*5,grip+swing.orthogonal()*5,accent,2.,true)
			if weapon=="axe": draw_arc(tip,9,swing.angle()-.8,swing.angle()+.8,8,accent,5.,true)
		elif weapon == "bow":
			draw_arc(origin+aim*16,15,aim.angle()-1.1,aim.angle()+1.1,10,accent,2.,true)
			draw_line(origin+aim*4,origin+aim*35,Color(1,.84,.5),1.5,true)
		elif weapon == "staff":
			draw_arc(origin,13.+p*8.,0.,TAU,24,Color(.64,.5,1.,.8),2.,true)
		else:
			for i: int in range(3):
				var offset: Vector2 = aim.orthogonal()*float(i-1)*6.
				draw_line(origin+offset+aim*18.,origin+offset+aim*(24.+p*23.),Color(1,.82,.54,.65 * strike),2.,true)
