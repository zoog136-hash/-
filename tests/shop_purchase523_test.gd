extends SceneTree
## NPC 상점 / 유료 상점 purchase (user report 2026-11-17: "상점 npc 구매가 안돼",
## "유료상점 구매 안돼 드래그도 안돼 ui도 없어").
## Always (synthetic, no original files):
##  - a list row button hands its finger's drag to its list (source_button_router
##    `source_drag_forward`): a short tap still activates, a drag scrolls and does
##    not activate (the phone's touch went only to the row button before);
##  - the original quantity keypad (Common_Calculator) count rules and its
##    fail-closed member check;
##  - purchases pay and deliver in one save (NPC: bag or refused; 유료: bag, or
##    the 보관함 when the bag cannot take it) — source contract.
## With the real 523 pack (--source523-pack, original UI pack): actual Main in
## Giran town (Locations473) -> the town merchant's original talk -> the
## original Store_All window -> row drag scrolls -> row tap opens the original
## keypad -> keypad taps (actual touch input) -> 확 인 -> adena paid, goods in
## the bag; the HUD 상점 -> original Shop_All with the original category tabs
## (MarketDisplayCategoryType) -> card drag scrolls -> tab tap switches the
## list -> card tap -> keypad -> game diamonds paid, goods in the bag.
## User report 2026-11-20 ("유료상점 구매안돼"): a refusal (다이아 0) was drawn
## under the full-screen window — the system message now sits above every
## original window, in the client's own words (DescData 268491); the original
## draw offers (MarketProduct UnitID 35, GotChaClass pools: 상급 변신/성물/
## 마법인형 뽑기) are bought and drawn from the original pools and weights; the
## tab bar / card list end at the shown screen, so every tab is reachable.
const ROUTER = preload("res://scripts/ui/original_ui/source_button_router.gd")
const BUTTON = preload("res://scripts/ui/original_ui/source_button.gd")
const CALCULATOR = preload("res://scripts/ui/original_ui/source_main_calculator.gd")
const SHOP_WINDOW = preload("res://scripts/ui/original_ui/source_main_shop_window.gd")
const STORE_WINDOW = preload("res://scripts/ui/original_ui/source_main_store_window.gd")
const RUNTIME = preload("res://scripts/shop/source523_shop_runtime.gd")
const GIRAN := Vector2i(33441, 32813)
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class FakePack extends RefCounted:
	var manifest: Dictionary = {"scenes": {}}

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		printerr("SHOP_PURCHASE523_FAIL: ", label)
	return value

func _initialize() -> void: call_deferred("run")

