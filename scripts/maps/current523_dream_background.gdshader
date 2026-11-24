shader_type canvas_item;
render_mode unshaded;

uniform sampler2D sky_image : filter_nearest, repeat_enable;
uniform sampler2D cloud_image : filter_nearest, repeat_enable;
uniform vec2 block_origin;
varying vec2 terrain_point;

void vertex() {
	terrain_point = VERTEX + block_origin;
}

void fragment() {
	// Current 523 verified originals. The background is placed in terrain
	// space (not a claim of native camera/time parity). Half-column stagger
	// and initial relative cloud phase come from the original renderer.
	float column = floor(terrain_point.x / 384.0);
	vec2 uv = vec2(terrain_point.x, terrain_point.y + mod(column, 2.0) * 192.0);
	vec3 a = floor(floor(texture(sky_image, uv / 384.0).rgb * 255.0 + 0.5) / 8.0);
	vec3 b = floor(floor(texture(cloud_image, (uv + vec2(0.0, 50.0)) / 768.0).rgb * 255.0 + 0.5) / 8.0);
	vec3 screen5 = a + b - floor(a * b / 31.0);
	COLOR = vec4(screen5 * vec3(1.0 / 31.0, 2.0 / 63.0, 1.0 / 31.0), 1.0);
}
