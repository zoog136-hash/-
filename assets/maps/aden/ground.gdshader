shader_type canvas_item;
render_mode unshaded;
uniform sampler2D terrain : filter_linear_mipmap, repeat_disable;
uniform float material_index = 0.0;
uniform float opacity = 1.0;
uniform bool edge_fade = false;
uniform bool wild_ground = true;
uniform vec4 palette : source_color = vec4(1.0);
uniform float saturation = 1.0;
uniform float brightness_lift = 0.0;
varying vec2 world;
varying vec4 vertex_tint;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec3 sample_ground(vec2 p, float index) {
    vec2 quadrant=vec2(mod(index,2.0),floor(index/2.0))*.5;
    // Repeat three unrelated projections and blend smoothly: no visible tile lattice.
    vec2 a=fract(p/430.0), b=fract(mat2(vec2(.8,.6),vec2(-.6,.8))*p/579.0+vec2(.17,.43));
    float blend=smoothstep(.12,.88,noise(p/380.0));
    return mix(texture(terrain,quadrant+.008+a*.484).rgb,texture(terrain,quadrant+.008+b*.484).rgb,blend);
}
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; vertex_tint=COLOR; }
void fragment() {
    float broad=noise(world/690.0);
    vec3 color=sample_ground(world,material_index);
    if(material_index<.5 && wild_ground) {
        float forest=max(1.0-length((world-vec2(2850,2050))/vec2(2250,1950)),1.0-length((world-vec2(9400,6600))/vec2(2250,1950)));
        float patches=smoothstep(.35,.75,broad)*.23+smoothstep(-.1,.5,forest)*.44;
        color=mix(color,sample_ground(world,3.0),patches);
        color*=vec3(.87,.94,.83)*(0.87+broad*.27);
    }
    float alpha=opacity;
    if(edge_fade) {
        float shoulder=min(UV.y,1.0-UV.y);
        alpha*=smoothstep(.015,.19,shoulder+(noise(world/32.0)-.5)*.095);
    }
    float luminance=dot(color,vec3(.299,.587,.114));
    color=mix(vec3(luminance),color,saturation)*palette.rgb+brightness_lift;
    COLOR=vec4(color,alpha)*vertex_tint;
}
