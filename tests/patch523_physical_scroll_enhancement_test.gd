extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const ENHANCE = preload("res://scripts/crafting/patch523_enhancement.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const PROJECTION = preload("res://scripts/crafting/patch523_rules_projection.gd")
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const TARGET: int=3192
const SCROLL: int=6401
var checks: int=0
var failures: Array[String]=[]

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);printerr("PATCH523_PHYSICAL_SCROLL_FAIL ",label)
	return ok
func check_save(world: TwilightWorld) -> Dictionary:
	var j:=JSON.new()
	if j.parse(FileAccess.get_file_as_string(world.save_path()))!=OK or not j.data is Dictionary:return {}
	ACCOUNT.expand(j.data)
	return j.data
## Compact fixture for the same transaction. Bootstrap Main without loading
## unrelated original tables, then bind just these rows from the pinned ZIP.
## Never substitute a fake item, probability or stock receipt.
func bind_targeted(world: TwilightWorld, path: String) -> bool:
	# The targeted harness attaches the archive after Main configured unrelated
	# systems. An untouched skill-awakening owner was legitimately saveable
	# before attaching; retain that test-only condition without loading its tables.
	if world.skill_awakening.blocks_save() or not world.skill_awakening.definitions_not_installed():return false
	world.skill_awakening.problem=""
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",path)
	SOURCE.reset()
	if SOURCE.identity().is_empty():return false
	var items: Dictionary={}
	var bonuses: Dictionary={}
	for id: int in [TARGET,SCROLL]:
		var k: String=str(id)
		var item: Dictionary=PROJECTION.source_fields(k)
		var native: Dictionary=DROPS.definition_id(k).get("native_record",{})
		if item.is_empty() or native.is_empty():return false
		item["catalog_record"]=native
		items[k]=item
		for link: Dictionary in item.item_bonuses:
			var b: int=int(link.BonusID)
			bonuses[str(b)]=SOURCE.row("Bonus",b)
		world.catalog_db["아이템"].append(native)
	world._index_catalog_item_sources()
	var tables: Dictionary={}
	for table: String in ["BmItemEnchantProView","ItemEnchantCostView","ItemEnchantProbabilityView","ItemEnchantProbabilityGroup","ItemEnchantEquipGroupMapping","ItemEnchantScrollGroupMapping","ItemBlessEnchantProbability","Material"]:
		tables[table]=SOURCE.rows(table)
	world.patch523_equipment.data={"items":items,"bonuses":bonuses,"enchantment":tables}
	return true

