extends "res://tests/original_based_transform_temporal_main_test.gd"

# Add actual-player event captures; all inherited transform/gameplay/temporal
# assertions remain. Atomic draw holds only QA Main/camera and restores them.
var player_review_active := false
var player_review_seen: Dictionary = {}
var player_review_contact_count := 0

func reset_case_state() -> void:
	super.reset_case_state()
	player_review_active = false
	player_review_seen.clear()
	player_review_contact_count = 0

func player_review_snapshot() -> Dictionary:
	var sprite := active_sprite()
	var target: TwilightMonster = world.selected_monster
	return {"animation":str(sprite.animation),"frame":sprite.frame,
		"texture":transform_temporal_texture_token(transform_temporal_texture(sprite)),
		"attack_elapsed":world.player.motion.attack_elapsed,"strikes":strikes.size(),
		"hp":world.hp,"target_hp":target.hp if is_instance_valid(target) else -1,
		"drops":world.ground_loot.records.size()}

func capture_player_event(stem: String) -> void:
	if player_review_seen.has(stem) or captures.is_empty(): return
	player_review_seen[stem] = true
	var before := player_review_snapshot()
	var prior_mode: Node.ProcessMode = world.process_mode
	var prior_zoom: Vector2 = world.player.camera.zoom
	var prior_position: Vector2 = world.player.camera.position
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.camera.zoom = Vector2(2.2,2.2)
	world.player.camera.position = Vector2(0,-32)
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	await RenderingServer.frame_post_draw
	check(player_review_snapshot() == before,"actual transform event frozen atomically " + stem)
	var sprite := active_sprite()
	var texture := transform_temporal_texture(sprite)
	var bounds: Rect2 = sprite.get_global_transform_with_canvas() * transform_temporal_local_bounds(sprite,texture)
	check(root.get_visible_rect().encloses(bounds),"whole actual transformed body in viewport " + stem)
	var path := captures.path_join(stem+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"actual transformed event screenshot " + stem)
	check(player_review_snapshot() == before,"readback cannot advance contact/damage " + stem)
	report.screenshots.append(stem+".png")
	if not report.has("remaining106_player_visual"):
		report.remaining106_player_visual = {"scope":"Actual Main production player input/weapon marker; additive event screenshots, separate from QA temporal clock","events":[],"production_changes":false}
	report.remaining106_player_visual.events.append({"name":stem,"path":path,"sha256":FileAccess.get_sha256(path),
		"state":before,"visible_body_viewport":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],
		"camera_only_detail":true,"whole_main_restored":true})
	world.player.camera.zoom = prior_zoom
	world.player.camera.position = prior_position
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	world.process_mode = prior_mode

func tick(count: int = 1) -> void:
	for _step: int in range(count):
		await super.tick()
		if not player_review_active or not is_instance_valid(world) or captures.is_empty(): continue
		var sprite := active_sprite()
		var direction: int = world.player.facing8
		var stem := "actual-player-" + str(COMPASS[direction])
		if world.player.motion.state in ["walk","run"]:
			await capture_player_event(stem+"-walk")
		if world.player.motion.presenting_attack:
			await capture_player_event(stem+"-attack-"+str(sprite.frame))
		if strikes.size() > player_review_contact_count:
			await capture_player_event(stem+"-contact")
			player_review_contact_count = strikes.size()

func player_case(spec: Dictionary, transformed: bool) -> void:
	player_review_active = transformed
	player_review_contact_count = strikes.size()
	await super.player_case(spec,transformed)
	player_review_active = false
	if transformed and not captures.is_empty():
		for direction: String in COMPASS:
			for suffix: String in ["-walk","-attack-0","-attack-1","-contact"]:
				check(player_review_seen.has("actual-player-"+direction+suffix),"actual transformed event captured " + direction+suffix)
