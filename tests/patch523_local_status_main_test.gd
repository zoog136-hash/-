extends "res://tests/patch523_equipment_invokes_main_test.gd"
## All22 source rows/all9 bound identities; controlled QA ownership, actual Main.
const NEW_KEYS={"PiercePVPDamageReduction":"source_pvp_flat_reduction_ignore","PVPSpellByLevelAdditionLevel":"source_pvp_status_success_level","PierceDamageReduction":"source_fear_flat_reduction_ignore"}
func expected(world: TwilightWorld,id: String,rank: int,bless: int) -> Dictionary:
 var result: Dictionary={};var groups: Dictionary={}
 for row: Dictionary in world.patch523_equipment.data.items[id].enchant_effects:
  var group: String=str(int(row.ItemEnchantBonusGroupID))
  if not groups.has(group):groups[group]=[]
  groups[group].append(int(row.BlessCode))
 for row: Dictionary in world.patch523_equipment.data.items[id].enchant_effects:
  if int(row.EnchantLevel)!=rank or int(row.BlessCode)!=(bless if groups[str(int(row.ItemEnchantBonusGroupID))].has(bless) else 0):continue
  var bonus: Dictionary=world.patch523_equipment.data.bonuses[str(int(row.BonusID))]
  var kind: Dictionary=world.patch523_equipment.data.bonus_types[str(int(bonus.BonusTypeID))]
  if not NEW_KEYS.has(kind.Name):continue
  if kind.Name=="PierceDamageReduction" and (int(bonus.BonusApplicationTypeID)!=2 or int(bonus.BonusApplicationTargetID)!=8):continue
  check(int(kind.UnitID)==1,"exact source integer unit")
  result[NEW_KEYS[kind.Name]]=int(result.get(NEW_KEYS[kind.Name],0))+int(bonus.Value)
 return result
