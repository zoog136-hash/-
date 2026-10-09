extends RefCounted

# Render/benchmark harnesses launch with no save. Simulate the same class
# confirmation a player performs before benchmarking active gameplay.
# This is test-only and must not disable the production startup picker.
static func enter_game(world: TwilightWorld) -> bool:
	var hud: Node = world.get_node_or_null("HUD")
	if hud == null:
		return false
	if not bool(hud.get("class_picker_initial")):
		return true
	var window: Control = hud.get("workspace") as Control
	if window == null:
		return false
	var knight: Button = window.find_child("Class_기사",true,false) as Button
	var confirm: Button = window.find_child("ClassConfirm",true,false) as Button
	if knight == null or confirm == null:
		return false
	knight.pressed.emit()
	if confirm.disabled:
		return false
	confirm.pressed.emit()
	return not bool(hud.get("class_picker_initial")) and world.job_class == "기사"
