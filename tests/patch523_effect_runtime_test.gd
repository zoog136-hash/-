extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Native=preload("res://scripts/cards/native_collection_rules.gd")
const API=preload("res://scripts/lineagem_base508.gd")
const SourceUI=preload("res://scripts/ui/source_collection_presentation.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var checks: int=0
var failures: Array[String]=[]
var world: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);push_error(why)
func frames(count: int=4) -> void:
	for i: int in range(count):await process_frame
func cache(values: Dictionary) -> void:
	world.card_collections.current_revision()
	world.card_collections.totals=values
	world.equipment_records_dirty=true;world.equipment_effects_dirty=true
func run() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/patch523_collections.json"))
	var core=Native.new();check(core.configure(data,API.cards().catalog),"current source joins configure")
	var missing: Dictionary={};var pvp_rows: int=0;var supported: int=0;var damp: Dictionary={}
	for row: Dictionary in core.definitions:
		for effect: Dictionary in row.effects:
			var raw: Dictionary=effect.source_original
			if not effect.native_supported and raw.nested_intervals.is_empty():missing[raw.bonus_type.Name]=int(missing.get(raw.bonus_type.Name,0))+1
			if effect.native_supported:
				supported+=1
				check(not core.availability[row.id].any(func(code: String) -> bool:return code=="effect_unsupported:"+Native.effect_code(effect)),"registered effect capability "+str(raw.bonus.ID))
				var denominator: float=float(raw.ui_unit.get("Denominator",0))
				if effect.unit=="percent":check(denominator>0 and float(effect.value)==float(raw.bonus.Value)/denominator,"exact source percentage "+str(raw.bonus.ID))
			if effect.get("runtime_policy","")=="existing_single_player_pvp_to_pve":
				pvp_rows+=1;check(not effect.label.contains("PVP") and raw.bonus_type.Name.contains("PVP"),"PvE projection preserves raw PvP identity")
			if effect.key=="stacked_damage_reduction":damp=effect
	check(missing.is_empty(),"all latest source reward types have explicit consumers/policies")
	check(Native.local_damp_supported(damp) and not damp.source_original.application_target.resolved,"local target13 policy does not falsify source resolution")
	var altered: Dictionary=damp.duplicate(true);altered.source_original.bonus.BonusApplicationTargetID=99
	check(not Native.local_damp_supported(altered),"unknown target is not silently covered by13 policy")
	print("EFFECT_RUNTIME_STAGE source definitions checked")
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(10)
	check(QA.enter_game(world) and not world.map_bootstrap_blocked,"actual Main/current map enters")
	world.set_process(false);world.save_timer=-100000;world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_process(false);actor.set_physics_process(false)
	for category: String in Cards.CATEGORIES:
		world.card_draw_fusion.owned[category]={}
		for record: Dictionary in world.catalog_db[category]:world.card_draw_fusion.owned[category][Cards.card_id(record)]=true
	var profile: Dictionary=data.source_server_limits.filter(func(r: Dictionary) -> bool:return int(r.ServerLimitSetID)==772)[0]
	var context: Dictionary={"source_snapshot":"base508","ServiceRegionCode":profile.ServiceRegionCode,"WorldNo":profile.WorldNo}
	world.card_collections.set_source_server_context(context);world._invalidate_equipment_static()
	var source_totals: Dictionary={}
	world.card_collections.current_revision();source_totals=world.card_collections.totals.duplicate(true)
	check(source_totals.get("damage_reduction_ignore:flat",0)>0 and source_totals.get("pve_damage_reduction:flat",0)>0,"real eligible source collections reach existing damage APIs")
	check(world.card_collections.catalog_bonus("damage_reduction_ignore")==int(source_totals["damage_reduction_ignore:flat"]),"flat pierce uses one existing catalog channel")
	var ledger: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	var save_before: String=FileAccess.get_file_as_string(world.save_path())
	cache({})
	var melee: int=world._melee_damage_stat();var ranged: int=world._ranged_damage_stat();var magic: int=world._magic_damage_stat()
	cache({"damage_reduction_ignore:flat":3,"melee_reduction_ignore:flat":4})
	check(world._melee_damage_stat()==melee+7 and world._ranged_damage_stat()==ranged+3 and world._magic_damage_stat()==magic+3,"flat pierce scoped and counted once")
	cache({"pve_melee_damage:flat":2,"pve_ranged_damage:flat":3,"pve_magic_damage:flat":4})
	check(world._melee_damage_stat()==melee+2 and world._ranged_damage_stat()==ranged+3 and world._magic_damage_stat()==magic+4,"PvP-to-PvE projected damage reaches each real style once")
	cache({})
	var incoming: int=world._pve_damage_after_item_buffs(100)
	cache({"pve_damage_reduction:flat":3})
	check(world._pve_damage_after_item_buffs(100)==maxi(1,incoming-3),"PvP reduction reaches existing PvE defense")
	cache({})
	var target: TwilightMonster=load("res://scenes/Monster.tscn").instantiate();world.monsters_root.add_child(target)
	target.setup({"name":"collection test actor","lv":1,"hp":100000,"atk":3,"ac":0,"mr":0,"sprite_id":"","exp":0},world.player,world,null)
	target.set_process(false);target.set_physics_process(false);target.armor_class=0;target.dead=false
	world.original_skills.status.set_modifiers(target,"fixture",60,{"dg":10})
	var base_hit: float=world.original_skills.physical_hit_chance(0,target,"melee")
	cache({"melee_evasion_ignore:flat":2,"ranged_evasion_ignore:flat":4})
	check(is_equal_approx(world.original_skills.physical_hit_chance(0,target,"melee"),base_hit+.02),"actual physical skill hit reads melee pierce")
	check(is_equal_approx(world.original_skills.physical_hit_chance(0,target,"ranged"),base_hit+.04),"actual physical skill hit reads ranged pierce")
	world.original_skills.status.remove_modifiers(target,"fixture")
	cache({"damage_reduction_ignore:percent":10,"melee_reduction_ignore:percent":20,"pve_damage_amplification:percent":5})
	var original_service=world.original_skills
	world.original_skills=null
	var target_hp: int=target.hp;world._deal_successful_player_hit(target,100,false,"melee")
	check(target_hp-target.hp==135,"actual successful-hit boundary combines generic/type/PvE percent")
	cache({"final_blow_probability:percent":100,"final_blow_damage:flat":2,"final_blow_amplification:percent":10})
	target_hp=target.hp;world._deal_successful_player_hit(target,100,false,"melee",true)
	check(target_hp-target.hp==167,"ordinary attack final blow runs once with explicit local critical base")
	target_hp=target.hp;world._deal_successful_player_hit(target,100,false,"melee",false)
	check(target_hp-target.hp==100,"skill/proc hit never recursively rolls final blow")
	cache({});var rng_before: int=world.rng.state
	check(not world.card_collections.final_blow(100,world.rng).triggered and not world.card_collections.blocks_weapon_hit("melee",world.rng) and world.rng.state==rng_before,"zero new probabilities preserve RNG stream")
	cache({"weapon_block:percent":100})
	var player_hp: int=world._effective_max_hp();world.hp=player_hp
	# Use an ordinary non-safe map position and a deterministic successful hit.
	var old_field=world.field_map;world.field_map=null;target.melee_accuracy=100000
	for i: int in range(20):world._on_player_hit(target,100,"melee")
	check(world.hp==player_hp,"actual incoming physical hits stop at weapon-block boundary")
	check(not world.card_collections.blocks_weapon_hit("magic",world.rng),"weapon block excludes magic")
	world.field_map=old_field
	cache({});var critical: int=world._critical_resistance_stat()
	cache({"melee_critical_resistance:percent":3,"ranged_critical_resistance:percent":4,"magic_critical_resistance:percent":5,"elemental_critical_resistance:percent":2})
	check(world._critical_resistance_stat("melee")==mini(50,critical+3) and world._critical_resistance_stat("magic",true)==mini(50,critical+7),"typed/elemental incoming critical resistance uses correct scopes")
	cache({"while_stun_damage_reduction:flat":2,"while_fear_damage_reduction:flat":3,"stacked_damage_reduction:percent":10})
	world.player.stun_remaining=0;world.player.fear_remaining=0
	check(world.card_collections.incoming_damage(100,"melee")==90,"local target13 applies one separate stacking factor")
	world.player.stun_remaining=5
	check(world.card_collections.incoming_damage(100,"melee")==88,"actual stun condition applies its own flat")
	world.player.fear_remaining=5
	check(world.card_collections.incoming_damage(100,"melee")==86,"separate source status conditions stack once")
	world.player.stun_remaining=0;world.player.fear_remaining=0
	cache({"magic_heal:percent":5})
	check(world.card_collections.magic_heal(100)==105,"magic healing source percentage")
	world.hp=1;var skill: Dictionary={"name":"fixture heal","heal":40,"mp":0,"class":"공용"}
	check(world._cast_job_heal_skill(skill),"actual legacy magic-heal consumer succeeds")
	check(world.hp>41,"actual magic-heal consumer applies source percentage")
	cache({"absolute_mp_regeneration:flat":3});world.mp=0;world.mp_recovery_elapsed=0
	world._tick_catalog_recovery(world.UNIQUE_RECOVERY_INTERVAL)
	check(world.mp==3,"actual existing recovery clock consumes exact absoluteMP value")
	cache({"blessing_charge:percent":5});world.ain_service.blessing=0
	check(world._apply_ain_consumable("드래곤의 다이아몬드",{"kind":"ain_charge"}),"actual Ain charge consumer succeeds")
	check(world.ain_service.blessing==int(round(world.AIN_SERVICE.charge_amount("드래곤의 다이아몬드",world.level)*1.05)),"actual charge applies native5% without changing item cost")
	extra_checks(target,original_service)
	cache(source_totals)
	world.hud.open_normal_card_collections("변신");await frames(6)
	var view=world.hud.normal_card_collection_view
	check(view.effects_filter.item_count>1 and view.effects_filter.get_item_text(0)=="모든 효과","actual collection effect UI opens")
	check(not range(view.effects_filter.item_count).any(func(i: int) -> bool:return view.effects_filter.get_item_text(i).contains("PVP")),"visible projection follows current single-player rule")
	check(world.card_draw_fusion.export_state()==ledger,"derived effects preserve owned/spare/RNG acquisition ledger")
	check(FileAccess.get_file_as_string(world.save_path())==save_before,"combat/stat/UI reads do not write saves")
	# Explicit save and reload retain the exact acquisition identities. No new
	# runtime totals are persisted as a second reward ledger.
	check(not world.source_save_blocked,"actual verified source map allows saving")
	check(world._save_game(true)==OK,"real atomic save after combat fixture")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved.card_draw_fusion.owned==ledger.owned,"saved original card identities remain unchanged")
	world.queue_free();await frames()
	print("PATCH523_EFFECT_RUNTIME_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"supported_effect_rows":supported,"pvp_projected_rows":pvp_rows,"remaining":missing}))
	quit(0 if failures.is_empty() else 1)

func extra_checks(target: TwilightMonster,service) -> void:
	world.original_skills=service
	target.critical_resistance=100
	cache({"life:flat":2,"death:flat":3})
	check(world.card_collections.magic_heal(100)==102,"configured local life conversion")
	var before_hp: int=target.hp;world._deal_successful_player_hit(target,100,false,"melee")
	check(before_hp-target.hp==103,"configured local death conversion reaches actual hit")
	cache({"spell_63_damage:flat":50,"spell_37921_damage:flat":70,"spell_120712_damage:flat":1,"spell_77761_damage:flat":2})
	check(world.card_collections.spell_damage_bonus({"source_m_spell_id":63})==50 and world.card_collections.spell_damage_bonus({"source_m_spell_id":37921})==70,"same bonus type keeps distinct exact spell targets")
	check(world.card_collections.spell_damage_bonus({"id":"lm_b9f1605d690c64f7"})==1,"local base triple-arrow profile selects only base reward")
	world.card_collections.policy_values.triple_arrow_spirit_profile=true
	check(world.card_collections.spell_damage_bonus({"id":"lm_b9f1605d690c64f7"})==2,"explicit spirit profile selects one target without merging variants")
	check(world.card_collections.spell_damage_bonus({"id":"lm_b9f1605d690c64f7","source_m_spell_id":63})==50,"explicit original spell identity has priority over profile")
	world.card_collections.policy_values.triple_arrow_spirit_profile=false
	before_hp=target.hp
	service.deal_damage({"id":"fixture","name":"source spell fixture","power":100,"source_m_spell_id":63,"source_m_snapshot":"base508","attack_type":"magic"},target)
	check(before_hp-target.hp==150,"actual skill damage path consumes only matching original spell bonus")
	cache({"spell_17564_hit:percent":1})
	check(world.card_collections.spell_hit_bonus({"status":"bleed"})==1 and world.card_collections.spell_hit_bonus({"status":"bleed","source_m_spell_id":999})==0,"local bleed alias never overrides an explicit other source spell")
	var selected_seed: int=-1
	var trial:=RandomNumberGenerator.new()
	for seed_value: int in range(10000):
		trial.seed=seed_value;var value: float=trial.randf()
		if value>=.1 and value<.11:selected_seed=seed_value;break
	check(selected_seed>=0,"deterministic status boundary fixture found")
	target.bleed_resistance=0
	var status_skill: Dictionary={"id":"fixture","status":"bleed","status_chance":.1,"duration":1.0,"tick_damage":1}
	cache({});world.rng.seed=selected_seed
	check(not service.status.apply(status_skill,target,world),"actual status consumer fails below the one-point bonus")
	cache({"spell_17564_hit:percent":1});world.rng.seed=selected_seed
	check(service.status.apply(status_skill,target,world),"actual status consumer succeeds with exact source one-point hit bonus")
	cache({});target.magic_resistance=100
	var old_hit: float=world._player_magic_hit_chance(target)
	cache({"magic_penetration:percent":20})
	check(world.card_collections.magic_resistance_after_pierce(100)==80 and world._player_magic_hit_chance(target)>old_hit,"configured magic penetration reaches actual outgoing magic-hit path")
	cache({"physical_magic_defense:percent":10,"ranged_burst_reduction:flat":5})
	check(world.card_collections.incoming_damage(100,"magic",false,{"physical_magic":true})==90 and world.card_collections.incoming_damage(100,"magic",false,{"physical_magic":false})==100,"physical magic fallback retains its own explicit scope")
	check(world.card_collections.incoming_damage(100,"ranged",false,{"hit_count":3})==95 and world.card_collections.incoming_damage(100,"ranged",false,{"hit_count":1})==100,"local tag1 fallback applies only to configured burst attacks")
	check(world.card_collections.incoming_damage(100,"ranged",false,{"hit_count":3,"spell_tags":[]})==100,"explicit original tag context takes priority over burst inference")
	cache({"reduction_efficiency:percent":3,"pve_damage_reduction:percent":20})
	check(world.card_collections.incoming_ignore({"ignore_percent":10})==7,"source efficiency offsets local opponent ignore by configured factor")
	check(world._pve_damage_after_item_buffs(100,7)<world._pve_damage_after_item_buffs(100,10),"actual PvE reduction consumer uses the compensated ignore")
	cache({"final_blow_resistance:percent":100})
	check(not world.card_collections.incoming_final_blow(100,"melee",{"final_blow_probability":100},world.rng).triggered,"original final-blow resistance suppresses explicit incoming probability")
	cache({})
	check(world.card_collections.incoming_final_blow(100,"melee",{"final_blow_probability":100,"final_blow_multiplier":2},world.rng).damage==200,"explicit incoming final-blow context executes its declared multiplier")
	var previous_field=world.field_map;world.field_map=null
	target.melee_accuracy=100000;target.melee_critical_rate=0
	target.collection_combat_context={"final_blow_probability":100,"final_blow_multiplier":2}
	var maximum: int=world._effective_max_hp();world.hp=maximum;world.rng.seed=42
	world._on_player_hit(target,100,"melee");var unprotected: int=maximum-world.hp
	cache({"final_blow_resistance:percent":100});world.hp=maximum;world.rng.seed=42
	world._on_player_hit(target,100,"melee")
	check(unprotected>maximum-world.hp,"actual NPC hit path consumes final-blow resistance")
	world.field_map=previous_field;target.collection_combat_context={}
	world.card_collections.policy_values.estimates_enabled=false
	cache({"life:flat":2,"death:flat":3,"stacked_damage_reduction:percent":10,"weapon_block:percent":100,"final_blow_probability:percent":100,"magic_penetration:percent":20})
	check(world.card_collections.magic_heal(100)==100 and world.card_collections.death_damage_bonus()==0 and world.card_collections.incoming_damage(100,"melee")==100 and world.card_collections.magic_resistance_after_pierce(100)==100,"estimate switch disables only local interpretation consumers")
	var rng_before: int=world.rng.state
	check(not world.card_collections.final_blow(100,world.rng).triggered and not world.card_collections.blocks_weapon_hit("melee",world.rng) and world.rng.state==rng_before,"disabled estimates make no hidden probability rolls")
	world.card_collections.import_policy({"schema":99,"future_key":[1,2,3]})
	check(world.card_collections.export_policy()=={"schema":99,"future_key":[1,2,3]} and not world.card_collections.estimated(),"unknown saved policy preserved without applying guesses")
	check(not world.card_collections.Policy.validate({"final_blow_multiplier":NAN}).ok and not world.card_collections.Policy.validate({"ranged_burst_min_hits":2.5}).ok,"nonfinite/fractional policy values rejected")
	world.card_collections.import_policy({})
