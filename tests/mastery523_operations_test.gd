extends SceneTree
## Actual private523 bytes + actual Main/UI/save/inventory. No fake wallet.
const Core = preload("res://scripts/mastery/mastery523.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MASTERY_OP_FAIL: ",label)

func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func confirm(world: Node, button_name: String) -> void:
	var button: Button = world.weapon_mastery.view.find_child(button_name,true,false)
	check(button != null and not button.disabled,"actual UI action enabled: "+button_name)
	if button == null or button.disabled: return
	button.pressed.emit()
	var dialog = world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(dialog != null,"actual confirmation dialog: "+button_name)
	if dialog != null: dialog.confirm_button.pressed.emit()

func seed_for(chance: float, hit: bool) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate: int in 10000:
		probe.seed = candidate
		if (probe.randf() < chance) == hit: return candidate
	return -1

func matching_seed(runtime, grades: Array) -> int:
	var probe := RandomNumberGenerator.new()
	for candidate: int in 100000:
		probe.seed = candidate
		var plan: Dictionary = runtime.core.plan_reroll(runtime.state,1,probe,"matching-seed-probe")
		if not plan.ok: return -1
		var colors: Dictionary = plan.after.weapons["1"].colors
		if colors["1"] == [grades[0],grades[0],grades[0],grades[0]] and colors["2"] == [grades[1],grades[1],grades[1],grades[1]]: return candidate
	return -1

func _initialize() -> void:
	call_deferred("run")

