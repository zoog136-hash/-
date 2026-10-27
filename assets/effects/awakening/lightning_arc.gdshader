shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec4 grade_color : source_color = vec4(1.0, 0.15, 0.2, 1.0);
varying vec4 drawing_color;
void vertex() { drawing_color = COLOR; }
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	// Preserve a white electrical core instead of tinting it into a solid halo.
	float core = smoothstep(0.22, 0.82, min(pixel.g, pixel.b));
	vec3 color = mix(grade_color.rgb * pixel.r, vec3(1.0, 0.97, 0.94), core);
	COLOR = vec4(color, pow(pixel.a, 1.4)) * drawing_color;
}
