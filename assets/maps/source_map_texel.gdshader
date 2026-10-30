shader_type canvas_item;
render_mode unshaded;

// Adjacent unpadded source chunks own complementary alpha pixels. At minified
// exact texel boundaries, normalized UV rounding differs for NPOT textures.
// Use one deterministic texel selection; do not stretch, fill or repaint art.
void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	ivec2 pixel = ivec2(floor(UV * vec2(size) + vec2(0.001)));
	COLOR = texelFetch(TEXTURE, clamp(pixel, ivec2(0), size - ivec2(1)), 0);
}
