extends SceneTree
## Production native view's cache/routing and slot owners; only the initial
## authored CSB mount is replaced with a synthetic shell for CI without a pack.
const TEST=preload("res://tests/source_inventory_header_refresh_test.gd")
const CHROME=preload("res://scripts/ui/original_ui/source_main_inventory_bindings.gd")
const SLOTS=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const VIEW=preload("res://scripts/ui/original_ui/source_main_inventory_view.gd")
var checks: int=0
var failures: Array[String]=[]
var samples: Array=[]

class Pack extends TEST.FakePack:
	var root: String="synthetic-first"
	var manifest_sha256: String="original-pin"

class Bag extends TEST.FakeBag:
	var native_inventory_asset_revision: int=0
	var armed: String=""
	func item_action_label(reference: String) -> String:return "사용" if armed==reference else ""

class Slot extends TEST.FakeSlot:
	func _init() -> void:source_nodes[SLOTS.ACTION]=true

class Presenter extends Node2D:
	var plays: int=0
	func play(clip: String, looped: bool) -> Dictionary:
		plays+=1
		return {"ok":clip=="Inventory_All_On" and not looped}

class FixtureView extends "res://scripts/ui/original_ui/source_main_inventory_view.gd":
	func _stage(parent: Node, _initial_open: bool) -> Dictionary:
		var model: Dictionary=_eligible_model()
		if not model.get("ok",false):return model
		var next:=Presenter.new()
		var chrome:=TEST.HeaderScene.new()
		chrome.build_header(_chrome.snapshot())
		next.add_child(chrome)
		var content:=Node2D.new()
		next.add_child(content)
		parent.add_child(next)
		_scene=next
		_inventory_scene=chrome
		_scroll_content=content
		_scroll_top=0.0
		_scroll_bottom=-500.0
		_native_capacity=int(model.native_capacity)
		_line_slot_set=int(model.slot_project_offset)
		_line_variant=str(model.authored_variant)
		_layout=_layout_key(model)
		_marker_key=_marker_inputs()
		_bound_inputs=_owner_inputs()
		_bound_asset_key=_source_asset_key()
		_chrome.bind_presented(chrome)
		for entry: Dictionary in model.current_display_rows.slice(0,24):
			var slot:=Slot.new()
			content.add_child(slot)
			_slots.refresh_slot(slot,entry.reference,model)
			_hits[entry.reference]={"native_slot_scene":slot,"owned_row":entry.duplicate(true),"shown_selected":model.selected_reference==entry.reference}
		stats.stages+=1
		return _open_result()

func _initialize() -> void:_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_INVENTORY_REOPEN_FAIL ",label)

func _fixture(columns: int) -> Dictionary:
	var host:=Node2D.new()
	root.add_child(host)
	var bag:=Bag.new()
	bag.capacity_label=Label.new()
	bag.capacity_label.text="64 / 120"
	bag.add_child(bag.capacity_label)
	bag.search_line=LineEdit.new()
	bag.add_child(bag.search_line)
	bag.item_grid=GridContainer.new()
	bag.item_grid.columns=columns
	bag.add_child(bag.item_grid)
	for index: int in range(64):
		var reference: String="같은 이름@@@physical-%02d"%index
		bag.offered.append({"name":"같은 이름","reference":reference,"amount":index+1})
		bag.sorted_references.append(reference)
	var hud:=TEST.FakeHud.new()
	hud.lineage_inventory_ui=bag
	hud.add_child(bag)
	host.add_child(hud)
	var pack:=Pack.new()
	pack.manifest["files"]={SLOTS.PARENT:{"sha256":SLOTS.PARENT_SHA},SLOTS.SET_MEMBER:{"sha256":SLOTS.SET_SHA},SLOTS.SLOT_MEMBER:{"sha256":SLOTS.SLOT_SHA}}
	var view:=FixtureView.new()
	check(view.configure(pack,hud).get("ok",false),"original verified slot identities configure")
	return {"host":host,"bag":bag,"view":view,"pack":pack}

