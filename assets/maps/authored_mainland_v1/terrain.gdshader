shader_type canvas_item;
render_mode unshaded;
uniform sampler2D atlas : source_color, filter_linear;
varying vec4 terrain_data;
void vertex() { terrain_data = COLOR; }
void fragment() {
	float kind = floor(terrain_data.r * 3.0 + 0.5);
	vec2 quadrant = vec2(mod(kind, 2.0), floor(kind / 2.0));
	// Mirrored repeats join exactly at atlas edges without crossing quadrants.
	vec2 repeated = 1.0 - abs(mod(UV, 2.0) - 1.0);
	vec2 uv = (quadrant + mix(vec2(0.003), vec2(0.997), repeated)) * 0.5;
	vec3 paint = texture(atlas, uv).rgb;
	float variation = mix(0.94, 1.04, terrain_data.g);
	COLOR = vec4(paint * variation * terrain_data.b, 1.0);
}
