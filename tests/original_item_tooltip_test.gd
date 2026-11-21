extends SceneTree
## One tap on a bag item opens the original item information popup
## (UI/ToolTip/ToolTip_CommonType.csb) instead of the small TWILIGHT label
## (user request 2026-11-20).
## Always: wiring (bag -> original HUD -> popup, closed with the bag), the
## popup hides its online/unconnected controls, values text of a record.
## With the original UI pack (TWILIGHT_SOURCE_UI) and 523 tables: the real
## popup opens with the original name, grade color, icon and description.
##   godot --headless --path <repo> --script res://tests/original_item_tooltip_test.gd
const TOOLTIP = preload("res://scripts/ui/original_ui/source_main_item_tooltip.gd")
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const IDENTITY = preload("res://scripts/ui/source523_item_identity.gd")
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
	values()
	real_pack()
	outside_close()
	print("ORIGINAL_ITEM_TOOLTIP_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func sources() -> void:
	var bag: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_inventory.gd")
	check(bag.contains("original_hud.call(\"try_open_item_tooltip\"") and bag.contains("original_hud.call(\"close_item_tooltip\")"), "the bag opens and closes the original popup")
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(hud.contains("func try_open_item_tooltip(") and hud.contains("close_item_tooltip()\n\tif _inventory_view!=null:_inventory_view.close()"), "the original HUD owns the popup and closes it with the bag")
	check(TOOLTIP.MEMBER == "UI/ToolTip/ToolTip_CommonType.csb", "the popup is the original ToolTip_CommonType")
	for name: String in ["Icon_Set","Nd_Btn","Nd_Btn_Collection","Btn_Compare","SetBuff_On","SetBuff_Off"]:
		check(TOOLTIP.HIDDEN.has(name), "online/unconnected control %s is not shown" % name)
	var text: String = FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_item_tooltip.gd")
	check(not text.contains("Image.create") and not text.contains("draw_rect"), "no picture is drawn")

func values() -> void:
	var lines: String = TOOLTIP.stats({"small_damage":7,"large_damage":5,"def":0,"hit":2,"hpFlat":30})
	check(lines == "대미지 7 / 5\n명중 +2\n최대 HP +30", "equipment values from the record (%s)" % lines)
	check(TOOLTIP.stats({"name":"물약"}) == "", "no values for a plain item")

func real_pack() -> void:
	var root: String = OS.get_environment("TWILIGHT_SOURCE_UI")
	var sha: String = OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	if root.is_empty() or sha.is_empty() or SOURCE.not_installed():
		evidence["real"] = "original UI pack or 523 tables not installed: real popup skipped"
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
