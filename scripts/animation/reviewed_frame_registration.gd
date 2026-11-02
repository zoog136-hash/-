extends RefCounted
## Opt-in source-pixel registration. No animation clock, physics or damage writes.
## Only the reviewed production compiler may emit this SpriteFrames metadata.
const META := "twilight_reviewed_frame_registration"
const OFFSET_META := "twilight_registration_prior_offset"

static func restore_offset(sprite: Node2D) -> void:
	if sprite.has_meta(OFFSET_META):
		sprite.set("offset", sprite.get_meta(OFFSET_META))
		sprite.remove_meta(OFFSET_META)

static func geometry(source: SpriteFrames, animation: String, phase: int, base_scale: Vector2) -> Dictionary:
	if source == null or not source.has_meta(META): return {}
	var tracks: Variant = source.get_meta(META)
	if not tracks is Dictionary or not tracks.has(animation): return {}
	var track: Variant = tracks[animation]
	if not track is Dictionary or track.get("semantic_review") != "PASS": return {}
	var frames: Variant = track.get("frames")
	if not frames is Array or not source.has_animation(animation): return {}
	if frames.size() != source.get_frame_count(animation) or phase < 0 or phase >= frames.size(): return {}
	var entry: Variant = frames[phase]
	if not entry is Dictionary: return {}
	var anchor: Variant = entry.get("anchor")
	var scale: Variant = entry.get("scale")
	var target: Variant = entry.get("target", Vector2.ZERO)
	if not anchor is Vector2 or not scale is Vector2 or not target is Vector2: return {}
	if not anchor.is_finite() or not scale.is_finite() or not target.is_finite(): return {}
	if scale.x <= 0.0 or not is_equal_approx(scale.x, scale.y): return {}
	var texture: Texture2D = source.get_frame_texture(animation, phase)
	if texture == null: return {}
	return {"texture_offset":texture.get_size() * 0.5 - anchor,"scale":base_scale * scale,"position":base_scale * target}

static func apply(sprite: Node2D, source: SpriteFrames, animation: String, phase: int, base_scale: Vector2) -> bool:
	if not sprite is AnimatedSprite2D and not sprite is Sprite2D: return false
	var pose: Dictionary = geometry(source, animation, phase, base_scale)
	if pose.is_empty(): return false
	if not sprite.has_meta(OFFSET_META): sprite.set_meta(OFFSET_META, sprite.get("offset"))
	sprite.set("offset", pose.texture_offset)
	sprite.scale = pose.scale
	sprite.position = pose.position
	return true
