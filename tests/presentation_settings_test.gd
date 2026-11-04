extends SceneTree

const PREFS = preload("res://scripts/animation/presentation_preferences.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("PRESENTATION_SETTINGS_FAIL: ", label)

func run() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("visual", "effect_detail", "low")
	cfg.set_value("audio", "volume", 37.0)
	cfg.set_value("custom", "preserve", "untouched")
	check(cfg.save("user://twilight_ui_settings.cfg") == OK, "legacy UI preference fixture")
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual Main enters current game")
	world.player.set_physics_process(false)
	check(world.presentation_settings.effect_detail == "low", "legacy simplified setting preserved")
	check(not world.presentation_settings.hide_doll and not world.presentation_settings.limit_effect_count, "new options default off")
	check(world._save_game(true) == OK, "baseline save")
	var saved_path: String = world.save_path()
	var saved_hash: String = FileAccess.get_sha256(saved_path)
	var equipped: Dictionary = world.equipped_catalog.duplicate(true)
	var attack: int = world._effective_attack()
	var hp_limit: int = world._effective_max_hp()
	world.hud.open_settings_info()
	await process_frame
	var ui: Node = world.hud.find_child("RenewalSettings", true, false)
	check(ui != null, "game menu opens actual settings panel")
	if ui == null:
		quit(1)
		return
	check(ui.effect_detail.selected == 1 and not ui.hide_doll.button_pressed, "controls show saved defaults")
	world.secondary_doll_visual = preload("res://scripts/cards/native_doll_subslot_visual.gd").new()
	world.add_child(world.secondary_doll_visual)
	ui.region_override.button_pressed = true
	ui.hide_doll.button_pressed = true
	check(not world.secondary_doll_visual.visible, "secondary doll container also hides")
	ui.limit_effect_count.button_pressed = true
	ui.effect_detail.select(0)
	ui.effect_detail.item_selected.emit(0)
	check(world.presentation_settings.hide_doll and not world.get_node("Companion").visible, "UI hides common doll parent")
	check(world.presentation_settings.effect_detail == "full", "UI regional detail applies immediately")
	check(world.presentation_global_settings.effect_detail == "low" and not world.presentation_global_settings.hide_doll, "regional controls preserve global preferences")
	check(world.combat_vfx.impact_visual_limit == 24 and world.combat_flights.visual_limit == 24, "count control reaches real VFX and flights")
	world.original_skills.tick(0.0)
	check(world.original_skills.vfx.detail_limit == 64 and not world.original_skills.vfx.low_detail, "count budget independent of simplified skill art")
	var other: Dictionary = PREFS.effective(world.presentation_global_settings,world.presentation_region_settings,"unconfigured_region")
	check(other.effect_detail == "low" and not other.hide_doll and not other.limit_effect_count, "separate map inherits global settings")
	world._set_map(world.active_map_id, true)
	check(world.presentation_settings.hide_doll, "real same-map transition reapplies regional choice")
	world._set_map("invalid-map-id", false)
	check(world.presentation_settings.hide_doll, "rejected map transition preserves choice")
	var restored := ConfigFile.new()
	check(restored.load("user://twilight_ui_settings.cfg") == OK, "preferences saved")
	check(restored.get_value("audio","volume") == 37.0 and restored.get_value("custom","preserve") == "untouched", "unrelated settings preserved")
	check(restored.get_value("visual","effect_detail") == "low", "regional edit leaves saved global detail")
	check(restored.get_value("visual_regions",world.active_map_id).hide_doll, "region dictionary persisted")
	check(FileAccess.get_sha256(saved_path) == saved_hash, "UI and map presentation leave save bytes unchanged")
	check(world.equipped_catalog == equipped and world._effective_attack() == attack and world._effective_max_hp() == hp_limit, "hide preserves equipment and gameplay stats")
	# The shared parent covers native and legacy attachments without pixel copies.
	var attachment := Node2D.new()
	world.get_node("Companion").add_child(attachment)
	check(not attachment.is_visible_in_tree(), "all doll attachments inherit hide")
	var old_clock: float = world.doll_motion.motion.state_clock
	for i: int in range(500): world._update_companion(1.0/60.0)
	check(world.doll_motion.motion.state_clock == old_clock, "hidden follower skips motion work")
	ui.region_override.button_pressed = false
	check(not world.presentation_settings.hide_doll and world.get_node("Companion").visible, "UI restores doll immediately")
	check(world.presentation_settings.effect_detail == "low" and world.combat_vfx.impact_visual_limit == 160, "turning region off restores legacy detail and full count")
	check(not world.presentation_region_settings.has(world.active_map_id), "override removed")
	check(not PREFS.region({"hide_doll":"false", "limit_effect_count":1, "effect_detail":"bad"}).size(), "malformed override cannot lower quality")
	var defaults: Dictionary = PREFS.effective({}, {}, "anywhere")
	check(defaults.effect_detail == "full" and not defaults.hide_doll and not defaults.limit_effect_count, "fresh defaults unchanged")
	# Flight callbacks remain authoritative even when visuals are limited.
	var target := Node2D.new()
	root.add_child(target)
	var hits: Array[int] = [0]
	world.combat_flights.visual_limit = 24
	for i: int in range(80): world.combat_flights.launch(target.position,target,"arrow",func() -> void: hits[0] += 1)
	world.combat_flights._physics_process(1.0)
	check(hits[0] == 80 and world.combat_flights.flights.is_empty(), "80 limited flights retain every callback")
	ui.region_override.button_pressed = true
	ui.hide_doll.button_pressed = true
	target.queue_free()
	attachment.queue_free()
	world.queue_free()
	await process_frame
	# A new actual Main reads the preferences; no stale in-memory-only setting.
	var reopened: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(reopened)
	reopened.set_process(false)
	reopened.save_timer = -100000.0
	check(QA.enter_game(reopened), "actual Main restarts")
	check(reopened.presentation_settings.effect_detail == "low" and reopened.presentation_settings.hide_doll, "restart loads saved regional hide and legacy detail")
	check(FileAccess.get_sha256(saved_path) == saved_hash, "restart preserves save bytes")
	reopened.queue_free()
	await process_frame
	print("PRESENTATION_SETTINGS_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
