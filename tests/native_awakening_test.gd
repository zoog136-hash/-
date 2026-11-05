extends SceneTree
const Option=preload("res://scripts/cards/option_awakening_service.gd")
const OptionRuntime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Skill=preload("res://scripts/cards/skill_awakening_service.gd")
const SkillRuntime=preload("res://scripts/cards/skill_awakening_runtime.gd")
const Adapter=preload("res://scripts/cards/native_option_awakening.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var checks: int=0
var errors: Array[String]=[]
class Context extends RefCounted:
	var context: Dictionary={}
	func source_server_context() -> Dictionary:return context.duplicate(true)
class Host extends Node:
	var hp: int=1000
	var player: Node2D
	var catalog_db: Dictionary={}
	var card_draw_fusion=Cards.new()
	var card_collections=Context.new()
	var equipped_catalog: Dictionary={"변신":{},"마법인형":{},"성물":{}}
	var inventory: Dictionary={}
	var item_instances: Dictionary={}
	var gold: int=100000000
	var save_error: Error=OK
	var equipment_records_dirty: bool=true
	var skill_cooldowns: Dictionary={}
	var rng=RandomNumberGenerator.new()
	var hud: Node=null
	func save_path() -> String:return "user://native-awakening-transactions.json"
	func _save_game(_quiet: bool,override: Dictionary={}) -> Error:
		if save_error!=OK:return save_error
		var snapshot: Dictionary={}
		if FileAccess.file_exists(save_path()):
			var previous: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path()))
			if previous is Dictionary:snapshot=previous
		snapshot.merge(override,true)
		return preload("res://scripts/skills/save_writer.gd").write(save_path(),snapshot)
class Preview extends Node:
	var events: Array[Dictionary]=[]
	var installed: bool=true
	func notify_source_spell_event(spell: int,stage: String,point: Vector2,facing: int,path: String) -> bool:
		events.append({"spell":spell,"stage":stage,"point":point,"facing":facing,"manifest":path});return installed
class Caster extends Node2D:
	var original_source_preview: Node
	var original_source_manifest: String="user://explicit-test-source-manifest.json"