func run() -> void:
	var targeted: String=OS.get_environment("TWILIGHT_TEST_ENHANCE_SOURCE")
	if targeted.is_empty() and SOURCE.not_installed():printerr("PATCH523_PHYSICAL_SCROLL_REAL_PACK_REQUIRED");quit(2);return
	for name: String in DirAccess.get_files_at("user://"):
		if name.begins_with("twilight_v20_save"):printerr("Isolated user data required");quit(2);return
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world),"actual Main character enters gameplay")
	world.field_population.set_process(false);world.player.set_physics_process(false);world.player.auto_enabled=false
	if not targeted.is_empty() and not check(bind_targeted(world,targeted),"original ZIP authenticated and exact targeted rows installed into fixture"):
		world.queue_free();await process_frame;quit(1);return
	var granted: Dictionary=INVENTORY.stage(world,[{"item_class_id":TARGET,"amount":1,"bless_raw":1,"enchant":0},{"item_class_id":SCROLL,"amount":2,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(granted.get("ok",false),"exact current ItemClass fixture grant: "+str(granted.get("error",""))):
		world.queue_free();await process_frame;quit(1);return
	var seed_error: Error=world._save_game(false,granted.overrides)
	check(seed_error==OK,"fixture saved by existing native owner: "+error_string(seed_error))
	world.inventory=granted.overrides.inventory;world.item_instances=granted.overrides.item_instances
	var uid: String="";var target_id: String=""
	for id: String in world.item_instances:
		var record: Dictionary=world.item_instances[id].get("record",{})
		match int(record.get("source_item_class_id",0)):
			TARGET:target_id=id
			SCROLL:uid=id
	if not check(not uid.is_empty() and not target_id.is_empty(),"physical weapon and scroll are distinct"):
		world.queue_free();await process_frame;quit(1);return
	var name: String=world.item_instances[uid].name
	var target_name: String=world.item_instances[target_id].name
	var reference: String=target_name+"@@@"+target_id
	var owned: Dictionary=STACK.proof(world,uid)
	var initial: String=FileAccess.get_sha256(world.save_path())
	var source_scroll: Dictionary=DROPS.definition_id(str(SCROLL)).get("native_record",{})
	for bless: int in [2,3]:
		var variant: Dictionary=DROPS.variant_item(source_scroll,bless)
		check(not variant.is_empty() and ENHANCE.item_id(variant)==str(SCROLL),"exact variant suffix joins ItemClass with bless "+str(bless))
		variant["source_bless_raw"]=3 if bless==2 else 2
		check(ENHANCE.item_id(variant).is_empty(),"mismatched variant blessing rejected "+str(bless))
	check(not owned.is_empty() and int(owned.remaining)==2,"original stack resolves two units")
	world.hud.inventory_item_activated.emit(name+"@@@"+uid)
	check(world._enhancement_scroll_selection.get("uid")==uid,"inventory activation chooses the actual physical scroll")
	check(world.item_instances.has(uid) and FileAccess.get_sha256(world.save_path())==initial,"opening cannot convert or consume a scroll")
	var quote: Dictionary=world._source_enhancement_rule(world.item_instances[target_id].record,0,"normal",name,world.item_instances[target_id],owned.record)
	check(is_equal_approx(float(quote.get("success",0.0)),33.3) and is_equal_approx(float(quote.get("destroy",0.0)),66.7) and int(quote.get("count",0))==1,"exact BlackMithril +0 success/destruction odds and existing quantity policy")
	var targets: Array=world._enhancement_candidates(world._scroll_kind(name),world._scroll_mode(name),name)
	check(targets.any(func(x: Dictionary)->bool:return x.target_id==reference),"actual target list exposes the proven item")
	var probe:=RandomNumberGenerator.new()
	for rng_seed: int in range(100):
		probe.seed=rng_seed
		if probe.randf_range(0.0,100.0)<33.3:
			world.rng.seed=rng_seed
			break
	var rng_before: int=world.rng.state
	world.enhancement_series_quiet=true
	var gold_before: int=world.gold
	var writes: Array[Dictionary]=[]
	world.equipment_collections.test_save_writer=func(_path: String,data: Dictionary)->Error:
		writes.append(data)
		return ERR_CANT_CREATE
	world.hud.enhancement_requested.emit(name,reference)
	check(int(STACK.proof(world,uid).get("remaining",-1))==2 and int(world.item_instances[target_id].level)==0 and world.gold==gold_before and world.rng.state==rng_before and FileAccess.get_sha256(world.save_path())==initial,"write failure preserves original units, weapon, RNG and disk")
	check(writes.size()==1,"valid enhancement reached the injected atomic writer exactly once")
	world.equipment_collections.test_save_writer=Callable()
	world.hud.enhancement_requested.emit(name,reference)
	var disk: Dictionary=check_save(world)
	var ledger: Dictionary=disk.get("consumable_state",{}).get(STACK.USES,{})
	check(int(world.item_instances[target_id].level)==1 and int(disk.get("item_instances",{}).get(target_id,{}).get("level",-1))==1,"confirmed +1 is applied and durable")
	check(world.gold==gold_before-1000 and int(disk.get("gold",-1))==gold_before-1000,"exact Ada cost charged once after durable save")
	check(int(world.inventory.get(name,0))==1 and int(world.item_instances[uid].get(STACK.QUANTITY,0))==1 and int(ledger.get(uid,{}).get("used_quantity",0))==1 and int(ledger.get(uid,{}).get("remaining_quantity",0))==1,"only one unit spent and physical receipt preserved on disk")
	var up_quote: Dictionary=world._source_enhancement_rule(world.item_instances[target_id].record,1,"normal",name,world.item_instances[target_id],owned.record)
	var break_threshold: float=float(up_quote.get("success",100.0))+float(up_quote.get("no_change",0.0))+float(up_quote.get("decrease",0.0))
	if check(float(up_quote.get("destroy",0.0))>0.0 and break_threshold<100.0,"original +1 row permits destruction"):
		for rng_seed: int in range(100):
			probe.seed=rng_seed
			if probe.randf_range(0.0,100.0)>break_threshold:
				world.rng.seed=rng_seed
				break
		world.hud.enhancement_requested.emit(name,reference)
		disk=check_save(world)
		ledger=disk.get("consumable_state",{}).get(STACK.USES,{})
		check(not world.item_instances.has(target_id) and not disk.get("item_instances",{}).has(target_id),"original-probability destruction removes only the selected equipment in memory and on disk")
		check(not world.item_instances.has(uid) and not disk.get("item_instances",{}).has(uid) and int(ledger.get(uid,{}).get("used_quantity",0))==2 and int(ledger.get(uid,{}).get("remaining_quantity",-1))==0,"last scroll debit preserves closed receipt without duplicated stock")
		var final_hash: String=FileAccess.get_sha256(world.save_path())
		world.hud.enhancement_requested.emit(name,reference)
		check(FileAccess.get_sha256(world.save_path())==final_hash,"stale enhancement request cannot write or reapply")
	world.queue_free();await process_frame
	print("PATCH523_PHYSICAL_SCROLL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"target":TARGET,"scroll":SCROLL,"name":name,"target_name":target_name,"rule":quote,"targeted_source_rows":not targeted.is_empty()}))
	quit(0 if failures.is_empty() else 1)
