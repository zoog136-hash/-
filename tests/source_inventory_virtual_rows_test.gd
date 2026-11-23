extends SceneTree
## The original inventory (source_main_inventory_view) builds only the
## Inventory_Slot_Set rows near the view: every owned row keeps its scroll
## place, scrolling builds the rows that come in and frees the far ones,
## and a count/marker/selection change over the same rows patches the built
## slots in place (no new scene, no icon re-applied, scroll kept). A changed
## row order or item record still rebuilds.
## Synthetic geometry always; with TWILIGHT_SOURCE_UI_PACK=<pack root holding
## source523_addons.json> the real original CSB rows are staged and counted.
##   godot --headless --path <repo> --script res://tests/source_inventory_virtual_rows_test.gd
const VIEW=preload("res://scripts/ui/original_ui/source_main_inventory_view.gd")
const SLOTS=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const CHROME=preload("res://scripts/ui/original_ui/source_main_inventory_bindings.gd")
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]
var samples: Dictionary={}

class FakePointer extends RefCounted:
	var pointer: int=-2

class FakeBag extends Control:
	var offered: Array[Dictionary]=[]
	var legacy_rows: Array=[]
	var sorted_references: Array[String]=[]
	var inventory_grid_dirty: bool=false
	var inventory_list_rebuilds: int=0
	var category_filter: String="전체"
	var inventory: Dictionary={}
	var capacity_label: Label
	var selected_item: String=""
	var detail_active: bool=false
	var search_line: LineEdit
	var item_grid: GridContainer
	var character_state: Dictionary={"gold":9,"current_weight":3,"max_weight":100,"carrying_capacity":100,"equipped_items":{},"equipped_ammo":"","item_locks":{},"item_instances":{},"enhancement_levels":{}}
	func hide_inventory() -> void:pass
	func _set_category(value: String) -> void:category_filter=value
	func _format_number(value: int) -> String:return str(value)
	func prepare_source_inventory_model() -> void:pass
	func _inventory_entries() -> Array[Dictionary]:return offered.duplicate(true)
	func _select_item(reference: String) -> void:selected_item=reference
	func _activate_selected() -> void:pass
	func _is_item_equipped(reference: String) -> bool:return character_state.equipped_items.values().has(reference)

class FakeHud extends Node:
	var lineage_inventory_ui: Control
	var pointer_transfer: RefCounted=FakePointer.new()

class Geometry extends "res://scripts/ui/original_ui/source_main_inventory_view.gd":
	var height: float=300.0
	func _view_height() -> float:return height

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("SOURCE_INVENTORY_VIRTUAL_ROWS_FAIL: "+label)

func _initialize() -> void:_run.call_deferred()

