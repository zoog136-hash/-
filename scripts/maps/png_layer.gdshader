shader_type canvas_item;
// Filter original RGB while keeping each manually separated pixel's owner
// discrete. Filtering the two complementary alpha masks would darken seams.
varying vec4 layer_tint;
void vertex() {
	layer_tint = COLOR;
}
void fragment() {
	vec2 dimensions = vec2(textureSize(TEXTURE, 0));
	vec2 center = (floor(UV * dimensions) + vec2(0.5)) / dimensions;
	vec3 source_rgb = texture(TEXTURE, UV).rgb;
	float owned_alpha = texture(TEXTURE, center).a;
	COLOR = vec4(source_rgb, owned_alpha) * layer_tint;
}
