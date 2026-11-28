extends SceneTree
## Item use through the player's own UI path (user report 2026-11-28 "스킬들,
## 아이템들 사용 안 되는 게 많아 … 정상 사용 기준이야"). For one original
## item of each use rule:
##  - grant: the catalog "선택 아이템 1개 임시 지급" button (pressed twice for
##    stackables); the phone pack has no full drop catalog, so this is the
##    name-quantity grant that issues a receipted stack,
##  - bag: a real ScreenTouch on the original bag slot shows 사용/장착, a
##    second touch uses or equips it, any confirmation/selection is accepted,
##  - effect: consumed with a visible result (buff, HP/MP, reward, points,
##    card, equipment, window),
##  - quick slot: registration and a quick-slot press use the second unit,
##  - old save form: a plain name balance (no receipt) of the same item.
## Items routed to the unbound original events window (진영전·사과 상자,
## 드래곤의 용옥) were silent on touch; they now say why and stay in the bag,
## and ComplexReward boxes with an exact native selection rule open it.
## Without the pinned 523 tables only the rules run. user:// is restored.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const SLOTS = preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const RUNTIME = preload("res://scripts/unconfirmed523/runtime.gd")
## [id, rule, expected bag result, quick-slot second unit, old plain save form]
## expected: consume (one used, visible effect) / equip / window / msg:<text>
const CASES = [
	[4241, "hp", "consume", "consume", true], # 강력 체력 회복제
	[180382, "mp", "consume", "consume", false], # 민트 초콜릿(MP)
	[248198, "buff", "consume", "", true], # 전투 강화의 주문서
	[125602, "buff_scroll", "consume", "", false], # 카시오페아의 축복 주문서
	[371161, "bag", "consume", "consume", true], # 지배석 특별 제작 상자
	[340503, "selection_bag", "consume", "consume", false], # [+5] 축복받은 … 선택 상자
	[339713, "select_reward", "consume", "consume", false], # 블랙 프라이데이 선택 상자
	[197121, "card", "consume", "", true], # [변신 카드] 천상의 수호 기사
	[120072, "skill_book", "consume", "", false], # [기사] 기술서 (그랜드 마스터: 카운터)
	[117304, "bless_points", "consume", "consume", true], # 축복의 성수(대)
	[217112, "ain", "consume", "consume", false], # 드래곤의 고급 다이아몬드
	[367732, "mastery", "consume", "consume", false], # 무기 수련의 서
	[267921, "fusion_points", "consume", "consume", false], # 성물 카드 합성 포인트 주문서
	[328198, "exact_experience", "consume", "consume", false], # 승리의 열매
	[4151, "elixir", "consume", "", false], # 엘릭서 (stat choice)
	[273043, "draw_ticket", "window", "", false], # 최상급 변신 픽업팩
	[301122, "mystery_card", "window", "", false], # [미스터리 성물 카드] 희귀
	[198031, "element_remove", "window", "", false], # 속성 제거 주문서
	[226872, "earring", "equip", "", false], # 성령의 귀걸이
	[571, "cloak", "equip", "", false], # 거대 여왕 개미의 금빛 날개
	[188314, "weapon", "equip", "", false], # 광대의 단검
	[323733, "domination_stone", "equip", "", false], # 지옥의 지배석
	[167424, "complex_selection", "consume", "", false], # 신성한 영웅 방어구 선택 상자 (ComplexReward)
	[178292, "events_box", "msg:" + RUNTIME.BOX_UNAVAILABLE, "", false], # 진심으로 사과드립니다(2차)
	[132834, "events_box", "msg:" + RUNTIME.BOX_UNAVAILABLE, "", false], # 진영전 계급 보상 상자 (대장)
	[181194, "jade_grail", "msg:" + RUNTIME.WINDOW_UNAVAILABLE, "", false], # 드래곤의 용옥 10일
]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var user_files: Dictionary = {}
var w: Node
var hud: Node
var bag: Control
var base: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ITEM_USE_UI_MATRIX_FAIL ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func frames(count: int = 4) -> void:
	for frame: int in count: await process_frame