func _run() -> void:
	_geometry()
	var root_path: String=OS.get_environment("TWILIGHT_SOURCE_UI_PACK")
	samples["real_pack"]=not root_path.is_empty()
	if not root_path.is_empty():_real(root_path)
	print("SOURCE_INVENTORY_VIRTUAL_ROWS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

func _geometry() -> void:
	var view:=Geometry.new()
	for line: int in range(100):view._lines.append({})
	view._scroll_content=Node2D.new()
	root.add_child(view._scroll_content)
	view._row_y=-260.0
	view._scroll_content.position.y=0.0
	var top: Vector2i=view.line_range(0)
	# Line L is at -260+76L; visible while -300 <= y <= 0 -> L in [1, 3].
	check(top==Vector2i(1,3),"lines in view at the top (%s)" % str(top))
	check(view.line_range(2)==Vector2i(1,5),"build margin around the view")
	view._scroll_content.position.y=-76.0*50.0
	var middle: Vector2i=view.line_range(0)
	check(middle==Vector2i(50,53),"lines in view after scrolling 50 lines (%s)" % str(middle))
	view.height=0.0
	check(view.line_range(0)==Vector2i(1,100),"without the view height every line counts")
	view._lines.clear()
	check(view.line_range(2)==Vector2i(1,0),"no extra lines, no range")
	view._scroll_content.free()

func _fixture(pack: RefCounted, count: int) -> Dictionary:
	var host:=Node2D.new()
	root.add_child(host)
	var bag:=FakeBag.new()
	bag.capacity_label=Label.new()
	bag.capacity_label.text="%d / 400" % count
	bag.add_child(bag.capacity_label)
	bag.search_line=LineEdit.new()
	bag.add_child(bag.search_line)
	bag.item_grid=GridContainer.new()
	bag.item_grid.columns=4
	bag.add_child(bag.item_grid)
	for index: int in range(count):
		var reference: String="item-%d" % index
		bag.offered.append({"name":"item-%d" % index,"reference":reference,"amount":index+1})
		bag.sorted_references.append(reference)
		bag.inventory[reference]=index+1
	var hud:=FakeHud.new()
	hud.lineage_inventory_ui=bag
	hud.add_child(bag)
	host.add_child(hud)
	var view=VIEW.new()
	# No picture provider result: each slot keeps its original frame with the
	# picture left empty (the view's own no-picture path).
	var configured: Dictionary=view.configure(pack,hud,func(_entry: Dictionary,_context: Dictionary) -> Dictionary:return {"ok":false,"code":"test_no_picture"})
	return {"host":host,"bag":bag,"hud":hud,"view":view,"configured":configured}

func _nodes(node: Node) -> int:
	var total: int=1
	for child: Node in node.get_children():total+=_nodes(child)
	return total

func _real(root_path: String) -> void:
	PACK.bake_enabled=false
	var addons: Variant=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("source523_addons.json")))
	var pack=PACK.new()
	var opened: Dictionary=pack.open(root_path.path_join("ui"),str(addons.ui.manifest_sha256))
	check(opened.get("ok",false),"the real UI pack opens")
	if not opened.get("ok",false):return
	var f: Dictionary=_fixture(pack,400)
	check(f.configured.get("ok",false),"the view configures on the real pack (%s)" % str(f.configured.get("code","")))
	if not f.configured.get("ok",false):return
	var view=f.view
	var started: int=Time.get_ticks_usec()
	var opened_view: Dictionary=view.open(f.host)
	var open_ms: float=float(Time.get_ticks_usec()-started)/1000.0
	check(opened_view.get("handled",false),"the original bag opens (%s)" % str(opened_view.get("code","")))
	if not opened_view.get("handled",false):return
	var built: int=view._line_scenes.size()
	var lines: int=view._lines.size()
	check(lines==99 and built>0 and built<=12,"only rows near the view are built (%d of %d)" % [built,lines])
	check(view._hits.size()==(built+1)*4,"hits cover the built rows only")
	samples["open_ms"]=open_ms
	samples["lines"]=lines+1
	samples["built_lines"]=built+1
	samples["scene_nodes"]=_nodes(view._scene)
	# Scroll to the middle and the end.
	var content: Node2D=view._scroll_content
	var drag:=InputEventScreenDrag.new()
	drag.relative=Vector2(0.0,-76.0*40.0)
	var scale_y: float=absf(content.get_global_transform_with_canvas().get_scale().y)
	drag.relative.y*=scale_y if scale_y>0.0 else 1.0
	started=Time.get_ticks_usec()
	view._forward_scroll_input(drag)
	samples["scroll_40_ms"]=float(Time.get_ticks_usec()-started)/1000.0
	var range_now: Vector2i=view.line_range(0)
	check(range_now.x>30 and view._line_scenes.has(range_now.x) and not view._line_scenes.has(1),"scrolling builds the rows in view and frees the far ones (%s)" % str(range_now))
	check(view._hits.has("item-%d" % (range_now.x*4)),"a scrolled-in slot is hittable")
	var slot_scene: Node2D=view._hits["item-%d" % (range_now.x*4)].native_slot_scene
	var line_scene: Node2D=view._line_scenes[range_now.x]
	var expected_y: float=(view._inventory_scene.get("source_nodes").get(view._line_slot_set) as Node2D).position.y+VIEW.ROW_PITCH*float(range_now.x)
	check(is_equal_approx(line_scene.position.y,expected_y),"a virtual row keeps its own place")
	drag.relative.y=-1e6
	view._forward_scroll_input(drag)
	check(view._line_scenes.has(99) and view._hits.has("item-399"),"the last row is reachable")
	# Back near the middle for the patch checks.
	drag.relative.y=76.0*55.0*(scale_y if scale_y>0.0 else 1.0)
	view._forward_scroll_input(drag)
	var scroll_before: float=view._scroll_content.position.y
	var scene_before: Node2D=view._scene
	var mid: Vector2i=view.line_range(0)
	var target: String="item-%d" % (mid.x*4+1)
	check(view._hits.has(target),"target slot built")
	var target_slot: Node2D=view._hits[target].native_slot_scene
	var stages: int=int(view.stats.stages)
	var builds: int=int(view.stats.line_builds)
	# One arrow: 100 -> 99.
	for entry: Dictionary in f.bag.offered:
		if entry.reference==target:entry.amount=int(entry.amount)-1
	f.bag.inventory_list_rebuilds+=1
	started=Time.get_ticks_usec()
	var patched: Dictionary=view.refresh_rows()
	samples["rows_only_ms"]=float(Time.get_ticks_usec()-started)/1000.0
	check(patched.get("rows_only",false) and int(patched.slots_patched)==1,"a count change patches one slot (%s)" % str(patched.get("slots_patched",patched.get("code",""))))
	check(view._scene==scene_before and view._hits[target].native_slot_scene==target_slot and view._scroll_content.position.y==scroll_before,"scene, slot and scroll kept")
	check(int(view.stats.stages)==stages and int(view.stats.line_builds)==builds,"no stage and no row built")
	f.bag.character_state.item_locks[target]=true
	patched=view.refresh_rows()
	check(patched.get("rows_only",false) and int(patched.slots_patched)==view._hits.size(),"a lock change patches the built slots' markers")
	# Compare with the full rebuild of the same change.
	started=Time.get_ticks_usec()
	var full: Dictionary=view.refresh()
	samples["full_refresh_ms"]=float(Time.get_ticks_usec()-started)/1000.0
	check(full.get("handled",false) and is_equal_approx(view._scroll_content.position.y,scroll_before),"a full refresh keeps the scroll")
	# A changed order rebuilds.
	var moved: String=f.bag.sorted_references.pop_back()
	f.bag.sorted_references.insert(0,moved)
	stages=int(view.stats.stages)
	var reordered: Dictionary=view.refresh_rows()
	check(not reordered.get("rows_only",false) and int(view.stats.stages)==stages+1,"a changed order rebuilds")
	# Reopen must use the retained authored shell, never a fake or legacy row.
	var open_identity: Node2D=view._scene
	view.close()
	check(not view.is_open() and not open_identity.visible,"original closed shell is hidden")
	started=Time.get_ticks_usec()
	var reopened: Dictionary=view.open(f.host)
	samples["reopen_ms"]=float(Time.get_ticks_usec()-started)/1000.0
	check(reopened.get("reused_scene",false) and view._scene==open_identity,"reopen replays the original native shell")
	check(is_equal_approx(view._scroll_content.position.y,view._scroll_top),"reopen resets original scroll to its authored top")
	samples["stats"]=view.stats.duplicate()
	view.close(false)
	f.host.free()
