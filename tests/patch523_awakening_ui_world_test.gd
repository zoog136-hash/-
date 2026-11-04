extends SceneTree
## Actual Main and native touch paths. Original private pixels are not fixtures.
const QA=preload("res://tests/qa_class_selection.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
const Slot=preload("res://scripts/cards/native_relic_subslot.gd")
const Box=preload("res://scripts/cards/native_relic_reward_box.gd")
const Acquire=preload("res://scripts/cards/native_card_acquisition.gd")
var checks: int=0
var errors: Array[String]=[]
var folder: String=""
var world: Node
var hud: Node
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func settle() -> void:
	for frame: int in range(8):await process_frame
func tap(button: Control) -> void:
	check(button.is_visible_in_tree(),"touch target visible "+str(button.name))
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=3;event.position=point;event.pressed=pressed;root.push_input(event,true);await process_frame
	await settle()
func capture(name_value: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name_value+".png")==OK,"capture "+name_value)
func select_card(category: String,identity: String) -> void:
	hud.open_catalog(category);hud.catalog_search.text=identity.trim_prefix("source:");hud._refresh_catalog_list(hud.catalog_search.text);await settle()
	var found: bool=false
	for index: int in range(hud.catalog_results.size()):
		if Cards.card_id(hud.catalog_results[index])==identity:hud._select_catalog_index(index);found=true;break
	check(found,"existing catalog finds "+identity);hud._set_catalog_detail_view(true);await settle()
func add_physical(record: Dictionary) -> String:
	var before: Array=world.item_instances.keys()
	world._grant_playtest_catalog_variant(str(record.sourceId),1)
	for key: String in world.item_instances:
		if not key in before:return key
	check(false,"source-ID development grant creates physical provenance "+str(record.sourceId))
	return ""
