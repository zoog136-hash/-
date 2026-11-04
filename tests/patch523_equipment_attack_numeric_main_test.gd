extends "res://tests/patch523_equipment_invokes_main_test.gd"
var absorption_base_only: bool=false

func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument=="--absorption-base-only":absorption_base_only=true
 super._initialize()

const FIELDS=["strPercent","dexPercent","intPercent","source_attack_drain_hp","source_attack_drain_mp","source_undead_damage_max"]

func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world),"actual Main and character UI")
 world.player.set_physics_process(false);world.field_population.set_process(false)
 var book: Object=world.patch523_equipment
 check(book.problem.is_empty() and book.data.source_files.size()==38,"actual pinned38-table source pack")
 var cases: Dictionary={};var rows: Dictionary={};var examples: Dictionary={}
 for id: String in book.data.equipment_runtime:
  var runtime: Dictionary=book.data.equipment_runtime[id]
  for bless: int in [1,2]:
   var prepared: Dictionary=ENGINE.prepare(book,book.record(id),bless)
   for rank: int in range(21):
    var extra: Dictionary=prepared.enhancement_extra_options[str(rank)]
    for key: String in FIELDS:
     if not extra.has(key):continue
     var case_key: String=id+":"+str(bless)+":"+str(rank)
     cases[case_key]={"id":id,"rank":rank,"bless":bless}
     if float(extra[key])>0 and not examples.has(key):examples[key]={"id":id,"rank":rank,"bless":bless}
  for row: Dictionary in book.data.items[id].enchant_effects:
   var b: Dictionary=book.data.bonuses[str(int(row.BonusID))]
   if int(b.BonusTypeID) in [10222,10232,10252,432,442,7304]:rows[str(int(row.ID))]=true
 check(rows.size()==116,"all116 new unique source numeric rows present")
 check(examples.size()==FIELDS.size(),"every added consumer has a positive original example")
 var reads: int=0
 for sample: Dictionary in ([] if ui_only else cases.values()):
  var record: Dictionary=equip_source(world,sample.id,sample.rank,sample.bless)
  var prepared: Dictionary=ENGINE.prepare(book,record,sample.bless)
  var base: Dictionary=world.INVEN_OPTIONS.annotate(book.record(sample.id))
  for key: String in FIELDS:
   if not prepared.enhancement_extra_options[str(sample.rank)].has(key):continue
   var expected: float=float(base.get(key,0))+float(prepared.enhancement_extra_options[str(sample.rank)][key])
   check(is_equal_approx(world._equipment_inven_sum(key),expected),"actual source physical rank/state sum "+str(sample)+key)
   reads+=1
 print("PATCH523_ATTACK_NUMERIC_MATRIX ",JSON.stringify({"source_rows":rows.size(),"physical_cases":cases.size(),"typed_reads":reads,"matrix_skipped":ui_only}))
 for key: String in examples:
  if absorption_base_only:continue
  var sample: Dictionary=examples[key]
  var record: Dictionary=equip_source(world,sample.id,sample.rank,sample.bless)
  var value: float=world._equipment_inven_sum(key)
  check(value>0,"actual equipped positive source "+key)
  if key.ends_with("Percent"):
   var stat: String=key.substr(0,3).to_upper()
   var raw: int=int(world.get(stat.to_lower()+"_stat"))
   var flat: int=raw+world._equipment_attribute_bonus(stat)+world._catalog_stat_sum(stat.to_lower()+"Flat")+int(world.original_skills.stat(stat.to_lower()))
   check(world._effective_attribute(stat)==flat+int(floor(float(flat)*value/100.0)),"actual source percentage applies configured base/rounding "+key)
  else:
   var target: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(target)
   target.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
   target.set_process(false);target.set_physics_process(false);target.max_hp=1000000;target.hp=target.max_hp
   target.undead=false;target.monster_type="일반"
   var skills: Object=world.original_skills;world.original_skills=null
   if key=="source_attack_drain_hp":
    world.hp=1;var legacy: int=1 if world._has_hp_absorption() else 0
    world._deal_successful_player_hit(target,100,false,"melee",false)
    check(world.hp==1+legacy+int(value),"actual normal-hit source HP increment heals exact bounded amount")
    target.hp=1;world.hp=1;world._deal_successful_player_hit(target,100,false,"melee",false)
    check(world.hp==2,"one target HP cannot create multiple stolen HP")
    target.dead=false;target.hp=target.max_hp;world.hp=1
    world._deal_successful_player_hit(target,100,false,"magic",true)
    check(world.hp==1+legacy,"new source HP increment never leaks into spells under normal-only policy")
   elif key=="source_attack_drain_mp":
    target.max_mp=100;target.mp=100;world.mp=0
    var base_mp: int=int(world._equipment_inven_sum("mpAbsorption"))
    world._deal_successful_player_hit(target,100,false,"ranged",false)
    check(world.mp==int(value)+base_mp and target.mp==100-world.mp,"actual normal hit transfers exactly existing target MP")
    target.mp=0;world.mp=0;world._deal_successful_player_hit(target,100,false,"melee",false)
    check(world.mp==0 and target.mp==0,"no MP can be created from an empty NPC pool")
    target.mp=100;world.mp=world._effective_max_mp();world._deal_successful_player_hit(target,100,false,"melee",false)
    check(target.mp==100,"full player MP does not destroy target MP")
    world.mp=0;world._deal_successful_player_hit(target,100,false,"magic",true)
    check(world.mp==0 and target.mp==100,"new MP drain respects actual spell context")
   else:
    var before_rng: int=world.rng.state;var before: int=target.hp
    world._deal_successful_player_hit(target,100,false,"melee",false)
    var ordinary_damage: int=before-target.hp
    check(world.rng.state==before_rng,"living target does not draw an undead bonus RNG")
    target.undead=true;target.hp=target.max_hp
    var probe:=RandomNumberGenerator.new();probe.seed=123;var amount: int=probe.randi_range(1,int(value))
    world.rng.seed=123;world._deal_successful_player_hit(target,100,false,"melee",false)
    check(target.max_hp-target.hp==ordinary_damage+amount and world.rng.state==probe.state,"actual undead hit uses source maximum and configured integer draw once")
    target.hp=target.max_hp;world.rng.seed=123;before_rng=world.rng.state
    world._deal_successful_player_hit(target,100,false,"magic",true)
    check(target.max_hp-target.hp==ordinary_damage and world.rng.state==before_rng,"undead normal-only bonus never leaks into spells")
   world.original_skills=skills;target.queue_free()
  check(world._save_game(true)==OK,"source attack/stat actual save "+key)
  world._load_game(true)
  check(is_equal_approx(world._equipment_inven_sum(key),value),"source attack/stat actual reload "+key)
  world.hud.open_patch523_equipment_info();await process_frame
  var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  check(info!=null and info.detail.text.contains("적용 연결") and info.pack_sha.text==book.digest,"actual stat/attack source information UI "+key)
  await capture("source-attack-numeric-"+key)
 if absorption_base_only:
  var indexed: Dictionary={"source":"inven","inven_indexed":true,"sourceOptions":["MP 흡수"],"inven_unimplemented_options":["MP 흡수"],"damage":77}
  check(world.INVEN_OPTIONS.annotate({"source":"inven","inven_indexed":true})=={"source":"inven","inven_indexed":true},"old indexed record without sourceOptions is safe")
  var refreshed: Dictionary=world.INVEN_OPTIONS.annotate(indexed)
  check(refreshed.get("mpAbsorption")==true and refreshed.damage==77 and not refreshed.inven_unimplemented_options.has("MP 흡수"),"old indexed MP flag refreshes without reparsing numeric stats")
  check(not indexed.has("mpAbsorption"),"indexed refresh preserves input record")
  for id: String in ["276058","276808"]:
   for bless: int in [1,2]:
    var record: Dictionary=equip_source(world,id,0,bless)
    var hp_amount: int=(1 if world._has_hp_absorption() else 0)+int(world._equipment_inven_sum("source_attack_drain_hp"))
    var mp_amount: int=int(world._equipment_inven_sum("mpAbsorption"))+int(world._equipment_inven_sum("source_attack_drain_mp"))
    check(hp_amount==1 and mp_amount==1,"source zero HP/MP totals count once across base and enhancement "+id+str(bless))
    var target: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(target)
    target.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
    target.set_process(false);target.set_physics_process(false);target.hp=1000000;target.max_hp=target.hp;target.mp=10;target.max_mp=10
    var service: Object=world.original_skills;world.original_skills=null;world.hp=1;world.mp=0
    world._deal_successful_player_hit(target,100,false,"melee",false)
    check(world.hp==2 and world.mp==1 and target.mp==9,"actual zero-rank source attack transfers one HP/MP without duplicate flags "+id+str(bless))
    world.original_skills=service;target.queue_free()
    check(world._save_game(true)==OK,"corrected zero absorption save")
    world._load_game(true)
    check(int(world._equipment_inven_sum("mpAbsorption"))+int(world._equipment_inven_sum("source_attack_drain_mp"))==1,"corrected source MP total survives reload")
 world.queue_free();await process_frame
 print("PATCH523_ATTACK_NUMERIC_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":rows.size(),"typed_reads":reads,"absorption_base_only":absorption_base_only,"attack_families_executed":0 if absorption_base_only else examples.size()}))
 quit(0 if failures.is_empty() else 1)
