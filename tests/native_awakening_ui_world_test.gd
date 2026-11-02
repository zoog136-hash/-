extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var errors: Array[String]=[]
var checks: int=0
var folder: String=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func settle() -> void:
	for frame: int in range(8):await process_frame
func capture(name_value: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name_value+".png")==OK,"capture "+name_value)
func touch(point: Vector2,index: int,pressed: bool) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=pressed;root.push_input(event,true)
func run() -> void:
	var private_root: String=""
	var effect_manifest: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--private-ui-root="):private_root=arg.trim_prefix("--private-ui-root=")
		if arg.begins_with("--capture-dir="):folder=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--effect-manifest="):effect_manifest=arg.trim_prefix("--effect-manifest=")
	if folder.is_empty() or private_root.is_empty():push_error("Explicit private UI root/capture dir required");quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var installer: Script=load("res://scripts/lineagem_pack_install.gd");installer._session_root=private_root
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);await settle()
	check(QA.enter_game(world),"class selection")
	world.save_timer=-10000;world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
	var hud: Node=world.hud;hud.process_mode=Node.PROCESS_MODE_ALWAYS
	var card: Dictionary={};var hero: Dictionary={}
	for record: Dictionary in world.catalog_db["변신"]:
		if Cards.card_id(record)=="source:m508:1:4":card=record
		if Cards.card_id(record)=="source:m508:1:85":hero=record
	check(not card.is_empty() and not hero.is_empty(),"exact native card fixtures")
	if card.is_empty():world.queue_free();quit(1);return
	var identity: String=Cards.card_id(card);var hero_id: String=Cards.card_id(hero)
	world.card_draw_fusion.owned["변신"][identity]=true
	world.card_draw_fusion.owned["변신"][hero_id]=true
	world.card_draw_fusion.spare["변신"][identity]=100
	world.equipped_catalog["변신"]=card
	world._invalidate_equipment_static()
	var base_hp: int=world._effective_max_hp()
	var state: Dictionary=world.skill_awakening.core.fresh_state()
	state.cards[identity]={"spell_id":64224,"level":1,"experience":"1234"}
	check(world.skill_awakening.accept_load({"card_skill_awakening":state}),"load verified source skill state fixture")
	check(world._effective_max_hp()==base_hp+300 and world._effective_max_hp()==base_hp+300,"actual World HP consumer gets source300 exactly once")
	world.equipped_catalog["변신"]={};world._invalidate_equipment_static()
	check(world._effective_max_hp()==base_hp,"actual unequip removes skill HP")
	world.equipped_catalog["변신"]=card;world._invalidate_equipment_static()
	check(world.option_awakening.view("변신",hero_id).ok,"existing option UI receives direct native target")
	var before: int=hash([world.inventory,world.item_instances,world.equipped_catalog,world.card_draw_fusion.export_state(),world.gold,world.skill_awakening.export_state(),world.option_awakening.export_state(),world.rng.state])
	world._update_hud()
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent;DisplayServer.window_set_size(extent)
		hud.open_catalog("변신");await settle()
		for index: int in range(hud.catalog_results.size()):
			if Cards.card_id(hud.catalog_results[index])==identity:hud._select_catalog_index(index);break
		hud._set_catalog_detail_view(true);await settle()
		var button: Button=hud.companion_detail_view.footer_actions.find_child("CompanionQuickRegister",true,false)
		check(button.text=="스킬 각성" and not button.disabled,"existing card footer routes to skill awakening")
		var point: Vector2=button.get_global_transform_with_canvas()*(button.size*.5)
		touch(point,0,true);await process_frame;touch(point,0,false);await settle()
		var view: Control=hud.workspace.content.find_child("CardSkillAwakeningView",true,false)
		check(view!=null and view.identity==identity,"skill UI keeps exact sourceID")
		if view==null:continue
		check(view.candidates.item_count==5 and view.candidates.get_item_metadata(0)==64224,"source skill candidates retain IDs")
		check(view.action.disabled and view.stats.text.contains("HP +300"),"unconfirmed cost button disabled with source HP profile")
		var source_target: Control=view.find_child("SkillAwakeningTargetArt",true,false)
		check(source_target.layers.size()==3 and source_target.portrait!=null,"source CSB target ring/plus/book slot use installed exact atlas images")
		check(view.action.get_meta("source_csb_node","")=="UI/Change/Change_Awaken_Skill.csb:Btn_Production" and view.action.custom_minimum_size.y>=44,"exact source awakening button retains adequate adaptive touch size")
		var owner_scroll: ScrollContainer=view.get_parent()
		var second: Vector2=view.candidates.get_global_transform_with_canvas()*view.candidates.get_item_rect(1).get_center()
		if second.y>owner_scroll.get_global_rect().end.y-12:
			owner_scroll.scroll_vertical+=ceili(second.y-owner_scroll.get_global_rect().end.y+20);await settle()
			second=view.candidates.get_global_transform_with_canvas()*view.candidates.get_item_rect(1).get_center()
		touch(second,1,true);await process_frame;touch(second,1,false);await settle()
		check(view.candidates.get_selected_items()==PackedInt32Array([1]) and view.effect.text.contains(str(view.snapshot.candidates[1].name)),"native candidate touch selects source details")
		check(view.current.text.contains("파이어 볼트"),"candidate browsing never changes saved selected skill")
		owner_scroll.scroll_vertical=0;await settle()
		await capture("skill-awakening-%dx%d" % [extent.x,extent.y])
		var scroll: ScrollContainer=view.get_parent()
		scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await settle()
		check(scroll.get_global_rect().grow(2).intersects(view.action.get_global_rect()),"blocked action remains reachable by scroll")
		await capture("source-skill-action-%dx%d" % [extent.x,extent.y])
		view.level.select(19);view.level.item_selected.emit(19);await settle()
		check(world.skill_awakening.export_state()==state and world._effective_max_hp()==base_hp+300,"level20 preview never changes saved level or live HP")
		var denied: Dictionary=world.skill_awakening.request_operation(identity,{identity:100})
		check(not denied.ok and denied.code=="source_cost_rules_unresolved","programmatic unpriced skill operation also blocked")
		hud._close_workspace();hud.open_catalog("변신");await settle()
		check(world.skill_awakening.export_state()==state,"reopen preserves source skill experience")
	for category: String in ["마법인형","성물"]:
		hud.open_catalog(category);await settle()
		var chosen_index: int=-1
		for index: int in range(hud.catalog_results.size()):
			if world.skill_awakening.core.eligibility(Cards.card_id(hud.catalog_results[index])).ok:chosen_index=index;break
		if chosen_index<0:
			for record: Dictionary in world.catalog_db[category]:
				if world.skill_awakening.core.eligibility(Cards.card_id(record)).ok:
					hud.catalog_search.text=str(record.sourceId);hud._refresh_catalog_list(str(record.sourceId));await settle();chosen_index=0;break
		check(chosen_index>=0,"source skill target exists "+category)
		if chosen_index<0:continue
		hud._select_catalog_index(chosen_index);await settle()
		var target_id: String=Cards.card_id(hud.selected_catalog_record)
		var button: Button=hud.companion_detail_view.footer_actions.find_child("CompanionQuickRegister",true,false) if category=="마법인형" else hud.relic_reference_view.find_child("RelicRegister",true,false)
		check(button!=null and not button.disabled,"native skill entry enabled "+category)
		button.pressed.emit();await settle()
		var view: Control=hud.workspace.content.find_child("CardSkillAwakeningView",true,false)
		check(view!=null and view.identity==target_id and view.action.disabled,"read-only native skill route "+category)
		await capture("skill-awakening-"+category)
	hud.set_option_awakening_view(world.option_awakening.view("변신",hero_id));await settle()
	check(hud.option_awakening_view.snapshot.target_id==hero_id and hud.option_awakening_view._target_art.texture!=null,"native option target uses original private card image")
	await capture("native-option-awakening")
	check(hash([world.inventory,world.item_instances,world.equipped_catalog,world.card_draw_fusion.export_state(),world.gold,world.skill_awakening.export_state(),world.option_awakening.export_state(),world.rng.state])==before,"UI navigation consumes no resources or RNG and preserves both awakening ledgers")
	# Real production Monster life/death/reset, isolated from field loot callbacks.
	var victim: Node=load("res://scenes/Monster.tscn").instantiate();world.monsters_root.add_child(victim)
	var record: Dictionary={"name":"QA lifecycle fixture","hp":30,"lv":1}
	victim.setup(record,world.player,world,null);victim.set_physics_process(false)
	world.equipped_catalog["변신"]=card
	var cooldowns: Dictionary=world.skill_cooldowns.duplicate(true)
	world.skill_cooldowns.clear()
	if not effect_manifest.is_empty():
		world.player.original_source_manifest=effect_manifest;world.player.motion.facing8=5
	var probe:=RandomNumberGenerator.new();var hit_seed: int=0
	for seed_value: int in range(1,10000):
		probe.seed=seed_value
		if probe.randi_range(0,9999)<100:hit_seed=seed_value;break
	world.rng.seed=hit_seed;world.skill_awakening.on_successful_hit(victim);victim.set_physics_process(false)
	check(victim.dead and victim.hp==0 and victim.damage_hit_count==1,"real Monster receives exactly one lethal source skill hit")
	if not effect_manifest.is_empty():check(world.skill_awakening.source_vfx.last_result.status=="played","actual equipped skill proc dispatches both original1583/218 pixel stages on lethal hit")
	var post_hit_rng: int=world.rng.state;var life: int=victim.life_id
	world.skill_awakening.on_successful_hit(victim)
	check(victim.damage_hit_count==1 and world.rng.state==post_hit_rng,"dead real Monster cannot consume another proc roll")
	victim.retire_for_pool();record.hp=100;victim.setup(record,world.player,world,null);victim.set_physics_process(false)
	check(victim.life_id==life+1 and not victim.dead and victim.hp==100 and victim.damage_hit_count==0,"production pool retirement/setup creates clean new Monster life")
	world.skill_awakening.on_successful_hit(victim)
	check(victim.hp==100 and world.rng.state==post_hit_rng,"pooled new life cannot bypass source per-card cooldown")
	world.skill_cooldowns.clear();world.equipped_catalog["변신"]={};world.skill_awakening.on_successful_hit(victim)
	check(victim.hp==100 and world.rng.state==post_hit_rng,"unequipped real World skill cannot damage reused Monster")
	world.equipped_catalog["변신"]=card;world.rng.seed=hit_seed
	world.skill_awakening.on_successful_hit(victim)
	check(victim.hp==30 and victim.damage_hit_count==1,"new actual hit damages reused Monster once without stale life callback")
	world.skill_cooldowns=cooldowns;victim.queue_free()
	var file: FileAccess=FileAccess.open(folder+"/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"errors":errors,"state":"isolated XDG and in-memory native ownership/skill fixture; private map guard unchanged"}));file.close()
	print("NATIVE_AWAKENING_UI_WORLD ",JSON.stringify({"checks":checks,"errors":errors}))
	hud._close_workspace();await settle();world.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
