extends SceneTree
## Numeric fixture costs/node topology are TEST ONLY; not a claim about Lineage M.
var failures: Array[String] = []
var checks: int = 0
var world
const Growth = preload("res://scripts/growth/growth_runtime.gd")
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); print("GROWTH_FAIL: "+message)
func act(action: String, id: String = "", count: int = 1) -> Dictionary:
	return world.growth.execute(action,id,count,int(world.growth.state.revision))
func tap(button: Control) -> void:
	var position: Vector2 = button.get_global_transform_with_canvas()*(button.size/2)
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index=93
		event.position=position
		event.pressed=pressed
		root.push_input(event,true)

func _run() -> void:
	root.size=Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.hud.complete_class_selection()
	world.player.set_physics_process(false)
	var rt = world.growth
	check(rt.config.emblems.size()==7 and rt.config.guardians.size()==6,"official catalogue scope")
	check(rt.config.probabilities_by_target_stage.size()==30,"30 official probability rows")
	for row: Array in rt.config.probabilities_by_target_stage:
		check(absf(float(row[0])+float(row[1])+float(row[2])-100.0)<0.00001,"probability sum")
	check(not rt.quote("enhance","eva").ok,"unknown first cost blocks")
	check(not rt.quote("activate","joe_0").ok,"unknown official node blocks")
	check(not act("holy_water").ok,"insufficient inventory rejects")
	world.inventory["축복의 성수(중)"] = 3
	check(world._save_game(true)==OK,"baseline durable save")
	var revision: int = int(rt.state.revision)
	check(act("holy_water").ok and rt.state.points==100,"real inventory conversion")
	check(not rt.execute("holy_water","",1,revision).ok,"duplicate stale request rejects")
	check(world.inventory["축복의 성수(중)"]==2,"duplicate does not consume")
	var before: Dictionary = rt.state.duplicate(true)
	world.equipment_collections.test_save_writer = func(_p: String,_d: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not act("holy_water").ok,"save failure rejects")
	check(rt.state==before and world.inventory["축복의 성수(중)"]==2,"save failure rolls back state/material")
	world.equipment_collections.test_save_writer = Callable()
	world._load_game(true)
	check(rt.state.points==100 and world.inventory["축복의 성수(중)"]==2,"whole game reload")
	# Synthetic deterministic economy for behavioral coverage. Never shipped in config.
	rt.config.enhancement_costs.fill(1)
	rt.config.reset_cost = 1
	var hp_before: int = world._effective_max_hp()
	check(act("enhance","eva").ok,"single enhance")
	check(world._effective_max_hp()==hp_before+10*int(rt.progress("eva").stage),"HP effect reaches actual world")
	check(act("enhance","eva",5).ok and rt.progress("eva").attempts==6,"five enhance transaction")
	var spent: int = int(rt.progress("eva").spent)
	var points: int = int(rt.state.points)
	check(act("reroll","eva").ok,"reroll costs independently")
	check(rt.state.points==points-1 and rt.progress("eva").spent==spent,"reroll excluded from refund ledger")
	world.inventory["문양 초기화 두루마리"] = 1
	check(act("reset","eva").ok,"reset consumes scroll")
	check(rt.state.points==points-1+spent and world._effective_max_hp()==hp_before,"reset refund/stat removal")
	check(rt.progress("eva").stage==0 and rt.progress("eva").attempts==0,"reset stage/count")
	world.inventory["축복 부여 주문서(각인)"] = 2
	world.inventory["마력의 돌"] = 100
	check(act("craft_stone_engraved").ok and world.inventory["수호석"]==1,"official recipe exact consumption")
	var n: Dictionary = rt.config.guardians[0].nodes[1]
	n.prerequisites = []
	n.cost = 1
	n.cards = 3
	n.card_rule = "single_winner_without_replacement"
	n.effects = {"max_hp:flat":7}
	check(act("activate",n.id).ok,"activation persists paid pending outcome")
	check(world.inventory["수호석"]==0 and not rt.state.pending.is_empty(),"cost deducted once")
	check(not act("activate",n.id).ok,"second pending activation blocked")
	world._load_game(true)
	check(not rt.state.pending.is_empty(),"pending survives close/load")
	var loser: int = (int(rt.state.searches[n.id].winner)+1)%3
	check(act("choose","",loser).ok and not rt.state.nodes.has(n.id),"failed card removed without unlocking")
	world._load_game(true)
	check(rt.state.searches[n.id].failed.has(loser),"failed card persists across reload")
	world.inventory["수호석"] = 1
	check(act("activate",n.id).ok and world.inventory["수호석"]==0,"retry consumes another stone")
	check(not act("choose","",loser).ok,"failed card cannot be selected twice")
	check(act("choose","",int(rt.state.searches[n.id].winner)).ok and rt.state.nodes.has(n.id),"correct card unlocks")
	check(not act("choose","",2).ok,"duplicate reveal blocked")
	check(world._effective_max_hp()==hp_before,"unrepresented guardian gives no stats")
	check(act("representative",n.id).ok,"representative selection")
	check(world._effective_max_hp()==hp_before+7,"represented guardian applies effects")
	world._load_game(true)
	check(world._effective_max_hp()==hp_before+7,"reload does not double effects")
	var saved_state: Dictionary = rt.state.duplicate(true)
	var mp_before: int = world._effective_max_mp()
	var damage_before: int = world._equipment_additional_damage("melee")
	var ac_before: int = world._effective_ac()
	var stat_fixture: Dictionary = saved_state.duplicate(true)
	for eid: String in ["sayha","paagrio","maphr"]:
		stat_fixture.emblems[eid] = {"stage":3,"attempts":1,"spent":1,"guaranteed":false}
	rt.restore(stat_fixture)
	check(world._effective_max_mp()==mp_before+6,"Sayha MP reaches world")
	check(world._equipment_additional_damage("melee")==damage_before+1,"Paagrio damage reaches world")
	check(world._effective_ac()==ac_before-1,"Maphr signed AC reaches world")
	rt.restore(saved_state)
	var limit_fixture: Dictionary = saved_state.duplicate(true)
	limit_fixture.emblems.eva = {"stage":30,"attempts":20,"spent":20,"guaranteed":false}
	rt.restore(limit_fixture)
	check(not rt.quote("enhance","eva").ok,"max stage/attempt cap enforced")
	rt.restore(saved_state)
	var invalid: Dictionary = Growth.fresh()
	invalid.points = -1
	check(not rt.validate(invalid).is_empty(),"negative points rejected")
	invalid = Growth.fresh(); invalid.schema=9
	check(not rt.validate(invalid).is_empty(),"future schema rejected")
	world.hud.toggle_menu()
	for i: int in range(3): await process_frame
	var menu_tile: Button = world.hud.workspace.find_child("MenuTile_emblems",true,false)
	tap(menu_tile)
	for i: int in range(3): await process_frame
	check(world.hud.workspace.visible and world.hud.active_section=="emblems","real menu workspace route")
	check(world.hud.workspace.find_child("GrowthAction_enhance1",true,false)!=null,"enhance action reachable")
	var view: Control = world.hud.workspace.find_child("GrowthView",true,false)
	var first_tab: Button = view.find_child("GrowthTab_eva",true,false)
	var origin: Vector2 = first_tab.get_global_transform_with_canvas()*(first_tab.size/2)
	var press := InputEventScreenTouch.new()
	press.index=94; press.position=origin; press.pressed=true
	root.push_input(press,true)
	var drag := InputEventScreenDrag.new()
	drag.index=94; drag.position=origin+Vector2(0,-55); drag.relative=Vector2(0,-55)
	root.push_input(drag,true)
	press=InputEventScreenTouch.new()
	press.index=94; press.position=origin+Vector2(0,-55); press.pressed=false
	root.push_input(press,true)
	await process_frame
	check(view.scroll.scroll_vertical>0 and view.selected=="eva" and view.request.is_empty(),"native swipe scrolls without activating button")
	var action_button: Button = view.find_child("GrowthAction_enhance1",true,false)
	view.scroll.ensure_control_visible(action_button)
	for i: int in range(3): await process_frame
	tap(action_button)
	for i: int in range(3): await process_frame
	check(not view.request.is_empty(),"native Android-style tap opens confirmation")
	var cancel_button: Button = view.find_child("GrowthCancel",true,false)
	if cancel_button != null:
		view.scroll.ensure_control_visible(cancel_button)
		for i: int in range(3): await process_frame
		var unchanged: Dictionary = rt.state.duplicate(true)
		tap(cancel_button)
		await process_frame
		check(rt.state==unchanged and view.request.is_empty(),"native cancel leaves state and cost intact")
	root.size=Vector2i(854,480)
	for i: int in range(3): await process_frame
	world.hud._fit_hud()
	var corner: Vector2 = root.get_final_transform()*world.hud.workspace.get_global_transform_with_canvas()*world.hud.workspace.size
	check(corner.x<=855 and corner.y<=481,"Android landscape workspace fits")
	world.hud._close_workspace()
	check(rt.rerolls.is_empty(),"closing resets session odds")
	world.hud.open_growth("guardians")
	await process_frame
	check(world.hud.workspace.find_child("GuardianNode_joe_0",true,false)!=null,"guardian nodes reachable")
	var durable: String = FileAccess.get_file_as_string(world.save_path())
	var damaged: Dictionary = JSON.parse_string(durable)
	damaged.growth.schema=999
	var file := FileAccess.open(world.save_path(),FileAccess.WRITE)
	file.store_string(JSON.stringify(damaged)); file.close()
	world._load_game(true)
	check(world.equipment_collections.save_blocked,"future growth schema protects existing file")
	check(world._save_game(true)!=OK,"autosave blocked after rejected growth load")
	file=FileAccess.open(world.save_path(),FileAccess.WRITE)
	file.store_string(durable); file.close()
	world._load_game(true)
	check(not world.equipment_collections.save_blocked,"valid reload recovers save protection")
	world.queue_free()
	await process_frame
	print("GROWTH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
