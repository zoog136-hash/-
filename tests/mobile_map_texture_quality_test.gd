extends SceneTree
## Fast, asset-independent verification of the mobile-only map texture policy.
const QUALITY = preload("res://scripts/maps/mobile_map_texture_quality.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		printerr("MOBILE_MAP_QUALITY_FAIL ",description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for floor: int in range(1,11):
		check(is_equal_approx(QUALITY.target_scale("oman_%02d" % floor),0.85),"Oman floor "+str(floor))
	for map_id: String in ["domination_summit","escaros_world"]:
		check(is_equal_approx(QUALITY.target_scale(map_id),0.85),"target "+map_id)
	for map_id: String in ["aden_world","faith_01","albino_01","oman_11"]:
		check(QUALITY.target_scale(map_id)==1.0,"other map unchanged "+map_id)
	var original_size:=Vector2i(101,57)
	var expected:=Vector2i(86,48)
	check(QUALITY.output_size(original_size,0.85)==expected,"exact rounded output size")
	check(QUALITY.pixel_count(original_size,0.85)==expected.x*expected.y,"accurate VRAM pixel accounting")
	var ratio: Vector2=QUALITY.pixel_ratio(original_size,expected)
	check((Vector2(expected)/ratio-Vector2(original_size)).length()<0.01,"world footprint preserved")
	var original_offset:=Vector2(18.0,-23.0)
	check(((original_offset*ratio)/ratio-original_offset).length()<0.01,"foreground foot offset preserved")
	var image:=Image.create(original_size.x,original_size.y,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.25,0.5,0.75,1.0))
	QUALITY.resize_image(image,0.85)
	check(image.get_size()==expected,"actual decoded image is downsampled")
	QUALITY.resize_image(image,1.0)
	check(image.get_size()==expected,"full-quality no-op cannot upscale accidentally")
	check(QUALITY.scale_for("aden_world")==1.0,"not-targeted map remains original on all devices")
	print("MOBILE_MAP_QUALITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
