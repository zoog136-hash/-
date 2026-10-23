extends SceneTree

## Requires the user's real installed private pack. Never a public CI fixture.
const VFX = preload("res://scripts/skills/skill_vfx.gd")
var failures: Array[String] = []
var checked: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok: failures.append(label)
func run() -> void:
	if not FileAccess.file_exists("res://data/external_spx/skills_manifest.json"):
		print("PRIVATE_SKILL_PACK_NOT_RUN: real private pack missing")
		quit(2)
		return
	var vfx: TwilightOriginalSkillVFX = VFX.new()
	root.add_child(vfx)
	await process_frame
	for id: String in vfx.spx_bridge.bindings:
		for phase: String in ["cast", "impact"]:
			var frames := vfx.spx_bridge.frames_for(id, phase)
			check(frames != null, "actual source clip " + id + ":" + phase)
			if frames == null: continue
			var clip := vfx.spx_bridge.clip_for(id, phase)
			var expected := 0.0
			for frame: int in range(frames.get_frame_count(clip)):
				expected += frames.get_frame_duration(clip, frame) / frames.get_animation_speed(clip)
				check(frames.get_frame_texture(clip, frame) != null, "source frame retained")
			vfx.emit_skill(id, phase, Vector2(100, 200))
			check(vfx.live.size() == 1, "actual private source admitted")
			if vfx.live.is_empty(): continue
			var item: Dictionary = vfx.live[0]
			var sprite: AnimatedSprite2D = item.spx_sprite
			check(sprite != null and not sprite.centered, "source origin restored from private manifest")
			check(is_equal_approx(float(item.ttl), expected), "installed clip timing unchanged")
			var layout := vfx.spx_bridge.layout_for(id, phase)
			var offset: Array = layout.sprite_offset
			check(sprite.offset.is_equal_approx(Vector2(float(offset[0]), float(offset[1]))), "cast/impact source offsets retained")
			for empty: Variant in layout.get("empty_composite_frames", []):
				check(frames.get_frame_texture(clip, int(empty)).get_image().is_invisible(), "intentional blank source frame retained")
			vfx.clear()
	check(vfx.spx_bridge.clip_for("lm_816e9fd2e2e8a4e8", "pvp_impact").is_empty(), "PvP source remains unreachable in PvE")
	vfx.queue_free()
	await process_frame
	for failure: String in failures: print("PRIVATE_SKILL_PACK_FAIL ", failure)
	print("PRIVATE_SKILL_PACK_RESULT ", JSON.stringify({"checks":checked, "failures":failures, "source_timing_clock":"UNVERIFIED", "fidelity":"UNVERIFIED", "directions":"UNVERIFIED"}))
	quit(0 if failures.is_empty() else 1)
