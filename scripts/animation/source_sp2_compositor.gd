extends RefCounted
## Bounded compatibility adapter for the restored M 1.10.22.0 RGB565 kernels.
## P02/P13 static evidence, projected onto 523 source flags; Android equivalence
## and the native per-cell depth/effect-map pipeline remain unverified.
const SHADER = preload("res://shaders/source_sp2_rgb565.gdshader")
const COPY_NAME = "SourceSP2Background"
const ORIGIN = "restored525_RGB565_static_to523_compatibility_Android_unverified"
static var _materials: Dictionary = {}

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
	var copy: BackBufferCopy = sprite.get_node_or_null(COPY_NAME) as BackBufferCopy
	if copy != null: copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED

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
	var copy: BackBufferCopy = sprite.get_node_or_null(COPY_NAME) as BackBufferCopy
	if copy == null:
		copy = BackBufferCopy.new()
		copy.name = COPY_NAME
		# Copy immediately before this sprite, in its existing draw position.
		# No viewport-wide copies, new layer ordering or detached live copies.
		copy.show_behind_parent = true
		sprite.add_child(copy)
	copy.rect = sprite.get_rect()
	copy.copy_mode = BackBufferCopy.COPY_MODE_RECT