class Target extends Node2D:
	var dead: bool=false
	var hp: int=10000
	var calls: int=0
	func take_damage(amount: int,_critical: bool,_kind: String) -> void:hp=maxi(0,hp-amount);calls+=1;dead=hp==0
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
	var snapshot: Dictionary=options.view("변신",hero)
	var required: int=100 # legacy progress display remains percent
	var per: int=int(snapshot.material_experience["희귀"])
	var amount: int=ceili(float(snapshot.required_experience)/per);host.card_draw_fusion.spare["변신"][material]=amount+3
	var before: int=hash([host.card_draw_fusion.export_state(),host.gold,options.export_state()]);var rng_before: String=str(options.rng.state)
	host.save_error=ERR_FILE_CANT_WRITE
	var result: Dictionary=options.feed("변신",hero,{material:amount})
	check(not result.ok and result.code=="save_failed","native feed uses existing atomic failure path")
	check(hash([host.card_draw_fusion.export_state(),host.gold,options.export_state()])==before and str(options.rng.state)==rng_before,"failed native persistence changes no material/gold/progress/RNG")
	host.save_error=OK;result=options.feed("변신",hero,{material:amount})
	check(result.ok and int(options.progress.cards["변신"][hero].experience)==required,"native ID feed reaches source experience requirement")
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
	var skills=SkillRuntime.new();check(skills.configure(host),"source skill runtime configured")
	var core=skills.core
	var profiles: int=0
	for identity: String in core.cards:
		if not core.profile(identity,1).is_empty():profiles+=1
	check(core.cards.size()==701 and core.pools.size()==15 and core.DATA.data.spells.size()==72 and profiles==523,"701 source identities, 15 live pools, 72 spells, 523 level profiles")
	check(core.candidates(material).size()==5 and core.select_candidate(material,65999).candidate.spell_id==64224 and core.select_candidate(material,66000).candidate.spell_id==64264,"source candidate-weight boundary separate from proc chance")
	check(not core.select_candidate(material,100000).ok,"selection denominator is exact 100000")
	var state: Dictionary=Skill.fresh_state();state.cards[material]={"spell_id":64224,"level":1,"experience":"1234567890123","future_metadata":{"v":1.5}}
	check(core.validate_state(state).is_empty() and skills.accept_load({SkillRuntime.SAVE_KEY:state}),"native skill level and decimal EXP state accepted")
	check(skills.export_state()==state,"skill save preserves experience and future metadata exactly")
	var invalid: Dictionary=state.duplicate(true);invalid.cards[material].spell_id=17614
	check(not core.validate_state(invalid).is_empty(),"wrong deck spell cannot confer an effect")
	invalid=state.duplicate(true);invalid.cards[material].level=21
	check(not core.validate_state(invalid).is_empty(),"invalid level blocked")
	invalid=state.duplicate(true);invalid.cards[material].experience="01"
	check(not core.validate_state(invalid).is_empty(),"noncanonical decimal EXP blocked")
	var invoke: Dictionary=core.invoke(material,state.cards[material],99)
	check(invoke.ok and invoke.invoked and not core.invoke(material,state.cards[material],100).invoked,"source proc uses exact 100/10000 boundary")
	var max_profile: Dictionary=core.profile(material,20)
	check(max_profile.hp==970 and int(max_profile.invoke.CastSuccessProb)==700 and int(max_profile.invoke.CastDelayBonus)==100,"original level20 HP/chance/delay profile")
	check(invoke.profile.hp==300 and invoke.damage.SpellDamageBase==69 and invoke.damage.SpellDamageDiceNumber==1 and invoke.damage.SpellDamageDiceSpotCount==1,"original level1 HP and fire bolt fixed damage")
	host.equipped_catalog["변신"]=options.core.catalog["변신"][material]
	check(skills.bonus_records().size()==1 and skills.bonus_records()[0].hpFlat==300,"source skill HP bonus equipped once")
	host.card_draw_fusion.owned["변신"].erase(material)
	check(skills.bonus_records().is_empty(),"skill HP not inferred from saved progress")
	host.card_draw_fusion.owned["변신"][material]=true
	var state_before: int=hash([skills.export_state(),host.card_draw_fusion.export_state(),host.gold,host.rng.state])
	result=skills.request_operation(material,{material:99})
	check(not result.ok and result.code=="insufficient_book" and hash([skills.export_state(),host.card_draw_fusion.export_state(),host.gold,host.rng.state])==state_before,"missing physical skill book never debits or advances RNG")
	var target:=Target.new();root.add_child(target)
	for seed_value: int in range(1,10000):
		probe.seed=seed_value
		if probe.randi_range(0,9999)<100:host.rng.seed=seed_value;break
	skills.on_successful_hit(target)
	check(target.hp==9930 and target.calls==1 and skills.proc_counts.get(material,0)==1,"saved native skill invokes real fixed70 damage on hit")
	var rng_after: int=host.rng.state;skills.on_successful_hit(target)
	check(target.calls==1 and host.rng.state==rng_after and host.skill_cooldowns.values()[0]==3.0,"source cast delay prevents repeat proc and RNG roll")
	var caster:=Caster.new();host.add_child(caster);host.player=caster
	var preview:=Preview.new();caster.add_child(preview);caster.original_source_preview=preview
	caster.position=Vector2(30,40);target.position=Vector2(110,120)
	var visual: Dictionary=skills.source_vfx.emit_spell(host,core.DATA.data.spells["64224"].source_spell,target)
	check(visual.status=="played" and preview.events.size()==2 and preview.events[0].spell==64224 and preview.events[0].stage=="effect" and preview.events[1].stage=="impact","exact source spell ID and declared stages reach existing compositor API")
	check(preview.events[0].point==target.global_position and preview.events[1].point==target.global_position,"source impact placement is copied from current target")
	preview.installed=false;visual=skills.source_vfx.emit_spell(host,core.DATA.data.spells["64224"].source_spell,target)
	check(visual.status=="unavailable" and visual.played.is_empty(),"missing originals stay unavailable without generated VFX fallback")
	preview.installed=true;host.skill_cooldowns.clear();target.hp=30
	for seed_value: int in range(1,10000):
		probe.seed=seed_value
		if probe.randi_range(0,9999)<100:host.rng.seed=seed_value;break
	skills.on_successful_hit(target)
	check(target.dead and target.calls==2 and preview.events.size()==6,"proc can kill target once and emits only its exact source stages")
	rng_after=host.rng.state;skills.on_successful_hit(target)
	check(target.calls==2 and host.rng.state==rng_after and preview.events.size()==6,"dead targets produce no repeat damage/RNG/VFX")
	target.dead=false;target.hp=100;target.position=Vector2(210,220)
	skills.on_successful_hit(target)
	check(target.hp==100 and preview.events.size()==6,"reused body retains per-card cooldown and no delayed effect follows new life")
	host.skill_cooldowns.clear();host.hp=0;rng_after=host.rng.state;skills.on_successful_hit(target)
	check(target.hp==100 and host.rng.state==rng_after and preview.events.size()==6,"dead player cannot proc or advance RNG")
	host.hp=1000;host.equipped_catalog["변신"]={};skills.on_successful_hit(target)
	check(target.hp==100 and preview.events.size()==6,"unequipped skill cannot emit source effects")
	host.equipped_catalog["변신"]=options.core.catalog["변신"][material]
	for seed_value: int in range(1,10000):
		probe.seed=seed_value
		if probe.randi_range(0,9999)<100:host.rng.seed=seed_value;break
	skills.on_successful_hit(target)
	check(target.hp==30 and preview.events.size()==8 and preview.events[6].point==Vector2(210,220),"new hit on reused target uses current-life point exactly once")
	host.equipped_catalog["변신"]={}
	check(skills.bonus_records().is_empty(),"unequip removes source HP")
	var persisted: Dictionary={SkillRuntime.SAVE_KEY:skills.export_state()}
	check(preload("res://scripts/skills/save_writer.gd").write("user://skill-awakening-roundtrip.json",persisted)==OK,"existing atomic writer stores separate skill namespace")
	var loaded: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://skill-awakening-roundtrip.json"))
	check(skills.accept_load(loaded) and skills.export_state()==state,"skill save/restore EXP and spell are lossless")
	var grown: Dictionary=state.duplicate(true)
	grown.cards[material].level=20;grown.cards[material].experience="9999999999999"
	check(skills.accept_load({SkillRuntime.SAVE_KEY:grown}),"grown source skill state accepted")
	var prepared: Dictionary=core.prepare_reroll(skills.export_state(),host.card_draw_fusion.owned,material,66000,0,"policy-reroll-1")
	check(prepared.ok and prepared.spell_id==64264 and prepared.state.cards[material].level==1 and prepared.state.cards[material].experience=="0","source weighted paid reroll follows user growth reset policy")
	check(not prepared.has("success_chance") and not prepared.state.cards[material].has("pity"),"no invented awakening failure or pity mechanic")
	for seed_value: int in range(1,10000):
		probe.seed=seed_value
		var roll: int=probe.randi_range(0,99999)
		if roll>=66000 and roll<98000:skills.selection_rng.seed=seed_value;break
	var before_commit: int=hash([skills.export_state(),skills.selection_rng.state,host.gold,host.card_draw_fusion.export_state()])
	var disk_before: String=FileAccess.get_file_as_string(host.save_path())
	host.save_error=ERR_FILE_CANT_WRITE
	result=skills._commit_confirmed_reroll(material,0,"policy-reroll-1")
	check(not result.ok and result.code=="save_failed" and FileAccess.get_file_as_string(host.save_path())==disk_before,"failed internal reroll persistence preserves disk")
	check(hash([skills.export_state(),skills.selection_rng.state,host.gold,host.card_draw_fusion.export_state()])==before_commit,"failed reroll persistence rolls back growth/RNG and changes no resources")
	host.save_error=OK;result=skills._commit_confirmed_reroll(material,0,"policy-reroll-1")
	check(result.ok and skills.progress.cards[material].spell_id==64264 and skills.progress.cards[material].level==1 and skills.progress.cards[material].experience=="0","confirmed internal reroll commits source skill with user growth reset")
	var after_commit: int=hash([skills.export_state(),skills.selection_rng.state,host.gold,host.card_draw_fusion.export_state()])
	result=skills._commit_confirmed_reroll(material,0,"policy-reroll-1")
	check(not result.ok and result.code=="duplicate_operation" and hash([skills.export_state(),skills.selection_rng.state,host.gold,host.card_draw_fusion.export_state()])==after_commit,"repeated reroll operation cannot duplicate transaction or advance live RNG")
	result=skills._commit_confirmed_reroll(material,0,"stale-reroll-2")
	check(not result.ok and result.code=="stale_revision","stale revision cannot apply another reroll")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.save_path()))
	check(saved.has("card_option_awakening") and saved.card_skill_awakening.cards[material].experience=="0","atomic writer retains option namespace and paid growth reset")
	check(skills.accept_load(saved) and str(skills.selection_rng.state)==str(saved.card_skill_awakening.rng_state),"saved reroll RNG/state restore together")
	var guarded: int=hash([skills.export_state(),skills.selection_rng.state,host.gold,host.card_draw_fusion.export_state()])
	check(not skills.request_operation(material).ok and hash([skills.export_state(),skills.selection_rng.state,host.gold,host.card_draw_fusion.export_state()])==guarded,"public paid operation remains gated despite internal policy implementation")
	print("NATIVE_AWAKENING_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"native_option_definitions":definitions,"default_eligible_options":eligible,"available_sets_with_native_option_binding":initial.rows.filter(func(row: Dictionary) -> bool:return bool(row.available)).size(),"skill_profiles":profiles}))
	target.queue_free();host.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
