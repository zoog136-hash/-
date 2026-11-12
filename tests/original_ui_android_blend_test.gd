extends SceneTree
## Synthetic: on Android the original-UI materials must not read the copied
## destination (hint_screen_texture samples black there, item icons turned
## into black boxes). Each blend pair gets a fixed-function canvas blend.
const BLEND = preload("res://scripts/ui/original_ui/source_blend.gd")
const PANEL = preload("res://scripts/ui/original_ui/source_panel.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_ANDROID_BLEND_FAIL: ", label)

func run() -> void:
	check(BLEND.screen_copy_available == not OS.has_feature("android"), "screen copy is only assumed off Android")
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var was: bool = BLEND.screen_copy_available
	BLEND._cache.clear()
	BLEND.screen_copy_available = true
	var exact: ShaderMaterial = BLEND.material(texture, "770:771")
	check(exact != null and exact.shader.code.contains("hint_screen_texture") and exact.shader.code.contains("blend_disabled"), "desktop keeps the exact destination-copy shader")
	BLEND._cache.clear()
	BLEND.screen_copy_available = false
	var expected := {"770:771":"blend_mix","1:771":"blend_premul_alpha","770:1":"blend_add","1:1":"blend_add","774:771":"blend_mul"}
	for pair: String in BLEND.PAIRS:
		var fixed: ShaderMaterial = BLEND.material(texture, pair)
		check(fixed != null, "pair %s still has a material" % pair)
		if fixed == null: continue
		check(not fixed.shader.code.contains("hint_screen_texture") and not fixed.shader.code.contains("blend_disabled"), "pair %s does not read the destination copy" % pair)
		if expected.has(pair): check(fixed.shader.code.contains(expected[pair]), "pair %s uses %s" % [pair, expected[pair]])
		var names: Array = []
		for uniform: Dictionary in fixed.shader.get_shader_uniform_list(): names.append(uniform.name)
		check("source_pma" in names and "source_display_bound" in names and "source_display_color" in names, "pair %s keeps the display/premultiply uniforms" % pair)
	PANEL._layer_material = null
	var panel: ShaderMaterial = PANEL.layer_material()
	check(panel != null and not panel.shader.code.contains("hint_screen_texture") and panel.shader.code.contains("blend_mix"), "panel colour layer uses the fixed mix blend")
	PANEL._layer_material = null
	BLEND.screen_copy_available = was
	BLEND._cache.clear()
	print("ORIGINAL_UI_ANDROID_BLEND_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
