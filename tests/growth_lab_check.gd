extends SceneTree
var failures: Array[String] = []
var checks: int = 0
var world
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); print("LAB_FAIL: "+message)
func act(action: String,id: String="",count: int=1) -> Dictionary:
	return world.growth.execute(action,id,count,int(world.growth.state.revision))
func _run() -> void:
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	var rt=world.growth
	check(rt.development,"explicit --growth-lab required")
	if not rt.development: quit(1); return
	check(world.save_path().ends_with("twilight_growth_lab_v1.json"),"isolated save path")
	check(not rt.validate(rt.fresh()).is_empty(),"ordinary save rejected in lab")
	check(rt.state.points==1000000,"new lab starts with test materials")
	check(rt.cost_for("eva",0)==20 and rt.cost_for("grankain",0)==30 and rt.cost_for("shilen",0)==45,"historical cost categories")
	var points: int=rt.state.points
	check(act("enhance","eva").ok,"actual lab single enhancement")
	check(rt.state.points==points-20,"lab single cost")
	check(act("enhance","eva",5).ok and rt.progress("eva").attempts==6,"actual lab five enhancement")
	check(act("reset","eva").ok and rt.state.points==points,"enhancement refund")
	check(not act("activate","joe_0").ok,"prerequisite chain blocks")
	check(act("activate","joe_stat").ok,"first lab node opens cards")
	var loser: int=(int(rt.state.searches.joe_stat.winner)+1)%3
	check(act("choose","",loser).ok,"losing card reveals")
	world._load_game(true)
	check(rt.state.searches.joe_stat.failed.has(loser),"failed card durable")
	check(act("activate","joe_stat").ok,"retry")
	world._load_game(true)
	check(rt.state.pending.node=="joe_stat","pending durable")
	check(not act("choose","",loser).ok,"failed card stays unavailable")
	check(act("choose","",int(rt.state.searches.joe_stat.winner)).ok,"win first node")
	check(act("activate","joe_0").ok,"connected node unlock")
	check(act("choose","",int(rt.state.searches.joe_0.winner)).ok,"win skill")
	var hp: int=world._effective_max_hp()
	check(act("representative","joe_0").ok,"representative selection")
	check(world._effective_max_hp()==hp+10,"two synthetic HP effects applied")
	# Explicit fixture only to reach endgame without relying on random progression.
	var fixture: Dictionary=rt.state.duplicate(true)
	for id: String in ["eva","grankain","einhasad","sayha"]:
		fixture.emblems[id]={"stage":30,"attempts":20,"spent":0,"guaranteed":false}
	rt.restore(fixture)
	check(rt.bonus("potion_cooldown:percent")==10,"Eva cooldown milestone")
	check(rt.incoming_damage(100)==90,"Grankain damage reduction")
	check(rt.stat_record().blessing_consumption_reduction_pct==8,"Sayha Ain consumption integration record")
	check(rt.bonus("blessing_charge:percent")==90,"Einhasad charge milestone")
	check(rt.bonus("mp_regeneration:flat")==5,"Sayha regeneration milestone")
	var keys: int=world.inventory["축복의 열쇠"]
	var hp_absolute: int=world._effective_max_hp()
	for i: int in range(5): check(act("absolute","eva").ok,"absolute tier "+str(i+1))
	check(world.inventory["축복의 열쇠"]==keys-838,"official five key costs")
	check(world._effective_max_hp()==hp_absolute+25,"explicit synthetic absolute effects")
	check(not act("absolute","eva").ok,"tier V cap")
	world._load_game(true)
	check(rt.progress("eva").absolute==5,"absolute durable")
	check(act("buy_key").ok,"point shop purchase")
	check(act("reset","eva").ok and rt.progress("eva").absolute==0,"lab reset clears absolute")
	world.queue_free()
	await process_frame
	print("GROWTH_LAB_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
