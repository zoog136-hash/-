extends SceneTree
## Run explicitly with the separately held523 pack and current-map pack.
## This exercises production UI signals, Main combat, and isolated real saves.
const QA = preload("res://tests/qa_class_selection.gd")
const POSITIONS = preload("res://tests/active_source_test_positions.gd")
const CLOCK = preload("res://tests/combat_test_clock.gd")
const SOURCE523 = preload("res://scripts/skills/player_skills523.gd")
var checks: int = 0
var failures: Array[String] = []
var world: TwilightWorld
var dummy: TwilightMonster
var captures: String = ""

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SKILLS523_LIVE_FAIL ",label)

func reset_cast() -> void:
	world._clear_combat_actions()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown=0
	world.mp=999
	world.hp=world._effective_max_hp()
	world.player.stun_remaining=0
	world.player.fear_remaining=0
	world.player.silence_remaining=0

func select_skill(id: String) -> Control:
	world.hud.open_skills()
	# Let the production window's deferred navigation restoration finish before
	# selecting, as a user does after the window appears.
	for _frame: int in range(2): await process_frame
	var view: Control = world.hud.skills_view
	for index: int in range(view.filtered.size()):
		if str(view.filtered[index].id)==id:
			view.cards.select(index)
			view.select(index)
			view._process(.2)
			var tabs: HBoxContainer = view.find_child("BrowserCompactTabs",true,false)
			if tabs != null: (tabs.get_child(1) as Button).pressed.emit()
			for _frame: int in range(2): await process_frame
			return view
	check(false,"UI contains "+id)
	return view

