extends "res://tests/patch523_equipment_invokes_main_test.gd"
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world,"마법사"),"actual Main/class/source map")
 world.player.set_physics_process(false);world.field_population.configure(world,null);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
 var book: RefCounted=world.patch523_equipment
 var rows: Dictionary={};var cases: Dictionary={}
 for id: String in book.data.equipment_runtime:
  for row: Dictionary in book.data.items[id].enchant_effects:
   var bonus: Dictionary=book.data.bonuses[str(int(row.BonusID))]
   if (int(bonus.BonusTypeID)==4 and int(bonus.BonusApplicationTypeID)==2 and int(bonus.BonusApplicationTargetID)==6):
    check(int(row.ID) not in book.data.equipment_runtime[id].unconnected_effect_row_ids,"all exact conditional source rows compile "+str(row.ID))
    rows[str(int(row.ID))]=true
    var bless: int=2 if int(row.BlessCode)==2 else 1
    cases[id+":"+str(bless)+":"+str(int(row.EnchantLevel))]={"id":id,"bless":bless,"rank":int(row.EnchantLevel)}
 check(rows.size()==2 and cases.size()==2,"all2 exact stunned-magic source rows; FixedDesc remains spell-scoped evidence")
 var actor: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(actor)
 actor.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
 actor.set_process(false);actor.set_physics_process(false);actor.max_hp=1000000;actor.hp=actor.max_hp;actor.monster_type="일반";actor.undead=false
 for sample: Dictionary in cases.values():
  var record: Dictionary=own(world,sample.id,sample.rank,sample.bless)
  record["instance_id"]="90001";world.equipped_items={str(record.slot):record};world._invalidate_equipment_static()
  check(world._equipment_inven_sum("source_stun_magic_damage")==5,"source typed stunned magic value5 "+str(sample))
  var final=preload("res://scripts/crafting/patch523_final_blow.gd")
  var policy: Dictionary=world.PATCH523_ENHANCE.policy()
  actor.stun_remaining=10;world.player.stun_remaining=0
  policy.source_stun_condition_subject="disabled"
  check(final.conditional_magic_damage(world,actor,true)==0,"explicit disabled condition policy preserves source but produces no guessed damage")
  policy.source_stun_condition_subject="self_status"
  check(final.conditional_magic_damage(world,actor,true)==0,"configured actor direction never falls back to target status")
  world.player.stun_remaining=10
  check(final.conditional_magic_damage(world,actor,true)==5,"explicit self status policy consumes exact source5")
  world.player.stun_remaining=0;policy.source_stun_condition_subject="target_status"
  policy.source_conditional_magic_scope="disabled"
  check(final.conditional_magic_damage(world,actor,true)==0,"conditional spell placement can be disabled without changing original value")
  policy.source_conditional_magic_scope="all_successful_hits"
  check(final.conditional_magic_damage(world,actor,false)==5,"configured all-hit scope is explicit rather than source claim")
  policy.source_conditional_magic_scope="spell_hits_only"
  var skills: Object=world.original_skills;world.original_skills=null
  for stunned: bool in [false,true]:
   actor.stun_remaining=10 if stunned else 0;actor.hp=actor.max_hp;world._refresh_equipment_effects()
   var factor: float=1+clampf(float(world.equipment_effects.damage_amp_pct),0,300)/100
   world._deal_successful_player_hit(actor,100,false,"magic",true,true)
   check(actor.max_hp-actor.hp==int(round((105 if stunned else 100)*factor)),"actual spell applies source +5 only to stunned target")
   actor.hp=actor.max_hp;seed_integer(world,100000,false)
   world._deal_successful_player_hit(actor,100,false,"melee",true,false)
   check(actor.max_hp-actor.hp==int(round(100*factor)),"source conditional magic never becomes normal attack damage")
  actor.stun_remaining=0;actor.fear_remaining=10;actor.hp=actor.max_hp
  world._deal_successful_player_hit(actor,100,false,"magic",true,true)
  check(actor.max_hp-actor.hp==100,"SpecialResistanceType8 Fear is not Stun6")
  actor.fear_remaining=0;world.original_skills=skills
  world.inventory["화살"]=0;world.inventory["총알"]=0
  check(world._save_game(true)==OK,"actual conditional source equipment saves")
  var rng_after: int=world.rng.state
  world._load_game(true)
  check(world.rng.state==rng_after,"conditional source transaction RNG survives scene restoration")
  world.hud.open_patch523_equipment_info();await process_frame
  var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  check(info!=null and info.detail.text.contains("스턴 조건 마법 피해"),"actual source equipment UI discloses conditional effect "+str(sample))
 print("PATCH523_CONDITIONAL_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":rows.size(),"controlled_actor_stats":true}))
 actor.queue_free();world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
