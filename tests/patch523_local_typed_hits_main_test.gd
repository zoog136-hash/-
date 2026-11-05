extends "res://tests/patch523_equipment_invokes_main_test.gd"
## Focused actual HP consumer proof after the separate complete102-state matrix.
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world,"다크엘프"),"actual Main with previously installed exact source catalog")
 world.player.set_physics_process(false);world.field_population.configure(world,null);world.monsters_root.process_mode=Node.PROCESS_MODE_DISABLED
 check(world.patch523_craft_catalog_status.get("registered_count")==30398,"reuse full catalog installation without another download/install")
 var actor: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(actor)
 actor.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
 actor.set_process(false);actor.set_physics_process(false);actor.max_hp=1000000;actor.undead=false;actor.monster_type="일반";actor.global_position=world.player.global_position+Vector2(32,0)
 world.active_skill_buffs={};world.original_skills.proc_depth=1;world.original_skills.status.clear()
 var policy: Dictionary=world.PATCH523_ENHANCE.policy()
 var typed_states: int=0
 for sample: Array in [["882","melee"],["883","ranged"],["885","magic"]]:
  var ranks: Dictionary={}
  for row: Dictionary in world.patch523_equipment.data.items[sample[0]].enchant_effects:
   var bonus: Dictionary=world.patch523_equipment.data.bonuses[str(int(row.BonusID))]
   if int(bonus.BonusTypeID) in [3342,462,2102]:ranks[int(row.EnchantLevel)]=int(bonus.Value)
  for rank: int in ranks:
   for blessing: int in [1,2]:
    var worn: Dictionary=own(world,sample[0],rank,blessing);worn["instance_id"]="90001";world.equipped_items={"rune":worn};world._invalidate_equipment_static()
    check(COMBAT.typed_flat_ignore(world,sample[1])==ranks[rank],"all42 exact source derivation states remain eligible")
    typed_states+=1
 check(typed_states==42,"entire21-row typed source family in both blessing states")
 for sample: Array in [["882","melee"],["883","ranged"],["885","magic"]]:
  var record: Dictionary=own(world,sample[0],8,1);record["instance_id"]="90001";world.equipped_items={"rune":record};world._invalidate_equipment_static()
  var kind: String=sample[1];var amount: int=int(world._equipment_inven_sum("source_"+kind+"_flat_reduction_ignore"))
  var damage: Array=[];var stats: Array=[];var rng_before: int=world.rng.state
  for mode: String in ["disabled","existing_typed_flat_damage_projection"]:
   policy.source_typed_flat_ignore_consumer=mode
   var base: int=world._melee_damage_stat() if kind=="melee" else world._ranged_normal_damage_stat() if kind=="ranged" else world._magic_damage_stat()
   stats.append(base);actor.hp=actor.max_hp
   world._deal_successful_player_hit(actor,base,false,kind,true,kind=="magic")
   damage.append(actor.max_hp-actor.hp)
  check(amount>0 and stats[1]-stats[0]==amount,"real production damage stat reads exact source typed increment "+kind)
  var factor: float=1+clampf(float(world.equipment_effects.damage_amp_pct),0,300)/100
  check(damage[1]-damage[0]==int(round(stats[1]*factor))-int(round(stats[0]*factor)),"actual target HP receives only typed flat projection, not AC or an extra proc "+kind)
  check(world.rng.state==rng_before,"deterministic typed source amount does not introduce proc RNG "+kind)
  world.hud.open_patch523_equipment_info();await process_frame
  var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  check(info!=null and info.detail.text.contains("게임 추가 피해 해석"),"actual UI labels the projection "+kind)
 # A stored opaque field with the new spelling must not become extra damage.
 var record: Dictionary=own(world,"882",8,1)
 record["instance_id"]="90001";record["source_melee_flat_reduction_ignore"]=99999
 world.item_instances["90001"].record=record.duplicate(true);world.equipped_items={"rune":record};world._invalidate_equipment_static()
 var original_instance: Dictionary=world.item_instances["90001"].duplicate(true)
 check(COMBAT.typed_flat_ignore(world,"melee")==7,"opaque same-named base field cannot be promoted to a source bonus")
 check(world.item_instances["90001"]==original_instance,"source-only reader does not rewrite opaque physical record")
 world.equipped_items["ring1"]=world.equipped_items.rune.duplicate(true)
 check(COMBAT.typed_flat_ignore(world,"melee")==7,"same physical source ID cannot be counted twice")
 world.equipped_items={"rune":record}
 world.item_instances["90001"].sourceId="m523:item:883"
 check(COMBAT.typed_flat_ignore(world,"melee")==0,"physical/source identity mismatch is refused without rewriting it")
 world.original_skills.proc_depth=0
 print("PATCH523_LOCAL_TYPED_HITS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_damage_channels":3,"typed_physical_states":typed_states,"controlled_actor_stats":true,"matrix_reused":"local36-actual-main-corrected657","delivery":"LOCAL_ONLY"}))
 actor.queue_free();world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
