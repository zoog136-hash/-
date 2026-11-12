shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Recovered 525 RGB565 software kernels, narrow 523 compatibility projection.
// 0: average (G6), 1: screen (G5), 2: multiply (G5). Not Android parity.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int operation = 0;
varying vec4 source_modulate;
void vertex() {
 source_modulate = COLOR;
}
void fragment() {
 vec4 source = texture(TEXTURE, UV) * source_modulate;
 if (source.a == 0.0) { discard; }
 vec4 destination = texture(screen_texture, SCREEN_UV);
 uvec3 s8 = uvec3(floor(clamp(source.rgb, vec3(0.0), vec3(1.0)) * 255.0 + 0.5));
 uvec3 d8 = uvec3(floor(clamp(destination.rgb, vec3(0.0), vec3(1.0)) * 255.0 + 0.5));
 uvec3 s = s8 >> uvec3(3, 2, 3);
 uvec3 d = d8 >> uvec3(3, 2, 3);
 uvec3 result;
 if (operation == 0) {
  result = (d + s) >> uvec3(1);
 } else {
  s.g >>= uint(1);
  d.g >>= uint(1);
  result = (d * s) / uvec3(31);
  if (operation == 1) { result = d + s - result; }
  result.g <<= uint(1);
 }
 uvec3 bytes = (result << uvec3(3, 2, 3)) | (result >> uvec3(2, 4, 2));
 vec3 blended = vec3(bytes) / 255.0;
 // Coverage remains decoder alpha; covered black is a real sample.
 COLOR = vec4(mix(destination.rgb, blended, source.a), source.a + destination.a * (1.0-source.a));
}
