extends SceneTree
const QA=preload("res://tests/qa_symbol_absolute_world.gd")
var world
var rt
var attacker: TwilightMonster
var checks: int=0
var failures: Array[String]=[]
var evidence: String=""
func canonical(value: Variant) -> Variant:
	if value is float and value==floorf(value):return int(value)
	if value is Array:
		var result: Array=[]
		for item: Variant in value:result.append(canonical(item))
		return result
	if value is Dictionary:
		var result: Dictionary={}
		for key: Variant in value:result[str(key)]=canonical(value[key])
		return result
	return value
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("SYMBOL_OFFLINE_FAIL "+label)
func frames() -> void:
	for i: int in range(3):await process_frame
func view():return world.hud.workspace.find_child("GrowthView",true,false)
func tap(button: Control) -> void:
	if button==null:check(false,"missing native button");return
	if view()!=null and view().scroll.is_ancestor_of(button):view().scroll.ensure_control_visible(button);await frames()
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size/2)
	for pressed: bool in [true,false]:
		var event=InputEventScreenTouch.new();event.index=88;event.position=point;event.pressed=pressed;root.push_input(event,true)
	await frames()
func own(rows: Dictionary) -> void:
	var next: Dictionary=rt.empty_state();next.points=10000000
	for id: String in rows:
		var grades: Array=[]
		for g: int in range(1,int(rows[id])+1):grades.append(g)
		next.emblems[id]={"stage":30,"attempts":10,"spent":0,"guaranteed":false,"absolute":0,"absolute_grades":grades}
	check(rt.validate(next).is_empty(),"valid ownership "+str(rows));rt.restore(next);world._invalidate_equipment_static()
	world.player.clear_status_effects()
func incoming(kind: String,context: Dictionary={}) -> int:
	world.hp=10000;rt.combat.last_hit_ms=-1
	var field=world.field_map;world.field_map=null
	attacker._emit_symbol_hit(1000,kind,context)
	world.field_map=field
	check(attacker.symbol_hit_context.is_empty(),"impact context cleared after signal")
	return 10000-world.hp
func dealt() -> int:
	attacker.hp=10000;attacker.dead=false;world.rng.seed=456
	world._deal_successful_player_hit(attacker,1000,false,"melee")
	return 10000-attacker.hp
