extends "res://tests/patch523_equipment_invokes_main_test.gd"
const CHANNELS=["fire","water","wind","earth"]

func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world),"actual Main and class UI for elemental source effects")
 world.player.set_physics_process(false);world.field_population.set_process(false)
 var book: Object=world.patch523_equipment
 check(book.problem.is_empty(),"actual full registered source rules loaded")
 var rows: Dictionary={};var cases: Dictionary={};var examples: Dictionary={}
 for id: String in book.data.equipment_runtime:
  var runtime: Dictionary=book.data.equipment_runtime[id]
  for row: Dictionary in book.data.items[id].enchant_effects:
   var bonus: Dictionary=book.data.bonuses[str(int(row.BonusID))]
   if book.data.bonus_types[str(int(bonus.BonusTypeID))].Name!="ElementalDamage" or int(row.ID) in runtime.unconnected_effect_row_ids:continue
   rows[str(int(row.ID))]=true
   for bless: int in [1,2]:
    var rank: int=int(row.EnchantLevel)
    cases[id+":"+str(bless)+":"+str(rank)]={"id":id,"bless":bless,"rank":rank}
    var channel: String=str(ENGINE.policy().source_elemental_target_channels[str(int(bonus.BonusApplicationTargetID))])
    if not examples.has(channel):examples[channel]={"id":id,"bless":bless,"rank":rank}
 check(rows.size()==64 and examples.size()==4,"all64 original rows and all4 explicit elemental targets")
 var reads: int=0
 for sample: Dictionary in cases.values():
  var record: Dictionary=own(world,sample.id,sample.rank,sample.bless)
  record["instance_id"]="90001"
  world.equipped_items={"earring1":record};world._invalidate_equipment_static()
  var prepared: Dictionary=ENGINE.prepare(book,book.record(sample.id),sample.bless)
  for channel: String in CHANNELS:
   var key: String="source_elemental_flat_"+channel
   var expected: float=float(prepared.enhancement_extra_options[str(sample.rank)].get(key,0))
   check(is_equal_approx(world._equipment_inven_sum(key),expected),"actual elemental typed sum for exact rank/bless "+str(sample)+channel)
   reads+=1
 print("PATCH523_ELEMENTAL_MATRIX ",JSON.stringify({"rows":rows.size(),"physical_cases":cases.size(),"typed_reads":reads}))
 for channel: String in examples:
  var sample: Dictionary=examples[channel]
  var record: Dictionary=equip_source(world,sample.id,sample.rank,sample.bless)
  var amount: float=world._equipment_inven_sum("source_elemental_flat_"+channel)
  check(amount>0,"actual source positive elemental component "+channel)
  var target: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(target)
  target.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
  target.set_process(false);target.set_physics_process(false);target.undead=false;target.monster_type="일반";target.max_hp=1000000
  var skills: Object=world.original_skills;world.original_skills=null
  for resistance: float in [-80.0,0.0,50.0,85.0]:
   target.element_resistance={channel:resistance};target.hp=target.max_hp
   var expected: int=maxi(0,int(round(amount*(1.0-resistance/100.0))))
   check(world._source_elemental_flat_damage(target,false)==expected,"source flat component uses its own target resistance "+channel+str(resistance))
   world._refresh_equipment_effects()
   var base: int=maxi(1,int(round(100.0*(1.0+clampf(float(world.equipment_effects.damage_amp_pct),0,300)/100.0))))
   world._deal_successful_player_hit(target,100,false,"melee",true,false)
   check(target.max_hp-target.hp==base+expected,"actual normal hit adds exact flat elemental damage once "+channel)
   target.hp=target.max_hp;world._deal_successful_player_hit(target,100,false,"magic",true,true)
   check(target.max_hp-target.hp==base and world._source_elemental_flat_damage(target,true)==0,"normal-only elemental source component never leaks into spells "+channel)
  target.element_resistance.clear()
  for other: String in CHANNELS:
   if other!=channel:target.element_resistance[other]=85.0
  check(world._source_elemental_flat_damage(target,false)==int(amount),"other elemental resistance never changes this source component "+channel)
  world.original_skills=skills;target.queue_free()
  check(world._save_game(true)==OK,"actual elemental equipment and source amount save")
  world._load_game(true)
  check(is_equal_approx(world._equipment_inven_sum("source_elemental_flat_"+channel),amount),"actual elemental source amount survives reload")
  world.hud.open_patch523_equipment_info();await process_frame
  var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  check(info!=null and info.detail.text.contains("속성 추가 피해") and info.detail.text.contains("TWILIGHT 설정") and info.pack_sha.text==book.digest,"actual source UI identifies component and configurable interpretation "+channel)
  await capture("source-elemental-flat-"+channel)
 world.equipped_items.clear();world._invalidate_equipment_static()
 var zero: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(zero);zero.element_resistance={"fire":-80}
 check(world._source_elemental_flat_damage(zero,false)==0,"no elemental source amount creates no phantom minimum damage")
 zero.queue_free();world.queue_free();await process_frame
 print("PATCH523_ELEMENTAL_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":rows.size(),"typed_reads":reads,"channels":examples.keys(),"npc_values_controlled_for_test":true}))
 quit(0 if failures.is_empty() else 1)
