extends RefCounted

static func available(viewport: Viewport) -> Rect2:
	var full: Rect2 = viewport.get_visible_rect()
	# Explicit harness injection exercises notches without claiming a device test.
	if viewport.has_meta("twilight_test_safe_rect"):
		return full.intersection(viewport.get_meta("twilight_test_safe_rect"))
	if not OS.has_feature("mobile"): return full
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if not safe.has_area(): return full
	var inverse: Transform2D = viewport.get_screen_transform().affine_inverse()
	var start: Vector2 = inverse * safe.position
	var end: Vector2 = inverse * safe.end
	return full.intersection(Rect2(start,end-start))
