extends SceneTree
const STATE=preload("res://scripts/ui/original_ui/source_particle_state.gd")
const RANDOM_VALUES=[-0.83,0.12,0.94,-0.47,0.33,-0.02,0.71,-0.61,0.05,0.55,-0.29,0.88,-0.76,0.22,0.44,-0.11,0.67,-0.95,0.38]
var random_index: int=0
var checks: int=0
var failures: int=0
var errors: Array[String]=[]
func random_signed() -> float:
	var value: float=RANDOM_VALUES[random_index%RANDOM_VALUES.size()]
	random_index+=1
	return value
func check(value: bool, description: String) -> void:
	checks+=1
	if not value:
		failures+=1
		if errors.size()<20:errors.append(description)
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var originals: Array=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var reference: Array=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if originals.size()!=reference.size():quit(2);return
	for case: int in range(originals.size()):
		random_index=0
		var state=STATE.new()
		check(state.configure(originals[case].values,random_signed).ok,"configure")
		check(originals[case].member==reference[case].member,"source case identity")
		for frame: int in range(reference[case].frames.size()):
			state.step(1.0/60.0)
			var expected: Dictionary=reference[case].frames[frame]
			var label: String=str(case)+":"+str(frame)
			check(state.particles.size()==int(expected.count),label+":count")
			check(state.active==expected.active,label+":active")
			check(absf(state.elapsed-float(expected.elapsed))<0.000002,label+":elapsed")
			check(absf(state.emit_counter-float(expected.counter))<0.000002,label+":counter")
			for index: int in range(mini(state.particles.size(),expected.particles.size())):
				var p: Dictionary=state.particles[index]
				var velocity: Vector2=p.get("velocity",Vector2.ZERO)
				var actual: Array=[p.life,p.position.x,p.position.y,velocity.x,velocity.y,p.size,p.rotation,p.color.r,p.color.g,p.color.b,p.color.a,p.get("radius",0.0),p.get("angle",0.0)]
				for field: int in range(actual.size()):
					var target: float=float(expected.particles[index][field])
					check(absf(float(actual[field])-target)<=maxf(0.0002,absf(target)*0.00001),label+":"+str(index)+":"+str(field)+":"+str(actual[field])+" != "+str(target))
	print("ORIGINAL_PARTICLE_REFERENCE "+JSON.stringify({"checks":checks,"failures":failures,"first_errors":errors,"scope":"unmodified upstream initParticle/update bodies, original plist values, injected identical test random sequence; no claim of original client RNG seed"}))
	quit(0 if failures==0 else 1)
