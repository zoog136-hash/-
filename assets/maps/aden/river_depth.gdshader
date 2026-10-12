shader_type canvas_item;
render_mode unshaded;
// UV.x follows the existing left/right banks; no collision or outline changes.
uniform sampler2D terrain : filter_linear_mipmap, repeat_disable;
uniform float river_width = 470.0;
uniform vec4 deep_color : source_color = vec4(.075,.19,.18,1.0);
uniform vec4 shallow_color : source_color = vec4(.16,.30,.28,1.0);
varying vec2 world;
varying vec4 vertex_tint;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec3 bank_material(vec2 p) {
    vec2 a=1.0-abs(mod(p/430.0,2.0)-1.0);
    vec2 b=1.0-abs(mod(mat2(vec2(.8,.6),vec2(-.6,.8))*p/579.0+vec2(.17,.43),2.0)-1.0);
    vec2 cell=vec2(.25,0.0);
    return mix(texture(terrain,cell+(vec2(.016)+a*.968)/4.0).rgb,
        texture(terrain,cell+(vec2(.016)+b*.968)/4.0).rgb,
        smoothstep(.12,.88,noise(p/380.0)))*vec3(.78,.83,.70);
}
void vertex() {
    world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
    vertex_tint=COLOR;
}
void fragment() {
    float depth=max(0.0,min(UV.x,1.0-UV.x)*river_width);
    float irregular=(noise(world/19.0)-.5)*7.0;
    float wet_depth=max(0.0,depth+irregular*smoothstep(0.0,9.0,depth));
    float ripple=sin(world.x*.029+world.y*.016+TIME*.8)*sin(world.y*.051-TIME*1.1);
    vec3 water=mix(shallow_color.rgb,deep_color.rgb,smoothstep(12.0,100.0,wet_depth));
    water*=.95+ripple*.055;
    vec3 color=water;
    if (wet_depth<90.0) {
        // Ground texture remains visible under the shallows and darkens when wet.
        vec3 bed=bank_material(world)*(1.0-.32*smoothstep(0.0,25.0,wet_depth));
        color=mix(bed,water,smoothstep(1.0,86.0,wet_depth));
        float lapping=sin(world.y*.052+world.x*.018-TIME*1.1)*1.6;
        float rim=1.0-smoothstep(1.0,3.8,abs(wet_depth-8.0-lapping));
        color+=vec3(.11,.14,.12)*rim*.18;
    }
    float glint=pow(max(0.0,sin(world.x*.12+world.y*.033+TIME)*sin(world.y*.061-TIME*.7)),12.0);
    COLOR=vec4(color+glint*.022*smoothstep(12.0,55.0,wet_depth),1.0)*vertex_tint;
}
