extends SceneTree
const RESOLVE = preload("res://scripts/combat/physical_resolution.gd")
var issues: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, name: String) -> void:
	if not ok:
		issues.append(name)
		printerr("COMBAT_RESOLUTION_FAIL: "+name)

func _run() -> void:
	var compared: int = 0
	for accuracy: int in [0,5,35,75,150,350]:
		for ac: int in [-300,-80,-25,-10,0,40,160]:
			for avoidance: int in [-25,0,12,50,120]:
				var base_percent: float = 75.0 + float(accuracy - absi(ac)) * 0.7
				var expected: float = clampf((base_percent - float(maxi(0,avoidance))) / 100.0,0.05,0.95)
				var actual: float = RESOLVE.physical_hit_chance(accuracy,ac,avoidance)
				_check(is_equal_approx(expected,actual),"physical hit mismatch accuracy/ac/evasion %d/%d/%d" % [accuracy,ac,avoidance])
				compared += 1
	for accuracy: int in [0,5,35,75,150,350]:
		for mr: int in [-10,0,15,50,200,500]:
			var expected: float = clampf((75.0 + float(accuracy-maxi(0,mr))*0.7)/100.0,0.05,0.95)
			_check(is_equal_approx(RESOLVE.magic_hit_chance(accuracy,mr),expected),"magic MR hit chance must exactly match legacy formula")
			compared += 1
	for incoming: int in [0,1,20,120,500]:
		for reduction: int in [0,1,10,70,250]:
			for buff: int in [0,1,12,100]:
				var expected: int = maxi(1,incoming-reduction-buff)
				_check(RESOLVE.physical_after_flat_reduction(incoming,reduction,buff) == expected,"flat reduction must be applied exactly once")
				compared += 1
	_check(RESOLVE.physical_hit_chance(100,-40,10) == RESOLVE.physical_hit_chance(100,40,10),"AC sign normalization preserved")
	var damage: int = RESOLVE.physical_after_flat_reduction(100,8,2)
	_check(damage == 90,"incoming raw 100 with reduction 8+2 -> 90")
	_check(RESOLVE.physical_hit_chance(100,-70,10) < RESOLVE.physical_hit_chance(100,-10,10),"AC affects hit chance, not damage")
	_check(damage == 90,"changing only AC must not double-deduct attack damage")
	if issues.is_empty():
		print("COMBAT_RESOLUTION_OK: %d exact formula comparisons, separate AC/MR hit and one reduction stage" % compared)
		quit(0)
	else:
		print("COMBAT_RESOLUTION_FAILED: %d issues" % issues.size())
		quit(1)
