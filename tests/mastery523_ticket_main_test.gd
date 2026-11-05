extends SceneTree
## Actual Main/source pack; ownership below is an explicit test fixture, not supply.
const Core = preload("res://scripts/mastery/mastery523.gd")
const Unit = preload("res://tests/mastery523_effects_repair_test.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MASTERY_TICKET_FAIL: ",label)
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func _initialize() -> void: call_deferred("run")

func snapshot(world) -> Dictionary:
	return {"state":world.weapon_mastery.state.duplicate(true),"bag":world.inventory.duplicate(true),"instances":world.item_instances.duplicate(true),"gold":world.gold,"rng":world.weapon_mastery.reset_rng.state,"sha":FileAccess.get_sha256(world.save_path())}

func choose(runtime, method: String) -> void:
	var select: OptionButton = runtime.view.find_child("MasteryResetPayment",true,false)
	check(select != null,"actual payment selector")
	select.select(1 if method == "ticket" else 0)
	select.item_selected.emit(select.selected)

func dialog(world):
	var button: Button = world.weapon_mastery.view.find_child("MasteryReset",true,false)
	check(button != null and not button.disabled,"actual enabled reset button")
	if button == null or button.disabled: return null
	button.pressed.emit()
	var modal = world.hud.get_node_or_null("Root/TwilightConfirmation")
	check(modal != null,"actual reset confirmation")
	return modal