func capture(label: String, size: Vector2i) -> void:
	if captures.is_empty(): return
	DisplayServer.window_set_size(size)
	root.size=size
	root.content_scale_size=size
	for _frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var path := captures.path_join(label+"-"+str(size.x)+"x"+str(size.y)+".png")
	var actual_image := root.get_texture().get_image()
	check(actual_image.get_size()==size,"actual render resolution "+label)
	check(actual_image.save_png(path)==OK,"actual OpenGL screenshot "+label)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-captures="): captures=arg.get_slice("=",1)
	if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
	world=(load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer=-100000
	check(QA.enter_game(world,"마법사"),"actual mage class confirmation")
	world.level=90
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	# Keep the controlled combat target stable while screenshots yield frames.
	# Population/AI coverage is separate from this skill transaction/UI fixture.
	if is_instance_valid(world.field_population): world.field_population.set_process(false)
	var service := world.original_skills
	var catalog := service.catalog
	var adapter = catalog.source523
	check(adapter.profiles.size()==440 and not adapter.active_sha256.is_empty(),"actual private523 pack consumed in Main")
	if adapter.profiles.is_empty():
		world.queue_free(); quit(2); return
	var original_state := catalog.export_state()
	var original_inventory: Dictionary = world.inventory.duplicate(true)
	var original_equipment: Dictionary = world.equipped_items.duplicate(true)
	var original_collections: Dictionary = world.equipment_collections.export_state().duplicate(true)
	check(world._save_game(true)==OK,"real source-enabled save")
	var path: String=world.save_path()
	var saved_sha: String=FileAccess.get_sha256(path)
	var revision: int=adapter.revision
	check(not adapter.load_pack("user://missing523.json","0".repeat(64)),"missing replacement rejected")
	check(adapter.revision==revision and adapter.profiles.size()==440,"failed load preserves active pack")
	check(FileAccess.get_sha256(path)==saved_sha and catalog.export_state()==original_state and world.inventory==original_inventory and world.equipped_items==original_equipment and world.equipment_collections.export_state()==original_collections,"pack replacement cannot mutate save/progression/equipment/collections")
	var arena: Vector2=POSITIONS.combat(world,[Vector2(24,0)])
	check(arena.is_finite(),"combat lane on actual current source map")
	if not arena.is_finite(): world.queue_free();quit(1);return
	world.player.global_position=arena
	dummy=(load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"523 실제 전투 검사", "hp":100000,"lv":1,"ac":0,"mr":0,"atk":1},world.player,world,null)
	dummy.global_position=arena+Vector2(24,0)
	dummy.set_physics_process(false)
	world.selected_monster=dummy
	world.gold=100000000
	reset_cast()
	var silence_id := "lm_7b6bd6ce56189fbc"
	var view := await select_skill(silence_id)
	check(view.get_node_or_null("PlayerSkills523Status")!=null,"real skill screen exposes active523 status")
	check(view.detail.text.contains("마력의 돌 1개") and view.detail.text.contains("20 / 0"),"real skill detail renders source costs/material")
	check(not view.book_button.disabled,"existing UI book purchase available")
	view.book_button.pressed.emit()
	view=await select_skill(silence_id)
	check(not view.learn_button.disabled,"existing UI learning available")
	view.learn_button.pressed.emit()
	check(catalog.owned(catalog.record_for(silence_id)),"learned through actual UI")
	world.inventory["마력의 돌"]=0
	view=await select_skill(silence_id)
	check(view.use_button.disabled and view.use_button.tooltip_text.contains("마력의 돌"),"material shortfall disables actual use button with reason")
	var mana: int=world.mp
	var random_state: int=world.rng.state
	check(not world._cast_job_skill(silence_id),"real cast rejects material shortfall")
	check(world.mp==mana and world.rng.state==random_state and world.skill_cooldowns.is_empty(),"failed cast costs no MP/RNG/cooldown")
	world.inventory["마력의 돌"]=3
	view=await select_skill(silence_id)
	check(not view.use_button.disabled,"source material enables actual UI cast")
	check(view.detail.is_visible_in_tree() and view.use_button.is_visible_in_tree(),"source cost and use control visible in actual detail tab")
	await capture("silence-ready",Vector2i(1280,720))
	view.use_button.pressed.emit()
	check(world.mp==mana-20 and int(world.inventory["마력의 돌"])==2,"UI cast pays523 MP/material exactly once")
	var pending_target: Variant = world.pending_attack.get("target")
	check(pending_target is WeakRef and pending_target.get_ref()==dummy,"actual UI cast retains controlled selected target")
	check(world.pending_attack.has("original_skill") and world.pending_attack.original_skill.duration_bounds==[16.0,16.0],"real queued cast carries confirmed source status seconds")
	CLOCK.settle(world)
	check(world.mp==mana-20 and int(world.inventory["마력의 돌"])==2,"marker/projectile does not charge twice")
	reset_cast()
	world.selected_monster=dummy
	world._on_quickslot_assignment_requested(0,"skill",silence_id)
	world._on_quickslot_pressed(0)
	check(world.mp==979 and int(world.inventory["마력의 돌"])==1,"existing quickslot uses same source cost path")
	CLOCK.settle(world)
	reset_cast()
	world.inventory["마력의 돌"]=0
	world.inventory["마력의 돌 (각인)"]=2
	world._on_quickslot_pressed(0)
	check(world.mp==979 and int(world.inventory["마력의 돌 (각인)"])==1 and int(world.inventory["마력의 돌"])==0,"real catalog marked material works through same quickslot")
	CLOCK.settle(world)
	reset_cast()
	var invisibility_id := "lm_19edb16ff7370abe"
	catalog.learned[invisibility_id]=1
	world.inventory["마력의 돌"]=2
	world.inventory["마력의 돌 (각인)"]=2
	check(not world._cast_job_skill(invisibility_id) and world.mp==999 and int(world.inventory["마력의 돌"])==2 and int(world.inventory["마력의 돌 (각인)"])==2,"split material shortfall is atomic")
	world.inventory["마력의 돌 (각인)"]=3
	check(world._cast_job_skill(invisibility_id) and world.mp==984 and int(world.inventory["마력의 돌"])==0 and int(world.inventory["마력의 돌 (각인)"])==0,"source five-material cost can consume verified legacy and catalog stacks exactly once")
	reset_cast()
	var slow_id := "lm_f5125fc718ebf071"
	catalog.learned[slow_id]=1
	view=await select_skill(slow_id)
	check(view.detail.text.contains("다른 플레이어") and view.detail.text.contains("미지원"),"actual UI explains523 PC-only boundary")
	check(view.detail.text.contains("45 / 0"),"blocked UI distinguishes native cost from old host balance")
	check(view.use_button.disabled and view.quick_button.disabled,"source PC-only cast and new quickslot blocked in UI")
	check(view.detail.is_visible_in_tree() and view.selection_sheet.title.text=="슬로우","actual visible screen shows PC-only selected skill")
	check(not world._cast_job_skill(slow_id) and world.mp==999 and world.skill_cooldowns.is_empty(),"Main cannot apply source PC slow to NPC")
	check(not service.auto_wants(catalog.record_for(slow_id),dummy),"AUTO also respects native PC-only filter")
	await capture("slow-blocked",Vector2i(960,540))
	# HP costs, buff timer and existing own stats stay distinct.
	reset_cast()
	var weight_id := "lm_1ec7e7edbce9ac29"
	catalog.learned[weight_id]=1
	var hp_before: int=world.hp
	check(world._cast_job_skill(weight_id),"real self buff uses source HP/MP cost")
	check(world.hp==hp_before-50 and world.mp==989,"source HP and MP charged once")
	check(is_equal_approx(float(world.active_skill_buffs.get("디크리즈 웨이트",{}).get("remaining",0)),1800.0),"source seconds reach live buff timer")
	var state_before:=catalog.export_state()
	check(world._save_game(true)==OK,"source-enabled skills save via existing atomic writer")
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(payload.original_skill_state==JSON.parse_string(JSON.stringify(state_before)),"existing learned/save IDs preserved")
	check(not payload.has("source523") and not payload.has("player_skills523"),"private source configuration stays out of player saves")
	world.queue_free()
	await process_frame
	print("SKILLS523_LIVE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"map_scope":"actual current source map","render_scope":"OpenGL" if not captures.is_empty() else "headless"}))
	quit(0 if failures.is_empty() else 1)
