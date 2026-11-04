extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
var archive: String=""
var export_path: String=""

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label); printerr("PATCH523_REGISTER_FAIL: ",label)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-catalog-zip="): archive=arg.trim_prefix("--source-catalog-zip=")
		if arg.begins_with("--export-registered-catalog="): export_path=arg.trim_prefix("--export-registered-catalog=")
	call_deferred("run")

func run() -> void:
	var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world); world.set_process(false); world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main class selection enters")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	check(not archive.is_empty() and FileAccess.file_exists(archive),"actual approved Drive source ZIP is present")
	check(world._save_game(true)==OK,"baseline actual save written")
	var sha: String=FileAccess.get_sha256(world.save_path())
	var inventory: String=JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id])
	world.hud.open_patch523_equipment_info(); await process_frame
	var button: Button=world.hud.workspace.find_child("Patch523InstallCraftCatalog",true,false)
	var dialog: FileDialog=world.hud.workspace.find_child("Patch523CraftCatalogDialog",true,false)
	check(button!=null and dialog!=null,"existing crafting info exposes actual source catalog installer")
	dialog.file_selected.emit(archive); await process_frame
	var status: Label=world.hud.workspace.find_child("Patch523CraftCatalogStatus",true,false)
	check(world.patch523_craft_catalog_status.get("ok",false) and status.text.contains("등록 완료"),"actual selected ZIP installs and registers through existing UI callback")
	check(FileAccess.get_sha256(world.PATCH523_CRAFT_CATALOG.STORE)==world.PATCH523_CRAFT_CATALOG.BIN_SHA,"shared installed BIN has verified original source fingerprint")
	var document: Dictionary=world.PATCH523_CRAFT_CATALOG.read(world.PATCH523_CRAFT_CATALOG.STORE)
	var expected: Dictionary={}
	for id: Variant in document.native_item_ids+document.native_reward_item_ids: expected[str(id)]=true
	var total: int=0
	for id: String in expected:
		var definition: Dictionary=document.item_definitions[id]
		if definition.original_item.get("TestItem",false) or definition.native_record.get("source_test_item",false): continue
		var registered: Dictionary=world._catalog_item_from_source_id("m523:item:"+id)
		check(not registered.is_empty() and int(registered.get("source_item_class_id",0))==int(id) and registered.get("name")==definition.native_record.name,"actual index registers exact source identity "+id)
		total+=1
	check(total==int(world.patch523_craft_catalog_status.get("added",-1)),"registered count comes from actual index rather than source row presence")
	check(world._catalog_item_from_source_id("m523:item:379").get("name")=="철 · 원본#379","original iron has separate exact ownership namespace")
	check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id])==inventory and FileAccess.get_sha256(world.save_path())==sha,"catalog install grants no inventory and preserves existing save bytes")
	var count: int=world.catalog_db["아이템"].size()
	check(world.install_patch523_craft_catalog_zip(archive) and world.catalog_db["아이템"].size()==count,"same verified data installation does not duplicate registered identities")
	check(not world.install_patch523_craft_catalog_zip(archive+".missing") and world.catalog_db["아이템"].size()==count,"bad replacement leaves actual registered catalog intact")
	if not export_path.is_empty():
		var file:=FileAccess.open(export_path,FileAccess.WRITE)
		check(file!=null,"actual registered catalog export can be written")
		if file!=null:
			file.store_string(JSON.stringify(world.catalog_db));file.flush();check(file.get_error()==OK,"actual registered catalog export flushed");file.close()
	world.queue_free(); await process_frame
	print("PATCH523_REGISTER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"registered":total,"actual_drive_pack":true,"export":export_path}))
	quit(0 if failures.is_empty() else 1)
