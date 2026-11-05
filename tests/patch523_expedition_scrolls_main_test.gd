extends "res://tests/patch523_expedition_crafting_main_test.gd"
## Six exact issued scroll identities, real physical targets and forge UI.
## Controlled source storage and existing debug catalog grant are explicit QA.
func run() -> void:
 var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
 root.add_child(world);world.set_process(false);world.save_timer=-100000
 check(QA.enter_game(world),"actual Main and class picker for issued scrolls")
 freeze(world)
 check(world.install_patch523_craft_catalog_zip("/workspace/pr238-full-drive239/TWILIGHT_patch523_full_items_38ee3ec7.zip"),"exact full native target catalog installed")
 world.expedition_catalog=load("res://scripts/expedition/source_catalog.gd").new()
 check(world.expedition_catalog.install(CATALOG_PATH,CATALOG_SHA),"exact published expedition source catalog")
 world.expedition_local=load("res://scripts/expedition/local_runtime.gd").new();world.expedition_local.world=world;world.expedition_local.restore({})
 world.level=100;world.gold=1000000000
 var completed: Array=[]
 for scroll_id: String in ["137","138"]:
  for bless: int in [1,2,3]:
   world.inventory={"화살":0,"총알":0};world.item_instances={};world.equipped_items={};world.ui_preferences["item_locks"]={};world.gold=1000000000
   var source_id: String="3192" if scroll_id=="137" else "252"
   var record: Dictionary=world.patch523_equipment.record(source_id)
   world._grant_playtest_catalog_variant(str(record.sourceId),1)
   var physical_id: String=world._chosen_instance(str(record.name))
   check(not physical_id.is_empty(),"existing debug grant creates actual exact catalog physical target "+source_id)
   if physical_id.is_empty():continue
   var initial: int=1 if bless==3 else 0
   world.item_instances[physical_id].level=initial
   var scroll_key: String=issued(world,scroll_id,10,bless)
   check(world._scroll_mode(scroll_key)=={1:"normal",2:"blessed",3:"cursed"}[bless],"issued raw blessing controls mode without a name alias")
   var quote: Dictionary=world._source_enhancement_rule(record,initial,world._scroll_mode(scroll_key),scroll_key,world.item_instances[physical_id])
   check(quote.get("source_rule",false) and quote.has("group"),"actual exact item/scroll groups resolve "+scroll_id+":"+str(bless)+str(quote))
   if not quote.has("group"):continue
   check(world._save_game(true)==OK,"actual issued scroll/target baseline saved")
   world._on_inventory_item_activated(scroll_key);await process_frame
   var forge: Control=world.hud.enhancement_forge
   check(forge!=null and forge.values.size()==1 and forge.values[0].instance_id==physical_id,"actual three-argument forge candidates identify exact physical target")
   if forge==null or forge.values.is_empty():continue
   check(forge.detail.text.contains("TWILIGHT") or forge.detail.text.contains("게임 설정"),"forge discloses source/host policy")
   var before: String=JSON.stringify([world.inventory,world.item_instances,world.gold,world.expedition_local.state]);var old_sha: String=FileAccess.get_sha256(world.save_path());var old_rng: int=world.rng.state
   world.ui_preferences.item_locks={scroll_key:true}
   world._attempt_enhancement(scroll_key,str(record.name)+"@@@"+physical_id)
   check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.expedition_local.state])==before and FileAccess.get_sha256(world.save_path())==old_sha and world.rng.state==old_rng,"locked original scroll remains intact "+scroll_id+":"+str(bless))
   world.ui_preferences.item_locks={}
   var tuple: String=scroll_id+":"+str(bless)+":0"
   world.expedition_local.state.issued.erase(tuple)
   world._attempt_enhancement(scroll_key,str(record.name)+"@@@"+physical_id)
   check(world.item_instances[physical_id].level==initial and int(world.inventory[scroll_key])==10,"stale forge cannot consume a scroll without its issued ledger")
   world.expedition_local.state.issued[tuple]=scroll_key
   if scroll_id=="137" and bless==1:
    var owner: RefCounted=world.expedition_local
    var original_catalog: Array=world.catalog_db["아이템"]
    world.catalog_db["아이템"]=original_catalog.filter(func(value: Dictionary) -> bool:return value.get("name")!=scroll_key)
    world.expedition_local=null
    check(world._find_catalog_item_record(scroll_key).is_empty(),"orphan saved issued key has no installed provider or catalog identity")
    var orphan: Dictionary=world.patch523_open_expedition_enhancement(scroll_key)
    check(orphan.get("handled",false) and not orphan.get("ok",false),"orphan namespace is refused rather than interpreted as a legacy scroll")
    world._attempt_enhancement(scroll_key,str(record.name)+"@@@"+physical_id)
    check(JSON.stringify([world.inventory,world.item_instances,world.gold,owner.state])==before and FileAccess.get_sha256(world.save_path())==old_sha and world.rng.state==old_rng,"missing provider/catalog cannot consume saved typed scroll via legacy substring fallback")
    world.catalog_db["아이템"]=original_catalog;world.expedition_local=owner
    world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary) -> Error:return ERR_FILE_CANT_WRITE
    seed_roll(world,0,float(quote.success))
    old_rng=world.rng.state
    world._attempt_enhancement(scroll_key,str(record.name)+"@@@"+physical_id)
    check(world.item_instances[physical_id].level==initial and int(world.inventory[scroll_key])==10 and world.rng.state==old_rng and FileAccess.get_sha256(world.save_path())==old_sha,"pre-write failure restores issued scroll, physical target, fee and RNG together")
    world.equipment_collections.test_save_writer=Callable()
   world._on_inventory_item_activated(scroll_key);await process_frame
   forge=world.hud.enhancement_forge
   if bless!=3:seed_roll(world,0,float(quote.success))
   var original_qty: int=int(world.inventory.get(scroll_key,0));var original_gold: int=world.gold
   if scroll_id=="138" and bless==2:
    world.equipment_collections.test_save_writer=func(path: String,data: Dictionary) -> Error:
     var result: Error=preload("res://scripts/skills/save_writer.gd").write_text(path,JSON.stringify(data,"",true,true))
     return ERR_FILE_CANT_WRITE if result==OK else result
   forge.action.pressed.emit();check(confirm(world),"actual issued scroll forge confirmation")
   world.equipment_collections.test_save_writer=Callable()
   await process_frame
   check(int(world.inventory.get(scroll_key,0))==original_qty-int(quote.count) and world.gold==original_gold-int(quote.cost),"source count/fee consume exact issued key once")
   check(world.item_instances.has(physical_id) and (int(world.item_instances[physical_id].level)==initial-1 if bless==3 else int(world.item_instances[physical_id].level)>initial),"exact physical target changes according to selected original scroll "+scroll_id+":"+str(bless))
   finish_reveal(world)
   var after: String=JSON.stringify([world.inventory,world.item_instances,world.gold,world.expedition_local.state]);var rng_after: int=world.rng.state
   world._load_game(true);freeze(world)
   check(JSON.parse_string(JSON.stringify([world.inventory,world.item_instances,world.gold,world.expedition_local.state],"",true,true))==JSON.parse_string(after) and world.rng.state==rng_after,"actual reconnect keeps issued scroll debit/target/ledger/RNG "+scroll_id+":"+str(bless))
   completed.append(tuple)
 check(completed.size()==6,"normal/blessed/cursed137/138 are six distinct executed UI transactions")
 print("EXPEDITION_SCROLL_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"completed":completed,"controlled_storage_and_target_grant":true,"cursed_nonengraved_and_minimum_are_twilight_policy":true}))
 world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
