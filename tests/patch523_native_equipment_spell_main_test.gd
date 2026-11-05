extends "res://tests/patch523_equipment_invokes_main_test.gd"
const SOURCE=preload("res://scripts/crafting/patch523_equipment_spells.gd")
const CASES="/workspace/equipment523-logs/native-damage-all-row-cases_LOCAL_ONLY.json"
func wear(world: TwilightWorld,id: String,rank: int,bless: int) -> Dictionary:
 var record: Dictionary=own(world,id,rank,bless);record["instance_id"]="90001"
 world.skill_cooldowns.clear() # Each controlled physical-state case starts independently.
 var limits: Dictionary=world.PATCH523_ITEM_USE.definition(record)
 if not limits.get("class_names",[]).is_empty():world.job_class=str(limits.class_names[0])
 var slot: String=world._equipment_slot_base(record)
 if slot in ["earring","ring","seal"]:slot+="1"
 world.equipped_items={slot:record};world._invalidate_equipment_static()
 return record
func seed_spell(world: TwilightWorld,weight: int,chance: float) -> void:
 var probe:=RandomNumberGenerator.new()
 for seed: int in range(100000):
  probe.seed=seed
  if weight<1000000 and probe.randi_range(0,999999)>=weight:continue
  if probe.randf()>=chance:continue
  world.rng.seed=seed;return
 check(false,"native probability/magic-hit branch is reachable")
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world,"다크엘프"),"actual Main/held catalog")
 world.player.set_physics_process(false);world.field_population.configure(world,null);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
 world.level=100;world.active_skill_buffs={};world.original_skills.status.clear()
 check(world.patch523_craft_catalog_status.get("registered_count")==30398,"reuse exact full catalog without download/reinstall")
 var actor: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(actor)
 actor.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
 actor.set_process(false);actor.set_physics_process(false);actor.max_hp=1000000;actor.undead=false;actor.monster_type="일반";actor.global_position=world.player.global_position+Vector2(1,0)
 var cases: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CASES));var native_rows: Dictionary={};var blocked_rows: Dictionary={};var counter_rows: Dictionary={};var executed: int=0;var zero: int=0
 print("NATIVE_EQUIPMENT_STAGE actual Main ready")
 for entry: Dictionary in cases.eligible:
  var effect: Dictionary=entry.effect
  if effect.kind!="attack_source_spell":continue
  var record: Dictionary=wear(world,str(entry.item_id),int(entry.rank),int(entry.bless));actor.hp=actor.max_hp
  var active: Array=COMBAT.active(world,"attack_source_spell")
  check(active.size()==1 and int(active[0].row_id)==int(effect.row_id),"exact native source row/physical identity/rank/blessing")
  if active.size()!=1:continue
  var row: Dictionary=active[0];var profile: Dictionary=world.patch523_equipment.data.equipment_spell_profiles[str(int(row.option.Param1))]
  var values: Dictionary=SOURCE.values(profile)
  check(not values.is_empty() and SOURCE.item_reason(world,record,str(entry.item_id)).is_empty(),"full source profile/actual original item eligibility")
  var before_rng: int=world.rng.state;var before_physical: String=JSON.stringify(world.item_instances)
  if int(row.probability)==0:
   COMBAT.on_hit(world,actor,"melee",true,false)
   check(COMBAT.spell_fired.is_empty() and world.rng.state==before_rng and actor.hp==actor.max_hp,"zero source weight never dispatches or draws")
   zero+=1
  else:
   seed_spell(world,int(row.probability),world.original_skills.hit_chance({"attack_type":"magic"},actor))
   COMBAT.on_hit(world,actor,"melee",true,false)
   check(COMBAT.spell_fired.size()==1,"actual on-hit invokes source owner")
   if COMBAT.spell_fired.size()==1:
    var result: Dictionary=COMBAT.spell_fired[0].result
    check(result.get("ok",false) and result.get("hit",false) and int(result.spell_class_id)==int(row.option.Param1),"source ID stays identity, not damage")
    check(actor.max_hp-actor.hp==int(result.damage),"actual NPC HP changes once by source owner result")
    var low: int=int(values.get("SpellDamageBase",0))+int(values.get("SpellDamageDiceNumber",0))
    var high: int=int(values.get("SpellDamageBase",0))+int(values.get("SpellDamageDiceNumber",0))*int(values.get("SpellDamageDiceSpotCount",0))
    var element: String=str({0:"physical",1:"fire",2:"water",3:"wind",4:"earth"}[int(profile.source_spell.ElementalTypeID)])
    check(int(result.damage)>=world.original_skills.target_damage(world._elemental_damage_to_monster(maxi(1,low),element,actor),actor) and int(result.damage)<=world.original_skills.target_damage(world._elemental_damage_to_monster(maxi(1,high),element,actor),actor),"original dice bounds and existing typed target stages")
    executed+=1
  check(JSON.stringify(world.item_instances)==before_physical,"zero-cost native proc preserves inventory/UUID/opaque physical fields")
  native_rows[int(row.row_id)]=true
 for entry: Dictionary in cases.blocked:
  var record: Dictionary=wear(world,str(entry.item_id),int(entry.rank),int(entry.bless));actor.hp=actor.max_hp
  var before: String=JSON.stringify([world.inventory,world.item_instances]);var old_rng: int=world.rng.state
  check(SOURCE.item_reason(world,record,str(entry.item_id)).contains("기간 만료"),"real original DeleteTime/DateTimes_Korean expires item, not its name")
  COMBAT.on_hit(world,actor,"melee",true,false)
  check(COMBAT.spell_fired.is_empty() and actor.hp==actor.max_hp and world.rng.state==old_rng and JSON.stringify([world.inventory,world.item_instances])==before,"expired source never consumes/draws/dispatches/regrants")
  blocked_rows[int(entry.effect.row_id)]=true
 # Both real cloak identities/all16 source ranks/both blessing states/all hit classes.
 for id: String in ["335782","335792"]:
  for rank: int in range(16):
   for bless: int in [1,2]:
    wear(world,id,rank,bless)
    var live: Array=COMBAT.active(world,"defence_fixed_counter")
    check(live.size()==2,"normal/spell counter alternatives retained")
    for kind: String in ["melee","ranged","magic"]:
     var effect: Dictionary=live[1] if bool(live[0].option.BySpellAttack)!=(kind=="magic") else live[0]
     counter_rows[int(effect.row_id)]=true
     for missed: bool in [false,true]:
      seed_integer(world,int(effect.probability),true);actor.hp=actor.max_hp
      var before_hits: int=actor.damage_hit_count
      var result: int=COMBAT.fixed_counter(world,actor,kind,0 if missed else 123,missed)
      check(result==0 and actor.hp==actor.max_hp-700 and actor.damage_hit_count==before_hits+1 and COMBAT.counter_fired.size()==1,"real source fixed700/100% reduction/evade flag, single nonrecursive counter")
 print("NATIVE_EQUIPMENT_STAGE complete all source cases")
 # Actual legacy World incoming event, including a real rolled miss.
 wear(world,"335782",15,1);world.hp=world._effective_max_hp();actor.hp=actor.max_hp
 var field=world.field_map;world.field_map=null
 var chosen: int=-1;var probe:=RandomNumberGenerator.new()
 for seed: int in range(100000):
  probe.seed=seed
  if probe.randf()>=world._monster_hit_chance(actor,"melee"):continue
  probe.randf() # Existing ordinary critical draw.
  if probe.randi_range(0,999999)<150000:chosen=seed;break
 check(chosen>=0,"actual incoming hit/counter interval reachable")
 var before_hp: int=world.hp;world.rng.seed=chosen;world._on_player_hit(actor,100,"melee")
 check(world.hp==before_hp and actor.max_hp-actor.hp==700,"actual World hit event consumes source counter and protects HP once")
 world.field_map=field
 # The source1000ms cooldown is real state, not bypassed by another hit/reconnect.
 var delayed: Dictionary=cases.eligible.filter(func(v: Dictionary) -> bool:return v.effect.kind=="attack_source_spell" and int(v.effect.option.Param1)==3831)[0]
 wear(world,str(delayed.item_id),int(delayed.rank),int(delayed.bless));actor.hp=actor.max_hp
 seed_spell(world,int(delayed.effect.probability),world.original_skills.hit_chance({"attack_type":"magic"},actor));COMBAT.on_hit(world,actor,"melee",true,false)
 var cooldown_key: String="equipment523|90001|3831"
 check(float(world.skill_cooldowns.get(cooldown_key,0))==1,"source CastDelay1000ms becomes1second in existing cooldown owner")
 var cooldown_rng: int=world.rng.state;var cooldown_hp: int=actor.hp;COMBAT.on_hit(world,actor,"melee",true,false)
 check(COMBAT.spell_fired.is_empty() and world.rng.state==cooldown_rng and actor.hp==cooldown_hp,"active cooldown rejects before proc probability draw")
 world.inventory["화살"]=0;world.inventory["총알"]=0
 check(world._save_game(true)==OK,"native cooldown and exact physical identity save together")
 world._load_game(true)
 check(float(world.skill_cooldowns.get(cooldown_key,0))==1 and world.rng.state==cooldown_rng,"reconnect preserves actual source cooldown/RNG")
 world._tick_skill_cooldowns(1)
 check(not world.skill_cooldowns.has(cooldown_key),"existing timer expires source cooldown")
 # Strict native service rejects stale target/life/profile/source before RNG.
 var entry: Dictionary=cases.eligible.filter(func(v: Dictionary) -> bool:return v.effect.kind=="attack_source_spell" and int(v.effect.probability)>0)[0]
 wear(world,str(entry.item_id),int(entry.rank),int(entry.bless));var e: Dictionary=COMBAT.active(world,"attack_source_spell")[0]
 var profile: Dictionary=world.patch523_equipment.data.equipment_spell_profiles[str(int(e.option.Param1))]
 var context: Dictionary={"source":"patch523_equipment","source_sha256":world.patch523_equipment.digest,"instance_id":"90001","source_item_id":str(entry.item_id),"row_id":int(e.row_id),"option_id":int(e.option.ID)}
 var old_rng: int=world.rng.state
 check(not world.original_skills.execute_equipment_source_damage(profile,actor,actor.life_id+1,context).get("ok",false) and world.rng.state==old_rng,"stale pooled life cannot dispatch or spend RNG")
 var forged: Dictionary=profile.duplicate(true);forged.effects[0].bonus.Value+=1
 check(not world.original_skills.execute_equipment_source_damage(forged,actor,actor.life_id,context).get("ok",false) and world.rng.state==old_rng,"source profile mutation cannot authorize damage")
 world.source_save_blocked=true;COMBAT.on_hit(world,actor,"melee",true,false)
 check(COMBAT.spell_fired.is_empty() and world.rng.state==old_rng,"blocked durable source context refuses new source proc")
 world.source_save_blocked=false
 for id: String in ["439","335782","221081"]:
  wear(world,id,0,1);world.inventory["화살"]=0;world.inventory["총알"]=0
  check(world._save_game(true)==OK,"native equipment/expiry identity can save without consuming it")
  var saved_rng: int=world.rng.state;world._load_game(true)
  check(world.rng.state==saved_rng and world.item_instances.has("90001"),"reconnect preserves native UUID and committed RNG")
  world.hud.open_patch523_equipment_info();await process_frame
  var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  check(info!=null and info.detail.text.contains("TWILIGHT") and info.detail.text.contains("장비 발동 실행 자격"),"actual source equipment information route")
 check(native_rows.size()==321 and blocked_rows.size()==90 and counter_rows.size()==32,"all443 source rows classified and exercised, expired90 remain inactive")
 print("PATCH523_NATIVE_EQUIPMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"native_live_rows":native_rows.size(),"expired_rows":blocked_rows.size(),"counter_rows":counter_rows.size(),"positive_native_executions":executed,"zero_native_weights":zero,"counter_physical_states":64,"controlled_qa_ownership":true,"status":"LOCAL_ONLY"}))
 actor.queue_free();world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
