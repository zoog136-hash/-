extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Writer=preload("res://scripts/skills/save_writer.gd")
var world
var rt
var travel
var checks: int=0
var failures: Array[String]=[]
var evidence: String=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("SYMBOL_CROSS_FAIL "+label)
func freeze() -> void:
	world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false)
	for mob: TwilightMonster in world.monsters_root.get_children():mob.set_physics_process(false)
func frames() -> void:
	for i: int in range(3):await process_frame
func screen():return world.hud.workspace.find_child("SymbolTravelView",true,false)
func tap(control: Control,point: Vector2=Vector2.INF) -> void:
	if point==Vector2.INF:point=control.size/2
	for down: bool in [true,false]:
		var event=InputEventScreenTouch.new();event.index=87;event.pressed=down;event.position=control.get_global_transform_with_canvas()*point;root.push_input(event,true)
	await frames()
func capture(label: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"actual cross-map viewport "+label)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):evidence=arg.trim_prefix("--evidence=")
	if not evidence.is_empty():DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world);check(QA.enter_game(world,"마법사"),"actual character entry");freeze()
	rt=world.growth;travel=rt.travel
	var fixture: Dictionary=rt.empty_state()
	fixture.emblems["eva"]={"stage":30,"attempts":10,"spent":0,"guaranteed":false,"absolute":0,"absolute_grades":[1,2,3]}
	rt.restore(fixture);world._invalidate_equipment_static();world.gold=10000;world.inventory["순간이동 주문서"]=3
	var aden: Vector2=world.player.global_position
	check(travel.remember("아덴 기억",int(rt.state.revision)).ok,"remember exact visited Aden location")
	world._npc_teleport_requested("oman_01");freeze()
	check(world.active_map_id=="oman_01" and world.gold==8500,"existing NPC admission loads verified Oman1 before charging1500")
	if world.active_map_id!="oman_01":world.queue_free();await process_frame;quit(1);return
	var oman: Vector2=world.player.global_position
	check(world.field_map.point_clear(oman,4),"actual Oman entry traversable")
	check(travel.remember("오만 기억",int(rt.state.revision)).ok,"remember actual visited Oman world coordinate without M-coordinate inference")
	var old_path: String=world.save_path();var old_sha: String=FileAccess.get_sha256(old_path)
	var offer: Dictionary=travel.quote(0,{"kind":"scroll","name":"순간이동 주문서"},world.active_map_id,int(rt.state.revision))
	check(offer.ok and int(offer.landing.gold)==0,"existing Aden entry policy reused")
	var moved: Dictionary=travel.travel(0,{"kind":"scroll","name":"순간이동 주문서"},world.active_map_id,int(rt.state.revision));freeze()
	check(moved.ok,"cross-map candidate activates · "+str(moved.message))
	check(world.active_map_id=="aden_world" and world.player.global_position.is_equal_approx(aden) and world.inventory["순간이동 주문서"]==2 and world.gold==8500,"exact saved Aden position, one scroll and unchanged zero-fee wallet")
	check(FileAccess.get_sha256(old_path)==old_sha and FileAccess.file_exists(old_path+".pre-source-map-"+old_sha),"pre-travel source and SHA-verified backup preserved")
	check(world.save_path()!=old_path and world.MAP_SAVE_MIGRATION.resolve(world.base_save_path()).path==world.save_path(),"verified candidate selected by existing active-file pointer")
	var ids: Dictionary=world.item_instances.duplicate(true)
	var revision: int=int(rt.state.revision)
	world.level=1;check(not travel.quote(1,{"kind":"scroll","name":"순간이동 주문서"},world.active_map_id,revision).ok,"existing destination level limit preserved");world.level=35
	world.gold=10;check(not travel.quote(1,{"kind":"scroll","name":"순간이동 주문서"},world.active_map_id,revision).ok,"existing destination wallet limit preserved");world.gold=8500
	var candidate_source: String=world.save_path()
	world._save_game(true)
	var before_sha: String=FileAccess.get_sha256(candidate_source)
	world.equipment_collections.test_save_writer=func(path: String,data: Dictionary) -> Error:
		return Writer.write(path,data) if path==candidate_source else ERR_CANT_CREATE
	var failed: Dictionary=travel.travel(1,{"kind":"scroll","name":"瞬間移動"},world.active_map_id,revision)
	check(not failed.ok,"unrecognized scroll refused")
	failed=travel.travel(1,{"kind":"scroll","name":"순간이동 주문서"},world.active_map_id,revision)
	check(not failed.ok and world.active_map_id=="aden_world" and world.inventory["순간이동 주문서"]==2 and world.gold==8500 and world.item_instances==ids and FileAccess.get_sha256(candidate_source)==before_sha,"candidate write failure preserves live world, physical IDs, currency and source bytes")
	world.equipment_collections.test_save_writer=Callable()
	# Force active-pointer publication failure after a successful target load.
	var blocked_temp: String=world.base_save_path()+".source-map-current.json.tmp"
	check(DirAccess.make_dir_absolute(blocked_temp)==OK,"isolate pointer-publication failure")
	failed=travel.travel(1,{"kind":"scroll","name":"순간이동 주문서"},world.active_map_id,revision);freeze()
	check(not failed.ok and world.active_map_id=="aden_world" and world.player.global_position.is_equal_approx(aden) and world.inventory["순간이동 주문서"]==2 and world.gold==8500,"activation failure reloads complete pre-travel checkpoint without charging")
	failed=travel.travel(1,{"kind":"scroll","name":"순간이동 주문서"},world.active_map_id,revision);freeze()
	check(not failed.ok and world.active_map_id=="aden_world" and world.inventory["순간이동 주문서"]==2 and world.gold==8500,"repeated activation failure reuses verified candidate without duplicate costs")
	check(DirAccess.remove_absolute(blocked_temp)==OK,"remove injected pointer block")
	world._use_quick_item("순간이동 주문서");await frames()
	if DisplayServer.get_name()!="headless":await tap(screen().listing,screen().listing.get_item_rect(1).get_center())
	else:screen().select(1)
	check(not screen().confirm.disabled and screen().detail.text.contains("1500 아데나"),"native remembered destination displays inherited NPC price")
	await capture("symbol523-crossmap-confirm-1280x720")
	if DisplayServer.get_name()!="headless":await tap(screen().confirm)
	else:screen().commit()
	freeze()
	check(world.active_map_id=="oman_01" and world.player.global_position.is_equal_approx(oman) and world.inventory["순간이동 주문서"]==1 and world.gold==7000,"native confirmation commits exact remembered Oman position, one scroll and1500 gold once")
	check(int(rt.state.economy.get("travel_gold_spent",0))==1500,"travel gold ledger stays separate from point refund")
	await capture("symbol523-crossmap-result-1280x720")
	world._load_game(true);freeze()
	check(world.active_map_id=="oman_01" and world.player.global_position.is_equal_approx(oman) and travel.marks().size()==2 and world.inventory["순간이동 주문서"]==1 and world.gold==7000,"real reload resumes activated destination without duplicate fees or items")
	var record: Dictionary=world.original_skills.catalog.record_for("텔레포트")
	world.mp=world._effective_max_mp();world.skill_cooldowns.clear();world.skill_global_cooldown=0
	check(not record.is_empty() and world.original_skills.ready(record),"existing common teleport ready for cross-map choice")
	var skill: Dictionary=world.original_skills.catalog.resolve(record)
	var mana: int=world.mp
	check(not world.original_skills.cast(record) and screen()!=null and world.mp==mana,"real cross-map spell opens picker before consumption")
	await frames()
	if DisplayServer.get_name()!="headless":await tap(screen().listing,screen().listing.get_item_rect(0).get_center())
	else:screen().select(0)
	check(not screen().confirm.disabled and screen().detail.text.contains("MP"),"native cross-map spell shows existing MP cost")
	if DisplayServer.get_name()!="headless":await tap(screen().confirm)
	else:screen().commit()
	freeze()
	check(world.active_map_id=="aden_world" and world.player.global_position.is_equal_approx(aden) and world.mp==mana-int(skill.mp) and world.inventory["순간이동 주문서"]==1 and world.gold==7000,"cross-map spell spends exact existing MP and no scroll or extra gold")
	world._load_game(true);freeze()
	check(world.active_map_id=="aden_world" and world.mp==mana-int(skill.mp) and world.inventory["순간이동 주문서"]==1 and world.gold==7000,"cross-map spell save reload has no duplicate consumption")
	print("SYMBOL_CROSS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
