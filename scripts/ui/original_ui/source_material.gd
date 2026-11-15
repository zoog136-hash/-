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
instance uniform bool source_display_bound = false;
instance uniform vec4 source_display_color = vec4(1.0);
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

## Cocos display colour/opacity per node, as per-instance shader parameters
## on the shared material. Each node used to get its own duplicated
## ShaderMaterial, so an original window with thousands of nodes held
## thousands of materials that could not be batched (2026-11-14 phone:
## 11,133 nodes, 18.8 s frame while drawing the skill window).
static var _display_shaders: Dictionary={}

## Only shaders that declare the per-instance display parameters take them;
## setting them on another shader's item logs an engine error on GLES3
## (material_storage instance_buffer_pos) and has no effect.
static func takes_display(material: ShaderMaterial) -> bool:
	var shader: Shader=material.shader
	if shader==null:return false
	var key: int=shader.get_instance_id()
	if not _display_shaders.has(key):
		_display_shaders[key]=shader.code.contains("instance uniform vec4 source_display_color") and shader.code.contains("instance uniform bool source_display_bound")
	return _display_shaders[key]

static func bind_display(item: CanvasItem, color: Color) -> void:
	if not item.material is ShaderMaterial or not takes_display(item.material):return
	# Read the item's actual values, not a memo: an external write must be
	# corrected immediately, and equal writes are skipped.
	var bound: Variant=item.get_instance_shader_parameter("source_display_bound")
	if typeof(bound)!=TYPE_BOOL or bound!=true:
		item.set_instance_shader_parameter("source_display_bound",true)
	var displayed: Variant=item.get_instance_shader_parameter("source_display_color")
	if typeof(displayed)!=TYPE_COLOR or displayed!=color:
		item.set_instance_shader_parameter("source_display_color",color)
static func bind_tree_display(node: Node, color: Color) -> void:
	if node is CanvasItem:bind_display(node,color)
	for child: Node in node.get_children():bind_tree_display(child,color)
