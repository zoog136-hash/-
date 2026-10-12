extends SceneTree
const VARIATION = preload("res://scripts/maps/terrain_variation_texture.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("TERRAIN_VARIATION_FAIL: "+label)
func _initialize() -> void:
	var image: Image = VARIATION.build_image()
	check(image.get_size()==Vector2i(128,128),"bounded 64 KiB control texture")
	check(image.get_data().size()==65536,"RGBA8 allocation")
	check(image.get_data()==VARIATION.build_image().get_data(),"deterministic across reload")
	var minimum := Vector3.ONE
	var maximum := Vector3.ZERO
	var distinct: Dictionary = {}
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var c: Color = image.get_pixel(x,y)
			var v := Vector3(c.r,c.g,c.b)
			minimum = minimum.min(v)
			maximum = maximum.max(v)
			distinct[c.to_rgba32()] = true
	for channel: int in range(3):
		check(maximum[channel]-minimum[channel]>.5,"independent variation channel "+str(channel))
	check(distinct.size()>10000,"sufficient source phase/weather/erosion variation")
	check(VARIATION.get_texture()==VARIATION.get_texture(),"one shared texture, not one allocation per material")
	print("TERRAIN_VARIATION_OK " if failures.is_empty() else "TERRAIN_VARIATION_FAILED ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
