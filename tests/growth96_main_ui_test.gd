extends SceneTree
## Real Main and real input, in an explicitly isolated profile only.
const Source = preload("res://scripts/progression/growth96_source.gd")
const Runtime = preload("res://scripts/progression/growth96_runtime.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks := 0
var world
var evidence := ""

func _initialize() -> void:
	var isolated := OS.get_environment("TWILIGHT_GROWTH96_TEST_ROOT")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(isolated):
		push_error("Explicit isolated test profile required"); quit(1); return
	evidence = OS.get_environment("TWILIGHT_GROWTH96_EVIDENCE")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); print("GROWTH96_MAIN_FAIL " + message)

func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame

func freeze_gameplay() -> void:
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.original_population.set_process(false)
	world.get_node("Monsters").process_mode = Node.PROCESS_MODE_DISABLED

func view() -> Control:
	return world.hud.workspace.find_child("Growth96View",true,false)

func tap_named(name: String) -> void:
	var button: Control = world.hud.workspace.find_child(name,true,false)
	if button == null: check(false,"missing actual UI control " + name); return
	var current := view()
	if current != null and current.scroll.is_ancestor_of(button):
		current.scroll.ensure_control_visible(button)
		await frames()
	var position := button.get_global_transform_with_canvas() * (button.size / 2)
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 97; event.position = position; event.pressed = pressed
		root.push_input(event,true)
	await frames()

func capture(name: String) -> void:
	if evidence.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(evidence)
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(evidence.path_join(name+".png")) == OK,"viewport capture " + name)

func encoded(value: Variant) -> String:
	return JSON.stringify(canonical(value),"",true,true)

func canonical(value: Variant) -> Variant:
	# JSON integral numbers decode as floats. Schema validation checks their
	# integral value; equality must preserve that same numerical contract.
	if value is float and is_finite(value) and value == floorf(value): return int(value)
	if value is Array:
		var entries: Array = []
		for entry: Variant in value: entries.append(canonical(entry))
		return entries
	if value is Dictionary:
		var entries: Dictionary = {}
		for key: Variant in value: entries[key] = canonical(value[key])
		return entries
	return value

func text_contains(node: Node, text: String) -> bool:
	if node is Label and node.text.contains(text): return true
	for child: Node in node.get_children():
		if text_contains(child,text): return true
	return false

