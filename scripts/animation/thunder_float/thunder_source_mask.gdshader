shader_type canvas_item;
uniform int layer = 0;
void fragment() {
	vec2 p = UV * vec2(192.0, 184.0);
	vec4 c = texture(TEXTURE, UV);
	// Front cape hem belongs over the folded legs, not to the thigh mesh.
	bool rear_cape = p.x > 118.0 && p.y > 96.0 && p.y < 143.0;
	bool front_hem = p.x > 96.0 && p.x < 121.0 && p.y > 104.0 && p.y < 128.0 && abs(p.y - (0.72 * p.x + 36.0)) < 6.0;
	bool cape = rear_cape || front_hem;
	// The original shaft is occluded by the thigh below y=116. Retaining a
	// rectangular strip through that occlusion left stationary trouser pixels.
	vec2 tip_local = (p - vec2(83.5, 151.5)) / vec2(7.0, 11.0);
	bool staff_tip = dot(tip_local, tip_local) < 1.0;
	bool staff_shaft = p.y > 102.0 && p.y <= 116.0 && abs(p.x - (0.25 * p.y + 41.0)) < 3.2;
	bool weapon = staff_tip || staff_shaft;
	bool keep = layer == 2 ? cape : (layer == 1 ? weapon : (!cape && !weapon));
	COLOR = c;
	if (!keep || p.y > 180.0) { COLOR.a = 0.0; }
}
