extends "res://tests/patch523_equipment_invokes_main_test.gd"
const SOURCE=preload("res://scripts/crafting/patch523_equipment_spells.gd")
func wear(world: TwilightWorld,id: String,rank: int,bless: int) -> Dictionary:
 var record: Dictionary=own(world,id,rank,bless);record["instance_id"]="90001";world.skill_cooldowns.clear()
 var limits: Dictionary=world.PATCH523_ITEM_USE.definition(record)
 if not limits.get("class_names",[]).is_empty():world.job_class=str(limits.class_names[0])
 var slot: String=world._equipment_slot_base(record)
 if slot in ["earring","ring","seal"]:slot+="1"
 world.equipped_items={slot:record};world._invalidate_equipment_static()
 return record
func seed_both(world: TwilightWorld,weight: int,hit: int) -> void:
 var probe:=RandomNumberGenerator.new()
 for seed: int in range(100000):
  probe.seed=seed
  if weight<1000000 and probe.randi_range(0,999999)>=weight:continue
  if hit<1000000 and probe.randi_range(0,999999)>=hit:continue
  world.rng.seed=seed;return
 check(false,"two distinct source probability stages reachable")
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world,"다크엘프"),"actual Main/held full source catalog")
 world.player.set_physics_process(false);world.field_population.configure(world,null);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
 world.level=100;world.active_skill_buffs={};world.original_skills.status.clear()
 var actor: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(actor)
 actor.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
 actor.set_process(false);actor.set_physics_process(false);actor.max_hp=1000000;actor.hp=actor.max_hp;actor.magic_resistance=0;actor.monster_level=100;actor.status_immunities=[];actor.global_position=world.player.global_position+Vector2(1,0)
 var options: Dictionary={}
 for o: Dictionary in world.patch523_equipment.data.enchantment.InvokeOption:options[str(int(o.ID))]=o
 var cases: Dictionary={};var profiles: Dictionary={}
 for id: String in world.patch523_equipment.data.equipment_runtime:
  if not world.patch523_equipment.data.get("equipment_spell_item_constraints",{}).has(id):continue
  var c: Dictionary=world.patch523_equipment.data.equipment_spell_item_constraints[id];var expired: bool=false
  for deadline: Dictionary in c.delete_times:
   if Time.get_unix_time_from_system()>=float(deadline.local_unix)-540*60:expired=true
  var runtime: Dictionary=world.patch523_equipment.data.equipment_runtime[id]
  for bless: String in runtime.invokes:
   for rank: String in runtime.invokes[bless]:
    for e: Dictionary in runtime.invokes[bless][rank]:
     if e.kind!="attack_source_spell":continue
     var option: Dictionary=options[str(int(e.option_id))] if e.has("option_id") else e.option
     var profile: Dictionary=world.patch523_equipment.data.equipment_spell_profiles[str(int(option.Param1))]
     if profile.mode!="source_buff_modifiers":continue
     var row: int=int(e.row_id)
     if not cases.has(row) or (cases[row].expired and not expired):cases[row]={"id":id,"bless":int(bless),"rank":int(rank),"expired":expired,"row":row,"profile":profile,"option_id":int(option.ID),"weight":int(e.probability)}
 print("NATIVE_BUFF_STAGE Main/source cases ready ",cases.size())
 var applied_rows: int=0;var expired_rows: int=0;var zero_rows: int=0
 var actual_hp_proofs: int=0;var deduplicated_rows: int=0
 for case: Dictionary in cases.values():
  var record: Dictionary=wear(world,case.id,case.rank,case.bless);world.original_skills.status.clear();actor.hold_remaining=0;actor.hp=actor.max_hp
  var active: Array=COMBAT.active(world,"attack_source_spell");var selected: Dictionary={}
  for e: Dictionary in active:
   if int(e.row_id)==int(case.row):selected=e;break
  if selected.is_empty():
   var stronger: bool=false
   for e: Dictionary in active:
    if int(e.option.ID)==int(case.option_id) and int(e.probability)>=int(case.weight):stronger=true
   check(stronger,"same-option source duplicate follows existing strongest-probability policy")
   if stronger:deduplicated_rows+=1;print("NATIVE_BUFF_DEDUPLICATED_SOURCE_ROW ",case.row)
   else:printerr("NATIVE_BUFF_MISSING_ROW ",case.row)
   continue
  check(true,"compact source option hydration/exact physical row")
  var data: Dictionary=SOURCE.buff_values(case.profile)
  check(not data.is_empty(),"entire original buff profile/units/qualifiers retained")
  if data.is_empty():continue
  var before_rng: int=world.rng.state;var ownership: String=JSON.stringify([world.inventory,world.item_instances])
  if case.expired:
   var denied: Dictionary=COMBAT.try_source_spell(world,selected,actor,"melee",true,false)
   check(denied.is_empty() and world.rng.state==before_rng and world.original_skills.status.debuffs.is_empty(),"expired original item does not draw/apply/regrant")
   expired_rows+=1;continue
  check(SOURCE.item_reason(world,record,case.id).is_empty(),"actual class/level/source period gate")
  var hit: int=SOURCE.buff_chance_raw(world,case.profile,actor)
  if int(selected.probability)<=0 or hit<=0:
   COMBAT.try_source_spell(world,selected,actor,"melee",true,false)
   check(world.original_skills.status.debuffs.is_empty(),"zero original proc or spell-hit chance grants no effect")
   zero_rows+=1;continue
  seed_both(world,int(selected.probability),hit)
  var result: Dictionary=COMBAT.try_source_spell(world,selected,actor,"melee",true,false)
  check(result.get("ok",false) and result.get("activated",false) and result.get("hit",false) and result.get("applied",false),"actual source dispatcher/SkillService applies entire buff")
  for key: String in data.modifiers:
   check(is_equal_approx(world.original_skills.status.modifier(actor,key),float(data.modifiers[key])),"all original buff numeric fields reach life-scoped host consumers")
  check(float(result.get("duration",0))>=float(data.SpellDebuffMinDuration) and float(result.get("duration",0))<=float(data.SpellDebuffMaxDuration),"original seconds/duration interval")
  check(JSON.stringify([world.inventory,world.item_instances])==ownership,"zero-cost buff leaves exact owned source/UUID intact")
  if data.modifiers.has("source_hold"):check(actor.is_held(),"real actor immobilization consumer")
  if data.modifiers.has("source_melee_hit"):check(world._monster_accuracy_for_attack_type(actor,"melee")==actor.melee_accuracy+int(data.modifiers.source_melee_hit),"actual NPC hit consumer")
  if data.modifiers.has("source_ranged_hit"):check(world._monster_accuracy_for_attack_type(actor,"ranged")==actor.ranged_accuracy+int(data.modifiers.source_ranged_hit),"actual NPC ranged hit consumer")
  if data.modifiers.has("source_hp_heal_decrease_raw"):check(actor.source_option_healing(100)==maxi(0,int(100*(1-clampf(float(data.modifiers.source_hp_heal_decrease_raw)/1000000.0,0,1)))),"actual NPC recovery consumer")
  if actual_hp_proofs<3 and (data.modifiers.has("reduction") or data.modifiers.has("source_melee_reduction_pct")):
   var before: int=actor.hp;world.original_skills.proc_depth=1
   world._deal_successful_player_hit(actor,100,false,"melee",true,true)
   var stolen: int=1 if world._has_hp_absorption() else 0
   var amplified: int=maxi(1,int(round(100*(1+clampf(float(world.equipment_effects.damage_amp_pct),0,300)/100))))
   var expected: int=maxi(1,amplified-int(data.modifiers.get("reduction",0)))
   expected=maxi(1,int(round(expected*(1-float(data.modifiers.get("source_melee_reduction_pct",0))/100.0))))+stolen
   check(before-actor.hp==expected,"actual target HP consumes native flat/typed reduction without recursive proc")
   world.original_skills.proc_depth=0;actual_hp_proofs+=1
  world.original_skills.status.tick(float(data.SpellDebuffMaxDuration)+1);actor._tick_hold(float(data.SpellDebuffMaxDuration)+1)
  check(world.original_skills.status.debuffs.is_empty() and not actor.is_held(),"real status clock expires this NPC life only")
  profiles[str(int(case.profile.source_spell.ID))]=true;applied_rows+=1
 # Compact old damage and counter schemas remain executable after hydration.
 wear(world,"335782",15,1);actor.hp=actor.max_hp;seed_integer(world,150000,true)
 check(COMBAT.fixed_counter(world,actor,"melee",100)==0 and actor.max_hp-actor.hp==700,"old validated counter path survives compact storage")
 var sample: Dictionary=cases.values().filter(func(c: Dictionary) -> bool:return not c.expired)[0]
 wear(world,sample.id,sample.rank,sample.bless);world.hud.open_patch523_equipment_info();await process_frame
 var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
 check(info!=null and info.detail.text.contains("TWILIGHT") and info.detail.text.contains("장비 발동 실행 자격"),"existing actual equipment information screen")
 world.inventory["화살"]=0;world.inventory["총알"]=0
 check(world._save_game(true)==OK,"source physical ownership/source cooldown save")
 var rng_before: int=world.rng.state;world._load_game(true)
 check(world.item_instances.has("90001") and world.rng.state==rng_before,"reconnect preserves physical UUID and committed RNG")
 check(cases.size()==1216,"all1216 new distinct buff rows, not a sample")
 print("PATCH523_NATIVE_BUFF_HANDOFF_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_buff_rows":cases.size(),"applied_rows":applied_rows,"source_expired_rows":expired_rows,"zero_chance_rows":zero_rows,"deduplicated_rows":deduplicated_rows,"live_spell_profiles":profiles.size(),"actual_hp_proofs":actual_hp_proofs,"controlled_qa_ownership":true,"status":"LOCAL_ONLY"}))
 actor.queue_free();world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
