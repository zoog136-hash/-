shader_type canvas_item;
render_mode blend_add, unshaded;

// SPX effect layers contain zero-light black pixels, not RGBA cutout masks.
// Add their original light values without covering the source body's colors.
void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
}
