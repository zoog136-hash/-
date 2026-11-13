extends SceneTree
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("PATCH523_UPGRADE_FAIL: ",label)
func run() -> void:
	var old_zip: String=OS.get_environment("TWILIGHT_PATCH523_OLD_ZIP")
	var new_zip: String=OS.get_environment("TWILIGHT_PATCH523_DROP_ZIP")
	check(D.install_zip(old_zip).get("ok",false),"previous full pack installed")
	check(not D.data().has("item_use_counts") and D.data().counts.verified_item_bindings==2379,"previous pack remains usable before installing current")
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world),"actual Main using previous pack")
	world.field_population.set_process(false);world.player.set_physics_process(false);world._clear_monsters();world._clear_drops()
	var stone: Dictionary=world._catalog_item_from_source_id("m523:item:323353")
	check(stone.get("slot")=="material","historical source-only slot definition loaded")
	var normal: String=str(stone.name)
	var blessed: String=normal+" · 축복"
	world.inventory[normal]=1;world.inventory[blessed]=2
	check(world._save_game(true)==OK,"previous source stack save durable")
	var old_hash: String=FileAccess.get_sha256(world.save_path())
	world.hud.open_settings_info(true);await process_frame
	var settings: Node=world.hud.find_child("Patch523DropSettings",true,false)
	check(settings!=null,"live source installer UI")
	settings._selected(new_zip)
	check(D.data().has("item_use_counts") and D.data().counts.item_definitions>=2624,"current full definitions loaded after UI install")
	check(world._catalog_item_from_source_id("m523:item:323353").get("slot")=="domination_stone","live existing source catalog row upgraded by exact identity")
	check(world._find_catalog_item_record(blessed).get("source_legacy_stack_variant",false),"previous blessing key upgraded without renaming inventory")
	check(int(world.inventory.get(normal,0))==1 and int(world.inventory.get(blessed,0))==2,"normal and blessed quantities survive live upgrade")
	check(FileAccess.get_sha256(world.save_path())==old_hash,"pack installation does not overwrite previous save")
	world._sync_item_instances()
	var matching: int=0
	for instance: Dictionary in world.item_instances.values():
		if str(instance.get("name","")) in [normal,blessed]:
			matching+=1
			check(instance.get("record",{}).get("source_item_class_id",0)==323353,"historical stack physical identity retained")
			check(str(instance.get("bless_state","normal"))==("blessed" if instance.name==blessed else "normal"),"historical blessing state retained")
	check(matching==3,"existing three items become exactly three physical items")
	var id: String=world._chosen_instance(blessed,true)
	world._on_inventory_item_activated(blessed+"@@@"+id)
	check(str(world.equipped_items.domination_stone.get("instance_id",""))==id,"upgraded original blessed item actually equips")
	check(world._save_game(true)==OK,"upgraded physical items saved")
	if D.data().get("full_item_catalog",false):check(FileAccess.get_sha256(world.save_path()+".pre-itemclass523-"+old_hash)==old_hash,"live ItemClass upgrade creates immutable byte-exact backup before first write")
	world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
	check(int(world.inventory[normal])==1 and int(world.inventory[blessed])==2 and world.item_instances.has(id),"upgraded identities and quantities survive reentry")
	check(D.install_zip(old_zip).get("ok",false) and D.data().has("item_use_counts"),"older reinstall cannot downgrade current source data")
	check(FileAccess.file_exists(D.installed_path(D.PREVIOUS_DATA_SHA)),"previous installed data preserved")
	var phase3: String=OS.get_environment("TWILIGHT_PATCH523_PHASE3_ZIP")
	if not phase3.is_empty():
		check(D.install_zip(phase3).get("ok",false) and int(D.data().counts.item_definitions)>=2624,"phase3 reinstall cannot downgrade selectable/book pack")
		check(FileAccess.get_sha256(D.installed_path(D.PHASE3_DATA_SHA))==D.PHASE3_DATA_SHA,"phase3 payload retained in separate immutable version folder")
	world.queue_free();await process_frame
	print("PATCH523_PACK_UPGRADE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
