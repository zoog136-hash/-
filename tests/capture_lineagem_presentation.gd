extends SceneTree
## Real Main presentation capture. Test-only encounter placement, unmodified records.
const QA = preload("res://tests/qa_class_selection.gd")
const POSITIONS = preload("res://tests/active_source_test_positions.gd")
var world: TwilightWorld
var folder: String
var seconds: float = 0.0
var failures: Array[String] = []
var events: Array = []
var photos: Array = []
var strikes: int = 0
var hits: int = 0
var kills: int = 0
var target: TwilightMonster
var landing: Vector2
var prior_inventory: Dictionary
var hp_damage_events: int = 0
var last_hp: int = 0
var started_usec: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); print("PRESENTATION_FAIL ",message)
func event(kind: String, detail: Dictionary = {}) -> void:
	detail["event"] = kind; detail["seconds"] = seconds
	events.append(detail); print("PRESENTATION_EVENT ",JSON.stringify(detail))
func step(duration: float) -> void:
	for tick: int in range(ceili(duration*60.0)):
		await physics_frame
		seconds += 1.0/60.0
		if world.hp < last_hp:
			hp_damage_events += 1
			event("player_damage",{"before":last_hp,"after":world.hp})
		last_hp = world.hp
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture.save_png(folder.path_join(label+".png"))==OK,"capture "+label)
	photos.append(label+".png")
func strike(_id: int) -> void: strikes += 1
func damaged(_actor: TwilightMonster, _damage: int, _kind: String) -> void: hits += 1
func died(actor: TwilightMonster) -> void:
	kills += 1
	world.player.set_auto_enabled(false)
	event("death",{"name":actor.monster_name,"ground_drops":world.ground_loot.records.size()})
func spawn(name_value: String) -> TwilightMonster:
	for record: Dictionary in world.monster_db:
		if str(record.name)!=name_value: continue
		var actor: TwilightMonster = world.MONSTER_SCENE.instantiate()
		world.monsters_root.add_child(actor)
		actor.global_position=landing+Vector2(40,0)
		actor.setup(record,world.player,world,world._monster_texture(record))
		actor.set_meta("size_class",world._monster_size_class(record))
		actor.died.connect(world._on_monster_died)
		actor.died.connect(died)
		actor.player_hit.connect(world._on_player_hit)
		actor.player_hit.connect(damaged)
		actor.selected.connect(world._select_monster)
		event("encounter",{"name":actor.monster_name,"hp":actor.hp,"attack":actor.attack_power,"position":str(actor.global_position),"record_unchanged":true})
		return actor
	return null
