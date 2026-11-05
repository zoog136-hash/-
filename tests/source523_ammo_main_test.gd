extends "res://tests/source523_regional_purchase_main_test.gd"
const AMMO=preload("res://scripts/shop/source523_ammo.gd")

func run() -> void:
	if OS.get_environment("TWILIGHT_SOURCE_AMMO_TEST")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():printerr("REQUIRES_ISOLATED_SOURCE_AMMO_PROFILE");quit(2);return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-capture-dir="):capture_directory=arg.trim_prefix("--source523-capture-dir=")
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	check(QA.enter_game(world),"actual Main class selection")
	freeze(world);world.level=100;world.gold=10000000;world.con_stat=1000
	world.hud.open_shop();await frames();tap(world.hud.shop_view.find_child("Source523Shop",true,false));await frames()
	var panel: Node=world.hud.shop_view.find_child("Source523ShopPanel",true,false)
	check(panel!=null,"actual original shop UI")
	if panel==null:world.queue_free();quit(1);return
	var weapons: Dictionary={}
	for id: int in [2602,13364,12333]:
		var offer: Dictionary=world.source_shop.quote_merchant(id)
		check(offer.ok,"existing real NPC weapon is purchasable")
		if not offer.ok:world.queue_free();quit(1);return
		if not await buy_and_receive(panel,world,id,1):world.queue_free();quit(1);return
		var record: Dictionary=world._find_catalog_item_record(str(offer.name))
		var kind: String=world._normalized_weapon_type(str(record.type))
		weapons["스팅" if kind=="건틀렛" else world._weapon_ammo_from_type(kind)]=str(offer.name)
	check(weapons.has("화살") and weapons.has("총알") and weapons.has("스팅"),"actual purchased bow/rifle/gauntlet retain distinct ammo families")
	var expected: Dictionary={};var first: bool=true
	for id: int in [2011,10161,12293,12303,13344,14654,14664,14674,14684,24583,37561]:
		var quote: Dictionary=world.source_shop.quote_merchant(id,3)
		check(quote.ok,"exact ordinary source ammunition is available")
		if not quote.ok:world.queue_free();quit(1);return
		var name: String=str(quote.name);var original:int=int(world.inventory.get(name,0))
		var source_record: Dictionary=world._find_catalog_item_record(name)
		var cap:int=int(world.source_shop.catalog.record("ItemClass",int(world.source_shop.catalog.merchant_offer(id).goods.ItemClassID)).MaxStackAmount)
		check(int(source_record.get("source_max_stack",0))==cap and source_record.get("source_bless_raw")==1,"source stack cap and Normal metadata registered")
		world.inventory[name]=cap
		check(not world.source_shop.quote_merchant(id).ok,"single source-key stack cap blocks over-cap purchase")
		world.inventory[name]=original
		if not await buy_and_receive(panel,world,id,3):world.queue_free();quit(1);return
		var received:int=int(world.source_shop.catalog.merchant_offer(id).goods.Amount)*3
		check(int(world.inventory.get(name,0))==original+received,"original bundle quantity credited exactly")
		var record: Dictionary=world._find_catalog_item_record(name)
		var spec: Dictionary=AMMO.definition(record)
		world.job_class={"화살":"요정","총알":"총사","스팅":"뇌신"}[spec.family]
		world._on_inventory_item_activated(str(weapons[spec.family]));await frames()
		check(world._weapon_ammo_family()==spec.family or (spec.family=="스팅" and world._current_weapon_type()=="건틀렛"),"actual purchased weapon supports matching ammo family")
		var legacy_before: int=int(world.inventory.get(str(spec.family),0))
		world.hud.show_companion_bag();await frames()
		var bag=world.hud.lineage_inventory_ui
		bag._select_item(name);bag.open_detail();await frames()
		check(not bag.detail_action.disabled and bag.detail_action.text=="착용","actual inventory exposes distinct ammunition equip action")
		tap(bag.detail_action);await frames()
		check(world.equipped_ammo==name and world._current_ammo_name()==name,"real UI selects exact paid engraved ammo key")
		if first:
			check(world._save_game(true)==OK,"ammo equipment baseline saved")
			var bytes_before: PackedByteArray=FileAccess.get_file_as_bytes(world.save_path())
			world.equipment_collections.test_save_writer=func(_path:String,_data:Dictionary)->Error:return ERR_CANT_CREATE
			check(not world._consume_weapon_ammo() and int(world.inventory.get(name,0))==original+received,"failed native shot save cancels consumption")
			check(FileAccess.get_file_as_bytes(world.save_path())==bytes_before,"failed shot preserves durable receipts and source quantity")
			world.equipment_collections.test_save_writer=Callable()
			record.source_bless_raw=2
			check(not world._consume_weapon_ammo() and int(world.inventory.get(name,0))==original+received,"invalid blessing cannot silently fall back to generic ammunition")
			record.source_bless_raw=1
			var mp_before:int=int(world.mp)
			world.equipment_collections.test_save_writer=func(_path:String,_data:Dictionary)->Error:return ERR_CANT_CREATE
			check(not world._spend_skill_mp({"mp":1,"ammo_per_hit":1,"hits":1}) and int(world.mp)==mp_before and int(world.inventory.get(name,0))==original+received,"failed existing skill charge restores MP and selected arrow key")
			world.equipment_collections.test_save_writer=Callable()
			check(world._spend_skill_mp({"mp":1,"ammo_per_hit":1,"hits":1}) and int(world.inventory.get(name,0))==original+received-1,"existing arrow skill cost consumes selected exact source stack")
			received-=1;first=false
		check(world._consume_weapon_ammo() and int(world.inventory.get(name,0))==original+received-1,"production shot gate consumes purchased native ammo once")
		check(int(world.inventory.get(str(spec.family),0))==legacy_before,"shot leaves generic and other ammo stacks unchanged")
		expected[name]=original+received-1
		check(world._save_game(true)==OK,"exact ammo equipment/use saved")
		world._load_game(true);freeze(world)
		check(world.equipped_ammo==name and int(world.inventory.get(name,0))==int(expected[name]),"reloaded equip and exact remaining source quantity")
	var target: Node=world.monsters_root.get_child(0) if world.monsters_root.get_child_count()>0 else null
	check(target!=null,"actual Main monster exists for size/race damage contract probe")
	if target!=null:
		var was_undead:bool=target.undead;var was_type:String=target.monster_type
		target.undead=false;target.monster_type="QA contract target"
		for item: String in expected:
			var record: Dictionary=world._find_catalog_item_record(item);var spec:Dictionary=AMMO.definition(record)
			for size:String in ["small","large"]:
				target.set_meta("size_class",size)
				var damage:int=AMMO.roll(record,target,world.rng)
				check(damage>=1 and damage<=int(spec[size]),"original per-size ammo bounds reach existing RNG consumer")
				var state_before:int=world.rng.state
				var normal:int=AMMO.roll(record,target,world.rng)
				world.rng.state=state_before;target.undead=true
				var undead:int=AMMO.roll(record,target,world.rng);target.undead=false
				check(undead-normal==(int(AMMO.DATA.data.estimated_undead_bonus) if int(spec.material) in AMMO.DATA.data.estimated_undead_materials else 0),"configured material bonus applies only to confirmed undead race")
		target.undead=was_undead;target.monster_type=was_type
	check(world.source_shop.orders().is_empty(),"weapon/ammo receipts cannot replay after use/reload")
	await capture("source-ammo-equipped-used-saved")
	print("SOURCE523_AMMO_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_paid_ammo_types":expected.size(),"shot_checks":"production consumption gate; damage size/race contract probe, no full combat equivalence claim"}))
	world.queue_free();await frames();quit(1 if failures else 0)
