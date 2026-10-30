shader_type canvas_item;
render_mode unshaded;

uniform vec4 grade_color : source_color = vec4(1.0);
uniform float rank = 0.0;
uniform float motion = 1.0;
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float metal = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	// Keep the painted bevel's white highlights and dark engraved recesses.
	vec3 tint = mix(vec3(1.0), grade_color.rgb, 0.72);
	float sweep = pow(max(0.0, sin(UV.x * 13.0 + UV.y * 6.0 - TIME * 0.85 * motion)), 24.0);
	float glint = step(3.0, rank) * sweep * 0.25 * motion;
	COLOR = vec4(metal * tint * (1.08 + glint), art.a) * vertex_tint;
}