func rules() -> void:
	var runtime: String = FileAccess.get_file_as_string("res://scripts/unconfirmed523/runtime.gd")
	check(runtime.contains("var box: bool = category in [78,10381,10394]"), "ComplexReward boxes with a native rule are left to the bag owner")
	check(runtime.contains("world.hud.show_message(BOX_UNAVAILABLE if box else WINDOW_UNAVAILABLE)"), "an events-window item says why when that window is unavailable")
	check(RUNTIME.BOX_UNAVAILABLE.ends_with("상자 보존") and RUNTIME.WINDOW_UNAVAILABLE.ends_with("아이템 보존"), "the reasons keep the item")
	var world: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world.contains('or supply.stage(self,[grant],{"kind":"twilight_debug_catalog"}).get("ok",false):'), "the catalog test grant issues a receipted stack without the full drop catalog")
	var hud_text: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_text.contains('playtest_grant_button = UI.button("선택 아이템 1개 임시 지급",_request_playtest_catalog_grant'), "the grant button requests the selected catalog item")
	var tap: String = FileAccess.get_file_as_string("res://scripts/ui/pointer_transfer.gd")
	check(tap.contains("if native:hud.original_inventory_activate_selected(reference)"), "the second touch on an armed original slot uses the item")

func snapshot_user(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for file: String in dir.get_files(): user_files[path.path_join(file)] = FileAccess.get_file_as_bytes(path.path_join(file))
	for sub: String in dir.get_directories(): snapshot_user(path.path_join(sub))

func restore_user(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for sub: String in dir.get_directories(): restore_user(path.path_join(sub))
	for file: String in dir.get_files():
		var full: String = path.path_join(file)
		if not user_files.has(full): DirAccess.remove_absolute(full)
	for full: String in user_files:
		if full.get_base_dir() != path: continue
		var current: PackedByteArray = FileAccess.get_file_as_bytes(full) if FileAccess.file_exists(full) else PackedByteArray()
		if current != user_files[full]:
			var out := FileAccess.open(full, FileAccess.WRITE)
			if out != null: out.store_buffer(user_files[full]); out.close()

func touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = pressed
	root.push_input(event, true)

func tap(at: Vector2) -> void:
	touch(at, true); await process_frame
	touch(at, false); await frames(4)

func close_popups() -> void:
	hud.set("card_reveal_stage", null)
	for child: Node in hud.get_children():
		if str(child.name).begins_with("CardRevealLayer") or str(child.name).begins_with("EnhancementRevealLayer"):
			hud.remove_child(child); child.free()
	if hud.has_meta("patch523_reward_choice"):
		var choice: Variant = hud.get_meta("patch523_reward_choice")
		if is_instance_valid(choice): choice.queue_free()
		hud.remove_meta("patch523_reward_choice")
	for popup: Node in root.find_children("*", "AcceptDialog", true, false):
		if (popup as Window).visible: (popup as Window).hide(); popup.queue_free()
	for dialog: Node in hud.get_node("Root").get_children():
		if dialog.name == "TwilightConfirmation" and dialog.has_method("dismiss"): dialog.dismiss()

func open_bag() -> bool:
	if hud.original_inventory_is_open() and hud.active_section == "inventory": return true
	close_popups()
	if hud.original_inventory_is_open(): hud.toggle_inventory(); await frames(2)
	if hud.workspace != null and hud.workspace.visible and hud.has_method("_close_workspace"): hud._close_workspace()
	hud.toggle_inventory()
	await frames(6)
	return hud.original_inventory_is_open()

func reset() -> void:
	close_popups()
	# Ledgers that name the removed physical stacks go back with them.
	w.consumable_service.import_state(base.consumable.duplicate(true))
	w.card_draw_fusion.import_state(base.cards.duplicate(true))
	w.growth.state = base.growth.duplicate(true)
	w.inventory = {}; w.item_instances = {}; w.item_use_cooldowns = {}; w.active_item_buffs = {}
	for slot: String in w.equipped_items.keys(): w.equipped_items.erase(slot)
	w.patch523_owner_state_problem = ""; w.quest_service.save_blocked = false
	w.hp = maxi(1, w._effective_max_hp() / 2); w.mp = maxi(1, w._effective_max_mp() / 2)
	for i: int in w.quickslots.size(): w.quickslots[i] = null
	hud.message_label.text = ""
	w._update_hud(); hud.refresh_inventory(w.inventory)

func state() -> Dictionary:
	var equipped: Dictionary = {}
	for slot: String in w.equipped_items.keys(): equipped[slot] = str((w.equipped_items[slot] as Dictionary).get("instance_id", ""))
	var path: String = w.save_path()
	if w.background_save_pending(): w._finish_background_save(true)
	return {"inv":w.inventory.duplicate(true),"hp":w.hp,"mp":w.mp,"buffs":w.active_item_buffs.keys(),"equipped":equipped,
		"active":str(hud.active_section),"reveal":hud.is_card_reveal_busy(),"save":FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""}

## Accept a confirmation, a stat/target choice or claim the first original reward.
func accept(log: Array) -> void:
	for round: int in 3:
		var found: bool = false
		for dialog: Node in hud.get_node("Root").get_children():
			if dialog.name == "TwilightConfirmation" and not dialog.is_queued_for_deletion() and dialog.has_method("_accept"):
				log.append("confirm"); dialog.call("_accept"); found = true; break
		for popup: Node in root.find_children("*", "AcceptDialog", true, false):
			var dialog_window: AcceptDialog = popup as AcceptDialog
			if dialog_window.visible and not dialog_window.is_queued_for_deletion():
				log.append("choice"); dialog_window.confirmed.emit(); dialog_window.hide(); found = true; break
		if not found: break
		await frames(2)
	var choice: Variant = hud.get_meta("patch523_reward_choice") if hud.has_meta("patch523_reward_choice") else null
	if is_instance_valid(choice) and choice.has_method("original_rows"):
		var rows: Array = choice.call("original_rows")
		log.append("select:%d" % rows.size())
		if not rows.is_empty(): log.append("claim:" + str(choice.call("claim_entity", int(rows[0].entity_id))))

func reference(name: String) -> String:
	for entry: Dictionary in bag._inventory_entries():
		var ref: String = str(entry.get("reference", ""))
		if ref.get_slice("@@@", 0) == name and not (ref.contains("@@@") and w._is_instance_equipped(ref.get_slice("@@@", 1))): return ref
	return ""

func slot_point(ref: String) -> Vector2:
	var view: RefCounted = hud.original_main_ui_controller._inventory_view
	for attempt: int in 40:
		if view._hits.has(ref):
			var control: Control = view._hits[ref].control
			var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
			if str(hud.original_inventory_hit_at(point).get("reference", "")) == ref: return point
		var step := InputEventScreenDrag.new()
		step.index = 0; step.relative = Vector2(0, -60)
		view._forward_scroll_input(step)
		await process_frame
	return Vector2.INF

func marker(ref: String) -> String:
	var view: RefCounted = hud.original_main_ui_controller._inventory_view
	if not view._hits.has(ref): return "<no slot>"
	var node: Variant = view._hits[ref].native_slot_scene.get("source_nodes").get(SLOTS.ACTION)
	if not is_instance_valid(node) or not (node as Node2D).is_visible_in_tree(): return ""
	return str(node.get_meta("source_text").original_options.get("text", "")) if node.has_meta("source_text") else ""

func outcome(name: String, before: Dictionary, after: Dictionary, message: String) -> Dictionary:
	var used: int = int(before.inv.get(name, 0)) - int(after.inv.get(name, 0))
	var gained: bool = false
	for key: Variant in after.inv:
		if key != name and int(after.inv[key]) > int(before.inv.get(key, 0)): gained = true
	var effect: bool = gained or after.hp != before.hp or after.mp != before.mp or after.buffs != before.buffs or after.save != before.save or after.reveal
	return {"used":used,"effect":effect,"equipped":after.equipped != before.equipped,"window":after.active != before.active or after.reveal,"message":message.left(80)}

func meets(result: Dictionary, expected: String) -> bool:
	match expected:
		"consume": return result.used == 1 and result.effect
		"equip": return result.equipped
		"window": return result.window or (result.used == 1 and result.effect)
	return expected.begins_with("msg:") and result.message == expected.trim_prefix("msg:") and result.used == 0

func use_from_bag(name: String) -> Dictionary:
	if not await open_bag(): return {"error":"bag"}
	hud.refresh_inventory(w.inventory); await frames(2)
	var ref: String = reference(name)
	var at: Vector2 = await slot_point(ref) if not ref.is_empty() else Vector2.INF
	if not at.is_finite(): return {"error":"slot"}
	hud.message_label.text = ""; w.item_use_cooldowns = {}
	var before: Dictionary = state()
	await tap(at)
	var shown: String = marker(ref)
	if shown.is_empty(): return {"error":"no marker","marker":shown}
	await tap(at)
	var message: String = str(hud.message_label.text)
	var log: Array = []
	await frames(3); await accept(log); await frames(3)
	var result: Dictionary = outcome(name, before, state(), message)
	result["marker"] = shown; result["dialogs"] = log
	return result

func use_from_quick(name: String) -> Dictionary:
	close_popups()
	var ref: String = reference(name)
	if ref.is_empty(): return {"error":"no unit"}
	var reason: String = w._quickslot_registration_error("item", ref)
	if not reason.is_empty(): return {"error":reason}
	hud._emit_quickslot_assignment(0, "item", ref)
	await frames(2)
	hud.message_label.text = ""; w.item_use_cooldowns = {}
	var before: Dictionary = state()
	hud.quickslot_pressed.emit(0)
	var message: String = str(hud.message_label.text)
	var log: Array = []
	await frames(3); await accept(log); await frames(3)
	return outcome(name, before, state(), message)

func grant_button(id: int, presses: int) -> String:
	var record: Dictionary = w._catalog_item_from_source_id("m523:item:" + str(id))
	if record.is_empty(): return ""
	hud.catalog_category = "아이템"; hud.selected_catalog_record = record
	# The button's own handler (the button exists once the catalog panel is built).
	var button: Variant = hud.get("playtest_grant_button")
	for press: int in presses:
		if is_instance_valid(button): (button as Button).pressed.emit()
		else: hud._request_playtest_catalog_grant()
	w._update_hud(); hud.refresh_inventory(w.inventory)
	return str(record.name)

func runtime() -> void:
	snapshot_user("user://")
	root.size = Vector2i(2048, 919)
	w = load("res://Main.tscn").instantiate()
	root.add_child(w); w.set_process(false); w.save_timer = -100000
	if not check(QA.enter_game(w, "기사"), "actual Main map entry"): return
	hud = w.hud; bag = hud.lineage_inventory_ui
	w.field_population.set_process(false); w.player.set_physics_process(false)
	w._clear_monsters(); w._clear_drops()
	w.level = 85; w.gold = 100000000
	base = {"consumable":w.consumable_service.export_state().duplicate(true),"cards":w.card_draw_fusion.export_state().duplicate(true),"growth":w.growth.state.duplicate(true)}
	await frames(20)
	if not check(is_instance_valid(hud.get("original_main_ui_controller")) and await open_bag(), "the original bag opens"): return
	var table: Dictionary = {}
	for case: Array in CASES:
		var id: int = case[0]
		var expected: String = case[2]
		reset()
		var equip: bool = expected == "equip"
		var name: String = grant_button(id, 1 if equip else 2)
		if not check(not name.is_empty() and int(w.inventory.get(name, 0)) >= (1 if equip else 2), "#%d %s: the grant button puts it in the bag" % [id, case[1]]): continue
		var first: Dictionary = await use_from_bag(name)
		var ok: bool = check(meets(first, expected), "#%d %s: bag touch → %s (%s)" % [id, case[1], expected, JSON.stringify(first)])
		var row: Dictionary = {"bag":ok}
		if str(case[3]) != "":
			var quick: Dictionary = await use_from_quick(name)
			row["quick"] = check(meets(quick, str(case[3])), "#%d %s: quick slot → %s (%s)" % [id, case[1], case[3], JSON.stringify(quick)])
		if case[4]:
			reset()
			w.inventory[name] = 2; w._sync_item_instances(); w._save_game(true)
			var plain: Dictionary = await use_from_bag(name)
			row["old_save"] = check(meets(plain, expected), "#%d %s: old name balance → %s (%s)" % [id, case[1], expected, JSON.stringify(plain)])
		table[str(id)] = row
	evidence["cases"] = table
	reset()
	w.queue_free()
	await frames(4)
	restore_user("user://")

func run() -> void:
	rules()
	if not SOURCE.not_installed(): await runtime()
	print("ITEM_USE_UI_MATRIX_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
