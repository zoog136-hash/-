extends "res://tests/aden_terrain_polish_test.gd"
## Real Main scene capture and regression for one authored Aden cottage.
const COTTAGE_AT := Vector2(1630,3610)
const COTTAGE_PATH := "res://assets/maps/aden/stone_cottage_v1.png"

func cottage() -> Sprite2D:
	for chunk: Node2D in world.field_renderer.chunks.values():
		for candidate: Node in chunk.get_children():
			if candidate is Sprite2D and candidate.position == COTTAGE_AT and str(candidate.get_meta("prop_kind","")) == "house":
				return candidate as Sprite2D
	return null

func building_view(label: String) -> void:
	world.player.camera.position = Vector2(-260,-150)
	await capture(label,Vector2(1980,3540))

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ADEN_BUILDING_SKIP: requires real OpenGL display; use tools/run_visual_capture.py")
		quit(0)
		return
	phase = OS.get_environment("ADEN_BUILDING_PHASE")
	if phase.is_empty(): phase = "after"
	directory = "user://aden-building/"+phase
	DirAccess.make_dir_recursive_absolute(directory)
	seed(8404)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	preload("res://tests/legacy_aden_fixture.gd").install(world)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world._set_map("aden_world",false)
	world.save_timer = -10000
	world.set_process(false)
	world.player.set_auto_enabled(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	await building_view("01-stone-cottage")
	if phase != "before":
		await building_checks()
		world.player.camera.position = Vector2.ZERO
		await gameplay()
	var report := {"phase":phase,"checks":checks,"failures":failures,
		"platform":"Godot 4.7.2 Linux software OpenGL","original_restored":false,
		"physical_devices_tested":false,"target_position":[1630,3610]}
	var output := FileAccess.open(directory+"/result.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  ")); output.close()
	print("ADEN_BUILDING_RESULT ",JSON.stringify(report))
	if failures.is_empty(): print("ADEN_BUILDING_OK")
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func building_checks() -> void:
	var target := cottage()
	check(target != null,"target cottage streams at original position")
	if target == null: return
	check(target.texture.resource_path == COTTAGE_PATH,"real authored PNG is used in Main scene")
	var changed: int = 0
	var unchanged: int = 0
	for chunk: Node2D in world.field_renderer.chunks.values():
		for candidate: Node in chunk.get_children():
			if candidate is Sprite2D and str(candidate.get_meta("prop_kind","")) == "house":
				if candidate.texture.resource_path == COTTAGE_PATH: changed += 1
				else: unchanged += 1
	check(changed == 1 and unchanged == 3,"only one of four Aden houses changes")
	check(target.has_meta("occluder"),"cottage participates in actor occlusion")
	var field_before: PlayableField = world.field_map
	var tint_before: Color = target.get_parent().modulate
	world.field_renderer.set_visual_mode("classic")
	check(target.get_parent().modulate != tint_before,"classic style applies to cottage")
	await building_view("02-classic")
	world.field_renderer.set_visual_mode("twilight")
	check(target.get_parent().modulate == tint_before,"default style restores")
	check(world.field_map == field_before,"style preserves gameplay field identity")
	world.player.global_position = Vector2(1630,3420)
	world.field_renderer._process(.3)
	check(target.modulate.a < .8,"cottage fades with actor behind roof")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory+"/03-occlusion.png") == OK,"capture roof fade")
	world.player.global_position = Vector2(1630,3750)
	world.field_renderer._process(.3)
	check(is_equal_approx(target.modulate.a,1.0),"cottage opacity restores in front")
	world.player.set_physics_process(true)
	world.player.set_touch_vector(Vector2.UP)
	for i: int in range(90): await physics_frame
	world.player.set_touch_vector(Vector2.ZERO)
	check(world.player.global_position.y > 3631 and world.player.global_position.y < 3750,"existing cottage wall physically stops actor")
	world.player.set_physics_process(false)
	var route := world.field_map.path(Vector2(1330,3710),Vector2(1930,3450))
	var route_clear := route.size() > 2
	for i: int in range(route.size()-1): route_clear = route_clear and world.field_map.line_clear(route[i],route[i+1])
	check(route_clear,"path routes around cottage footprint")
	await capture("04-stream-away",Vector2(8000,4600))
	check(cottage() == null,"cottage leaves streamed set when distant")
	await building_view("05-stream-return")
	target = cottage()
	check(target != null and target.texture.resource_path == COTTAGE_PATH,"cottage art survives chunk reload")
	world._set_map("oman_01",false)
	var leaked: bool = false
	for chunk: Node2D in world.field_renderer.chunks.values():
		for candidate: Node in chunk.get_children():
			if candidate is Sprite2D and candidate.texture != null and candidate.texture.resource_path == COTTAGE_PATH: leaked = true
	check(not leaked,"cottage art does not leak into another map")
	world._set_map("aden_world",false)
	await building_view("06-portal-return")
	target = cottage()
	check(target != null and target.texture.resource_path == COTTAGE_PATH,"cottage art survives map return")