func _run() -> void:
	for columns: int in [4,8]:
		_lifecycle(columns)
		_measure(columns)
	print("SOURCE_INVENTORY_REOPEN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

func _lifecycle(columns: int) -> void:
	var f: Dictionary=_fixture(columns)
	var host: Node=f.host
	var bag: Bag=f.bag
	var view: FixtureView=f.view
	var selected: String=bag.sorted_references[1]
	var another: String=bag.sorted_references[2]
	bag.selected_item=selected
	bag.armed=selected
	check(view.open(host).get("authored_slot_set_project")== (56036 if columns==4 else 44156),"both authored layout branches")
	var scene: Presenter=view._scene
	var marked: Slot=view._hits[selected].native_slot_scene
	check(marked.shown[SLOTS.ACTION] and marked.shown[SLOTS.SELECTED],"armed marker on exact physical row")
	view._scroll_content.position.y=-300.0
	view._chrome.close()
	check(not view.is_open() and not scene.visible and scene.process_mode==Node.PROCESS_MODE_DISABLED,"native X parks but disables the original shell")
	check(view.presentation().get("scene")==null and view.hit_at(Vector2.ZERO).is_empty(),"parked shell is not exposed to hit testing")
	check(not view.select(selected).get("ok",false) and not view.activate_selected(selected).get("ok",false) and not view.scroll_by(-80.0).get("ok",false),"parked view rejects selection, use and scroll")
	var hidden_drag:=InputEventScreenDrag.new()
	hidden_drag.relative.y=-100.0
	view._forward_scroll_input(hidden_drag)
	check(view._scroll_content.position.y==-300.0,"late scroll signal cannot mutate a parked view")
	bag.armed=""
	bag.character_state.gold=123
	var reads: int=bag.entry_calls
	var reused: Dictionary=view.open(host)
	check(reused.get("reused_scene",false) and view._scene==scene and scene.plays==1 and view._hits[selected].native_slot_scene==marked,"reopen reuses exact scene, slot and original animation")
	check(bag.entry_calls==reads and view._scroll_content.position.y==0.0 and not marked.shown[SLOTS.ACTION],"unchanged reopen reads no ownership, resets scroll and clears a stale armed label")
	check(str(view._inventory_scene.values()[CHROME.GOLD_TEXT])=="formatted-123","header refresh follows fresh gold")
	check(view._chrome._scene.get_ref()==view._inventory_scene,"native close/reopen restores the existing category callback target")
	view.close()
	bag.offered[1].amount=99
	bag.selected_item=another
	bag.inventory_list_rebuilds+=1
	reads=bag.entry_calls
	check(view.open(host).get("reused_scene",false) and bag.entry_calls==reads+1,"count/selection change takes one validated ownership snapshot")
	check(view._hits[selected].native_slot_scene==marked and marked.texts[SLOTS.AMOUNT]=="99" and not marked.shown[SLOTS.SELECTED],"same row is patched, not swapped by its shared display name")
	check(view._hits[another].native_slot_scene.shown[SLOTS.SELECTED],"new exact physical selection is visible")
	bag.offered[3].amount=77
	bag.inventory_list_rebuilds+=1
	var refreshed: Dictionary=view.refresh_rows()
	check(refreshed.get("rows_only",false) and int(refreshed.slots_patched)==1,"same-layout count refresh only patches the dirty row")
	bag.sorted_references.erase(another)
	check(not view.activate_selected(another).get("ok",false) and bag.activations==0,"even a stale displayed hit cannot bypass the live action guard")
	view.close()
	bag.search_line.text="filtered"
	bag.inventory_list_rebuilds+=1
	check(not view.open(host).get("reused_scene",false) and not view._hits.has(another),"changed search/order stages fresh rows")
	view.close()
	var moved: String=bag.sorted_references.pop_back()
	bag.sorted_references.insert(0,moved)
	bag.inventory_list_rebuilds+=1
	check(not view.open(host).get("reused_scene",false) and view._hits.has(moved),"changed order admits moved exact ID on a new scene")
	view.close()
	var replacement: String="같은 이름@@@replacement"
	bag.sorted_references[0]=replacement
	bag.offered[-1].reference=replacement
	bag.inventory_list_rebuilds+=1
	check(not view.open(host).get("reused_scene",false) and view._hits.has(replacement) and not view._hits.has(moved),"replacement with the same name cannot borrow a vanished physical hit")
	view.close()
	bag.item_grid.columns=8 if columns==4 else 4
	check(not view.open(host).get("reused_scene",false) and view._native_capacity==bag.item_grid.columns,"4/8 expansion disposes an incompatible shell")
	view.close()
	bag.native_inventory_asset_revision+=1
	check(not view.open(host).get("reused_scene",false),"new item catalog/image owner revision invalidates old visual bindings")
	view.close()
	f.pack.manifest_sha256="different-pack"
	check(not view.open(host).get("reused_scene",false),"new pack manifest pin invalidates old shell")
	view.close()
	view._parked_until=1
	view.expire_cache()
	check(view._scene==null and view._hits.is_empty(),"short idle expiration releases all cached nodes and hits")
	view.open(host)
	view.close()
	view.invalidate_parked_cache()
	check(view._scene==null and view._hits.is_empty(),"explicit pack refresh/controller release clears parked state")
	host.free()

func _measure(columns: int) -> void:
	var f: Dictionary=_fixture(columns)
	var host: Node=f.host
	var view: FixtureView=f.view
	var cold: Array[int]=[]
	var warm: Array[int]=[]
	var refresh: Array[int]=[]
	for index: int in range(17):
		var started: int=Time.get_ticks_usec()
		view.open(host)
		cold.append(Time.get_ticks_usec()-started)
		view.close()
		started=Time.get_ticks_usec()
		view.open(host)
		warm.append(Time.get_ticks_usec()-started)
		f.bag.offered[0].amount+=1
		f.bag.inventory_list_rebuilds+=1
		started=Time.get_ticks_usec()
		view.refresh_rows()
		refresh.append(Time.get_ticks_usec()-started)
		view.close(false)
	cold.sort()
	warm.sort()
	refresh.sort()
	samples.append({"columns":columns,"bag_rows":64,"fixture_visible_slots":24,"synthetic_first_open_us":cold[8],"synthetic_reopen_us":warm[8],"synthetic_one_dirty_row_us":refresh[8]})
	host.free()
