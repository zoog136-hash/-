shader_type canvas_item;
render_mode unshaded;
uniform float dissolve = 0.0;
uniform float energy = 1.0;
uniform float flow = 0.0;
varying vec4 drawing_color;
void vertex() { drawing_color = COLOR; }
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	// Keep branching white cores, suppress the broad translucent blue fringe.
	float core = smoothstep(0.30, 0.82, min(pixel.r, min(pixel.g, pixel.b)));
	float alpha = pow(pixel.a, 1.4) * mix(0.22, 1.0, core) * (1.0 - dissolve);
	COLOR = vec4(pixel.rgb * energy, alpha) * drawing_color;
}
