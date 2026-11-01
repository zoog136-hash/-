extends Node2D
## Authored movement study for catalog transform:283 only.
## Source-facing projection; this is not an independent lateral/eight-view asset.
## No attack, actor physics, common RUN, or idle animation is authored here.
const SOURCE = preload("res://assets/catalog/f82cc8301ecf2848b139f0d3.png")
var blend := 0.0
var clock := 0.0
var texture_mesh := MeshInstance2D.new()
var weapon_sprite := Sprite2D.new()
const MASK = preload("res://scripts/animation/thunder_float/thunder_source_mask.gdshader")
var original := PackedVector2Array()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()
const COLS := 55
const ROWS := 67

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_mesh.texture = SOURCE
	var body_material := ShaderMaterial.new()
	body_material.shader = MASK
	texture_mesh.material = body_material
	add_child(texture_mesh)
	weapon_sprite.texture = SOURCE
	var weapon_material := ShaderMaterial.new()
	weapon_material.shader = MASK
	weapon_material.set_shader_parameter("weapon_layer", true)
	weapon_sprite.material = weapon_material
	add_child(weapon_sprite)
	for y in range(ROWS):
		for x in range(COLS):
			var p := Vector2(x * 2, y * 2)
			original.append(p)
			uvs.append(p / Vector2(108, 132))
	for y in range(ROWS - 1):
		for x in range(COLS - 1):
			var a := y * COLS + x
			indices.append_array(PackedInt32Array([a, a + 1, a + COLS, a + 1, a + COLS + 1, a + COLS]))
	apply_movement(0.0, 0.0)

func _smooth(a: float, b: float, v: float) -> float:
	return smoothstep(a, b, v)

func _leg(p: Vector2, side: int) -> Vector2:
	var hip := Vector2(46, 67) if side == 0 else Vector2(60, 67)
	var knee := Vector2(42, 93) if side == 0 else Vector2(70, 94)
	var ankle := Vector2(36, 113) if side == 0 else Vector2(77, 115)
	# Both knees stay folded. No alternating stride phase or ground foot plant.
	var knee_target := hip + Vector2(-11 if side == 0 else -7, 23)
	var shin_target := Vector2(19 if side == 0 else 20, 8)
	var thigh_angle := (knee_target - hip).angle() - (knee - hip).angle()
	var shin_angle := shin_target.angle() - (ankle - knee).angle()
	var thigh := hip + (p - hip).rotated(thigh_angle * blend)
	var posed_knee := hip + (knee - hip).rotated(thigh_angle * blend)
	var shin := posed_knee + (p - knee).rotated(shin_angle * blend)
	return thigh.lerp(shin, _smooth(89, 96, p.y))

func apply_movement(amount: float, elapsed: float) -> void:
	blend = clampf(amount, 0.0, 1.0)
	clock = elapsed
	if original.is_empty(): return
	var vertices := PackedVector3Array()
	for p: Vector2 in original:
		var q := p
		# Staff remains a single rigid piece connected to its hand. Cape has a
		# delayed low-amplitude response; neither uses the ground RUN clock.
		if p.y > 66:
			var side := 0 if p.x < 55 else 1
			var leg := _leg(p, side)
			var weight := _smooth(66, 82, p.y)
			# Preserve the dark cape's outer edges and center tail above the knee.
			if p.y < 86 and (p.x < 39 or p.x > 75 or (p.x > 49 and p.x < 58)):
				weight *= _smooth(80, 88, p.y)
			q = p.lerp(leg, weight)
			var cape_weight := (1.0 - weight) * _smooth(58, 80, p.y)
			q += Vector2(2.0 + sin(clock * 4.2 - p.y * 0.05) * 1.3, sin(clock * 4.2 - 0.5) * 0.5) * cape_weight * blend
		# Lean and suspension move equipment and upper body together.
		q = Vector2(54, 68) + (q - Vector2(54, 68)).rotated(-0.065 * blend)
		q += Vector2(0, -7.0 + sin(clock * 3.2) * 0.8) * blend
		q -= Vector2(54, 124)
		vertices.append(Vector3(q.x, q.y, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	texture_mesh.mesh = mesh
	weapon_sprite.rotation = -0.065 * blend
	weapon_sprite.position = Vector2(0, -56) + Vector2(0, -2).rotated(weapon_sprite.rotation) + Vector2(0, -7.0 + sin(clock * 3.2) * 0.8) * blend
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.24))
	draw_circle(Vector2.ZERO, 20.0 - blend * 2.5, Color(0, 0, 0, 0.25 - blend * 0.05))
