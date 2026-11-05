extends SceneTree
## Actual Main/UI/atomic writer with isolated owned/item fixtures. No acquisition
## supplier, original art equivalence, expedition or Android claim.
const QA=preload("res://tests/qa_class_selection.gd")
const API=preload("res://scripts/lineagem_base508.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Slot=preload("res://scripts/cards/native_relic_subslot.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
var world: Node
var hud: Node
var checks: int=0
var errors: Array[String]=[]
var folder: String=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func frames(n: int=6) -> void:
	for i: int in range(n):await process_frame
func tap(button: Control) -> void:
	check(button.is_visible_in_tree(),"touch target visible "+str(button.name))
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=31;event.position=point;event.pressed=pressed;root.push_input(event,true);await process_frame
	await frames()
func capture(label: String) -> void:
	if folder.is_empty():return
	await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"capture "+label)
func select(category: String,identity: String) -> void:
	hud.open_catalog(category);hud.catalog_search.text=identity.trim_prefix("source:");hud._refresh_catalog_list(hud.catalog_search.text);await frames()
	var found: bool=false
	for i: int in range(hud.catalog_results.size()):
		if Cards.card_id(hud.catalog_results[i])==identity:hud._select_catalog_index(i);found=true;break
	check(found,"actual catalog stable ID "+identity);hud._set_catalog_detail_view(true);await frames()
func apply_primary() -> void:
	await tap(hud.catalog_equip_button)
	var modal: Control=hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	check(modal!=null,"actual primary confirmation opens")
	if modal!=null:
		# Standard confirmation buttons use pointer input; the primary and
		# secondary actions above are native touch paths.
		var point: Vector2=modal.confirm_button.get_global_transform_with_canvas()*(modal.confirm_button.size*.5)
		var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await frames(1)
		for pressed: bool in [true,false]:
			var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;root.push_input(event,true);await frames(1)
		await frames()
func freeze() -> void:
	world.set_process(false);world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_process(false);actor.set_physics_process(false)
func disk() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
func signature() -> String:
	return JSON.stringify([world.option_awakening.export_state(),world.card_draw_fusion.export_state(),world.equipped_catalog,world.hp,world.mp,world.inventory,world.item_instances,world.gold,FileAccess.get_sha256(world.save_path())])
