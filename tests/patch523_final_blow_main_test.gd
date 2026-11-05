extends "res://tests/patch523_equipment_invokes_main_test.gd"
const FINAL=preload("res://scripts/crafting/patch523_final_blow.gd")
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world,"마법사"),"actual Main class selection")
 world.player.set_physics_process(false);world.field_population.set_process(false)
 var book: RefCounted=world.patch523_equipment
 var rows: Dictionary={};var cases: Dictionary={}
 for id: String in book.data.equipment_runtime:
  var raw: Dictionary=book.data.items[id]
  for row: Dictionary in raw.enchant_effects:
   var bonus: Dictionary=book.data.bonuses[str(int(row.BonusID))]
   if book.data.bonus_types[str(int(bonus.BonusTypeID))].Name not in FINAL.FIELD_NAMES:continue
   check(int(row.ID) not in book.data.equipment_runtime[id].unconnected_effect_row_ids,"source final blow row really compiles "+str(row.ID))
   rows[str(int(row.ID))]=true
   for bless: int in [1,2]:cases[id+":"+str(bless)+":"+str(int(row.EnchantLevel))]={"id":id,"bless":bless,"rank":int(row.EnchantLevel)}
 check(rows.size()==56,"all56 source final-blow rows")
 var target: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(target)
 target.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
 target.set_process(false);target.set_physics_process(false);target.max_hp=1000000;target.undead=false;target.monster_type="일반"
 var skills: Object=world.original_skills;world.original_skills=null
 var live_cases: int=0
 for sample: Dictionary in cases.values():
  var record: Dictionary=own(world,sample.id,sample.rank,sample.bless)
  record["instance_id"]="90001";world.equipped_items={"crystal":record};world._invalidate_equipment_static()
  # Independently read source rows, including exact raw0 fallback selection.
  var expected: Dictionary={"chance_pct":0.0,"amp_pct":0.0};var groups: Dictionary={}
  for row: Dictionary in book.data.items[sample.id].enchant_effects:
   var group: String=str(int(row.ItemEnchantBonusGroupID))
   if not groups.has(group):groups[group]=[]
   groups[group].append(row)
  for values: Array in groups.values():
   var codes: Array=[]
   for row: Dictionary in values:
    if int(row.BlessCode) not in codes:codes.append(int(row.BlessCode))
   var selected: int=sample.bless if sample.bless in codes else 0
   for row: Dictionary in values:
    if int(row.EnchantLevel)!=sample.rank or int(row.BlessCode)!=selected:continue
    var bonus: Dictionary=book.data.bonuses[str(int(row.BonusID))]
    var kind: Dictionary=book.data.bonus_types[str(int(bonus.BonusTypeID))]
    if kind.Name=="FinalBlowProbability":expected.chance_pct+=float(bonus.Value)/10000.0
    if kind.Name=="FinalBlowAdditionalScale":expected.amp_pct+=float(bonus.Value)/10000.0
  target.stun_remaining=10
  var total: Dictionary=FINAL.totals(world,target)
  check(total==expected,"actual worn values equal raw source probability/amplification "+str(sample))
  if sample.id=="213611" and ((sample.bless==1 and sample.rank==6) or (sample.bless==2 and sample.rank==5)):
   target.stun_remaining=0
   check(FINAL.totals(world,target).chance_pct==0,"conditional source final blow cannot leak to an unstunned target")
   target.stun_remaining=10
  var before_rng: int=world.rng.state
  check(FINAL.damage(world,100,true,target)==100 and world.rng.state==before_rng,"source preview/spell scope preserves RNG "+str(sample))
  if expected.chance_pct<=0 or expected.amp_pct<=0:
   check(FINAL.damage(world,100,false,target)==100 and world.rng.state==before_rng,"zero source final-blow family produces no roll or damage")
   continue
  live_cases+=1
  var weight: int=int(expected.chance_pct*10000)
  seed_integer(world,weight,true)
  check(FINAL.damage(world,100,false,target)==100+int(round(expected.amp_pct)) and world.patch523_final_blow_fired,"actual successful source chance amplifies once "+str(sample))
  seed_integer(world,weight,false)
  check(FINAL.damage(world,100,false,target)==100 and not world.patch523_final_blow_fired,"actual failed source chance leaves damage intact "+str(sample))
  seed_integer(world,weight,true);target.hp=target.max_hp;world._refresh_equipment_effects()
  var base: int=maxi(1,int(round(100.0*(1+clampf(float(world.equipment_effects.damage_amp_pct),0,300)/100))))
  world._deal_successful_player_hit(target,100,false,"melee",true,false)
  check(target.max_hp-target.hp==base+int(round(base*expected.amp_pct/100.0))+maxi(0,int(world._equipment_inven_sum("source_attack_drain_hp")))+(1 if world._has_hp_absorption() else 0),"actual successful production hit includes one final-blow addition "+str(sample))
  seed_integer(world,weight,true);target.hp=target.max_hp;before_rng=world.rng.state
  world._deal_successful_player_hit(target,100,false,"magic",true,true)
  check(target.max_hp-target.hp==maxi(1,int(round((100.0+world._equipment_inven_sum("source_stun_magic_damage"))*(1+clampf(float(world.equipment_effects.damage_amp_pct),0,300)/100.0)))) and world.rng.state==before_rng,"production spell does not roll or apply normal-only final blow")
 var rune: Dictionary=own(world,"226328",0,1)
 rune["instance_id"]="90001";world.equipped_items={"rune":rune};world._invalidate_equipment_static()
 check(FINAL.totals(world)=={"chance_pct":3.0,"amp_pct":10.0},"entire native base final-blow item set: exact rune226328 gives3%/10%, no duplicate base")
 seed_integer(world,30000,true)
 check(FINAL.damage(world,100,false,target)==110,"native base source rune participates in same actual chance/amplification consumer")
 var record: Dictionary=own(world,"213631",8,2);record["instance_id"]="90001";world.equipped_items={"crystal":record};world._invalidate_equipment_static()
 world.original_skills=skills
 check(world._save_game(true)==OK,"source final-blow physical equipment saves")
 var prior: Dictionary=FINAL.totals(world)
 world._load_game(true)
 check(FINAL.totals(world)==prior,"actual reconnect preserves source final-blow values")
 world.hud.open_patch523_equipment_info();await process_frame
 var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
 check(info!=null and info.detail.text.contains("결정타") and info.detail.text.contains("TWILIGHT"),"actual equipment UI exposes source final blow and policy basis")
 await capture("source-final-blow-local-candidate")
 world.original_skills=skills;target.queue_free();world.queue_free();await process_frame
 print("PATCH523_FINAL_BLOW_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"rows":rows.size(),"states":cases.size(),"positive_states":live_cases,"controlled_physical_equipment":true}))
 quit(0 if failures.is_empty() else 1)
