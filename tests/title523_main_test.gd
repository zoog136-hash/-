extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Writer=preload("res://scripts/skills/save_writer.gd")
var checks:=0
var failures: Array[String]=[]
var world
var evidence:=OS.get_environment("TWILIGHT_TITLE523_EVIDENCE")
var writer_failures:=0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("TITLE523_MAIN_FAIL ",label)
func frames(count: int=3) -> void:
	for i: int in count: await process_frame
func view(): return world.hud.workspace.find_child("Title523View",true,false)
func tap(button: Control, scroll: ScrollContainer=null) -> void:
	if button==null: check(false,"missing control"); return
	if scroll!=null: scroll.ensure_control_visible(button); await frames()
	var position: Vector2=button.get_global_transform_with_canvas()*(button.size/2.0)
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=position; event.pressed=pressed; button.get_viewport().push_input(event,true)
	await frames()
func shot(name: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(name+".png"))==OK,"viewport capture "+name)
func data() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))

func run() -> void:
	root.size=Vector2i(1280,720)
	root.gui_embed_subwindows=true
	world=load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer=-100000
	check(QA.enter_game(world),"real Main class confirmation")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	await frames(5)
	check(world.field_map!=null and world.active_map_id=="aden_world","real current source map")
	if "--verify-missing" in OS.get_cmdline_user_args():
		var preserved:=FileAccess.get_sha256(world.save_path())
		check(world.titles.blocked and not world.titles.source.problem.is_empty(),"new process rejects owned title with actual installed ZIP absent")
		check(world.titles.state.achieved.is_empty(),"missing source rejects before owned title mutation")
		check(world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==preserved,"missing source keeps exact original save bytes")
		await finish(); return
	if "--verify-reload" in OS.get_cmdline_user_args():
		check(world.titles.state.achieved==[8],"fresh process owned stage restored")
		check(world.titles.source.problem.is_empty(),"fresh process installed source SHA validated")
		check(world.inventory.get("상급 축복의 가루 · 원본#117544",0)==100,"fresh process material deduction persisted")
		check(world.gold==174321 and world.titles.display_name()!="","fresh process wallet and highest title")
		check(world.titles.powder_count()==100,"fresh process source definition registered before inventory load")
		var material: String=world.titles.source.powder_record.name
		var old_hash:=FileAccess.get_sha256(world.save_path())
		world._warehouse_transfer(material,1,"deposit","")
		check(world.inventory[material]==100 and not world.warehouse.stacks.has(material) and FileAccess.get_sha256(world.save_path())==old_hash,"native no-storage restriction preserves inventory and disk")
		await finish(); return
	world.hud.toggle_menu(); await frames()
	await tap(world.hud.menu_page.find_child("MenuTile_titles",true,false),world.hud.menu_scroll_view)
	check(world.hud.active_section=="titles" and view()!=null,"real menu pointer enters titles")
	if view()==null: await finish(); return
	await tap(view().find_child("InstallTitle523",true,false),view())
	var dialog: FileDialog=null
	for child: Node in view().get_children():
		if child is FileDialog: dialog=child
	check(dialog!=null,"source install chooser opens")
	if dialog!=null: dialog.file_selected.emit(OS.get_environment("TWILIGHT_TITLE523_ZIP")); await frames()
	check(world.titles.source.problem.is_empty(),"real install handler pins original ZIP")
	var t=world.titles
	var key: String=t.source.powder_record.name
	check(t.source.stages.size()==25 and t.source.quests.size()==128 and t.source.powder_drop_rows.size()==178,"Main complete rule sets")
	world.level=85; world.gold=174321
	world.inventory[key]=2100 # isolated ownership fixture, never production grant
	var before_quests: Dictionary=world.quest_service.export_state().duplicate(true)
	check(world._save_game(true)==OK,"actual baseline atomic save")
	var baseline_sha:=FileAccess.get_sha256(world.save_path())
	var before_title: String=JSON.stringify(t.state)
	await tap(view().find_child("ReviewTitleDonation",true,false),view())
	check(view().confirm.visible,"donation confirmation visible")
	await tap(view().confirm_cancel,view())
	check(not view().confirm.visible,"donation popup canceled by pointer")
	check(world.inventory[key]==2100 and JSON.stringify(t.state)==before_title and FileAccess.get_sha256(world.save_path())==baseline_sha,"pointer cancel preserves ownership state disk")
	world.equipment_collections.test_save_writer=func(_path: String,_payload: Dictionary) -> Error:
		writer_failures+=1
		return ERR_CANT_CREATE
	await tap(view().find_child("ReviewTitleDonation",true,false),view())
	await tap(view().confirm_ok,view())
	check(not view().confirm.visible and view().outcome.text.contains("저장 실패"),"actual failed-write result shown and popup closes")
	check(writer_failures==1,"actual writer failure reached, not earlier rejection")
	check(world.inventory[key]==2100 and JSON.stringify(t.state)==before_title and FileAccess.get_sha256(world.save_path())==baseline_sha,"actual UI writer failure preserves RNG wallet title bytes")
	world.equipment_collections.test_save_writer=Callable()
	# Exercise dedicated trial from the same normal UI; completion fixture is
	# one away from the source amount, then actual player damage/death dispatch.
	await tap(view().find_child("StartTitleTrial",true,false),view())
	check(not t.state.active.is_empty(),"actual trial UI starts one selected target")
	if t.state.active.is_empty():
		printerr("TITLE523_START_DETAIL ",view().outcome.text)
		await finish(); return
	var q: Dictionary=t.source.quests[int(t.state.active.quest)]
	t.state.active.count=int(q.amount)-1
	var actor: TwilightMonster=null
	for candidate: Node in world.monsters_root.get_children():
		if candidate is TwilightMonster and not candidate.dead: actor=candidate; break
	check(actor!=null,"real pooled actor available")
	if actor!=null:
		actor.source_m_npc_id=int(q.targets[0]); actor.source_m_original=t.source.trial_npcs[actor.source_m_npc_id].duplicate(true)
		actor.hp=1
		world._deal_successful_player_hit(actor,999999,false,"melee")
		check(int(t.state.active.count)==int(q.amount),"actual successful hit/death counts one exact native last hit")
		world._on_monster_died(actor)
		check(int(t.state.active.count)==int(q.amount),"pooled duplicate death does not count twice")
	check(t.state.achieved.is_empty(),"normal target completion grants eligibility only")
	await tap(view().find_child("ReviewTitleQuest",true,false),view())
	check(view().confirm.visible,"normal review confirmation")
	await tap(view().confirm_cancel,view())
	check(int(t.state.attempts)==0,"normal review cancel consumes no daily attempt")
	await shot("title-trial-eligible")
	# Stable fixture seed selects a success at unchanged production odds.
	var draw:=RandomNumberGenerator.new()
	for seed_value: int in range(1,10000):
		draw.seed=seed_value; var initial:=str(draw.state)
		if draw.randi_range(0,9999999)<1500000: t.state.rng=initial; break
	await tap(view().find_child("ReviewTitleDonation",true,false),view())
	await tap(view().confirm_ok,view())
	check(t.state.achieved==[8] and world.inventory[key]==100,"actual UI donation deducts2000 and grants one stage")
	check(int(t.state.attempts)==0 and t.state.active.is_empty(),"donation success clears old stage trial without normal count")
	check(t.bonus("ArmorClass")==-2 and t.bonus("MagicResist")==2,"owned source benefits")
	var ac: int=world._effective_ac(); var mr: int=world._effective_mr()
	var owned: Dictionary=t.state.duplicate(true)
	t.state.achieved=[]
	check(world._effective_ac()==ac+2 and world._effective_mr()==mr-2,"real Main AC and MR consumers")
	t.state=owned
	await tap(view().find_child("ToggleTitleDisplay",true,false),view())
	check(not world.title_badge.text.is_empty() and world.title_badge.visible,"highest title actual actor badge")
	check(world.quest_service.export_state().get("claimed",[])==before_quests.get("claimed",[]) and world.quest_service.quests.size()==10,"existing instant quest ownership and all10 definitions preserved")
	var durable: Dictionary=data()
	check(int(durable.inventory[key])==100 and durable.title523.achieved.size()==1 and int(durable.title523.achieved[0])==8,"real save includes same ownership transaction")
	await shot("title-achieved")
	var durable_sha:=FileAccess.get_sha256(world.save_path())
	var durable_gold: int=world.gold
	var malformed:=data(); malformed.title523.achieved=[18]
	check(Writer.write(world.save_path(),malformed)==OK,"isolated corrupt title fixture")
	var corrupt_sha:=FileAccess.get_sha256(world.save_path())
	world._load_game(true)
	check(t.blocked and world.gold==durable_gold and t.state.achieved==[8],"malformed title load rejects before live mutation")
	check(world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==corrupt_sha,"rejected load preserves bytes")
	malformed.title523=owned.duplicate(true); malformed.title523.display=true
	check(Writer.write(world.save_path(),malformed)==OK,"restore valid isolated save")
	world._load_game(true)
	check(not t.blocked and t.state.achieved==[8] and t.display_name()!="","valid reload restores title state")
	# Supply path: use exact immutable native provider record as a labelled
	# fixture actor, then the real roll -> floor -> visibility delay -> pickup.
	var supplier_id:=int(t.source.powder_npcs.keys()[0])
	for candidate: Node in world.monsters_root.get_children():
		if candidate is TwilightMonster and not candidate.dead: actor=candidate; break
	if actor!=null:
		actor.source_m_npc_id=supplier_id; actor.source_m_original=t.source.powder_npcs[supplier_id].duplicate(true)
		actor.global_position=world.player.global_position
		var previous_chance: float=t.policy.powder_drop_percent; t.policy.powder_drop_percent=100.0
		world._roll_drop(actor,true); t.policy.powder_drop_percent=previous_chance
		var drop: Button=null
		for id: String in world.ground_loot.records:
			if world.ground_loot.records[id].item_name==key: drop=world.ground_loot.views.get(id)
		check(drop!=null and world.inventory[key]==100,"actual powder supplier rolls to floor; no instant grant")
		if drop!=null:
			world.player.global_position=drop.global_position
			await create_timer(0.9).timeout
			check(world._collect_ground_drop(drop) and world.inventory[key]==101,"actual visible floor proximity pickup")
			world.inventory[key]=100 # restore fixture stock for new-process assertion
	world.gold=174321
	check(world._save_game(true)==OK,"final real save for new process")
	# Real consumers for the later stages, without claiming natural progression.
	t.state.achieved=[]
	for stage: Dictionary in t.source.stages: t.state.achieved.append(int(stage.id))
	check(world._equipment_accuracy_bonus("melee")>=4 and t.pve_pierce()==5,"all stage accuracy and pierce consumer")
	check(t.incoming(100,"melee",0.0)==50 and t.outgoing(100,0.0)==205,"explicit advanced combat policies")
	t.restore(data()); world._update_hud()
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(854,480); world.hud.open_titles523(); await frames(8)
		check(view()!=null and view().size.x<=854,"small screen title layout")
		await shot("title-small-854")
	await finish()

func finish() -> void:
	print("TITLE523_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"fixtures":"isolated ownership/native actor/threshold/RNG; no claim of natural all-map supply or full-thousands-kills gameplay"}))
	world.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
