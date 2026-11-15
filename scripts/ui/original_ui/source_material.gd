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

## Cocos display colour/opacity per node. Nodes with the same base material
## and the same display colour share one material, so an original window
## with thousands of nodes holds only a few materials (2026-11-14 phone:
## 11,133 nodes each with its own duplicated material, 18.8 s frame).
## #522 used instance uniforms instead. Those live in the global shader
## uniform buffer, which the GLES3 driver clamps to the device's uniform
## block size (a phone's 16-64 KB = 1,024-4,096 slots, two per node). Past
## that the allocation fails ("Too many instances using shader instance
## variables") and the nodes read other slots: original windows and quick
## slots showed random colour blocks instead of their art on the phone.
const DISPLAY_CACHE_LIMIT: int=4096
static var _display_variants: Dictionary={}
static func bind_display(item: CanvasItem, color: Color) -> void:
	if not item.material is ShaderMaterial:return
	var current: ShaderMaterial=item.material
	var base: ShaderMaterial=display_base(current)
	var key: Array=[base.get_instance_id(),color]
	var variant: Variant=_display_variants.get(key)
	# A cached variant whose parameters were written externally is replaced.
	if not variant is ShaderMaterial or variant.shader!=base.shader or not _bound_to(variant,color):
		if _display_variants.size()>=DISPLAY_CACHE_LIMIT:_display_variants.clear()
		variant=base.duplicate()
		variant.set_meta("source_display_base",base)
		variant.set_shader_parameter("source_display_bound",true)
		variant.set_shader_parameter("source_display_color",color)
		_display_variants[key]=variant
	if current!=variant:item.material=variant
static func _bound_to(material: ShaderMaterial, color: Color) -> bool:
	var bound: Variant=material.get_shader_parameter("source_display_bound")
	var displayed: Variant=material.get_shader_parameter("source_display_color")
	if typeof(bound)!=TYPE_BOOL or bound!=true:return false
	# A vec4 uniform may read back as Vector4 rather than Color.
	if typeof(displayed)==TYPE_VECTOR4:return displayed==Vector4(color.r,color.g,color.b,color.a)
	return typeof(displayed)==TYPE_COLOR and displayed==color
## The shared factory material a display variant was made from.
static func display_base(material: ShaderMaterial) -> ShaderMaterial:
	var base: Variant=material.get_meta("source_display_base") if material!=null and material.has_meta("source_display_base") else null
	return base if base is ShaderMaterial else material
static func bind_tree_display(node: Node, color: Color) -> void:
	if node is CanvasItem:bind_display(node,color)
	for child: Node in node.get_children():bind_tree_display(child,color)
