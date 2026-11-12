extends RefCounted
## Bounded compatibility adapter for the restored M 1.10.22.0 RGB565 kernels.
## P02/P13 static evidence, projected onto 523 source flags; Android equivalence
## and the native per-cell depth/effect-map pipeline remain unverified.
const SHADER = preload("res://shaders/source_sp2_rgb565.gdshader")
const COPY_NAME = "SourceSP2Background"
const ORIGIN = "restored525_RGB565_static_to523_compatibility_Android_unverified"
static var _materials: Dictionary = {}

class BackgroundCopy:
	extends BackBufferCopy
	var active: bool = false
	func _enter_tree() -> void:
		if not RenderingServer.frame_pre_draw.is_connected(_refresh_region):
			RenderingServer.frame_pre_draw.connect(_refresh_region)
	func _exit_tree() -> void:
		if RenderingServer.frame_pre_draw.is_connected(_refresh_region):
			RenderingServer.frame_pre_draw.disconnect(_refresh_region)
	func _refresh_region() -> void:
		var sprite: Sprite2D = get_parent() as Sprite2D
		copy_mode = BackBufferCopy.COPY_MODE_DISABLED
		if not active or sprite == null or not sprite.is_visible_in_tree(): return
		var screen: Transform2D = sprite.get_viewport_transform() * sprite.get_global_transform()
		if is_zero_approx(screen.determinant()): return
		var region: Rect2 = screen * sprite.get_rect()
		var start: Vector2 = region.position.floor()
		region = Rect2(start, region.end.ceil() - start).intersection(Rect2(Vector2.ZERO, Vector2(sprite.get_viewport().get_texture().get_size())))
		# Empty rectangles mean a FULL viewport copy to the render server.
		if not region.has_area(): return
		# 4.7.2 GLES3/RD consume raw copy.rect, not cull's screen_rect.
		# Use viewport coordinates and neutralize the child's inherited transform.
		# Updating just before draw also follows camera-only moves and resizing.
		transform = screen.affine_inverse()
		rect = region
		copy_mode = BackBufferCopy.COPY_MODE_RECT

static func _bits(attributes: Array) -> int:
	var bits: int = 0
	for value: Variant in attributes:
		if not str(value).is_valid_int(): return -1
		bits |= int(str(value))
	return bits

## Only the three simple, recovered flag cases. Combined flags may have early
## returns, coefficients or effect-map preprocessing: keep their existing policy.
static func style(layer: Dictionary, body_attributes: Array, body_unresolved: bool, mode: String) -> Dictionary:
	if mode != "compatible" or bool(layer.get("source_attributes_unresolved", false)): return {}
	var flags: int = _bits(layer.get("source_attributes", []))
	if layer.get("kind", "") == "shadow":
		if body_unresolved: return {}
		var parent_flags: int = _bits(body_attributes)
		if parent_flags < 0: return {}
		flags = (parent_flags & ~0x8000) | 1
	var operation: int = {1:0, 8:1, 128:2}.get(flags, -1)
	if operation < 0: return {}
	return {"operation":operation,"flags":flags,"origin":ORIGIN}

## Independent integer oracle for diagnostics; no source texture is rewritten.
static func blend565(destination: int, source: int, operation: int) -> int:
	var dr: int = (destination >> 11) & 31
	var dg: int = (destination >> 5) & 63
	var db: int = destination & 31
	var sr: int = (source >> 11) & 31
	var sg: int = (source >> 5) & 63
	var sb: int = source & 31
	if operation == 0: return (((dr + sr) >> 1) << 11) | (((dg + sg) >> 1) << 5) | ((db + sb) >> 1)
	dg >>= 1
	sg >>= 1
	var r: int = (dr * sr) / 31
	var g: int = (dg * sg) / 31
	var b: int = (db * sb) / 31
	if operation == 1:
		r = dr + sr - r
		g = dg + sg - g
		b = db + sb - b
	return (r << 11) | (g << 6) | b

static func reset(sprite: Sprite2D) -> void:
	sprite.material = null
	sprite.modulate.a = 1.0
	if sprite.has_meta("source_compositor"): sprite.remove_meta("source_compositor")
	var copy: BackgroundCopy = sprite.get_node_or_null(COPY_NAME) as BackgroundCopy
	if copy != null:
		copy.active = false
		copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED

static func apply(sprite: Sprite2D, selected: Dictionary) -> void:
	if selected.is_empty():
		reset(sprite)
		return
	var operation: int = int(selected.operation)
	if not _materials.has(operation):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("operation", operation)
		_materials[operation] = material
	sprite.material = _materials[operation]
	sprite.modulate.a = 1.0
	sprite.set_meta("source_compositor", selected)
	var copy: BackgroundCopy = sprite.get_node_or_null(COPY_NAME) as BackgroundCopy
	if copy == null:
		copy = BackgroundCopy.new()
		copy.name = COPY_NAME
		# Copy immediately before this sprite, in its existing draw position.
		# No viewport-wide copies, new layer ordering or detached live copies.
		copy.show_behind_parent = true
		sprite.add_child(copy)
	copy.active = true
	copy._refresh_region()
