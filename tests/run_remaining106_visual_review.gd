extends "res://tests/run_original_based_batch.gd"

# Additive actual-Main evidence. The inherited AI, contact, HP, weapon, death,
# drop and manual-pickup assertions run unchanged. Only QA positions/camera
# and a scoped simulation pause for atomic framebuffer readback are added.
var review_stage := ""
var review_direction := 0
var review_contact_before := 0
var review_seen: Dictionary = {}
var review_had_drop := false

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("REMAINING106_VISUAL_FAIL: actual OpenGL viewport required")
		quit(1)
		return
	await super.run()

func monster_case() -> void:
	review_seen.clear()
	review_stage = "ai"
	report.remaining106_visual = []
	await super.monster_case()
	review_stage = ""
	for direction: String in COMPASS:
		check(review_seen.has("ai-" + direction + "-walk"), "actual rendered AI walk " + direction)
		check(review_seen.has("ai-" + direction + "-contact"), "actual rendered contact " + direction)
		check(review_seen.has("ai-" + direction + "-attack-0"), "actual rendered attack windup " + direction)

func review_body_clear(point: Vector2) -> bool:
	var body := Rect2(point + Vector2(-128, -160), Vector2(256, 176))
	for actor: Node in world.monsters_root.get_children():
		if actor == normal or not actor is Node2D or not (actor as Node2D).is_visible_in_tree(): continue
		if point.distance_squared_to((actor as Node2D).position) < 192.0 * 192.0: return false
	for prop: Node2D in world.field_renderer.faded:
		if prop is Sprite2D and prop.global_position.y + 16.0 > point.y:
			if (prop.global_transform * (prop as Sprite2D).get_rect()).intersects(body): return false
	return true

func prepare_monster_direction(direction: int) -> bool:
	review_direction = direction
	review_contact_before = monster_strikes.size()
	var old_center := center
	var aim := screen_direction(direction)
	var distance := monster_start_distance()
	var travel := maxf(0.0, distance - normal.current_attack_range())
	for radius: float in [0., 80., 160., 240., 320., 480., 640., 800., 1120., 1600., 2400., 3200.]:
		for heading: int in range(8):
			var target := old_center + screen_direction(heading) * radius
			var start := target - aim * distance
			if not route_clear(target, 150.) or not route_clear(start, 0.): continue
			if not world.field_map.line_clear(start, target): continue
			world.player.position = target
			world.player.camera.zoom = Vector2.ONE * minf(1.6, 270. / distance)
			world.player.camera.position = -aim * distance * .5 + Vector2(0, -32)
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			var clear := true
			for portion: float in [0., .5, 1.]:
				if not review_body_clear(start + aim * travel * portion): clear = false; break
			if not clear: continue
			center = target
			if not report.setup.has("visual_approaches"): report.setup.visual_approaches = {}
			report.setup.visual_approaches[COMPASS[direction]] = {"target": [target.x,target.y],
				"start": [start.x,start.y], "unchanged_start_distance": distance,
				"unchanged_attack_range": normal.current_attack_range(), "walkable_line": true,
				"foreground_and_other_actor_clear": true, "map_modified": false}
			return true
	return false

func review_frame() -> int:
	if not is_instance_valid(normal) or normal.motion.frame_source == null: return -1
	var key: String = normal.motion._resolved_key
	if not normal.motion.frame_source.has_animation(key): return -1
	for index: int in range(normal.motion.frame_source.get_frame_count(key)):
		if normal.motion.frame_source.get_frame_texture(key,index) == normal.sprite.texture: return index
	return -1

