extends "res://tests/patch523_equipment_invokes_main_test.gd"
const TYPED_KEYS=["stun_accuracy","fear_accuracy","hold_resistance","fear_resistance","healing_magic_pct","castSpeed","melee_critical_resistance","ranged_critical_resistance","melee_damage_reduction_pct","ranged_damage_reduction_pct","magic_damage_reduction_pct","dot_damage_reduction_pct"]
var rune_only: bool=false
var install_from: String=""
var catalog_zip: String=""

func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument=="--rune-only":rune_only=true
  if argument.begins_with("--install-from="):install_from=argument.trim_prefix("--install-from=")
  if argument.begins_with("--catalog-zip="):catalog_zip=argument.trim_prefix("--catalog-zip=")
 super._initialize()

func verify_actual_npc_hit(world: TwilightWorld,key: String) -> void:
 var kind: String=key.get_slice("_",0)
 var position: Vector2=world.player.global_position
 for attempt: int in range(128):
  var candidate: Vector2=world.field_map.random_landing(world.rng,position,500,1800)
  if world.field_map.point_clear(candidate,4) and not world.field_map.is_safe(candidate):position=candidate;break
 check(not world.field_map.is_safe(position),"actual traversable non-safe combat cell "+key)
 world.player.global_position=position
 var actor: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(actor)
 actor.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
 actor.set_process(false);actor.set_physics_process(false);actor.global_position=position+Vector2(24,0)
 actor.max_hp=1000000;actor.hp=actor.max_hp
 actor.melee_accuracy=100000;actor.ranged_accuracy=100000;actor.magic_accuracy=100000
 actor.attack_element="physical"
 for status: String in ["stun","hold","fear","silence","poison","bleed"]:actor.set(status+"_duration",0)
 var critical_case: bool=key.ends_with("critical_resistance")
 actor.melee_critical_rate=50 if critical_case else 0;actor.ranged_critical_rate=actor.melee_critical_rate;actor.magic_critical_rate=actor.melee_critical_rate
 actor.player_hit.connect(world._on_player_hit)
 # Isolate the equipment path from unrelated learned counters/shields. This
 # controlled production NPC is not an original NPC stat/spawn assertion.
 var service: Object=world.original_skills;world.original_skills=null
 var observed: bool=false
 for seed: int in range(2000):
  world.rng.seed=seed
  if not world._roll_monster_hit(actor,kind):continue
  var crit_roll: float=world.rng.randf()
  if critical_case and not (crit_roll>=world._critical_chance(50,world._critical_resistance_stat(kind)) and crit_roll<world._critical_chance(50,world._critical_resistance_stat())):continue
  var expected: int=100 if kind=="magic" else world._physical_damage_after_reduction(100)
  expected=world.growth.incoming_damage(world._pve_damage_after_item_buffs(expected,0.0,kind))
  world.rng.seed=seed;world.hp=world._effective_max_hp();var before: int=world.hp
  actor.player_hit.emit(actor,100,kind)
  if not COMBAT.fired.is_empty():continue
  check(before-world.hp==expected,"actual NPC hit signal uses exact typed equipment "+key)
  observed=true;break
 check(observed,"observable NPC equipment hit case exists "+key)
 world.original_skills=service;world.hp=world._effective_max_hp()
 actor.queue_free()

