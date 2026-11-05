extends SceneTree
const Core = preload("res://scripts/mastery/mastery523.gd")
const Unit = preload("res://tests/mastery523_effects_repair_test.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MASTERY_EFFECT_MAIN_FAIL: ",label)

func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func _initialize() -> void: call_deferred("run")

func confirm(world, name: String) -> void:
	var button: Button = world.weapon_mastery.view.find_child(name,true,false)
	check(button != null and not button.disabled,"actual enabled UI: "+name)
	if button == null or button.disabled: return
	button.pressed.emit()
	var dialog = world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(dialog != null,"actual confirmation: "+name)
	if dialog != null:
		if name == "MasteryRepair":
			var explicit_repair: bool = false
			for label: Node in dialog.find_children("*","Label",true,false):
				if label.text.contains("자체 복구") and label.text.contains("재추첨하지"): explicit_repair = true
			check(explicit_repair,"actual repair confirmation explains inferred fixed-only recovery and no reroll")
		dialog.confirm_button.pressed.emit()

func capture(world, name: String) -> void:
	var output: String = OS.get_environment("TWILIGHT_MASTERY_CAPTURE_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name+".png") == OK,"actual OpenGL capture: "+name)

func actual_damage(world, mob, kind: String, enabled: bool) -> int:
	world.weapon_mastery.enabled = enabled
	world.rng.seed = 125
	var before: int = mob.hp
	world._deal_successful_player_hit(mob,100,false,kind)
	return before-mob.hp

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world,"요정"),"actual class UI")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	var runtime = world.weapon_mastery
	var path: String = OS.get_environment("TWILIGHT_MASTERY523_PACK")
	check(not path.is_empty() and runtime.core.load_pack(path,FileAccess.get_sha256(path)),"actual private source pack")
	if runtime.core.levels.is_empty(): quit(1); return
	runtime.enabled = true
	for item: Dictionary in world.catalog_db.get("아이템",[]):
		if item.get("type") == "한손검" and item.get("slot") == "weapon": world._equip_or_acquire_item(item); break
	check(world._mastery_actual_weapon_type() == 1,"actual equipped source weapon")
	world.gold = 10000000
	world.inventory[world.CURRENCY_DROP.DIAMOND] = 5000
	var grade: int = int(runtime.core.tables.MasteryGradeView[0].GradeID)
	var legacy: Dictionary = Core.fresh()
	legacy.rng_state = str(runtime.reset_rng.state)
	legacy.legacy_note = {"preserve":true}
	legacy.weapons["1"] = {"points":str(int(runtime.core.levels[1][7].CumulativePoint)),"options":[{"group_id":Unit.group_for(runtime.core,1,1,1),"memo":"fixed peer missing"},{"group_id":Unit.group_for(runtime.core,1,2,1),"memo":"variable peer missing"}],"colors":{"1":[grade,grade,grade,grade],"2":[grade,grade,grade,grade]},"locks":{"1":[false,false,false,false],"2":[true,true,true,true]},"user_note":"preserved"}
	check(world._save_game(true,{Core.SAVE_KEY:legacy}) == OK,"valid partial legacy fixture written through actual Main")
	world._load_game(true)
	check(normalized(runtime.state) == normalized(legacy) and not world.equipment_collections.save_blocked,"actual load preserves valid partial save without implicit repair")
	runtime.show_panel()
	runtime.view.selected_weapon = 1
	runtime.view.refresh()
	var original: Dictionary = runtime.state.duplicate(true)
	var original_sha: String = FileAccess.get_sha256(world.save_path())
	var rng_before: int = runtime.reset_rng.state
	var speed_before: float = world._effective_attack_speed_bonus_percent()
	runtime.balance_config.partial_repair = "preview_only"
	check(not runtime.quote("repair",1).ok and runtime.state == original,"preview-only policy never writes legacy state")
	runtime.balance_config.partial_repair = "fixed_missing_values_only"
	runtime.view.refresh()
	var repair_button: Button = runtime.view.find_child("MasteryRepair",true,false)
	check(repair_button != null and not repair_button.disabled,"fixed-only legacy repair offered in actual HUD")
	repair_button.pressed.emit()
	world.hud.get_node("Root/TwilightConfirmation").dismiss()
	await process_frame
	check(runtime.state == original and FileAccess.get_sha256(world.save_path()) == original_sha,"repair cancel preserves exact old save bytes")
	world.equipment_collections.test_save_writer = func(_p: String,_d: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not runtime.execute("repair",1,0,0,original).ok and runtime.state == original and runtime.reset_rng.state == rng_before and FileAccess.get_sha256(world.save_path()) == original_sha,"failed repair preserves raw bytes partial values and RNG")
	world.equipment_collections.test_save_writer = Callable()
	await capture(world,"partial-before")
	confirm(world,"MasteryRepair")
	var repaired: Dictionary = runtime.core.record(runtime.state,1)
	check(repaired.options.size() == 3 and normalized(repaired.options[0]) == normalized(original.weapons["1"].options[0]) and normalized(repaired.options[1]) == normalized(original.weapons["1"].options[1]),"repair restores only missing fixed option and retains both known option records")
	check(repaired.colors == original.weapons["1"].colors and repaired.locks == original.weapons["1"].locks and repaired.user_note == "preserved" and runtime.state.legacy_note.preserve and runtime.reset_rng.state == rng_before,"actual repair preserves colors locks opaque fields and RNG")
	check(world._effective_attack_speed_bonus_percent()-speed_before == 1,"fixed missing source attack speed reaches actual consumer as one percent")
	check(FileAccess.get_sha256(world.save_path()+".pre-mastery-repair-"+original_sha) == original_sha,"exact pre-repair save backup is durable")
	check(not runtime.quote("repair",1).ok,"unknown variable missing value cannot be repaired or rerolled into existence")
	var reset: Dictionary = runtime.quote("reset",1)
	check(reset.ok and reset.frozen_levels == [2] and int(reset.charge.LockSlotCount) == 0 and int(reset.charge.CurrencyID) == 1,"partial-level locks are preserved outside explicit complete-level reset scope")
	var gold_before: int = world.gold
	confirm(world,"MasteryReset")
	var after: Dictionary = runtime.core.record(runtime.state,1)
	check(world.gold == gold_before-int(reset.charge.Cost) and after.colors["2"] == repaired.colors["2"] and after.locks["2"] == repaired.locks["2"] and normalized(after.options[1]) == normalized(repaired.options[1]),"actual scoped reroll pays original scoped fee and never changes unknown partial level")
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	var malformed: Dictionary = good.duplicate(true)
	malformed[Core.SAVE_KEY].weapons["1"].colors["2"].pop_back()
	check(Writer.write(world.save_path(),malformed) == OK,"malformed fixture written only to isolated test profile")
	var corrupt_sha: String = FileAccess.get_sha256(world.save_path())
	world._load_game(true)
	check(world.equipment_collections.save_blocked and not runtime.quote("repair",1).ok and world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == corrupt_sha,"malformed load keeps overwrite protection; repair never bypasses it")
	check(Writer.write(world.save_path(),good) == OK,"restore known-good isolated test save")
	world._load_game(true)
	check(not world.equipment_collections.save_blocked,"accepted original state clears protection")
	# Separate controlled ownership fixture tests every source combat consumer;
	# these source groups are not gameplay grants and never enter normal saves.
	var all_owned: Dictionary = Core.fresh()
	all_owned.weapons["1"] = Unit.owned(runtime.core,1)
	check(world._save_game(true,{Core.SAVE_KEY:all_owned}) == OK,"combat source fixture saved through production validator")
	world._load_game(true)
	var expected_melee: int = 0
	var expected_flat: int = 0
	var expected_pvp: int = 0
	for bonus: Dictionary in runtime.core.active_options(runtime.state,1):
		if bonus.type_name in ["MeleeDamage","PVPMeleeAdditionDamage"]: expected_melee += int(bonus.Value)
		if bonus.type_name == "PVPMeleeAdditionDamage": expected_pvp += int(bonus.Value)
		if bonus.type_name in ["PierceDamageReduction","PiercePVPDamageReduction"]: expected_flat += int(bonus.Value)
	runtime.enabled = false
	var melee_base: int = world._catalog_damage_bonus("melee")
	var ranged_base: int = world._catalog_damage_bonus("ranged")
	runtime.enabled = true
	check(expected_pvp > 0 and world._catalog_damage_bonus("melee")-melee_base == expected_melee+expected_flat,"actual style damage API includes PvP->PvE and native flat damage once")
	check(world._catalog_damage_bonus("ranged")-ranged_base == expected_flat and runtime.catalog_bonus("damage_reduction_ignore",1) == expected_flat,"actual generic reduction-ignore consumer includes both original flat types once without style leakage")
	var mob = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(mob)
	mob.setup({"name":"숙련 피해 검증","hp":9999999,"ac":0},world.player,world,null)
	mob.set_physics_process(false)
	world.active_skill_buffs.clear()
	world._invalidate_equipment_static()
	world._refresh_equipment_effects()
	var existing_amp: float = float(world.equipment_effects.damage_amp_pct)
	var stolen: int = 1 if world._has_hp_absorption() else 0
	world.rng.seed = 125
	var outgoing: int = world.original_skills.outgoing_damage(100)
	var expected_base: int = world.original_skills.target_damage(maxi(1,int(round(outgoing*(1.0+clampf(existing_amp,0,300)/100.0)))),mob)+stolen
	var expected_with: int = world.original_skills.target_damage(maxi(1,int(round(outgoing*(1.0+clampf(existing_amp+1.0,0,300)/100.0)))),mob)+stolen
	var melee_hit_base: int = actual_damage(world,mob,"melee",false)
	var melee_hit: int = actual_damage(world,mob,"melee",true)
	check(melee_hit_base == expected_base,"actual hit preserves existing equipment amplification lifesteal and target modifier order")
	check(runtime.damage_amplification("melee",1) == 1 and melee_hit == expected_with,"actual damage event adds raw10000 as one percentage point with existing cap and rounding")
	var ranged_hit_base: int = actual_damage(world,mob,"ranged",false)
	check(actual_damage(world,mob,"ranged",true) == ranged_hit_base,"melee percent ignore never amplifies ranged damage event")
	var magic_hit_base: int = actual_damage(world,mob,"magic",false)
	check(actual_damage(world,mob,"magic",true) == magic_hit_base,"melee percent ignore never amplifies magic damage event")
	var magic_skill: Dictionary = world.original_skills.catalog.record_for("에너지 볼트")
	check(not magic_skill.is_empty() and str(magic_skill.get("attack_type","")) == "magic","actual current skill catalog resolves magic attack kind")
	world.feedback_kind = "melee"
	runtime.enabled = false
	world.rng.seed = 313
	var before_spell: int = mob.hp
	world.original_skills.deal_damage(magic_skill,mob)
	var base_spell: int = before_spell-mob.hp
	runtime.enabled = true
	world.rng.seed = 313
	before_spell = mob.hp
	world.original_skills.deal_damage(magic_skill,mob)
	check(before_spell-mob.hp == base_spell,"actual skill-service API forwards magic kind even when ambient feedback is melee")
	runtime.balance_config.typed_percent_ignore = "display_only"
	check(actual_damage(world,mob,"melee",true) == melee_hit_base and runtime.catalog_bonus("damage_reduction_ignore",1) == expected_flat,"display-only setting disables only inferred percentage damage")
	runtime.balance_config.typed_percent_ignore = "style_amplifier"
	runtime.view.refresh()
	var notes: Dictionary = {"pvp":false,"flat":false,"percent":false}
	for label: Node in runtime.view.body.get_children():
		if not label is Label: continue
		if label.text.contains("PvP→PvE"): notes.pvp = true
		if label.text.contains("추가 피해 적용"): notes.flat = true
		if label.text.contains("자체 적용"): notes.percent = true
	check(notes.pvp and notes.flat and notes.percent,"actual UI distinguishes established PvE/flat adapters from custom percentage behavior")
	await capture(world,"combat-effects")
	var saved: Dictionary = runtime.state.duplicate(true)
	world._load_game(true)
	check(normalized(runtime.state) == normalized(saved) and runtime.damage_amplification("melee",1) == 1,"reload restores owned source effects without duplicate bonuses or source edits")
	print("MASTERY_EFFECT_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source":"actual523"}))
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