func capture(world: Node, name: String, weapon: int) -> void:
	var output: String = OS.get_environment("TWILIGHT_MASTERY_CAPTURE_DIR")
	if output.is_empty(): return
	world.weapon_mastery.view.selected_weapon = weapon
	world.weapon_mastery.view.refresh()
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name+".png") == OK,"actual paid-action OpenGL capture: "+name)

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual class confirmation")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	var runtime = world.weapon_mastery
	var path: String = OS.get_environment("TWILIGHT_MASTERY523_PACK")
	check(not path.is_empty() and runtime.core.load_pack(path,FileAccess.get_sha256(path)),"actual source operation pack")
	if runtime.core.operations.is_empty(): quit(1); return
	runtime.enabled = true
	var powder: String = str(runtime.core.operations.point_purchase.material.Name).trim_prefix("[재료] ")
	var unit_cost: int = int(runtime.core.tables.MasteryPointPayment[0].Cost)
	var point_amount: int = int(runtime.core.tables.MasteryPointPurchaseView[0].PointAmount)
	world.inventory[powder] = unit_cost*7
	world.inventory[world.CURRENCY_DROP.DIAMOND] = 10000
	world.gold = 10000000
	check(world._save_game(true) == OK,"initial ordinary save")
	runtime.show_panel()
	runtime.view.selected_weapon = 1
	runtime.view.refresh()
	world.ui_preferences.item_locks[powder] = true
	check(not runtime.quote("purchase",1).ok,"locked real inventory material cannot be spent")
	world.ui_preferences.item_locks.erase(powder)
	var original: Dictionary = runtime.state.duplicate(true)
	var button: Button = runtime.view.find_child("MasteryPointPurchase",true,false)
	check(button != null and not button.disabled,"source-ID matched powder enables actual buy button")
	button.pressed.emit()
	check(runtime.state == original and int(world.inventory[powder]) == unit_cost*7,"opening confirmation does not pay")
	world.hud.get_node("Root/TwilightConfirmation").dismiss()
	await process_frame
	check(runtime.state == original,"cancel keeps state")
	confirm(world,"MasteryPointPurchase")
	check(int(world.inventory[powder]) == unit_cost*6 and runtime.core.record(runtime.state,1).points == str(point_amount),"UI purchase spends exact original material and credits exact points")
	await capture(world,"purchase",1)
	check(not runtime.execute("purchase",1,0,0,original).ok,"stale confirmation cannot buy again")
	var before: Dictionary = runtime.state.duplicate(true)
	var bag: Dictionary = world.inventory.duplicate(true)
	var saved_sha: String = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_p: String,_d: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not runtime.execute("purchase",1,0,0,before).ok,"purchase save failure rejected")
	check(runtime.state == before and world.inventory == bag and FileAccess.get_sha256(world.save_path()) == saved_sha,"failed purchase preserves all bytes and materials")
	world.equipment_collections.test_save_writer = Callable()
	for i: int in 4: check(runtime.execute("purchase",1,0,0,runtime.state.duplicate(true)).ok,"remaining first-period purchase")
	check(int(runtime.state.purchase_count) == 5 and int(world.inventory[powder]) == unit_cost*2,"all five costs are paid exactly")
	check(not runtime.quote("purchase",1).ok,"sixth purchase is blocked by the shared local-day limit")
	var threshold: int = int(runtime.core.levels[1][0].CumulativePoint)
	check(runtime.credit_confirmed_points(1,str(threshold-point_amount*5),"confirmed-operation-fixture-award").ok,"confirmed growth uses ordinary save")
	# Claim through the actual HUD; no imported/free owned-option fixture.
	runtime.view.refresh()
	before = runtime.state.duplicate(true)
	var claim_rng: int = runtime.reset_rng.state
	world.equipment_collections.test_save_writer = func(_p: String,_d: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not runtime.execute("acquire",1,0,1,before).ok,"option claim write failure rejected")
	check(runtime.state == before and runtime.reset_rng.state == claim_rng,"failed claim preserves ownership and RNG")
	world.equipment_collections.test_save_writer = Callable()
	await capture(world,"acquire",1)
	confirm(world,"MasteryAcquire_1")
	var options: Array = runtime.core.record(runtime.state,1).options.duplicate(true)
	check(options.size() == 2 and runtime.core.record(runtime.state,1).colors["1"].size() == 4,"UI level acquisition grants exact two-value four-color structure")
	check(not runtime.quote("acquire",1,0,1).ok,"UI cannot claim the same level twice")
	for item: Dictionary in world.catalog_db.get("아이템",[]):
		if item.get("type") == "한손검" and item.get("slot") == "weapon": world._equip_or_acquire_item(item); break
	var native_speed: float = world._effective_attack_speed_bonus_percent()
	runtime.enabled = false
	var baseline_speed: float = world._effective_attack_speed_bonus_percent()
	runtime.enabled = true
	check(native_speed-baseline_speed == 1 and runtime.catalog_bonus("attackSpeed",1) == 1,"native raw10000 reaches actual attack speed as exactly one percentage point")
	runtime.view.refresh()
	before = runtime.state.duplicate(true)
	var rng_before: int = runtime.reset_rng.state
	var gold_before: int = world.gold
	saved_sha = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_p: String,_d: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not runtime.execute("reset",1,0,0,before).ok,"reset save failure rejected")
	check(runtime.state == before and runtime.reset_rng.state == rng_before and world.gold == gold_before and FileAccess.get_sha256(world.save_path()) == saved_sha,"failed reset preserves RNG money options and bytes")
	world.equipment_collections.test_save_writer = Callable()
	confirm(world,"MasteryReset")
	check(world.gold == gold_before-int(runtime.core.reset_quote(before,1).Cost),"UI reset debits exact original Adena fee")
	check(runtime.core.record(runtime.state,1).options == options and runtime.core.record(runtime.state,1).points == str(threshold),"100-percent values and points are preserved")
	check(runtime.state.rng_state == str(runtime.reset_rng.state) and runtime.reset_rng.state != rng_before,"only committed reset advances persistent RNG")
	gold_before = world.gold
	world.equipment_collections.test_save_writer = func(p: String,d: Dictionary) -> Error:
		var written: Error = preload("res://scripts/skills/save_writer.gd").write(p,d)
		return ERR_CANT_CREATE if written == OK else written
	var uncertain: Dictionary = runtime.execute("reset",1,0,0,runtime.state.duplicate(true))
	check(not uncertain.ok and uncertain.get("committed",false),"post-write error is checked against actual durable outcome")
	check(world.gold == gold_before-int(runtime.core.reset_quote(runtime.state,1).Cost) and runtime.transaction_blocked,"durable debit is published and immediate retry blocked")
	check(not runtime.quote("reset",1).ok,"a committed-but-unacknowledged reset cannot be blindly retried")
	world.equipment_collections.test_save_writer = Callable()
	world._load_game(true)
	check(not runtime.transaction_blocked and not world.equipment_collections.save_blocked,"accepted reload reconciles the durable transaction and writer lease")
	await capture(world,"reset",1)
	check(runtime.set_color_lock(1,1,0,true).ok and runtime.quote("reset",1).ok,"official field mapping enables locked reroll")
	var locked_color: int = int(runtime.core.record(runtime.state,1).colors["1"][0])
	var diamonds_before: int = int(world.inventory[world.CURRENCY_DROP.DIAMOND])
	var locked_fee: Dictionary = runtime.quote("reset",1).charge
	confirm(world,"MasteryReset")
	check(int(world.inventory[world.CURRENCY_DROP.DIAMOND]) == diamonds_before-int(locked_fee.Cost) and int(runtime.core.record(runtime.state,1).colors["1"][0]) == locked_color,"UI locked reroll pays original Gem fee and preserves locked name color")
	check(runtime.set_color_lock(1,1,0,false).ok,"unlock restores executable reset path")
	# Actual hit/miss/skill/impact resolution, isolated from background combat.
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	var mob = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(mob)
	mob.setup({"name":"숙련 명중 검증","hp":99999999,"ac":0},world.player,world,null)
	mob.set_physics_process(false)
	mob.position = world.player.position
	world.deferred_save_enabled = true
	check(world._save_game(true) == OK,"baseline save before normal-hit progression")
	var before_hits: int = int(runtime.core.record(runtime.state,1).points)
	var writes_before: int = world.equipment_collections.save_writes
	var chance: float = world._normal_attack_hit_chance(mob,"melee")
	var hit_seed: int = seed_for(chance,true)
	var miss_seed: int = seed_for(chance,false)
	world.rng.seed = miss_seed
	world._resolve_normal_attack(mob,"melee",1)
	check(int(runtime.core.record(runtime.state,1).points) == before_hits,"actual ordinary attack MISS gives no mastery")
	world.rng.seed = hit_seed
	world._resolve_normal_attack(mob,"melee",1)
	var hit_amount: int = int(runtime.balance_config.normal_hit_points)
	check(int(runtime.core.record(runtime.state,1).points) == before_hits+hit_amount,"actual normal HIT awards configured local points to equipped weapon")
	check(world.equipment_collections.save_writes == writes_before and world.deferred_save.pending(),"ordinary mastery uses bounded deferred save, no synchronous hit save")
	world.rng.seed = hit_seed
	world._resolve_normal_attack(mob,"melee",3)
	check(int(runtime.core.record(runtime.state,1).points) == before_hits+hit_amount,"weapon swap after launch cannot credit the wrong mastery")
	world.resolving_combat_action = true
	world._cast_magic_attack(mob,10,0,"숙련 검증 마법")
	world.resolving_combat_action = false
	check(int(runtime.core.record(runtime.state,1).points) == before_hits+hit_amount,"actual magic skill path gives no ordinary-hit mastery")
	var empty_snapshot: Dictionary = runtime.state.duplicate(true)
	check(not runtime.normal_hit(0) and not runtime.normal_hit(-1) and runtime.state == empty_snapshot,"unarmed and unmapped weapon types give no mastery")
	var action: Dictionary = {"target":weakref(mob),"generation":world.combat_generation,"target_life_id":mob.life_id,"kind":"melee","callback":world._resolve_normal_attack.bind(mob,"melee",1),"impact_resolved":false}
	world.rng.seed = hit_seed
	world._impact_player_attack(action)
	world._impact_player_attack(action)
	check(int(runtime.core.record(runtime.state,1).points) == before_hits+hit_amount*2,"duplicate actual impact event cannot double-credit mastery")
	var modal_quote: Dictionary = runtime.quote("reset",1)
	world.rng.seed = hit_seed
	world._resolve_normal_attack(mob,"melee",1)
	check(runtime.execute("reset",1,0,0,modal_quote.before).ok,"ordinary progress during modal keeps a valid financial confirmation")
	check(int(runtime.core.record(runtime.state,1).points) == before_hits+hit_amount*3,"paid reset rebuilds from latest points and never loses concurrent hits")
	threshold = before_hits+hit_amount*3
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(int(on_disk[Core.SAVE_KEY].weapons["1"].points) == threshold,"financial save atomically includes pending ordinary mastery progress")
	mob.queue_free()
	check(QA.enter_game(world,"요정"),"actual class UI selects an allowed bow target")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	runtime.view.selected_weapon = 1
	runtime.view.target_weapon = 3
	runtime.view.prefix_level = 1
	runtime.view.refresh()
	var fee: Dictionary = runtime.quote("change",1,3,1)
	check(fee.ok and int(fee.charge.CurrencyID) == 4 and int(fee.charge.Cost) == int(fee.charge.BaseCost)+int(fee.charge.AdditionalCost),"linked source Gem base plus independent-service level fee")
	before = runtime.state.duplicate(true)
	bag = world.inventory.duplicate(true)
	saved_sha = FileAccess.get_sha256(world.save_path())
	var save_path: String = world.save_path()
	world.equipment_collections.test_save_writer = func(_p: String,_d: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not runtime.execute("change",1,3,1,before).ok,"change save failure rejected")
	check(runtime.state == before and world.inventory == bag and FileAccess.get_sha256(save_path) == saved_sha,"failed change preserves source target and Gem")
	world.equipment_collections.test_save_writer = Callable()
	confirm(world,"MasteryTransfer")
	check(int(world.inventory[world.CURRENCY_DROP.DIAMOND]) == int(bag[world.CURRENCY_DROP.DIAMOND])-int(fee.charge.Cost),"UI change pays full source Gem fee once")
	check(runtime.core.record(runtime.state,1).points == "0" and runtime.core.record(runtime.state,1).options.is_empty(),"source points and unselected options cleared after commit")
	var destination: Dictionary = runtime.core.record(runtime.state,3)
	check(destination.points == str(threshold) and normalized(destination.options) == normalized(options) and destination.colors == runtime.core.record(before,1).colors and destination.locks.is_empty(),"target preserves raw sum options colors and resets locks")
	check(runtime.core.achieved_level(3,destination.points) < 1 and runtime.core.active_options(runtime.state,3).is_empty(),"higher-threshold bow retains inactive owned options")
	var first: Dictionary = runtime.core.options[int(options[0].group_id)][3]
	check(runtime.core.types[int(runtime.core.bonuses[int(first.BonusID)].BonusTypeID)].Name == "RangeHit","source hit group resolves target ranged type")
	check(FileAccess.get_sha256(save_path+".pre-mastery-change-"+saved_sha) == saved_sha,"independent before-change backup preserves exact source bytes")
	check(runtime.quote("change",3,1,0).ok,"official product has no purchase-count limit after first paid use")
	await capture(world,"change",3)
	runtime.view.selected_weapon = 3
	runtime.view.target_weapon = 1
	runtime.view.prefix_level = 0
	runtime.view.refresh()
	var repeat_fee: Dictionary = runtime.quote("change",3,1,0)
	var repeat_gems: int = int(world.inventory[world.CURRENCY_DROP.DIAMOND])
	confirm(world,"MasteryTransfer")
	check(runtime.core.record(runtime.state,3).points == "0" and runtime.core.record(runtime.state,1).points == str(threshold),"actual second UI transfer runs with exact raw sum")
	check(int(world.inventory[world.CURRENCY_DROP.DIAMOND]) == repeat_gems-int(repeat_fee.charge.Cost),"second UI transfer debits its own original service fee once")
	# Produce rare matching outcomes through the real paid reroll, using a
	# deterministic test seed. No owned options or colors are injected.
	for item: Dictionary in world.catalog_db.get("아이템",[]):
		if item.get("type") == "한손검" and item.get("slot") == "weapon": world._equip_or_acquire_item(item); break
	runtime.view.selected_weapon = 1
	runtime.view.refresh()
	confirm(world,"MasteryAcquire_1")
	var next_threshold: int = int(runtime.core.levels[1][1].CumulativePoint)
	check(runtime.credit_confirmed_points(1,str(next_threshold-int(runtime.core.record(runtime.state,1).points)),"matching-test-growth").ok,"confirmed test growth reaches second source level")
	confirm(world,"MasteryAcquire_2")
	var selected_seed: int = matching_seed(runtime,[2,2])
	check(selected_seed >= 0,"deterministic original-weight two-green-match seed exists")
	runtime.reset_rng.seed = selected_seed
	runtime.state.rng_state = str(runtime.reset_rng.state)
	check(world._save_game(true) == OK,"test seed persisted before actual paid matching reroll")
	runtime.view.refresh()
	confirm(world,"MasteryReset")
	check(runtime.core.active_matching_bonuses(runtime.state,1).size() == 2 and runtime.catalog_bonus("hpFlat",1) == 40,"two actual green matched levels grant forty HP")
	runtime.enabled = false
	var base_hp: int = world._effective_max_hp()
	var base_mp: int = world._effective_max_mp()
	runtime.enabled = true
	check(world._effective_max_hp()-base_hp == 40 and world._effective_max_mp() == base_mp,"actual Main maximum HP consumer adds both flat matched grants once")
	var matching_labels: int = 0
	for label: Node in runtime.view.body.get_children():
		if label.has_meta("mastery_matching_level"): matching_labels += 1
	check(matching_labels == 2,"actual UI renders each matched level with its effect and activation status")
	await capture(world,"matching",1)
	selected_seed = matching_seed(runtime,[2,3])
	check(selected_seed >= 0,"deterministic mixed green/blue match seed exists")
	runtime.reset_rng.seed = selected_seed
	runtime.state.rng_state = str(runtime.reset_rng.state)
	check(world._save_game(true) == OK,"second deterministic test seed persisted")
	runtime.view.refresh()
	before = runtime.state.duplicate(true)
	gold_before = world.gold
	rng_before = runtime.reset_rng.state
	world.equipment_collections.test_save_writer = func(_p: String,_d: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not runtime.execute("reset",1,0,0,before).ok and runtime.state == before and world.gold == gold_before and runtime.reset_rng.state == rng_before and world._effective_max_hp()-base_hp == 40,"failed matching reroll preserves live HP bonus money state and RNG")
	world.equipment_collections.test_save_writer = Callable()
	confirm(world,"MasteryReset")
	check(world._effective_max_hp()-base_hp == 20 and world._effective_max_mp()-base_mp == 20,"actual reroll replaces only changed level's HP matching grant with MP matching grant")
	check(runtime.credit_confirmed_points(3,"1","existing-target-policy-probe").ok,"isolated source point prepares guarded existing-target quote")
	runtime.balance_config.point_only_target_options = "block_unverified"
	var guard_state: Dictionary = runtime.state.duplicate(true)
	var guard_bag: Dictionary = world.inventory.duplicate(true)
	var guarded: Dictionary = runtime.quote("change",3,1,0)
	check(not guarded.ok and guarded.reason == "target_option_policy_unconfirmed","ambiguous existing-option point-only transfer remains explicitly blocked")
	runtime.view.selected_weapon = 3
	runtime.view.target_weapon = 1
	runtime.view.prefix_level = 0
	runtime.view.refresh()
	var blocked_button: Button = runtime.view.find_child("MasteryTransfer",true,false)
	check(blocked_button != null and blocked_button.disabled,"actual UI cannot charge for unresolved target-option policy")
	var existing_preview: bool = false
	for label: Node in runtime.view.body.get_children():
		if label.has_meta("mastery_existing_target") and int(label.get_meta("mastery_existing_target")) == 1: existing_preview = true
	check(existing_preview and runtime.state == guard_state and world.inventory == guard_bag,"existing-target UI previews owned options without changing state or paying")
	runtime.balance_config.point_only_target_options = "preserve_existing"
	runtime.view.refresh()
	var target_before: Dictionary = runtime.core.record(runtime.state,1)
	check(runtime.set_color_lock(1,1,0,true).ok,"target lock set before point-only preservation")
	target_before = runtime.core.record(runtime.state,1)
	var only_points: Dictionary = runtime.quote("change",3,1,0)
	check(only_points.ok and int(only_points.charge.Cost) == int(only_points.charge.BaseCost) and int(only_points.charge.AdditionalCost) == 0,"custom point-only path uses original base fee with no option fee")
	var point_only_gems: int = int(world.inventory[world.CURRENCY_DROP.DIAMOND])
	var point_only_rng: int = runtime.reset_rng.state
	var point_button: Button = runtime.view.find_child("MasteryTransfer",true,false)
	check(point_button != null and not point_button.disabled,"actual point-only UI action enabled")
	point_button.pressed.emit()
	var point_dialog = world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(point_dialog != null,"actual point-only confirmation exists")
	var custom_warning: bool = false
	if point_dialog != null:
		for label: Node in point_dialog.find_children("*","Label",true,false):
			if label.text.contains("자체 동작") and label.text.contains("보존"): custom_warning = true
	check(custom_warning,"actual confirmation explicitly labels the custom destination-preservation behavior")
	await capture(world,"point-only",3)
	if point_dialog != null: point_dialog.confirm_button.pressed.emit()
	target_before.points = str(int(target_before.points)+1)
	check(normalized(runtime.core.record(runtime.state,1)) == normalized(target_before) and runtime.core.record(runtime.state,3).points == "0","actual UI point-only transfer preserves all target values colors locks and exact point sum")
	check(int(world.inventory[world.CURRENCY_DROP.DIAMOND]) == point_only_gems-int(only_points.charge.Cost) and runtime.reset_rng.state == point_only_rng,"point-only execution pays once and never rerolls target")
	var custom_receipt: bool = false
	for receipt: Dictionary in runtime.state.receipts.values():
		if receipt.get("custom_point_only_target_policy") == "preserve_existing": custom_receipt = true
	check(custom_receipt,"custom destination policy recorded durably in transaction receipt")
	var committed: Dictionary = runtime.state.duplicate(true)
	var rng_committed: int = runtime.reset_rng.state
	runtime.state = Core.fresh()
	world._load_game(true)
	check(normalized(runtime.state) == normalized(committed) and runtime.reset_rng.state == rng_committed,"actual reload restores paid state counters and RNG")
	check(world._effective_max_hp()-base_hp == 20 and world._effective_max_mp()-base_mp == 20,"actual reload derives matching effects without persisting or double-counting calculated grants")
	print("MASTERY_OPERATIONS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source":"actual523"}))
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
