extends "res://tests/pr100_direction_gameplay_test.gd"
## Read-only reproduction of the pre-candidate arena gate. No weaker clearance.
const RawLoader = preload("res://tests/pr122_published_boss_approval_main.gd")
const Positions = preload("res://tests/active_source_test_positions.gd")
var image_loader: ResourceFormatLoader

func run() -> void:
	image_loader = RawLoader.NativeImageLoader.new()
	ResourceLoader.add_resource_format_loader(image_loader, true)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world, "사신"), "real Main production class entry")
	world.hud.class_selected.emit(3)
	world.hud._hide_aux_panels()
	world.save_timer = -10000.0
	world.rng.seed = 20261013
	world._set_map("aden_world", false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._equip_or_acquire_item(world._find_catalog_item_record("배틀 사이드"), true)
	for record: Dictionary in world.catalog_db["변신"]:
		if str(record.get("sourceId", "")) == "288": world._equip_catalog("변신", record); break
	await tick(14)
	var point := find_clearing()
	var result := {"actual_Main": true, "map": "aden_world", "candidate_injected": false,
		"original_find_clearing_pass": point.is_finite(), "production_profile": world.player.motion.profile.frames_path,
		"field_class": world.field_map.get_script().resource_path, "sampled_cells": 0,
		"walkable": 0, "point_clear": 0, "not_safe": 0, "all_150px_spokes": 0,
		"fixture_motion_clear": 0, "largest_spawn_rect": [], "errors": failures,
		"new_quality_approvals": 0, "gate_requirements_unchanged": true}
	var offsets: Array = []
	for d: int in range(8): offsets.append(screen_direction(d) * 150.0)
	var largest: float = 0.0
	if world.field_map is NativePngField:
		var field: NativePngField = world.field_map
		for region: Dictionary in field.data.get("monster_spawn", []):
			var rect: Array = region.get("rect", [])
			if rect.size() == 4 and float(rect[2])*float(rect[3]) > largest:
				largest = float(rect[2])*float(rect[3]); result.largest_spawn_rect = rect
			var cells: Array[Vector2i] = field.spawn_cells.get(str(region.id), [])
			var stride: int = maxi(1, ceili(float(cells.size())/768.0))
			for i: int in range(0, cells.size(), stride):
				var p: Vector2 = field.cell_to_world(cells[i])
				result.sampled_cells += 1
				if field.walkable(p): result.walkable += 1
				if field.point_clear(p): result.point_clear += 1
				if not field.is_safe(p): result.not_safe += 1
				if Positions._fits(field, p, offsets):
					result.all_150px_spokes += 1
					if Positions._native_motion_fits(field,p,offsets,50.0): result.fixture_motion_clear += 1
	result["classification"] = "ARENA_GATE_PASS_NOT_ANIMATION_APPROVAL" if point.is_finite() else "BLOCKED_BEFORE_CANDIDATE_ANIMATION_NOT_EVALUATED"
	var output := FileAccess.open(OS.get_environment("BOSS_DEFAULT_MAIN_OUTPUT").path_join("clearing-probe.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t")+"\n")
	print("PR122_CLEARING_PROBE " + JSON.stringify(result))
	world.queue_free()
	await process_frame
	ResourceLoader.remove_resource_format_loader(image_loader)
	quit(0)
