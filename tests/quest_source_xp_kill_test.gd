extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	checks+=1
	if not v:failures.append(label);printerr("QUEST_SOURCE_XP_KILL_FAIL "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
	check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"actual saved R13 quest-produced source1186 use output")
	if not failures.is_empty():quit(1);return
	var w: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false);w.player.set_physics_process(false);check(QA.enter_game(w,"기사"),"actual Main/current source map")
	var xp_key: String=""
	for key: String in w.active_item_buffs:
		if w.active_item_buffs[key].get("source_item_class_id")==1186:xp_key=key;break
	check(not xp_key.is_empty() and w._active_item_buff_total("xp")==10,"original finite quest potion effect remains restored")
	var source: Dictionary={}
	for row: Dictionary in w.monster_db:
		var xp: int=int(row.get("xp",row.get("exp",0)))
		if xp>=100 and xp<=10000:source=row.duplicate(true);break
	check(not source.is_empty(),"reuse an existing actual monster definition, no invented monster/reward")
	if source.is_empty() or xp_key.is_empty():w.queue_free();await process_frame;quit(1);return
	var buff: Dictionary=w.active_item_buffs[xp_key].duplicate(true);var ain: Dictionary=w.ain_service.export_state();var values: Array=[]
	w.player.auto_enabled=false
	for enabled: bool in [false,true]:
		if enabled:w.active_item_buffs[xp_key]=buff.duplicate(true)
		else:w.active_item_buffs.erase(xp_key)
		w.ain_service.import_state(ain);w.rng.seed=9450;w.experience=0
		var actor: TwilightMonster=w.MONSTER_SCENE.instantiate();w.monsters_root.add_child(actor);actor.setup(source.duplicate(true),w.player,w,null);actor.set_physics_process(false);actor.global_position=w.player.global_position+Vector2(1024,1024)
		var base: int=actor.exp_reward;var factor: float=w._experience_multiplier();var rate: float=w.ain_service.experience_rate();actor.dead=true
		w._on_monster_died(actor);var gained: int=w.experience
		check(gained>0 and w.level==int(JSON.parse_string(FileAccess.get_file_as_string(w.save_path())).level),"actual monster death consumer grants XP without a controlled-fixture level crossing")
		w._on_monster_died(actor);check(w.experience==gained,"same actor life cannot grant XP twice")
		values.append({"source_monster_id":source.get("source_m_npc_id",null),"name":actor.monster_name,"original_actor_exp":base,"item_multiplier":factor,"ain_rate":rate,"gained":gained});actor.queue_free()
	check(int(values[1].gained)>int(values[0].gained) and is_equal_approx(float(values[1].item_multiplier)-float(values[0].item_multiplier),0.1),"real original1186 effect increases actual common monster-death XP by its10percentage-point contribution")
	check(values[0].original_actor_exp==values[1].original_actor_exp and values[0].ain_rate==values[1].ain_rate,"same original monster and same blessing rate isolate the existing XP consumer")
	w.deferred_save.cancel();check(FileAccess.get_sha256(w.save_path())==seed,"controlled kill context does not rewrite prior owned-item/effect input save")
	print("QUEST_SOURCE_XP_KILL_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"measured":values,"controlled_actor_kill_callback_not_natural_encounter_or_native_stacking_equivalence":true}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
