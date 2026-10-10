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

func update_pose() -> void:
	if not is_instance_valid(actor): return
	var material := actor.sprite.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("gait",actor.motion.gait)
		material.set_shader_parameter("move_amount",minf(1.0,actor.motion.move_ratio))
		material.set_shader_parameter("strike",sin(actor.motion.visual_progress*PI) if actor.motion.active else 0.0)
		material.set_shader_parameter("facing",float(actor.motion.facing8))
		var facing_scale: float = .84 if actor.motion.facing8 in [2,6] else (.93 if actor.motion.facing8 % 2 == 1 else 1.)
		actor.sprite.scale.x *= facing_scale * float(visual.get("width",1.))
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(actor): return
	if warning_active:
		var center: Vector2 = to_local(warning_center)
		var radius: float = float(special.get("radius",200))
		var color := Color(1.,.24,.10,.18+.15*warning_progress)
		var kind: String = str(special.get("kind","nova"))
		if kind=="cone":
			var points := PackedVector2Array([center])
			for i: int in range(17): points.append(center+warning_aim.rotated(-.55+float(i)*1.1/16.)*radius*2.)
			draw_colored_polygon(points,color)
			points.append(center)
			draw_polyline(points,Color(1,.45,.18,.8),2.,true)
		elif kind in ["beam","charge"]:
			var aim: Vector2 = warning_aim.normalized()
			var side: Vector2 = aim.orthogonal() * (55. if kind != "cone" else 95.)
			var points := PackedVector2Array([center-side,center+side,center+aim*radius*2.+side,center+aim*radius*2.-side])
			draw_colored_polygon(points,color)
			draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),Color(1,.45,.18,.8),2.,true)
		else:
			draw_circle(center,radius,color)
			draw_arc(center,radius,0.,TAU,64,Color(1,.42,.18,.85),2.,true)
			draw_arc(center,radius*.90,-PI*.5,-PI*.5+TAU*warning_progress,48,Color(1,.8,.3),3.,true)
	if actor.dead: return
	# Source-only normal monsters must not acquire the old invented weapons
	# and crests. Boss warning geometry remains above this early return.
	if original_source: return
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
		var weapon: String = str(visual.get("weapon","claws"))
		if weapon in ["sword","axe"]:
			var swing: Vector2 = aim.rotated(lerpf(-1.5,.85,p))
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
				draw_line(origin+offset+aim*18.,origin+offset+aim*(24.+p*23.),Color(1,.82,.54,.7),2.,true)