func wear(world: TwilightWorld,id: String,rank: int,bless: int) -> void:
 var record: Dictionary=own(world,id,rank,bless);record["instance_id"]="90001"
 var slot: String=world._equipment_slot_base(record)
 if slot in ["ring","earring","seal"]:slot+="1"
 world.equipped_items={slot:record};world._invalidate_equipment_static()
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world,"다크엘프"),"actual Main with installed exact source catalog")
 world.player.set_physics_process(false);world.field_population.configure(world,null);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
 check(world.patch523_craft_catalog_status.get("registered_count")==30398,"reuse full catalog, no download/install")
 var actor: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(actor)
 actor.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
 actor.set_process(false);actor.set_physics_process(false);actor.max_hp=1000000;actor.undead=false;actor.monster_type="일반";actor.global_position=world.player.global_position+Vector2(32,0)
 world.active_skill_buffs={};world.original_skills.proc_depth=1;world.original_skills.status.clear()
 print("STATUS22_STAGE actual Main/catalog ready")
 var policy: Dictionary=world.PATCH523_ENHANCE.policy()
 var cases: Array[String]=["146352","147002","178784","178864","183681","213611","226328","328244","328364"]
 var source_rows: Dictionary={};var states: int=0
 for id: String in cases:
  check(not world.patch523_equipment.data.items[id].item_class.TestItem,"original TestItem false, names do not override source restrictions")
  for row: Dictionary in world.patch523_equipment.data.items[id].enchant_effects:
   var b: Dictionary=world.patch523_equipment.data.bonuses[str(int(row.BonusID))]
   var kind: String=world.patch523_equipment.data.bonus_types[str(int(b.BonusTypeID))].Name
   if kind in ["PiercePVPDamageReduction","PVPSpellByLevelAdditionLevel"] or (kind=="PierceDamageReduction" and int(b.BonusApplicationTypeID)==2 and int(b.BonusApplicationTargetID)==8):source_rows[int(row.ID)]=true
  for rank: int in range(22):
   for bless: int in [1,2]:
    wear(world,id,rank,bless);var before: String=JSON.stringify(world.item_instances);var before_rng: int=world.rng.state
    var values: Dictionary=expected(world,id,rank,bless)
    for key: String in NEW_KEYS.values():check(COMBAT.source_integer(world,key)==int(values.get(key,0)),"exact whole family/bless/zero-level alternative "+id+":"+str(rank)+":"+str(bless)+":"+key)
    check(JSON.stringify(world.item_instances)==before and world.rng.state==before_rng,"pure source preview preserves physical fields and RNG")
    states+=1
 check(source_rows.size()==22 and states==396,"all22 distinct source rows/all396 physical states across9 source definitions")
 print("STATUS22_STAGE complete source/physical matrix")
 # Five distinct virtual-level rows exercise all six existing status consumers.
 world.level=50;actor.monster_level=50
 var player_level: int=world.level;var experience: int=world.experience
 for sample: Array in [[7,1,1],[8,1,2],[6,2,1],[7,2,2],[8,2,3]]:
  wear(world,"183681",sample[0],sample[1])
  for status: String in ["stun","silence","hold","fear","poison","bleed"]:
   actor.set(status+"_resistance",int(world.call("_"+status+"_accuracy_stat")))
   policy.source_pvp_status_level_consumer="disabled"
   var baseline: float=float(world.call("_player_"+status+"_chance",actor))
   policy.source_pvp_status_level_consumer="existing_singleplayer_status_virtual_level"
   var actual: float=float(world.call("_player_"+status+"_chance",actor))
   check(is_equal_approx(actual-baseline,float(sample[2])*.005),"actual legacy "+status+" chance consumes source virtual level, not raw percent")
  check(world.level==player_level and world.experience==experience,"virtual level never changes actual level/XP/gates")
 policy.source_pvp_status_level_consumer="unknown"
 check(COMBAT.status_caster_level(world,50)==50,"unknown status policy does not grant a new level")
 policy.source_pvp_status_level_consumer="existing_singleplayer_status_virtual_level"
 check(COMBAT.source_integer(world,"damage_reduction_ignore")==0,"source-only helper does not widen its key allowlist")
 # All attack channels consume only the labelled source PvP flat projection.
 wear(world,"226328",8,1)
 for kind: String in ["melee","ranged","magic"]:
  policy.source_pvp_flat_ignore_consumer="disabled";var baseline: int=world._equipment_additional_damage(kind)
  policy.source_pvp_flat_ignore_consumer="existing_singleplayer_flat_damage_projection"
  check(world._equipment_additional_damage(kind)-baseline==7,"existing single-player flat damage consumer "+kind)
  var hp_damage: Array=[]
  for enabled: bool in [false,true]:
   policy.source_pvp_flat_ignore_consumer="existing_singleplayer_flat_damage_projection" if enabled else "disabled"
   var damage: int=world._equipment_additional_damage(kind)+100;actor.hp=actor.max_hp
   world._deal_successful_player_hit(actor,damage,false,kind,true,kind=="magic");hp_damage.append(actor.max_hp-actor.hp)
  var factor: float=1+clampf(float(world.equipment_effects.damage_amp_pct),0,300)/100
  check(hp_damage[1]-hp_damage[0]>=int(floor(7*factor)) and hp_damage[1]-hp_damage[0]<=int(ceil(7*factor)),"actual target HP consumes PvP projection exactly once "+kind)
 policy.source_pvp_flat_ignore_consumer="existing_singleplayer_flat_damage_projection"
 # Both Fear source rows, target/self, actual fear, normal/spell and disabled scope.
 for sample: Array in [[7,1],[6,2]]:
  wear(world,"213611",sample[0],sample[1])
  for subject: String in ["target_status","self_status"]:
   policy.source_fear_condition_subject=subject
   for feared: bool in [false,true]:
    actor.fear_remaining=0;world.player.fear_remaining=0
    if feared:
     if subject=="target_status":actor.apply_fear(10,world.player.global_position)
     else:world.player.apply_fear(10,actor.global_position)
    for by_spell: bool in [false,true]:
     for scope: String in ["all_successful_hits","normal_only","spell_hits_only","disabled"]:
      policy.source_fear_flat_ignore_scope=scope
      var eligible: bool=feared and (scope=="all_successful_hits" or (scope=="normal_only" and not by_spell) or (scope=="spell_hits_only" and by_spell))
      check(COMBAT.fear_flat_ignore(world,actor,by_spell)==(4 if eligible else 0),"actual Fear8 subject/scope selection")
      var hp_damage: Array=[]
      for enabled: bool in [false,true]:
       policy.source_fear_flat_ignore_consumer="existing_flat_damage_projection" if enabled else "disabled"
       seed_integer(world,100000,false) # Isolate the existing independent10% final-blow roll.
       actor.hp=actor.max_hp;world._deal_successful_player_hit(actor,100,false,"melee",true,by_spell);hp_damage.append(actor.max_hp-actor.hp)
      var factor: float=1+clampf(float(world.equipment_effects.damage_amp_pct),0,300)/100
      check(hp_damage[1]-hp_damage[0]==int(round((100+(4 if eligible else 0))*factor))-int(round(100*factor)),"actual target HP obeys Fear condition, not unconditional bonus")
      policy.source_fear_flat_ignore_consumer="existing_flat_damage_projection"
 policy.source_fear_flat_ignore_scope="all_successful_hits";policy.source_fear_condition_subject="target_status";actor.fear_remaining=0;world.player.fear_remaining=0
 # Opaque stored data cannot authorize these new fields; source mismatch fails closed.
 wear(world,"183681",8,2)
 world.item_instances["90001"].record["source_pvp_status_success_level"]=99999
 var preserved: Dictionary=world.item_instances["90001"].duplicate(true)
 check(COMBAT.source_integer(world,"source_pvp_status_success_level")==3 and world.item_instances["90001"]==preserved,"same-named opaque field preserved but not promoted")
 world.equipped_items["ring1"]=world.equipped_items.badge.duplicate(true)
 check(COMBAT.source_integer(world,"source_pvp_status_success_level")==3,"same physical UUID cannot count twice")
 world.item_instances["90001"].sourceId="m523:item:213611"
 check(COMBAT.source_integer(world,"source_pvp_status_success_level")==0,"physical source mismatch preserves record and refuses bonus")
 world.original_skills.proc_depth=0
 for sample: Array in [["183681",8,2,"가상 레벨"],["213611",6,2,"공포8 조건"],["226328",8,1,"싱글플레이어 추가 피해"]]:
  equip_source(world,sample[0],sample[1],sample[2])
  world.item_instances["90001"].record["future_opaque"]={"keep":17};world.inventory["화살"]=0;world.inventory["총알"]=0
  var rng_before: int=world.rng.state
  check(world._save_game(true)==OK,"source effect and opaque physical fields save together")
  var saved_sha: String=FileAccess.get_sha256(world.save_path())
  world.source_save_blocked=true
  check(world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==saved_sha and world.rng.state==rng_before,"blocked durable write preserves previous source save/RNG")
  world.source_save_blocked=false;world._load_game(true)
  check(world.rng.state==rng_before,"reconnect resumes committed RNG")
  check(int(world.item_instances["90001"].record.get("future_opaque",{}).get("keep",-1))==17,"reconnect preserves opaque field value despite JSON numeric type normalization")
  check(world.item_instances["90001"].record.get("sourceId")=="m523:item:"+sample[0] and int(world.item_instances["90001"].level)==int(sample[1]),"reconnect preserves exact source physical UUID and rank")
  world.hud.open_patch523_equipment_info();await process_frame
  var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  check(info!=null and info.detail.text.contains(sample[3]) and info.detail.text.contains("TWILIGHT"),"actual equipped source UI distinguishes raw value/host policy "+sample[0])
  var policy_key: String="source_pvp_status_level_consumer" if sample[0]=="183681" else "source_fear_flat_ignore_consumer" if sample[0]=="213611" else "source_pvp_flat_ignore_consumer"
  var setting: Variant=policy[policy_key];policy[policy_key]="disabled";info._refresh()
  check(info.detail.text.contains("설정 꺼짐·원본 보존"),"disabled UI does not claim source numbers are applied")
  policy[policy_key]=setting
 print("PATCH523_LOCAL_STATUS22_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":source_rows.size(),"physical_states":states,"status_consumers":6,"actual_hp_channels":3,"saved_reconnect_identities":3,"controlled_qa_ownership":true,"delivery":"LOCAL_ONLY"}))
 actor.queue_free();world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
