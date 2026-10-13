extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const Settings = preload("res://scripts/ui/renewal_settings.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		print("REMAKE_UI FAIL: ",description)

func frames(count: int = 3) -> void:
	for index: int in range(count): await process_frame

func touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 51
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event,true)

func center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*.5)

func _run() -> void:
	root.size = Vector2i(1280,720)
	var had_settings: bool = FileAccess.file_exists(Settings.SETTINGS_PATH)
	var saved_settings: PackedByteArray = FileAccess.get_file_as_bytes(Settings.SETTINGS_PATH) if had_settings else PackedByteArray()
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	check(QA.enter_game(world),"class selection uses existing world signals")
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.player.clear_click_path()
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	var hud: Node = world.hud
	check(not hud.pointer_transfer.is_processing(),"idle pointer transfer performs no per-frame work")
	check(not hud.blocks_world_input(Vector2(720,360)),"open field remains available for movement")
	check(hud.blocks_world_input(center(hud.v20_auto_button)),"real combat button intercepts world touch")

	hud._navigate("settings")
	await frames()
	var settings: Node = hud.workspace.find_child("RenewalSettings",true,false)
	check(settings.get_script() == Settings,"presentation options are part of actual settings screen")
	var panel_point: Vector2 = hud.workspace.get_global_transform_with_canvas()*Vector2(3,3)
	check(hud.blocks_world_input(panel_point),"passive window frame blocks world input")
	touch(panel_point,true)
	touch(panel_point,false)
	check(world.player.click_path.is_empty(),"native window-frame touch cannot set a path")
	var original_quickslots: Array = world.quickslots.duplicate(true)
	var original_inventory: Dictionary = world.inventory.duplicate(true)
	settings.impact_intensity.value = 25
	settings.reduced_motion.button_pressed = true
	settings.effect_detail.select(1)
	settings.effect_detail.item_selected.emit(1)
	var config := ConfigFile.new()
	check(config.load(Settings.SETTINGS_PATH) == OK,"presentation preferences persist")
	check(is_equal_approx(float(config.get_value("visual","impact_intensity",1.0)),.25),"slider stores normalized effect intensity")
	check(bool(config.get_value("visual","reduced_motion",false)),"motion reduction persists")
	check(str(config.get_value("visual","effect_detail","full")) == "low","effect detail persists")
	check(world.has_method("apply_presentation_settings"),"settings have a real world application endpoint")
	check(is_equal_approx(world.combat_vfx.impact_intensity,.25),"slider immediately changes actual combat effects")
	check(world.combat_vfx.reduced_motion and world.player.motion.reduced_motion,"motion checkbox immediately updates world visuals")
	check(world.combat_vfx.detail_limit == 6 and world.combat_flights.visual_limit == 24,"detail selector immediately applies effect budgets")
	check(world.quickslots == original_quickslots and world.inventory == original_inventory,"presentation changes preserve gameplay items and bindings")
	var rare_record: Dictionary = {}
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if str(record.get("grade","")) == "영웅":
			rare_record = record
			break
	check(not rare_record.is_empty(),"rarity preference check uses an actual catalog item")
	var icon := TextureRect.new()
	icon.size = Vector2(56,56)
	icon.position = Vector2(600,300)
	hud.get_node("Root").add_child(icon)
	UI.apply_item_visual(icon,rare_record,str(rare_record.get("name","")),hud.item_image_index.get("아이템",{}),"detail")
	await frames()
	var item_visual: Node = icon.get_node("ItemVisual")
	check(icon.material == null and not item_visual.scheduler.is_processing(),"motion reduction removes rarity animation and suspends scheduler")
	settings.reduced_motion.button_pressed = false
	check(icon.material != null and item_visual.scheduler.is_processing(),"motion preference restores visible rarity animation immediately")
	settings.reduced_motion.button_pressed = true
	check(icon.material == null and not item_visual.scheduler.is_processing(),"motion preference stops existing rarity animation immediately")
	icon.queue_free()
	hud._close_workspace()
	await frames()
	hud._navigate("settings")
	await frames()
	var restored: HSlider = hud.workspace.find_child("ImpactIntensity",true,false)
	check(is_equal_approx(restored.value,25),"reopened settings restore effect intensity")
	check((hud.workspace.find_child("ReducedMotion",true,false) as CheckButton).button_pressed,"reopened settings restore motion preference")
	hud._close_workspace()
	await frames()

	# A clipped child outside its viewport must not reserve an invisible area.
	var clipped := Control.new()
	clipped.position = Vector2(600,280)
	clipped.size = Vector2(40,40)
	clipped.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clipped.clip_contents = true
	hud.get_node("Root").add_child(clipped)
	var hidden_button := Button.new()
	hidden_button.position = Vector2(90,0)
	hidden_button.size = Vector2(40,40)
	clipped.add_child(hidden_button)
	check(not hud.blocks_world_input(center(hidden_button)),"clipped control does not block exposed world")
	clipped.queue_free()
	await frames()

	hud.open_skills()
	await frames()
	var skills: Node = hud.skills_view
	skills.preview_button.pressed.emit()
	check(skills.preview_vfx.is_processing(),"visible skill preview animates")
	skills.hide()
	check(not skills.is_processing(),"hidden skill view suspends cooldown polling")
	check(skills.preview_vfx.live.is_empty() and not skills.preview_vfx.is_processing(),"hidden preview retires effects immediately")
	skills.show()
	check(skills.is_processing(),"visible skill view resumes live cooldown display")
	hud.open_catalog("아이템")
	await frames()
	check(hud.catalog_test_toggle.visible == OS.is_debug_build(),"grant tools are visible only in development builds")
	hud.catalog_test_toggle.button_pressed = true
	check(hud.catalog_test_tools.visible == OS.is_debug_build(),"grant panel obeys development-build gate")

	if had_settings:
		var file := FileAccess.open(Settings.SETTINGS_PATH,FileAccess.WRITE)
		file.store_buffer(saved_settings)
	else:
		DirAccess.remove_absolute(Settings.SETTINGS_PATH)
	world.queue_free()
	await frames()
	print("REMAKE_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty(): print("REMAKE_UI_OK")
	quit(0 if failures.is_empty() else 1)
