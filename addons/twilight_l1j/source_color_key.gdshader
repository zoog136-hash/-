shader_type canvas_item;
// Source bytes remain unchanged. Client portrait/ground backgrounds use a display key.
uniform vec3 background_key = vec3(0.0);
uniform float key_tolerance = 0.015;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float distance_to_key = max(max(abs(source.r-background_key.r), abs(source.g-background_key.g)), abs(source.b-background_key.b));
	source.a *= step(key_tolerance, distance_to_key);
	COLOR *= source;
}
