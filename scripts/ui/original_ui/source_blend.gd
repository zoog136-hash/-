extends RefCounted
## Original GL blend factors evaluated against a copied destination framebuffer.
## Each Sprite must have its own preceding BackBufferCopy in canvas draw order.
const PAIRS=["770:1","1:771","1:1","770:771","1:769","1:772","774:1","772:771","772:1","770:772","1:770","0:769","774:772","774:771","772:769"]
const FACTORS={"0":"vec4(0.0)","1":"vec4(1.0)","769":"(vec4(1.0)-source)","770":"vec4(source.a)","771":"vec4(1.0-source.a)","772":"vec4(destination.a)","774":"destination"}
static var _cache: Dictionary={}
static func material(texture: Texture2D, pair: String, particle_vertex_color: bool=false) -> ShaderMaterial:
	if pair not in PAIRS:return null
	var pma: bool=bool(texture.get_meta("cocos_premultiplied",false)) and not particle_vertex_color
	var key: String=pair+":"+str(pma)
	if _cache.has(key):return _cache[key]
	var factors: PackedStringArray=pair.split(":")
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
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
