extends SceneTree

const UI = preload("res://scripts/ui/renewal_theme.gd")
const RenewalWindow = preload("res://scripts/ui/renewal_window.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("LINEAGEM_UI_FAIL: " + description)

func _run() -> void:
	var theme: Theme = UI.make_theme()
	_check(theme.has_stylebox("panel","PanelContainer"),"shared panel theme")
	_check(theme.has_stylebox("normal","Button"),"shared button theme")
	_check(theme.has_stylebox("panel","ItemList"),"codex list frame")
	_check(theme.has_stylebox("separator","HSeparator"),"gold sectional divider")
	_check(theme.has_stylebox("fill","ProgressBar"),"status bar style")
	var panel: StyleBoxFlat = UI.chrome_panel()
	_check(panel.border_width_top == 2 and panel.border_width_left == 2,"raised metallic rim")
	_check(UI.slot_frame(UI.GOLD,true).border_color == UI.GOLD,"selected item border")
	var window: PanelContainer = RenewalWindow.new()
	root.add_child(window)
	await process_frame
	var title: Control = window.find_child("WorkspaceTitleDragArea",true,false) as Control
	var crest: Control = window.find_child("DecorativeFrame",true,false) as Control
	var compact: Button = window.find_child("CompactMenuButton",true,false) as Button
	_check(title != null and title.mouse_filter == Control.MOUSE_FILTER_STOP,"title drag zone preserved")
	_check(window.find_child("WorkspaceNavigationScroll",true,false) == null,"global navigation rail no longer covers the playfield")
	_check(crest != null and crest.mouse_filter == Control.MOUSE_FILTER_IGNORE,"ornament is input-transparent")
	_check(compact != null,"compact workspace navigation fallback")
	window.open("inventory","인벤토리","선택한 장비를 확인합니다.")
	_check(window.is_drawer() and window.heading.text == "인벤토리","active inventory route uses gameplay drawer")
	_check(window.size.x <= 480 and window.position.x >= root.get_visible_rect().size.x*.5,"inventory occupies the right edge and leaves the center visible")
	_check(window.find_child("CloseWindow",true,false) != null,"close and Esc action retained")
	window.queue_free()
	await process_frame
	if failures.is_empty():
		print("LINEAGEM_UI_VISUAL_OK")
		quit(0)
	else:
		print("LINEAGEM_UI_VISUAL_FAILED: %d" % failures.size())
		quit(1)
