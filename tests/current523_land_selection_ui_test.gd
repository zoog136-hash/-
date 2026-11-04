extends SceneTree
## Existing real Settings controls, actual verified catalog; no synthetic map.
const SETTINGS=preload("res://scripts/ui/current523_aden_review_settings.gd")
var checks: int=0
var failures: Array[String]=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var first: String="";var alternate: String="";var pin: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-root="):first=arg.trim_prefix("--source-root=")
		if arg.begins_with("--alternate-root="):alternate=arg.trim_prefix("--alternate-root=")
		if arg.begins_with("--source-sha="):pin=arg.trim_prefix("--source-sha=")
	var panel:=SETTINGS.new();root.add_child(panel);panel.configure(null)
	panel.raw_path_edit.text=first;panel.source_manifest.text=pin
	panel._reload_native_lands(12582)
	check(panel.native_land_choice.item_count==997 and panel.native_land_choice.get_selected_id()==12582 and panel._native_catalog_loads==1,"actual verified logical listing")
	panel.source_entry_enabled.button_pressed=true;panel._reload_native_lands()
	check(panel.native_land_choice.get_selected_id()==12582 and panel.source_entry_enabled.button_pressed and panel._native_catalog_loads==1,"same verified refresh preserves selected identity and explicit input without reparse")
	panel._reload_native_lands(22582)
	check(panel.native_land_choice.get_selected_id()==22582 and not panel.source_entry_enabled.button_pressed,"programmatic different logical selection cannot retain prior coordinate input")
	panel.source_entry_enabled.button_pressed=true
	panel.raw_path_edit.text=alternate;panel._reload_native_lands(22582)
	check(panel.native_land_choice.get_selected_id()==22582 and not panel.source_entry_enabled.button_pressed and panel._native_catalog_loads==2,"a new actual directory identity clears coordinates even with identical catalog SHA and logical ID")
	var cached: RefCounted=panel._native_catalog
	panel.source_entry_enabled.button_pressed=true;panel.source_manifest.text="0".repeat(64);panel._reload_native_lands()
	check(panel.native_land_choice.item_count==0 and not panel.source_entry_enabled.button_pressed and panel._native_catalog==cached and panel._native_catalog_loads==2,"wrong pin clears listing/input and preserves last valid immutable cache")
	panel.source_entry_enabled.button_pressed=true;panel.source_manifest.text=pin;panel.raw_path_edit.text="/missing/source-catalog";panel._reload_native_lands()
	check(panel.native_land_choice.item_count==0 and not panel.source_entry_enabled.button_pressed and panel._native_catalog==cached and panel._native_catalog_loads==2,"missing candidate cannot carry an explicit coordinate to another context")
	panel.raw_path_edit.text=alternate;panel._reload_native_lands(22582)
	check(panel.native_land_choice.item_count==997 and panel.native_land_choice.get_selected_id()==22582 and not panel.source_entry_enabled.button_pressed and panel._native_catalog_loads==2,"valid identity recovers without reparse or stale input")
	for index: int in panel.native_land_choice.item_count:
		if panel.native_land_choice.get_item_id(index)==12582:
			panel.source_entry_enabled.button_pressed=true;panel.native_land_choice.select(index);panel.native_land_choice.item_selected.emit(index)
			check(not panel.source_entry_enabled.button_pressed,"ordinary user selection retains the existing stale-input guard")
	print("CURRENT523_LAND_SELECTION_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_Settings_controls":true,"actual_catalog":true,"actual_Main":false,"new_geometry_play":false}))
	panel.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
