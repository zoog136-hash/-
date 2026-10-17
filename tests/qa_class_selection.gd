extends RefCounted

# Render/benchmark harnesses launch with no save. Simulate the same class
# confirmation a player performs before benchmarking active gameplay.
# This is test-only and must not disable the production startup picker.
static func enter_game(world: Node, job: String = "기사") -> bool:
	var hud: Node = world.get_node_or_null("HUD")
	if hud == null:
		return false
	# The older benchmark baseline has no class picker, so proceed directly.
	if not hud.has_method("open_class_selection"):
		return true
	if not bool(hud.get("class_picker_initial")):
		if str(world.get("job_class"))==job: return true
		# A save or already-entered session uses the same class window from the
		# menu; the requested bow/mage capture must not silently keep a knight.
		hud.call("open_class_selection",false)
	var window: Control = hud.get("workspace") as Control
	if window == null:
		return false
	var selected: Button = window.find_child("Class_"+job,true,false) as Button
	var confirm: Button = window.find_child("ClassConfirm",true,false) as Button
	if selected == null or confirm == null:
		return false
	selected.pressed.emit()
	if confirm.disabled:
		return false
	confirm.pressed.emit()
	return not bool(hud.get("class_picker_initial")) and str(world.get("job_class")) == job
