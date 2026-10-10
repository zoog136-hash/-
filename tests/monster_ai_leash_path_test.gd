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
	# Social help is bounded and never overrides concealment, safe areas,
	# empty factions, the individual leash, or the monster's return state.
	_check(AI.MAX_SOCIAL_ASSIST == 4,"at most four nearby allies answer one hit")
	_check(AI.can_assist("ant","ant",90,120,160,760,180,false,false,false),"nearby same-pack member may assist")
	_check(not AI.can_assist("","",90,120,160,760,180,false,false,false),"empty groups cannot summon unrelated creatures")
	_check(not AI.can_assist("ant","orc",90,120,160,760,180,false,false,false),"unrelated species cannot join the pack")
	_check(not AI.can_assist("ant","ant",181,120,160,760,180,false,false,false),"out-of-hearing ally ignored")
	_check(not AI.can_assist("ant","ant",90,120,160,760,180,true,false,false),"safe player cannot trigger social chase")
	_check(not AI.can_assist("ant","ant",90,120,160,760,180,false,true,false),"hidden player cannot trigger social chase")
	_check(not AI.can_assist("ant","ant",90,120,160,760,180,false,false,true),"returning ally cannot be re-aggroed")
	_check(not AI.can_assist("ant","ant",90,120,761,760,180,false,false,false),"ally never helps outside home leash")
	# Local boss tactics: a single threshold transition, no attack outside
	# attackable state and no changes to the base animation timing markers.
	_check(not AI.should_enrage(false,10,100),"field monsters never enrage by default")
	_check(not AI.should_enrage(true,0,100),"dead bosses cannot enrage")
	_check(not AI.should_enrage(true,50,100),"healthy bosses use normal combat")
	_check(AI.should_enrage(true,35,100),"boss enrages at 35 percent HP")
	_check(AI.should_enrage(true,34,100),"wounded boss remains enraged")
	_check(not AI.should_enrage(true,20,100,{"enabled":false}),"boss enrage can be disabled by AI record")
	_check(AI.should_enrage(true,45,100,{"hp_ratio":0.45}),"boss threshold can be overridden per record")
	_check(AI.attack_interval(1.25,true)<AI.attack_interval(1.25,false),"enrage speeds up attacks")
	_check(AI.chase_speed_factor(true)>1.0 and AI.chase_speed_factor(false)==1.0,"enrage improves chase without teleportation")
	var instance: TwilightMonster = MONSTER.new()
	_check(instance != null,"main TwilightMonster scene script still instantiates")
	_check(instance.has_method("_tick_ai") and instance.has_method("_move_toward"),"existing combat/animation entrypoints preserved")
	_check(not instance.enraged and instance.social_alert_cooldown == 0.0,"recycled monster tactics default to neutral state")
	instance.free()
	if failures.is_empty():
		print("MONSTER_AI_OK: leash, stealth, safe zones, sticky return, obstacle repath and unchanged attack interfaces")
		quit(0)
	else:
		print("MONSTER_AI_FAILED: %d issues" % failures.size())
		quit(1)
