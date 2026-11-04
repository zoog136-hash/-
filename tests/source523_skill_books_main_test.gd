extends "res://tests/source523_regional_purchase_main_test.gd"
const BOOKS = preload("res://scripts/shop/source523_skill_books.gd")

func run() -> void:
	if OS.get_environment("TWILIGHT_SOURCE_BOOK_TEST") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		printerr("REQUIRES_ISOLATED_SOURCE_BOOK_PROFILE");quit(2);return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-capture-dir="):capture_directory=arg.trim_prefix("--source523-capture-dir=")
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	check(QA.enter_game(world),"actual Main character selection")
	freeze(world);world.level=100;world.gold=1000000000000
	world.con_stat=1000
	check(world.source_shop.catalog.available(),"verified original source catalogue")
	check(BOOKS.DATA.data.books.size()==130,"130 source-exact item/card/spell/reviewed skill contracts")
	world.hud.open_shop();await frames();tap(world.hud.shop_view.find_child("Source523Shop",true,false));await frames()
	var panel: Node=world.hud.shop_view.find_child("Source523ShopPanel",true,false)
	check(panel!=null,"actual source shop UI")
	if panel==null:world.queue_free();quit(1);return
	var completed: Dictionary={};var first: bool=true;var total_paid: int=0
	var rejected: Dictionary={}
	for job: String in ["기사","군주","요정","마법사","다크엘프","총사","투사","암흑기사","신성검사","광전사","사신","뇌신","마검사"]:
		world.job_class=job
		for sale: Dictionary in world.source_shop.catalog.rows("MerchantGoods"):
			if int(sale.MerchantsID)!=10 or completed.has(str(int(sale.ID))):continue
			var quote: Dictionary=world.source_shop.quote_merchant(int(sale.ID))
			if not quote.ok:
				rejected[str(int(sale.ID))]=str(quote.get("reason",""));continue
			var spec: Dictionary=BOOKS.contract(int(sale.ItemClassID))
			check(not spec.is_empty() and BOOKS.learn_reason(world,spec).is_empty(),"native class/level prerequisites checked before sale")
			var key: String=str(quote.name);var skill_id: String=str(spec.skill_id)
			var native_before: int=int(world.inventory.get(key,0))
			var host_key: String=str(world.original_skills.catalog.record_for(skill_id).book_name)
			var host_before: int=int(world.inventory.get(host_key,0))
			var gold_before: int=int(world.gold)
			if not await buy_and_receive(panel,world,int(sale.ID),1):world.queue_free();quit(1);return
			check(int(world.gold)==gold_before-int(quote.payment.amount) and int(world.inventory.get(key,0))==native_before+1,"actual original price payment and exact engraved receipt")
			total_paid+=int(quote.payment.amount)
			check(int(world.inventory.get(host_key,0))==host_before,"generic book key never coalesces")
			if first:
				check(world._save_game(true)==OK,"pre-failure paid receipt saved")
				var before: PackedByteArray=FileAccess.get_file_as_bytes(world.save_path())
				world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
				world._on_inventory_item_activated(key)
				check(int(world.inventory.get(key,0))==native_before+1 and not world.original_skills.catalog.learned.has(skill_id),"learning writer failure restores paid book and learned ID")
				check(FileAccess.get_file_as_bytes(world.save_path())==before,"learning failure preserves exact durable receipt/save bytes")
				world.equipment_collections.test_save_writer=Callable()
				var record: Dictionary=world._find_catalog_item_record(key)
				record.source_bless_raw=2;world._on_inventory_item_activated(key)
				check(int(world.inventory.get(key,0))==native_before+1 and not world.original_skills.catalog.learned.has(skill_id),"blessing mismatch cannot consume or learn")
				record.source_bless_raw=1
				await capture("actual-source-book-purchased")
				first=false
			world._on_inventory_item_activated(key)
			check(world.original_skills.catalog.owned(world.original_skills.catalog.record_for(skill_id)) and int(world.inventory.get(key,0))==native_before,"actual inventory use delegates to existing learned skill catalog")
			check(not world.source_shop.quote_merchant(int(sale.ID)).ok,"learned skill cannot be repurchased through source NPC")
			check(int(world.inventory.get(host_key,0))==host_before,"learning consumes exact source key only")
			completed[str(int(sale.ID))]={"name":key,"skill":skill_id,"job":job}
	check(not first and completed.size()>0,"at least one real paid book reaches production learning")
	check(world._save_game(true)==OK,"all paid receipts and learned IDs saved")
	world._load_game(true);freeze(world)
	for id: String in completed:
		var row: Dictionary=completed[id]
		check(int(world.original_skills.catalog.learned.get(str(row.skill),0))==1 and int(world.inventory.get(str(row.name),0))==0,"reload retains consumed exact source book and stable learned ID")
	check(world.source_shop.orders().is_empty(),"all book receipts remain claimed after reload")
	await capture("source-book-learning-saved")
	print("SOURCE523_SKILL_BOOK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_paid_books_learned":completed.size(),"total_paid":total_paid,"class_profiles":"controlled13class QA eligibility; no new spell effects","unexecuted_or_blocked_rows":137-completed.size()}))
	world.queue_free();await frames();quit(1 if failures else 0)
