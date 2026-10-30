extends SceneTree
## Authoring helper only. Continuous skinned mesh, two-bone leg IK and
## alternating locked support. This is not an installed runtime animation.

const SOURCE := "res://docs/remake/evidence/pr122-remaining106/batch13/albino-mutated-golem-idle16-pilot01.png"
const REGION := Rect2(33, 11, 195, 349)
const SOURCE_ROOT := Vector2(130, 356)
const OUTPUT_ROOT := Vector2(128, 160)
const BAKE_SCALE := 0.42
const WORLD_HEIGHT := 86.0
const SOURCE_HEIGHT := 349.0
const WALK_SECONDS := 0.48
const WALK_SPEED := 82.0
const BONES := [
	[Vector2(133, 239), Vector2(131, 105), 43.0], # torso
	[Vector2(133, 110), Vector2(141, 47), 32.0], # head
	[Vector2(102, 109), Vector2(77, 184), 31.0], # near upper arm
	[Vector2(77, 184), Vector2(85, 261), 39.0], # near forearm/fist
	[Vector2(165, 120), Vector2(189, 202), 27.0], # far upper arm
	[Vector2(189, 202), Vector2(192, 259), 26.0], # far forearm/fist
	[Vector2(135, 241), Vector2(128, 290), 19.0], # near thigh
	[Vector2(128, 290), Vector2(126, 340), 21.0], # near calf
	[Vector2(126, 340), Vector2(163, 349), 19.0], # near foot
	[Vector2(154, 234), Vector2(171, 275), 17.0], # far thigh
	[Vector2(171, 275), Vector2(167, 314), 17.0], # far calf
	[Vector2(167, 314), Vector2(188, 321), 17.0], # far foot
]

var original_vertices := PackedVector2Array()
var skin_weights: Array[PackedFloat32Array] = []
var uvs := PackedVector2Array()
var indices := PackedInt32Array()
var output := ""

func _initialize() -> void:
	output = OS.get_environment("TWILIGHT_GOLEM_RIG_OUTPUT")
	if output.is_empty() or not output.begins_with("/workspace/"):
		printerr("Authoring output must be an explicit /workspace path; no production install")
		quit(2)
		return
	call_deferred("_bake")

func _point_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var t := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return point.distance_to(a.lerp(b, t))

func _prepare_mesh(texture_size: Vector2) -> void:
	var columns := int(ceil(REGION.size.x / 5.0)) + 1
	var rows := int(ceil(REGION.size.y / 5.0)) + 1
	for row in range(rows):
		for column in range(columns):
			var p := REGION.position + Vector2(
				REGION.size.x * float(column) / (columns - 1),
				REGION.size.y * float(row) / (rows - 1))
			original_vertices.append(p)
			uvs.append(p / texture_size)
			var weights := PackedFloat32Array()
			var total := 0.0
			for bone in BONES:
				var distance := _point_distance(p, bone[0], bone[1])
				var score := exp(-3.0 * pow(distance / float(bone[2]), 2.0))
				weights.append(score)
				total += score
			for index in range(weights.size()):
				weights[index] /= maxf(total, 0.000000001)
			# Soles are rigid support patches, not a blend of thigh/torso fields.
			# Keep the actual painted near sole on its target ground plane.
			if p.y >= 324.0:
				var foot_weight := smoothstep(324.0, 333.0, p.y)
				for index in range(weights.size()):
					weights[index] *= 1.0 - foot_weight
				weights[8] += foot_weight
			elif p.y >= 302.0 and p.x >= 154.0:
				var foot_weight := smoothstep(302.0, 313.0, p.y) * smoothstep(151.0, 163.0, p.x)
				for index in range(weights.size()):
					weights[index] *= 1.0 - foot_weight
				weights[11] += foot_weight
			skin_weights.append(weights)
	for row in range(rows - 1):
		for column in range(columns - 1):
			var a := row * columns + column
			indices.append_array(PackedInt32Array([a, a + 1, a + columns,
				a + 1, a + columns + 1, a + columns]))

func _ik(a: Vector2, target: Vector2, rest_a: Vector2, rest_b: Vector2, rest_c: Vector2) -> Vector2:
	var first := rest_a.distance_to(rest_b)
	var second := rest_b.distance_to(rest_c)
	var delta := target - a
	var distance := clampf(delta.length(), absf(first - second) + 0.01, first + second - 0.01)
	var axis := delta.normalized()
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var across := sqrt(maxf(0.0, first * first - along * along))
	var old_axis := (rest_c - rest_a).normalized()
	var bend_sign := signf((rest_b - rest_a).dot(Vector2(-old_axis.y, old_axis.x)))
	return a + along * axis + across * Vector2(-axis.y, axis.x) * bend_sign

