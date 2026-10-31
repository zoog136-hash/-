extends "res://tests/transform_legendary_precision_main.gd"
## Final source226 regression, scoped explicitly by TRANSFORM_PRECISION_IDS=226.
## Keeps all original 41 Main cases and checks the declared timeline aliases.
var alias_attack_trace:Array=[]
var alias_recovery_seen=false
var trace_attack=false

func expected_visual_route(selected:Dictionary) -> Dictionary:
	var route=super.expected_visual_route(selected)
	if str(selected.sourceId)=="226":
		var saved=selected.duplicate(true)
		saved.animation_profile=selected.animation_profile.duplicate(true)
		saved.animation_profile.frames_path=EXPECTED["226"].catalog_path
		var saved_before=JSON.stringify(saved)
		var state_before=invariant(world_ref)
		world_ref._apply_transform_visual(saved)
		check(JSON.stringify(saved)==saved_before and invariant(world_ref)==state_before,"Old saved226 record, stats, equipment IDs and collider stay unchanged")
		check(actor.transform_sprite.sprite_frames.resource_path==str(route.path),"Old saved226 uses current source override")
		check(actor.motion.profile.get_meta("twilight_explicit_role_timeline_aliases",{})=={"recovery":"attack","corpse":"death"},"Reviewed source manifest aliases transferred once to current profile")
		report["old_saved226_unchanged_current_source_selected"]=true
	return route

func pose_tick(velocity:Vector2=Vector2.ZERO) -> void:
	var elapsed=float(actor.motion.attack_elapsed)
	var active=bool(actor.motion.active)
	var duration=float(actor.motion.attack_duration)
	var ratio=float(actor.motion.attack_hit_ratio)
	super.pose_tick(velocity)
	if trace_attack:
		check(actor.motion.attack_duration==duration and actor.motion.attack_hit_ratio==ratio,"Presentation aliases never change authoritative attack duration/hit ratio")
		if active:check(is_equal_approx(actor.motion.attack_elapsed,elapsed+1./120.),"Presentation aliases never change authoritative elapsed clock")
		var sprite:AnimatedSprite2D=actor.transform_sprite
		if actor.motion.presenting_attack and (str(sprite.animation).begins_with("attack_") or str(sprite.animation).begins_with("recovery_")):
			if not alias_attack_trace.is_empty():check(sprite.frame>=int(alias_attack_trace.back().phase),"Explicit recovery continues forward without source rewind")
			alias_attack_trace.append({"clip":str(sprite.animation),"phase":sprite.frame,"elapsed":actor.motion.attack_elapsed})
			if str(sprite.animation).begins_with("recovery_"):alias_recovery_seen=true

func controlled_role(id:String,d:int,role:String) -> void:
	if role=="attack":alias_attack_trace=[];alias_recovery_seen=false;trace_attack=true
	await super.controlled_role(id,d,role)
	trace_attack=false
	if role=="attack":
		check(alias_recovery_seen,"Actual source226 recovery branch exercised "+str(d))
		check(actor.motion._tracks.get("recovery_"+str(d),{}).get("clock_role","")=="attack","Validated identical recovery clock cached "+str(d))
		if not report.has("canonical_attack_traces"):report["canonical_attack_traces"]={}
		report.canonical_attack_traces[str(d)]=alias_attack_trace.duplicate(true)
	if role=="death":
		var sprite:AnimatedSprite2D=actor.transform_sprite
		var frames=sprite.sprite_frames
		var final=frames.get_frame_count("death_2")-1
		var strike_count=strikes.size()
		var start=float(actor.motion.death_clock)
		for tick in range(240):
			pose_tick()
			check(actor.motion.state=="corpse" and str(sprite.animation)=="corpse_2" and sprite.frame==final and frames.get_frame_texture("corpse_2",sprite.frame)==frames.get_frame_texture("death_2",final),"Long corpse hold preserves original final death texture")
		check(is_equal_approx(actor.motion.death_clock-start,2.) and strikes.size()==strike_count,"Long corpse hold preserves gameplay death clock and emits no strike")
		check(actor.motion._tracks.get("corpse_2",{}).get("clock_role","")=="death","Validated identical corpse clock cached")
		report["canonical_corpse_hold"]={"ticks":240,"seconds":2.,"terminal_phase":final,"source_texture_identity":true}

func precision_output_name() -> String:
	return "source226-canonical-clock-actual-Main.jpg"
