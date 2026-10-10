extends SceneTree
const AI = preload("res://scripts/monsters/monster_ai_policy.gd")
const MONSTER = preload("res://scripts/monster.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("MONSTER_AI_FAIL: "+label)

func _run() -> void:
	# field, safe, hidden, monster_home, player_home, player_distance,
	# aggro_remaining, aggro_radius, leash
	_check(not AI.should_disengage(false,false,false,1100,2000,2000,2,550,1050),"legacy maps preserve existing combat behavior")
	_check(AI.should_disengage(true,true,false,0,0,100,2,550,1050),"safe-zone player triggers retreat")
	_check(AI.should_disengage(true,false,true,0,0,100,2,550,1050),"concealment breaks monster pursuit")
	_check(AI.should_disengage(true,false,false,1051,0,200,2,550,1050),"monster outside home leash disengages")
	_check(AI.should_disengage(true,false,false,100,1051,200,2,550,1050),"player outside home leash disengages")
	_check(AI.should_disengage(true,false,false,100,100,940,1.5,550,1050),"lost aggro target after 1.7x chase radius returns home")
	_check(not AI.should_disengage(true,false,false,100,100,940,0,550,1050),"unprovoked distant player does not interrupt ordinary roaming")
	_check(not AI.should_disengage(true,false,false,100,100,400,2,550,1050),"close active combat remains unchanged")
	_check(AI.should_keep_returning(true,100),"return state remains sticky until spawn point")
	_check(not AI.should_keep_returning(true,AI.RETURN_RADIUS),"return state clears at home radius")
	_check(not AI.should_keep_returning(false,100),"idle monster never enters return state by itself")
	var elapsed: float = 0.0
	for step: int in range(5):
		elapsed = AI.next_stuck_elapsed(elapsed,0.0,90.0,0.15)
	_check(AI.should_repath(elapsed),"blocked motion requests new path after retry interval")
	_check(not AI.should_repath(0.32),"one blocked frame does not thrash pathfinding")
	_check(AI.next_stuck_elapsed(elapsed,2.0,90.0,0.033) == 0.0,"successful movement clears stuck timer")
	_check(AI.next_stuck_elapsed(elapsed,0.0,0.0,0.033) == 0.0,"idle actor is never marked stuck")
	var instance: TwilightMonster = MONSTER.new()
	_check(instance != null,"main TwilightMonster scene script still instantiates")
	_check(instance.has_method("_tick_ai") and instance.has_method("_move_toward"),"existing combat/animation entrypoints preserved")
	instance.free()
	if failures.is_empty():
		print("MONSTER_AI_OK: leash, stealth, safe zones, sticky return, obstacle repath and unchanged attack interfaces")
		quit(0)
	else:
		print("MONSTER_AI_FAILED: %d issues" % failures.size())
		quit(1)
