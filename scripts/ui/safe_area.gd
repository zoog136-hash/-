extends RefCounted

# PR86 concept retained, with invalid/empty rectangle fallback. Coordinates
# returned here are viewport coordinates, not physical display pixels.
static func available(viewport: Viewport) -> Rect2:
	var full: Rect2 = viewport.get_visible_rect()
	if viewport.has_meta("twilight_test_safe_rect"):
		var injected: Variant = viewport.get_meta("twilight_test_safe_rect")
		if injected is Rect2:
			return _usable(full, injected)
		return full
	if not OS.has_feature("mobile"):
		return full
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if not safe.has_area():
		return full
	var transform: Transform2D = viewport.get_screen_transform()
	if is_zero_approx(transform.determinant()):
		return full
	var inverse: Transform2D = transform.affine_inverse()
	var start: Vector2 = inverse * safe.position
	var finish: Vector2 = inverse * safe.end
	return _usable(full, Rect2(start, finish - start).abs())

static func _usable(full: Rect2, candidate: Rect2) -> Rect2:
	var clipped: Rect2 = full.intersection(candidate)
	return clipped if clipped.has_area() else full
