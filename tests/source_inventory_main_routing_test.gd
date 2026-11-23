extends SceneTree
## Actual Main with its real fallback; a synthetic native admission result
## verifies no legacy inventory slots are rendered before the native route.
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]

class Admission extends "res://scripts/ui/original_ui/source_main_hud.gd":
	var bag: Control
	var accepted: bool=true
	var opened: bool=false
	var legacy_was_visible: bool=true
	var rows: int=0
	func try_open_inventory() -> Dictionary:
		legacy_was_visible=bag.inventory_panel.is_visible_in_tree()
		rows=bag.source_inventory_entries_for_view().size()
		opened=accepted
		return {"ok":accepted,"handled":accepted,"code":"fixture_native_admission"}
	func inventory_is_open() -> bool:return opened
	func close_inventory() -> void:opened=false

func _initialize() -> void:_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_INVENTORY_MAIN_ROUTING_FAIL ",label)

func _run() -> void:
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main class admission")
	await process_frame
	var hud: Node=world.hud
	var bag: Control=hud.lineage_inventory_ui
	var actual: Node=hud.original_main_ui_controller
	hud.original_main_ui_controller=null
	hud.toggle_inventory()
	await process_frame
	check(hud.workspace.is_visible_in_tree() and bag.inventory_panel.is_visible_in_tree() and hud.active_section=="inventory","no native pack still opens visible existing fallback")
	check(bag.item_grid.columns in [4,8] and not bag.inventory_grid_dirty,"fallback slot display is prepared")
	hud._close_workspace()
	await process_frame
	var fake:=Admission.new()
	fake.bag=bag
	hud.add_child(fake)
	fake.set_process(false)
	hud.original_main_ui_controller=fake
	var inv: Dictionary=bag.inventory.duplicate(true)
	for index: int in range(90):inv["routing-fixture-%02d"%index]=2
	bag.set_inventory(inv)
	var visuals: int=bag.slot_visual_updates
	var layouts: int=bag.inventory_list_rebuilds
	hud.toggle_inventory()
	await process_frame
	check(fake.opened and fake.rows>=90 and not fake.legacy_was_visible,"native open sees current inventory before the legacy pane is shown")
	check(bag.slot_visual_updates==visuals and bag.inventory_list_rebuilds==layouts+1 and not hud.workspace.visible,"native acceptance skips all legacy slot rendering; owner preparation runs once")
	hud.toggle_inventory()
	await process_frame
	check(not fake.opened and not hud.workspace.visible,"toggle closes native admission without opening legacy")
	fake.accepted=false
	hud.toggle_inventory()
	await process_frame
	check(not fake.legacy_was_visible and not fake.opened and bag.inventory_panel.is_visible_in_tree() and hud.workspace.visible,"native rejection opens the existing fallback after admission fails")
	check(bag.slot_visual_updates>visuals,"fallback still binds and shows current slots")
	hud._close_workspace()
	hud.original_main_ui_controller=actual
	world.queue_free()
	await process_frame
	print("SOURCE_INVENTORY_MAIN_ROUTING_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
