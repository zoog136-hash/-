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
uniform float atlas_grid = 2.0;
uniform vec4 material_slots = vec4(0.0,1.0,2.0,3.0);
// Opt-in for Aden: the authored atlas cells do not have matching edge pixels.
uniform bool continuous_ground = false;
// Per-courtyard world-space bounds; zero width leaves every other surface alone.
uniform vec4 courtyard_rect = vec4(0.0);
// Only the connected road meshes opt in. Keep scenery and terrain materials intact.
uniform bool road_surface = false;
uniform float road_strength = 1.0;
varying vec2 world;
varying vec4 vertex_tint;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec3 sample_ground(vec2 p, float index) {
    float tile = material_slots[int(clamp(index,0.0,3.0))];
    vec2 quadrant=vec2(mod(tile,atlas_grid),floor(tile/atlas_grid))/atlas_grid;
    if (road_surface) {
        // Offset the source phase in broad, overlapping world-space patches.
        // Smooth weights and mirrored atlas sampling keep every patch continuous.
        // Smaller material features make the route readable against broad terrain.
        vec2 patch = p / 410.0;
        vec2 cell = floor(patch);
        vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(patch));
        vec3 samples[4];
        for (int j = 0; j < 4; j++) {
            vec2 offset = vec2(float(j % 2), float(j / 2));
            vec2 seed = cell + offset;
            vec2 phase = vec2(hash(seed + vec2(17.2,31.7)), hash(seed + vec2(73.9,11.3)));
            vec2 q = p / 155.0 + phase * 3.7;
            vec2 uv = 1.0 - abs(mod(q,2.0)-1.0);
            samples[j] = texture(terrain,quadrant+(vec2(.016)+uv*.968)/atlas_grid).rgb;
        }
        vec3 stone = mix(mix(samples[0],samples[1],blend.x),mix(samples[2],samples[3],blend.x),blend.y);
        float wear = noise(p/93.0)*.065 + noise(p/357.0)*.085;
        return stone * (.89 + wear);
    }
    if (atlas_grid > 3.0 && tile != 0.0 && tile != 1.0 && tile != 3.0 && tile != 8.0 && tile != 9.0) {
        vec2 repeat_uv=1.0-abs(mod(p/240.0,2.0)-1.0);
        return texture(terrain,quadrant+(vec2(.016)+repeat_uv*.968)/atlas_grid).rgb;
    }
    // Blend two unrelated projections. Mirrored wrapping is continuous at cell
    // boundaries; fract() alone abruptly joined unrelated source edge pixels.
    vec2 source_a=p/430.0;
    vec2 source_b=mat2(vec2(.8,.6),vec2(-.6,.8))*p/579.0+vec2(.17,.43);
    vec2 a=fract(source_a), b=fract(source_b);
    if (continuous_ground) {
        a=1.0-abs(mod(source_a,2.0)-1.0);
        b=1.0-abs(mod(source_b,2.0)-1.0);
    }
    float blend=smoothstep(.12,.88,noise(p/380.0));
    return mix(texture(terrain,quadrant+(vec2(.016)+a*.968)/atlas_grid).rgb,texture(terrain,quadrant+(vec2(.016)+b*.968)/atlas_grid).rgb,blend);
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
    if(courtyard_rect.z>0.0) {
        vec2 local=(world-courtyard_rect.xy-courtyard_rect.zw*.5)/(courtyard_rect.zw*.5);
        float worn=(noise(world/23.0)-.5)*.065+(noise(world/103.0)-.5)*.035;
        alpha*=1.0-smoothstep(.91,1.04,length(local)+worn);
    }
    if(edge_fade) {
        float shoulder=min(UV.y,1.0-UV.y);
        alpha*=smoothstep(.015,.19,shoulder+(noise(world/32.0)-.5)*.095);
    }
    float luminance=dot(color,vec3(.299,.587,.114));
    color=mix(vec3(luminance),color,saturation)*palette.rgb+brightness_lift;
    float coverage = vertex_tint.a;
    if (road_surface) {
        coverage = 1.0-pow(1.0-clamp(coverage,0.0,1.0),road_strength);
    }
    COLOR=vec4(color*vertex_tint.rgb,alpha*coverage);
}

