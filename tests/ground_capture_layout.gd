extends RefCounted
## QA-only gallery placement on the installed map. Never changes map or loot rules.
const POSITIONS = preload("res://tests/active_source_test_positions.gd")
const SAMPLE_COUNT: int = 12

static func offsets_for(spacing: Vector2) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	for i: int in range(SAMPLE_COUNT):
		offsets.append(Vector2((float(i % 4)-1.5)*spacing.x, -spacing.y-35.0+float(i / 4)*spacing.y))
	return offsets

static func find_layout(world: Node) -> Dictionary:
	# Keep the original spacing when it fits; smaller grids still leave more
	# than the real 56x52 loot button between origins. Never drop samples.
	for spacing: Vector2 in [Vector2(150,120), Vector2(120,96), Vector2(96,80)]:
		var offsets: Array[Vector2] = offsets_for(spacing)
		var anchor: Vector2 = POSITIONS.combat(world, offsets)
		if anchor.is_finite():
			return {"anchor":anchor,"offsets":offsets,"spacing":spacing}
	# A missing reviewed floor is a test failure, never an invented location.
	return {}
