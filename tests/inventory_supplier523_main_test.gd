extends "res://tests/inventory_registry_automatic_ui_test.gd"
## Actual Main UI/save with explicit supplier-record fixtures; not a PR247 merge
## or a claim that ordinary play can acquire these items on this branch.
const SUPPLIER_TEST = preload("res://tests/inventory_supplier523_contract_test.gd")
func run() -> void:
	folder = "/tmp/supplier523-evidence"
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world = load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	check(QA.enter_game(world),"actual Main startup")
	freeze();hud = world.hud
	var auto = world.inventory_automation
	var status: Dictionary = auto.refresh_catalog()
	check(status.deposit == 80 and status.sell == 19,"production catalog remains80/19; supplier runtime is absent")
	hud.open_inventory_automation_settings("deposit");await frames()
	var screen: Control = hud.transaction_view
	check(screen.source_rows.size() == 84 and screen.source_status.text.contains("원본 정의 확인") and screen.source_status.text.contains("235, 237, 313, 385"),"all original storage rows and precise registration dependency shown")
	var teleport: Dictionary = SUPPLIER_TEST.supplier_record(auto.source_rules.definition("313"))
	var mana: Dictionary = SUPPLIER_TEST.supplier_record(auto.source_rules.definition("385"))
	world.inventory[teleport.name] = 5;world.inventory[mana.name] = 4
	world.item_instances["detached_supplier"] = {"name":mana.name,"record":mana.duplicate(true)}
	check(auto.source_rules.resolve(world._find_catalog_item_record(mana.name)).is_empty(),"detached save-instance record does not authenticate a normal stack")
	world.item_instances.erase("detached_supplier")
	var ownership: String = JSON.stringify([world.inventory,world.item_instances,world.gold])
	world.catalog_db["아이템"].append(teleport);world.catalog_db["아이템"].append(mana)
	world._index_catalog_item_sources()
	status = auto.refresh_catalog()
	check(status.deposit == 82 and status.sell == 20 and JSON.stringify([world.inventory,world.item_instances,world.gold]) == ownership,"explicit supplier fixtures add two definition matches but no ownership")
	world.inventory["순간이동 주문서"] = 8;world.inventory["마나 회복 물약"] = 9
	check(auto.set_source_only(true).ok,"source-only selection enabled")
	hud.open_inventory_automation_settings("deposit");await frames();screen = hud.transaction_view
	check(select_source(screen,313) and screen.held_options.size() == 1 and not screen.register.disabled,"actual UI finds exact engraved PR247 key without a sourceId field")
	check(screen.held_choice.get_item_text(1).contains("shop523:item:313"),"explicit supplier ID visible without mutating upstream record")
	screen.keep.value = 2;await click(screen.register)
	check(auto.contains("deposit",teleport.name,"") and auto.preview("deposit").cart[0].quantity == 3,"touch selection preserves exact supplier key and reserve")
	hud.open_inventory_automation_settings("sell");await frames();screen = hud.transaction_view
	check(screen.source_rows.size() == 25 and select_source(screen,385) and screen.fallback.editable,"all original sale rows; unknown price remains explicitly configurable")
	screen.fallback.value = 17;await click(screen.price_action)
	select_source(screen,385);screen.keep.value = 1;await click(screen.register)
	check(auto.preview("sell").payment == 51 and not auto.source_rules.eligible(auto.source_rules.resolve(teleport),"sell"),"own price17 is visible; original313 non-sale rule remains")
	select_source(screen,385);screen.list.ensure_current_is_visible()
	await capture("supplier-contract-fixture-1280x720")
	hud.open_warehouse();await frames();screen = hud.transaction_view
	await click(screen.auto_controls.get_node("AutoActions/AutoFill"))
	check(dialog() != null,"actual warehouse opens source supplier cart confirmation")
	await click(dialog().cancel_button)
	check(world.inventory[teleport.name] == 5 and not world.warehouse.stacks.has(teleport.name),"actual cancel preserves stack")
	await click(screen.auto_controls.get_node("AutoActions/AutoFill"));await click(dialog().confirm_button)
	check(world.inventory[teleport.name] == 2 and world.warehouse.stacks[teleport.name] == 3 and world.inventory["순간이동 주문서"] == 8,"actual store UI commits exact engraved key without normal-stack alias")
	hud.open_item_sell();await frames();screen = hud.transaction_view
	var wallet: int = world.gold
	await click(screen.auto_controls.get_node("AutoActions/AutoFill"))
	check(dialog() != null,"actual sale UI opens supplier cart")
	var disk: String = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	await click(dialog().confirm_button)
	check(world.inventory[mana.name] == 4 and world.gold == wallet and FileAccess.get_sha256(world.save_path()) == disk,"actual supplier sale writer failure preserves disk and inventory")
	world.equipment_collections.test_save_writer = Callable()
	await click(screen.auto_controls.get_node("AutoActions/AutoFill"));await click(dialog().confirm_button)
	check(world.inventory[mana.name] == 1 and world.gold == wallet+51 and world.inventory["마나 회복 물약"] == 9,"actual supplier sale commits exact key with reserve and own price")
	world._load_game(true);freeze()
	check(world.inventory[teleport.name] == 2 and world.warehouse.stacks[teleport.name] == 3 and world.inventory[mana.name] == 1 and world.gold == wallet+51,"actual save reload preserves supplier cart result")
	check(auto.preview("sell").cart.is_empty() and auto.preview("deposit").cart.is_empty(),"reload cannot repeat source supplier processing")
	print("INVENTORY_SUPPLIER_MAIN: %d checks, %d failures; EXPLICIT_SUPPLIER_RECORD_FIXTURE_NOT_PRODUCTION_SUPPLY" % [checks,failures.size()])
	world.queue_free();await frames();quit(0 if failures.is_empty() else 1)
