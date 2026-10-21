extends SceneTree

const BRIDGE = preload("res://scripts/skills/skill_spx_bridge.gd")
const VFX = preload("res://scripts/skills/skill_vfx.gd")

var problems: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, note: String) -> void:
	if not ok:
		problems.append(note)
		print("SOURCE_SKILL_SPX_FAIL " + note)

func _run() -> void:
	var bridge: TwilightSkillSPXBridge = BRIDGE.new()
	_check(str(bridge.binding_for("lm_45d35daedfc527c9").get("name", "")) == "포우 슬레이어", "Foe Slayer binding missing")
	_check(str(bridge.binding_for("lm_42262935d6f53b07").get("name", "")) == "포우 슬레이어(임팩트)", "Foe Slayer Impact binding missing")
	_check(str(bridge.binding_for("lm_816e9fd2e2e8a4e8").get("name", "")) == "아우라키아", "Aurakiya binding missing")
	_check(bridge.binding_for("lm_none").is_empty(), "unexpected automatic name matching")
	_check(bridge.clip_for("lm_816e9fd2e2e8a4e8", "status").is_empty(), "unmapped phase should fall back")

	var frames := SpriteFrames.new()
	for clip: String in ["cast", "impact"]:
		frames.add_animation(clip)
		frames.set_animation_loop(clip, false)
		frames.set_animation_speed(clip, 14.0)
		var picture := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		picture.fill(Color(1, 0.7, 0.2))
		frames.add_frame(clip, ImageTexture.create_from_image(picture))
	var vfx: TwilightOriginalSkillVFX = VFX.new()
	root.add_child(vfx)
	await process_frame
	vfx.spx_bridge.cache["foe_slayer"] = frames
	vfx.emit_skill("lm_45d35daedfc527c9", "impact", Vector2(30, 30))
	_check(vfx.live.size() == 1, "name-matched effect not emitted")
	var source_sprite: Variant = vfx.live[0].get("spx_sprite", null) if not vfx.live.is_empty() else null
	_check(source_sprite is AnimatedSprite2D and is_instance_valid(source_sprite), "private source sprite not selected")
	_check(vfx.emitted == 1, "effect metrics should stay intact")
	vfx.clear()
	_check(vfx.live.is_empty(), "clear leaves live effects")
	vfx.spx_bridge.cache["foe_slayer"] = null
	vfx.emit_skill("lm_45d35daedfc527c9", "impact", Vector2(30, 30))
	_check(vfx.live.size() == 1, "fallback effect not emitted")
	var fallback_sprite: Variant = vfx.live[0].get("spx_sprite", null) if not vfx.live.is_empty() else null
	_check(fallback_sprite == null, "missing source pack did not fall back")
	vfx.clear()
	vfx.queue_free()
	await process_frame
	if problems.is_empty():
		print("SOURCE_SKILL_SPX_OK: named bindings, optional source layer and fallback")
		quit(0)
	else:
		print("SOURCE_SKILL_SPX_FAILED: %d issues" % problems.size())
		quit(1)
