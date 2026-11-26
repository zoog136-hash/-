extends SceneTree
const Catalog=preload("res://scripts/shop/source523_shop_catalog.gd")
const Packages=preload("res://scripts/shop/source523_cash_packages.gd")
const Books=preload("res://scripts/shop/source523_skill_books.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const LOOKUP=preload("res://scripts/catalog_item_lookup.gd")
var checks:=0
var fails:Array[String]=[]
func ck(ok:bool,message:String)->bool:
	checks+=1
	if not ok:fails.append(message);printerr("SHOP_STARTUP_FAIL ",message)
	return ok
func _initialize()->void:run.call_deferred()
func old_products(catalog,id:int,bonuses:bool)->PackedInt64Array:
	var result:=PackedInt64Array();var offer:Dictionary=catalog.market_offer(id)
	for link:Dictionary in offer.get("products",[])+(offer.get("bonuses",[]) if bonuses else []):
		var row:Dictionary=link.product.definition
		if int(row.get("UnitID",0))==4:result.append(int(row.ClassID))
	return result
func run()->void:
	ck(Catalog.new().install_item_products(-1,true).is_empty(),"missing purchase has no products")
	if not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty():
		if ck(not FileAccess.file_exists("user://twilight_v20_save.json"),"separate user data"):
			await actual()
	print("SHOP_STARTUP_SCOPE_RESULT ",JSON.stringify({"checks":checks,"failures":fails}))
	quit(0 if fails.is_empty() else 1)
func actual()->void:
	var world:Node=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.field_population.set_process(false)
	ck(QA.enter_game(world),"actual Main title/class route");world.player.set_physics_process(false)
	ck(world.source_shop._catalog==null and world.source_shop._catalog_released,"registered and released exactly like production")
	var at:int=Time.get_ticks_usec()
	world.hud.open_shop();await process_frame
	var actual_button:Button=world.hud.shop_view.find_child("Source523Shop",true,false)
	if ck(actual_button!=null and not actual_button.disabled,"first real shop has exact source entry"):
		actual_button.pressed.emit();await process_frame
		var panel:Node=world.hud.shop_view.find_child("Source523ShopPanel",true,false)
		ck(panel!=null and panel.is_visible_in_tree(),"first source panel opens")
	print("SHOP_STARTUP_FIRST_PANEL_US ",Time.get_ticks_usec()-at)
	var c=world.source_shop.catalog
	if ck(c!=null and c.available() and c.model_input_identity.get("kind")=="twilight.source523.original-shop-input.v1","actual pinned original market model"):
		var identity:String=c.loaded_sha256
		var ids:Array[int]=Packages.displayed_purchases(c)
		for key:String in Packages.CashMarket.data().entries:
			if int(key) not in ids:ids.append(int(key))
		var baseline:Array=[];var optimized:Array=[]
		var previous:int=0;var current:int=0
		for id:int in ids:
			for bonuses:bool in [false,true]:
				var tick:int=Time.get_ticks_usec()
				var old:PackedInt64Array=old_products(c,id,bonuses)
				previous+=Time.get_ticks_usec()-tick
				tick=Time.get_ticks_usec()
				var new:PackedInt64Array=c.install_item_products(id,bonuses)
				current+=Time.get_ticks_usec()-tick
				ck(old==new,"exact ordered physical roots "+str(id)+"/"+str(bonuses))
				baseline.append(old);optimized.append(new)
		ck(baseline==optimized and identity==c.loaded_sha256,"complete offer ID, bonus and digest parity")
		print("SHOP_STARTUP_EXTRACT_US old=",previous," new=",current," offers=",ids.size()," hash=",identity)
		check_book_install(world,c)
	world.queue_free();await process_frame
func check_book_install(world:Node,c)->void:
	# Reconstruct the exact candidate population (don't benchmark all-hit repeat registration).
	var catalog:Array=world.catalog_db["아이템"];var stock:Array=world.item_db
	var base_c:Array=catalog.filter(func(x:Dictionary)->bool:return x.get("source")!="twilight-shop523-book")
	var base_s:Array=stock.filter(func(x:Dictionary)->bool:return x.get("source")!="twilight-shop523-book")
	world._weight_index_deferred=true
	world.catalog_db["아이템"]=base_c.duplicate();world.item_db=base_s.duplicate()
	var at:int=Time.get_ticks_usec()
	var old:Dictionary=Books.install(world,c)
	var old_us:int=Time.get_ticks_usec()-at
	var old_rows:Array=world.catalog_db["아이템"];var old_stock:Array=world.item_db
	world.catalog_db["아이템"]=base_c.duplicate();world.item_db=base_s.duplicate()
	at=Time.get_ticks_usec()
	var scope:LOOKUP.CashInstallScope=Packages._install_lookup(world,c)
	ck(scope!=null,"actual Main append-only path")
	var new:Dictionary=Books.install(world,c,scope)
	var new_us:int=Time.get_ticks_usec()-at
	if scope!=null:scope.close()
	ck(not old.is_empty() and new==old and old_rows==world.catalog_db["아이템"] and old_stock==world.item_db,"new book bindings and appended row order exact")
	print("SHOP_STARTUP_SKILL_BIND_US old=",old_us," new=",new_us," rows=",old.size())
	world.catalog_db["아이템"]=catalog;world.item_db=stock
	world._weight_index_deferred=false
