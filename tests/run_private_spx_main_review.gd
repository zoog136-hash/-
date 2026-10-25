extends "res://tests/pr100_direction_gameplay_test.gd"

## Explicit private preview in the real Main. No target498/skill identity claim.
const SOURCE = preload("res://scripts/animation/source_spx_player.gd")
var source_screens: Array[Dictionary] = []

func capture_source(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := captures.path_join(label+".png")
	var image := root.get_texture().get_image()
	check(image.save_png(path) == OK,"actual Main source capture "+label)
	source_screens.append({"file":path.get_file(),"sha256":FileAccess.get_sha256(path)})

func run() -> void:
	out = OS.get_environment("TWILIGHT_SPX_MAIN_REPORT")
	captures = OS.get_environment("TWILIGHT_SPX_MAIN_CAPTURES")
	check(not out.is_empty() and not captures.is_empty(),"explicit private outputs required")
	check(DisplayServer.get_name() != "headless","actual OpenGL renderer required")
	if not failures.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(captures)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world,"기사"),"real class entry")
	world.hud._hide_aux_panels()
	world.save_timer = -10000.
	world._set_map("aden_world",false)
	world.field_population.set_process(false)
	for actor in world.monsters_root.get_children(): actor.set_physics_process(false)
	center = find_clearing()
	check(center.is_finite(),"existing map clearing")
	if not center.is_finite(): world.queue_free(); quit(1); return
	world.player.position = center
	world.player.set_physics_process(false)
	world.player.camera.zoom = Vector2(2.0,2.0)
	world.player.camera.position = Vector2(0,-48)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	await tick(8)
	var hp_before: int = world.hp
	var manifest := SOURCE.read_manifest()
	check(manifest.get("skill_bindings",{}).is_empty(),"unmatched skills remain unbound")
	var body_tracks := 0
	for id: String in manifest.get("actors",{}):
		for aid: String in ["3","0","0-1","0-2","5","8","18"]:
			for direction in range(8):
				var player := SOURCE.new()
				player.set_process(false)
				player.free_on_finish = false
				var ok := player.configure(id,aid,direction,true)
				check(ok,"Main body track "+id+"/"+aid+"/"+str(direction))
				if not ok: player.free(); continue
				world.add_child(player)
				player.scale = Vector2(.7,.7)
				# Existing reviewed source foot; not a new target database mapping.
				player.position = center+Vector2(80,0)-Vector2(72,30)*.7
				player.z_index = 8
				player.play()
				player.advance(float(player._action.total_ticks)/float(manifest.tick_rate)*.4)
				if direction in [0,2,4,6] and aid in ["0","0-1","5"]:
					await capture_source(id+"-"+aid+"-"+str(direction))
				check(SOURCE._resource_bytes <= SOURCE.CACHE_LIMIT_BYTES,"bounded source track cache")
				body_tracks += 1
				player.free()
	for id: String in manifest.get("effects",{}):
		var aid := str(manifest.effects[id].actions.keys()[0])
		check(not world.combat_vfx.play_source_effect(id,aid,center),"unapproved production effect rejected")
		var played := world.combat_vfx.play_source_effect(id,aid,center,true)
		check(played,"Main effect preview "+id)
		if not played: continue
		var player: TwilightSourceSPXPlayer = world.combat_vfx.source_effects[-1]
		player.set_process(false)
		player.advance(float(player._action.total_ticks)/float(manifest.tick_rate)*.45)
		await capture_source("effect-"+id)
		world.combat_vfx.clear()
		await process_frame
		played = world.combat_vfx.play_source_effect(id,aid,center,true)
		check(played,"effect replay resets "+id)
		if not played: continue
		player = world.combat_vfx.source_effects[-1]
		player.set_process(false)
		player.advance(float(player._action.total_ticks)/float(manifest.tick_rate)+1.)
		await process_frame
		check(not is_instance_valid(player),"effect end cleanup "+id)
	for id: String in ["FX_11549","FX_11558","FX_11560"]:
		check(world.combat_vfx.play_source_csb(id,center,true),"CSB candidate in Main "+id)
		if world.combat_vfx.source_csb_effects.is_empty(): continue
		var effect: Node2D = world.combat_vfx.source_csb_effects[-1]
		var animation := effect.get_node("AnimationPlayer") as AnimationPlayer
		animation.seek(animation.current_animation_length*.45,true)
		await capture_source(id)
		animation.speed_scale = 100.
		await tick(12)
		check(not is_instance_valid(effect),"CSB real animation-finished cleanup "+id)
	check(world.hp == hp_before,"source events never call combat damage")
	var result := {"checks":checks,"failures":failures,"Main":"Main.tscn","engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_video_adapter_name(),"body_tracks":body_tracks,"effect_groups":36,"CSB_candidates":3,
		"captures":source_screens,"skill_DB_bindings":0,"new_target498_completions":0,
		"visual_blend_approval":"HOLD","Android":"NOT_RUN","original_art_delivery":"PRIVATE_INPUTS_ONLY"}
	var file := FileAccess.open(out,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"\t")); file.close()
	print("PRIVATE_SPX_MAIN_RESULT "+JSON.stringify(result))
	world.queue_free()
	await process_frame
	quit(1 if not failures.is_empty() else 0)
