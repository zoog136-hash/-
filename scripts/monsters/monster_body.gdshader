shader_type canvas_item;
uniform vec4 uv_rect = vec4(0.,0.,1.,1.);
uniform float gait = 0.;
uniform float move_amount = 0.;
uniform float strike = 0.;
uniform float facing = 2.;
uniform float variation = 0.;
uniform vec4 accent : source_color = vec4(.77,.66,.39,1.);
varying vec4 vertex_tint;
varying vec2 stride_offsets;
varying float rise_offset;
varying float bend_amount;
varying float rear_shade;

void vertex() {
	vertex_tint = COLOR;
	// Pose constants are evaluated on four vertices instead of every body pixel.
	stride_offsets = sin(vec2(gait*3.141593-1.,gait*3.141593+1.))*.022*move_amount;
	rise_offset = sin(gait*3.141593)*.012*move_amount;
	bend_amount = strike*.013;
	rear_shade = 1.-max(0.,-sin(facing*.785398))*.10;
}

void fragment() {
	vec2 p = (UV-uv_rect.xy)/uv_rect.zw;
	float legs = smoothstep(.55,.92,p.y);
	float right_side = step(.5,p.x);
	float side = right_side*2.-1.;
	p.x += mix(stride_offsets.x,stride_offsets.y,right_side)*legs;
	p.y += rise_offset*side*legs;
	// This bounded arch preserves the strike bend without a per-pixel sine.
	p.x += 4.*p.y*(1.-p.y)*side*bend_amount;
	vec4 body = texture(TEXTURE,uv_rect.xy+clamp(p,vec2(.002),vec2(.998))*uv_rect.zw);
	float tint = .055+variation*.002;
	body.rgb = mix(body.rgb,body.rgb*accent.rgb*1.45,tint);
	body.rgb *= rear_shade;
	COLOR = vertex_tint*body;
}
