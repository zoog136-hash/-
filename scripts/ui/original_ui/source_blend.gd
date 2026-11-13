extends RefCounted
const DESTINATION_COPY = preload("res://scripts/ui/original_ui/source_destination_copy.gd")
## Original GL blend factors evaluated against a copied destination framebuffer.
## Exact shaders need their own preceding copy; generated fixed shaders do not.
const PAIRS=["770:1","1:771","1:1","770:771","1:769","1:772","774:1","772:771","772:1","770:772","1:770","0:769","774:772","774:771","772:769"]
const FACTORS={"0":"vec4(0.0)","1":"vec4(1.0)","769":"(vec4(1.0)-source)","770":"vec4(source.a)","771":"vec4(1.0-source.a)","772":"vec4(destination.a)","774":"destination"}
static var _cache: Dictionary={}
## The exact factors read the copied destination through hint_screen_texture.
## On the Android devices tried that copy samples black (the same failure that
## turned 523 characters into silhouettes, see SourceSP2Compositor), so every
## transparent original-UI pixel (item icons, AUTO/SELF, currency slots) became
## a black box while opaque skill icons looked right. Android draws with the
## nearest fixed-function blend instead until the copy is verified on devices.
static var screen_copy_available: bool = not OS.has_feature("android")
## Pair -> fixed-function canvas blend used without a destination copy.
const FIXED={"770:771":"blend_mix","1:771":"blend_premul_alpha","770:1":"blend_add","1:1":"blend_add","1:769":"blend_add","772:1":"blend_add","774:1":"blend_add","774:771":"blend_mul","774:772":"blend_mul","0:769":"blend_mul"}
static func material(texture: Texture2D, pair: String, particle_vertex_color: bool=false) -> ShaderMaterial:
	if pair not in PAIRS:return null
	var pma: bool=bool(texture.get_meta("cocos_premultiplied",false)) and not particle_vertex_color
	var key: String=pair+":"+str(pma)+(":fixed" if not screen_copy_available else "")
	if _cache.has(key):return _cache[key]
	var factors: PackedStringArray=pair.split(":")
	var shader:=Shader.new()
	if not screen_copy_available:
		shader.code=_fixed_code(pair)
		DESTINATION_COPY.mark_copy_free(shader)
	else: shader.code="""shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D original_destination : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool source_pma;
uniform bool source_display_bound = false;
uniform vec4 source_display_color = vec4(1.0);
varying vec4 original_modulation;
void vertex() {
    original_modulation = COLOR;
    if (source_display_bound) original_modulation *= source_display_color;
    if (source_pma) {
        original_modulation.rgb = floor(original_modulation.rgb * original_modulation.a * 255.0 + 0.00001) / 255.0;
    }
}
void fragment() {
    vec4 source = texture(TEXTURE, UV) * original_modulation;
    vec4 destination = textureLod(original_destination, SCREEN_UV, 0.0);
    COLOR = clamp(source * %s + destination * %s, vec4(0.0), vec4(1.0));
}
"""%[FACTORS[factors[0]],FACTORS[factors[1]]]
	var valid: bool=false
	for uniform: Dictionary in shader.get_shader_uniform_list():
		if uniform.get("name")=="source_pma":valid=true
	if not valid:return null
	var result:=ShaderMaterial.new()
	result.shader=shader
	result.set_shader_parameter("source_pma",pma)
	_cache[key]=result
	return result

## Same modulation/premultiply handling as the exact shader, written straight
## to the canvas with a fixed blend. 1:1 and the other additive pairs keep the
## source colour at full weight (alpha 1 under blend_add).
static func _fixed_code(pair: String) -> String:
	var mode: String=str(FIXED.get(pair,"blend_mix"))
	var output: String="source"
	if pair in ["1:1","1:769","774:1"]: output="vec4(source.rgb, 1.0)"
	elif pair=="772:1": output="vec4(source.rgb, 1.0)"
	elif pair=="0:769": output="vec4(vec3(1.0)-source.rgb, 1.0)"
	elif pair=="774:771": output="vec4(source.rgb+vec3(1.0-source.a), 1.0)"
	return """shader_type canvas_item;
render_mode unshaded, %s;
uniform bool source_pma;
uniform bool source_display_bound = false;
uniform vec4 source_display_color = vec4(1.0);
varying vec4 original_modulation;
void vertex() {
    original_modulation = COLOR;
    if (source_display_bound) original_modulation *= source_display_color;
    if (source_pma) {
        original_modulation.rgb = floor(original_modulation.rgb * original_modulation.a * 255.0 + 0.00001) / 255.0;
    }
}
void fragment() {
    vec4 source = texture(TEXTURE, UV) * original_modulation;
    COLOR = clamp(%s, vec4(0.0), vec4(1.0));
}
"""%[mode,output]
