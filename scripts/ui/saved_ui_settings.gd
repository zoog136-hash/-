extends RefCounted
## Apply the user's persisted HUD and audio settings before the settings panel opens.

const SETTINGS_PATH = "user://twilight_ui_settings.cfg"
const UI = preload("res://scripts/ui/renewal_theme.gd")

static func apply_saved(controller: Node) -> void:
	var saved := ConfigFile.new()
	var load_error: Error = saved.load(SETTINGS_PATH)
	UI.set_reduced_motion(bool(saved.get_value("visual","reduced_motion",false)))
	if load_error != OK: return
	if controller.log_label != null:
		controller.log_label.visible = bool(saved.get_value("interface","combat_log",true))
	if controller.coordinates_readout != null:
		controller.coordinates_readout.visible = bool(saved.get_value("interface","coordinates",true))
	if AudioServer.get_bus_count() > 0:
		var level := clampf(float(saved.get_value("audio","volume",100.0)),0.0,100.0)
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,level/100.0)))
		AudioServer.set_bus_mute(0,bool(saved.get_value("audio","muted",false)) or level <= 0.0)
