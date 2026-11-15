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

## Cocos display colour/opacity per node.
## - #522 used per-instance shader parameters ("instance uniform"). The phone's
##   GLES3 global uniform buffer holds only a few dozen instances; once full,
##   every later item failed to allocate and re-tried on every update
##   (2026-11-15 523.504: material_storage.cpp:2098 instance_buffer_pos, 4 fps).
## - Before #522 every node duplicated its own material (2026-11-14: 11,133
##   nodes, 18.8 s frame in the skill window).
## Now nodes with the same base material and colour share one material variant,
## so a window needs only (bases x colours) materials and nothing is allocated
## per node. Particles, whose colour changes every frame, keep a private copy.
static var _display_shaders: Dictionary={}
static var _variants: Dictionary={}
const VARIANTS_PER_BASE: int=128

## Only shaders that declare the display parameters take them.
static func takes_display(material: ShaderMaterial) -> bool:
	var shader: Shader=material.shader
	if shader==null:return false
	var key: int=shader.get_instance_id()
	if not _display_shaders.has(key):
		_display_shaders[key]=shader.code.contains("uniform vec4 source_display_color") and shader.code.contains("uniform bool source_display_bound")
	return _display_shaders[key]

## The shared, never-bound material a display variant was made from.
static func display_base(material: Material) -> Material:
	if material==null:return null
	if not material.has_meta("source_display_base"):return material
	var base: Variant=material.get_meta("source_display_base")
	return base if base is ShaderMaterial and is_instance_valid(base) else material

static func _set_display(material: ShaderMaterial, color: Color) -> void:
	# Read the material's actual values, not a memo: an external write is
	# corrected immediately; equal writes are skipped (GLES3 marks them dirty).
	var bound: Variant=material.get_shader_parameter("source_display_bound")
	if typeof(bound)!=TYPE_BOOL or bound!=true:
		material.set_shader_parameter("source_display_bound",true)
	var displayed: Variant=material.get_shader_parameter("source_display_color")
	if typeof(displayed)!=TYPE_COLOR or displayed!=color:
		material.set_shader_parameter("source_display_color",color)

static func _variant(base: ShaderMaterial, color: Color) -> ShaderMaterial:
	var base_id: int=base.get_instance_id()
	var by_color: Dictionary=_variants.get(base_id,{})
	if by_color.is_empty():_variants[base_id]=by_color
	var key: int=color.to_rgba64()
	var variant: ShaderMaterial=by_color.get(key) as ShaderMaterial
	if variant==null:
		if by_color.size()>=VARIANTS_PER_BASE:return null
		variant=base.duplicate()
		variant.set_meta("source_display_base",base)
		variant.set_meta("source_shared_display",true)
		by_color[key]=variant
	_set_display(variant,color)
	return variant

static func bind_display(item: CanvasItem, color: Color, private_material: bool=false) -> void:
	if not item.material is ShaderMaterial or not takes_display(item.material):return
	var current: ShaderMaterial=item.material
	var base: ShaderMaterial=display_base(current) as ShaderMaterial
	if private_material:
		if not bool(current.get_meta("source_private_display",false)):
			current=base.duplicate()
			current.set_meta("source_display_base",base)
			current.set_meta("source_private_display",true)
			item.material=current
		_set_display(current,color)
		return
	var variant: ShaderMaterial=_variant(base,color)
	if variant==null:
		# Too many distinct colours on one base: fall back to a private copy.
		bind_display(item,color,true)
		return
	if item.material!=variant:item.material=variant
static func bind_tree_display(node: Node, color: Color) -> void:
	if node is CanvasItem:bind_display(node,color)
	for child: Node in node.get_children():bind_tree_display(child,color)
