extends RefCounted
## Original ImageGen texture. Frame anchors are measured from its actual pixels.
## This module has no RNG, combat, save, or clock access.
const PATH := "res://assets/effects/skills/lightning_discharge_frames.png"
const RGBA_BYTES: int = 1254 * 1254 * 4
const STRIKE_ANCHORS: Array[Vector2] = [Vector2(166,294), Vector2(166.5,292), Vector2(164,290), Vector2(162.5,290), Vector2(166,283.5), Vector2(164.5,288.5), Vector2(166,288.5), Vector2(162.5,292.5)]
const LINK_STARTS: Array[Vector2] = [Vector2(41,154), Vector2(39.5,156), Vector2(45,154), Vector2(50.5,154), Vector2(37,153.5), Vector2(43.5,156.5), Vector2(42,156.5), Vector2(37.5,157.5)]
const LINK_ENDS: Array[Vector2] = [Vector2(278,154), Vector2(272.5,156), Vector2(275,158), Vector2(274.5,153), Vector2(273,156.5), Vector2(274.5,155.5), Vector2(278,158.5), Vector2(275.5,156.5)]
const DURATIONS: Array[float] = [16,24,36,42,50,55,70,90]

static func supports(profile: Dictionary) -> bool:
	return str(profile.get("program", "")) in ["lightning", "chain_lightning", "thunder_stun"]

static func make_frames(profile: Dictionary) -> SpriteFrames:
	var atlas := ResourceLoader.load(PATH, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if atlas == null: return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("impact")
	frames.set_animation_speed("impact", 1000)
	frames.set_animation_loop("impact", false)
	var chain: bool = str(profile.get("program", "")) == "chain_lightning"
	var cell: Vector2 = atlas.get_size() / 4.0
	for index: int in range(8):
		var first: int = index + (8 if chain else 0)
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(Vector2(first % 4, floori(float(first) / 4.0)) * cell + Vector2.ONE, cell - Vector2(2,2))
		texture.filter_clip = true
		frames.add_frame("impact", texture, DURATIONS[index])
	frames.set_meta("electric_form", "link" if chain else "strike")
	frames.set_meta("cell", cell)
	return frames

static func pose(body: AnimatedSprite2D, container: Node2D, point: Vector2, end: Vector2, ground: Vector2) -> void:
	var cell: Vector2 = body.sprite_frames.get_meta("cell")
	var frame: int = clampi(body.frame, 0, 7)
	if str(body.sprite_frames.get_meta("electric_form")) == "strike":
		body.rotation = 0
		body.scale = Vector2(112,218) / cell
		body.offset = cell * 0.5 - STRIKE_ANCHORS[frame]
		body.position = container.to_local(ground if ground.is_finite() else point)
	else:
		var target: Vector2 = container.to_local(point)
		var origin: Vector2 = container.to_local(end) if end.is_finite() else target - Vector2(96,0)
		var direction: Vector2 = target - origin
		var start: Vector2 = LINK_STARTS[frame] - cell * 0.5
		var tip: Vector2 = LINK_ENDS[frame] - cell * 0.5
		var length: float = maxf(1.0, tip.x - start.x)
		body.scale = Vector2(direction.length() / length, 96.0 / cell.y)
		# Account for the slight slope between the painted endpoints as well.
		var painted := (tip - start) * body.scale
		body.rotation = direction.angle() - painted.angle()
		body.offset = Vector2.ZERO
		body.position = origin - (start * body.scale).rotated(body.rotation)
