extends SceneTree
## Actual Main and native touch paths. Original private pixels are not fixtures.
const QA=preload("res://tests/qa_class_selection.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
const Slot=preload("res://scripts/cards/native_relic_subslot.gd")
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
	world.card_draw_fusion.owned["마법인형"][new_id]=true
	world.card_draw_fusion.owned["성물"][relic_id]=true
	world.gold=10000000;world._update_hud()
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent)
		await select_card("마법인형",new_id)
		await tap(hud.companion_detail_view.footer_actions.find_child("CompanionQuickRegister",true,false))
		var view: Control=hud.workspace.content.find_child("CardSkillAwakeningView",true,false)
		check(view!=null and view.identity==new_id,"new card enters existing skill screen")
		if view==null:continue
		check(view.find_child("SkillGrowthReadiness",true,false).text.contains("미확인"),"unverified growth rules visible in actual UI")
		var req: Dictionary=world.skill_awakening.core.book_requirement(new_id);var book: Dictionary={}
		for record: Dictionary in world.catalog_db["아이템"]:
			if record.get("source","")=="lineagem_base508" and int(record.get("source_item_class_id",0))==int(req.item_class_id):book=record;break
		check(not book.is_empty(),"real source book exists")
		var book_instance: String=add_physical(book);var gold: int=world.gold
		var scroll: ScrollContainer=view.get_parent();scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await settle()
		check(view.action.custom_minimum_size.y>=44,"native skill action touch size")
		await tap(view.action)
		check(world.skill_awakening.progress.cards.has(new_id) and world.skill_awakening.progress.cards[new_id].level==1 and world.skill_awakening.progress.cards[new_id].experience=="0","actual screen touch commits one-book awakening/reset")
		check(not world.item_instances.has(book_instance) and world.gold==gold-int(req.fee),"actual writer commits physical debit and fee")
		check(view.current.text.contains("Lv.1") and view.growth.text.contains("저장 경험치 0"),"committed result reflected on screen")
		scroll.scroll_vertical=0;await capture("new-card-skill-%dx%d" % [extent.x,extent.y]);hud._close_workspace();await settle()
		if not Unlock.unlocked(world.option_awakening.progress):
			var unlock: Dictionary=Unlock.record();var physical: String=add_physical(unlock);world._update_hud();hud.toggle_inventory();await settle()
			var bag: Control=hud.lineage_inventory_ui;bag._select_item(str(unlock.name)+"@@@"+physical);bag.open_detail();await settle()
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
	var file=FileAccess.open(folder+"/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"errors":errors}));file.close()
	print("PATCH523_AWAKENING_UI_WORLD ",JSON.stringify({"checks":checks,"errors":errors,"scope":"ACTUAL_MAIN_TOUCH_ITEM_UNLOCK_SLOT_AND_SKILL; PRIVATE_PIXELS_NOT_VERIFIED"}))
	world.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
