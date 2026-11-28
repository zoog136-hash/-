extends "res://tests/source_inventory_controls_main_test.gd"
## Optional original UI46 plus pinned definitions. Open the actual dungeon
## screen and send touches. The arrival boundary is controlled because the
## original S32/TI2 is not part of this test. The save owner is actual Main.

const ORIM = preload("res://scripts/orim523/orim523.gd")
const LOADING = preload("res://scripts/boot/dungeon_loading.gd")

class Arrival extends RefCounted:
	const PAYMENT = preload("res://scripts/maps/current523_map_travel_payment.gd")
	var world: Node
	var land := 4
	var problem := "검증용 도착 거절"
	var allow := false
	var transition: Dictionary = {}
	var calls: Array[Dictionary] = []

	func current_source_land() -> Dictionary:
		return {"land_id":land,"cell":[33442,32798]}

	func enter_source_land_loading(target: int, bounds: Array, waive: Array = [], save: Dictionary = {}) -> bool:
		return enter_source_land(target,bounds,waive,save)

	func enter_source_land(target: int, bounds: Array, _waive: Array = [], save: Dictionary = {}) -> bool:
		calls.append({"target":target,"bounds":bounds,"balance":world.ain_service.blessing,"save":save})
		transition={"ok":false,"saved":false,"uncertain":false}
		if not allow: return false
		transition=PAYMENT.commit(world,save)
		problem=str(transition.get("reason",""))
		if not transition.get("ok",false): return false
		land=target
		return true

	func last_source_transition() -> Dictionary:
		return transition

	func close(_restore: bool) -> void:
		pass

func result_marker() -> String:
	return "ORIM_ENTRY_PINNED_MAIN_RESULT"

func fallback() -> void:
	ck(false,"set the exact definition and UI paths")

func exact(archive: String) -> void:
	controller=h.original_main_ui_controller
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",archive)
	SOURCE.reset()
	ORIM.release()
	w.skill_awakening=w.SKILL_AWAKENING.new()
	w.skill_awakening.configure(w)
	if not ck(is_instance_valid(controller) and SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"authored UI owner and exact definitions"): return
	var loaded: Dictionary=w.source_dungeons.load_configured()
	if not ck(loaded.get("ok",false),"dungeon projection verified: "+str(loaded.get("reason",""))): return
	var original: Dictionary=w.dungeon_play.orim_model()
	var first: Dictionary=original.get("stages",{}).get(2,{})
	if not ck(first.get("land_id")==48752 and first.get("territory",{}).get("ID")==224812,"exact ground/territory chain"): return

	w.level=85
	w.ain_service.blessing=50
	var arrival:=Arrival.new()
	arrival.world=w
	w._current523_aden_play_controller=arrival
	ck(w._save_game(true)==OK,"initial disposable Main save")
	var snapshot: String=hash_file()
	var before: Dictionary=w.dungeon_play.state.duplicate(true)
	h._open_source_dungeons("orim",0,"source_dungeons","던전")
	await frames()
	var window: RefCounted=controller.dungeon_window()
	if not ck(window!=null and window.is_open() and h.original_main_ui_status["dungeon_window"].get("handled",false),"pinned dungeon screen: "+str(h.original_main_ui_status["dungeon_window"])): return
	if not await tap(dungeon_button(window,"Nd_CardOff/Panel_Card/Btn_Plus"),"authored hero Plus"): return
	if not ck(window.hero==0,"first exact hero selected"): return
	if not await challenge(window): return
	ck(window.is_open() and snapshot==hash_file() and w.ain_service.blessing==50 and w.dungeon_play.state==before,"controlled map refusal preserves original UI, live balance, ledger and file")
	if not ck(arrival.calls.size()==1,"one attempt dispatched"): return
	print("ORIM_FIRST_ROUTE ",JSON.stringify({"target":arrival.calls[0].target,"bounds":arrival.calls[0].bounds,"balance":arrival.calls[0].balance}))
	ck(arrival.calls[0].target==48752 and arrival.calls[0].bounds==[32563,33093,32577,33107] and arrival.calls[0].balance==50,"destination uses the original rectangle and receives no advance debit")
	arrival.allow=true
	w.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
	if not await challenge(window): return
	w.equipment_collections.test_save_writer=Callable()
	ck(window.is_open() and not w.dungeon_play.save_blocked and snapshot==hash_file() and w.ain_service.blessing==50 and w.dungeon_play.state==before,"real Main save writer refusal is retryable and preserves bytes and attempt")
	if not await challenge(window): return
	var active: Dictionary=w.dungeon_play.state.active
	var persisted: Variant=JSON.parse_string(FileAccess.get_file_as_string(w.save_path()))
	ck(not window.is_open() and int(w.ain_service.blessing)==40 and arrival.calls.size()==3,"successful original entry closes menu and charges default fee once")
	ck(int(active.get("land",0))==48752 and active.get("home",{}).get("land_id")==4 and int(active.get("orim",{}).get("character",0))==2 and int(active.get("orim",{}).get("hero_hp",0))==350,"original selected hero, destination, and return field stored")
	if not ck(persisted is Dictionary,"canonical save is readable"): return
	var ledger: Dictionary=persisted.get("source_dungeon_play",{})
	ck(int(persisted.get("ainhasad_state",{}).get("blessing",0))==40 and int(ledger.get("active",{}).get("land",0))==48752 and ledger.get("attempts",{}).values()==[1.0],"canonical save persisted both fee and exactly one attempt in the same file")
	ck(w.dungeon_play.restore(ledger) and int(w.dungeon_play.state.active.get("land",0))==48752,"existing save loader accepts the arrival ledger")
	print("ORIM_ENTRY_PERSISTED ",JSON.stringify({"initial_blessing":50,"saved_blessing":persisted.ainhasad_state.blessing,"attempts":ledger.attempts.values(),"land":active.get("land"),"hero_hp":active.get("orim",{}).get("hero_hp")}))

func challenge(window: RefCounted) -> bool:
	if not await tap(dungeon_button(window,"Nd_Challenge/Btn_Challenge"),"authored Orim challenge"): return false
	await frames()
	var dialog: Control=h.get_node("Root").get_node_or_null("TwilightConfirmation")
	if not ck(dialog!=null and dialog.get_script().resource_path.ends_with("source_main_awakening_review.gd"),"authored confirmation opens"): return false
	if not await tap(dialog.confirm_button,"authored confirmation button"): return false
	for index: int in 240:
		await process_frame
		if get_first_node_in_group(LOADING.GROUP)==null:
			await frames()
			return true
	return ck(false,"transition did not settle before deadline")

func dungeon_button(window: RefCounted, suffix: String) -> Control:
	var node: Dictionary=TREE.locate(window._scene,window.node_keys(),suffix)
	return area(node.player.source_nodes.get(node.offset)) if node.get("ok",false) else null