func _foot_offset(phase: float) -> Vector2:
	var p := fposmod(phase, 1.0)
	# Half-cycle stance displacement equals actual82px/s *0.24s.
	var half_step := WALK_SPEED * WALK_SECONDS / 4.0 / (WORLD_HEIGHT / SOURCE_HEIGHT)
	if p < 0.5:
		return Vector2(half_step * (1.0 - 4.0 * p), 0.0)
	var swing := (p - 0.5) * 2.0
	return Vector2(-half_step * cos(PI * swing), -18.0 * sin(PI * swing))

func _targets(phase: float) -> Array:
	var near_foot := _foot_offset(phase)
	var far_foot := _foot_offset(phase + 0.5)
	var hips := Vector2(1.5 * sin(TAU * phase), 16.0 + 2.0 * sin(TAU * 2.0 * phase))
	var result: Array = []
	for bone in BONES:
		result.append([bone[0] + hips, bone[1] + hips])
	result[0][1] += Vector2(4.0, -2.0)
	result[1][0] += Vector2(4.0, -2.0)
	result[1][1] += Vector2(3.0, -2.0)
	for spec in [[6, 7, 8, near_foot], [9, 10, 11, far_foot]]:
		var thigh: int = spec[0]
		var calf: int = spec[1]
		var foot: int = spec[2]
		var a: Vector2 = BONES[thigh][0] + hips
		var ankle: Vector2 = BONES[calf][1] + spec[3]
		var knee := _ik(a, ankle, BONES[thigh][0], BONES[thigh][1], BONES[calf][1])
		result[thigh] = [a, knee]
		result[calf] = [knee, ankle]
		result[foot] = [ankle, ankle + (BONES[foot][1] - BONES[foot][0])]
	for spec in [[2, 3, -near_foot.x * 0.42], [4, 5, -far_foot.x * 0.42]]:
		var upper: int = spec[0]
		var lower: int = spec[1]
		var shoulder: Vector2 = BONES[upper][0] + hips + Vector2(4.0, -2.0)
		var wrist: Vector2 = BONES[lower][1] + hips + Vector2(spec[2], -3.0)
		var elbow := _ik(shoulder, wrist, BONES[upper][0], BONES[upper][1], BONES[lower][1])
		result[upper] = [shoulder, elbow]
		result[lower] = [elbow, wrist]
	return result

func _map_bone(point: Vector2, index: int, target: Array) -> Vector2:
	var start: Vector2 = BONES[index][0]
	var vector: Vector2 = BONES[index][1] - start
	var new_vector: Vector2 = target[1] - target[0]
	return target[0] + (point - start).rotated(new_vector.angle() - vector.angle()) * (new_vector.length() / vector.length())

func _make_mesh(targets: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for index in range(original_vertices.size()):
		var point := Vector2.ZERO
		for bone_index in range(BONES.size()):
			point += _map_bone(original_vertices[index], bone_index, targets[bone_index]) * skin_weights[index][bone_index]
		point = OUTPUT_ROOT + (point - SOURCE_ROOT) * BAKE_SCALE
		vertices.append(Vector3(point.x, point.y, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _bake() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if source == null or source.is_empty():
		printerr("Missing exact golem source")
		quit(2)
		return
	var texture := ImageTexture.create_from_image(source)
	_prepare_mesh(source.get_size())
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(viewport)
	var display := MeshInstance2D.new()
	display.texture = texture
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport.add_child(display)
	var phases: Array = []
	for index in range(8):
		var phase := float(index) / 8.0
		var targets := _targets(phase)
		display.mesh = _make_mesh(targets)
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var file := output.path_join("E-walk-%02d.png" % index)
		if rendered.save_png(file) != OK:
			printerr("Cannot preserve source frame: ", file)
			quit(2)
			return
		phases.append({"phase": phase, "file": file,
			"near_support": phase < 0.5, "far_support": phase >= 0.5,
			"near_ankle": [targets[7][1].x, targets[7][1].y],
			"far_ankle": [targets[10][1].x, targets[10][1].y]})
	var receipt := {"key": "monster:알비노 변이된 골렘", "direction": "E",
		"method": "continuous whole-source skinning with independent hip/knee/ankle/elbow/shoulder targets and locked alternating support",
		"source": SOURCE, "source_region": [33,11,195,349],
		"cycle_seconds": WALK_SECONDS, "unchanged_game_speed": WALK_SPEED,
		"gait_quality": "HOLD_UNREVIEWED", "actual_Main": "NOT_RUN",
		"production_applied": false, "new_approved": 0, "phases": phases}
	var report := FileAccess.open(output.path_join("source-authoring.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(receipt, "\t") + "\n")
	report.close()
	print("Authored8 E source frames; unreviewed authoring output, no Main or completion claim")
	quit(0)
