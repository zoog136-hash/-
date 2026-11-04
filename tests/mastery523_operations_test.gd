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
	check(not runtime.quote("purchase",1).ok,"sixth purchase waits for verified reset boundary")
	var threshold: int = int(runtime.core.levels[1][0].CumulativePoint)
	check(runtime.credit_confirmed_points(1,str(threshold-point_amount*5),"confirmed-operation-fixture-award").ok,"confirmed growth uses ordinary save")
	# Imported owned fixed options are a test fixture, never a free gameplay grant.
	var options: Array = []
	for id: int in runtime.core.options:
		if int(runtime.core.options[id][1].level) == 1: options.append({"group_id":id})
	var grade: int = int(runtime.core.tables.MasteryGradeView[0].GradeID)
	runtime.state.weapons["1"].options = options
	runtime.state.weapons["1"].colors = {"1":[grade,grade,grade,grade]}
	runtime.state.weapons["1"].locks = {}
	check(world._save_game(true) == OK,"owned-option fixture persisted without changing source values")
	for item: Dictionary in world.catalog_db.get("아이템",[]):
		if item.get("type") == "한손검" and item.get("slot") == "weapon": world._equip_or_acquire_item(item); break
	var native_speed: float = world._effective_attack_speed_bonus_percent()
	runtime.enabled = false
	var baseline_speed: float = world._effective_attack_speed_bonus_percent()
	runtime.enabled = true
	check(native_speed-baseline_speed == runtime.catalog_bonus("attackSpeed",1) and native_speed > baseline_speed,"native percentage reaches actual equipped-weapon attack-speed consumer")
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
	check(runtime.set_color_lock(1,1,0,true).ok and not runtime.quote("reset",1).ok,"locked coupling blocks only that reset path")
	check(runtime.set_color_lock(1,1,0,false).ok,"unlock restores executable reset path")
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
	check(not runtime.quote("change",3,1,0).ok,"unresolved repeated service restricted after first paid use")
	await capture(world,"change",3)
	var committed: Dictionary = runtime.state.duplicate(true)
	var rng_committed: int = runtime.reset_rng.state
	runtime.state = Core.fresh()
	world._load_game(true)
	check(normalized(runtime.state) == normalized(committed) and runtime.reset_rng.state == rng_committed,"actual reload restores paid state counters and RNG")
	print("MASTERY_OPERATIONS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source":"actual523"}))
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
