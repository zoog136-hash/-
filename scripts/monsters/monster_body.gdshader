shader_type canvas_item;
uniform vec4 uv_rect = vec4(0.,0.,1.,1.);
uniform float gait = 0.;
uniform float move_amount = 0.;
uniform float strike = 0.;
uniform float facing = 2.;
uniform float variation = 0.;
uniform vec4 accent : source_color = vec4(.77,.66,.39,1.);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 p = (UV-uv_rect.xy)/uv_rect.zw;
	// Anatomical pose offsets inside the cropped region. Sampling is constrained
	// to this body, so neighbouring atlas species never leak into the animation.
	float legs = smoothstep(.55,.92,p.y);
	float side = p.x < .5 ? -1. : 1.;
	p.x += sin(gait*3.141593+side)*.022*legs*move_amount;
	p.y += sin(gait*3.141593)*side*.012*legs*move_amount;
	p.x += sin(p.y*3.141593)*side*.013*strike;
	vec4 body = texture(TEXTURE,uv_rect.xy+clamp(p,vec2(.002),vec2(.998))*uv_rect.zw);
	float rear = max(0.,-sin(facing*.785398));
	float tint = .055+variation*.002;
	body.rgb = mix(body.rgb,body.rgb*accent.rgb*1.45,tint);
	body.rgb *= 1.-rear*.10;
	COLOR = vertex_tint*body;
}