func physical_for(item_id: int) -> String:
	for key: String in world.item_instances:
		var entry: Dictionary=world.item_instances[key]
		if entry.get("record") is Dictionary and entry.record.get("source_snapshot","")=="patch523" and int(entry.record.get("source_item_class_id",0))==item_id:return key
	return ""
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
	if folder.is_empty() or OS.get_environment("TWILIGHT_UI_TEST_ISOLATED")!="1":push_error("Explicit capture dir and isolated test profile required");quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.field_population.set_process(false)
	await settle()
	check(QA.enter_game(world),"actual Main class selection")
	check(not world.map_bootstrap_blocked,"actual current source map loaded")
	world.save_timer=-10000;world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
	hud=world.hud;hud.process_mode=Node.PROCESS_MODE_ALWAYS
	var new_id: String="source:m523:2:25152";var relic_id: String="source:m508:98:20548"
	world.card_draw_fusion.owned["마법인형"].erase(new_id);world._update_hud()
	await select_card("마법인형",new_id)
	check(hud.catalog_equip_button.disabled,"new card remains unowned/read-only")
	check(hud.catalog_preview.get_meta("original_card_asset",{}).get("status","")=="missing","unavailable523 image explicitly reported; no old art substituted")
	var coin: Dictionary=Acquire.record(Acquire.COIN)
	world.inventory["마법인형 제작 코인"]=77
	for definition: Dictionary in [Acquire.record(Acquire.TICKET),Acquire.record(Acquire.COIN),Box.record()]:
		world.inventory[definition.name]=1
		check(not world._drop_inventory_reference(str(definition.name),world.player.global_position) and world.inventory[definition.name]==1,"name-only copy cannot gain source provenance by floor transfer "+str(definition.source_item_class_id))
		world.inventory.erase(definition.name)
	var floor: Button=world.ground_loot.spawn(str(coin.name),world.player.global_position,3000001,"",{"item_record":coin})
	await create_timer(1.0).timeout
	check(floor!=null and world._collect_ground_drop(floor),"real floor pickup creates one provenance-backed source currency stack")
	var coin_id: String=physical_for(Acquire.COIN)
	check(not coin_id.is_empty() and world.item_instances[coin_id][Acquire.QUANTITY]==3000001,"source quantity retained without millions of fake physical IDs")
	var coin_before: int=hash([world.inventory,world.item_instances,world.warehouse.snapshot()])
	world._warehouse_transfer(str(coin.name),1,"deposit","")
	check(hash([world.inventory,world.item_instances,world.warehouse.snapshot()])==coin_before,"authoritative warehouse rejects source coin without losing physical quantity")
	check(world._drop_inventory_reference(str(coin.name)+"@@@"+coin_id,world.player.global_position),"one-coin floor transfer splits a source currency stack")
	check(world.item_instances[coin_id][Acquire.QUANTITY]==3000000,"drop preserves source stack remainder")
	await create_timer(1.0).timeout
	for view: Button in world.ground_loot.views.values():
		if world.ground_loot.valid_view(view):check(world._collect_ground_drop(view),"split physical coin returns through floor pickup");break
	await tap(hud.companion_detail_view.source_craft_button)
	var craft: Control=hud.workspace.content.find_child("NativeCardCraftView",true,false)
	check(craft!=null and not craft.action.disabled,"existing card detail opens funded source crafting")
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await capture("nemesis-craft-%dx%d" % [extent.x,extent.y])
	var craft_scroll: ScrollContainer=craft.get_parent();craft_scroll.scroll_vertical=int(craft_scroll.get_v_scroll_bar().max_value);await settle()
	await tap(craft.action)
	var ticket_id: String=physical_for(Acquire.TICKET)
	check(not ticket_id.is_empty() and not world.card_draw_fusion.owned["마법인형"].has(new_id),"craft commits physical ticket without auto-granting card")
	var ticket_before: int=hash([world.inventory,world.item_instances,world.warehouse.snapshot()]);world._warehouse_transfer(str(Acquire.record().name),1,"deposit",ticket_id)
	check(hash([world.inventory,world.item_instances,world.warehouse.snapshot()])==ticket_before,"source ticket cannot be converted to a name-only warehouse stack")
	check(world.inventory[coin.name]==1 and world.inventory["마법인형 제작 코인"]==77,"exact source debit preserves unrelated pre-existing currency")
	hud.toggle_inventory();await settle()
	var ticket_bag: Control=hud.lineage_inventory_ui
	ticket_bag._select_item(str(Acquire.record().name)+"@@@"+ticket_id);ticket_bag.open_detail();await settle();await tap(ticket_bag.detail_action)
	check(world.card_draw_fusion.owned["마법인형"].get(new_id,false) and not world.item_instances.has(ticket_id),"inventory touch consumes crafted ticket and acquires permanent new card")
	ticket_bag.hide_inventory();await settle()
	world.card_draw_fusion.owned["성물"][relic_id]=true
	world.gold=10000000;world._update_hud()
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent)
		await select_card("마법인형",new_id)
		await tap(hud.companion_detail_view.footer_actions.find_child("CompanionQuickRegister",true,false))
		var view: Control=hud.workspace.content.find_child("CardSkillAwakeningView",true,false)
		check(view!=null and view.identity==new_id,"new card enters existing skill screen")
		if view==null:continue
		check(view.find_child("SkillGrowthReadiness",true,false).text.contains("TWILIGHT"),"custom growth economics explicitly distinguished in actual UI")
		var req: Dictionary=world.skill_awakening.core.book_requirement(new_id);var book: Dictionary={}
		for record: Dictionary in world.catalog_db["아이템"]:
			if record.get("source","")=="lineagem_base508" and int(record.get("source_item_class_id",0))==int(req.item_class_id):book=record;break
		check(not book.is_empty(),"real source book exists")
		var book_instance: String=add_physical(book);var gold: int=world.gold
		if extent.x==1280:
			var physical_book: Dictionary=world.item_instances[book_instance].duplicate(true)
			world.ui_preferences.item_locks[str(book.name)+"@@@"+book_instance]=true
			world._warehouse_transfer(str(book.name),1,"deposit",book_instance)
			check(world.item_instances.has(book_instance) and not world.warehouse.instances.has(book_instance),"physical book lock prevents warehouse deposit")
			world.ui_preferences.item_locks.erase(str(book.name)+"@@@"+book_instance)
			world._warehouse_transfer(str(book.name),1,"deposit",book_instance)
			check(not world.item_instances.has(book_instance) and world.warehouse.instances.get(book_instance,{})==physical_book,"storable source book moves to warehouse with exact physical metadata")
			world._warehouse_transfer(str(book.name),1,"withdraw",book_instance)
			check(world.item_instances.get(book_instance,{})==physical_book and not world.warehouse.instances.has(book_instance),"source book withdrawal restores same identity and remains usable")
		var scroll: ScrollContainer=view.get_parent();scroll.ensure_control_visible(view.action);await settle()
		check(view.action.custom_minimum_size.y>=44,"native skill action touch size")
		await tap(view.action)
		check(world.skill_awakening.progress.cards.has(new_id) and world.skill_awakening.progress.cards[new_id].level==1 and world.skill_awakening.progress.cards[new_id].experience=="0","actual screen touch commits one-book awakening/reset")
		check(not world.item_instances.has(book_instance) and world.gold==gold-int(req.fee),"actual writer commits physical debit and fee")
		check(view.current.text.contains("Lv.1") and view.growth.text.contains("저장 경험치 0"),"committed result reflected on screen")
		check(world.hp<=world._effective_max_hp(),"paid reawakening clamps current HP to reset source profile")
		if extent.x==1280:
			var material: String=""
			for key: String in world.skill_awakening.core.cards:
				var candidate: Dictionary=world.skill_awakening.core.cards[key]
				if candidate.category=="마법인형" and int(candidate.source_card.GradeID)==4 and not bool(candidate.source_card.IsNoMergeOut) and world.skill_awakening.core.eligibility(key).ok:material=key;break
			check(not material.is_empty(),"actual eligible growth duplicate exists")
			world.card_draw_fusion.owned["마법인형"][material]=true;world.card_draw_fusion.spare["마법인형"][material]=6
			var before_growth_gold: int=world.gold;world.gold=0
			view.refresh_growth(true)
			check(view.growth_feed.disabled and view.growth_result.text.contains("아데나"),"growth screen reports insufficient currency")
			world.gold=before_growth_gold;world._refresh_combat_hud();await create_timer(.3).timeout
			check(not view.growth_feed.disabled and not view.growth_result.text.contains("아데나 부족"),"wallet change re-enables growth and clears stale reason without re-opening")
			for feed: int in range(6):
				scroll.ensure_control_visible(view.growth_feed);await settle();await tap(view.growth_feed)
			check(world.skill_awakening.progress.cards[new_id].level==2 and view.current.text.contains("Lv.2"),"six actual one-card synthesis touches grow source level and refresh UI")
			check(not world.card_draw_fusion.spare["마법인형"].has(material) and world.card_draw_fusion.owned["마법인형"][material],"synthesis consumes duplicates while retaining permanent ownership")
			await capture("skill-growth-result")
			world._equip_catalog("마법인형",world.option_awakening.core.catalog["마법인형"][new_id]);world.hp=world._effective_max_hp()
		scroll.scroll_vertical=0;await capture("new-card-skill-%dx%d" % [extent.x,extent.y]);hud._close_workspace();await settle()
		if not Unlock.unlocked(world.option_awakening.progress):
			var box: Dictionary=Box.record()
			var drop: Button=world.ground_loot.spawn(str(box.name),world.player.global_position,1,"",{"item_record":box})
			await create_timer(1.0).timeout
			check(drop!=null and world._collect_ground_drop(drop),"original reward box acquired through real floor pickup")
			var box_id: String=physical_for(Box.ITEM);world._update_hud();hud.toggle_inventory();await settle()
			var bag: Control=hud.lineage_inventory_ui;bag._select_item(str(box.name)+"@@@"+box_id);bag.open_detail();await settle()
			await capture("relic-reward-box-inventory");await tap(bag.detail_action)
			check(not world.item_instances.has(box_id) and not physical_for(365748).is_empty() and not physical_for(365758).is_empty() and not Unlock.unlocked(world.option_awakening.progress),"touch opens box into both exact guaranteed items without auto-unlock")
			var unlock: Dictionary=Unlock.record();var physical: String=physical_for(365748)
			check(not world._drop_inventory_reference(str(unlock.name)+"@@@"+physical,world.player.global_position),"original unlock item cannot be dropped")
			check(not world._drop_inventory_reference(str(Box.record(365758).name)+"@@@"+physical_for(365758),world.player.global_position),"original infinite summon scroll cannot be dropped")
			bag._select_item(str(unlock.name)+"@@@"+physical);bag.open_detail();await settle()
			check(bag.detail_action.text=="사용" and not bag.detail_action.disabled,"actual inventory presents unlock use action")
			await capture("relic-unlock-inventory")
			await tap(bag.detail_action)
			check(Unlock.unlocked(world.option_awakening.progress) and not world.item_instances.has(physical),"inventory touch reaches consumable and durable unlock")
			bag.hide_inventory();await settle()
		await select_card("성물",relic_id)
		var secondary: Button=hud.relic_reference_view.secondary_button
		world._equip_catalog("성물",world.option_awakening.core.catalog["성물"][relic_id])
		check(secondary.disabled,"same main card immediately disables additional summon")
		world._equip_catalog("성물",{})
		check(not secondary.disabled,"clearing main immediately refreshes additional eligibility")
		check(secondary.visible and not secondary.disabled and secondary.custom_minimum_size.y>=44,"actual relic additional summon action available")
		world.equipped_catalog["성물"]={};world.max_hp=10000;world._invalidate_equipment_static()
		var hp_before: int=world._effective_max_hp()
		await tap(secondary)
		check(world.option_awakening.relic_subslot_view().active and world.option_awakening.progress[Slot.FIELD]==relic_id,"screen touch selects actual additional relic")
		var hp_after: int=world._effective_max_hp()
		check(hp_after>hp_before and hp_after<hp_before*1.1,"actual HP consumer applies one percent rather than one hundred percent")
		world.hp=hp_after
		check(secondary.text=="추가 소환 해제" and hud.relic_reference_view.status.text.contains("추가:"),"selection and result status refresh")
		await capture("relic-additional-%dx%d" % [extent.x,extent.y])
		await tap(secondary)
		check(not world.option_awakening.relic_subslot_view().active and world._effective_max_hp()==hp_before,"screen release removes secondary stats")
		check(world.hp<=hp_before,"release clamps current HP to the reduced maximum")
		var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		check(int(disk.hp)<=hp_before and disk.card_option_awakening[Slot.FIELD]=="","release persists capped HP and slot state in one save")
		await capture("relic-released-%dx%d" % [extent.x,extent.y]);hud._close_workspace();await settle()
	var mariela: String="source:m508:2:25002"
	world.card_draw_fusion.owned["마법인형"][mariela]=true;world.equipped_catalog["마법인형"]=world.option_awakening.core.catalog["마법인형"][mariela]
	world.option_awakening.progress.cards["마법인형"][mariela]={"experience":0,"awakened":false,"attempts":1,"failures":1};world.option_awakening.progress.revision+=1;world._invalidate_equipment_static()
	var xp_before: float=world._experience_multiplier();world.option_awakening.progress.cards["마법인형"][mariela].awakened=true;world.option_awakening.progress.cards["마법인형"][mariela].failures=0;world.option_awakening.progress.revision+=1;world._invalidate_equipment_static()
	check(is_equal_approx(world._experience_multiplier()-xp_before,0.07),"actual XP consumer applies verified seven percent")
	var record: Dictionary=world.option_awakening.core.catalog["변신"]["source:m523:1:25293"]
	world.card_draw_fusion.owned["변신"][Cards.card_id(record)]=true
	var equipped_before: Dictionary=world.equipped_catalog.duplicate(true);world._equip_catalog("변신",record)
	check(world.equipped_catalog==equipped_before,"missing server274 definition rejects actual main equip without altering saved selection")
	hud.open_warehouse();await settle()
	var storage: Control=hud.transaction_view
	check(storage.entries.all(func(entry: Dictionary) -> bool:return str(entry.get("name","")) not in [str(coin.name),str(Box.record(365758).name)]),"actual warehouse listing omits source non-storable coin and reward scroll")
	var file=FileAccess.open(folder+"/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"errors":errors}));file.close()
	print("PATCH523_AWAKENING_UI_WORLD ",JSON.stringify({"checks":checks,"errors":errors,"scope":"ACTUAL_MAIN_TOUCH_ITEM_UNLOCK_SLOT_AND_SKILL; PRIVATE_PIXELS_NOT_VERIFIED"}))
	world.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
