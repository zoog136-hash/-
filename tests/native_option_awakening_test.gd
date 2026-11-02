extends SceneTree
const Option=preload("res://scripts/cards/option_awakening_service.gd")
const OptionRuntime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Adapter=preload("res://scripts/cards/native_option_awakening.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var checks: int=0
var errors: Array[String]=[]
class Context extends RefCounted:
	var context: Dictionary={}
	func source_server_context() -> Dictionary:return context.duplicate(true)
class Host extends Node:
	var catalog_db: Dictionary={}
	var card_draw_fusion=Cards.new()
	var card_collections=Context.new()
	var equipped_catalog: Dictionary={"변신":{},"마법인형":{},"성물":{}}
	var gold: int=100000000
	var save_error: Error=OK
	var equipment_records_dirty: bool=true
	var skill_cooldowns: Dictionary={}
	var rng=RandomNumberGenerator.new()
	var hud: Node=null
	func save_path() -> String:return "user://native-awakening-transactions.json"
	func _save_game(_quiet: bool,override: Dictionary={}) -> Error:
		if save_error!=OK:return save_error
		return preload("res://scripts/skills/save_writer.gd").write(save_path(),override)
class Target extends Node:
	var dead: bool=false
	var hp: int=10000
	var calls: int=0
	func take_damage(amount: int,_critical: bool,_kind: String) -> void:hp-=amount;calls+=1
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-cards="):path=arg.trim_prefix("--native-cards=")
	if path.is_empty():push_error("Explicit native catalog required");quit(2);return
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path)).catalog
	var host:=Host.new();root.add_child(host);host.catalog_db=catalog;host.card_draw_fusion.configure(catalog)
	var options=OptionRuntime.new()
	check(options.configure(host),"existing option runtime accepts exact native definitions")
	var definitions: int=0;var eligible: int=0
	for category: String in Cards.CATEGORIES:
		definitions+=options.core.definitions[category].size()
		for identity: String in options.core.definitions[category]:
			if options.core.native_eligibility(category,identity).ok:eligible+=1
	check(definitions==289,"289 native option targets joined without name aliases")
	var hero: String="source:m508:1:85";var material: String="source:m508:1:4"
	var definition: Dictionary=options.core.definition("변신",hero)
	check(definition.stats.attackSpeed==7 and definition.stats.moveSpeedPct==3 and definition.stats.strFlat==1 and definition.stats.weightBonus==500,"original guard spear first-slot units")
	check(not options.core.definitions["변신"].has("source:85"),"legacy numeric identity not treated as native")
	host.card_draw_fusion.owned["변신"][hero]=true;host.card_draw_fusion.owned["변신"][material]=true
	var required: int=int(options.core.policy.experience_required)
	var source_view: Dictionary=options.view("변신",hero)
	var per: int=int(source_view.material_experience["희귀"])
	var amount: int=ceili(float(source_view.required_experience)/per);host.card_draw_fusion.spare["변신"][material]=amount+3
	var before: int=hash([host.card_draw_fusion.export_state(),host.gold,options.export_state()]);var rng_before: String=str(options.rng.state)
	host.save_error=ERR_FILE_CANT_WRITE
	var result: Dictionary=options.feed("변신",hero,{material:amount})
	check(not result.ok and result.code=="save_failed","native feed uses existing atomic failure path")
	check(hash([host.card_draw_fusion.export_state(),host.gold,options.export_state()])==before and str(options.rng.state)==rng_before,"failed native persistence changes no material/gold/progress/RNG")
	host.save_error=OK;result=options.feed("변신",hero,{material:amount})
	check(result.ok and int(options.progress.cards["변신"][hero].experience)==required,"native source pool fills while compatible save percent remains100")
	check(host.card_draw_fusion.owned["변신"][hero] and host.card_draw_fusion.spare["변신"][material]==3,"only exact native duplicates consumed")
	var probe:=RandomNumberGenerator.new()
	for seed_value: int in range(1,10000):
		probe.seed=seed_value
		if probe.randi_range(0,9999)<1650:options.rng.seed=seed_value;break
	result=options.awaken("변신",hero)
	check(result.ok and result.success and options.core.awakened(options.progress,"변신",hero),"native hero awakens using existing verified 16.5 percent rule")
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.save_path()))
	check(disk.card_option_awakening.cards["변신"].has(hero) and not disk.card_option_awakening.cards["변신"].has("source:85"),"exact sourceID persisted by existing writer")
	host.equipped_catalog["변신"]=options.core.catalog["변신"][hero]
	check(options.bonus_records().size()==1 and options.bonus_records()[0].attackSpeed==7,"native option bonus once on equipped card")
	host.card_draw_fusion.owned["변신"].erase(hero)
	check(options.bonus_records().is_empty(),"no native option bonus without permanent acquisition")
	host.card_draw_fusion.owned["변신"][hero]=true
	var limited: Dictionary={}
	for category: String in Cards.CATEGORIES:
		for identity: String in options.core.definitions[category]:
			var row: Dictionary=options.core.definition(category,identity)
			if row.native_source.limits.any(func(value: Variant) -> bool:return int(value)==772):limited={"category":category,"id":identity};break
		if not limited.is_empty():break
	check(not limited.is_empty() and not options.core.native_eligibility(limited.category,limited.id).ok,"native option server condition retained")
	var server_row: Dictionary={}
	for row: Dictionary in Adapter.DATA.data.source_server_limits:
		if int(row.ServerLimitSetID)==772:server_row=row;break
	host.card_collections.context={"source_snapshot":"base508","ServiceRegionCode":str(server_row.ServiceRegionCode),"WorldNo":int(server_row.WorldNo)}
	options.view(limited.category,limited.id)
	check(options.core.native_eligibility(limited.category,limited.id).ok,"native option server condition uses explicit original row")
	host.card_collections.context={}
	var collections=preload("res://scripts/cards/native_collection_rules.gd").new()
	check(collections.configure(JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/base508_collections.json")),catalog),"native collection rules configured")
	var bridge: Dictionary=options.native_collection_state()
	var initial: Dictionary=collections.derive({"owned":host.card_draw_fusion.owned,"source_option_awakening":bridge})
	var chosen: Dictionary={}
	for row: Dictionary in initial.rows:
		if row.available and not row.completed and row.requirements.any(func(req: Dictionary) -> bool:return bool(req.awakened)):
			chosen=row;break
	check(not chosen.is_empty(),"native awakened collection has exact supported option bindings")
	if not chosen.is_empty():
		for req: Dictionary in chosen.requirements:
			host.card_draw_fusion.owned[req.category][req.id]=true
			if req.awakened:options.progress.cards[req.category][req.id]={"experience":0,"awakened":false,"attempts":0,"failures":0}
		var fake: Dictionary=collections.derive({"owned":host.card_draw_fusion.owned,"option_awakening":options.export_state(),"card_skill_awakening":{"all":true}})
		check(not fake.completed.has(chosen.id),"generic option flags and skill state never satisfy native IsAwaken")
		for req: Dictionary in chosen.requirements:
			if req.awakened:options.progress.cards[req.category][req.id]={"experience":0,"awakened":true,"attempts":1,"failures":0}
		options.progress.revision+=1
		bridge=options.native_collection_state()
		var derived: Dictionary=collections.derive({"owned":host.card_draw_fusion.owned,"source_option_awakening":bridge})
		check(derived.completed.has(chosen.id),"exact native option first-slot state satisfies source IsAwaken")
		var repeated: Dictionary=collections.derive({"owned":host.card_draw_fusion.owned,"source_option_awakening":bridge})
		check(derived.totals==repeated.totals,"native awakened collection rewards do not stack on rebuild")
		var broken: Dictionary=bridge.duplicate(true)
		for req: Dictionary in chosen.requirements:
			if req.awakened:broken.bindings[req.id].group_id=-1;break
		check(not collections.derive({"owned":host.card_draw_fusion.owned,"source_option_awakening":broken}).completed.has(chosen.id),"wrong original option group cannot satisfy collection")
		for req: Dictionary in chosen.requirements:
			if req.awakened:options.progress.cards[req.category][req.id].awakened=false;break
		check(not collections.derive({"owned":host.card_draw_fusion.owned,"source_option_awakening":options.native_collection_state()}).completed.has(chosen.id),"cleared exact awakening removes collection effect")
	print("NATIVE_OPTION_AWAKENING_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"native_definitions":definitions,"default_eligible":eligible,"available_collections":initial.rows.filter(func(row: Dictionary) -> bool:return bool(row.available)).size()}))
	host.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
