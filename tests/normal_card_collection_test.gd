extends SceneTree
const Core=preload("res://scripts/cards/collection_rules.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
var world: TwilightWorld
var data: Dictionary
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("NORMAL_COLLECTION_FAIL ",why)
func definition(category: String,title: String) -> Dictionary:
	for row: Dictionary in data.collections:
		if row.category==category and row.name==title:return row
	return {}
func empty_ownership() -> Dictionary:return {"변신":{},"마법인형":{},"성물":{}}
func notification_count() -> int:
	var count: int=0
	for text: String in world.hud.log_history:
		if text.begins_with("카드 컬렉션 자동 완성"):count+=1
	return count
func receive(category: String,key: String) -> void:
	var grade: String=str(world.card_draw_fusion.known_ids[category][key])
	for sample: Dictionary in world.card_draw_fusion.pools[category][grade]:
		if sample.id==key:world.card_draw_fusion._receive(category,sample);return
func hide_reveal() -> void:
	if is_instance_valid(world.hud.card_reveal_stage):world.hud.card_reveal_stage.close_reveal()
func reset_owned() -> void:
	world.card_draw_fusion.import_state({})
	world.card_collections.restore_from_owned();world._update_hud()
func seed_for_grade(grade: String) -> int:
	var probe:=RandomNumberGenerator.new()
	for value: int in range(100000):
		probe.seed=value
		var roll: int=probe.randi_range(0,9999);var upper: int=0
		for entry: String in Cards.DRAW_ORDER:
			upper+=int(Cards.DRAW_WEIGHTS[entry])
			if roll<upper:
				if entry==grade:return value
				break
	return -1
func run() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/normal_collections.json"))
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var core=Core.new();check(core.configure(data,catalog),"versioned official definitions configure: "+core.error)
	check(core.definitions.size()==139 and data.reviewed_definition_count==195 and data.excluded_definition_count==56,"139 playable definitions remain from 195 reviewed rows after the explicitly requested 56 exclusions")
	var counts: Dictionary={};var blocked: Dictionary={};var active: int=0
	for row: Dictionary in core.definitions:
		counts[row.category]=int(counts.get(row.category,0))+1
		check(row.source.date<"2026-01-01","source cutoff: "+row.name)
		if core.availability[row.id].is_empty():active+=1
		for reason: String in core.availability[row.id]:blocked[reason.get_slice(":",0)]=int(blocked.get(reason.get_slice(":",0),0))+1
	print("NORMAL_COLLECTION_COVERAGE ",counts," applicable=",active," blocked_reasons=",blocked)
	check(counts=={"변신":28,"마법인형":27,"성물":84} and active==139 and blocked.is_empty(),"all three categories have exact playable counts and no blocked rows remain in game data")
	for binding: Array in [["변신","신화 : 천둥의 신","source:283","신화-뇌신(남)","신화"],["변신","어둠의 선생님","source:170","포노스 오크 마법사","전설"],["마법인형","탱커 듀오","source:102","광전사(남)","고급"]]:
		var row: Dictionary=definition(binding[0],binding[1])
		check(row.grade==binding[4] and row.requirements.any(func(q: Dictionary) -> bool:return q.id==binding[2] and q.catalog_name==binding[3] and not q.identity_binding.url.is_empty()),"verified legacy card name binds the existing exact ID/grade: "+binding[1])
		var acquired: Dictionary=empty_ownership()
		for q: Dictionary in row.requirements:acquired[row.category][q.id]=true
		var completed: Dictionary=core.derive({"owned":acquired,"spare":{}})
		check(completed.completed.has(row.id),"fixed collection auto-completes on permanent ownership with zero spare: "+binding[1])
	var bug: Dictionary=definition("변신","둥둥이 형제")
	check(bug.requirements[0].id=="source:62" and bug.requirements[1].id=="source:61" and bug.effects[0].value==5,"2019 official Bugbear pair +5HP exact IDs")
	var wolf: Dictionary=definition("마법인형","나의 살던 고향은 북섬")
	check(wolf.effects[0].key=="melee_hit" and wolf.effects[0].value==1,"2019 wolf/golem melee hit+1")
	var totem: Dictionary=definition("성물","토템 쿵쿵따")
	check(totem.requirements[0].id=="source:1008" and totem.requirements[1].id=="source:1007" and totem.effects[0].value==10,"2023 launch totem pair +10HP exact IDs")
	var staff: Dictionary=definition("성물","지팡이와 몽둥이")
	check(staff.effects[0].key=="max_mp" and staff.effects[0].value==5,"dated 2023 patch MP+5 preserved over conflicting unversioned live guide")
	var alphonse: Dictionary=definition("변신","노인과 괴수").requirements[1]
	check(alphonse.id=="source:209" and not alphonse.awakened,"literal card name 각성 알폰스 is source209, not base Alphonse or option-awakening state")
	var balrog: Dictionary=definition("변신","상급 마수들").requirements[3]
	check(balrog.id=="source:16" and not balrog.awakened,"literal 각성:발록 card identity is source16, not stripped Balrog")
	var ownership: Dictionary=empty_ownership();ownership["변신"]={"source:62":true,"source:61":true}
	var result: Dictionary=core.derive({"owned":ownership,"spare":{}})
	check(result.completed.has(bug.id) and result.totals["max_hp:flat"]==5,"permanent owned alone completes; zero duplicates is still owned")
	ownership["변신"]["source:61"]=false
	check(not core.derive({"owned":ownership}).completed.has(bug.id),"false-valued legacy entry is not acquisition")
	ownership=empty_ownership()
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in catalog[category]:ownership[category][Cards.card_id(record)]=true
	result=core.derive({"owned":ownership,"spare":{}})
	check(result.completed.size()==active,"unsupported PvP/evasion/rate, missing IDs and awakening conditions never award partial effects")
	for key: String in result.totals:check(not key.begins_with("pvp_"),"PvP effects not converted into solo PvE: "+key)
	var unsafe: Dictionary={"schema_version":1,"collections":[bug.duplicate(true)]}
	unsafe.collections[0].effects=[{"key":"pvp_damage_reduction","unit":"flat","value":1}]
	check(core.configure(unsafe,catalog) and core.availability[bug.id].has("effect_unsupported:pvp_damage_reduction:flat"),"the capability guard still rejects unsupported data rather than silently converting PvP to PvE")
	unsafe.collections[0].effects=bug.effects.duplicate(true)
	unsafe.collections[0].source.date="2026-01-01"
	check(core.configure(unsafe,catalog) and core.availability[bug.id].has("source_version_unverified"),"post-2025 source cannot become active by setting a flag")
	unsafe.collections[0].source=bug.source.duplicate(true);unsafe.collections[0].effects=["not an effect"]
	check(not core.configure(unsafe,catalog),"malformed effect fails safely")
	unsafe.collections=[bug.duplicate(true),bug.duplicate(true)]
	check(not core.configure(unsafe,catalog),"duplicate definition cannot double bonuses")
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	await process_frame;await process_frame
	check(QA.enter_game(world),"actual class confirmation")
	world.set_process(false);world.save_timer=-100000;world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_process(false);actor.set_physics_process(false)
	check(world.card_collections.problem.is_empty(),"actual world runtime initialized")
	# Exercise each real supported effect through the existing final stat path,
	# isolating one cited definition at a time so overlapping collections cannot
	# hide missing or double-counted adapters.
	var exercised: Dictionary={}
	var capabilities: Dictionary=world.card_collections.core.availability.duplicate(true)
	for row: Dictionary in data.collections:
		if not capabilities[row.id].is_empty() or row.effects.size()!=1:continue
		var effect: Dictionary=row.effects[0];var code: String=str(effect.key)+":"+str(effect.unit)
		if exercised.has(code):continue
		exercised[code]=true
		reset_owned()
		check(world.card_collections.core.configure({"schema_version":1,"collections":[row]},world.catalog_db),"isolated real source definition "+row.name)
		world.card_collections.restore_from_owned();world._invalidate_equipment_static()
		var prior: Dictionary=stat_probe()
		for requirement: Dictionary in row.requirements:receive(row.category,requirement.id)
		world._update_hud()
		var after: Dictionary=stat_probe()
		var key: String=str(effect.key)
		if prior.has(key):check(is_equal_approx(float(after[key])-float(prior[key]),float(effect.value)),"actual stat adapter "+code+" via "+row.name)
		else:check(world.card_collections.bonus(code)==float(effect.value),"supported effect retained "+code)
	check(exercised.has("hp_regeneration:flat") and exercised.has("mp_regeneration:flat") and exercised.has("potion_heal:percent") and exercised.has("attack_speed:percent"),"source data exercises recovery, potion and speed effect paths")
	world.card_collections.core.configure(data,world.catalog_db)
	reset_owned()
	for binding: Array in [["변신","신화 : 천둥의 신","melee_hit",2],["변신","어둠의 선생님","max_hp",50],["마법인형","탱커 듀오","mr",1]]:
		reset_owned()
		var row: Dictionary=definition(binding[0],binding[1])
		var prior: Dictionary=stat_probe()
		for q: Dictionary in row.requirements:receive(row.category,q.id)
		check(world._save_game(true)==OK,"verified ID collection acquisition reaches existing save: "+row.name)
		world._update_hud()
		check(world.card_collections.snapshot(row.category).any(func(value: Dictionary) -> bool:return value.id==row.id and value.completed),"verified ID collection is completed in the actual world: "+row.name)
		check(int(stat_probe()[binding[2]])-int(prior[binding[2]])==int(binding[3]),"exact source bonus reaches final world stat: "+row.name)
		var expected: Dictionary=stat_probe();var notices: int=notification_count()
		world._load_game(true)
		check(stat_probe()==expected and notification_count()==notices,"verified ID legacy ownership restores once without notification/regrant: "+row.name)
	reset_owned()
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in world.catalog_db[category]:world.card_draw_fusion.owned[category][Cards.card_id(record)]=true
	world._update_hud()
	var all_rows: Array=world.card_collections.snapshot()
	check(all_rows.size()==139 and all_rows.all(func(row: Dictionary) -> bool:return row.available and row.completed),"actual world applies all 139 definitions; no excluded/blocked definitions remain")
	reset_owned()
	var hp_before: int=world._effective_max_hp();var hit_before: int=world._equipment_accuracy_bonus("melee")
	var log_before: int=notification_count()
	receive("변신","source:62");world._update_hud()
	check(world._effective_max_hp()==hp_before,"incomplete acquisition grants nothing")
	receive("변신","source:61");world._update_hud()
	check(world._effective_max_hp()==hp_before+5,"first acquisition updates actual maximum HP immediately")
	check(notification_count()==log_before+1,"one aggregated completion notification")
	var roll: int=world.card_draw_fusion.rng.state
	for index: int in range(10):world._update_hud()
	check(notification_count()==log_before+1 and world._effective_max_hp()==hp_before+5,"repeat HUD publications never regrant or repeat notification")
	check(world.card_draw_fusion.rng.state==roll,"derived collection checks never use RNG")
	receive("변신","source:61");world._update_hud()
	check(world.card_draw_fusion.spare["변신"]["source:61"]==1 and world._effective_max_hp()==hp_before+5,"duplicate acquisition retains exact effect once")
	world.card_draw_fusion.spare["변신"]["source:61"]=0;world._update_hud()
	check(world._effective_max_hp()==hp_before+5,"zero spendable duplicates retain permanent completion")
	for requirement: Dictionary in wolf.requirements:receive("마법인형",requirement.id)
	world._update_hud();check(world._equipment_accuracy_bonus("melee")==hit_before+1,"doll collection affects real accuracy without equipping")
	var old_data: Dictionary=JSON.parse_string(JSON.stringify(world.card_draw_fusion.export_state()))
	check(world._save_game(true)==OK,"existing save schema persists first acquisitions")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(not saved.has("card_collections") and saved.card_draw_fusion==old_data,"legacy owned field remains sole ledger; no separate rewards/progress migration")
	var base_hp: int=world.max_hp
	var expected_hp: int=world._effective_max_hp()
	var expected_hit: int=world._equipment_accuracy_bonus("melee")
	for iteration: int in range(3):
		world.card_draw_fusion.import_state({});world.card_collections.invalidate();world._invalidate_equipment_static()
		var prior: int=notification_count();world._load_game(true)
		check(world._effective_max_hp()==expected_hp and world._equipment_accuracy_bonus("melee")==expected_hit,"old version-1 owned auto-restores on reload "+str(iteration))
		check(world.max_hp==base_hp and notification_count()==prior,"migration idempotent and silent; base stats not baked "+str(iteration))
	world.card_draw_fusion.spare["변신"]["source:61"]=4
	world._on_card_fusion_requested("변신","일반");hide_reveal()
	check(world.card_draw_fusion.owned["변신"].has("source:61") and world.card_collections.snapshot("변신").any(func(row: Dictionary) -> bool:return row.id==bug.id and row.completed),"actual fusion consumes spare only and retains completed permanent collection")
	await process_frame
	var original_pools: Dictionary=world.card_draw_fusion.pools.duplicate(true)
	for category: String in Cards.CATEGORIES:
		# Fixed real known cards in every grade make the transaction deterministic
		# without modifying production rates or randomness implementation.
		for grade: String in Cards.DRAW_ORDER:
			var pool: Array=original_pools[category][grade]
			world.card_draw_fusion.pools[category][grade]=[pool[0]]
		reset_owned()
		var ticket: String="최상급 "+category+" 뽑기권"
		world.inventory[ticket]=1;world._use_card_pack_item(ticket);hide_reveal()
		check(not world.card_draw_fusion.owned[category].is_empty() and int(world.inventory.get(ticket,0))==0,"real single ticket acquisition path "+category)
		check(world.card_collections.snapshot(category)==world.card_collections.core.derive({"owned":world.card_draw_fusion.owned}).rows.filter(func(row: Dictionary) -> bool:return row.category==category),"single ticket publishes exact new permanent state "+category)
		await process_frame
		# Use the actual catalog-defined pack name (the single ticket suffix differs).
		var pack: String="최상급 "+category+" 뽑기권 11회 팩"
		world.inventory[pack]=1;world._use_card_pack_item(pack);hide_reveal()
		check(int(world.inventory.get(pack,0))==0,"real 11-ticket path "+category)
		await process_frame
		world._on_card_pack_draw_requested(category);hide_reveal();await process_frame
		check(world.card_collections.snapshot(category)==world.card_collections.core.derive({"owned":world.card_draw_fusion.owned}).rows.filter(func(row: Dictionary) -> bool:return row.category==category),"debug acquisition publishes same automatic rules "+category)
	world.card_draw_fusion.pools=original_pools.duplicate(true)
	for category: String in Cards.CATEGORIES:
		var pair: Dictionary=definition(category,{"변신":"고대의 암흑기사","마법인형":"그저 빛","성물":"당근 주면 받을게요"}[category])
		for count: int in [1,11]:
			reset_owned()
			var target: Dictionary=pair.requirements[0]
			for number: int in range(1,pair.requirements.size()):receive(category,pair.requirements[number].id)
			world._update_hud()
			var grade: String=target.grade
			for entry: Dictionary in original_pools[category][grade]:
				if entry.id==target.id:world.card_draw_fusion.pools[category][grade]=[entry];break
			var fixed_seed: int=seed_for_grade(grade);check(fixed_seed>=0,"test seed reaches actual original grade weight")
			world.card_draw_fusion.rng.seed=fixed_seed
			var ticket: String="최상급 "+category+" 뽑기권"+(" 11회 팩" if count==11 else "")
			world.inventory[ticket]=1
			var notices: int=notification_count()
			world._use_card_pack_item(ticket);hide_reveal();await process_frame
			if not world.card_draw_fusion.owned[category].has(target.id):print("DRAW_COMPLETION_TRACE ",category,count," seed=",fixed_seed," target=",target.id," owned=",world.card_draw_fusion.owned[category]," ticket=",world.inventory.get(ticket,0)," recent=",world.hud.log_history.slice(-3))
			check(world.card_collections.snapshot(category).any(func(row: Dictionary) -> bool:return row.id==pair.id and row.completed),"real "+str(count)+" draw auto-completes exact cited collection "+category)
			check(notification_count()==notices+1,"one completion notification after durable draw batch "+category+str(count))
			world.card_draw_fusion.pools=original_pools.duplicate(true)
	reset_owned()
	var rebuilds: int=world.card_collections.rebuild_count
	for index: int in range(500):world._effective_max_hp();world._effective_max_mp();world._equipment_accuracy_bonus("melee")
	check(world.card_collections.rebuild_count==rebuilds,"combat stat reads reuse derived cache without per-frame table scans")
	for index: int in range(5):world._update_hud()
	check(world.card_collections.rebuild_count==rebuilds,"unchanged HUD invalidation hashes ownership but does not rebuild tables")
	var before_rollback: Dictionary=world.card_draw_fusion.export_state()
	var totals_before: Dictionary=world.card_collections.totals.duplicate()
	var notices_before: int=notification_count()
	var rng_before: int=world.card_draw_fusion.rng.state
	world.inventory["최상급 성물 뽑기권"]=1;world.equipment_collections.save_blocked=true
	world._use_card_pack_item("최상급 성물 뽑기권")
	check(world.card_draw_fusion.export_state()==before_rollback and world.card_draw_fusion.rng.state==rng_before,"failed save rolls back ticket draw ownership and RNG")
	check(world.card_collections.totals==totals_before and notification_count()==notices_before,"failed acquisition publishes neither effect nor notification")
	check(int(world.inventory.get("최상급 성물 뽑기권",0))==1,"failed draw retains owned ticket")
	world.equipment_collections.save_blocked=false
	world.queue_free();await process_frame
	if failures.is_empty():print("NORMAL_CARD_COLLECTION_OK ",checks," checks")
	else:print("NORMAL_CARD_COLLECTION_FAILED ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func stat_probe() -> Dictionary:
	world._refresh_equipment_effects()
	return {"max_hp":world._effective_max_hp(),"max_mp":world._effective_max_mp(),"melee_hit":world._equipment_accuracy_bonus("melee"),"ranged_hit":world._equipment_accuracy_bonus("ranged"),"magic_hit":world._equipment_accuracy_bonus("magic"),"melee_damage":world._equipment_additional_damage("melee"),"ranged_damage":world._equipment_additional_damage("ranged"),"magic_damage":world._equipment_additional_damage("magic"),"ac":world._effective_ac(),"mr":world._effective_mr(),"er":world._effective_er(),"damage_reduction":world._damage_reduction_stat(),"pve_damage_reduction":world._catalog_stat_sum("pve_damage_reduction"),"experience_bonus":world._experience_multiplier()*100.0,"stun_hit":world._equipped_numeric_sum("stun_accuracy"),"stun_resistance":world._equipped_numeric_sum("stun_resistance"),"str":world._effective_attribute("STR"),"dex":world._effective_attribute("DEX"),"con":world._effective_attribute("CON"),"int":world._effective_attribute("INT"),"wis":world._effective_attribute("WIS"),"weight_bonus":world._catalog_stat_sum("weightBonus"),"sp":world._catalog_stat_sum("sp"),"hp_regeneration":world.equipment_effects.hp_tick_amount,"mp_regeneration":world.equipment_effects.mp_tick_amount,"potion_heal":world._catalog_stat_sum("potionHealPct") if world.card_collections.bonus("potion_heal:percent")>0 else world._catalog_stat_sum("potionHealFlat"),"attack_speed":world._effective_attack_speed_bonus_percent(),"melee_critical_damage":world._player_critical_damage(20,"melee"),"ranged_critical_damage":world._player_critical_damage(20,"ranged")}