func capture(label: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless":return
	view().scroll.scroll_vertical=0;await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"actual capture "+label)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):evidence=arg.trim_prefix("--evidence=")
	if not evidence.is_empty():DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();world.set_script(QA);root.add_child(world)
	world.hud.complete_class_selection();world.set_process(false);world.player.set_physics_process(false);world.field_population.set_process(false);world.quickslots=[];world.max_hp=20000
	for mob: TwilightMonster in world.monsters_root.get_children():mob.set_physics_process(false)
	rt=world.growth;attacker=world.MONSTER_SCENE.instantiate();world.monsters_root.add_child(attacker)
	attacker.setup({"name":"문양 검증","hp":999999,"lv":1,"ac":0,"crit":0},world.player,world,null);attacker.set_physics_process(false);attacker.attack_element="physical"
	attacker.player_hit.connect(world._on_player_hit) # Same signal hookup as Main._spawn_monster.
	# Exact source transactions through the real existing confirmation UI.
	for id: String in ["maphr","paagrio"]:
		own({id:0});world.inventory["축복의 열쇠"]=1000;world.hud.open_growth("emblems");await frames()
		await tap(view().find_child("GrowthTab_"+id,true,false))
		for g: int in range(1,6):
			var offer: Dictionary=rt.quote("absolute",id,g)
			check(offer.ok,"source quote now usable "+id+str(g))
			if DisplayServer.get_name()!="headless":
				await tap(view().find_child("GrowthAbsolute_absolute"+str(g),true,false));await tap(view().find_child("GrowthConfirm",true,false));await create_timer(1.4).timeout
			else:check(rt.execute("absolute",id,g,int(rt.state.revision)).ok,"headless source purchase")
			check(rt.progress(id).get("absolute_grades",[]).has(g),"source tier acquired "+id+str(g))
		check(world.inventory["축복의 열쇠"]==162,"five tiers consume exact838 keys "+id)
		check(view().find_child("GrowthLocalCombatPolicy",true,false)!=null,"estimate policy shown in native UI")
		view()._refresh();await frames();await capture("symbol523-"+id+"-offline-1280x720")
	var before_damage: Dictionary={}
	own({"maphr":1})
	for kind: String in ["melee","ranged","magic"]:before_damage[kind]=incoming(kind)
	own({"maphr":2})
	check(world._catalog_stat_sum("pve_damage_reduction")==5,"flat5 reaches existing PvE catalog consumer")
	for kind: String in before_damage:check(incoming(kind)==before_damage[kind]-5,"converted flat5 applies exactly once "+kind)
	own({"maphr":4})
	for kind: String in before_damage:before_damage[kind]=incoming(kind)
	own({"maphr":5});check(world._catalog_stat_sum("pve_damage_reduction_pct")==2,"source percent2 uses existing PvE percent consumer")
	for kind: String in before_damage:check(incoming(kind)==int(round(before_damage[kind]*.98)),"percent applies once after existing flat reduction "+kind)
	own({"paagrio":0});var stats: Array=[world._melee_damage_stat(),world._ranged_damage_stat(),world._magic_damage_stat()]
	own({"paagrio":1});check([world._melee_damage_stat(),world._ranged_damage_stat(),world._magic_damage_stat()]==[stats[0]+3,stats[1]+3,stats[2]+3],"source three PvP damage3 convert to three distinct PvE channels once")
	stats=[world._melee_damage_stat(),world._ranged_damage_stat(),world._magic_damage_stat()]
	own({"paagrio":2});check([world._melee_damage_stat(),world._ranged_damage_stat(),world._magic_damage_stat()]==[stats[0]+5,stats[1]+5,stats[2]+5],"flat ignore5 reuses existing offline extra-damage model")
	var source_spell: Dictionary={"id":"offline_fixture","name":"검증","power":1000,"attack_type":"magic","element":"physical"}
	attacker.hp=10000;attacker.dead=false;world.original_skills.deal_damage(source_spell,attacker)
	check(10000-attacker.hp==1008+(1 if world._has_hp_absorption() else 0),"actual fixed-power spell receives source PvE3 and typed flat-ignore5 once")
	own({"shilen":4});var hit: Array=[world._melee_accuracy_stat(),world._ranged_accuracy_stat()]
	own({"shilen":5});check(world._melee_accuracy_stat()==hit[0]+2 and world._ranged_accuracy_stat()==hit[1]+2,"evasion-ignore2 reuses existing separate accuracy consumers")
	own({"grankain":1});var ordinary: int=incoming("ranged",{"boss_kind":"volley"})
	own({"grankain":2});check(incoming("ranged",{"boss_kind":"volley"})==int(round((ordinary/.9-5)*.9)),"real emitted boss volley context receives estimated rapid-fire flat5")
	var before_charge: int=incoming("melee",{"boss_kind":"charge"})
	own({"grankain":3});check(incoming("melee",{"boss_kind":"charge"})==int(round(before_charge*.72/.9)),"estimated armorbreak mapping applies source18 once to boss charge")
	var d: int=dealt();own({"grankain":4});check(dealt()==d+3,"actual outgoing hit uses configurable death damage-per-point")
	check(incoming("magic",{"boss_kind":"nova"})==1000,"estimated nova10 bypasses source10 own reduction without efficiency")
	own({"grankain":5});check(incoming("magic",{"boss_kind":"nova"})==930,"efficiency7 counters bypass without exceeding own defense")
	rt.combat.last_hit_ms=-1
	check(rt.incoming_damage(1000,false,false,-1,-1,{"now_ms":1000})==900,"first hit has no estimated consecutive bonus")
	check(rt.incoming_damage(1000,false,false,-1,-1,{"now_ms":1500})==810,"within configured window source damp9 applies once")
	check(rt.incoming_damage(1000,false,false,-1,-1,{"now_ms":2501})==900,"consecutive bonus expires at exact configured boundary")
	own({"einhasad":2});check(rt.combat.outgoing(1000,"magic")==1100,"source ignore total10 uses configured outgoing-percent proxy")
	own({"shilen":1})
	for kind: String in ["melee","ranged","magic"]:check(rt.combat.outgoing(1000,kind)==1020,"source style-specific ignore2 remains separate "+kind)
	# Native veil uses raw InvokeOption15333's defensive flat300 and total7%.
	var seed: int=0;var probe:=RandomNumberGenerator.new()
	for candidate: int in range(10000):
		probe.seed=candidate;probe.randf()
		if probe.randf()<.07:seed=candidate;break
	world.rng.seed=seed
	check(incoming("magic")==700 and rt.combat.veil_fired,"actual incoming contact rolls native veil7 and consumes native reduction300")
	check(int(rt.source523.data.veil_invoke.option.ID)==15333 and int(rt.source523.data.veil_invoke.option.Param1)==300,"native invoke source identity retained")
	var all: Dictionary={}
	for id: String in rt.source523.data.emblems:all[id]=5
	own(all);check(world._save_game(true)==OK,"all35 valid owned groups save with native and local policies separate")
	var state: Dictionary=rt.state.duplicate(true);world._load_game(true);world.set_process(false);world.field_population.set_process(false)
	check(canonical(rt.state)==canonical(state),"real load preserves all35 groups and ledger")
	var file_sha: String=FileAccess.get_sha256(world.save_path());var inv: Dictionary=world.inventory.duplicate(true)
	own({"grankain":1});world._save_game(true);file_sha=FileAccess.get_sha256(world.save_path());state=rt.state.duplicate(true)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary) -> Error:return ERR_CANT_CREATE
	check(not rt.execute("absolute","grankain",2,int(rt.state.revision)).ok and rt.state==state and world.inventory==inv and FileAccess.get_sha256(world.save_path())==file_sha,"estimated-tier save failure preserves currency, ownership, inventory and file")
	world.equipment_collections.test_save_writer=Callable()
	rt.Combat.policy.estimates_enabled=false;rt._rebuild()
	check(not rt.quote("absolute","grankain",2).ok and rt.combat.outgoing(1000,"melee")==1000,"configured opt-out blocks new estimated acquisition and execution")
	check(rt.validate(state).is_empty(),"opt-out never invalidates or deletes existing ownership")
	rt.Combat.policy.estimates_enabled=true;rt._rebuild()
	world.hud.open_growth("emblems");await frames();await tap(view().find_child("GrowthTab_grankain",true,false))
	await capture("symbol523-estimate-policy-1280x720")
	print("SYMBOL_OFFLINE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
