extends "res://tests/source523_npc_local_main_test.gd"
const KEY:String="귀환 주문서 (각인) · 원본#239"
const POLICY=preload("res://scripts/quickslots/regional_return.gd")
func run() -> void:
	if OS.get_environment("TWILIGHT_OWNED_RETURN_TEST")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty():quit(2);return
	var world:Node=load("res://Main.tscn").instantiate();root.add_child(world);freeze(world)
	if "--owned-return-restart" in OS.get_cmdline_user_args():
		var bytes:PackedByteArray=FileAccess.get_file_as_bytes(world.save_path())
		check(world.active_map_id=="aden_world" and not world.source_save_blocked,"fresh process restores the committed Aden destination")
		check(not world.inventory.has(KEY),"fresh process retains exact native stock depletion")
		var replay:Dictionary=world.consumable_service.use_owned_native_return(KEY)
		check(not replay.ok and not replay.saved and int(replay.consumed)==0,"fresh process cannot replay an unowned native scroll")
		check(FileAccess.get_file_as_bytes(world.save_path())==bytes,"blocked restart replay preserves exact durable bytes")
		print("SOURCE523_OWNED_RETURN_RESTART_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
		world.queue_free();await frames();quit(1 if failures else 0);return
	check(QA.enter_game(world),"actual Main and existing Aden destination")
	freeze(world)
	# Exact existing PR238 producer contract; explicit QA owned stock, not quest issuance.
	var record:Dictionary={"name":KEY,"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:239","source_item_class_id":239,"source_m_native_item":true,"source_display_name":"귀환 주문서 (각인)","source_bless_raw":1,"slot":"consumable","source_is_consumable":true,"source_test_item":false,"grade":"일반","weight":0}
	world.catalog_db["아이템"].append(record);world.inventory[KEY]=2;world._index_item_weights()
	check(POLICY.stack_identity(KEY,record).get("origin")=="patch523_native_normal","exact native item239 key accepted without legacy merge")
	var host_count:int=int(world.inventory.get("귀환 주문서",0));var canonical:int=int(world.inventory.get("귀환 주문서 (각인)",0))
	check(world._save_game(true)==OK,"isolated owned-stock fixture baseline saved")
	var before:PackedByteArray=FileAccess.get_file_as_bytes(world.save_path());var position:Vector2=world.player.global_position
	world.equipment_collections.test_save_writer=func(_path:String,_data:Dictionary)->Error:return ERR_CANT_CREATE
	var result:Dictionary=world.consumable_service.use_owned_native_return(KEY)
	check(result.handled and not result.ok and not result.saved and int(result.consumed)==0,"handled never means committed on failed native return save")
	check(world.player.global_position==position and int(world.inventory[KEY])==2 and FileAccess.get_file_as_bytes(world.save_path())==before,"failed writer restores exact source stock and position and durable bytes")
	world.equipment_collections.test_save_writer=Callable()
	record.source_bless_raw=2
	result=world.consumable_service.use_owned_native_return(KEY)
	check(not result.ok and not result.saved and int(world.inventory[KEY])==2,"other blessing never consumes or coalesces")
	record.source_bless_raw=1;world.player.apply_stun(1.0)
	check(not world.consumable_service.use_owned_native_return(KEY).ok and int(world.inventory[KEY])==2,"stun preserves exact native stack")
	world.player.clear_status_effects()
	world.ui_preferences.item_locks[KEY]=true
	check(not world.consumable_service.use_owned_native_return(KEY).ok,"locked native scroll preserved")
	world.ui_preferences.item_locks.erase(KEY)
	result=world.consumable_service.use_owned_native_return("잊혀진 귀환 주문서 (각인)")
	check(not result.ok and not result.saved,"native239 API never substitutes dedicated126424")
	world._on_inventory_item_activated(KEY)
	check(int(world.inventory[KEY])==1,"actual inventory route consumes the exact owned source239 once")
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(int(saved.inventory[KEY])==1 and saved.map_id=="aden_world" and saved.position==[world.player.global_position.x,world.player.global_position.y],"actual inventory consumer durably saves position with exact stock")
	result=world.consumable_service.use_owned_native_return(KEY)
	check(result.ok and result.saved and int(result.consumed)==1 and result.source_item_id==239,"structured caller can require ok and saved and consumed1")
	check(not world.inventory.has(KEY) and not world.consumable_service.use_owned_native_return(KEY).ok,"empty native stack cannot replay")
	check(int(world.inventory.get("귀환 주문서",0))==host_count and int(world.inventory.get("귀환 주문서 (각인)",0))==canonical,"legacy and shop-owned source keys remain distinct")
	world._load_game(true);freeze(world)
	check(not world.inventory.has(KEY),"reload cannot restore spent native stock")
	world._set_map("source_70",false);freeze(world)
	check(world.active_map_id=="source_70","existing PC source70 loads; no M coordinates introduced")
	# Nonpersistent isolated stock probe only; the denied call must not save it.
	world.inventory[KEY]=1;before=FileAccess.get_file_as_bytes(world.save_path())
	result=world.consumable_service.use_owned_native_return(KEY)
	check(not result.ok and not result.saved and int(world.inventory[KEY])==1 and FileAccess.get_file_as_bytes(world.save_path())==before,"cross-map destination dependency preserves native stock and durable bytes")
	world.inventory.erase(KEY)
	print("SOURCE523_OWNED_RETURN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"stock":"exact native issuer fixture, not actual quest reward","destination":"existing Aden only; cross-map native dependency preserved"}))
	world.queue_free();await frames();quit(1 if failures else 0)
