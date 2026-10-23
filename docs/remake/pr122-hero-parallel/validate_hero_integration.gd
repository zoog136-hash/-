extends "res://docs/remake/pr122-hero-parallel/validate_candidates.gd"
## Final combined Main selection/strike/corpse pass. No art or catalog writes.
func _initialize() -> void:
	call_deferred("_integrated")

func _integrated() -> void:
	_check(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"),"isolated saves")
	_check(Engine.get_version_info().string.begins_with("4.7.2"),"engine")
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var selected: Dictionary = staging.actors.duplicate()
	selected.merge(staging.remediation_18.actors)
	var world: Node = load("res://Main.tscn").instantiate()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	_check(CLASS_QA.enter_game(world),"actual Main gameplay entry")
	world.hud._close_workspace()
	world.save_timer=-10000.0
	await process_frame
	player_camera_update(world)
	var player: Node = world.player
	var strikes: Array[int] = []
	player.attack_strike.connect(func(sequence: int) -> void:strikes.append(sequence))
	var results: Array = []
	var before_catalog: String = JSON.stringify(world.catalog_db["변신"])
	var evidence := "res://docs/remake/pr122-hero-parallel/evidence/audit-once-20261023/"
	for row: Dictionary in world.catalog_db["변신"]:
		if row.grade!="영웅":continue
		var key := "transform:"+str(row.sourceId)
		var candidate := row.duplicate(true)
		var entry: Dictionary = selected.get(key,{})
		if not entry.is_empty():candidate.animation_profile=_settings(load(entry.native_profile))
		var before := _fingerprint(world)
		player.motion.dead=false
		world._apply_transform_visual(candidate)
		var sprite: AnimatedSprite2D = player.transform_sprite
		var profile: Resource = player.motion.profile
		_check(player.transform_active and profile.profile_id==key,"Main transformation identity "+key)
		_check(sprite.is_visible_in_tree(),"visible actual Main player "+key)
		if not entry.is_empty():_check(sprite.sprite_frames.resource_path==str(entry.frames),"exact selected hero resource "+key)
		for direction: int in range(8):
			var aim := Vector2.RIGHT.rotated(direction*PI/4)
			player.motion.dead=false
			player.motion.advance(3.0,Vector2.ZERO)
			player.motion.face(aim)
			_tick(player)
			_check(str(sprite.animation)=="idle_"+str(direction),"idle heading "+key)
			for tick: int in range(100):_tick(player,aim*profile.reference_speed)
			var run_key := str(sprite.animation)
			_check(run_key=="run_"+str(direction) or (entry.is_empty() and run_key=="walk_"+str(direction)),"run or preserved legacy fallback "+key)
			_check(sprite.sprite_frames.has_animation(run_key) and sprite.sprite_frames.get_frame_count(run_key)>0,"live movement clip "+key)
			player.motion.advance(3.0,Vector2.ZERO)
			var start := strikes.size()
			var sequence: int = player.start_combat_attack(player.global_position+aim,.9,profile.motion_style)
			var marker_checked := false
			for tick: int in range(250):
				_tick(player)
				if not marker_checked and strikes.size()>start:
					_check(strikes.size()==start+1 and strikes.back()==sequence,"one authoritative strike "+key)
					if not entry.is_empty():_check(sprite.frame==profile.attack_hit_frame,"preserved strike pose "+key)
					marker_checked=true
			_check(marker_checked,"strike reached "+key)
			player.motion.advance(3.0,Vector2.ZERO)
			player.motion.react(false,-aim)
			_tick(player)
			_check(str(sprite.animation)=="hit_"+str(direction),"hit heading "+key)
			player.motion.advance(3.0,Vector2.ZERO)
			player.motion.die()
			_tick(player)
			var death_key := str(sprite.animation)
			_check(death_key.begins_with("death_"),"authored death selected "+key)
			player.motion.advance(31.0,aim*profile.reference_speed)
			player.motion.apply(sprite,sprite.get_meta("base_scale",Vector2.ONE))
			_check(player.motion.dead and str(sprite.animation)==death_key and sprite.frame==sprite.sprite_frames.get_frame_count(death_key)-1,"final corpse hold "+key)
		_check(_fingerprint(world)==before,"gameplay fields preserved "+key)
		if str(row.sourceId) in ["2","173","231","359"]:
			player.motion.dead=false
			_tick(player)
			await process_frame
			await RenderingServer.frame_post_draw
			_check(root.get_texture().get_image().save_png(evidence+"integration-Main-"+str(row.sourceId)+".png")==OK,"actual Main integration capture")
		results.append({"id":key,"selected_candidate":not entry.is_empty(),"directions":8,"roles":5})
	_check(results.size()==109,"full hero roster")
	_check(JSON.stringify(world.catalog_db["변신"])==before_catalog,"catalog unchanged")
	var report := {"schema":"hero-final-combined-main-v1","status":"FAIL" if failed else "PASS","engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"checks":checks,"heroes":results,"selected_candidates":selected.size(),"default_catalog_connections":0,"asset_writes":0,"art_regenerations":0,"PR122_merged":false}
	var file := FileAccess.open(evidence+"integration-main.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	world.queue_free()
	print("HERO_FINAL_INTEGRATION_%s heroes=109 selected=36 checks=%d art_regenerations=0" % ["FAIL" if failed else "PASS",checks])
	quit(1 if failed else 0)
