extends Node2D
## Existing transform:283 sheet, LEFT row/cell. Newly authored floating motion;
## not an independently verified original game animation. No idle/attack edits.
const SOURCE_PATH := "res://assets/directional/transform/283.webp"
const SOURCE_REGION := Rect2i(0, 384, 192, 184)
const MASK = preload("res://scripts/animation/thunder_float/thunder_source_mask.gdshader")
const COLS := 97
const ROWS := 93
var layers: Array[MeshInstance2D] = []
var original := PackedVector2Array()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()
var blend := 0.0
var clock := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var image := Image.load_from_file(SOURCE_PATH)
	assert(image != null and not image.is_empty(), "Missing exact thunder 283 sheet")
	var texture := ImageTexture.create_from_image(image.get_region(SOURCE_REGION))
	for layer in range(3):
		var part := MeshInstance2D.new()
		part.texture = texture
		var material_value := ShaderMaterial.new()
		material_value.shader = MASK
		material_value.set_shader_parameter("layer", layer)
		part.material = material_value
		add_child(part)
		layers.append(part)
	for y in range(ROWS):
		for x in range(COLS):
			var p := Vector2(x * 2, y * 2)
			original.append(p)
			uvs.append(p / Vector2(192, 184))
	for y in range(ROWS - 1):
		for x in range(COLS - 1):
			var a := y * COLS + x
			indices.append_array(PackedInt32Array([a, a + 1, a + COLS, a + 1, a + COLS + 1, a + COLS]))
	apply_movement(0.0, 0.0)

func _leg(p: Vector2, side: int, fold: float) -> Vector2:
	var hip := Vector2(86, 106) if side == 0 else Vector2(101, 110)
	var knee := Vector2(72, 139) if side == 0 else Vector2(116, 140)
	var ankle := Vector2(55, 168) if side == 0 else Vector2(129, 168)
	# Knees finish below/behind the hip; both shins and heels fold toward RIGHT,
	# behind LEFTward travel. Neither leg is lifted in front of the abdomen.
	var thigh_target := Vector2(5, 33) if side == 0 else Vector2(14, 27)
	var shin_target := Vector2(29, -8) if side == 0 else Vector2(28, -6)
	var thigh_angle := thigh_target.angle() - (knee - hip).angle()
	var shin_angle := shin_target.angle() - (ankle - knee).angle()
	var thigh := hip + (p - hip).rotated(thigh_angle * fold)
	var posed_knee := hip + (knee - hip).rotated(thigh_angle * fold)
	var shin := posed_knee + (p - knee).rotated(shin_angle * fold)
	return thigh.lerp(shin, smoothstep(132.0, 142.0, p.y))

func apply_movement(amount: float, elapsed: float) -> void:
	blend = clampf(amount, 0.0, 1.0)
	clock = elapsed
	if original.is_empty(): return
	var body := PackedVector3Array()
	var weapon := PackedVector3Array()
	var cape := PackedVector3Array()
	for p: Vector2 in original:
		var q := p
		if p.y > 105.0:
			var side := 0 if p.x < 99.0 else 1
			q = p.lerp(_leg(p, side, blend), smoothstep(105.0, 121.0, p.y))
		var c := p
		var tail := smoothstep(113.0, 167.0, p.x)
		c += Vector2(2.6 + sin(clock * 4.3 - p.x * 0.06) * 1.2,
			sin(clock * 4.3 - p.x * 0.06) * 3.0) * tail * blend
		var hair := smoothstep(110.0, 142.0, p.x) * smoothstep(40.0, 54.0, p.y) * (1.0 - smoothstep(75.0, 84.0, p.y))
		q.y += sin(clock * 4.3 - p.x * 0.06) * hair * blend
		var pitch := (-0.035 + sin(clock * 2.4) * 0.01) * blend
		var lift := Vector2(0, -8 + sin(clock * 3.1) * 1.2) * blend
		body.append(_posed(q, pitch, lift))
		weapon.append(_posed(p, pitch, lift))
		cape.append(_posed(c, pitch, lift))
	_set_mesh(layers[0], body)
	_set_mesh(layers[1], weapon)
	_set_mesh(layers[2], cape)
	queue_redraw()

func _posed(p: Vector2, pitch: float, lift: Vector2) -> Vector3:
	var point := Vector2(90, 104) + (p - Vector2(90, 104)).rotated(pitch) + lift - Vector2(90, 174)
	point *= 132.0 / 184.0
	return Vector3(point.x, point.y, 0)

func _set_mesh(part: MeshInstance2D, vertices: PackedVector3Array) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	part.mesh = mesh

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.24))
	draw_circle(Vector2.ZERO, 18.0 - blend, Color(0, 0, 0, 0.22))