func capture(name_value: String) -> void:
	var output: String = OS.get_environment("TWILIGHT_MASTERY_CAPTURE_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name_value+".png") == OK,"actual OpenGL capture")

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false); world.save_timer = -100000.0
	check(QA.enter_game(world),"actual class confirmation")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	var runtime = world.weapon_mastery
	var path: String = OS.get_environment("TWILIGHT_MASTERY523_PACK")
	check(runtime.enabled or runtime.core.load_pack(path,FileAccess.get_sha256(path)),"verified native ticket pack or production CLI installation")
	runtime.enabled = true
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var instances_before: Dictionary = world.item_instances.duplicate(true)
	check(runtime.install_reset_ticket().ok,"source-exact ticket catalog registration")
	check(runtime.install_reset_ticket().ok and world.inventory == inventory_before and world.item_instances == instances_before,"idempotent install grants no resources or ownership")
	var record: Dictionary = runtime.reset_ticket.record()
	if record.is_empty(): quit(1); return
	check(world._find_catalog_item_record(record.name,record.sourceId) == record,"existing Main catalog lookup resolves exact native ID")
	var bad_operation: Dictionary = runtime.core.operations.reset_ticket.duplicate(true)
	bad_operation.definition.item.MaxStackAmount = 1
	var rejected = preload("res://scripts/mastery/mastery_reset_ticket.gd").new()
	check(not rejected.configure(bad_operation),"altered definition hash rejected")
	runtime.state = Core.fresh()
	runtime.state.weapons["1"] = Unit.owned(runtime.core,1,1)
	var grade: int = int(runtime.core.tables.MasteryGradeView[0].GradeID)
	runtime.state.weapons["1"].colors["1"] = [grade,grade,grade,grade]
	runtime.state.weapons["1"].locks["1"] = [false,false,false,false]
	world.gold = 10000000; world.inventory[world.CURRENCY_DROP.DIAMOND] = 5000
	world.inventory[record.name] = 14 # twelve verified fixture copies + two opaque legacy copies
	check(runtime.balance(1814) == 0,"name-only legacy stack never promoted by catalog registration")
	for index: int in 12:
		world.item_instances["ticket-fixture-%02d" % index] = {"name":record.name,"level":0,"bless_state":"normal","record":record.duplicate(true),"fixture":"test only"}
	check(runtime.balance(1814) == 12,"only source-exact fixture ownership counts")
	var blessed: Dictionary = record.duplicate(true); blessed.source_bless_raw = 2
	world.item_instances["ticket-fixture-blessed"] = {"name":record.name,"record":blessed,"bless_state":"blessed"}
	check(runtime.balance(1814) == 12,"blessed variant never flattened into normal tickets")
	check(world._save_game(true) == OK,"ordinary Main fixture save")
	runtime.show_panel(); runtime.view.selected_weapon = 1; runtime.view.refresh()
	check(runtime.view.reset_payment == "currency","existing currency payment remains default")
	check(runtime.quote("reset",1).charge.Cost == 1000000,"zero locks retain original Adena cost")
	check(runtime.quote("reset",1,0,0,"ticket").get("reason") == "ticket_not_applicable","zero-ticket row cannot give free reset")
	for locks: int in range(1,4):
		var toggle: CheckButton = runtime.view.find_child("MasteryLock_1_%d" % (locks-1),true,false)
		check(toggle != null,"actual color lock UI")
		toggle.toggled.emit(true)
		var currency: Dictionary = runtime.quote("reset",1)
		var ticket: Dictionary = runtime.quote("reset",1,0,0,"ticket")
		check(currency.ok and currency.charge.CurrencyID == 4 and currency.charge.Cost == locks*200,"original alternative diamond cost")
		check(ticket.ok and ticket.charge.CurrencyID == 1814 and ticket.charge.Cost == locks,"original alternative ticket amount")
		choose(runtime,"ticket")
		var before: Dictionary = snapshot(world)
		var modal = dialog(world)
		if modal == null: quit(1); return
		var named_payment: bool = false
		for label: Node in modal.find_children("*","Label",true,false):
			if label.text.contains("티켓") and label.text.contains(str(locks)): named_payment = true
		check(named_payment,"confirmation names selected ticket payment")
		modal.dismiss()
		await process_frame
		check(snapshot(world) == before,"cancel preserves wallet instances RNG state and file")
		world.equipment_collections.test_save_writer = func(_p: String,_d: Dictionary) -> Error: return ERR_CANT_CREATE
		check(not runtime.execute("reset",1,0,0,runtime.state.duplicate(true),"ticket").ok,"ticket reset write failure rejected")
		check(snapshot(world) == before,"write failure rolls back tickets RNG and state without rewriting old save")
		world.equipment_collections.test_save_writer = Callable()
		modal = dialog(world)
		if modal == null: quit(1); return
		await capture("ticket-confirm-%d" % locks)
		modal.confirm_button.pressed.emit()
		await process_frame
		check(int(world.inventory[record.name]) == int(before.bag[record.name])-locks and runtime.balance(1814) == int(before.bag[record.name])-locks-2,"selected exact ticket quantity consumed; legacy copies preserved")
		check(world.inventory[world.CURRENCY_DROP.DIAMOND] == before.bag[world.CURRENCY_DROP.DIAMOND] and world.gold == before.gold,"ticket selection never also spends currency")
		for slot: int in locks:
			check(runtime.state.weapons["1"].colors["1"][slot] == before.state.weapons["1"].colors["1"][slot] and runtime.state.weapons["1"].locks["1"][slot],"locked fields preserved in paid reset")
		check(not runtime.execute("reset",1,0,0,before.state,"ticket").ok,"duplicate confirmation cannot charge again")
		var committed: Dictionary = snapshot(world)
		world._load_game(true)
		check(normalized(runtime.state) == normalized(committed.state) and normalized(world.inventory) == normalized(committed.bag) and normalized(world.item_instances) == normalized(committed.instances),"reload preserves exact ticket debit and reset result")
		check(not runtime.transaction_blocked,"successful reload resumes transactions")
	# Diamond alternative must ignore ticket locks and preserve ticket ownership.
	choose(runtime,"currency")
	var before: Dictionary = snapshot(world)
	var modal = dialog(world)
	if modal == null: quit(1); return
	modal.confirm_button.pressed.emit(); await process_frame
	check(world.inventory[world.CURRENCY_DROP.DIAMOND] == int(before.bag[world.CURRENCY_DROP.DIAMOND])-600 and world.inventory[record.name] == before.bag[record.name] and world.item_instances == before.instances,"explicit diamond payment consumes only 600 diamonds")
	# Individual/global locks, missing provenance, insufficiency, and no fallback.
	for id: String in world.item_instances:
		if id.begins_with("ticket-fixture-"): world.ui_preferences.item_locks[record.name+"@@@"+id] = true
	check(not runtime.quote("reset",1,0,0,"ticket").ok,"locked physical tickets cannot be spent")
	world.ui_preferences.item_locks.clear()
	world.ui_preferences.item_locks[record.name] = true
	check(runtime.quote("reset",1,0,0,"ticket").get("reason") == "material_locked","global ticket stack lock enforced")
	world.ui_preferences.item_locks.erase(record.name)
	var physicals: Dictionary = world.item_instances.duplicate(true)
	for id: String in world.item_instances.keys():
		if id.begins_with("ticket-fixture-"): world.item_instances.erase(id)
	before = snapshot(world)
	check(runtime.quote("reset",1,0,0,"ticket").get("reason") == "insufficient_verified_tickets","unverified same-name remainder cannot pay")
	check(not runtime.execute("reset",1,0,0,runtime.state.duplicate(true),"ticket").ok and snapshot(world) == before,"insufficient tickets preserve all state and never fall back to diamonds")
	world.item_instances = physicals
	world.inventory[world.CURRENCY_DROP.DIAMOND] = 0
	check(not runtime.quote("reset",1).ok and runtime.quote("reset",1,0,0,"ticket").ok,"insufficient diamonds do not disable independently selected tickets")
	# Durable-write/post-activation error must not restore already spent tickets.
	check(world._save_game(true) == OK,"before post-write error")
	before = snapshot(world)
	world.equipment_collections.test_save_writer = func(p: String,d: Dictionary) -> Error:
		var result: Error = Writer.write(p,d)
		return ERR_BUG if result == OK else result
	var result: Dictionary = runtime.execute("reset",1,0,0,runtime.state.duplicate(true),"ticket")
	check(not result.ok and result.get("committed",false) and runtime.transaction_blocked,"post-write error recognizes durable ticket transaction")
	check(int(world.inventory[record.name]) == int(before.bag[record.name])-3,"durable ticket debit remains published")
	var once: Dictionary = snapshot(world)
	check(not runtime.execute("reset",1,0,0,runtime.state.duplicate(true),"ticket").ok and snapshot(world) == once,"durable result blocks retry and double debit")
	world.equipment_collections.test_save_writer = Callable()
	world._load_game(true)
	check(not runtime.transaction_blocked and normalized(runtime.state) == normalized(once.state) and normalized(world.item_instances) == normalized(once.instances),"reconnection accepts durable result without duplicate payment")
	print("MASTERY_TICKET_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"ownership":"explicit fixtures only; normal acquisition not implemented"}))
	world.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
