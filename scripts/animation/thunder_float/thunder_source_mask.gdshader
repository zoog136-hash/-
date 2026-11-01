shader_type canvas_item;
uniform int layer = 0;
void fragment() {
	vec2 p = UV * vec2(192.0, 184.0);
	vec4 c = texture(TEXTURE, UV);
	bool cape = p.x > 118.0 && p.y > 96.0 && p.y < 143.0;
	bool staff_tip = p.y > 137.0 && p.y < 164.0 && p.x > 76.0 && p.x < 92.0;
	bool staff_shaft = p.y > 102.0 && p.y <= 137.0 && abs(p.x - (0.25 * p.y + 41.0)) < 3.2;
	bool weapon = staff_tip || staff_shaft;
	bool keep = layer == 2 ? cape : (layer == 1 ? weapon : (!cape && !weapon));
	COLOR = c;
	if (!keep || p.y > 180.0) { COLOR.a = 0.0; }
}
