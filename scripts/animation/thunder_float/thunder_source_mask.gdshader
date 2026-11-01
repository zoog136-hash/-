shader_type canvas_item;
// Draw order: body/inner cape, far leg, near leg, staff, front cape.
uniform int layer = 0;
void fragment() {
	vec2 p = UV * vec2(192.0, 184.0);
	vec4 c = texture(TEXTURE, UV);
	bool cape = p.y > 100.0 && p.y < 158.0 && p.x > 0.625 * p.y + 73.0;
	// Include the visible shaft's antialiasing halo so it cannot stretch with a leg.
	bool shaft = p.y > 103.0 && p.y < 144.0 && abs(p.x - (0.21 * p.y + 66.5)) < 5.0;
	vec2 tip_local = (p - vec2(103.0, 151.0)) / vec2(5.5, 12.0);
	bool weapon = shaft || dot(tip_local, tip_local) < 1.0;
	float near_x = p.y <= 125.0 ? mix(112.0, 105.0, clamp((p.y - 104.0) / 21.0, 0.0, 1.0)) : 105.0 - (p.y - 125.0) * 15.0 / 35.0;
	float far_x = p.y <= 125.0 ? mix(128.0, 139.0, clamp((p.y - 105.0) / 20.0, 0.0, 1.0)) : 139.0 + (p.y - 125.0) * 12.0 / 35.0;
	float near_distance = abs(p.x - near_x);
	float far_distance = abs(p.x - far_x);
	bool near_leg = p.y > 103.0 && near_distance < 14.0 && near_distance <= far_distance && !cape && !weapon;
	bool far_leg = p.y > 103.0 && far_distance < 14.0 && far_distance < near_distance && !cape && !weapon;
	bool body = !near_leg && !far_leg && !weapon && !cape;
	bool keep = layer == 0 ? body : (layer == 1 ? far_leg : (layer == 2 ? near_leg : (layer == 3 ? weapon : cape)));
	COLOR = c;
	if (!keep || p.y > 180.0) { COLOR.a = 0.0; }
}
