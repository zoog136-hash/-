extends "res://tests/patch523_equipment_invokes_main_test.gd"
const KEYS=["damage_amp_pct","pve_damage_reduction_pct","adena_drop_pct"]

func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world),"actual Main/class UI")
 world.player.set_physics_process(false);world.field_population.set_process(false)
 var book: Object=world.patch523_equipment
 check(book.problem.is_empty() and book.data.source_files.size()==37,"actual37 source tables loaded")
 var changed_rows: Dictionary={};var representatives: Dictionary={};var consumer_reads: int=0;var items: Dictionary={}
 for id: String in book.data.equipment_runtime:
  var runtime: Dictionary=book.data.equipment_runtime[id]
  var affected: bool=false
  for state: Dictionary in runtime.extra_options.values():
   for rank: Dictionary in state.values():
    for key: String in KEYS:
     if rank.has(key):affected=true
  if not affected:continue
  items[id]=true
  if items.size()%50==0:print("PATCH523_NUMERIC_STAGE typed equipment ",items.size())
  var base: Dictionary=book.record(id)
  var new_reduction: bool=false
  for row: Dictionary in book.data.items[id].enchant_effects:
   if int(book.data.bonuses[str(int(row.BonusID))].BonusTypeID)==231:new_reduction=true
  for bless: int in [1,2]:
   var record: Dictionary=ENGINE.prepare(book,base,bless)
   record["instance_id"]="90001";record["bless_state"]="blessed" if bless==2 else "normal"
   if record.get("source_m_native_item",false):record["source_bless_raw"]=bless
   world.inventory={str(record.name):1}
   var baseline: Dictionary=world.INVEN_OPTIONS.annotate(base)
   for rank: int in range(21):
    var extra: Dictionary=record.enhancement_extra_options[str(rank)]
    for key: String in KEYS:
     if key=="pve_damage_reduction_pct" and not new_reduction:continue
     if float(extra.get(key,0))>0 and not representatives.has(key):representatives[key]={"id":id,"rank":rank,"bless":bless}
    if ui_only:continue
    world.item_instances={"90001":{"name":record.name,"record":record,"level":rank,"bless_state":record.bless_state,"source_bless_code":bless}}
    var slot: String=world._equipment_slot_base(record)
    if slot in ["earring","ring","seal"]:slot+="1"
    world.equipped_items={slot:record}
    world._invalidate_equipment_static()
    for key: String in KEYS:
     if not extra.has(key):continue
     var expected: float=float(baseline.get(key,0))+float(extra[key])
     check(is_equal_approx(world._equipment_inven_sum(key),expected),"actual Main exact source rank/state typed sum "+id+"/"+str(bless)+"/"+str(rank)+"/"+key)
     consumer_reads+=1
  for row: Dictionary in book.data.items[id].enchant_effects:
   var bonus: Dictionary=book.data.bonuses[str(int(row.BonusID))]
   if int(bonus.BonusTypeID) in [4073,11124,231,6322] and not runtime.unconnected_effect_row_ids.has(row.ID):changed_rows[str(row.ID)]=true
 print("PATCH523_NUMERIC_SOURCE_MATRIX ",JSON.stringify({"items_with_typed_values":items.size(),"new_unique_source_rows":changed_rows.size(),"actual_main_consumer_reads":consumer_reads,"matrix_skipped":ui_only}))
 check(changed_rows.size()==1132,"all1132 newly connected source rows retained and classified")
 check(representatives.size()==3,"all three existing world consumers have nonzero original examples")
 for key: String in representatives:
  var example: Dictionary=representatives[key]
  var record: Dictionary=equip_source(world,example.id,example.rank,example.bless)
  world._invalidate_equipment_static()
  var value: float=world._equipment_inven_sum(key)
  check(value>0,"actual class UI/equipped original positive "+key)
  check(STATS.summary(world._enhancement_kind_for_record(record),example.rank,world._physical_enhancement_record(record)).contains("%"),"source numerical percent appears in equipment UI "+key)
  if key=="pve_damage_reduction_pct":
   var expected: int=maxi(1,int(round(float(1000-int(world._equipment_inven_sum("pve_damage_reduction")))*(1.0-clampf(value,0,90)/100.0))))
   check(world._pve_damage_after_item_buffs(1000)==expected,"actual incoming PvE percent damage consumer")
  else:
   var target: TwilightMonster=world.MONSTER_SCENE.instantiate();world.add_child(target)
   target.setup(world.monster_db[0].duplicate(true),world.player,world,world._monster_texture(world.monster_db[0]))
   target.set_process(false);target.set_physics_process(false);target.max_hp=1000000;target.hp=target.max_hp
   if key=="damage_amp_pct":
    var source_damage: int=world.original_skills.outgoing_damage(100)
    var expected: int=world.original_skills.target_damage(maxi(1,int(round(float(source_damage)*(1.0+clampf(value,0,300)/100.0)))),target)
    var drain: int=1 if world._has_hp_absorption() else 0
    world._deal_successful_player_hit(target,100)
    check(target.hp==target.max_hp-expected-drain,"actual successful player hit applies source damage percent")
   else:
    target.gold_reward=100;target.exp_reward=0;target.dead=true
    var before_gold: int=world.gold
    var expected: int=int(round(100.0*world.ain_service.adena_rate()*(1.0+clampf(world._equipped_numeric_sum("adena_drop_pct"),0,500)/100.0)))
    world._on_monster_died(target)
    check(world.gold-before_gold==expected,"actual NPC death applies Adena-only original item26 modifier")
    var awarded: int=world.gold
    world._on_monster_died(target)
    check(world.gold==awarded,"repeated NPC death cannot duplicate source-modified reward")
   if is_instance_valid(target):target.queue_free()
  check(world._save_game(true)==OK,"source numeric actual save "+key)
  world._load_game(true)
  check(is_equal_approx(world._equipment_inven_sum(key),value),"source numeric actual reload "+key)
  world._update_hud();world.hud.open_patch523_equipment_info();await process_frame
  var information: Control=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
  if information!=null:
   for index: int in range(information.scroll_ids.size()):
    var evidence: Dictionary=book.enhancement_evidence(int(example.id),int(information.scroll_ids[index]),example.rank,example.bless,1)
    if not evidence.groups.is_empty() and not evidence.probabilities.is_empty():
     information.scroll.select(index);information.scroll.item_selected.emit(index);break
  check(information!=null and information.pack_sha.text==book.digest,"actual equipment detail displays loaded SHA "+key)
  var label: String={"damage_amp_pct":"대미지 증가","pve_damage_reduction_pct":"대미지 감소","adena_drop_pct":"아데나 드롭량"}[key]
  check(information!=null and information.detail.text.contains(label) and information.detail.text.contains("적용 연결"),"actual original effect label and active source row "+key)
  if information!=null:information.find_child("Patch523EquipmentScroll",true,false).scroll_vertical=100000
  await capture("source-numeric-"+key)
 world.queue_free();await process_frame
 print("PATCH523_NUMERIC_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"new_unique_source_rows":changed_rows.size(),"consumer_reads":consumer_reads}))
 quit(0 if failures.is_empty() else 1)
