extends SceneTree
## Real Main stat consumers and successful-hit dispatcher, no art fixture claims.
const QA=preload("res://tests/qa_class_selection.gd")
const Registry=preload("res://scripts/lineagem_base508.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
var checks: int=0
var errors: Array[String]=[]
var world: Node
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func clear_equipped() -> void:
	world.equipped_catalog={"변신":{},"마법인형":{},"성물":{}};world.equipped_items={};world._invalidate_equipment_static()
func select_relic(card_id: int) -> bool:
	var id: String="source:m508:98:"+str(card_id)
	world.card_draw_fusion.owned["성물"][id]=true
	return world.option_awakening.select_relic_subslot(id).ok
func run() -> void:
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.field_population.set_process(false)
	for frame: int in range(3):await process_frame
	check(QA.enter_game(world) and not world.map_bootstrap_blocked,"actual Main and verified current map")
	world.player.set_physics_process(false);world.save_timer=-10000;world.level=1
	for child: Node in world.monsters_root.get_children():child.set_physics_process(false)
	clear_equipped()
	var nemesis: Dictionary=Registry.canonical({"source":"lineagem_patch523","sourceId":"m523:2:25152"})
	world.card_draw_fusion.owned["마법인형"]["source:m523:2:25152"]=true
	var before: Dictionary={}
	for style: String in ["melee","ranged","magic"]:before[style]=world._player_critical_rate(style)
	world._equip_catalog("마법인형",nemesis)
	for style: String in ["melee","ranged","magic"]:check(world._player_critical_rate(style)-int(before[style])==2,"actual Nemesis "+style+" critical percentage adds exactly2 without description double count")
	clear_equipped()
	var dg: int=world._effective_dg();var er: int=world._effective_er()
	var spear: Dictionary=Registry.canonical({"source":"lineagem_patch523","sourceId":"m523:1:25344"})
	world.card_draw_fusion.owned["변신"]["source:m523:1:25344"]=true;world._equip_catalog("변신",spear)
	check(world._effective_dg()-dg==2 and world._effective_er()-er==2,"actual spearman melee and ranged evasion")
	clear_equipped();var damage: int=world._melee_damage_stat()
	var warrior: Dictionary=Registry.canonical({"source":"lineagem_patch523","sourceId":"m523:1:25354"})
	world.card_draw_fusion.owned["변신"]["source:m523:1:25354"]=true;world._equip_catalog("변신",warrior)
	check(world._melee_damage_stat()-damage==3,"actual warrior PVE melee damage")
	clear_equipped();world.option_awakening.progress[Unlock.FIELD]=Unlock.marker()
	check(world.card_collections.set_source_server_context({"source_snapshot":"base508","ServiceRegionCode":"KR","WorldNo":1}),"explicit test server tuple supplied without map/language inference")
	for entry: Array in [[23132,"_melee_accuracy_stat",2],[23122,"_ranged_accuracy_stat",2],[24418,"_magic_accuracy_stat",2],[21858,"_melee_accuracy_stat",1],[21868,"_ranged_accuracy_stat",1]]:
		check(world.option_awakening.select_relic_subslot("").ok,"release previous test relic")
		var baseline: int=int(world.call(entry[1]))
		check(select_relic(int(entry[0])),"select exact secondary "+str(entry[0]))
		check(int(world.call(entry[1]))-baseline==int(entry[2]),"actual secondary accuracy/evasion-ignore consumer "+str(entry[0]))
	for entry: Array in [[22082,"melee"],[22102,"ranged"],[22092,"magic"]]:
		world.option_awakening.select_relic_subslot("");var baseline: int=world._catalog_damage_bonus(str(entry[1]))
		check(select_relic(int(entry[0])) and world._catalog_damage_bonus(str(entry[1]))-baseline==1,"actual secondary style reduction-ignore "+str(entry[0]))
	for entry: Array in [[22443,"melee"],[22453,"ranged"],[22463,"magic"]]:
		world.option_awakening.select_relic_subslot("");var baseline: int=world._player_critical_damage(100,str(entry[1]))
		check(select_relic(int(entry[0])) and world._player_critical_damage(100,str(entry[1]))-baseline==2,"actual secondary flat critical damage "+str(entry[0]))
	world.option_awakening.select_relic_subslot("");var incoming: int=world._pve_damage_after_item_buffs(10000)
	check(select_relic(25012) and incoming-world._pve_damage_after_item_buffs(10000)==200,"actual secondary two-percent PVE reduction")
	check(select_relic(22182),"actual contextual relic selected")
	var target: Node=load("res://scenes/Monster.tscn").instantiate();root.add_child(target);target.set_physics_process(false);target.dead=false;target.hp=10000;target.max_hp=10000
	var probe:=RandomNumberGenerator.new()
	for seed_value: int in range(1,10000):
		probe.seed=seed_value
		if probe.randi_range(0,999999)<30000:world.rng.seed=seed_value;break
	world.hp=100;world.equipped_catalog={"변신":{},"마법인형":{},"성물":{}};world._invalidate_equipment_static()
	var original: Variant=world.original_skills;var skills: Array=world.skills_db
	world.original_skills=null;world.skills_db=[]
	world._try_trigger_passives("on_hit",target,"melee",true,false)
	check(target.hp==9499 and world.option_awakening.combat.fired==[16572],"actual successful-hit dispatcher applies source500+1d1 fixed magic damage once")
	var cooldown: Dictionary=world.skill_cooldowns.duplicate(true)
	world._try_trigger_passives("on_hit",target,"melee",true,false)
	check(target.hp==9499 and world.skill_cooldowns==cooldown,"actual dispatcher preserves source cooldown on repeated hit")
	world.original_skills=original;world.skills_db=skills
	world.option_awakening.select_relic_subslot("")
	var identity: String="source:m523:2:25152"
	var first_spell: int=int(world.skill_awakening.core.candidates(identity)[0].spell_id)
	var threshold: int=int(world.skill_awakening.core.profile(identity,1).experience_row.CumExp)
	world.skill_awakening.progress.cards[identity]={"spell_id":first_spell,"level":1,"experience":str(threshold-1)}
	world.equipped_catalog["마법인형"]=nemesis;world._invalidate_equipment_static();world.experience=0;world.exp_need=2000000000
	var hp_before: int=world._effective_max_hp()
	target.monster_name="__growth_hunt_fixture__";target.exp_reward=137;target.gold_reward=0;target.drop_items.clear();target.dead=true;target.hp=0;target.life_id=81234
	world._on_monster_died(target)
	var gained: int=world.experience
	check(gained>0 and world.skill_awakening.progress.cards[identity].experience==str(threshold-1+gained),"real monster reward grants identical card EXP without taking player EXP")
	check(world.skill_awakening.progress.cards[identity].level==2,"real hunting crosses configured source threshold")
	var hp_delta: int=int(world.skill_awakening.core.profile(identity,2).hp)-int(world.skill_awakening.core.profile(identity,1).hp)
	check(world._effective_max_hp()-hp_before==hp_delta,"hunting-grown source HP profile reaches actual max HP")
	check(int(world.hud.character_state.max_hp)==world._effective_max_hp(),"card-only level-up immediately publishes the new HP maximum to the real HUD")
	world._on_monster_died(target)
	check(world.experience==gained and world.skill_awakening.progress.cards[identity].experience==str(threshold-1+gained),"duplicate death notification grants no second player or card EXP")
	check(world._save_game(true)==OK,"player and hunt card growth save through real atomic writer")
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(disk.card_skill_awakening.cards[identity].level==2 and int(disk.experience)==gained,"hunt card level and player experience share durable save")
	target.queue_free();world.queue_free();await process_frame
	print("PATCH523_LIVE_CARD_EFFECTS ",JSON.stringify({"checks":checks,"errors":errors,"scope":"ACTUAL_MAIN_STAT_CONSUMERS_AND_HIT_DISPATCH; ORIGINAL_PIXELS_NOT_TESTED"}));quit(0 if errors.is_empty() else 1)
