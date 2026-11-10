extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var checks: int=0
var world
var rt
var travel
var evidence: String=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);print("SYMBOL_TRAVEL_FAIL "+message)
func frames() -> void:
	for i: int in range(3):await process_frame
func tap(control: Control, point: Vector2=Vector2.INF) -> void:
	if control==null:check(false,"missing native control");return
	if point==Vector2.INF:point=control.size/2
	for down: bool in [true,false]:
		var event=InputEventScreenTouch.new();event.index=84;event.pressed=down;event.position=control.get_global_transform_with_canvas()*point;root.push_input(event,true)
	await frames()
func screen():return world.hud.workspace.find_child("SymbolTravelView",true,false)
func capture(label: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"viewport capture "+label)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="):evidence=arg.trim_prefix("--evidence=")
	if not evidence.is_empty():DirAccess.make_dir_recursive_absolute(evidence)
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world,"마법사"),"actual wizard class confirmation")
	if world.field_map == null:
		# Remembered locations need a walkable map: only the installed 523 pack
		# provides one (pre-November maps were removed).
		print("SYMBOL_TRAVEL_NOT_RUN: no map without the installed 523 pack")
		print("SYMBOL_TRAVEL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"map":"not_installed"}))
		world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1);return
	world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false);world.player.set_auto_enabled(false)
	for mob: TwilightMonster in world.monsters_root.get_children():mob.set_physics_process(false)
	rt=world.growth;travel=rt.travel
	rt.restore(rt.empty_state());check(not travel.enabled(),"no native control without ownership")
	travel.open();await frames();screen().label_input.text="처음 위치"
	if DisplayServer.get_name()!="headless":await tap(screen().find_child("SymbolRemember",true,false))
	else:screen().show_result(travel.remember("처음 위치",int(rt.state.revision)))
	check(screen().result.text.contains("기억했습니다"),"native registration remembers real traversable field location")
	check(travel.marks().size()==1,"first mark committed")
	var origin: Vector2=world.player.global_position
	var request: Dictionary={"kind":"scroll","name":"순간이동 주문서"}
	check(not travel.quote(0,request,world.active_map_id,int(rt.state.revision)).ok,"locked symbol cannot use saved destination")
	var fixture: Dictionary=rt.state.duplicate(true)
	fixture.emblems["eva"]={"stage":30,"attempts":10,"spent":0,"guaranteed":false,"absolute":0,"absolute_grades":[1,2]}
	rt.restore(fixture);world.inventory["축복의 열쇠"]=1000
	for grade: int in [3,4,5]:
		var unlocked: Dictionary=rt.execute("absolute","eva",grade,int(rt.state.revision))
		check(unlocked.ok,"Eva reachable tier "+str(grade)+" · "+str(unlocked.message))
	if not travel.enabled():
		print("SYMBOL_TRAVEL_SETUP ",rt.validate(rt.state)," ",world.source_save_blocked," ",world.player.global_position)
		world.queue_free();await process_frame;quit(1);return
	check(travel.enabled() and rt.bonus("potion_flat:flat")==30 and rt.bonus("potion_percent:percent")==30,"full Eva source rewards now reachable")
	world.inventory["순간이동 주문서"]=3
	var destination: Vector2=world.field_map.random_landing(world.rng,origin)
	check(destination.is_finite() and world.field_map.point_clear(destination,4),"real current source-map second location")
	world.player.global_position=destination
	check(travel.remember("다음 위치",int(rt.state.revision)).ok,"remember second source-map point")
	var revision: int=int(rt.state.revision)
	check(not travel.quote(0,request,"other_map",revision).ok,"stale origin map rejected")
	check(not travel.quote(0,request,world.active_map_id,revision-1).ok,"stale revision rejected")
	var valid: Dictionary=rt.state.duplicate(true)
	rt.state.teleport_bookmarks[0].layout_key="stale"
	check(not travel.quote(0,request,world.active_map_id,revision).ok,"changed terrain revision rejected")
	rt.restore(valid);revision=int(rt.state.revision)
	rt.state.teleport_bookmarks[0].map_id="another_map"
	check(not travel.quote(0,request,world.active_map_id,revision).ok,"cross-map admission not bypassed")
	rt.restore(valid)
	rt.state.teleport_bookmarks[0].position=[100000000,100000000]
	check(not travel.quote(0,request,world.active_map_id,revision).ok,"blocked or out-of-field remembered coordinate rejected")
	rt.restore(valid)
	world.player.apply_stun(1)
	check(not travel.quote(0,request,world.active_map_id,revision).ok,"stun rechecked at confirmation")
	world.player.clear_status_effects()
	check(world._save_game(true)==OK,"baseline real atomic save")
	var sha: String=FileAccess.get_sha256(world.save_path())
	var before: Dictionary=rt.state.duplicate(true);var inv: Dictionary=world.inventory.duplicate(true);var ids: Dictionary=world.item_instances.duplicate(true)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary) -> Error:return ERR_CANT_CREATE
	check(not travel.travel(0,request,world.active_map_id,revision).ok,"failed scroll save rejected")
	check(world.player.global_position==destination and world.inventory==inv and rt.state==before and world.item_instances==ids and FileAccess.get_sha256(world.save_path())==sha,"failed move preserves position, scrolls, physical IDs, growth and file bytes")
	check(not travel.remember("저장 실패",revision).ok and travel.marks().size()==2,"failed bookmark write leaves list intact")
	world.equipment_collections.test_save_writer=Callable()
	world.active_skill_buffs["Travel retained"]={"remaining":20.0,"speed":1.1}
	world._use_quick_item("순간이동 주문서");await frames()
	check(screen()!=null and world.inventory["순간이동 주문서"]==3 and world.player.global_position==destination,"real quick-item opens picker before any cost or movement")
	if DisplayServer.get_name()!="headless":
		await tap(screen().listing,screen().listing.get_item_rect(0).get_center())
	else:screen().select(0)
	check(not screen().confirm.disabled,"selected valid remembered location enables confirmation")
	await capture("symbol523-remembered-choice-1280x720")
	if DisplayServer.get_name()!="headless":await tap(screen().confirm)
	else:screen().commit()
	check(world.player.global_position.is_equal_approx(origin) and world.inventory["순간이동 주문서"]==2,"native confirmation moves to exact remembered point and spends one scroll")
	check(world.active_skill_buffs.has("Travel retained"),"travel does not clear unrelated skill buffs")
	check(screen().result.text.contains("순간이동했습니다") and screen().confirm.disabled,"result visible and repeat click cannot spend")
	await capture("symbol523-remembered-result-1280x720")
	var state: Dictionary=rt.state.duplicate(true)
	world._load_game(true);world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	check(travel.marks().size()==2 and world.player.global_position.is_equal_approx(origin) and world.inventory["순간이동 주문서"]==2,"real save/reload preserves marks, destination and exact consumption")
	check(rt.state.get("teleport_bookmarks",[])==state.teleport_bookmarks,"bookmark fields survive JSON round trip")
	var record: Dictionary=world.original_skills.catalog.record_for("텔레포트")
	# Restore the isolated buff fixture after the normal loader prunes unknown skills.
	world.active_skill_buffs["Travel retained"]={"remaining":20.0,"speed":1.1}
	world.mp=world._effective_max_mp();world.hp=world._effective_max_hp();world.skill_cooldowns.clear();world.skill_global_cooldown=0
	check(not record.is_empty() and world.original_skills.ready(record),"real learned common teleport is ready")
	var resolved: Dictionary=world.original_skills.catalog.resolve(record)
	var spell: Dictionary={"kind":"original","id":str(record.id)}
	var mana_before: int=world.mp
	world.mp=0
	check(not travel.quote(1,spell,world.active_map_id,int(rt.state.revision)).ok,"selected spell still requires mana")
	world.mp=mana_before
	check(not world.original_skills.cast(record) and screen()!=null and world.mp==mana_before,"real spell opens choice without early MP or cooldown")
	check(world._save_game(true)==OK,"pre-spell save")
	sha=FileAccess.get_sha256(world.save_path());before=rt.state.duplicate(true);inv=world.inventory.duplicate(true)
	var cd: Dictionary=world.skill_cooldowns.duplicate(true)
	world.active_skill_buffs["Travel stealth"]={"remaining":20.0,"stealth":true}
	var buffs: Dictionary=world.active_skill_buffs.duplicate(true)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary) -> Error:return ERR_CANT_CREATE
	check(not travel.travel(1,spell,world.active_map_id,int(rt.state.revision)).ok,"spell failed write rejected")
	check(world.mp==mana_before and world.skill_cooldowns==cd and world.inventory==inv and rt.state==before and world.active_skill_buffs==buffs and FileAccess.get_sha256(world.save_path())==sha,"failed spell write preserves MP, cooldown, items, buffs, growth and file")
	world.equipment_collections.test_save_writer=Callable()
	check(travel.travel(1,spell,world.active_map_id,int(rt.state.revision)).ok,"actual spell travel commits")
	check(world.player.global_position.is_equal_approx(destination) and world.mp==mana_before-int(resolved.get("mp",0)),"selected spell preserves existing mana cost and destination")
	check(float(world.skill_cooldowns.get(str(resolved.name),-1))>=0,"selected spell retains cooldown consumer")
	check(world.inventory["순간이동 주문서"]==2,"spell does not consume a scroll")
	var saved_spell: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(not world.active_skill_buffs.has("Travel stealth") and not saved_spell.active_skill_buffs.has("Travel stealth") and world.active_skill_buffs.has("Travel retained"),"spell reveals stealth in live and saved state while retaining unrelated buffs")
	check(not travel.quote(0,spell,world.active_map_id,int(rt.state.revision)).ok,"spell cooldown prevents immediate reuse")
	var invalid: Dictionary=rt.state.duplicate(true);invalid.teleport_bookmarks[0].position=["invalid",1]
	check(not rt.validate(invalid).is_empty(),"malformed bookmark save rejected")
	invalid=rt.state.duplicate(true);invalid.teleport_bookmarks=[]
	for i: int in range(int(travel.POLICY.bookmark_limit)+1):invalid.teleport_bookmarks.append(travel.marks()[0])
	check(not rt.validate(invalid).is_empty(),"configured bookmark capacity enforced at load")
	screen().refresh();screen().select(0);await frames()
	if DisplayServer.get_name()!="headless":await tap(screen().find_child("SymbolForget",true,false))
	else:screen().show_result(travel.forget(0,int(rt.state.revision)))
	check(travel.marks().size()==1,"native delete commits exact selected mark · "+screen().result.text)
	if DisplayServer.get_name()!="headless":
		world._use_quick_item("순간이동 주문서");await frames();root.size=Vector2i(854,480);await frames()
		await capture("symbol523-remembered-854x480")
		await tap(screen().find_child("SymbolTravelCancel",true,false))
		check(world.inventory["순간이동 주문서"]==2,"native cancellation spends nothing")
	print("SYMBOL_TRAVEL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
