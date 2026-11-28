extends RefCounted
## A radial gauge over an original Sprite picture (a ring such as
## Com_Skillful_Gauge): the part of the picture within `ratio` of a full turn,
## clockwise from the top of the screen, is drawn; the rest is cut away. The
## picture itself is the original one; no image is made. One shader, one
## material per sprite (its own ratio).
static var _shader: Shader

static func shader() -> Shader:
	if _shader!=null:return _shader
	_shader=Shader.new()
	_shader.code="""shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float start_turn = 0.0;
uniform bool source_pma = false;
void fragment() {
    vec2 local = (UV - uv_rect.xy) / uv_rect.zw - vec2(0.5);
    // Clockwise turns from the top (screen y grows downwards).
    float turn = fract(atan(local.x, -local.y) / 6.28318530718 + 1.0 - start_turn);
    vec4 sampled = texture(TEXTURE, UV);
    if (!source_pma) sampled.rgb *= sampled.a;
    if (fill_ratio <= 0.0 || turn > fill_ratio) sampled = vec4(0.0);
    COLOR = sampled * vec4(COLOR.rgb * COLOR.a, COLOR.a);
}
"""
	return _shader

## Shows `ratio` (0..1) of `sprite`'s ring. A sprite turned by its node (the
## Mastery ProgressBar is authored at 180 degrees) still starts at the top.
static func apply(sprite: Sprite2D, ratio: float) -> bool:
	if not is_instance_valid(sprite) or sprite.texture==null or not is_finite(ratio):return false
	if sprite.material is ShaderMaterial and sprite.material.shader==shader():
		set_fill_ratio(sprite,ratio)
		return true
	var material:=ShaderMaterial.new()
	material.shader=shader()
	material.set_shader_parameter("source_pma",bool(sprite.texture.get_meta("cocos_premultiplied",false)))
	var rect:=Rect2(0,0,1,1)
	if sprite.texture is AtlasTexture and (sprite.texture as AtlasTexture).atlas!=null:
		var atlas: AtlasTexture=sprite.texture
		var size: Vector2=atlas.atlas.get_size()
		if size.x>0 and size.y>0:rect=Rect2(atlas.region.position/size,atlas.region.size/size)
	material.set_shader_parameter("uv_rect",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
	var turned: float=0.0
	var node: Node=sprite
	while node is Node2D:
		turned+=(node as Node2D).rotation
		node=node.get_parent()
	material.set_shader_parameter("start_turn",fposmod(-turned/TAU,1.0))
	sprite.material=material
	set_fill_ratio(sprite,ratio)
	return true

static func set_fill_ratio(item: CanvasItem, ratio: float) -> void:
	var fill: float=clampf(ratio,0.0,1.0)
	if item.get_meta("source_radial_fill",-1.0)==fill:return
	(item.material as ShaderMaterial).set_shader_parameter("fill_ratio",fill)
	item.set_meta("source_radial_fill",fill)
