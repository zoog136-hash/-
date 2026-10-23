shader_type canvas_item;
render_mode unshaded;

// Local sprite only; no screen texture, full-screen pass or TIME clock.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float energy : hint_range(0.0, 1.5) = 1.0;
uniform float flow : hint_range(0.0, 1.0) = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float grain = fract(sin(dot(floor(UV * 1024.0), vec2(12.9898, 78.233))) * 43758.5453);
	float erosion = smoothstep(dissolve - 0.12, dissolve + 0.12, grain);
	float filament = 0.97 + 0.03 * sin(UV.y * 55.0 - flow * 12.0);
	COLOR = sprite_tint * vec4(texel.rgb * energy * filament, texel.a * mix(1.0, erosion, step(0.001, dissolve)));
}
