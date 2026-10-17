shader_type canvas_item;
render_mode unshaded;
uniform sampler2D material_map : filter_nearest, repeat_disable;
uniform sampler2D approved_terrain : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D regional_terrain : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 source_dimensions = vec2(2048.0,1536.0);

float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float kind_at(vec2 cell) {
	return floor(texture(material_map,(clamp(cell,vec2(0),source_dimensions-1.0)+0.5)/source_dimensions).r*255.0+0.5);
}
vec4 terrain(float kind,vec2 source) {
	// Mirrored repetition meets the SAME texture edge on both sides. Unlike
	// fract(UV), it cannot jump between opposite non-tileable atlas borders.
	vec2 uv=abs(fract(source/28.0)*2.0-1.0);
	if (kind<3.5) {
		vec2 inset=vec2(2.0)/vec2(textureSize(approved_terrain,0));
		vec2 q=vec2(mod(kind,2.0),floor(kind/2.0));
		return texture(approved_terrain,q*0.5+inset+uv*(0.5-2.0*inset));
	}
	vec2 inset=vec2(2.0)/vec2(textureSize(regional_terrain,0));
	vec2 q=vec2(mod(kind,4.0),floor(kind/4.0));
	uv=abs(fract(source/9.0)*2.0-1.0);
	return texture(regional_terrain,q*0.25+inset+uv*(0.25-2.0*inset));
}
void fragment() {
	vec2 p=UV-0.5;
	// Noise only feathers the visible material boundary by less than one cell;
	// it never moves a source edge, actor, collider, road or S32 object.
	p+=vec2(noise(UV*1.4),noise(UV*1.4+vec2(31.8,17.2)))*0.65-0.325;
	vec2 cell=floor(p);vec2 weight=smoothstep(vec2(0.10),vec2(0.90),fract(p));
	vec4 a=terrain(kind_at(cell),UV),b=terrain(kind_at(cell+vec2(1,0)),UV);
	vec4 c=terrain(kind_at(cell+vec2(0,1)),UV),d=terrain(kind_at(cell+vec2(1,1)),UV);
	COLOR=mix(mix(a,b,weight.x),mix(c,d,weight.x),weight.y);
}
