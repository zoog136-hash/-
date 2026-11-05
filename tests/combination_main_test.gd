extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const Fixtures=preload("res://tests/combination_full_contract_test.gd")
const Writer=preload("res://scripts/skills/save_writer.gd")
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("COMBINATION_MAIN_FAIL ",label)
func run() -> void:
	var scene=load("res://Main.tscn")
	var world=scene.instantiate();root.add_child(world);world.set_process(false)
	check(QA.enter_game(world),"normal class selection")
	world.player.set_physics_process(false)
	check(not world.source_save_blocked,"verified current map permits normal save")
	var catalog_path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--catalog="):catalog_path=arg.trim_prefix("--catalog=")
	if catalog_path.is_empty():quit(2);return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	check(world.combinations.accept_catalog(data),"full source catalog on actual World")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(world.combinations.PRIVATE_PATH).get_base_dir())
	check(Writer.write(world.combinations.PRIVATE_PATH,data)==OK,"private catalog persists")
	# Every original combination enters the actual World stat graph, separately.
	var helper_all=Fixtures.new()
	for original: Dictionary in data.combinations:
		Fixtures.fixture(world,original);helper_all.choose_context(world.combinations,original)
		world.combinations.accept_load({"combination523":world.combinations.fresh_state()});world._invalidate_equipment_static()
		var baseline: Dictionary={}
		for kind: String in ["melee","ranged","magic"]:
			baseline[kind+"damage"]=world._catalog_damage_bonus(kind);baseline[kind+"hit"]=world._catalog_accuracy_bonus(kind)
		var next: Dictionary=world.combinations.fresh_state();next.selected_id=int(original.id)
		world.combinations.accept_load({"combination523":next});world._invalidate_equipment_static()
		var live_records: Array=world._all_equipped_records();var live_count: int=0
		for record: Dictionary in live_records:
			if record.get("_combination_bonus",false):live_count+=1
		check(live_count==1,"entire catalog enters actual single-record graph "+str(original.id))
		var active: Dictionary=world.combinations.stat_record()
		for effect: Dictionary in original.effects:
			var kind: String=effect.type;var expected: float=world.combinations.amount(kind,int(effect.target));var observed: float=0
			var field: String=str(preload("res://scripts/combinations/effects.gd").FLAT_FIELDS.get(kind,""))
			if not field.is_empty():observed=float(active.get(field,0))
			match kind:
				"MeleeCritical":observed=world._record_critical_bonus(active,"melee")
				"RangeCritical":observed=world._record_critical_bonus(active,"ranged")
				"DamageReduction":observed=world._record_damage_reduction(active)
				"RangeEvasion":observed=world._record_er(active)
				"MeleeEvasion":observed=world._record_dg(active)
				"AttackSpeedBonus":observed=world._record_attack_speed_percent(active)
				"MoveSpeedBonus":observed=(world._record_move_speed_multiplier(active)-1.0)*100.0
				"ExperienceAdditionPercent":observed=float(active.get("xp",0))*100.0
				"KarmaDeath":observed=world._effective_attribute("DTH")
				"DecreaseChargeStepTime":observed=(1.0-world._skill_motion_duration({"combination_charge_step_seconds":1.0}))*100.0
				"SpecialResistance","HitSpecialResistance":
					var status_name: String={6:"stun",7:"hold",8:"fear"}[int(effect.target)]
					observed=world.call("_record_"+status_name+("_accuracy" if kind=="HitSpecialResistance" else "_resistance"),active)
				"ElementalDamage":
					var monster=preload("res://scripts/monster.gd").new();monster.element_resistance={}
					var element: String={1:"fire",2:"water",3:"wind",4:"earth"}[int(effect.target)]
					observed=world._elemental_damage_to_monster(100,element,monster)-100;monster.free()
				"RegenMP":
					world.hp=1;world.mp=0;world.combinations.tick(float(world.combinations.policy.regen_interval_seconds));observed=world.mp
			check(is_equal_approx(observed,expected),"entire original effect reaches typed live consumer "+str(effect.source_link.ID))
		for kind: String in ["melee","ranged","magic"]:
			var damage_type: String={"melee":"MeleeDamage","ranged":"RangeDamage","magic":""}[kind]
			var hit_type: String={"melee":"MeleeHit","ranged":"RangeHit","magic":"MagicHit"}[kind]
			check(world._catalog_damage_bonus(kind)-int(baseline[kind+"damage"])==int(world.combinations.amount(damage_type)),"actual style damage consumer "+str(original.id)+kind)
			check(world._catalog_accuracy_bonus(kind)-int(baseline[kind+"hit"])==int(world.combinations.amount(hit_type)),"actual style hit consumer "+str(original.id)+kind)
	helper_all.free()
	world.combinations.accept_load({"combination523":world.combinations.fresh_state()})
	var combo: Dictionary=data.combinations[0]
	Fixtures.fixture(world,combo)
	var helper=Fixtures.new();helper.choose_context(world.combinations,combo);helper.free()
	world.combinations.invalidate();world._invalidate_equipment_static()
	check(world.combinations.evaluate(int(combo.id)).ok,"real Main ownership adapter")
	world.gold=1000
	check(world._save_game(true)==OK,"production atomic baseline save")
	world.hud._navigate("combinations")
	await process_frame;await process_frame
	var view=world.hud.find_child("CombinationSelectionView",true,false)
	check(view!=null and view.entries.item_count==62,"ordinary HUD shows all 62 combinations")
	view.chosen=int(combo.id);view.refresh();view.apply_button.pressed.emit()
	await process_frame
	var modal=world.hud.find_child("TwilightConfirmation",true,false)
	check(modal!=null,"selection opens normal confirmation")
	if modal!=null:modal.cancel_button.pressed.emit()
	await process_frame
	check(int(world.combinations.progress.selected_id)==0,"cancel preserves selection")
	var disk: String=FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary) -> Error:return ERR_CANT_CREATE
	var result: Dictionary=world.combinations.request_selection(int(combo.id),0,"main-failed")
	check(not result.ok and int(world.combinations.progress.selected_id)==0 and FileAccess.get_sha256(world.save_path())==disk,"production writer failure preserves live and disk state")
	world.equipment_collections.test_save_writer=Callable()
	view.apply_button.pressed.emit();await process_frame
	modal=world.hud.find_child("TwilightConfirmation",true,false)
	if modal!=null:modal.confirm_button.pressed.emit();modal.confirm_button.pressed.emit()
	await process_frame
	check(int(world.combinations.progress.selected_id)==int(combo.id) and int(world.combinations.progress.revision)==1,"normal confirmation commits once")
	check(world.gold==1000,"default policy does not charge or grant gold")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(int(saved.combination523.selected_id)==int(combo.id),"actual save contains selection")
	var records: Array=world._all_equipped_records();var count: int=0
	for record: Dictionary in records:
		if record.get("_combination_bonus",false):count+=1
	check(count==1,"actual stat graph contains exactly one selected record")
	var outer_scroll: ScrollContainer=world.hud.find_child("CombinationScroll",true,false)
	outer_scroll.ensure_control_visible(view.release_button)
	await process_frame;await process_frame
	check(view.release_button.get_global_rect().intersects(outer_scroll.get_global_rect()),"small-screen action reachable by normal scroll")
	if DisplayServer.get_name()!="headless":
		var touch:=InputEventScreenTouch.new();touch.index=0;touch.position=view.release_button.get_global_rect().get_center();touch.pressed=true;root.push_input(touch,true)
		await process_frame
		touch=InputEventScreenTouch.new();touch.index=0;touch.position=view.release_button.get_global_rect().get_center();touch.pressed=false;root.push_input(touch,true)
		await process_frame
		modal=world.hud.find_child("TwilightConfirmation",true,false)
		check(modal!=null,"real touch opens release confirmation")
		if modal!=null:modal.cancel_button.pressed.emit()
		await process_frame
		check(int(world.combinations.progress.selected_id)==int(combo.id),"touch cancellation keeps selected combination")
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		var capture_path: String="user://combination-main.png"
		check(root.get_texture().get_image().save_png(capture_path)==OK,"actual rendered screenshot")
		print("COMBINATION_CAPTURE ",ProjectSettings.globalize_path(capture_path))
	var source_hash: String=FileAccess.get_sha256(world.save_path())
	world.queue_free();await process_frame
	world=scene.instantiate();root.add_child(world);world.set_process(false);world.player.set_physics_process(false)
	check(int(world.combinations.progress.selected_id)==int(combo.id),"normal Main restart restores selection")
	check(FileAccess.get_sha256(world.save_path())==source_hash,"restart does not rewrite original save")
	check(world.combinations.problem.is_empty(),"restart restores private source catalog")
	var good: String=FileAccess.get_file_as_string(world.save_path())
	var bad: Dictionary=JSON.parse_string(good);bad.combination523.selected_id="broken"
	check(Writer.write(world.save_path(),bad)==OK,"isolated corrupt fixture written")
	var corrupt_hash: String=FileAccess.get_sha256(world.save_path());var before: int=world.gold
	world._load_game(true)
	check(world.combinations.save_blocked and world.gold==before,"corrupt selection rejects before live mutation")
	check(world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==corrupt_hash,"corrupt save is not overwritten")
	check(Writer.write_text(world.save_path(),good)==OK,"isolated good save restored")
	world._load_game(true)
	check(not world.combinations.save_blocked,"valid save recovers")
	world.queue_free();await process_frame
	print("COMBINATION_MAIN ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
