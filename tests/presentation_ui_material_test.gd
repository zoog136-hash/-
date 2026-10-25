extends SceneTree

const UI = preload("res://scripts/ui/renewal_theme.gd")
const Icons = preload("res://scripts/ui/renewal_icons.gd")
const MaterialStyle = preload("res://scripts/ui/renewal_material_style.gd")
const WindowScript = preload("res://scripts/ui/renewal_window.gd")
var failures: Array[String] = []
var assertions: int = 0

class AudioProbe extends Node:
	var events: Array[String] = []
	func play_ui(event: String) -> bool:
		events.append(event)
		return true

func _initialize() -> void: call_deferred("_run")
func _check(value: bool, why: String) -> void:
	assertions += 1
	if not value: failures.append(why); printerr("PRESENTATION_UI_FAIL "+why)

func _run() -> void:
	root.size = Vector2i(1280,720)
	await process_frame
	var menu_bytes := Icons.texture("menu").get_image().get_data()
	var distinct: Array[PackedByteArray] = []
	for kind: String in ["warehouse","crafting","sell","teleport","equipment_collections"]:
		var texture: Texture2D = UI.icon(kind)
		_check(texture != null and texture.get_size() == Vector2(64,64),"dedicated readable icon "+kind)
		var bytes := texture.get_image().get_data()
		_check(bytes != menu_bytes and not distinct.has(bytes),"dedicated service silhouette "+kind)
		distinct.append(bytes)
		_check(UI.icon(kind) == texture,"cached service icon "+kind)
	var unknown: Texture2D = UI.icon("missing-service-a")
	var count: int = Icons.cache.size()
	_check(unknown == UI.icon("missing-service-b") and Icons.cache.size() == count,"unknown keys share one neutral cache entry")
	_check(unknown.get_image().get_data() != menu_bytes,"unknown icon does not impersonate navigation menu")
	_check(UI.icon("변신") == Icons.texture("transform"),"existing category binding preserved")
	_check(UI.icon("inventory") == UI.icon("inventory"),"existing PNG handle reused")
	var theme: Theme = UI.make_theme()
	var texture_count: int = MaterialStyle.textures.size()
	var second: Theme = UI.make_theme()
	_check(MaterialStyle.textures.size() == texture_count,"reopening window does not allocate more material textures")
	_check(theme.get_stylebox("normal","Button").texture == second.get_stylebox("normal","Button").texture,"themes share immutable material texture")
	for state: String in ["normal","hover","pressed","disabled"]:
		var style: StyleBoxTexture = theme.get_stylebox(state,"Button")
		_check(style != null and style.texture != null,"button material state "+state)
		_check(style.get_content_margin(SIDE_LEFT) == 7,"button layout margin unchanged "+state)
	_check(theme.get_stylebox("normal","Button").texture != theme.get_stylebox("pressed","Button").texture,"press reverses relief")
	var window := WindowScript.new()
	root.add_child(window)
	window.open("inventory","인벤토리","")
	await process_frame
	var surface: Control = window.get_node("WindowMaterialSurface")
	_check(surface.mouse_filter == Control.MOUSE_FILTER_IGNORE and surface.focus_mode == Control.FOCUS_NONE,"window material cannot capture gestures/focus")
	_check(not surface.is_processing() and not surface.is_physics_processing(),"material has no frame callback")
	_check(surface.get_index() < window.content.get_parent().get_index(),"material stays below text and content")
	_check(window.size.x <= 378 and window.position.x > 800,"actual inventory shelf bounds unchanged")
	var probe := AudioProbe.new()
	root.add_child(probe)
	probe.add_to_group("presentation_audio")
	var actions: Array[int] = []
	var button := UI.button("창고",func() -> void: actions.append(1))
	root.add_child(button)
	_check(probe.events.is_empty(),"constructing controls is silent")
	button.pressed.emit()
	_check(actions == [1] and probe.events == ["button"],"one action and one sound per accepted press")
	button.disabled = true
	button.pressed.emit()
	_check(probe.events == ["button"],"disabled synthetic signal cannot play UI sound")
	button.queue_free(); probe.queue_free(); window.queue_free()
	await process_frame
	print("PRESENTATION_UI_RESULT ",JSON.stringify({"assertions":assertions,"failures":failures}))
	if failures.is_empty(): print("PRESENTATION_UI_OK")
	quit(0 if failures.is_empty() else 1)
