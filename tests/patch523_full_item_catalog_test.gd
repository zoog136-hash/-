extends SceneTree
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const U = preload("res://scripts/loot/patch523_item_use.gd")
const GRANTS = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("FULL_ITEM_FAIL: ",label)
func reject(_path: String,_state: Dictionary) -> Error: return ERR_CANT_CREATE
func same_inventory(a: Dictionary,b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for key: String in a:
		if not b.has(key) or int(a[key]) != int(b[key]): return false
	return true
func run() -> void:
	var zip: String = OS.get_environment("TWILIGHT_PATCH523_DROP_ZIP")
	check(not zip.is_empty(),"explicit private full-source pack required")
	var installed: Dictionary = D.install_zip(zip)
	check(installed.get("ok",false),"full source root and every detail shard installed: "+str(installed.get("error","")))
	if not installed.get("ok",false): quit(1);return
	var document: Dictionary = D.data()
	check(int(document.counts.source_item_class_rows) == 34743 and D.definition_count() == 34743,"all 34743 source definitions indexed")
	check(document.native_item_ids.size() == 30398,"every non-Test source class registered")
	check(document.source_exclusions.size() == 4345 and document.source_exclusions.get("0") == "source_none_sentinel","Test and None preserved with exact exclusion reason")
	print("FULL_ITEM_STAGE source_installed ",D.definition_count())
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer = -100000
	check(QA.enter_game(world),"actual Main source map entry")
	world.field_population.set_process(false);world.player.set_physics_process(false)
	world._clear_monsters();world._clear_drops();world.level = 90
	print("FULL_ITEM_STAGE main_entered")
	# Real legacy JSON/physical identity migration; native stats replace web stats,
	# while unknown fields survive in the archived original record.
	var alias_id: String = "27" if document.catalog_aliases.has("27") else str(document.catalog_aliases.keys()[0])
	var old: Dictionary = document.catalog_aliases[alias_id].original_identity.duplicate(true)
	old["hit"] = 9876
	old["future_opaque"] = {"owner":"legacy","value":[7,"keep"]}
	var old_name: String = str(old.name)
	var uid: String = "source523-legacy-physical"
	world.inventory[old_name] = 1
	world.item_instances[uid] = {"name":old_name,"record":old.duplicate(true),"level":7,"element":"fire","element_level":2,"bless_state":"blessed","opaque_instance":"keep"}
	check(world._save_game(true) == OK,"legacy physical baseline persisted")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	legacy.erase("source_item_catalog")
	var legacy_file := FileAccess.open(world.save_path(),FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy));legacy_file.close()
	var legacy_sha: String = FileAccess.get_sha256(world.save_path())
	world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
	check(FileAccess.get_sha256(world.save_path()+".pre-itemclass523-"+legacy_sha) == legacy_sha,"byte-exact immutable pre-migration backup")
	check(int(world.inventory.get(old_name,0)) == 1 and world.item_instances.has(uid),"legacy stack and physical UID remain unchanged")
	check(int(world.item_instances[uid].level) == 7 and world.item_instances[uid].element == "fire" and int(world.item_instances[uid].element_level) == 2 and world.item_instances[uid].opaque_instance == "keep","legacy enhancement, element and unknown instance data preserved")
	check(world.item_instances[uid].record.get("source_m_native_item",false) and int(world.item_instances[uid].record.get("hit",0)) != 9876 and world.item_instances[uid].source523_previous_record.future_opaque.owner == "legacy","current native stats with archived opaque old source record")
	check(world._save_game(true) == OK,"migrated state committed")
	world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
	check(int(world.item_instances[uid].source523_previous_record.future_opaque.value[0]) == 7 and world.item_instances[uid].source523_previous_record.future_opaque.value[1] == "keep","archive remains available after second reentry")
	var grants: Array[Dictionary] = []
	var trash: int = 0
	var native_gear: int = 0
	var expired: int = 0
	for id: String in document.native_item_ids:
		var record: Dictionary = world.source_item_record(int(id))
		check(not record.is_empty() and int(record.get("source_item_class_id",-1)) == int(id) and D.matches(record,world._catalog_item_from_source_id("m523:item:"+id)),"runtime exact catalog identity "+id)
		check(not record.get("source_test_item",true),"normal source flag "+id)
		if record.get("source_is_trash",false): trash += 1
		if D.equipment(record): native_gear += 1
		if not D.deadline_problem(record).is_empty(): expired += 1
		grants.append({"item_class_id":int(id),"amount":1,"bless_raw":1,"enchant":0})
	check(trash == 1242,"all 1242 non-Test IsTrash rows preserved")
	check(world.source_item_record(0).is_empty(),"sentinel never becomes normal inventory")
	for id: String in document.source_exclusions:
		check(world.source_item_record(int(id)).is_empty(),"excluded source remains ungrantable "+id)
	for id: String in document.catalog_aliases:
		var alias: Dictionary = world._catalog_item_from_source_id(id)
		var source: Dictionary = D.cached_definition(id).native_record
		check(alias.get("source_m_native_item",false) and int(alias.get("source_item_class_id",-1)) == int(id),"every reviewed old source key replaced "+id)
		for field: String in ["small_damage","large_damage","additionalDamage","hit","def","hpFlat","mpFlat","strFlat","mr","xp","speed","attackSpeed"]:
			check(alias.get(field) == source.get(field),"native source stat outranks old web field "+id+"/"+field)
	print("FULL_ITEM_STAGE all_runtime_records ",grants.size()," gear ",native_gear," expired ",expired)
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var instances_before: Dictionary = world.item_instances.duplicate(true)
	check(world._save_game(true) == OK,"baseline durable save")
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(world.save_path())
	var staged: Dictionary = world.stage_source_item_grants(grants,{"kind":"isolated_full_catalog_supplier_contract"})
	check(staged.get("ok",false),"all normal source IDs stage through exact supplier contract: "+str(staged.get("error","")))
	check(world.inventory == inventory_before and world.item_instances == instances_before,"staging all source items never mutates live ownership")
	if not staged.get("ok",false): world.queue_free();await process_frame;quit(1);return
	check(staged.overrides.item_instances.size() == instances_before.size()+native_gear,"one physical identity for every mapped normal gear")
	world.equipment_collections.test_save_writer = reject
	check(world._save_game(true,staged.overrides) != OK,"all-source transaction actual writer failure")
	world.equipment_collections.test_save_writer = Callable()
	check(world.inventory == inventory_before and world.item_instances == instances_before and FileAccess.get_file_as_bytes(world.save_path()) == bytes_before,"failed full catalog acquisition preserves live ownership and save bytes")
	check(world._save_game(true,staged.overrides) == OK,"all-source supplier receipt durably committed")
	world.inventory = staged.overrides.inventory
	world.item_instances = staged.overrides.item_instances
	world.gold = int(staged.overrides.gold)
	print("FULL_ITEM_STAGE all_normal_ownership_saved")
	var owned: Dictionary = world.inventory.duplicate(true)
	world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
	check(same_inventory(world.inventory,owned),"every normal source inventory key and quantity survives real reentry")
	for id: String in document.native_item_ids:
		var record: Dictionary = world.source_item_record(int(id))
		var wallet: String = D.currency_identity_name(record)
		if wallet == "아데나": continue
		var key: String = wallet if not wallet.is_empty() else str(record.name)
		check(int(world.inventory.get(key,0)) >= 1,"every normal source item is addressable after reentry "+id)
	world.hud.open_catalog("아이템")
	world.hud._refresh_catalog_list("")
	var ui_ids: Dictionary = {}
	for record: Dictionary in world.hud.catalog_filtered_results:
		if record.get("source_m_native_item",false): ui_ids[str(int(record.get("source_item_class_id",-1)))] = true
		check(not record.get("source_test_item",false) and not record.get("source_preserved_legacy_catalog",false),"replacement UI hides archived/Test rows")
	for id: String in document.native_item_ids: check(ui_ids.has(id),"every normal source ID is reachable in actual catalog UI "+id)
	check(D.FULL_ITEMS.order.size() <= 2,"bounded detail shard cache")
	# Losing one owned installed shard cannot replace a full-source save with an
	# older/smaller catalog. Only this isolated profile's copied file is moved.
	var shard: String = str(document.item_shards.keys()[0])
	var installed_shard: String = D.installed_path().get_base_dir().path_join(shard)
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(world.save_path())
	check(DirAccess.rename_absolute(installed_shard,installed_shard+".qa-held") == OK,"hold one isolated installed detail shard")
	D._checked = false;D._data = {};D.FULL_ITEMS.reset()
	world._load_game(true)
	check(world.source_item_save_blocked and world._save_game(true) != OK and FileAccess.get_file_as_bytes(world.save_path()) == original_bytes,"missing full pack preserves exact saved bytes and blocks writes")
	check(DirAccess.rename_absolute(installed_shard+".qa-held",installed_shard) == OK,"restore same verified detail bytes")
	D._checked = false;D._data = {};D.FULL_ITEMS.reset()
	world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
	check(not world.source_item_save_blocked and same_inventory(world.inventory,owned),"restored full source pack reopens original ownership")
	world.queue_free();await process_frame
	print("FULL_ITEM_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_rows":34743,"normal_catalog":grants.size(),"native_gear":native_gear,"expired_rows_preserved":expired,"scope":"all identities and supplier/save/UI contract; not all item effects or normal suppliers"}))
	quit(0 if failures.is_empty() else 1)
