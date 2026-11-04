extends SceneTree
## Actual Main/Drive-restored523 pack. Currency and spatial results stay separate.
const QA=preload("res://tests/qa_class_selection.gd")
var checks:int=0
var failures:Array[String]=[]
var scan:Array=[]
var successful_moves:int=0
var reentrant_code:String=""
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("AUTO_HUNT_GEM_MAIN_FAIL: ",label)
func snapshot(w:Node)->Dictionary:
	return {"gold":w.gold,"inventory":JSON.stringify(w.inventory,"",true,true),"instances":JSON.stringify(w.item_instances,"",true,true),"position":w.player.global_position,"auto":w.player.auto_enabled,"path":w.player.click_path.duplicate(),"sha":FileAccess.get_sha256(w.save_path())}
func run()->void:
	var scene=load("res://Main.tscn") as PackedScene
	check(scene!=null,"production Main loads")
	if scene==null:quit(1);return
	var w=scene.instantiate();root.add_child(w);w.set_process(false);w.save_timer=-100000.0
	check(QA.enter_game(w),"actual Main/class startup")
	w.player.set_physics_process(false)
	if is_instance_valid(w.field_population):w.field_population.set_process(false)
	w.level=99;w.gold=1234567;w.inventory["다이아"]=100;w.player.auto_enabled=true
	check(w._save_game(true)==OK,"real initial save with existing inventory wallet")
	var baseline:Dictionary=snapshot(w)
	w._update_hud();w.hud._navigate("auto");await process_frame
	var view=w.hud.find_child("AutoHuntingDestinations",true,false)
	check(view!=null and view.is_visible_in_tree(),"Gem option mounted in actual AUTO UI")
	view.local_enabled.button_pressed=true
	check(not w.auto_hunting_local_settings().gem_wallet_enabled,"old/default policy does not auto-spend Gem")
	view.gem_enabled.button_pressed=true
	check(w.auto_hunting_local_settings().gem_wallet_enabled and w.auto_hunting_gem_wallet().balance==100,"actual UI enables existing wallet binding")
	var entries:Array=view.entries
	var gem_entry:int=-1
	for i:int in range(entries.size()):
		if int(entries[i].currency.ID)==4:gem_entry=i;break
	check(gem_entry>=0,"actual Gem source entry available")
	if gem_entry<0:quit(1);return
	view.regions.select(gem_entry);view.regions.item_selected.emit(gem_entry)
	check(view.details.text.contains("Gem ID4") and view.details.text.contains("100"),"UI shows source currency and actual wallet")
	var id:int=entries[gem_entry].schedule.ID;var link:int=entries[gem_entry].destinations[0].link.ID
	var cost:int=entries[gem_entry].teleport.TeleportCost
	view.gem_enabled.button_pressed=false
	check(w.auto_hunting_move(id,link).code=="GEM_WALLET_DISABLED" and snapshot(w)==baseline,"cancel policy spends no currency or character save")
	view.gem_enabled.button_pressed=true
	w.inventory["다이아"]=cost-1
	check(w.auto_hunting_move(id,link).code=="INSUFFICIENT_GEM","actual world rejects insufficient Gem even with plenty of gold")
	w.inventory["다이아"]=100
	check(snapshot(w)==baseline,"insufficient funds leaves state and save unchanged")
	w.ui_preferences.item_locks["다이아"]=true
	check(w.auto_hunting_move(id,link).code=="GEM_LOCKED","actual inventory lock blocks spending")
	w.ui_preferences.item_locks.erase("다이아")
	var candidate:Dictionary={};var region:int=-1
	for i:int in range(entries.size()):
		var entry:Dictionary=entries[i]
		if int(entry.currency.ID)!=4:continue
		var source:Dictionary=w.auto_hunting_schedule.request_definition(int(entry.schedule.ID),int(entry.destinations[0].link.ID),99,0,100)
		check(source.ok and source.currency_id==4 and source.price==int(entry.teleport.TeleportCost),"exact original Gem cost supported for every menu")
		var quote:Dictionary=w.auto_hunting_movement_assessment(int(entry.schedule.ID),int(entry.destinations[0].link.ID))
		scan.append({"schedule":int(entry.schedule.ID),"link":int(entry.destinations[0].link.ID),"code":str(quote.get("code","READY")),"ok":bool(quote.ok)})
		print("AUTO_HUNT_GEM_SCAN ",JSON.stringify(scan[-1]))
		check(str(quote.code) not in ["UNSUPPORTED_CURRENCY","INSUFFICIENT_GEM","GEM_WALLET_DISABLED"],"currency eligibility independent of Land/path guards")
		if quote.ok and candidate.is_empty():candidate=quote;region=i
	check(scan.size()==23,"all23 real Gem menus assessed")
	# Current configured alternatives may choose a different safe cell. Never
	# alter original regions, field passability or the production save guard.
	if candidate.is_empty():
		for order:String in ["coordinate_order","center_first"]:
			for inclusive:bool in [false,true]:
				w.auto_hunting_set_local_settings({"enabled":true,"end_inclusive":inclusive,"search_order":order,"gem_wallet_enabled":true})
				for i:int in range(entries.size()):
					var entry:Dictionary=entries[i]
					if int(entry.currency.ID)!=4 or int(entry.destinations[0].land.ID)!=4:continue
					var quote:Dictionary=w.auto_hunting_movement_assessment(int(entry.schedule.ID),int(entry.destinations[0].link.ID))
					if quote.ok:candidate=quote;region=i;break
				if not candidate.is_empty():break
			if not candidate.is_empty():break
	if not candidate.is_empty():
		id=int(candidate.schedule_id);link=int(candidate.landing_link_id)
		view._sync_settings();view.regions.select(region);view.regions.item_selected.emit(region)
		check(not view.move_button.disabled,"safe Gem destination enables production move button")
		var before:Dictionary=snapshot(w)
		w.equipment_collections.test_save_writer=func(_p:String,_d:Dictionary)->Error:
			reentrant_code=str(w.auto_hunting_move(id,link).code);return ERR_CANT_CREATE
		view.move_button.pressed.emit()
		check(view.status.text.contains("실패") and snapshot(w)==before,"Gem save failure preserves exact wallet position items and saved bytes")
		check(reentrant_code=="BUSY","Gem reentrant spend blocked")
		w.equipment_collections.test_save_writer=Callable()
		view.move_button.pressed.emit()
		check(view.status.text.contains("완료") and w.player.global_position==candidate.destination,"actual Gem movement succeeds through UI")
		check(w.gold==1234567 and int(w.inventory.get("다이아",0))==100-int(candidate.price),"only exact original Gem fee debited; no Adena conversion")
		var prior_items:Dictionary=JSON.parse_string(str(before.inventory));prior_items.erase("다이아")
		var next_items:Dictionary=JSON.parse_string(JSON.stringify(w.inventory));next_items.erase("다이아")
		check(prior_items==next_items and JSON.stringify(w.item_instances,"",true,true)==str(before.instances),"all other inventory and physical IDs preserved")
		check(w.hud.currency_balances["다이아"]==int(w.inventory.get("다이아",0)) and view.details.text.contains(str(int(w.inventory.get("다이아",0)))),"HUD and destination UI show remaining Gem")
		var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
		check(int(saved.inventory["다이아"])==int(w.inventory["다이아"]) and int(saved.gold)==1234567 and saved.position==[candidate.destination.x,candidate.destination.y],"Gem debit and destination durable in same save")
		var after:Dictionary=snapshot(w)
		check(w.auto_hunting_move(id,link).code=="ALREADY_THERE" and snapshot(w)==after,"duplicate Gem activation cannot debit twice")
		var point:Vector2=w.player.global_position;var balance:int=int(w.inventory["다이아"])
		w.inventory["다이아"]=1;w._load_game(true)
		check(w.player.global_position==point and int(w.inventory["다이아"])==balance and w.gold==1234567,"actual reload restores Gem debit and destination")
		check(FileAccess.get_sha256(w.save_path())==after.sha,"reload does not rewrite saved bytes")
		successful_moves=1
		for row:Dictionary in scan:
			if not bool(row.ok) or int(row.schedule)==id:continue
			var previous_balance:int=int(w.inventory.get("다이아",0))
			var moved:Dictionary=w.auto_hunting_move(int(row.schedule),int(row.link))
			check(moved.ok and moved.code=="MOVED","other safe Gem destination performs actual movement")
			check(w.gold==1234567 and int(w.inventory.get("다이아",0))==previous_balance-int(moved.get("price",0)),"each safe Gem move debits only original amount")
			if moved.ok:successful_moves+=1
		# The existing Adena path must still debit gold and preserve Gem.
		var gems_before:int=int(w.inventory.get("다이아",0))
		var adena:Dictionary=w.auto_hunting_move(174,882)
		check(adena.ok and w.gold==1234567-int(adena.get("price",0)) and int(w.inventory.get("다이아",0))==gems_before,"actual Adena movement remains independent of Gem wallet")
		# Exact funds may reach zero without retaining a negative or phantom key.
		w.inventory["다이아"]=int(candidate.price)
		check(w._save_game(true)==OK,"exact Gem balance durably staged by test fixture")
		var zero:Dictionary=w.auto_hunting_move(id,link)
		check(zero.ok and not w.inventory.has("다이아"),"actual exact-fee Gem movement consumes balance to zero")
		w._load_game(true)
		check(not w.inventory.has("다이아") and w.auto_hunting_gem_wallet().balance==0,"zero Gem balance survives reload without a grant")
		w.hud._navigate("auto");await process_frame
		view=w.hud.find_child("AutoHuntingDestinations",true,false)
		view.regions.select(region);view.regions.item_selected.emit(region)
		check(view.move_button.disabled and view.details.text.contains("다이아 0"),"reopened UI shows zero balance and blocks another fee")
	else:
		check(snapshot(w)==baseline,"all spatially blocked Gem requests preserve original wallet and save")
		view.regions.select(gem_entry);view.regions.item_selected.emit(gem_entry)
		view.move_button.pressed.emit()
		check(snapshot(w)==baseline and not view.status.text.is_empty(),"actual UI reports spatial block without spending Gem")
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture=") and DisplayServer.get_name()!="headless":
			var scroll:ScrollContainer=w.hud.find_child("AutoSettingsScroll",true,false)
			await process_frame
			if scroll!=null:scroll.ensure_control_visible(view.gem_enabled)
			await process_frame;await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))==OK,"actual Gem UI captured")
	print("AUTO_HUNT_GEM_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scan":scan,"successful_moves":successful_moves,"reentrant_code":reentrant_code,"drive_pack":OS.get_environment("TWILIGHT_AUTO_HUNT523_DIR")}))
	w.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
