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
	root.size = Vector2i(1280,720)
	await process_frame
	var theme: Theme = UI.make_theme()
	_check(theme.has_stylebox("panel","PanelContainer"),"shared panel theme")
	_check(theme.has_stylebox("normal","Button"),"shared button theme")
	_check(theme.has_stylebox("panel","ItemList"),"codex list frame")
	_check(theme.has_stylebox("separator","HSeparator"),"gold sectional divider")
	_check(theme.has_stylebox("fill","ProgressBar"),"status bar style")
	var panel: StyleBoxFlat = UI.chrome_panel()
	_check(panel.border_width_top == 2 and panel.border_width_left == 1,"thin game-window rim")
	_check(UI.slot_frame(UI.GOLD,true).border_color == UI.GOLD,"selected item border")
	var window: PanelContainer = RenewalWindow.new()
	root.add_child(window)
	await process_frame
	var title: Control = window.find_child("WorkspaceTitleDragArea",true,false) as Control
	var nav: ScrollContainer = window.find_child("WorkspaceNavigationScroll",true,false) as ScrollContainer
	var crest: Control = window.find_child("DecorativeFrame",true,false) as Control
	var compact: Button = window.find_child("CompactMenuButton",true,false) as Button
	_check(title != null and title.mouse_filter == Control.MOUSE_FILTER_STOP,"title drag zone preserved")
	_check(nav == null,"content windows do not include dashboard navigation")
	_check(crest == null,"no ornamental header occupying content area")
	_check(compact != null and not compact.visible,"menu shortcut stays hidden without a navigation controller")
	window.open("inventory","인벤토리","선택한 장비를 확인합니다.")
	var active: Button = window.find_child("Nav_inventory",true,false) as Button
	_check(active == null and window.current_section == "inventory","inventory has its own window profile")
	_check(window.size.x <= 378 and window.position.x > 800,"inventory is a right shelf")
	_check(window.find_child("CloseWindow",true,false) != null,"close and Esc action retained")
	# Content windows keep the real menu shortcut; it appears only when the
	# owning HUD connects navigation and must send the actual requested section.
	var requested: Array[String] = []
	window.navigate.connect(func(section: String) -> void: requested.append(section))
	window.open("inventory","인벤토리","선택한 장비를 확인합니다.")
	_check(compact != null and compact.visible,"connected inventory exposes the menu shortcut")
	if compact != null: compact.pressed.emit()
	_check(requested == ["menu"],"content shortcut routes to the actual game menu")
	window.open("menu","메뉴","")
	var teleport: Button = window.find_child("MenuTeleportShortcut",true,false) as Button
	_check(compact != null and not compact.visible and teleport != null and teleport.visible,"menu keeps its regional travel action without a recursive menu button")
	if teleport != null: teleport.pressed.emit()
	_check(requested == ["menu","teleport"],"menu travel shortcut preserves the existing teleport route")
	window.open("class_select","직업 선택","")
	_check(compact != null and not compact.visible and teleport != null and not teleport.visible,"class selection hides game-navigation shortcuts")
	window.queue_free()
	await process_frame
	if failures.is_empty():
		print("LINEAGEM_UI_VISUAL_OK")
		quit(0)
	else:
		print("LINEAGEM_UI_VISUAL_FAILED: %d" % failures.size())
		quit(1)
