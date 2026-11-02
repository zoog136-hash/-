shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Girtas22260/22261 observation candidate only; not a decoded M blend rule.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool screen_operation = false;
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 vec4 destination = texture(screen_texture, SCREEN_UV);
 vec3 blended = screen_operation ? 1.0-(1.0-destination.rgb)*(1.0-source.rgb) : destination.rgb*source.rgb;
 COLOR = vec4(mix(destination.rgb, blended, source.a), source.a+destination.a*(1.0-source.a));
}
