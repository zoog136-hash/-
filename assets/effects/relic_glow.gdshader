shader_type canvas_item;
render_mode unshaded;
uniform vec4 aura_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.2;
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 p = TEXTURE_PIXEL_SIZE * 1.8;
	float edge = max(max(texture(TEXTURE, UV + vec2(p.x, 0.0)).a, texture(TEXTURE, UV - vec2(p.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, p.y)).a, texture(TEXTURE, UV - vec2(0.0, p.y)).a));
	float halo = max(0.0, edge - base.a) * strength;
	COLOR *= vec4(base.rgb + aura_color.rgb * (strength * 0.18 + halo), max(base.a, halo));
}
