extends SceneTree
## Whole-input execution inventory. Excluded, expired and provider-dependent
## items are reported separately; a preserved item is never counted as used.
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const U = preload("res://scripts/loot/patch523_item_use.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
var outcomes: Dictionary = {}
var counts: Dictionary = {}
var world: TwilightWorld
var classes: Dictionary = {}
func reject(_path: String,_state: Dictionary) -> Error: return ERR_CANT_CREATE
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		if failures.size() < 50: printerr("ALL_USE_FAIL: ",label)
		failures.append(label)
func mark(id: String,status: String,reason: String = "") -> void:
	outcomes[id] = {"status":status,"reason":reason}
	counts[status] = int(counts.get(status,0))+1
func prepare(record: Dictionary,spec: Dictionary) -> void:
	for slot: String in world.EQUIPMENT_SLOT_ORDER: world.equipped_items[slot] = {}
	world.inventory = {str(record.name):1}
	world.item_instances = {}
	world.active_item_buffs = {}
	world.item_use_cooldowns = {}
	world._invalidate_equipment_static()
	if is_instance_valid(world.hud.card_reveal_stage): world.hud.card_reveal_stage.close_reveal()
	if world.hud.has_meta("patch523_reward_choice"):
		var popup: Node = world.hud.get_meta("patch523_reward_choice")
		if is_instance_valid(popup): popup.free()
	var candidates: Array = record.get("source_class_names",[]).duplicate()
	if candidates.is_empty(): candidates.assign(classes.values())
	world.job_class = "기사"
	for candidate: String in candidates:
		if world.BASE508.source_class_id(candidate) <= 0: continue
		if record.get("slot") == "weapon" and not world._weapon_allowed_for_job(record,candidate): continue
		if spec.get("kind") in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward"]:
			var matching: bool = false
			for reward: Dictionary in spec.get("rewards",[]):
				if U.class_matches(reward.get("class_ids",[]),world.BASE508.source_class_id(candidate)): matching = true;break
			if not matching: continue
		world.job_class = candidate;break
	if spec.get("kind") == "source_skill_book":
		for limit: Dictionary in spec.get("source_learn_limits",[]):
			if classes.has(int(limit.ClassID)): world.job_class = str(classes[int(limit.ClassID)]);break
	world.level = maxi(90,maxi(int(record.get("source_level_limit_min",0)),int(record.get("source_max_level_limit_min",0))))
	for maximum: Variant in [record.get("source_level_limit_max",0),record.get("source_max_level_limit_max",0)]:
		if int(maximum)>0: world.level = mini(world.level,int(maximum))
	world.hp = maxi(1,world._effective_max_hp()-100)
	world.mp = maxi(0,world._effective_max_mp()-100)

func run() -> void:
	var installed: Dictionary = D.install_zip(OS.get_environment("TWILIGHT_PATCH523_DROP_ZIP"))
	check(installed.get("ok",false),"all-source private pack installed")
	if not installed.get("ok",false): quit(1);return
	var document: Dictionary = D.data()
	var selected: Dictionary = {}
	var selection_path: String = OS.get_environment("TWILIGHT_ITEM_USE_SELECTION")
	if not selection_path.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(selection_path))
		check(value is Dictionary and not value.is_empty(),"explicit nonempty whole candidate selection")
		if not value is Dictionary or value.is_empty():quit(1);return
		selected = value
	world = load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer = -100000
	check(QA.enter_game(world),"actual Main map entry")
	world.field_population.set_process(false);world.player.set_physics_process(false)
	world._clear_monsters();world._clear_drops()
	for row: Dictionary in world.BASE508.cards().get("classes",[]): classes[int(row.source_original.ID)] = str(row.name)
	print("ALL_USE_STAGE main_entered")
	if not selected.is_empty():
		world.hud.open_settings_info(true);await process_frame
		var settings: Node = world.hud.find_child("Patch523DropSettings",true,false)
		check(settings != null and settings.presentation_flags != null,"actual presentation flag policy UI reachable")
		if settings != null:
			check(world._save_game(true) == OK,"presentation policy baseline save")
			var before: PackedByteArray = FileAccess.get_file_as_bytes(world.save_path())
			world.equipment_collections.test_save_writer = reject
			settings.presentation_flags.button_pressed = false
			check(bool(world.ui_preferences.get("patch523_item_presentation_flags_policy",true)) and settings.presentation_flags.button_pressed and FileAccess.get_file_as_bytes(world.save_path()) == before,"presentation policy UI writer failure rolls back preference and bytes")
			world.equipment_collections.test_save_writer = Callable()
			settings.presentation_flags.button_pressed = false
			world._load_game(true);world.field_population.set_process(false);world._clear_monsters()
			check(not world.ui_preferences.get("patch523_item_presentation_flags_policy",true),"disabled metadata interpretation survives actual reentry")
			settings.presentation_flags.button_pressed = true
			check(world.ui_preferences.get("patch523_item_presentation_flags_policy",false),"metadata interpretation actual UI reenabled")
		if OS.get_environment("TWILIGHT_ITEM_USE_POLICY_UI_ONLY") == "1":
			world.queue_free();await process_frame
			print("PRESENTATION_POLICY_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual_policy_UI_save_failure_and_reentry_only"}))
			quit(0 if failures.is_empty() else 1);return
	var visited: int = 0
	var option_claims: int = 0
	for id: String in D.definition_ids():
		if not selected.is_empty() and not selected.has(id): continue
		visited += 1
		if document.source_exclusions.has(id): mark(id,"source_excluded",str(document.source_exclusions[id]));continue
		var definition: Dictionary = D.definition_id(id)
		check(not definition.is_empty(),"full detail shard reachable "+id)
		var record: Dictionary = world.source_item_record(int(id))
		var spec: Dictionary = definition.native_record.get("source_use_spec",{})
		prepare(record,spec)
		if not selected.is_empty():
			world.ui_preferences.patch523_item_presentation_flags_policy = false
			world._on_inventory_item_activated(str(record.name))
			check(int(world.inventory.get(str(record.name),0)) == 1,"disabling estimated presentation policy preserves item "+id)
			world.ui_preferences.patch523_item_presentation_flags_policy = true
			spec = U.action_record(world,record).get("source_use_spec",{})
			check(spec.get("activation_status") == "unrestricted" and U.canonical(record).get("source_use_spec",{}).get("activation_status") == "blocked","host metadata policy never rewrites original source status "+id)
		var eligibility: String = U.eligibility(world,U.canonical(record))
		if not eligibility.is_empty():
			world._on_inventory_item_activated(str(record.name))
			check(int(world.inventory.get(str(record.name),0)) == 1,"source deadline/class/level gates preserve item "+id)
			mark(id,"source_condition_blocked",eligibility)
		elif D.equipment(record):
			world._sync_item_instances()
			world._on_inventory_item_activated(str(record.name))
			var equipped: bool = false
			for slot: String in world.EQUIPMENT_SLOT_ORDER:
				if int(world.equipped_items.get(slot,{}).get("source_item_class_id",-1)) == int(id): equipped = true
			if equipped:
				check(world._save_game(true) == OK,"source equipment persisted "+id)
				mark(id,"equipped_and_saved")
			else:
				check(int(world.inventory.get(str(record.name),0)) == 1,"host weapon/slot condition preserves source gear "+id)
				mark(id,"equipment_host_contract_blocked","host weapon/offhand/class interface")
		elif not record.get("heal_spec",{}).is_empty():
			var problem: String = D.hp_use_problem(U.canonical(record),false)
			world._on_inventory_item_activated(str(record.name))
			if problem.is_empty():
				check(int(world.inventory.get(str(record.name),0)) == 0,"every eligible pure source HP potion consumed "+id)
				mark(id,"hp_used_and_saved")
			else:
				check(int(world.inventory.get(str(record.name),0)) == 1,"compound source healing not partially applied "+id)
				mark(id,"compound_healing_contract_blocked",problem)
		elif spec.is_empty() or spec.get("activation_status") != "unrestricted":
			world._on_inventory_item_activated(str(record.name))
			check(int(world.inventory.get(str(record.name),0)) == 1,"unimplemented/conditional source use preserves ownership "+id)
			mark(id,"no_direct_use_or_source_rule_blocked",str(spec.get("blocked_reasons",[])))
		elif spec.kind == "source_skill_book":
			var learned: Dictionary = world.original_skills.catalog.export_state()
			world._on_inventory_item_activated(str(record.name))
			check(int(world.inventory.get(str(record.name),0)) == 1 and world.original_skills.catalog.export_state() == learned,"book provider absent/condition gates never guess identity "+id)
			mark(id,"skill_provider_dependency","PR245 exact source ID and row hash contract")
		elif spec.kind == "fixed_card":
			var candidates: Array[Dictionary] = []
			for card: Dictionary in world.catalog_db.get(str(spec.card_kind),[]):
				if card.get("source") in ["lineagem_base508","lineagem_patch523"] and int(card.get("source_card_id",-1)) == int(spec.card_id) and card.get("source_original_card",{}) == spec.original_card: candidates.append(card)
			var owned_before: int = world.card_draw_fusion.total_count(str(spec.card_kind),world.card_draw_fusion.card_id(candidates[0])) if candidates.size() == 1 else 0
			world._on_inventory_item_activated(str(record.name))
			if candidates.size() == 1:
				check(int(world.inventory.get(str(record.name),0)) == 0 and world.hud.is_card_reveal_busy(),"every compatible source fixed card received and revealed "+id)
				check(world.card_draw_fusion.total_count(str(spec.card_kind),world.card_draw_fusion.card_id(candidates[0])) == owned_before+1,"exact original card ownership increased "+id)
				mark(id,"fixed_card_received_and_saved")
			else:
				check(int(world.inventory.get(str(record.name),0)) == 1,"unmatched latest card preserves item "+id)
				mark(id,"card_provider_dependency","PR249 original full-card row missing/mismatch")
			if is_instance_valid(world.hud.card_reveal_stage): world.hud.card_reveal_stage.close_reveal()
			await process_frame
		elif spec.kind == "source_selectable_reward":
			var possible: int = 0
			for reward: Dictionary in spec.get("rewards",[]):
				var class_found: bool = false
				for candidate: Variant in classes:
					if not U.class_matches(reward.get("class_ids",[]),int(candidate)): continue
					var name_value: String = str(classes[candidate])
					if not record.get("source_class_names",[]).is_empty() and not record.source_class_names.has(name_value): continue
					world.job_class = name_value;class_found = true;break
				if not class_found: continue
				possible += 1
				world.inventory = {str(record.name):1};world.item_instances = {};world.item_use_cooldowns = {}
				var state: int = world.rng.state
				var ok: bool = U.claim_selection(world,record,int(reward.source_entity_id))
				check(ok and int(world.inventory.get(str(record.name),0)) == 0,"every currently eligible selector entity claimed "+id+"/"+str(int(reward.source_entity_id)))
				check(world.rng.state == state,"explicit selection has no hidden random draw "+id)
				option_claims += 1
			if possible > 0: mark(id,"all_current_class_choices_claimed_and_saved",str(possible))
			else: mark(id,"reward_class_contract_blocked","no option for source item eligible player class")
		else:
			world._on_inventory_item_activated(str(record.name))
			if int(world.inventory.get(str(record.name),0)) == 0:
				mark(id,str(spec.kind)+"_used_and_saved")
			else:
				mark(id,"runtime_use_contract_blocked",str(spec.kind))
		if visited%500 == 0:
			print("ALL_USE_PROGRESS ",visited,"/",D.definition_count()," options ",option_claims)
			await process_frame
	check(outcomes.size() == (D.definition_count() if selected.is_empty() else selected.size()),"every selected source ItemClass has actual execution/exclusion outcome")
	var result: Dictionary = {"checks":checks,"failures":failures,"source_rows":outcomes.size(),"input_scope":"all_ItemClass" if selected.is_empty() else "all_presentation_policy_candidates","counts":counts,"actual_current_class_selector_entity_claims":option_claims,"skill_engine":"PR245 not installed; preserved","other_class_choices":"raw relationships verified, current eligible class executed"}
	var output: String = OS.get_environment("TWILIGHT_ITEM_COVERAGE_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"summary":result,"items":outcomes}));file.close()
	world.queue_free();await process_frame
	print("ALL_USE_RESULT ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