func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world),"actual Main/class UI")
 world.player.set_physics_process(false);world.field_population.set_process(false)
 var book: Object=world.patch523_equipment
 check(book.problem.is_empty() and book.data.source_files.size()==38,"38 pinned source tables including resistance enum")
 if not install_from.is_empty():
  world.hud.open_patch523_equipment_info();await process_frame
  var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  var inventory_before: String=JSON.stringify([world.inventory,world.item_instances,world.gold])
  var save_before: String=FileAccess.get_sha256(world.save_path())
  check(info!=null,"actual existing pack install screen opens")
  if not catalog_zip.is_empty():
   info.catalog_dialog.file_selected.emit(catalog_zip)
   check(world.patch523_craft_catalog_status.get("ok",false),"existing shared catalog ZIP installs through actual UI")
  info.pack_sha.text=book.digest;info.pack_dialog.file_selected.emit(install_from)
  check(world.PATCH523_STORE.active().get("sha256")==book.digest,"new received runtime installs through actual UI")
  check(FileAccess.get_sha256(install_from)==book.digest,"selected runtime bytes match loaded exact SHA")
  check(JSON.stringify([world.inventory,world.item_instances,world.gold])==inventory_before and FileAccess.get_sha256(world.save_path())==save_before,"pack UI installation grants nothing and preserves existing save bytes")
  book=world.patch523_equipment
  await capture("source-v11-installation")
 var representatives: Dictionary={};var reads: int=0;var affected: int=0
 for id: String in book.data.equipment_runtime:
  var runtime: Dictionary=book.data.equipment_runtime[id]
  var used: bool=false
  for state: Dictionary in runtime.extra_options.values():
   for values: Dictionary in state.values():
    for key: String in TYPED_KEYS:
     if values.has(key):used=true
  if not used:continue
  affected+=1
  var base: Dictionary=book.record(id)
  var baseline: Dictionary=world.INVEN_OPTIONS.annotate(base)
  for bless: int in [1,2]:
   var record: Dictionary=ENGINE.prepare(book,base,bless)
   record["instance_id"]="90001";record["bless_state"]="blessed" if bless==2 else "normal"
   if record.get("source_m_native_item",false):record["source_bless_raw"]=bless
   world.inventory={str(record.name):1}
   for rank: int in range(21):
    var extras: Dictionary=record.enhancement_extra_options[str(rank)]
    for key: String in TYPED_KEYS:
     if float(extras.get(key,0))>0 and not representatives.has(key):representatives[key]={"id":id,"rank":rank,"bless":bless}
    if ui_only:continue
    world.item_instances={"90001":{"name":record.name,"record":record,"level":rank,"bless_state":record.bless_state,"source_bless_code":bless}}
    var slot: String=world._equipment_slot_base(record)
    if slot in ["earring","ring","seal"]:slot+="1"
    world.equipped_items={slot:record};world._invalidate_equipment_static()
    for key: String in TYPED_KEYS:
     if not extras.has(key):continue
     check(is_equal_approx(world._equipment_inven_sum(key),float(baseline.get(key,0))+float(extras[key])),"actual typed Main consumer "+id+"/"+str(bless)+"/"+str(rank)+"/"+key)
     reads+=1
 print("PATCH523_TYPED_MATRIX ",JSON.stringify({"equipment":affected,"consumer_reads":reads,"matrix_skipped":ui_only}))
 check(representatives.size()==TYPED_KEYS.size(),"every new supported source numeric family has an original example")
 for key: String in representatives:
  if rune_only:continue
  var sample: Dictionary=representatives[key]
  var record: Dictionary=equip_source(world,sample.id,sample.rank,sample.bless)
  world._invalidate_equipment_static()
  var value: float=world._equipment_inven_sum(key)
  check(value>0,"equipped original positive "+key)
  if key.ends_with("_accuracy") or key.ends_with("_resistance") and not key.contains("critical"):
   var stat: Callable=Callable(world,"_"+key+"_stat")
   var with_item: int=int(stat.call())
   var equipped: Dictionary=world.equipped_items.duplicate(true)
   world.equipped_items.clear();world._invalidate_equipment_static()
   var without_item: int=int(stat.call())
   world.equipped_items=equipped;world._invalidate_equipment_static()
   check(with_item>without_item,"actual status hit/resist consumer "+key)
  elif key.ends_with("critical_resistance"):
   var kind: String=key.get_slice("_",0)
   var other: String="ranged" if kind=="melee" else "melee"
   var common: int=world._critical_resistance_stat()
   check(world._critical_resistance_stat(kind)==clampi(common+int(value),0,50) and world._critical_resistance_stat(other)==clampi(common+int(world._equipment_inven_sum(other+"_critical_resistance")),0,50),"critical resistance keeps exact attack scope including gear with both bonuses "+key)
  elif key.ends_with("_damage_reduction_pct") and key!="dot_damage_reduction_pct":
   var kind: String=key.get_slice("_",0)
   check(world._pve_damage_after_item_buffs(10000,0.0,kind)<world._pve_damage_after_item_buffs(10000,0.0,""),"actual attack-scoped incoming percent "+key)
  elif key=="dot_damage_reduction_pct":
   for kind: String in ["poison","bleed"]:
    world.hp=world._effective_max_hp();var before: int=world.hp
    world.call("_on_player_"+kind+"_tick",100)
    check(before-world.hp==maxi(1,int(round(100.0*(1.0-clampf(value,0,90)/100.0)))),"actual player DOT signal handler "+kind)
  elif key=="castSpeed":
   var with_item: float=world._skill_cooldown_factor()
   var equipped: Dictionary=world.equipped_items.duplicate(true)
   world.equipped_items.clear();world._invalidate_equipment_static()
   var without_item: float=world._skill_cooldown_factor()
   world.equipped_items=equipped;world._invalidate_equipment_static()
   check(with_item<without_item,"actual existing spell cooldown consumer")
  elif key=="healing_magic_pct":
   var healing: Dictionary={}
   for skill: Dictionary in world.original_skills.catalog.records:
    if skill.get("mode")=="heal":healing=skill;break
   check(not healing.is_empty(),"existing actual heal spell definition")
   var base_heal: int=100+int(world.original_skills.stat("lfe")*float(healing.get("lfe_scale",0)))
   world.hp=1;world.original_skills.heal(healing,100)
   check(world.hp==1+int(round(float(base_heal)*(1.0+value/100.0))),"actual magic healing receives exact source percent after existing LFE")
   world.hp=1;world.original_skills.heal({"id":"qa-regeneration","mode":"recovery"},100)
   check(world.hp==101,"magic amount never leaks into passive regeneration")
  if key.ends_with("critical_resistance") or key in ["melee_damage_reduction_pct","ranged_damage_reduction_pct","magic_damage_reduction_pct"]:verify_actual_npc_hit(world,key)
  check(world._save_game(true)==OK,"actual typed source save "+key)
  world._load_game(true)
  check(is_equal_approx(world._equipment_inven_sum(key),value),"actual typed source reload "+key)
  world._update_hud();world.hud.open_patch523_equipment_info();await process_frame
  var info: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  check(info!=null and info.pack_sha.text==book.digest and info.detail.text.contains("적용 연결"),"actual source detail/hash/applied UI "+key)
  if key in ["stun_accuracy","healing_magic_pct","magic_damage_reduction_pct","castSpeed"]:
   await capture("source-typed-"+key)
 # The exact source +0 stun family changes one existing rune: its base
 # resistance must be counted once, including after a real save/reload.
 var rune: Dictionary=equip_source(world,"226358",0,1)
 var base: Dictionary=world.INVEN_OPTIONS.annotate(book.record("226358"))
 var prepared: Dictionary=world._physical_enhancement_record(rune)
 check(is_equal_approx(float(STATS.stats("accessory",0,prepared).get("stun_resistance",0)),3.0-float(base.get("stun_resistance",0))),"actual rune +0 subtracts its annotated base exactly once")
 var with_rune: int=world._stun_resistance_stat()
 var equipped: Dictionary=world.equipped_items.duplicate(true)
 world.equipped_items.clear();world._invalidate_equipment_static()
 var without_rune: int=world._stun_resistance_stat()
 world.equipped_items=equipped;world._invalidate_equipment_static()
 check(with_rune-without_rune==3,"actual rune contributes source3 rather than duplicate6")
 check(world._save_game(true)==OK,"actual corrected rune save")
 world._load_game(true)
 check(world._stun_resistance_stat()==with_rune,"actual corrected rune reload")
 if not install_from.is_empty():
  var digest: String=book.digest
  OS.unset_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES");OS.unset_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256");OS.unset_environment("TWILIGHT_PATCH523_CRAFT_CATALOG_BIN")
  world.queue_free();await process_frame
  world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world);world.set_process(false);world.save_timer=-100000
  check(QA.enter_game(world,world.job_class),"installed source rules restore in an actual fresh Main")
  check(world.patch523_equipment.digest==digest and world.patch523_equipment.data.source_files.size()==38,"fresh Main loads exactly installed38-table runtime without environment arguments")
  check(world.patch523_craft_catalog_status.get("ok",false),"fresh Main restores installed shared item identities")
  check(world._stun_resistance_stat()==with_rune,"actual durable rune effect survives fresh installed Main")
 world.queue_free();await process_frame
 print("PATCH523_TYPED_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"consumer_reads":reads,"source_types":representatives.size(),"typed_families_executed":0 if rune_only else representatives.size(),"rune_only":rune_only}))
 quit(0 if failures.is_empty() else 1)
