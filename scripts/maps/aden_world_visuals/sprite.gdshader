shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sprite_ids : filter_nearest, repeat_disable;
uniform float sprite_id;
void fragment() {
	// Atlas UVs refer to the underlying sheet. Integer IDs isolate the actual
	// connected sprite, even if generated neighboring bounds overlap slightly.
	float found=floor(texture(sprite_ids,UV).r*255.0+0.5);
	COLOR.a*=1.0-step(0.1,abs(found-sprite_id));
}
