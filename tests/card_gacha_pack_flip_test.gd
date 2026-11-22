extends SceneTree
## User report 2026-11-22: a 뽑기팩 used from the bag showed the 뽑기 결과 grid
## already face up, under the bag (still open) and the grant toast. As the
## original 523 client, on the actual Main:
## - the bag (two taps on the slot: 사용) closes when the original 카드 뽑기
##   window (BMShop/BM_Gacha) opens over it;
## - the cards are dealt face down: the category's card back
##   (Change_Fusion_Card Fx_Start_Change / _Doll / _HolyStuff, the client's
##   Img_Card_Back_*), the face (Panel) hidden;
## - a tap on a card turns it (Card_Back off, face and name shown), 영웅 이상
##   with the original grade light; 모두 확인 turns the rest; then the
##   full-screen tap closes;
## - no toast lies over the window while it is open (the line stays in the
##   log);
## - every 변신 / 마법인형 / 성물 draw pack and the shop draw reveal take the
##   same window.
## Without the original files: the window's open/turn rules and the HUD's
## toast hold on the actual Main HUD. user:// is put back at the end.
## Captures with -- --capture-dir=<dir> (rendering run).
const QA = preload("res://tests/qa_class_selection.gd")
const WINDOW = preload("res://scripts/ui/original_ui/source_main_card_gacha_window.gd")
const GRADE_FX = preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
const CASH = preload("res://scripts/shop/source523_cash_packages.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const SLOTS = preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var user_files: Dictionary = {}
var capture_dir: String = ""

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CARD_GACHA_FLIP_FAIL: ",label)
	return condition

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func frames(count: int = 6) -> void:
	for frame: int in range(count): await process_frame

func touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = pressed
	root.push_input(event,true)

func tap(at: Vector2) -> void:
	touch(at,true); await process_frame
	touch(at,false); await frames(6)

func capture(label: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.get_texture().get_image().save_png(capture_dir.path_join(label+".png"))

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
			var out := FileAccess.open(full,FileAccess.WRITE)
			if out != null: out.store_buffer(user_files[full]); out.close()

static func cards(count: int, grade: String = "희귀") -> Array:
	var rows: Array = []
	for index: int in count: rows.append({"name":"카드 %d" % index,"grade":grade})
	return rows

static func constant(name: String, fallback: Variant = null) -> Variant:
	var script: Script = WINDOW
	return script.get_script_constant_map().get(name,fallback)

## Window rules without the original files.
func rules() -> void:
	var window = WINDOW.new()
	if not check(window.has_method("open_card") and window.has_method("page_open"), "the window opens cards one by one"): return
	window.results = cards(12)
	window.opened.resize(12)
	check(not window.page_open() and window.pages() == 2, "the cards start closed")
	check(window.open_card(3).get("opened",false) and window.is_opened(3) and not window.is_opened(2), "a tap opens only that card")
	check(not window.open_card(3).get("opened",true), "an open card stays open")
	check(not window.open_card(11).get("ok",true), "a card of another page is not opened")
	var closed: Array = []
	window.on_closed = func() -> void: closed.append(true)
	window._next()
	check(window.page == 0 and window.page_open(), "the full-screen tap opens the closed cards of the page first")
	window._next()
	check(window.page == 1 and not window.page_open(), "then turns the page (its cards closed)")
	check(int(window.open_all().get("opened",0)) == 2 and window.page_open(), "모두 확인 opens the rest of the page")
	window._next()
	check(closed == [true], "the last tap closes and releases the reveal")
	check(window.has_method("back_clip") and window.call("back_clip","변신") == "Fx_Start_Change" and window.call("back_clip","마법인형") == "Fx_Start_Doll" and window.call("back_clip","성물") == "Fx_Start_HolyStuff", "the card back clip of each category")
	check(constant("DEAL") == {"Nd_CardSet_One":"CardSet_One","Nd_CardSet_Five":"CardSet_Five","Nd_CardSet":"Fx_Start"}, "each set's own dealing clip")
	check(int(constant("Z",0)) > 160 and int(constant("Z",0)) < 180, "the window lies over the bag and shop windows, under the system message")
	var spec_window = WINDOW.new()
	spec_window.results = cards(1,"전설")
	spec_window.opened.resize(1)
	var spec: Dictionary = spec_window._spec()
	check(spec.get("Nd_ButtonSet/Btn_Open",{}).get("visible",false), "모두 확인 is shown while a card is closed")
	check(not spec.has("Nd_CardSet_One/Card_00/Fx_Glow") and spec.get("Nd_CardSet_One/Card_00/Fx_Outline_Front",{}).get("exclude",false), "a closed card keeps its card back and no outline")
	spec_window.opened[0] = true
	spec = spec_window._spec()
	check(spec.get("Nd_ButtonSet/Btn_Open",{}).get("exclude",false), "모두 확인 is left out once all are open")

static func reveal_open(hud: Node) -> bool:
	return hud.has_method("original_gacha_reveal_open") and hud.call("original_gacha_reveal_open")

func finish(world: Node) -> void:
	if is_instance_valid(world): world.queue_free()
	await frames(4)
	restore_user("user://")
	print("CARD_GACHA_FLIP_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(1 if not failures.is_empty() else 0)

func run() -> void:
	snapshot_user("user://")
	rules()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world._clear_monsters()
	await frames(30)
	var hud: Node = world.hud
	# Toast hold on the actual HUD: while the original window's guard holds
	# the reveal, a grant line does not reach the screen.
	var guard := Control.new()
	guard.set_meta("original_gacha_reveal",true)
	hud.add_child(guard)
	var previous: Variant = hud.card_reveal_stage
	hud.card_reveal_stage = guard
	hud.message_label.text = ""
	hud.show_message("신비한 변신 뽑기팩 개봉 · 시험")
	check(reveal_open(hud) and hud.message_label.text.is_empty(), "no toast over the open card draw window")
	hud.card_reveal_stage = previous
	guard.queue_free()
	hud.show_message("시험 문구")
	check(hud.message_label.text == "시험 문구", "toasts return once it is closed")
	hud.message_label.text = ""
	if DEF.not_installed() or not is_instance_valid(hud.get("original_main_ui_controller")) or not hud.original_main_ui_controller.feature_window_available("card_gacha_result"):
		evidence["mode"] = "no_original_pack"
		await finish(world); return
	evidence["mode"] = "original_pack"
	var packs: Dictionary = draw_packs(world)
	evidence["packs"] = packs.duplicate()
	check(packs.has("변신") and packs.has("마법인형") and packs.has("성물"), "a draw pack of each category: %s" % str(packs))
	var order: Array = ["변신","마법인형","성물"]
	for category: String in order:
		if packs.has(category): await bag_use(world,str(packs[category]),category)
	await shop_reveal(world)
	await finish(world)

## {category: item name} of one original draw pack (gotcha) per category.
func draw_packs(world: Node) -> Dictionary:
	var found: Dictionary = {}
	var named: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source") != CASH.TAG: continue
		var spec: Dictionary = CASH.definition(int(record.get("source_item_class_id",0)))
		if spec.get("kind") != "gotcha": continue
		var card_id: int = 0
		for entry: Dictionary in spec.entries:
			if int(entry.get("card_id",0)) > 0: card_id = int(entry.card_id); break
		if card_id <= 0: continue
		var category: String = str(CASH._card_target(world,card_id).get("category",""))
		if category.is_empty(): continue
		var name: String = str(record.name)
		# The user's pack first, then any 뽑기팩, then any draw pack.
		var rank: int = 0 if name == "신비한 변신 뽑기팩" else (1 if name.contains("뽑기팩") else 2)
		if not found.has(category) or rank < int(named[category]):
			found[category] = name
			named[category] = rank
	return found

func reference_of(world: Node, needle: String) -> String:
	for reference: String in world.hud.lineage_inventory_ui.sorted_references:
		if reference.get_slice("@@@",0) == needle: return reference
	return ""

func slot_point(hud: Node, reference: String) -> Vector2:
	var view: RefCounted = hud.original_main_ui_controller._inventory_view
	for attempt: int in range(40):
		if view._hits.has(reference):
			var control: Control = view._hits[reference].control
			var point: Vector2 = control.get_global_transform_with_canvas()*(control.size*0.5)
			if str(hud.original_inventory_hit_at(point).get("reference","")) == reference: return point
		var step := InputEventScreenDrag.new()
		step.index = 0; step.relative = Vector2(0,-60)
		view._forward_scroll_input(step)
		await process_frame
	return Vector2.INF

## Screen center of the input area of the window node at `suffix`.
func window_point(window: RefCounted, suffix: String) -> Vector2:
	var located: Dictionary = window._locate(window._scene,window._out,suffix)
	if not located.get("ok",false): return Vector2.INF
	var node: Variant = located.player.source_nodes.get(located.offset)
	var button: Variant = node.get_meta("source_button") if node is Node and node.has_meta("source_button") else null
	var area: Variant = button.get("_input_area") if is_instance_valid(button) else null
	if not area is Control or not (area as Control).is_visible_in_tree(): return Vector2.INF
	var rect: Rect2 = (area as Control).get_global_rect()
	return rect.get_center()

func node_of(window: RefCounted, suffix: String) -> CanvasItem:
	var located: Dictionary = window._locate(window._scene,window._out,suffix)
	if not located.get("ok",false): return null
	var node: Variant = located.player.source_nodes.get(located.offset)
	return node as CanvasItem

func back_shown(window: RefCounted, cell: String) -> bool:
	var back: CanvasItem = node_of(window,cell+"/Fx_Glow/Card_Back")
	var face: CanvasItem = node_of(window,cell+"/Panel")
	return back != null and back.visible and face != null and not face.visible

func face_shown(window: RefCounted, cell: String) -> bool:
	var back: CanvasItem = node_of(window,cell+"/Fx_Glow/Card_Back")
	var face: CanvasItem = node_of(window,cell+"/Panel")
	return (back == null or not back.visible) and face != null and face.visible

## Grants one pack, uses it from the bag with two taps, then turns the cards.
func bag_use(world: Node, name: String, category: String) -> void:
	var hud: Node = world.hud
	var controller: Node = hud.original_main_ui_controller
	world.inventory[name] = int(world.inventory.get(name,0)) + 1
	world._update_hud(); hud.refresh_inventory(world.inventory)
	if not hud.original_inventory_is_open(): hud.toggle_inventory()
	await frames(30)
	if not check(hud.original_inventory_is_open(), "%s: the original bag opens" % category): return
	var reference: String = reference_of(world,name)
	var point: Vector2 = await slot_point(hud,reference)
	if not check(point.is_finite(), "%s: the pack has a bag slot (%s)" % [category,name]): return
	await tap(point)
	await tap(point)
	await frames(20)
	var window: RefCounted = controller.feature_window("card_gacha_result")
	var label: String = "%s %s" % [category,name]
	if not check(window != null and window.is_open(), "%s: the bag's 사용 opens the original card draw window" % label): return
	check(reveal_open(hud), "%s: the HUD holds the reveal for it" % label)
	check(not hud.original_inventory_is_open() and not controller.item_tooltip_is_open(), "%s: the bag and its item popup close" % label)
	check(hud.message_label.text.is_empty(), "%s: no toast over the window (%s)" % [label,hud.message_label.text])
	check(window._scene.z_index == int(constant("Z",-1)), "%s: the window lies over the other windows" % label)
	var filled: Dictionary = window.last_result.get("filled",{})
	check(int(filled.get("backs",-1)) == int(filled.get("shown",-2)) and bool(filled.get("dealing",false)), "%s: every card is dealt face down by the set clip (%s)" % [label,str(filled)])
	evidence[category] = {"name":name,"filled":filled.duplicate(),"title":window.title}
	if not window.has_method("open_card"):
		await capture("%s_0_before_fix" % category)
		window.close()
		await frames(4)
		return
	await create_timer(3.4).timeout
	await frames(3)
	check(not bool(window._scene.playback_status().get("playing",true)), "%s: the deal ends" % label)
	var set_name: String = str(filled.get("set",""))
	var shown: int = int(filled.get("shown",0))
	var backs_ok: bool = true
	for index: int in range(shown):
		if not back_shown(window,"%s/Card_%02d" % [set_name,index]): backs_ok = false
	check(backs_ok, "%s: each card shows its card back, the face hidden" % label)
	var back_texture: String = ""
	var back: CanvasItem = node_of(window,"%s/Card_00/Fx_Glow/Card_Back" % set_name)
	if back != null and back.has_meta("source_sprite"):
		var sprite: Sprite2D = back.get_meta("source_sprite")
		back_texture = str(sprite.texture.resource_name if sprite.texture != null else "")
	evidence[category]["back_texture"] = back_texture
	await capture("%s_1_backs" % category)
	# Tap the first card.
	var card_point: Vector2 = window_point(window,"%s/Card_00/Btn_Card" % set_name)
	if check(card_point.is_finite(), "%s: the first card takes a tap" % label):
		await tap(card_point)
		await frames(20)
		check(window.is_opened(0) and face_shown(window,"%s/Card_00" % set_name), "%s: a tap turns the card face up" % label)
		if shown > 1: check(back_shown(window,"%s/Card_01" % set_name), "%s: the other cards stay closed" % label)
		await create_timer(1.2).timeout
		await capture("%s_2_one_open" % category)
	var lit_expected: int = 0
	for index: int in range(shown):
		if GRADE_FX.available(window,str(window.results[index].get("grade",""))): lit_expected += 1
	evidence[category]["grades"] = window.results.map(func(card: Dictionary) -> String: return str(card.get("grade","")))
	if shown > 1 and not window.page_open():
		var open_point: Vector2 = window_point(window,"Nd_ButtonSet/Btn_Open")
		if check(open_point.is_finite(), "%s: 모두 확인 is on the screen" % label):
			await tap(open_point)
			await frames(20)
	var all_open: bool = true
	for index: int in range(shown):
		if not face_shown(window,"%s/Card_%02d" % [set_name,index]): all_open = false
	check(window.page_open() and all_open, "%s: 모두 확인 turns every card" % label)
	check(window_point(window,"Nd_ButtonSet/Btn_Open") == Vector2.INF, "%s: 모두 확인 goes once all are open" % label)
	var lights: int = 0
	for index: int in range(shown):
		var glow: CanvasItem = node_of(window,"%s/Card_%02d/Fx_Glow" % [set_name,index])
		if glow != null:
			for child: Node in glow.get_children():
				if child.has_meta("source_project_player") or str(child.get("source_member")).contains("Fx_Change_ActiveGreade"): lights += 1
	evidence[category]["lit_expected"] = lit_expected
	await create_timer(1.5).timeout
	await capture("%s_3_all_open" % category)
	# The full-screen tap closes (one page) and releases the reveal.
	while window.is_open() and window.page + 1 < window.pages():
		window._next(); await frames(4); window.open_all(); await frames(4)
	var close_point: Vector2 = window_point(window,"Btn_Close")
	if check(close_point.is_finite(), "%s: the full-screen tap area" % label):
		await tap(close_point)
		await frames(10)
	check(not window.is_open() and not reveal_open(hud) and not hud.is_card_reveal_busy(), "%s: the last tap closes the window" % label)
	check(int(world.inventory.get(name,0)) == 0, "%s: one pack used" % label)

## The shop's draw reveal (source523_inventory_tickets.market_draw_presented
## → present_card_reveal) takes the same window over the open store window.
func shop_reveal(world: Node) -> void:
	var hud: Node = world.hud
	var controller: Node = hud.original_main_ui_controller
	# 영웅 이상 light up when turned (CardSet_Five, real taps).
	var mixed: Array = []
	var wanted: Array = ["영웅","전설","희귀","고급","영웅"]
	for grade: String in wanted.duplicate():
		for record: Dictionary in world.catalog_db.get("변신",[]):
			if str(record.get("grade","")) != grade or mixed.any(func(row: Dictionary) -> bool: return row.name == str(record.get("name",""))): continue
			mixed.append({"id":preload("res://scripts/card_draw_fusion.gd").card_id(record),"name":str(record.get("name","")),"grade":grade})
			break
	if check(mixed.size() == 5, "five original 변신 cards with 영웅/전설: %d" % mixed.size()):
		hud.present_card_reveal("변신",{"ok":true,"category":"변신","results":mixed,"count":5,"message":"상점 뽑기"},false)
		await frames(10)
		var five: RefCounted = controller.feature_window("card_gacha_result")
		check(five.is_open() and str(five.last_result.get("filled",{}).get("set","")) == "Nd_CardSet_Five" and int(five.last_result.filled.get("backs",0)) == 5, "five cards: Nd_CardSet_Five face down")
		await create_timer(2.6).timeout
		var hero_point: Vector2 = window_point(five,"Nd_CardSet_Five/Card_00/Btn_Card")
		var glow: CanvasItem = node_of(five,"Nd_CardSet_Five/Card_00/Fx_Glow")
		var before: int = glow.get_child_count() if glow != null else -1
		if check(hero_point.is_finite(), "the 영웅 card takes a tap"):
			await tap(hero_point)
			await frames(10)
			check(five.is_opened(0) and glow != null and glow.get_child_count() > before, "a turned 영웅 card mounts its original grade light (%d → %d)" % [before,glow.get_child_count() if glow != null else -1])
		var rest: Dictionary = five.open_all()
		check(int(rest.get("lit",-1)) == 2 and int(rest.get("opened",0)) == 4, "모두 확인 lights the other 영웅 이상 only: %s" % str(rest))
		await create_timer(1.0).timeout
		await capture("shop_0_five_lit")
		five._next(); await frames(6)
		check(not five.is_open(), "five cards close")
	var rows: Array = []
	for record: Dictionary in world.catalog_db.get("성물",[]):
		rows.append({"id":preload("res://scripts/card_draw_fusion.gd").card_id(record),"name":str(record.get("name","")),"grade":str(record.get("grade",""))})
		if rows.size() >= 11: break
	if not check(rows.size() == 11, "eleven original 성물 cards for a shop draw"): return
	hud.present_card_reveal("성물",{"ok":true,"category":"성물","results":rows,"count":rows.size(),"message":"상점 뽑기"},false)
	hud.show_message("구매 완료 · 상점 뽑기")
	await frames(10)
	var window: RefCounted = controller.feature_window("card_gacha_result")
	check(window != null and window.is_open() and window.pages() == 2 and int(window.last_result.get("filled",{}).get("backs",0)) == 10, "the shop draw: the same face-down window, ten a page")
	check(hud.message_label.text.is_empty(), "the shop draw: the purchase line does not lie over it")
	await capture("shop_1_backs")
	window._next(); await frames(10)
	check(window.page == 0 and window.page_open(), "the shop draw: the full-screen tap turns the page's cards")
	window._next(); await frames(10)
	check(window.page == 1 and not window.page_open(), "the shop draw: the next page is dealt face down")
	window.open_all(); await frames(4)
	window._next(); await frames(10)
	check(not window.is_open() and not hud.is_card_reveal_busy(), "the shop draw: closes after the last page")