func run() -> void:
	started_usec=Time.get_ticks_usec()
	folder=OS.get_environment("TWILIGHT_CAPTURE_DIR")
	if folder.is_empty(): folder="/tmp/lineagem-presentation"
	DirAccess.make_dir_recursive_absolute(folder)
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world),"actual class selection")
	world.save_timer=-10000.0
	world.rng.seed=20261025
	world.player.set_auto_enabled(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	landing=POSITIONS.combat(world,[Vector2(40,0),Vector2(-30,0)],20)
	check(landing.is_finite(),"existing clear nonsafe terrain")
	if not landing.is_finite(): await finish(); return
	world.player.global_position=landing
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	world.player.attack_strike.connect(strike)
	prior_inventory=world.inventory.duplicate(true)
	last_hp=world.hp
	event("fixture",{"map":world.active_map_id,"seed":20261025,"position":str(landing),"paused_background_count":world.monsters_root.get_child_count(),"fixture":"Three unchanged existing monster records placed consecutively in clear existing terrain; background AI paused; no gameplay resource changes; not a performance benchmark"})
	await step(3.0)
	await capture("00-idle")
	Input.action_press("move_left")
	await step(.1)
	Input.action_release("move_left")
	check(world.player.global_position.distance_to(landing)>5,"real movement input")
	await capture("01-move")
	for monster_name: String in ["고스트","버그베어","드레이크"]:
		target=spawn(monster_name)
		check(is_instance_valid(target),"existing record "+monster_name)
		if not is_instance_valid(target): continue
		world._select_monster(target)
		await step(.25)
		if monster_name=="고스트":
			var cast: bool=world._cast_job_skill("에너지 볼트")
			check(cast,"actual starter energy bolt cast")
			event("skill",{"name":"에너지 볼트","accepted":cast})
			await step(.2)
			await capture("02-energy-bolt")
		if monster_name=="드레이크":
			await step(5.0)
			await capture("04-boss-hit")
		world.player.set_auto_enabled(false)
		world.player.set_click_path(world.find_world_path(world.player.global_position,target.global_position),target.global_position)
		var approach_deadline: float=seconds+3.0
		while not world._target_in_current_weapon_range(target) and seconds<approach_deadline: await step(.05)
		world.player.clear_click_path()
		check(world._target_in_current_weapon_range(target),"path reached range "+monster_name)
		var deadline: float=seconds+15.0
		while is_instance_valid(target) and not target.dead and seconds<deadline:
			if not world._target_in_current_weapon_range(target):
				world.player.set_click_path(world.find_world_path(world.player.global_position,target.global_position),target.global_position)
			else:
				world.player.clear_click_path()
			world.hud.attack_pressed.emit()
			await step(.25)
			if not photos.has("03-normal-combat.png") and strikes>0: await capture("03-normal-combat")
		if is_instance_valid(target): event("combat_end",{"name":monster_name,"hp":target.hp,"strikes":strikes,"player":str(world.player.global_position),"monster":str(target.global_position)})
		check(not is_instance_valid(target) or target.dead,"combat killed "+monster_name)
		world.player.set_auto_enabled(false)
		world.player.clear_click_path()
		await step(2.0)
	await capture("05-floor-drops")
	await step(2.0)
	var earned: Array=world.ground_loot.snapshot()
	check(not earned.is_empty(),"earned ground drops")
	if not earned.is_empty():
		var item: Dictionary=earned[0]
		var count_before: int=int(world.inventory.get(str(item.item_name),0))
		var view: Button=world.ground_loot.views[str(item.id)]
		view.pressed.emit()
		await step(.2)
		await capture("06-selected-loot")
		world.loot_pickup.pickup_button.pressed.emit()
		var deadline: float=seconds+4.0
		while world.ground_loot.records.has(str(item.id)) and seconds<deadline: await step(.1)
		check(not world.ground_loot.records.has(str(item.id)),"manual pickup removed ground record")
		check(int(world.inventory.get(str(item.item_name),0))==count_before+int(item.quantity),"manual pickup grants earned quantity")
		event("pickup",{"name":item.item_name,"quantity":item.quantity,"inventory_before":count_before,"inventory_after":world.inventory.get(str(item.item_name),0)})
	world.hud.toggle_inventory()
	await step(.5)
	await capture("07-inventory")
	if seconds<32.0: await step(32.0-seconds)
	check(strikes>0,"actual attack strikes")
	check(hits>0,"actual monster attack events")
	check(hp_damage_events>0,"actual player HP loss")
	check(kills==3,"two normal species and boss killed")
	await finish()
func finish() -> void:
	Input.action_release("move_left")
	var report: Dictionary={"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"seconds":seconds,"events":events,"captures":photos,"strikes":strikes,"monster_hit_events":hits,"player_hp_loss_events":hp_damage_events,"kills":kills,"failures":failures,"performance_measurement":false,"android_device":false,"wall_seconds":float(Time.get_ticks_usec()-started_usec)/1000000.0,"physics_ticks_per_second":Engine.physics_ticks_per_second,"capture_note":"MovieWriter fixed-fps output is simulation-time evidence, not device performance; requested movie FPS logged in invocation"}
	var file:=FileAccess.open(folder.path_join("scene.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	world.queue_free();await process_frame
	print("LINEAGEM_SCENE_OK" if failures.is_empty() else "LINEAGEM_SCENE_FAILED")
	quit(0 if failures.is_empty() else 1)