func run() -> void:
	if OS.get_environment("TWILIGHT_UI_TEST_ISOLATED")!="1":push_error("isolated profile required");quit(2);return
	folder=OS.get_environment("TWILIGHT_CARD523_CAPTURE")
	if not folder.is_empty():DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	print("SLOT_UI_STAGE instantiating Main")
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames(10)
	print("SLOT_UI_STAGE Main ready")
	check(QA.enter_game(world) and not world.map_bootstrap_blocked,"actual Main current map and class flow")
	world.set_process(false);world.save_timer=-100000;world.player.set_physics_process(false);world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_process(false);actor.set_physics_process(false)
	hud=world.hud
	check(preload("res://scripts/cards/patch523_slot_data.gd").installed(),"hash-bound private support pack actually loaded")
	var new_id: String="source:m523:98:25162"
	var spare_before: Dictionary=world.card_draw_fusion.spare.duplicate(true)
	var rng_before: int=world.card_draw_fusion.rng.state
	await select("성물",new_id)
	check(hud.catalog_equip_button.disabled and not world.card_draw_fusion.owned["성물"].has(new_id),"new card lookup does not grant ownership")
	check(hud.catalog_preview.get_meta("original_card_asset").get("source_asset_id",0)==413882 and hud.catalog_preview.texture==null,"exact new portrait ID, missing pixels and no substituted art")
	# Controlled source ownership/item fixtures; production never grants these.
	for identity: String in [new_id,"source:m508:98:20548","source:m508:98:20578"]:world.card_draw_fusion.owned["성물"][identity]=true
	world.max_hp=10000;world.max_mp=1000;world.equipped_catalog["성물"]={};world._invalidate_equipment_static()
	print("SLOT_UI_STAGE fixture ownership installed")
	var unlock: Dictionary=Unlock.record()
	world.inventory[unlock.name]=2
	for id: String in ["slot-locked","slot-selected"]:world.item_instances[id]={"name":unlock.name,"record":unlock.duplicate(true)}
	world.ui_preferences.item_locks[str(unlock.name)+"@@@slot-locked"]=true
	check(world._save_game(true)==OK,"isolated fixture stored by real atomic writer")
	var ledger_before: Dictionary=world.card_draw_fusion.export_state().duplicate(true)
	var gold_before: int=world.gold
	# A locked selected physical item must not consume another unlocked copy.
	hud._close_workspace();hud.toggle_inventory();await frames()
	var bag=hud.lineage_inventory_ui
	bag._select_item(str(unlock.name)+"@@@slot-locked");bag.open_detail();await frames()
	var before: String=signature();await tap(bag.detail_action)
	check(signature()==before and not Unlock.unlocked(world.option_awakening.progress),"selected locked item preserves both copies and unlock state")
	bag._select_item(str(unlock.name)+"@@@slot-selected");bag.open_detail();await frames()
	world.equipment_collections.save_blocked=true;before=signature();await tap(bag.detail_action)
	check(signature()==before,"failed actual inventory save preserves item, selection, HP/MP and file")
	world.equipment_collections.save_blocked=false
	await tap(bag.detail_action)
	check(Unlock.unlocked(world.option_awakening.progress) and world.inventory[unlock.name]==1 and world.item_instances.has("slot-locked") and not world.item_instances.has("slot-selected"),"inventory touch consumes exactly selected original item and unlocks")
	check(disk().card_option_awakening[Unlock.FIELD]==JSON.parse_string(JSON.stringify(Unlock.marker())),"item debit and source unlock share actual saved state")
	before=signature();world.option_awakening.use_relic_unlock_item(unlock.name);check(signature()==before,"duplicate unlock preserves remaining item")
	bag.hide_inventory();await frames()
	var secondary: String="source:m508:98:20578" # exact +5MP, +1%HP secondary.
	print("SLOT_UI_STAGE unlock path finished")
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent);await frames()
		print("SLOT_UI_STAGE secondary ",extent)
		await select("성물",secondary)
		var button: Button=hud.relic_reference_view.secondary_button
		check(not button.disabled and button.custom_minimum_size.y>=44,"unlocked owned additional summon touch action")
		var physical_rect: Rect2=root.get_final_transform()*button.get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(physical_rect),"additional action fits physical viewport "+str(physical_rect)+" / "+str(root.size))
		var hp_cap: int=world._effective_max_hp();var mp_cap: int=world._effective_max_mp()
		world.hp=hp_cap;world.mp=mp_cap
		world.equipment_collections.save_blocked=true;before=signature();await tap(button)
		check(signature()==before,"failed UI selection has no ledger, caps or file mutation")
		world.equipment_collections.save_blocked=false;await tap(button)
		check(world.option_awakening.relic_subslot_view().active and world._effective_max_hp()>hp_cap and world._effective_max_mp()==mp_cap+5,"UI adds only native secondary +1%HP/+5MP effects")
		check(hud.relic_reference_view.secondary_effects.text.contains("최대 MP +5") and hud.relic_reference_view.secondary_effects.text.contains("최대 HP +1%"),"actual UI shows committed secondary effects")
		var active_hp: int=world._effective_max_hp();var active_mp: int=world._effective_max_mp()
		for i: int in range(3):world._update_hud()
		check(world._effective_max_hp()==active_hp and world._effective_max_mp()==active_mp,"UI refresh never stacks effects")
		world.hp=active_hp;world.mp=active_mp
		check(world._save_game(true)==OK,"active capped state stored")
		world._load_game(true);freeze();await frames();await select("성물",secondary);button=hud.relic_reference_view.secondary_button
		check(world.option_awakening.relic_subslot_view().active and world.hp==active_hp and world.mp==active_mp,"actual reload restores choice/current values and derived caps")
		await capture("secondary-active-%d" % extent.x)
		world.equipment_collections.save_blocked=true;before=signature();await tap(button)
		check(signature()==before,"failed release keeps active slot and uncropped HP/MP")
		world.equipment_collections.save_blocked=false;await tap(button)
		check(not world.option_awakening.relic_subslot_view().active and world.hp==hp_cap and world.mp==mp_cap,"actual release clamps current HP/MP with removed caps")
		check(disk().card_option_awakening[Slot.FIELD]=="" and int(disk().hp)==hp_cap and int(disk().mp)==mp_cap,"slot release and capped vitals committed together")
		await capture("secondary-released-%d" % extent.x)
	# Primary/secondary shared state and interval effects across changed caps.
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world.option_awakening.select_relic_subslot(secondary)
	var profile: Dictionary={}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/patch523_collections.json")).source_server_limits:
		if int(row.ServerLimitSetID)==772:profile={"source_snapshot":"patch523","ServiceRegionCode":row.ServiceRegionCode,"WorldNo":row.WorldNo};break
	check(not profile.is_empty(),"exact original server profile for HP interval fixture")
	world.card_collections.set_source_server_context(profile)
	for row: Dictionary in world.card_collections.core.definitions:
		if int(row.source_original.ID) in [14813,16521]:
			for req: Dictionary in row.requirements:world.card_draw_fusion.owned[req.category][req.id]=true
	world.card_collections.restore_from_owned();world._invalidate_equipment_static()
	world.hp=int(world._effective_max_hp()*0.6);world.mp=world._effective_max_mp()
	var fear_before: float=world.card_collections.interval_bonus("fear_resistance:percent",world.hp,world._effective_max_hp())
	await select("성물",new_id)
	world.equipment_collections.save_blocked=true;before=signature();await apply_primary()
	check(signature()==before,"failed primary change preserves secondary, HP interval and saved state")
	world.equipment_collections.save_blocked=false;await apply_primary()
	check(Cards.card_id(world.equipped_catalog["성물"])==new_id and world.option_awakening.relic_subslot_view().active,"different-grade primary and secondary coexist on same720 registry")
	var expected: float=world.card_collections.interval_bonus("fear_resistance:percent",world.hp,world._effective_max_hp())
	check(world._fear_resistance_stat()>=int(expected) and fear_before>0 and expected<fear_before,"actual combat interval reader uses post-primary HP/cap")
	var saved: Dictionary=disk();world._load_game(true);freeze();await frames()
	check(world.hp==int(saved.hp) and world.mp==int(saved.mp) and world.card_collections.interval_bonus("fear_resistance:percent",world.hp,world._effective_max_hp())==expected,"reconnect interval equals the committed primary/secondary/vitals state")
	# Same grade deactivates an already selected extra slot without deleting it.
	await select("성물","source:m508:98:20548");await apply_primary()
	check(not world.option_awakening.relic_subslot_view().active and world.option_awakening.progress[Slot.FIELD]==secondary,"same-grade primary suppresses extra effects but preserves selection")
	await select("성물",secondary);check(not hud.relic_reference_view.secondary_button.disabled,"release stays possible when source conditions deactivate the slot")
	await tap(hud.relic_reference_view.secondary_button)
	check(world.option_awakening.progress[Slot.FIELD]=="","actual UI releases inactive selection")
	check(world.card_draw_fusion.spare==spare_before and world.card_draw_fusion.rng.state==rng_before and world.gold==gold_before,"slot actions preserve copies/acquisition RNG/gold")
	check(ledger_before.owned["성물"]==world.card_draw_fusion.owned["성물"],"no additional relic ownership awarded by slot actions")
	await select("성물",new_id);await apply_primary()
	var skill=world.skill_awakening
	var req: Dictionary=skill.core.book_requirement(new_id)
	var book: Dictionary={}
	for record: Dictionary in world.catalog_db["아이템"]:
		if record.get("source","")=="lineagem_base508" and int(record.get("source_item_class_id",0))==int(req.item_class_id):book=record;break
	check(not book.is_empty(),"exact original physical awakening book definition")
	world.inventory[book.name]=1;world.item_instances["slot-skill-book"]={"name":book.name,"record":book.duplicate(true)}
	world.gold=maxi(world.gold,int(req.fee))
	skill.progress.cards[new_id]={"spell_id":int(skill.core.candidates(new_id)[0].spell_id),"level":20,"experience":"4567"}
	skill._has_cache=false;world._invalidate_equipment_static();world.hp=world._effective_max_hp();world.mp=world._effective_max_mp()
	check(world._save_game(true)==OK,"controlled Lv20 fixture persisted without automatic reset")
	await tap(hud.relic_reference_view.find_child("RelicRegister",true,false))
	var skill_view: Control=hud.workspace.content.find_child("CardSkillAwakeningView",true,false)
	check(skill_view!=null and skill_view.identity==new_id,"new stable relic ID opens existing skill awakening UI")
	if skill_view!=null:
		check(int(req.quantity)==1 and skill_view.current.text.contains("Lv.20"),"existing one-book policy and saved growth are visible")
		var scroll: ScrollContainer=skill_view.get_parent();scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await frames()
		world.equipment_collections.save_blocked=true;before=signature();var selection_before: int=skill.selection_rng.state
		await tap(skill_view.action)
		check(skill_view.current.text.contains("저장 실패"),"actual failed paid UI action executed and reports save failure")
		check(signature()==before and skill.selection_rng.state==selection_before,"failed paid reawakening preserves Lv20, HP/MP, physical book, gold and RNG")
		world.equipment_collections.save_blocked=false;var paid_gold: int=world.gold
		await tap(skill_view.action)
		check(skill.progress.cards[new_id].level==1 and skill.progress.cards[new_id].experience=="0" and not world.item_instances.has("slot-skill-book") and world.gold==paid_gold-int(req.fee),"real skill UI resets Lv1/EXP0 and debits exactly one book plus existing fee")
		check(world.hp<=world._effective_max_hp() and world.mp<=world._effective_max_mp() and int(disk().hp)==world.hp and int(disk().mp)==world.mp,"paid growth reset and cropped HP/MP share saved state")
		check(skill_view.current.text.contains("Lv.1") and skill_view.growth.text.contains("저장 경험치 0"),"actual skill result labels match durable reset")
		await capture("paid-reroll-result")
	print("PATCH523_SLOT_WORLD_UI ",JSON.stringify({"checks":checks,"errors":errors,"scope":"ACTUAL_MAIN_TOUCH_SLOT_SAVE; CONTROLLED_OWNERSHIP_ITEMS; NO_ART_EQUIVALENCE"}))
	world.queue_free();await frames();quit(0 if errors.is_empty() else 1)
