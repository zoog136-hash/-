extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var checks := 0
var failures: Array[String] = []

class PackProbe extends RefCounted:
	var context: Dictionary
	func geographic_contract() -> Dictionary: return context

class FieldProbe extends PlayableField:
	var source_pack: RefCounted
	func actor_contract(_actor: Node2D) -> Dictionary: return {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("TOTEM_PROGRESSION_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func seed_for_stage(runtime: RefCounted, id: int, level: int, win: bool, zero_xp: bool = false) -> int:
	var stage: Dictionary = runtime.level_preview(id,level)
	var probe := RandomNumberGenerator.new()
	for seed_value in range(1,50000):
		probe.seed = seed_value
		if (probe.randi_range(0,999999) < int(stage.level.Probability)) != win: continue
		if not zero_xp: return seed_value
		var found_zero := false
		for pool: Array in stage.option_pools.values():
			var roll: int = probe.randi_range(0,999999)
			for candidate: Dictionary in pool:
				roll -= int(candidate.source.Probability)
				if roll < 0:
					if candidate.bonus.type.Name == "ExperienceAdditionPercent" and candidate.bonus.bonus.Value == 0: found_zero = true
					break
		if found_zero: return seed_value
	return -1

func seed_for_proc(pattern: Array) -> int:
	var probe := RandomNumberGenerator.new()
	for seed_value in range(1,100000):
		probe.seed = seed_value
		var matches := true
		for expected: bool in pattern:
			if (probe.randi_range(0,999999) < 5000) != expected: matches = false
		if matches: return seed_value
	return -1

func run() -> void:
	if OS.get_environment("TWILIGHT_TOTEM_PACK").is_empty():
		print("TOTEM_PROGRESSION SKIP: private 523 pack required")
		quit(0)
		return
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main class confirmation")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.original_population.set_process(false)
	for actor in world.monsters_root.get_children(): actor.set_physics_process(false)
	world.con_stat = 100 # Explicit test inventory capacity, never a production grant.
	world.gold = 100000000
	world.inventory["축복 부여 주문서"] = 13
	for id in [301664,301674,301684]: world.inventory[world._catalog_item_from_source_id(str(id)).name] = 80
	for id in [347164,347174,347184]: world.inventory[world._catalog_item_from_source_id(str(id)).name] = 10
	for id in [301634,301644,301654]: world.inventory[world._catalog_item_from_source_id(str(id)).name] = 60
	for id in [3581,65291]:
		var item: Dictionary = world._catalog_item_from_source_id(str(id))
		check(not item.is_empty() and item.name != "축복 부여 주문서","source material identity stays distinct from local scroll")
		world.inventory[item.name] = 12
	var reset_name := str(world._catalog_item_from_source_id("301694").name)
	world.inventory[reset_name] = 4
	world.totems.state = {}
	for id in [4,14,24]: world.totems.state[str(id)] = {"active":true,"kills":3000,"level":0,"selected":{}}
	world._invalidate_equipment_static()
	check(world._save_game(true) == OK,"fixture committed through actual writer")
	var baseline_ac: int = world._effective_ac()
	var baseline_mr: int = world._effective_mr()
	var baseline_xp: float = world._experience_multiplier()
	world.hud.open_totems()
	var button: Button = world.hud.totem_view.find_child("TotemUpgrade_4_301664",true,false)
	check(button != null and not button.disabled,"actual growth button usable")
	var stone_name := str(world._catalog_item_from_source_id("301664").name)
	var engraved_name := str(world._catalog_item_from_source_id("347164").name)
	var stones_before := int(world.inventory[stone_name])
	world.rng.seed = seed_for_stage(world.totems,4,1,true)
	button.pressed.emit()
	check(world.totems.progress(4).level == 1 and world.inventory[stone_name] == stones_before-1,"screen spends only selected stone and advances target row")
	check(world.hud.message_label.text.contains("강화 성공"),"growth success result displayed")
	var revision: int = world.totems.revision
	button.pressed.emit()
	check(world.totems.revision == revision and world.inventory[stone_name] == stones_before-1,"stale screen callback cannot repeat transaction")
	check(world._effective_ac() == baseline_ac-1,"source ArmorClass applies to actual AC once")
	var prior: Dictionary = world.totems.export_state()
	var engraved_before := int(world.inventory[engraved_name])
	world.rng.seed = seed_for_stage(world.totems,4,2,false)
	var failed: Dictionary = world.totem_actions.execute("upgrade",4,347164,world.totems.revision)
	check(failed.ok and not failed.success and world.inventory[engraved_name] == engraved_before-2,"failed growth consumes exactly chosen engraved material")
	check(world.hud.message_label.text.contains("강화 실패"),"growth failure result displayed")
	check(world.totems.progress(4) == prior.totems["4"],"failed growth preserves level and prior selections")
	check(not world.totem_actions.execute("upgrade",4,301674,world.totems.revision).ok,"wrong region material rejected")
	world.ui_preferences["item_locks"][stone_name] = true
	check(not world.totem_actions.quote("upgrade",4,301664,world.totems.revision).ok,"locked growth material rejected")
	world.ui_preferences.item_locks.erase(stone_name)
	var inventory_before := world.inventory.duplicate(true)
	var state_before: Dictionary = world.totems.export_state()
	var save_sha := FileAccess.get_sha256(world.save_path())
	world.rng.seed = seed_for_stage(world.totems,4,2,true)
	var rng_before: int = world.rng.state
	world.source_save_blocked = true
	check(not world.totem_actions.execute("upgrade",4,301664,world.totems.revision).ok,"failed save rejects growth")
	check(world.totems.export_state() == state_before and world.inventory == inventory_before and world.rng.state == rng_before and FileAccess.get_sha256(world.save_path()) == save_sha,"failed commit preserves bytes inventory progression and RNG")
	world.source_save_blocked = false
	for pair in [[4,301664],[14,301674],[24,301684]]:
		var id: int = pair[0]
		for stage in range(int(world.totems.progress(id).level)+1,11):
			world.rng.seed = seed_for_stage(world.totems,id,stage,true,stage in [5,10])
			var result: Dictionary = world.totem_actions.execute("upgrade",id,pair[1],world.totems.revision)
			check(result.ok and result.success and world.totems.progress(id).level == stage,"real growth transaction %d/%d" % [id,stage])
			var total: int = world.totems.resonance().total_level
			if total in [15,20,25,30]: check(is_equal_approx(world.totem_reduction_pierce(),float(total-10)/500.0),"earned cumulative resonance threshold %d" % total)
	check(world._effective_ac() == baseline_ac-4,"four acquired AC options preserved once")
	check(world._effective_mr() == baseline_mr+8,"four acquired MR options preserved once")
	check(world.totems.bonus("ExperienceAdditionPercent") == 0 and is_equal_approx(world._experience_multiplier(),baseline_xp),"rolled zero EXP candidates remain zero, no positive re-normalization")
	var acquired_label: Label = world.hud.totem_view.find_child("TotemAcquiredOptions",true,false)
	check(acquired_label != null and acquired_label.text.contains("0.00%"),"actual acquired zero EXP option shown, separate from candidate pool")
	var actual_field: RefCounted = world.field_map
	var field := FieldProbe.new()
	var pack := PackProbe.new()
	field.source_pack = pack
	world.field_map = field
	for land: Dictionary in world.totems.map_contexts["4"]:
		pack.context = {"edition":"LineageM_base508","land_id":int(land.ID),"asset_path":str(land.AssetPath)}
		check(is_equal_approx(world._experience_multiplier(),baseline_xp+0.05),"exact native field contract enables one regional bonus")
	pack.context.asset_path = "unrelated/"
	check(is_equal_approx(world._experience_multiplier(),baseline_xp),"invalid field asset clears regional bonus immediately")
	world.field_map = actual_field
	check(is_equal_approx(world._experience_multiplier(),baseline_xp),"current Aden does not stack three regional buffs")
	var monster: TwilightMonster = world.monsters_root.get_child(0)
	monster.max_hp = 100000
	monster.hp = 100000
	monster.dead = false
	world.original_skills.status.set_modifiers(monster,"totem_reduction_probe",10,{"reduction":100})
	check(world.original_skills.target_damage(200,monster) == 104,"resonance ignores four percent of target reduction at existing hit boundary")
	world.original_skills.status.set_modifiers(monster,"totem_reduction_probe",10,{"reduction":-3})
	check(world.original_skills.target_damage(200,monster) == 203,"resonance does not amplify a negative reduction debuff")
	world.original_skills.status.remove_modifiers(monster,"totem_reduction_probe")
	world.rng.seed = seed_for_proc([true])
	var hp_before: int = monster.hp
	world.totem_combat.on_hit(monster,"melee",false)
	check(world.totem_combat.fired.has(17504) and monster.hp < hp_before and not world.totem_combat.fired.has(17514),"Osiris physical damage uses actual Monster, defence proc never fires on attack")
	world.rng.seed = seed_for_proc([true])
	world.totem_combat.on_hit(monster,"magic",true)
	check(world.totem_combat.fired.is_empty(),"BySpellAttack false does not proc from magic spell hits")
	world.rng.seed = seed_for_proc([false,true])
	world.totem_combat.on_hit(monster,"melee",false)
	check(world.totem_combat.fired.has(17524) and monster.source_option_healing(100,true) == 85,"Tikal applies exact fifteen percent potion healing decrease")
	monster.prune_source_option_debuffs({})
	check(monster.source_option_debuffs.has("totem:17524"),"card pruning cannot remove Totem-owned debuff")
	var base_reduction: int = world._damage_reduction_stat()
	world.rng.seed = seed_for_proc([true])
	check(world.totem_combat.incoming(monster,"melee",20) == 15 and world.totem_combat.fired.has(17514),"defence proc applies confirmed five-point reduction")
	check(world._damage_reduction_stat() == base_reduction+5 and world.totem_combat.incoming(monster,"melee",20) == 20,"active barrier reduction is not subtracted twice")
	world.totem_combat.tick(5.01)
	check(world._damage_reduction_stat() == base_reduction and world.totems.row("ShieldGroup",454).is_empty(),"five-second local duration expires without invented shield body")
	for pair in [[206794,301664,3581],[206804,301674,65291],[206814,301684,3581]]:
		var source_name := str(world._catalog_item_from_source_id(str(pair[2])).name)
		var output_name := str(world._catalog_item_from_source_id(str(pair[1])).name)
		var count_before := int(world.inventory[source_name])
		var output_before := int(world.inventory[output_name])
		var gold_before: int = world.gold
		var result: Dictionary
		if pair[0] == 206794:
			var craft: Button = world.hud.totem_view.find_child("TotemCraft_206794_3581",true,false)
			check(craft != null and not craft.disabled,"general stone craft usable on existing screen")
			if craft != null: craft.pressed.emit()
			result = {"ok":world.hud.message_label.text.contains("제작 완료")}
		else: result = world.totem_actions.execute("craft",pair[0],pair[2],world.totems.revision)
		check(result.ok and world.inventory[source_name] == count_before-3 and world.inventory[output_name] == output_before+1 and world.gold == gold_before-1000000,"native general-stone craft consumes one alternative scroll and exact gold")
		check(world.hud.message_label.text.contains(output_name),"crafted item result displayed")
	check(world.inventory["축복 부여 주문서"] == 13,"legacy locally authored scroll stack never consumed")
	world.hud.refresh_totems()
	var reset: Button = world.hud.totem_view.find_child("TotemReset_4",true,false)
	check(reset != null and not reset.disabled,"reset available on actual screen")
	var reset_before := int(world.inventory[reset_name])
	reset.pressed.emit()
	var confirm: Button = world.hud.find_child("ConfirmTransaction",true,false)
	check(confirm != null,"reset confirmation appears")
	if confirm != null: confirm.pressed.emit()
	check(world.totems.progress(4).level == 0 and world.totems.progress(4).active and world.totems.progress(4).kills == 3000 and world.inventory[reset_name] == reset_before-1,"reset consumes one scroll and preserves activation and kills")
	check(world.hud.message_label.text.contains("Lv.0 초기화"),"reset result displayed")
	check(world._effective_ac() == baseline_ac and world.totems.progress(4).selected.is_empty() and is_equal_approx(world.totem_reduction_pierce(),0.02),"reset removes only selected Totem effects and recalculates resonance")
	var saved: Dictionary = world.totems.export_state()
	var hash_before := FileAccess.get_sha256(world.save_path())
	world._load_game(true)
	var restored: Dictionary = JSON.parse_string(JSON.stringify(world.totems.export_state()))
	var expected: Dictionary = JSON.parse_string(JSON.stringify(saved))
	check(restored == expected and FileAccess.get_sha256(world.save_path()) == hash_before,"load keeps exact rolled options and revision without rerolling or rewriting")
	world.hud.open_totems()
	await process_frame
	if DisplayServer.get_name() != "headless":
		for size in [Vector2i(1280,720),Vector2i(900,640)]:
			root.size = size
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "user://totem-growth-%dx%d.png" % [size.x,size.y]
			check(root.get_texture().get_image().save_png(path) == OK,"real growth UI capture")
			print("TOTEM_GROWTH_CAPTURE ",ProjectSettings.globalize_path(path))
	world.queue_free()
	await process_frame
	print("TOTEM_PROGRESSION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_GROWTH_RESET_CRAFT_STATS; MAP_REGION_CONTRACT_FIXTURE; PARTIAL_NATIVE_PROCS"}))
	quit(0 if failures.is_empty() else 1)
