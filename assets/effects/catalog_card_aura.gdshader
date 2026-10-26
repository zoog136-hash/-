shader_type canvas_item;
render_mode unshaded;

uniform vec4 grade_color : source_color = vec4(1.0);
uniform float rank = 0.0;
uniform float motion = 1.0;
uniform float intensity = 1.0;
uniform bool detail_view = false;
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p * vec2(0.92, 1.0));
	float angle = atan(p.y, p.x);
	float moving = step(2.0, rank) * motion;
	float t = TIME * moving;
	float rotation = step(5.0, rank) * t * 0.30;
	float folds = sin(angle * 3.0 - t * 0.7 - rotation) * 0.045;
	folds += sin(angle * 7.0 + t * 0.5) * 0.022 * step(3.0, rank);
	float ring = exp(-pow((radius - 0.69 - folds) * 7.0, 2.0));
	float wisps = 0.7 + 0.3 * sin(angle * 5.0 + t * 0.9 - rotation);
	float spokes = rank >= 6.0 ? 11.0 : (rank >= 5.0 ? 8.0 : 5.0);
	float rays = pow(max(0.0, sin(angle * spokes - rotation)), 12.0) * step(4.0, rank);
	float breathe = 0.88 + 0.12 * sin(t * 1.6);
	float density = 0.035 + rank * 0.025;
	float light = ring * (wisps + rays * 0.65) * breathe;
	// The illustration centre and native text/quantity strip stay clear.
	float clear_centre = smoothstep(detail_view ? 0.36 : 0.56, 0.72, radius);
	float edge_fade = 1.0 - smoothstep(0.86, 1.04, radius);
	float alpha = light * clear_centre * edge_fade * density * intensity;
	if (detail_view) alpha *= 2.1;
	COLOR = vec4(grade_color.rgb * (1.0 + rays * 0.25), alpha) * vertex_tint;
}