func run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world); freeze_gameplay()
	await frames(5)
	check(not world.map_bootstrap_blocked and not world.source_save_blocked,"actual source-map startup accepted")
	check(QA.enter_game(world),"normal class selection accepted")
	await frames()
	world.hud.toggle_menu(); await frames()
	await tap_named("MenuTile_growth96")
	check(world.hud.active_section == "growth96" and view() != null,"actual Main menu opens feature")
	if view() == null: finish(); return
	var rt = world.growth96
	if "--cold-reload" in OS.get_cmdline_user_args():
		check(OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty() and rt.source.ready,"cold process loads installed definitions without source environment")
		check(rt.state.claims.size() == 4 and rt.state.registrations.size() == 3,"cold process restores receipts and registrations")
		check(world.inventory.get(Source.item_key(96094),0) == 3 and not world.inventory.has(Source.item_key(Source.TOKEN)),"cold process preserves earned sealed boxes and consumed tokens")
		check(rt.bonus("local_reduction_efficiency:percent") == 5,"cold process derives bonus once")
		check(world.inventory.get("성장 검사 보존용",0) == 19,"cold process preserves unrelated inventory")
		await capture("growth96-cold-reload")
		finish(); return
	check(not rt.source.ready and rt.state.claims.is_empty(),"first launch without definitions grants nothing")
	await capture("growth96-missing-definitions")
	await tap_named("Growth96Install")
	check(view().source_picker.visible,"normal local file picker opens")
	view().source_picker.hide()
	view().source_picker.file_selected.emit(OS.get_environment("TWILIGHT_GROWTH96_INPUT"))
	await frames(); await tap_named("Growth96Cancel")
	check(not rt.source.ready and not FileAccess.file_exists(Source.INSTALLED),"cancel leaves installation and ownership unchanged")
	await tap_named("Growth96Install"); view().source_picker.hide()
	view().source_picker.file_selected.emit(OS.get_environment("TWILIGHT_GROWTH96_INPUT"))
	await frames(); await tap_named("Growth96Confirm")
	check(rt.source.ready and FileAccess.get_sha256(Source.INSTALLED) == Source.ZIP_SHA,"normal UI verifies and installs exact local source")
	if not rt.source.ready: finish(); return
	check(rt.state.claims.is_empty() and rt.state.registrations.is_empty(),"definition installation has no ownership grants")
	# Level/EXP are an isolated achievement fixture, never a player save.
	world.level = 96; world.exp_need = 1000; world.experience = 100
	world.inventory["성장 검사 보존용"] = 19
	check(world._save_game(true) == OK,"real whole-save baseline commits")
	var baseline := FileAccess.get_sha256(world.save_path())
	var inventory_before := encoded(world.inventory)
	var cards_before := encoded(world.card_draw_fusion.export_state())
	var quests_before := encoded(world.quest_service.export_state())
	var gold_before: int = world.gold
	var rng_before: int = world.rng.state
	view()._refresh(); await frames()
	await tap_named("Growth96Claim_828")
	check(view().pending.get("action") == "claim","normal claim selection opens exact review")
	await capture("growth96-claim-review")
	await tap_named("Growth96Cancel")
	check(FileAccess.get_sha256(world.save_path()) == baseline and encoded(world.inventory) == inventory_before,"claim cancel keeps disk and inventory")
	world.equipment_collections.test_save_writer = func(_path: String,_payload: Dictionary) -> Error: return ERR_CANT_CREATE
	await tap_named("Growth96Claim_828"); await tap_named("Growth96Confirm")
	check(FileAccess.get_sha256(world.save_path()) == baseline and rt.state.claims.is_empty() and encoded(world.inventory) == inventory_before,"real Main failed write rolls claim back")
	check(view().result.text.contains("저장 실패"),"normal UI reports write failure")
	world.equipment_collections.test_save_writer = Callable()
	await tap_named("Growth96Claim_828"); await tap_named("Growth96Confirm")
	for item: int in [96094,96084,254268,371128]:
		check(world.inventory.get(Source.item_key(item),0) == 3,"actual UI grants exactly3 of source item " + str(item))
	check(rt.state.claims.size() == 4 and not rt.quote("claim","828").ok,"normal claim commits four receipts and rejects duplicate")
	check(encoded(world.card_draw_fusion.export_state()) == cards_before and world.rng.state == rng_before,"sealed source boxes do not mint cards or use acquisition RNG")
	world._index_item_weights()
	for item: String in rt.source.items:
		check(world.item_weight_index[Source.item_key(int(item))] == int(rt.source.items[item].Weight),"real weight index preserves original weight")
	world._warehouse_transfer(Source.item_key(Source.TOKEN),1,"deposit","")
	check(world.inventory.get(Source.item_key(Source.TOKEN),0) == 3 and not world.warehouse.stacks.has(Source.item_key(Source.TOKEN)),"original no-storage restriction blocks actual warehouse commit")
	world.hud.open_warehouse(); await frames()
	var listing: ItemList = world.hud.workspace.find_child("WarehouseItems",true,false)
	check(listing != null,"actual warehouse UI remains available")
	if listing != null:
		for index: int in range(listing.item_count): check(not listing.get_item_text(index).contains("m523-growth-item:"),"warehouse UI excludes restricted growth items")
	world.hud.open_growth96(); await frames()
	world._on_inventory_item_activated(Source.item_key(96094))
	check(world.inventory.get(Source.item_key(96094),0) == 3 and encoded(world.card_draw_fusion.export_state()) == cards_before,"source box activation preserves existing card-supply contract")
	await tap_named("Growth96CollectionsTab")
	var first: Dictionary = rt.source.collections["38828"]
	var card: String = first.cards[0]
	world._set_item_locked(Source.item_key(Source.TOKEN),true); await frames()
	check(not rt.quote("register",card).ok and world.inventory.get(Source.item_key(Source.TOKEN),0) == 3,"existing player item lock protects registration")
	world._set_item_locked(Source.item_key(Source.TOKEN),false); await frames()
	await tap_named("Growth96Register_" + card); await tap_named("Growth96Cancel")
	check(rt.state.registrations.is_empty() and world.inventory.get(Source.item_key(Source.TOKEN),0) == 3,"normal registration cancel consumes nothing")
	baseline = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_path: String,_payload: Dictionary) -> Error: return ERR_CANT_CREATE
	await tap_named("Growth96Register_" + card); await tap_named("Growth96Confirm")
	check(FileAccess.get_sha256(world.save_path()) == baseline and rt.state.registrations.is_empty() and world.inventory.get(Source.item_key(Source.TOKEN),0) == 3,"real registration failure keeps token receipt and disk")
	world.equipment_collections.test_save_writer = Callable()
	for id: String in first.cards:
		await tap_named("Growth96Register_" + id); await tap_named("Growth96Confirm")
	check(rt.state.registrations.size() == 3 and not world.inventory.has(Source.item_key(Source.TOKEN)),"UI spends exactly3 actually earned tokens")
	check(not rt.quote("register",card).ok,"UI transaction duplicate rejected")
	for id: String in rt.source.cards:
		if not rt.state.registrations.has(id): check(not rt.quote("register",id).ok,"unearned token cannot register remaining choice"); break
	check(rt.bonus("local_reduction_efficiency:percent") == 0,"unrecovered percent formula stays disabled by default")
	check(text_contains(view().body,"실행 보류"),"normal collection UI distinguishes preserved values from applied effects")
	await tap_named("Growth96EffectsPolicy")
	await tap_named("Growth96EffectsPolicy_twilight_estimates"); await tap_named("Growth96Confirm")
	check(rt.bonus("local_reduction_efficiency:percent") == 5 and world.growth.combat.incoming(100,0,20,{"ignore_percent":10}) == 85,"UI opt-in reaches actual incoming combat consumer")
	view().scroll.ensure_control_visible(view().find_child("Growth96CollectionDetail",true,false)); await frames()
	await capture("growth96-earned-collection-1280x720")
	# Full effects use a separate, clearly synthetic registration fixture.
	var earned: Dictionary = rt.state.duplicate(true)
	var complete: Dictionary = earned.duplicate(true)
	var baseline_stats: Dictionary = {}
	for kind: String in ["melee","ranged","magic"]:
		baseline_stats[kind] = [world.call("_"+kind+"_accuracy_stat"),world.call("_"+kind+"_damage_stat"),world._player_critical_damage(100,kind)]
	var baseline_status: Dictionary = {}
	for kind: String in ["stun","silence","hold","fear"]: baseline_status[kind] = world.call("_"+kind+"_accuracy_stat")
	for id: String in rt.source.cards: complete.registrations[id] = true
	rt.restore(complete)
	check(world.growth.combat.outgoing(100,"melee") == 115 and world.growth.bonus("melee_hit:flat") == 5 and world.growth.bonus("melee_critical_damage:flat") == 7,"all registered effect fixture reaches real combat consumers")
	for kind: String in ["melee","ranged","magic"]:
		check(int(world.call("_"+kind+"_accuracy_stat")) == int(baseline_stats[kind][0])+5,"real " + kind + " accuracy consumer adds5")
		check(int(world.call("_"+kind+"_damage_stat")) == int(baseline_stats[kind][1])+5,"real " + kind + " offline damage consumer adds5")
		check(world._player_critical_damage(100,kind) == int(baseline_stats[kind][2])+7,"real " + kind + " critical consumer adds7")
	for kind: String in ["stun","silence","hold","fear"]:
		check(int(world.call("_"+kind+"_accuracy_stat")) == int(round(float(baseline_status[kind])*1.05)),"real " + kind + " status consumer uses explicit local multiplier")
	check(rt.status_accuracy(40) == 42,"scoped local status model is a5percent multiplier")
	rt.restore(earned)
	check(world.gold == gold_before and encoded(world.quest_service.export_state()) == quests_before and encoded(world.card_draw_fusion.export_state()) == cards_before,"cost transactions preserve gold quests and owned cards")
	var saved := FileAccess.get_file_as_string(world.save_path())
	world._load_game(true); freeze_gameplay()
	check(encoded(rt.state) == encoded(earned) and rt.bonus("local_reduction_efficiency:percent") == 5,"actual Main reload preserves receipts and applies bonus once")
	var damaged: Dictionary = JSON.parse_string(saved)
	damaged.growth96.registrations[card] = false
	check(Writer.write(world.save_path(),damaged) == OK,"isolated damaged namespace fixture written")
	baseline = FileAccess.get_sha256(world.save_path())
	world._load_game(true); freeze_gameplay()
	check(rt.save_blocked and world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == baseline,"damaged namespace protects original test save from overwrite")
	check(Writer.write_text(world.save_path(),saved) == OK,"normal test save restored")
	world._load_game(true); freeze_gameplay()
	check(not rt.save_blocked and encoded(rt.state) == encoded(earned),"normal reload releases protection without resetting history")
	world.hud.open_growth96(); await frames()
	root.size = Vector2i(854,480); world.hud._fit_hud(); await frames(5)
	await tap_named("Growth96CollectionsTab")
	var corner: Vector2 = root.get_final_transform() * view().get_global_transform_with_canvas() * view().size
	check(corner.x <= 855 and corner.y <= 481,"small landscape keeps actual feature in viewport")
	view().scroll.ensure_control_visible(view().find_child("Growth96CollectionDetail",true,false)); await frames()
	await capture("growth96-earned-collection-854x480")
	finish()

func finish() -> void:
	print("GROWTH96_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_main":true,"cold_reload":"--cold-reload" in OS.get_cmdline_user_args()}))
	if is_instance_valid(world): world.free()
	quit(0 if failures.is_empty() else 1)
