shader_type canvas_item;
render_mode unshaded;

uniform vec4 grade_color : source_color = vec4(1.0);
uniform float rank = 0.0;
uniform float motion = 1.0;
uniform float intensity = 1.0;
uniform bool detail_view = false;
uniform float aura_radius = 0.58;
uniform float band_width = 0.035;
uniform float light_strength = 0.18;
uniform float ribbon_layers = 1.0;
uniform float mote_count = 2.0;
uniform float rotation_speed = 0.0;
uniform float flow_speed = 0.25;
uniform float ray_count = 0.0;
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p * vec2(0.92, 1.0));
	float angle = atan(p.y, p.x);
	float t = TIME * motion;
	float rotation = t * rotation_speed;
	float folds = sin(angle * 3.0 - t * flow_speed - rotation) * 0.046 * step(3.0, rank);
	folds += sin(angle * 7.0 + t * flow_speed * 0.6) * 0.024 * step(4.0, rank);
	float distance_to_band = abs(radius - aura_radius - folds);
	float haze = exp(-pow(distance_to_band / (band_width * 2.6), 2.0)) * 0.30;
	float crest = 0.52 + 0.30 * sin(angle * 2.0 - t * flow_speed - rotation);
	if (rank >= 3.0) {
		// Higher tiers form broken, flowing light clouds instead of larger copies
		// of the rare tier's restrained circular glow.
		float cloud = 0.5 + 0.5 * sin(angle * 3.0 - t * flow_speed - rotation);
		crest = 0.22 + 0.72 * cloud * cloud;
		haze *= 0.72 + 0.28 * sin(radius * 20.0 + angle * 5.0 - t * flow_speed);
	}
	float filament = exp(-pow(distance_to_band / band_width, 2.0)) * crest;
	float light = haze + filament;
	if (ribbon_layers >= 2.0) {
		float inner = aura_radius - 0.11 + sin(angle * 4.0 + t * flow_speed) * 0.025;
		float arcs = 0.45 + 0.55 * sin(angle * 3.0 + t * flow_speed) * sin(angle * 3.0 + t * flow_speed);
		light += exp(-pow((radius - inner) / (band_width * 0.65), 2.0)) * 0.27 * arcs;
	}
	if (ribbon_layers >= 3.0) {
		float outer = aura_radius + 0.07 + sin(angle * 6.0 - rotation) * 0.018;
		float arcs = 0.45 + 0.55 * cos(angle * 4.0 - rotation) * cos(angle * 4.0 - rotation);
		light += exp(-pow((radius - outer) / (band_width * 0.40), 2.0)) * 0.33 * arcs;
	}
	float rays = 0.0;
	if (ray_count > 0.0) {
		rays = pow(max(0.0, cos(angle * ray_count - rotation)), 18.0);
		light += rays * exp(-pow((radius - aura_radius) / (band_width * 2.3), 2.0)) * 0.38;
	}
	// One analytic point per polar sector: more motes without particles/nodes/loops.
	float motes = 0.0;
	if (mote_count > 0.0) {
		float sectors = (angle + 3.14159265 + t * flow_speed * 0.16) / 6.28318530 * mote_count;
		float seed = floor(sectors);
		float local = fract(sectors) - 0.5;
		float orbit = aura_radius + sin(seed * 5.7 + t * flow_speed * 0.7) * 0.055;
		float point = pow(local / (0.006 * mote_count), 2.0) + pow((radius - orbit) / 0.019, 2.0);
		motes = exp(-point) * (0.72 + 0.18 * sin(seed * 3.2 + t * 0.6));
	}
	// Protect the illustration centre, native name strip and quantity labels.
	float clear_centre = smoothstep(detail_view ? 0.34 : 0.44, 0.56, radius);
	float edge_fade = 1.0 - smoothstep(0.92, 1.04, radius);
	float alpha = light * light_strength * (detail_view ? 1.22 : 1.0);
	alpha = min(alpha, (detail_view ? 0.26 : 0.18) + rank * 0.04);
	alpha += motes * (0.28 + rank * 0.035);
	alpha *= clear_centre * edge_fade * intensity;
	vec3 glow = mix(grade_color.rgb, vec3(1.0), min(0.50, motes * 0.50 + rays * 0.08));
	COLOR = vec4(glow, alpha) * vertex_tint;
}
