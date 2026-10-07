extends RefCounted
class_name WorldCoordinates

# All actors, physics, field data and path points use global canvas coordinates.
# InputEvent.position is viewport-space (already adjusted by Godot's stretch).
static func screen_to_world(viewport: Viewport, point: Vector2) -> Vector2:
	return viewport.get_canvas_transform().affine_inverse() * point

static func world_to_screen(viewport: Viewport, point: Vector2) -> Vector2:
	return viewport.get_canvas_transform() * point

static func world_to_minimap(point: Vector2, bounds: Rect2, area: Rect2) -> Vector2:
	return area.position + (point - bounds.position) / bounds.size * area.size

static func minimap_to_world(point: Vector2, bounds: Rect2, area: Rect2) -> Vector2:
	return bounds.position + (point - area.position) / area.size * bounds.size

static func array_vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