func review_capture(stem: String) -> void:
	if review_seen.has(stem) or captures.is_empty(): return
	review_seen[stem] = true
	var prior_mode := world.process_mode
	var prior_zoom: Vector2 = world.player.camera.zoom
	var prior_camera: Vector2 = world.player.camera.position
	var prior_hp: int = world.hp
	var prior_drops: int = world.ground_loot.records.size()
	var valid := is_instance_valid(normal)
	var actor_hp: int = normal.hp if valid else -1
	var actor_point: Vector2 = normal.position if valid else world.player.position + Vector2(40,0)
	var token: int = normal.sprite.texture.get_instance_id() if valid and normal.sprite.texture != null else 0
	var detail := {"path": captures.path_join(stem + ".png"), "kind": stem,
		"actual_Main": true, "physics_tick": ticks_elapsed, "player_hp": prior_hp,
		"actor_hp": actor_hp, "ground_drop_count": prior_drops, "frame": review_frame(),
		"resolved_key": normal.motion._resolved_key if valid else "",
		"attack_elapsed": normal.motion.attack_elapsed if valid else 0.,
		"contact_count": monster_strikes.size(), "actor_world": [actor_point.x,actor_point.y],
		"camera_only_detail": true, "production_stats_or_map_changes": false}
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.camera.zoom = Vector2(2.6,2.6)
	world.player.camera.position = actor_point - world.player.position + Vector2(0,-32)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	check(review_body_clear(actor_point), "no foreground/other actor hides actual evidence " + stem)
	check(not FileAccess.file_exists(str(detail.path)), "visual evidence does not overwrite " + stem)
	if not FileAccess.file_exists(str(detail.path)):
		await super.capture(stem)
		detail.sha256 = FileAccess.get_sha256(str(detail.path))
	if valid:
		check(normal.hp == actor_hp and normal.sprite.texture.get_instance_id() == token,
			"atomic actual actor/frame during framebuffer readback " + stem)
		var bounds: Rect2 = normal.sprite.get_rect()
		if normal.sprite.texture is AtlasTexture:
			var atlas := normal.sprite.texture as AtlasTexture
			bounds = Rect2(bounds.position + atlas.margin.position, atlas.region.size)
		var screen: Rect2 = normal.sprite.get_global_transform_with_canvas() * bounds
		detail.visible_body_viewport = [screen.position.x,screen.position.y,screen.size.x,screen.size.y]
		check(root.get_visible_rect().encloses(screen), "complete body fits actual Main viewport " + stem)
	check(world.hp == prior_hp and world.ground_loot.records.size() == prior_drops,
		"readback does not advance damage or loot " + stem)
	report.remaining106_visual.append(detail)
	world.player.camera.zoom = prior_zoom
	world.player.camera.position = prior_camera
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	world.process_mode = prior_mode

func tick(count: int = 1) -> void:
	for _step: int in range(count):
		await super.tick()
		if captures.is_empty() or review_stage.is_empty(): continue
		var valid := is_instance_valid(normal)
		var key: String = normal.motion._resolved_key if valid else ""
		var frame := review_frame()
		if review_stage == "ai":
			if not valid: continue
			var prefix: String = "ai-" + str(COMPASS[review_direction])
			if normal.motion.state in ["walk","run"]: await review_capture(prefix + "-walk")
			if normal.motion.presenting_attack and frame >= 0: await review_capture(prefix + "-attack-" + str(frame))
			if monster_strikes.size() > review_contact_before: await review_capture(prefix + "-contact")
		elif review_stage == "lifecycle":
			if key.begins_with("hit_"): await review_capture("lifecycle-hit")
			if valid and normal.dead and key.begins_with("death_") and frame >= 0:
				await review_capture("lifecycle-death-" + str(frame))
			if not world.ground_loot.records.is_empty():
				review_had_drop = true
				await review_capture("lifecycle-ground-drop")
			elif review_had_drop: await review_capture("lifecycle-manual-pickup")

func lifecycle_case() -> void:
	review_stage = "lifecycle"
	review_had_drop = false
	await super.lifecycle_case()
	review_stage = ""
	for stem: String in ["lifecycle-hit","lifecycle-death-0","lifecycle-death-1","lifecycle-death-2", "lifecycle-ground-drop","lifecycle-manual-pickup"]:
		check(review_seen.has(stem), "actual rendered lifecycle event " + stem)
