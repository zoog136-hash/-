shader_type canvas_item;
render_mode unshaded, blend_add;

// Original painted smoke/flame/fleck atlas. No radial or geometric aura mask.
uniform sampler2D aura_texture : source_color, filter_linear, repeat_disable;
uniform vec4 aura_region = vec4(0.0, 0.0, 0.33333333, 1.0);
uniform vec4 grade_color : source_color = vec4(1.0);
uniform float rank = 0.0;
uniform float motion = 1.0;
uniform float intensity = 1.0;
uniform bool detail_view = false;
uniform float spread = 0.64;
uniform float light_strength = 0.18;
uniform float veil_strength = 0.08;
uniform float flow_speed = 0.20;
varying vec4 vertex_tint;

void vertex() { vertex_tint = COLOR; }

vec4 painted_wisps(vec2 position) {
    float inside = step(0.0, position.x) * step(position.x, 1.0);
    inside *= step(0.0, position.y) * step(position.y, 1.0);
    vec2 safe_position = clamp(position, vec2(0.002), vec2(0.998));
    return texture(aura_texture, aura_region.xy + safe_position * aura_region.zw) * inside;
}

void fragment() {
    vec2 position = (UV - vec2(0.5)) / spread + vec2(0.5);
    float moving = step(0.001, flow_speed) * motion;
    float t = TIME * flow_speed * motion;
    // Gentle two-dimensional advection keeps the painted torn edges and gaps.
    position.x += sin(position.y * 7.1 - t * 1.3) * 0.028 * moving;
    position.y += sin(position.x * 5.7 + t * 0.9) * 0.022 * moving;
    vec4 art = painted_wisps(position);
    vec2 drift = vec2(sin(position.y * 4.4 + t * 0.7), cos(position.x * 5.1 - t * 0.6));
    vec4 veil = painted_wisps(position + drift * 0.025 * moving);
    float brightness = dot(art.rgb, vec3(0.299, 0.587, 0.114));
    float glow = art.a * sqrt(max(0.0, brightness));
    glow += veil.a * veil_strength * 0.55;
    float alpha = glow * light_strength * intensity * (detail_view ? 1.22 : 1.0);
    alpha = min(alpha, detail_view ? 0.40 : 0.30);
    vec3 light = grade_color.rgb * (0.78 + brightness * 0.42);
    COLOR = vec4(light, alpha) * vertex_tint;
}
