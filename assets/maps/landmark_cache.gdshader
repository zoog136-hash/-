shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// SubViewport output is premultiplied. Preserve soft edges and multiply both
// RGB and alpha when a cached landmark fades behind the player.
varying vec4 instance_tint;
void vertex() { instance_tint = COLOR; }
void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    COLOR = vec4(pixel.rgb * instance_tint.rgb * instance_tint.a,
                 pixel.a * instance_tint.a);
}
