extends SceneTree
const Fixture=preload("res://tests/native_option_awakening_test.gd")
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Economy=preload("res://scripts/cards/native_option_economy.gd")
var checks: int=0
var errors: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-cards="):path=arg.trim_prefix("--native-cards=")
	if path.is_empty():push_error("Explicit native catalog required");quit(2);return
	var host:=Fixture.Host.new();root.add_child(host)
	host.catalog_db=JSON.parse_string(FileAccess.get_file_as_string(path)).catalog;host.card_draw_fusion.configure(host.catalog_db)
	var runtime=Runtime.new();check(runtime.configure(host),"native economy configured")
	var hero: String="source:m508:1:85";var rare: String="source:m508:1:4"
	host.card_draw_fusion.owned["변신"][hero]=true;host.card_draw_fusion.owned["변신"][rare]=true;host.card_draw_fusion.spare["변신"][rare]=10
	var state: Dictionary=runtime.export_state();var cards: Dictionary=host.card_draw_fusion.export_state();var before: int=hash([state,cards,host.gold])
	var view: Dictionary=runtime.view("변신",hero)
	check(view.attempt_cost==300000 and view.required_experience==5000000 and view.source_exp_scale==100,"named source hero fee300000 and EXP50000; integer hundredths display scale")
	var material: Dictionary={}
	for row: Dictionary in view.materials:
		if row.id==rare:material=row
	check(material.experience_per_card==1666700 and material.cost_per_card==10000,"source rare material EXP16667 and feed fee10000")
	var result: Dictionary=runtime.core.prepare_feed(state,cards,host.gold,"변신",hero,{rare:1})
	check(result.ok and result.gold==host.gold-10000 and result.state.cards["변신"][hero][Economy.FIELD]==1666700,"native feed stages exact source EXP and Adena cost")
	check(hash([state,cards,host.gold])==before,"native preparation changes no caller state/cards/gold")
	result=runtime.core.prepare_feed(state,cards,host.gold,"변신",hero,{rare:3})
	check(result.ok and result.state.cards["변신"][hero][Economy.FIELD]==5000000 and result.discarded_experience==100,"three source rares fill hero exactly and discard only source1XP overflow")
	check(result.card_state.owned["변신"][rare] and result.card_state.spare["변신"][rare]==7 and result.gold==host.gold-30000,"only duplicate quantities and exact per-material fees are staged")
	check(not runtime.core.prepare_feed(state,cards,host.gold,"변신",hero,{hero:1}).ok,"hero material forbidden for hero target by source min/max grades")
	check(runtime.core.prepare_feed(state,cards,9999,"변신",hero,{rare:1}).code=="insufficient_gold","unaffordable source feed rejected")
	var full: Dictionary=result.state
	check(runtime.core.prepare_awaken(full,cards,100000,"변신",hero,0).code=="insufficient_gold","old local100000 fee cannot pay native300000")
	result=runtime.core.prepare_awaken(full,cards,host.gold,"변신",hero,9999)
	check(result.ok and not result.success and result.state.cards["변신"][hero][Economy.FIELD]==1666700 and result.gold==host.gold-300000,"failure subtracts named33333XP from50000 and consumes source fee once")
	var legend: String=""
	for id: String in runtime.core.definitions["변신"]:
		if runtime.core.definitions["변신"][id].grade=="전설" and runtime.core.native_eligibility("변신",id).ok:legend=id;break
	host.card_draw_fusion.owned["변신"][legend]=true
	var old: Dictionary=state.duplicate(true);old.cards["변신"][legend]={"experience":25,"awakened":false,"attempts":0,"failures":0,"future_note":"keep"}
	var old_hash: int=hash(old);var migrated: Dictionary=Economy.view(runtime.core,old,host.card_draw_fusion.export_state(),host.gold,"변신",legend)
	check(migrated.experience==21666650 and hash(old)==old_hash,"legacy25percent progress reads as exact216666.50 sourceXP without save mutation or rounding loss")
	var corrupt: Dictionary=full.duplicate(true);corrupt.cards["변신"][hero][Economy.FIELD]=-1
	check(not runtime.core.validate_state(corrupt,cards).is_empty(),"invalid native progress blocks save")
	host.save_error=ERR_FILE_CANT_WRITE;before=hash([runtime.export_state(),host.card_draw_fusion.export_state(),host.gold,runtime.rng.state])
	result=runtime.feed("변신",hero,{rare:1})
	check(result.code=="save_failed" and hash([runtime.export_state(),host.card_draw_fusion.export_state(),host.gold,runtime.rng.state])==before,"save failure rolls back source EXP/feed fee/material/RNG together")
	host.save_error=OK;var gold: int=host.gold;result=runtime.feed("변신",hero,{rare:1})
	check(result.ok and host.gold==gold-10000 and host.card_draw_fusion.spare["변신"][rare]==9,"existing runtime commits exact source feed debit only after save")
	var loaded: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.save_path()))
	check(runtime.accept_load(loaded) and runtime.progress.cards["변신"][hero][Economy.FIELD]==1666700,"exact source numerator survives JSON save/restore")
	var ac_count: int=0
	for category: String in runtime.core.definitions:
		for row: Dictionary in runtime.core.definitions[category].values():
			for effect: Dictionary in row.native_source.effects:
				if effect.type.Name=="ArmorClassBonus":
					ac_count+=1;check(effect.runtime_supported and row.applied_options.has("AC -"+str(int(effect.bonus.Value))),"source flat AC feeds existing negative-AC consumer")
	check(ac_count==12,"all12 exact flat ArmorClassBonus definitions connected")
	print("NATIVE_OPTION_ECONOMY ",JSON.stringify({"checks":checks,"errors":errors,"flat_ac_definitions":ac_count,"source_policy":"named option-only rules; skill book consumption separate"}))
	host.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
