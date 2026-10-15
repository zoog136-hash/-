shader_type canvas_item;
uniform sampler2D floor_atlas : source_color, filter_linear, repeat_disable;
varying vec4 source_data;

void vertex() {
	source_data = COLOR;
}

void fragment() {
	if (source_data.r > 0.5) {
		COLOR = vec4(0.035, 0.051, 0.063, 1.0);
	} else {
		vec4 stone = texture(floor_atlas, UV);
		// The original authored diamond alpha becomes dark grout at its edges.
		// Keep the complete source cell opaque, including chunk boundaries.
		COLOR = vec4(stone.rgb * source_data.b * stone.a, 1.0);
	}
}
