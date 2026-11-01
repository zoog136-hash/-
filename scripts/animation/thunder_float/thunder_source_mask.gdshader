shader_type canvas_item;
uniform bool weapon_layer = false;
void fragment() {
	vec2 p = UV * vec2(108.0, 132.0);
	float boundary = p.y < 45.0 ? 33.0 : (p.y < 99.0 ? 31.0 : (p.y < 109.0 ? 35.0 : 0.0));
	bool weapon = p.x < boundary;
	COLOR = texture(TEXTURE, UV);
	if (weapon_layer && p.y > 96.0 && max(COLOR.r, max(COLOR.g, COLOR.b)) < 0.17) { COLOR.a = 0.0; }
	if (weapon != weapon_layer) { COLOR.a = 0.0; }
}
