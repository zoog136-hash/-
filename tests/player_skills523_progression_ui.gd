extends "res://tests/player_skills523_progression_live.gd"
## Focused final UI check: per-shot price, explicit manual toggle, precise settings.
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source523-captures="):captures=arg.get_slice("=",1)
	if not captures.is_empty():DirAccess.make_dir_recursive_absolute(captures)
	world=(load("res://Main.tscn") as PackedScene).instantiate();root.add_child(world)
	check(QA.enter_game(world,"요정"),"actual Main elf entry");freeze();world.gold=100000000
	arena=POSITIONS.combat(world,[Vector2(24,0)])
	check(arena.is_finite(),"actual map firing floor")
	if not arena.is_finite():world.queue_free();quit(2);return
	dummy=(load("res://scenes/Monster.tscn") as PackedScene).instantiate();world.monsters_root.add_child(dummy)
	dummy.setup({"name":"반복 발사 표시 검증","hp":100000,"lv":1,"ac":0,"mr":0,"atk":1},world.player,world,null);dummy.set_physics_process(false)
	enter("요정","활");world.inventory["화살"]=30
	var view:=await learn_ui(IDS.triple)
	check(view.selection_sheet.info_text.contains("반복 발사 MP / HP") and view.selection_sheet.info_text.contains("15 / 0") and view.selection_sheet.info_text.contains("화살 3개"),"compact card shows actual per-shot native cost rather than only free toggle")
	check(view.quick_button.text=="퀵슬롯 · 수동 전환","quickslot control clearly separates manual toggle from AUTO")
	world.mp=world._effective_max_mp();var mp_before: int=world.mp
	view.use_button.pressed.emit();world.auto_attack_timer=0;world._attack();CLOCK.settle(world)
	check(world.mp==mp_before-15 and int(world.inventory["화살"])==27,"actual UI ON and normal-shot contact use displayed payment")
	view=await select_skill(IDS.triple)
	check(view.use_button.text.begins_with("OFF"),"actual state button remains usable during firing cooldown")
	await capture("triple-per-shot-cost",Vector2i(960,540))
	world.hud.open_settings_info(true)
	for _frame: int in range(3):await process_frame
	var panel: Control=world.hud.workspace.find_child("SkillProgression523Settings",true,false)
	panel.selector.select(8);panel.selector.item_selected.emit(8)
	var cast_time: SpinBox=panel.find_child("Progression523_cast_time",true,false)
	check(is_equal_approx(cast_time.value,.42),"settings display precise host cast time without rounding default to .4")
	var scroll: ScrollContainer=world.hud.workspace.find_child("SettingsScroll",true,false)
	for _frame: int in range(2):await process_frame
	scroll.scroll_vertical=int(panel.position.y)
	await capture("precise-host-settings",Vector2i(1280,720))
	world.queue_free();await process_frame
	print("SKILLS523_PROGRESSION_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
