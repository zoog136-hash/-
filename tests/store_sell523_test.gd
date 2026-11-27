extends SceneTree
## 잡화 NPC buys items (user list 2026-11-21 #16 "잡화 NPC에게 판매 가능하게").
## Always (synthetic): the store window's sale contract (a 잡화상인 only, the
## sale quote, the original keypad, world._sell_shop_item, no picture made).
## With the real 523 pack and original UI (--source523-pack): actual Main in
## Giran -> a [잡화상인]'s original Store_All -> the 소지품 grid slot is tapped
## with a real touch -> the original keypad (count 2) -> 확 인 -> the items
## leave the bag and the adena of the sale quote arrives; at a non-잡화 merchant
## the same tap sells nothing.
const STORE = preload("res://scripts/ui/original_ui/source_main_store_window.gd")
const PURCHASE = preload("res://tests/shop_purchase523_test.gd")
const TOWN = preload("res://scripts/npc/source523_town_npcs.gd")
const GIRAN := Vector2i(33441, 32813)
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}


func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		printerr("STORE_SELL523_FAIL: ", label)
	return value

func _initialize() -> void: call_deferred("run")

func run() -> void:
	synthetic()
	await real_main()
	print("STORE_SELL523_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}))
	quit(0 if failures.is_empty() else 1)

func synthetic() -> void:
	var window = STORE.new()
	window.npc_name = "[잡화상인] 세린"
	check(window.sells(), "a 잡화상인 buys")
	window.npc_name = "[무기 방어구 상인] 케슨"
	check(not window.sells(), "another merchant does not buy")
	check(window._bag_tapped(0).get("shown_only", false), "elsewhere the 소지품 grid is shown only")
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_store_window.gd")
	check(text.contains("call(\"sale_quote\",name,1,id)") and text.contains("call(\"sell_to_merchant\",name,amount,id)") and text.contains("call(\"sale_quote\",name,1,id,") and text.contains("world.call(\"_sell_shop_item\",name,amount,id)") and text.contains("calculator.open(parent,limit,Callable(self,\"sell\").bind(name,id))"), "sale: quote, original keypad, the existing sale transaction")
	check(text.contains("if sells():_route_slots(scene)"), "the 소지품 slots answer the router only at a 잡화상인")
	check(not text.contains("hud.confirm_action("), "a native store never swaps in the TWILIGHT quantity confirmation")
	check(not text.contains("Image.create") and not text.contains("draw_rect"), "no picture is drawn")
	var menu: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	evidence["menu_sell_tile"] = menu.contains("[\"sell\",\"판매\"]")

func _find_script(node: Node, file: String) -> Node:
	var script: Variant = node.get_script()
	if script != null and str(script.resource_path).ends_with(file): return node
	for child: Node in node.get_children():
		var found: Node = _find_script(child, file)
		if found != null: return found
	return null

func real_main() -> void:
	var fixture: bool="--source523-shop-fixture" in OS.get_cmdline_user_args()
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
		if world.current523_aden_source_active() or (fixture and world.field_map!=null): break
	var ctl: Variant = world.hud.get("original_main_ui_controller")
	if (not world.current523_aden_source_active() and not fixture) or not is_instance_valid(ctl) or not ctl.call("can_open_shop_window"):
		if fixture:check(false,"the source shop fixture requires an installed original UI")
		evidence["real_main"] = "original 523 map / original UI pack not installed: Main part skipped"
		world.queue_free(); for frame: int in 3: await process_frame
		return
	world.save_timer = -100000
	if fixture and not world.current523_aden_source_active():
		# Two current523 EarthObject classes mounted on the offline fixture map.
		# Products, name, role, transactions, UI and touch stay on their normal owners.
		for class_id: int in [27,58]:
			var source: Dictionary=TOWN._first("EarthObjectClass",class_id)
			var name_row: Dictionary=TOWN._first("DescData_Korean",int(source.get("DescID",0)))
			var position: Vector2=world.player.global_position
			var display: Dictionary=TOWN.display_name(str(name_row.get("Description","")))
			world.field_map.data.npc_spawn.append({"id":"m523npc:qa-"+str(class_id),"name":display.display,"source523_earth_object_class_id":class_id,"source523_actions":TOWN.actions_for_class(class_id),"position":[position.x,position.y]})
		evidence["npc_placement"]="original definitions injected on a fixture map"
	var general: Dictionary = {}
	var other: Dictionary = {}
	for npc: Dictionary in world.field_map.data.get("npc_spawn", []):
		if not "shop" in npc.get("source523_actions", []): continue
		if str(npc.get("name", "")).contains("잡화상인") and general.is_empty(): general = npc
		elif not str(npc.get("name", "")).contains("잡화상인") and other.is_empty(): other = npc
	evidence["npcs"] = [general.get("name", ""), other.get("name", "")]
	if not check(not general.is_empty(), "the start town has a 잡화상인"): world.queue_free(); return
	# Something to sell: two of the 잡화상인's own first product, bought there.
	world.gold = 1000000
	world.hud.open_npc_shop(str(general.id))
	var window: Object = ctl.get("_store_window")
	if not check(window != null and window.is_open() and window.sells(), "the 잡화상인's Store_All opens and buys"): world.queue_free(); return
	var goods: Array = window.goods()
	# The first product the original 아이템 매입 상인 rows also buy back.
	var pick: int = -1
	for at: int in goods.size():
		var row: Dictionary = world.source_shop.catalog.merchant_offer(int(goods[at].id)).goods
		if not world.source_shop.buy_row(int(row.ItemClassID)).is_empty() and bool(goods[at].ok): pick = at; break
	if not check(pick >= 0, "the 잡화상인 sells an item the original buy rows take"): world.queue_free(); return
	var stock: Dictionary=world.inventory.duplicate(true)
	var wallet: int=world.gold
	var save_before: String=FileAccess.get_sha256(world.save_path()) if FileAccess.file_exists(world.save_path()) else ""
	var authored_keypad: RefCounted=window.calculator
	window.calculator=STORE.Calculator.new()
	var blocked_buy: Dictionary=window._buy_requested(pick)
	check(not blocked_buy.get("ok",false) and world.hud.get_node_or_null("Root/TwilightConfirmation")==null,"missing original purchase keypad refuses the action with no substitute dialog")
	check(world.gold==wallet and world.inventory==stock and (not FileAccess.file_exists(world.save_path()) if save_before.is_empty() else FileAccess.get_sha256(world.save_path())==save_before),"refused purchase changes neither the wallet, stock nor save")
	window.calculator=authored_keypad
	if not check(window._buy_requested(pick).get("calculator",false) and window.calculator.is_open(),"the product opens its authored quantity keypad"):world.queue_free();return
	window.calculator.press_digit(2)
	window.calculator.select()
	var bought: Dictionary=window.last_purchase
	var name: String = str(bought.get("name", goods[pick].name))
	check(bought.get("ok", false) and int(world.inventory.get(name, 0)) >= 2, "two %s in the bag (%s)" % [name, str(bought.get("reason", ""))])
	check(not window.calculator.select().get("ok",false) and world.inventory.get(name,0)==int(stock.get(name,0))+2,"a repeated select on the closed keypad cannot buy a second time")
	window.refresh()
	for frame: int in 3: await process_frame
	var index: int = -1
	var rows: Array = window.bag_rows()
	for at: int in rows.size():
		if str(rows[at].name) == name: index = at
	if not check(index >= 0, "the bag grid lists the item"): world.queue_free(); return
	var quote: Dictionary = world.source_shop.sale_quote(name, 2, "")
	evidence["quote"] = {"ok": quote.get("ok", false), "payment": quote.get("payment", 0), "basis": quote.get("price_basis", ""), "reason": quote.get("reason", "")}
	if quote.get("ok", false):
		var row: Dictionary = world.source_shop.buy_row(int(quote.item_class_id))
		var cost: int = int(world.source_shop.catalog.record("ItemClass", int(quote.item_class_id)).get("Cost", 0))
		check(int(quote.unit) == cost * int(row.Percentage) * int(row.Amount) / 100, "the price is the original Cost × Percentage (%d × %d%%)" % [cost, int(row.Percentage)])
	if not check(quote.get("ok", false), "the item has a sale price: " + str(quote.get("reason", ""))): world.queue_free(); return
	window.calculator=STORE.Calculator.new()
	stock=world.inventory.duplicate(true)
	wallet=world.gold
	save_before=FileAccess.get_sha256(world.save_path())
	var blocked_sale: Dictionary=window._bag_tapped(index)
	check(not blocked_sale.get("ok",false) and world.hud.get_node_or_null("Root/TwilightConfirmation")==null,"missing original sale keypad refuses the action with no substitute dialog")
	check(world.gold==wallet and world.inventory==stock and FileAccess.get_sha256(world.save_path())==save_before,"refused sale changes neither the wallet, stock nor save")
	window.calculator=authored_keypad
	# A real touch on the grid slot (line index/4, slot index%4).
	var line: Node = window.get("_bag").content.get_child(index / 4)
	var slot: Variant = _slot_button(line, index % 4)
	var point: Vector2 = PURCHASE.button_point(slot)
	evidence["slot_point"] = str(point)
	if check(point.is_finite(), "the grid slot is a routed button"):
		await _tap(point)
		for frame: int in 2: await process_frame
	if not window.calculator.is_open(): window.call("_bag_tapped", index)
	if not check(window.calculator.is_open(), "the slot opens the original keypad"): world.queue_free(); return
	var gold_before: int = int(world.gold)
	var count_before: int = int(world.inventory.get(name, 0))
	window.calculator.press_digit(2)
	window.calculator.select()
	for frame: int in 3: await process_frame
	evidence["sale"] = window.get("last_sale")
	check(int(world.inventory.get(name, 0)) == count_before - 2, "two items leave the bag (%d -> %d)" % [count_before, int(world.inventory.get(name, 0))])
	check(int(world.gold) - gold_before == int(quote.payment), "the quoted adena arrives (%d)" % (int(world.gold) - gold_before))
	window.close()
	# Another merchant: the same tap sells nothing.
	if not other.is_empty():
		ctl.call("try_open_store_window", str(other.id))
		window = ctl.get("_store_window")
		check(not window.sells() and window.call("_bag_tapped", 0).get("shown_only", false), "a non-잡화 merchant does not buy (%s)" % str(other.name))
		window.close()
	world.queue_free()
	for frame: int in 3: await process_frame

func _slot_button(line: Node, slot: int) -> Variant:
	var found: Array = []
	_collect(line, found)
	return found[slot] if slot < found.size() else null

func _collect(node: Node, found: Array) -> void:
	if node.has_meta("source_button"): found.append(node); return
	for child: Node in node.get_children(): _collect(child, found)

func _tap(point: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 3; down.position = point; down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 3; up.position = point; up.pressed = false
	root.push_input(up, true)
	await process_frame