func run() -> void:
	await router_forwarding()
	calculator_rules()
	sources()
	await real_main()
	print("SHOP_PURCHASE523_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}))
	quit(0 if failures.is_empty() else 1)

## --- Synthetic -------------------------------------------------------------

func _button(host: Node2D, at: Vector2, activations: Array) -> Node2D:
	var button: Node2D = BUTTON.new()
	for state: String in ["normal", "pressed", "disabled"]:
		var picture := Control.new()
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(picture)
		button.states[state] = picture
	button.set_source_state("normal")
	button.bind_activation(func() -> Dictionary: activations.append(true); return {"ok": true}, Vector2(100, 40), true)
	button.position = at
	host.add_child(button)
	return button

func _touch(index: int, at: Vector2, down: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index; event.position = at; event.pressed = down
	return event

func _drag(index: int, at: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index; event.position = at; event.relative = relative
	return event

func router_forwarding() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var activations: Array = []
	var forwarded: Array = []
	var row: Node2D = _button(host, Vector2(100, 200), activations)
	row.set_meta(ROUTER.DRAG_META, func(event: InputEvent) -> void: forwarded.append(event))
	await process_frame
	var router = ROUTER.new()
	var centre := Vector2(150, 180)
	# A tap (no drag) activates the row and the list sees press + release.
	router.route(_touch(2, centre, true), centre, [row])
	router.route(_touch(2, centre, false), centre, [row])
	check(activations.size() == 1 and forwarded.size() == 2, "a tap on a list row activates it; the list sees the press and release")
	# A drag past the slop scrolls (every drag reaches the list) and the release does not activate.
	forwarded.clear()
	router.route(_touch(2, centre, true), centre, [row])
	for step: int in range(1, 5): router.route(_drag(2, centre + Vector2(0, -10 * step), Vector2(0, -10)), centre + Vector2(0, -10 * step), [row])
	var drags: int = forwarded.filter(func(e: InputEvent) -> bool: return e is InputEventScreenDrag).size()
	router.route(_touch(2, centre + Vector2(0, -2), false), centre + Vector2(0, -2), [row])
	check(drags == 4 and activations.size() == 1, "a drag over a list row reaches the list and does not activate the row")
	check(not router.is_capturing(), "the finger is released after the drag")
	# A small wobble (under the slop) still activates.
	router.route(_touch(2, centre, true), centre, [row])
	router.route(_drag(2, centre + Vector2(3, 2), Vector2(3, 2)), centre + Vector2(3, 2), [row])
	router.route(_touch(2, centre + Vector2(3, 2), false), centre + Vector2(3, 2), [row])
	check(activations.size() == 2, "a wobble under %d px still activates" % int(ROUTER.DRAG_SLOP))
	# A button without the meta keeps the old capture (no forwarding).
	var plain_hits: Array = []
	var plain: Node2D = _button(host, Vector2(400, 200), plain_hits)
	await process_frame
	var p := Vector2(450, 180)
	forwarded.clear()
	router.route(_touch(4, p, true), p, [plain])
	router.route(_drag(4, p + Vector2(0, -15), Vector2(0, -15)), p + Vector2(0, -15), [plain])
	router.route(_touch(4, p, false), p, [plain])
	check(forwarded.is_empty() and plain_hits.size() == 1, "a button outside a list keeps its own capture")
	host.queue_free()
	await process_frame

func calculator_rules() -> void:
	var keypad = CALCULATOR.new()
	check(keypad.configure(FakePack.new()).get("member") == CALCULATOR.ROOT, "the keypad fails closed without Common_Calculator")
	check(CALCULATOR.ROOT == "UI/CommonUi/Common_Calculator.csb", "the keypad is the original Common_Calculator")
	keypad.maximum = 25
	keypad.value = 1
	keypad.press_digit(3)
	check(keypad.value == 3, "the first digit replaces the shown count")
	keypad.press_digit(7)
	check(keypad.value == 25, "the count stops at the maximum (37 -> 25)")
	keypad.press_back()
	check(keypad.value == 2, "← drops the last digit")
	keypad.press_max()
	check(keypad.value == 25, "최대 sets the maximum")
	keypad.step(1)
	check(keypad.value == 25, "+ stays at the maximum")
	keypad.step(-1)
	check(keypad.value == 24, "- lowers by one")
	keypad.value = 0
	check(keypad.select().get("refused") == "count_zero", "확 인 refuses a zero count")
	# The keypad's malformed sound/text-id user data is metadata only (the
	# same reading as the floor-drop keypad, PR #647).
	var scene_text: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/sprite_scene.gd")
	check(scene_text.contains("custom={\"touchsoundid\":unquoted.get_string(1),\"textid\":unquoted.get_string(2)}"), "the keypad's touchsoundid/textid typo is read as its two metadata strings")

func sources() -> void:
	var store: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_store_window.gd")
	check(store.contains("buy_merchant\",id,amount,Runtime.Delivery.BAG)"), "an NPC 상점 purchase goes straight into the bag (or is refused)")
	check(store.contains("calculator.open(") and store.contains("forward_drag("), "the NPC 상점 uses the original keypad and forwards row drags")
	var shop: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_shop_window.gd")
	check(shop.contains("\"buy\",id,amount,Runtime.Delivery.BAG_OR_BOX)") and shop.contains("calculator.open("), "a 유료 상점 purchase uses the keypad and game currency, bag or 보관함")
	check(shop.contains("MarketDisplayCategoryType") and shop.contains("DisplayOnBmShopCategory"), "유료 상점 tabs are the original BM shop categories")
	var runtime: String = FileAccess.get_file_as_string("res://scripts/shop/source523_shop_runtime.gd")
	check(runtime.contains("enum Delivery {BOX, BAG, BAG_OR_BOX}") and runtime.contains("next.orders[order_id].status = \"claimed\""), "payment and delivery share one save")
	for path: String in ["res://scripts/ui/original_ui/source_main_calculator.gd", "res://scripts/ui/original_ui/source_main_shop_window.gd", "res://scripts/ui/original_ui/source_main_store_window.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		check(not text.contains("Image.create") and not text.contains("draw_rect") and not text.contains("Image.new"), "no picture is drawn: " + path.get_file())
	# 2026-11-20: refusal above the window, original words, draw offers.
	var hud_text: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(hud_text.contains("_system_message_scene.z_index=SYSTEM_MESSAGE_Z") and preload("res://scripts/ui/original_ui/source_main_hud.gd").SYSTEM_MESSAGE_Z > 170, "the system message is drawn over every original window (z %d > 170)" % preload("res://scripts/ui/original_ui/source_main_hud.gd").SYSTEM_MESSAGE_Z)
	check(SHOP_WINDOW.DIAMOND_SHORT_DESC == 268491 and shop.contains("reason==SHORT_REASON:reason=shortage_text(id)"), "다이아 부족 uses the client's DescData 268491 line")
	check(not SHOP_WINDOW._has_final("마일리지") and SHOP_WINDOW._has_final("명예 코인") and not SHOP_WINDOW._has_final(""), "the particle follows the currency name (마일리지가 / 명예 코인이)")
	check(RUNTIME.DRAW_UNIT == 35 and runtime.contains("inventory_tickets.market_draw_quote(draws)") and runtime.contains("inventory_tickets.market_draw(plan"), "draw offers (UnitID 35) are drawn through the original pool engine")
	var eleven: Array = [{"product_id": 1, "pool_id": 9, "count": 10}]
	RUNTIME._named_bonus_draw("상급 성물 뽑기 11회", eleven, 1)
	check(eleven.size() == 2 and int(eleven[1].count) == 1 and int(eleven[1].pool_id) == 9, "11회 with a 10-card product draws the named 11th from the same pool (TWILIGHT 근사)")
	var one: Array = [{"product_id": 1, "pool_id": 9, "count": 1}]
	RUNTIME._named_bonus_draw("상급 성물 뽑기 1회", one, 1)
	var twice: Array = [{"product_id": 1, "pool_id": 9, "count": 20}]
	RUNTIME._named_bonus_draw("상급 성물 뽑기 11회", twice, 2)
	check(one.size() == 1 and twice.size() == 2 and int(twice[1].count) == 2, "1회 is unchanged; 11회 x2 adds two")
	check(shop.contains("fit_list(_tab_content,TAB_BAR_WIDTH)") and shop.contains("fit_list(content,LIST_SIZE.x)"), "the tab bar and the card list end at the shown screen")
	# No real payment path.
	check(not shop.contains("OS.shell_open") and not shop.contains("billing"), "the 유료 상점 has no real payment")

## --- Real pack, actual Main ---------------------------------------------------

func _find_script(node: Node, file: String) -> Node:
	var script: Variant = node.get_script()
	if script != null and str(script.resource_path).ends_with(file): return node
	for child: Node in node.get_children():
		var found: Node = _find_script(child, file)
		if found != null: return found
	return null

func touch(point: Vector2, down: bool, index: int = 3) -> void:
	root.push_input(_touch(index, point, down), true)

func drag(from: Vector2, to: Vector2, steps: int = 8, index: int = 3) -> void:
	touch(from, true, index)
	await process_frame
	var last: Vector2 = from
	for step: int in range(1, steps + 1):
		var at: Vector2 = from.lerp(to, float(step) / float(steps))
		root.push_input(_drag(index, at, at - last), true)
		last = at
		await process_frame
	touch(to, false, index)
	await process_frame

func tap(point: Vector2) -> void:
	touch(point, true)
	await process_frame
	touch(point, false)
	await process_frame

static func button_point(node: Variant) -> Vector2:
	var button: Variant = node.get_meta("source_button") if node is Node and is_instance_valid(node) and node.has_meta("source_button") else (node if node is Node2D and node.has_method("handle_native_touch") else null)
	var area: Variant = button.get("_input_area") if is_instance_valid(button) else null
	if not area is Control: return Vector2.INF
	return (area as Control).get_global_transform_with_canvas() * ((area as Control).size * 0.5)

static func first_button(node: Node, visible_only: bool = false) -> Variant:
	if visible_only and node is CanvasItem and not (node as CanvasItem).visible: return null
	if node.has_meta("source_button"): return node
	for child: Node in node.get_children():
		var found: Variant = first_button(child, visible_only)
		if found != null: return found
	return null

## The first button of `node` the HUD router can give a press (Common_Slot
## controls stay PointerTransfer's): a store row's Btn_Calculator.
static func routable_button(node: Node) -> Variant:
	var found: Array = []
	preload("res://scripts/ui/original_ui/source_main_hud.gd")._collect_native_buttons(node, found)
	return _owner_of(node, found)

static func _slot_root(node: Node) -> Node:
	if node.has_meta("source_slot_routed"): return node
	for child: Node in node.get_children():
		var hit: Node = _slot_root(child)
		if hit != null: return hit
	return null

static func _owner_of(node: Node, found: Array) -> Variant:
	if node is CanvasItem and not (node as CanvasItem).visible: return null
	if node.has_meta("source_button") and found.has(node.get_meta("source_button")) and node.get_meta("source_button").call("_input_available"): return node
	for child: Node in node.get_children():
		var hit: Variant = _owner_of(child, found)
		if hit != null: return hit
	return null

## The keypad button named `name` of an open keypad.
static func keypad_point(keypad: RefCounted, suffix: String) -> Vector2:
	var located: Dictionary = preload("res://scripts/ui/original_ui/source_main_named_tree.gd").locate(keypad.get("_scene"), keypad.get("_out"), suffix)
	if not located.get("ok", false): return Vector2.INF
	return button_point(located.player.source_nodes.get(located.offset))

## Which original button the HUD router would give a press at `point`.
static func hit_report(ctl: Object, point: Vector2, wanted: Variant) -> Dictionary:
	var found: Array = []
	ctl.call("_collect_native_buttons", ctl.get("_coordinates"), found)
	var want: Variant = wanted.get_meta("source_button") if wanted is Node and wanted.has_meta("source_button") else null
	var hits: Array = []
	for button: Variant in found:
		if not is_instance_valid(button): continue
		if button.call("_hit_viewport", point):
			var owner: Node = button.get_parent()
			while owner != null and not owner.has_meta("original_ui_source"): owner = owner.get_parent()
			hits.append({"wanted": button == want, "available": button.call("_input_available"), "source": owner.get_meta("original_ui_source") if owner != null else {}})
		if hits.size() >= 4: break
	var clips: Array = []
	if want is Node2D:
		var area: Variant = want.get("_input_area")
		if area is Control: clips.append({"self": str((area as Control).get_global_rect()), "contains": want.call("_control_contains", area, point)})
		var ancestor: Node = area.get_parent() if area is Control else null
		while ancestor != null:
			if ancestor is Control and (ancestor as Control).clip_contents: clips.append({"clip": str((ancestor as Control).get_global_rect()), "name": str(ancestor.name), "contains": want.call("_control_contains", ancestor, point)})
			ancestor = ancestor.get_parent()
	return {"point": str(point), "wanted_found": found.has(want), "hits": hits, "clips": clips}

func real_main() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for frame: int in 120: await process_frame
	var picker: Node = _find_script(root, "renewal_class_select.gd")
	if picker != null:
		picker.call("_choose", "기사")
		if picker.has_method("_choose_gender"): picker.call("_choose_gender", 1)
		picker.call("_confirm")
	else: preload("res://tests/qa_class_selection.gd").enter_game(world)
	for frame: int in 900:
		await process_frame
		if world.current523_aden_source_active(): break
	var ctl: Variant = world.hud.get("original_main_ui_controller")
	if not world.current523_aden_source_active() or not is_instance_valid(ctl) or not ctl.call("can_open_shop_window"):
		evidence["real_main"] = "original 523 map / original UI pack not installed: Main part skipped"
		world.queue_free(); for frame: int in 3: await process_frame
		return
	world.save_timer = -100000
	var here: Dictionary = world.orim_current_land()
	if int(here.get("land_id", -1)) != 4 or absi(int(here.cell[0]) - GIRAN.x) > 30 or absi(int(here.cell[1]) - GIRAN.y) > 30:
		# Until the Giran start (#631) is on main: walk the character to Giran's
		# original restart point (Locations473) on the same Land 4 field.
		var entered: bool = world.call("_aden_play_controller").enter_source_land(4, [GIRAN.x - 5, GIRAN.y - 5, GIRAN.x + 5, GIRAN.y + 5], world.ITEM523_TELEPORT_WAIVE.duplicate())
		for frame: int in 60: await process_frame
		evidence["giran_entry"] = {"entered": entered, "problem": str(world.call("_aden_play_controller").get("problem"))}
	here = world.orim_current_land()
	evidence["land"] = here
	var cell: Array = here.get("cell", [0, 0]) if here.get("cell") is Array else [0, 0]
	if not check(int(here.get("land_id", -1)) == 4 and absi(int(cell[0]) - GIRAN.x) <= 30 and absi(int(cell[1]) - GIRAN.y) <= 30, "the character stands in Giran town (%s)" % str(here)):
		world.queue_free(); for frame: int in 3: await process_frame
		return
	await npc_store(world, ctl)
	await cash_shop(world, ctl)
	world.queue_free()
	for frame: int in 3: await process_frame

func npc_store(world: Node, ctl: Object) -> void:
	var hud: Node = world.hud
	var merchants: Array = []
	for npc: Dictionary in world.field_map.data.get("npc_spawn", []):
		var at: Array = npc.get("source_position", [])
		if "shop" in npc.get("source523_actions", []) and at.size() == 2 and absi(int(at[0]) - GIRAN.x) <= 60 and absi(int(at[1]) - GIRAN.y) <= 60: merchants.append(npc)
	evidence["giran_merchants"] = merchants.map(func(n: Dictionary) -> Array: return [n.id, n.name])
	if not check(not merchants.is_empty(), "Giran town has an original merchant NPC (SellList)"): return
	world.gold = 5000000
	world._update_hud()
	var window: Object = null
	var opened: Dictionary = {}
	var npc: Dictionary = {}
	for candidate: Dictionary in merchants:
		world.player.global_position = Vector2(float(candidate.position[0]), float(candidate.position[1])) + Vector2(20, 0)
		await process_frame
		hud.open_npc_dialogue(str(candidate.id))
		for frame: int in 5: await process_frame
		var talk: Node = _find_script(hud, "renewal_dialogue.gd")
		for guard: int in 10:
			if talk == null or not is_instance_valid(talk): break
			var choices: Array = talk.source_dialogue_model.get("choices", [])
			if choices.is_empty(): break
			var action: String = str(choices[0].action)
			talk.call("_choice_picked", str(choices[0].next), action)
			for frame: int in 3: await process_frame
			if not action.is_empty(): break
		for frame: int in 3: await process_frame
		opened = hud.original_main_ui_status.get("store_window", {})
		window = ctl.get("_store_window")
		if window != null and window.is_open() and not window.goods().is_empty(): npc = candidate; break
		if window != null: window.close()
		hud.call("_close_workspace")
		for frame: int in 2: await process_frame
	evidence["store_open"] = opened
	if not check(window != null and window.is_open() and opened.get("handled", false), "talking to the Giran merchant opens the original Store_All window"): return
	var goods: Array = window.goods()
	evidence["store"] = {"npc": npc.get("name", ""), "goods": goods.size(), "first": goods.slice(0, 6)}
	check(goods.size() >= 3 and goods.all(func(g: Dictionary) -> bool: return int(g.class_id) > 0), "the merchant lists its original MerchantGoods rows")
	var index: int = -1
	for at: int in goods.size():
		if bool(goods[at].ok) and int(goods[at].price) > 0 and int(goods[at].price) * 3 <= int(world.gold): index = at; break
	if not check(index >= 0, "a priced product can be bought"): return
	# The old route (before this fix): buy_merchant's default 보관함 delivery
	# left the bag unchanged (the user saw "구매가 안돼").
	var old_name: String = str(goods[index].name)
	var old_bag: int = int(world.inventory.get(old_name, 0))
	var old_route: Dictionary = world.source_shop.buy_merchant(int(goods[index].id), 1)
	evidence["old_box_route"] = {"result_reason": str(old_route.get("reason", "")), "bag_before": old_bag, "bag_after": int(world.inventory.get(old_name, 0)), "pending": world.source_shop.orders().size()}
	check(old_route.get("ok", false) and int(world.inventory.get(old_name, 0)) == old_bag and world.source_shop.orders().size() == 1, "repro: the old route paid and left the goods in the 보관함, not the bag")
	if old_route.get("ok", false): world.source_shop.claim(str(old_route.order_id))
	# Drag the list by a row button (the whole list is row buttons).
	var list: Object = window.get("_list")
	var content: Node2D = list.content
	var row_button: Variant = first_button(content)
	var start: Vector2 = button_point(row_button)
	var before_y: float = content.position.y
	await drag(start, start + Vector2(0, -150))
	var scrolled: bool = not is_equal_approx(list.content.position.y, before_y) if is_instance_valid(list.content) else false
	evidence["store_drag"] = {"before": before_y, "after": list.content.position.y if is_instance_valid(list.content) else null, "rows": goods.size()}
	if goods.size() > 6: check(scrolled, "dragging a product row scrolls the goods list")
	check(not window.calculator.is_open(), "the drag does not open a purchase")
	# Drag back from inside the list (the finger lands on another row).
	await drag(start, start + Vector2(0, 150))
	evidence["store_drag_back"] = list.content.position.y if is_instance_valid(list.content) else null
	check(is_instance_valid(list.content) and is_equal_approx(list.content.position.y, before_y), "dragging back down returns the list to its top")
	# Tap the row's product picture slot -> the keypad.
	for frame: int in 3: await process_frame
	content = list.content
	var row_scene: Node = content.get_child(index)
	var slot_root: Node = _slot_root(row_scene)
	var tapped: Variant = routable_button(slot_root) if slot_root != null else null
	check(tapped != null, "the row's product picture slot (Common_Slot) is handed to the router")
	if tapped == null: tapped = routable_button(row_scene)
	evidence["row_hit"] = hit_report(ctl, button_point(tapped), tapped)
	await tap(button_point(tapped))
	for frame: int in 2: await process_frame
	if not check(window.calculator.is_open(), "tapping a product opens the original quantity keypad (Common_Calculator)"):
		evidence["store_direct"] = window.call("_buy_requested", index)
		evidence["store_keypad"] = window.calculator.last_result
	if not window.calculator.is_open(): return
	var gold_before: int = int(world.gold)
	var bag_before: Dictionary = world.inventory.duplicate(true)
	var name: String = str(goods[index].name)
	await tap(keypad_point(window.calculator, "Nd_Keypad/Btn_No_3"))
	check(window.calculator.value == 3, "keypad digit taps set the count (%d)" % window.calculator.value)
	await tap(keypad_point(window.calculator, "Btn_Select"))
	for frame: int in 5: await process_frame
	var bought: Dictionary = window.get("last_purchase")
	var unit: int = int(goods[index].price)
	evidence["store_purchase"] = {"name": name, "unit": unit, "result": bought.duplicate(true), "gold": [gold_before, world.gold], "bag": [bag_before.get(name, 0), world.inventory.get(name, 0)]}
	check(bought.get("ok", false) and bought.get("delivered", false), "확 인 buys: " + str(bought.get("reason", "")))
	check(int(world.gold) == gold_before - unit * 3, "the adena price x3 is paid (%d -> %d)" % [gold_before, int(world.gold)])
	var amount: int = int(world.source_shop.state.orders.get(str(bought.get("order_id", "")), {}).get("goods", [{}])[0].get("amount", 0))
	check(amount > 0 and int(world.inventory.get(name, 0)) == int(bag_before.get(name, 0)) + amount, "the goods are in the bag, stacked on the same item (%s +%d)" % [name, amount])
	check(world.source_shop.orders().is_empty(), "no 보관함 order is left behind")
	window.close()
	hud.call("_close_workspace")
	for frame: int in 3: await process_frame

## 카드&장비 (first tab): 다이아 0 -> the client's refusal above the window;
## funded -> the draw card -> keypad -> 확 인 -> drawn from the original pool.
func draw_offer(world: Node, ctl: Object, window: Object) -> void:
	window.select_tab(0)
	for frame: int in 3: await process_frame
	var products: Array = window.call("_products")
	var at_card: int = -1
	for at: int in products.size():
		for relation: Dictionary in world.source_shop.catalog._related("MarketPurchaseProduct", int(products[at].id)):
			if int(world.source_shop.catalog.record("MarketProduct", int(relation.MarketProductID)).get("UnitID", 0)) == RUNTIME.DRAW_UNIT: at_card = at
		if at_card >= 0: break
	if not check(at_card >= 0, "카드&장비 lists an original draw offer"): return
	var saved_diamonds: int = int(world.inventory.get("다이아", 0))
	world.inventory["다이아"] = 0
	var card: Variant = routable_button(window.get("_content").get_child(at_card))
	await tap(button_point(card))
	for frame: int in 3: await process_frame
	var message: Dictionary = world.hud.original_main_ui_status.get("system_message", {})
	var scene: Variant = ctl.get("_system_message_scene")
	evidence["draw_refusal"] = {"text": message.get("text", ""), "z": scene.z_index if scene is Node2D else -1}
	check(not window.calculator.is_open() and str(message.get("text", "")) == "보유한 다이아가 부족하여 아이템을 구매할 수 없습니다.", "다이아 0: the client's own refusal line (%s)" % str(message.get("text", "")))
	check(scene is Node2D and (scene as Node2D).visible and (scene as Node2D).z_index > int(window.get("_scene").z_index), "the refusal is drawn above Shop_All")
	world.inventory["다이아"] = 100000
	var cards_before: Dictionary = world.card_draw_fusion.export_state()
	await tap(button_point(routable_button(window.get("_content").get_child(at_card))))
	for frame: int in 2: await process_frame
	if not check(window.calculator.is_open(), "a funded draw card opens the keypad"): return
	await tap(keypad_point(window.calculator, "Btn_Select"))
	for frame: int in 5: await process_frame
	var bought: Dictionary = window.get("last_purchase")
	evidence["draw_purchase"] = {"name": bought.get("name", ""), "reason": bought.get("reason", ""), "draws": bought.get("draw_results", []).size(), "diamonds": world.inventory.get("다이아", 0)}
	check(bought.get("ok", false) and bought.get("draw_results", []).size() >= 1, "the draw offer is bought and drawn: " + str(bought.get("reason", "")))
	check(world.card_draw_fusion.export_state() != cards_before, "the drawn cards are owned")
	var stage: Variant = world.hud.get("card_reveal_stage")
	if is_instance_valid(stage):
		stage.emit_signal("finished"); stage.queue_free()
	for frame: int in 3: await process_frame
	world.inventory["다이아"] = saved_diamonds
	window.set("last_purchase", {})

func cash_shop(world: Node, ctl: Object) -> void:
	var hud: Node = world.hud
	hud.open_shop()
	for frame: int in 5: await process_frame
	var status: Dictionary = hud.original_main_ui_status.get("shop_window", {})
	var window: Object = ctl.get("_shop_window")
	evidence["shop_window"] = status
	if not check(window.is_open() and status.get("handled", false), "상점 opens the original Shop_All window"): return
	var tabs: Array = window.tabs
	evidence["tabs"] = tabs.map(func(t: Dictionary) -> Array: return [t.id, t.name, t.products.size()])
	check(tabs.size() >= 5 and int(status.get("tabs_built", 0)) == tabs.size(), "the original BM shop category tabs are built (%d)" % tabs.size())
	check(tabs.map(func(t: Dictionary) -> int: return int(t.id)).has(5) and tabs.map(func(t: Dictionary) -> int: return int(t.id)).has(31), "카드&장비 and 마일리지 categories are tabs")
	await draw_offer(world, ctl, window)
	# Card drag scrolls the horizontal list.
	var content: Node2D = window.get("_content")
	var before_x: float = content.position.x
	var start: Vector2 = button_point(first_button(content))
	await drag(start, start + Vector2(-400, 0))
	evidence["shop_drag"] = {"before": before_x, "after": window.get("_content").position.x}
	if int(status.get("cards", 0)) > 6: check(window.get("_content").position.x < before_x - 50.0, "dragging a product card scrolls the list")
	check(not window.calculator.is_open(), "the drag does not open a purchase")
	# Tap another tab: its products replace the list.
	var tab_content: Node2D = window.get("_tab_content")
	if check(is_instance_valid(tab_content) and tab_content.get_child_count() == tabs.size(), "one original tab button per category"):
		var target_tab: int = -1
		for at: int in range(1, tabs.size()):
			for id: int in tabs[at].products:
				if world.source_shop.quote(id, 1).get("ok", false) or str(world.source_shop.quote(id, 1).get("reason", "")).contains("부족"): target_tab = at; break
			if target_tab >= 0: break
		if target_tab < 0: target_tab = 1
		var tab_button: Variant = first_button(window.get("_tab_content").get_child(target_tab), true)
		var tab_point: Vector2 = button_point(tab_button)
		evidence["tab_hit"] = hit_report(ctl, tab_point, tab_button)
		await tap(tab_point)
		for frame: int in 3: await process_frame
		evidence["tab_tap"] = {"point": str(tab_point), "tab": window.tab, "target": target_tab, "result": window.get("last_result")}
		check(window.tab == target_tab and int(window.get("last_result").get("cards", -1)) == mini(tabs[target_tab].products.size(), SHOP_WINDOW.MAX_CARDS), "tapping a tab lists that category (%s)" % str(tabs[target_tab].name))
	# Buy one offer paid in a game currency.
	var offer: int = -1
	var quote: Dictionary = {}
	var offer_tab: int = -1
	for at: int in tabs.size():
		for id: int in tabs[at].products:
			var q: Dictionary = world.source_shop.quote(id, 1)
			if not q.get("ok", false) and str(q.get("reason", "")) == "구매 재화가 부족합니다":
				# Fund the price in its own game currency (its first original source).
				var price: Dictionary = world.source_shop.catalog.payment_quote(id, 1)
				var sources: Array = world.source_shop.catalog.currency(int(price.class_id)).get("sources", []) if int(price.get("unit_id", 0)) == 201 else [{"UnitID": int(price.unit_id), "ClassID": int(price.class_id)}]
				var saved_gold: int = int(world.gold)
				var saved_bag: Dictionary = world.inventory.duplicate(true)
				for source: Dictionary in sources:
					var resolved: Dictionary = world.source_shop.call("_resolve", world.source_shop.call("_token", int(source.UnitID), int(source.ClassID), int(price.total)), false, world.inventory, int(world.gold))
					if not resolved.get("ok", false): continue
					if resolved.binding.get("gold", false): world.gold = int(price.total) * 10
					else: world.inventory[str(resolved.binding.name)] = int(price.total) * 10
					evidence["cash_funding"] = {"currency": str(resolved.binding.get("name", "adena")), "amount": int(price.total) * 10}
					break
				q = world.source_shop.quote(id, 1)
				if not q.get("ok", false):
					world.gold = saved_gold
					world.inventory = saved_bag
			if q.get("ok", false) and int(q.get("payment", {}).get("unit_id", 37)) != 37:
				offer = id; quote = q; offer_tab = at
				break
		if offer >= 0: break
	if not check(offer >= 0, "a 유료 상점 offer is sold for game currency"): return
	window.select_tab(offer_tab)
	for frame: int in 2: await process_frame
	quote = world.source_shop.quote(offer, 1)
	evidence["cash_offer"] = {"id": offer, "quote_ok": quote.get("ok", false), "reason": quote.get("reason", ""), "payment": quote.get("payment", {}), "currency": quote.get("payment_binding", {}).get("name", "")}
	if not check(quote.get("ok", false), "the chosen offer can be paid: " + str(quote.get("reason", ""))): return
	var binding: Dictionary = quote.payment_binding
	check(int(quote.payment.unit_id) != 37, "the payment is a game currency, never a store payment")
	var wallet_before: int = int(world.gold) if binding.get("gold", false) else int(world.inventory.get(str(binding.name), 0))
	var bag_before: Dictionary = world.inventory.duplicate(true)
	# Tap the offer's card (scrolled into view) like a finger.
	var products: Array = window.call("_products")
	var at_card: int = -1
	for at: int in products.size():
		if int(products[at].id) == offer: at_card = at
	window.set("_scroll", -SHOP_WINDOW.COLUMN_WIDTH * float(floori(at_card / 2.0)))
	window.refresh()
	for frame: int in 3: await process_frame
	var cards: Node2D = window.get("_content")
	var card_button: Variant = routable_button(cards.get_child(at_card)) if at_card >= 0 and at_card < cards.get_child_count() else null
	var card_point: Vector2 = button_point(card_button)
	evidence["card_hit"] = hit_report(ctl, card_point, card_button)
	await tap(card_point)
	for frame: int in 2: await process_frame
	evidence["cash_keypad"] = {"card": at_card, "keypad": window.calculator.last_result}
	check(window.calculator.is_open(), "tapping a card opens the original quantity keypad")
	if not window.calculator.is_open(): return
	await tap(keypad_point(window.calculator, "Btn_Select"))
	for frame: int in 5: await process_frame
	var bought: Dictionary = window.get("last_purchase")
	var wallet_after: int = int(world.gold) if binding.get("gold", false) else int(world.inventory.get(str(binding.name), 0))
	var gained: Dictionary = {}
	for key: Variant in world.inventory:
		if int(world.inventory[key]) > int(bag_before.get(key, 0)) and str(key) != str(binding.get("name", "")): gained[key] = int(world.inventory[key]) - int(bag_before.get(key, 0))
	evidence["cash_purchase"] = {"result": bought.duplicate(true), "wallet": [wallet_before, wallet_after], "gained": gained}
	check(bought.get("ok", false), "확 인 buys the offer: " + str(bought.get("reason", "")))
	check(wallet_after == wallet_before - int(quote.payment.amount), "the game currency price is paid")
	check(bought.get("delivered", false) and not gained.is_empty(), "the offer's goods are in the bag")
	window.close()
	hud.call("_close_workspace")
	for frame: int in 3: await process_frame
