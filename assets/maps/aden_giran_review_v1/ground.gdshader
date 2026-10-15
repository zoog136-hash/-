shader_type canvas_item;
render_mode unshaded;
uniform sampler2D terrain_atlas : source_color, filter_linear_mipmap, repeat_disable;
varying float material_kind;

void vertex() {
	material_kind = COLOR.r * 3.0;
}

void fragment() {
	float kind = floor(material_kind + 0.5);
	vec2 quadrant = vec2(mod(kind,2.0),floor(kind/2.0));
	// Independent per-surface atlas quadrants, inset to avoid cross-material
	// sampling. The same global source UVs meet exactly at chunk borders.
	vec2 margin = vec2(2.0) / vec2(textureSize(terrain_atlas,0));
	vec2 at = quadrant*0.5 + margin + fract(UV)*(vec2(0.5)-2.0*margin);
	COLOR = texture(terrain_atlas,at);
}
