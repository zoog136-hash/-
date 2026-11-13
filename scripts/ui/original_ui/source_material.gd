extends RefCounted
## Cocos Image PNG premultiplication and Sprite opacityModifyRGB travel together.
static var _materials: Dictionary={}
static func for_blend(texture: Texture2D, blend: String, grayscale: bool=false) -> ShaderMaterial:
	var pma: bool=bool(texture.get_meta("cocos_premultiplied",false))
	var key: String=blend+":"+str(pma)+":"+str(grayscale)
	if _materials.has(key):return _materials[key]
	var mode: String={"770:1":"blend_add","770:771":"blend_mix","1:771":"blend_premul_alpha"}.get(blend,"")
	if mode.is_empty():return null
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
render_mode unshaded, %s;
uniform bool source_pma;
uniform bool source_display_bound = false;
uniform vec4 source_display_color = vec4(1.0);
uniform bool source_gray;
varying vec4 original_modulation;
void vertex() {
    original_modulation = COLOR;
    if (source_display_bound) original_modulation *= source_display_color;
    if (source_pma) {
        original_modulation.rgb = floor(original_modulation.rgb * original_modulation.a * 255.0 + 0.00001) / 255.0;
    }
}
void fragment() {
    vec4 sampled = texture(TEXTURE, UV);
    if (source_gray) {
        // ccShader_UI_Gray.frag intentionally does not apply vertex color.
        float luminance = dot(sampled.rgb, vec3(0.2126, 0.7152, 0.0722));
        COLOR = vec4(vec3(luminance), sampled.a);
    } else {
        COLOR = sampled * original_modulation;
    }
}
"""%mode
	var valid: bool=false
	for uniform: Dictionary in shader.get_shader_uniform_list():
		if uniform.get("name")=="source_pma":valid=true
	if not valid:return null
	var material:=ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("source_pma",pma)
	material.set_shader_parameter("source_gray",grayscale)
	_materials[key]=material
	return material
static func original_default(texture: Texture2D, grayscale: bool=false) -> ShaderMaterial:
	return for_blend(texture,"1:771" if bool(texture.get_meta("cocos_premultiplied",false)) else "770:771",grayscale)

static func bind_display(item: CanvasItem, color: Color) -> void:
	if not item.material is ShaderMaterial:return
	var current: ShaderMaterial=item.material
	if not bool(current.get_meta("source_private_display",false)):
		current=current.duplicate()
		current.set_meta("source_private_display",true)
		item.material=current
	# Read this material's actual parameters, not an identity/color memo: a
	# replacement material or an external write must be corrected immediately.
	# Godot 4.7.2 GLES3 marks uniforms dirty even for equal setter values.
	var bound: Variant=current.get_shader_parameter("source_display_bound")
	if typeof(bound)!=TYPE_BOOL or bound!=true:
		current.set_shader_parameter("source_display_bound",true)
	var displayed: Variant=current.get_shader_parameter("source_display_color")
	if typeof(displayed)!=TYPE_COLOR or displayed!=color:
		current.set_shader_parameter("source_display_color",color)
static func bind_tree_display(node: Node, color: Color) -> void:
	if node is CanvasItem:bind_display(node,color)
	for child: Node in node.get_children():bind_tree_display(child,color)
