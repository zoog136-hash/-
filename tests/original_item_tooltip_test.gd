extends SceneTree
## One tap on a bag item opens the original item information popup
## (UI/ToolTip/ToolTip_CommonType.csb) instead of the small TWILIGHT label
## (user request 2026-11-20).
## Always: wiring (bag -> original HUD -> popup, closed with the bag), the
## popup hides its online/unconnected controls and mounts only the held item's
## connected actions; values text of a record.
## With the original UI pack (TWILIGHT_SOURCE_UI) and 523 tables: the real
## popup opens with the original name, grade color, icon and description.
##   godot --headless --path <repo> --script res://tests/original_item_tooltip_test.gd
const TOOLTIP = preload("res://scripts/ui/original_ui/source_main_item_tooltip.gd")
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const IDENTITY = preload("res://scripts/ui/source523_item_identity.gd")
const TREE = preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const ICON_GROUPS: Array[String] = ["Business", "Del", "Warehouse", "Enchant", "Probability", "Detail"]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ORIGINAL_ITEM_TOOLTIP_FAIL: " + label)

func _initialize() -> void:
	sources()
	action_projection()
	values()
	outside_close()
	_finish.call_deferred()

func _finish() -> void:
	real_pack()
	print("ORIGINAL_ITEM_TOOLTIP_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func sources() -> void:
	var bag: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_inventory.gd")
	check(bag.contains("original_hud.call(\"try_open_item_tooltip\"") and bag.contains("original_hud.call(\"close_item_tooltip\")"), "the bag opens and closes the original popup")
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(hud.contains("func try_open_item_tooltip(") and hud.contains("close_item_tooltip()\n\tif _inventory_view!=null:_inventory_view.close()"), "the original HUD owns the popup and closes it with the bag")
	check(TOOLTIP.MEMBER == "UI/ToolTip/ToolTip_CommonType.csb", "the popup is the original ToolTip_CommonType")
	for name: String in ["Nd_Btn","Nd_Btn_Collection","Btn_Compare","SetBuff_On","SetBuff_Off"]:
		check(TOOLTIP.HIDDEN.has(name), "online/unconnected control %s is not shown" % name)
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_item_tooltip.gd")
	check(not text.contains("Image.create") and not text.contains("draw_rect"), "no picture is drawn")

class CaptureTree extends RefCounted:
	var spec: Dictionary
	func scene_of(_member: String, bindings: Dictionary, _out: Dictionary) -> Dictionary:
		spec = bindings
		return {"ok":false,"code":"capture_original_tooltip_spec"}

func action_projection() -> void:
	var popup = TOOLTIP.new()
	var parent := Node2D.new()
	var capture := CaptureTree.new()
	popup._tree = capture
	var action := func() -> Dictionary: return {"ok":true}
	for actions: Dictionary in [{}, {"delete":Callable(),"acquisition":Callable(),"business":action}, {"delete":action}, {"acquisition":action}, {"delete":action,"acquisition":action}]:
		var result: Dictionary = popup.open(parent,"held@@@verified","상세",0,0,{},actions)
		check(result.get("code")=="capture_original_tooltip_spec", "production popup supplied its original node scope")
		var allowed: Array[String] = allowed_groups(actions)
		check(capture.spec.get("Icon_Set",{}).get("exclude",false)==allowed.is_empty(), "no valid scoped actions hides the entire original icon strip")
		if allowed.is_empty(): continue
		for group: String in ICON_GROUPS:
			check(capture.spec.get("Icon_Set/"+group+"_Off",{}).get("exclude",false), "no unconnected/inactive variant: "+group)
			var on: String = "Icon_Set/"+group+"_On"
			if group in allowed:
				var button: Dictionary = capture.spec.get(on+"/Btn_Icon",{})
				check(capture.spec.get(on,{}).get("visible",false) and button.get("activate")==action and button.get("touch_enabled",false), "only a bound action activates original "+group)
			else:
				check(capture.spec.get(on,{}).get("exclude",false), "an unconnected action cannot mount original "+group)
	parent.free()

static func allowed_groups(actions: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if (actions.get("delete",Callable()) as Callable).is_valid(): result.append("Del")
	if (actions.get("acquisition",Callable()) as Callable).is_valid(): result.append("Detail")
	return result

func values() -> void:
	var lines: String = TOOLTIP.stats({"small_damage":7,"large_damage":5,"def":0,"hit":2,"hpFlat":30})
	check(lines == "대미지 7 / 5\n명중 +2\n최대 HP +30", "equipment values from the record (%s)" % lines)
	check(TOOLTIP.stats({"name":"물약"}) == "", "no values for a plain item")

func real_pack() -> void:
	var root: String = OS.get_environment("TWILIGHT_SOURCE_UI")
	var sha: String = OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	if root.is_empty() or sha.is_empty():
		evidence["real"] = "original UI pack not installed: real popup skipped"
		return
	var pack = PACK.new()
	var opened: Dictionary = pack.open(root, sha)
	if not opened.get("ok", false) or not pack.manifest.get("scenes", {}).has(TOOLTIP.MEMBER):
		evidence["real"] = "UI pack without ToolTip_CommonType: skipped (%s)" % str(opened.get("error", ""))
		return
	var popup = TOOLTIP.new()
	check(popup.configure(pack).get("ok", false), "the popup configures from the installed UI pack")
	var parent := Node2D.new()
	get_root().add_child(parent)
	real_action_visibility(popup,parent)
	if SOURCE.not_installed():
		evidence["real"] = "original UI action visibility checked; 523 data/icon case skipped without source tables"
		parent.free()
		return
	var name: String = IDENTITY.original_name(6161)
	var result: Dictionary = popup.open(parent, "각인 장비 상자", name, 6161, int(IDENTITY.row(6161).get("GradeID", 0)))
	evidence["real"] = result.duplicate()
	check(result.get("ok", false) and popup.is_open(), "the original popup opens")
	check(str(result.get("title", "")) == "각인 장비 상자", "original name in the title")
	check(str(result.get("description", "")).contains("각인 장비 상자로"), "original StoryDescID description")
	check(not str(result.get("grade_color", "")).is_empty(), "original grade color")
	check(result.get("picture", false), "original icon in the popup slot")
	popup.close()
	check(not popup.is_open(), "the popup closes")
	parent.free()

func real_action_visibility(popup: RefCounted, parent: Node2D) -> void:
	var action := func() -> Dictionary: return {"ok":true}
	for actions: Dictionary in [{}, {"delete":action}, {"acquisition":action}, {"delete":action,"acquisition":action}]:
		var result: Dictionary = popup.open(parent,"held@@@verified","상세",0,0,{},actions)
		check(result.get("ok",false) and popup.is_open(), "original tooltip stages with its item action scope")
		if not result.get("ok",false): continue
		var allowed: Array[String] = allowed_groups(actions)
		var strip: Dictionary = TREE.locate(popup._scene,popup._out,"Icon_Set")
		check(strip.get("ok",false)==not allowed.is_empty(), "authored icon strip exists only for connected actions")
		for group: String in ICON_GROUPS:
			for state: String in ["On","Off"]:
				var path: String = "Icon_Set/"+group+"_"+state
				var located: Dictionary = TREE.locate(popup._scene,popup._out,path)
				var visible_now: bool = located.get("ok",false) and located.player.source_nodes[located.offset].is_visible_in_tree()
				check(visible_now==(state=="On" and group in allowed), "exact original visible state: "+path+" for "+str(allowed))
				if state!="On" or group not in allowed: continue
				var original_button: Dictionary = TREE.locate(popup._scene,popup._out,path+"/Btn_Icon")
				var native: Node = original_button.player.source_nodes[original_button.offset] if original_button.get("ok",false) else null
				var button: Node = native.get_meta("source_button") if is_instance_valid(native) and native.has_meta("source_button") else null
				var area: Control = button.get("_input_area") if is_instance_valid(button) else null
				check(is_instance_valid(area) and area.is_visible_in_tree(), "only the corresponding original button is touch-enabled: "+path)
		popup.close()

class FakePopup extends RefCounted:
	var _scene: Node2D
	var closed: int = 0
	func close() -> void: closed += 1

## The popup has no X (2026-11-21): a tap outside its Bg panel closes it, a
## tap inside keeps it, and a closer of a replaced popup closes nothing.
func outside_close() -> void:
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_item_tooltip.gd")
	check(text.contains("var closer: bool=_attach_outside_closer()") and not text.contains("set_input_as_handled"), "every opened popup gets the outside closer, which never consumes the tap")
	var scene := Node2D.new()
	root.add_child(scene)
	var panel := Node2D.new()
	panel.position = Vector2(200, 200)
	panel.set_meta("source_size", [100, 50])
	scene.add_child(panel)
	var popup := FakePopup.new()
	popup._scene = scene
	var closer = TOOLTIP.OutsideCloser.new()
	closer.popup = weakref(popup)
	closer.panel = weakref(panel)
	scene.add_child(closer)
	check(closer.panel_rect().is_equal_approx(Rect2(200, 150, 100, 50)), "the closer reads the panel's area: " + str(closer.panel_rect()))
	var press := InputEventScreenTouch.new(); press.pressed = true; press.position = Vector2(250, 175)
	closer._input(press)
	check(not closer._pressed_outside, "a press inside the panel is not an outside tap")
	press.position = Vector2(10, 10)
	closer._input(press)
	check(closer._pressed_outside, "a press outside the panel starts an outside tap")
	closer._close()
	check(popup.closed == 1, "the outside tap closes its own popup")
	popup._scene = Node2D.new()
	closer._close()
	check(popup.closed == 1, "a newer popup (another item tapped) is not closed by the old closer")
	popup._scene.free()
	scene.free()
