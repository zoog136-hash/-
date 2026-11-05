extends "res://tests/patch523_equipment_invokes_main_test.gd"
## All36 newly connected source rows; controlled owned equipment and actor.
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world,"다크엘프"),"actual Main/class/source map")
 world.player.set_physics_process(false);world.field_population.configure(world,null);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
 check(world.install_patch523_craft_catalog_zip("/workspace/pr238-full-drive239/TWILIGHT_patch523_full_items_38ee3ec7.zip"),"reuse held full source catalog with actual installation API")
 var book: RefCounted=world.patch523_equipment
 check(book.problem.is_empty() and book.recipes.size()==1045,"local delta preserves1045 source recipes")
 var actor: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(actor)
 actor.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
 actor.set_process(false);actor.set_physics_process(false);actor.max_hp=1000000;actor.hp=actor.max_hp;actor.undead=false;actor.monster_type="일반";actor.global_position=world.player.global_position+Vector2(32,0)
 var skills: Object=world.original_skills;world.active_skill_buffs={}
 var weapon_rows: Dictionary={};var flat_rows: Dictionary={};var states: int=0
 var policy: Dictionary=world.PATCH523_ENHANCE.policy()
 for id: String in ["498","30773"]:
  for rank: int in range(1,16):
   for bless: int in [1,2]:
    var record: Dictionary=own(world,id,rank,bless);record["instance_id"]="90001";world.equipped_items={"weapon":record};world._invalidate_equipment_static()
    var live: Array=COMBAT.active(world,"attack_weapon_scale")
    check(live.size()==1 and int(live[0].option.ID)==681,"exact source weapon/physical rank/bless qualifies "+id+str([rank,bless]))
    if live.size()!=1:continue
    var source: Dictionary={}
    for row: Dictionary in book.data.items[id].enchant_effects:
     if int(row.EnchantLevel)==rank and int(book.data.bonuses[str(int(row.BonusID))].BonusApplicationTargetID)==681:source=row;weapon_rows[str(int(row.ID))]=true;break
    check(not source.is_empty() and int(live[0].probability)==int(book.data.bonuses[str(int(source.BonusID))].Value) and int(live[0].option.Param1)==2000000,"raw source chance and per-million scale retained")
    var weight: int=int(live[0].probability)
    seed_integer(world,weight,true)
    check(COMBAT.weapon_scale(world,7,"melee",actor)==14 and COMBAT.weapon_fired.size()==1,"all source weapon states amplify only supplied weapon roll")
    seed_integer(world,weight,false)
    check(COMBAT.weapon_scale(world,7,"melee",actor)==7 and COMBAT.weapon_fired.is_empty(),"all failed source rolls preserve weapon base")
    var rng_before: int=world.rng.state
    check(COMBAT.weapon_scale(world,0,"melee",actor)==0 and world.rng.state==rng_before,"zero weapon base consumes no proc RNG")
    policy.source_weapon_scale_scope="disabled"
    check(COMBAT.weapon_scale(world,7,"melee",actor)==7 and world.rng.state==rng_before,"explicit disabled scope preserves damage/RNG")
    policy.source_weapon_scale_scope="normal_weapon_roll_only"
    states+=1
 var kinds: Dictionary={"882":"melee","883":"ranged","885":"magic"}
 for id: String in kinds:
  var by_rank: Dictionary={}
  for row: Dictionary in book.data.items[id].enchant_effects:
   var bonus: Dictionary=book.data.bonuses[str(int(row.BonusID))]
   if int(bonus.BonusTypeID) not in [3342,462,2102]:continue
   flat_rows[str(int(row.ID))]=true;by_rank[int(row.EnchantLevel)]=bonus
  for rank: int in by_rank:
   for bless: int in [1,2]:
    var record: Dictionary=own(world,id,rank,bless);record["instance_id"]="90001";world.equipped_items={"rune":record};world._invalidate_equipment_static()
    var kind: String=kinds[id];var key: String="source_"+kind+"_flat_reduction_ignore"
    var amount: int=int(by_rank[rank].Value)
    check(int(world._equipment_inven_sum(key))==amount,"exact source Unit1 typed ignore sum "+id+str([rank,bless]))
    for channel: String in ["melee","ranged","magic"]:
     policy.source_typed_flat_ignore_consumer="disabled"
     var before: int=world._equipment_additional_damage(channel)
     policy.source_typed_flat_ignore_consumer="existing_typed_flat_damage_projection"
     check(world._equipment_additional_damage(channel)-before==(amount if channel==kind else 0),"current damage-stat consumer projects only exact typed source channel")
    states+=1
 check(weapon_rows.size()==15 and flat_rows.size()==21,"entire36 source-row delta exercised, not samples")
 # Execute the actual normal-hit production boundary with only its weapon
 # component doubled. Flat stats, later effects and critical roll stay separate.
 var record: Dictionary=own(world,"498",15,1);record["instance_id"]="90001";world.equipped_items={"weapon":record};world._invalidate_equipment_static()
 var old_depth: int=world.original_skills.proc_depth
 world.original_skills.proc_depth=1 # suppress unrelated learned-skill procs, keep required catalog APIs alive
 var maximum: int=world.ITEM_OPTIONS.weapon_size_damage(world._equipped_weapon_record(),false)
 var probe:=RandomNumberGenerator.new();var selected: int=-1;var rolled: int=0
 for candidate: int in range(100000):
  probe.seed=candidate
  if probe.randf()>=world._normal_attack_hit_chance(actor,"melee"):continue
  var base: int=probe.randi_range(1,maximum)
  if probe.randi_range(0,999999)>=150000:continue
  if probe.randf()<world._critical_chance(world._player_critical_rate("melee"),actor.critical_resistance):continue
  selected=candidate;rolled=base;break
 check(maximum>0 and selected>=0,"actual weapon roll/hit/proc/noncritical sequence reachable")
 if selected>=0:
  actor.hp=actor.max_hp;world._refresh_equipment_effects()
  var normal: int=maxi(1,world._melee_damage_stat()+rolled*2)
  normal=world._elemental_damage_to_monster(normal,world._normal_attack_element(),actor)+int(world.consumable_service.call("weapon_element_bonus",world._equipped_weapon_record(),actor))
  var expected: int=maxi(1,int(round(normal*(1+clampf(float(world.equipment_effects.damage_amp_pct),0,300)/100))))+world._source_elemental_flat_damage(actor,false)+(1 if world._has_hp_absorption() else 0)+maxi(0,int(world._equipment_inven_sum("source_attack_drain_hp")))
  world.rng.seed=selected;world._resolve_normal_attack(actor,"melee")
  check(actor.max_hp-actor.hp==expected and COMBAT.weapon_fired.size()==1,"actual normal resolver doubles rolled weapon part once before later stages")
 world.original_skills.proc_depth=old_depth
 for id: String in ["498","30773","882","883","885"]:
  var rank: int=15 if id in ["498","30773"] else 8
  var equipped: Dictionary=own(world,id,rank,1);equipped["instance_id"]="90001";world.equipped_items={str(equipped.slot):equipped};world._invalidate_equipment_static()
  world.inventory["화살"]=0;world.inventory["총알"]=0
  check(world._save_game(true)==OK,"new exact source effect saves "+id)
  var rng_before: int=world.rng.state
  world._load_game(true)
  check(world.rng.state==rng_before,"source effect reload keeps committed RNG "+id)
  world.hud.open_patch523_equipment_info();await process_frame
  var panel: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  check(panel!=null and panel.detail.text.contains("TWILIGHT") and (panel.detail.text.contains("무기 기본 피해") if id in ["498","30773"] else panel.detail.text.contains("게임 추가 피해 해석")),"actual source equipment UI discloses rule basis "+id)
 world.original_skills=skills;actor.queue_free();world.queue_free();await process_frame
 print("PATCH523_LOCAL36_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_weapon_rows":weapon_rows.size(),"source_typed_rows":flat_rows.size(),"physical_states":states,"controlled_equipment":true,"delivery":"LOCAL_ONLY"}))
 quit(0 if failures.is_empty() else 1)
