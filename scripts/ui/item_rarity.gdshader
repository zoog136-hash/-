shader_type canvas_item;
render_mode unshaded;

// Immutable shared materials use the engine clock. No per-slot Tween or clock.
uniform float rank = 3.0;
uniform float phase = 0.0;
uniform vec4 accent : source_color = vec4(0.96, 0.46, 0.42, 1.0);
uniform float preview_time = -1.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	float seconds = preview_time >= 0.0 ? preview_time : TIME;
	float clock = seconds + phase;
	vec2 uv = UV;
	float facing = 1.0;
	if (rank >= 5.0) {
		// A restrained double-sided pseudo-3D turn, not a rotating slot/card.
		// Keep 42% width even edge-on so tiny item details remain identifiable.
		float angle = clock * 0.785398;
		facing = abs(cos(angle));
		float width = 0.42 + 0.58 * facing;
		vec2 p = UV - vec2(0.5);
		float roll = sin(angle) * 0.065;
		p = mat2(vec2(cos(roll), -sin(roll)), vec2(sin(roll), cos(roll))) * p;
		p.x /= width;
		p.y -= p.x * sin(angle) * 0.10;
		uv = p + vec2(0.5);
	}
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec4 base = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	float light = max(base.r, max(base.g, base.b));
	// Preserve every original pixel, including black details and alpha. Only
	// the added highlight is masked, so opaque black backgrounds stay quiet.
	float foreground = smoothstep(0.055, 0.36, light) * base.a;
	float period = rank == 3.0 ? 4.8 : (rank == 4.0 ? 4.1 : 6.4);
	float cycle = mod(clock, period);
	float active = 1.0 - step(1.25, cycle);
	float sweep = mix(-0.25, 2.25, clamp(cycle / 1.25, 0.0, 1.0));
	// UV.x + UV.y increasing: upper-left -> lower-right, never the reverse.
	float band = exp(-pow((uv.x + uv.y - sweep) / 0.105, 2.0)) * active;
	float strength = rank == 3.0 ? 0.27 : (rank == 4.0 ? 0.43 : 0.22);
	vec3 color = base.rgb;
	if (rank >= 5.0) color *= 0.86 + 0.14 * facing;
	color = mix(color, vec3(1.0, 0.97, 0.90), band * foreground * strength);
	if (rank >= 6.0) {
		float pulse = 0.055 + 0.045 * sin(clock * 1.7);
		color += accent.rgb * foreground * pulse;
		vec2 orbit = vec2(0.5) + vec2(cos(clock * 0.9), sin(clock * 0.9)) * 0.27;
		vec2 d = abs(uv - orbit);
		float star = exp(-d.x * 180.0 - d.y * 28.0) + exp(-d.y * 180.0 - d.x * 28.0);
		color += accent.rgb * min(star, 1.0) * foreground * 0.42;
	}
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), base.a * inside) * vertex_tint;
}
