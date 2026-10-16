shader_type canvas_item;
render_mode unshaded;
// PR121 separately authored 2D material. NOT recovered NC artwork.
uniform int zone = 0; // 0 summit, 1 faith 4F, 2 sulfur, 3 escaros
uniform bool road_surface = false;
uniform float opacity = 1.0;
uniform bool edge_fade = false;
varying vec2 position_world;
varying vec4 mesh_color;

float h21(vec2 p) {
    p = fract(p * vec2(0.1031,0.11369));
    p += dot(p,p.yx+19.19);
    return fract((p.x+p.y)*p.x);
}
float smooth_noise(vec2 x) {
    vec2 i=floor(x),f=fract(x);
    f=f*f*(3.0-2.0*f);
    return mix(mix(h21(i),h21(i+vec2(1.0,0.0)),f.x),
               mix(h21(i+vec2(0.0,1.0)),h21(i+vec2(1.0,1.0)),f.x),f.y);
}
float layered_noise(vec2 p) {
    return smooth_noise(p)*0.54+smooth_noise(p*2.35)*0.29+smooth_noise(p*5.4)*0.17;
}
float crack_pattern(vec2 p, float scale) {
    vec2 q=p/scale;
    vec2 cell=floor(q),f=fract(q);
    vec2 centre=vec2(0.22+0.55*h21(cell),0.18+0.63*h21(cell+53.4));
    float slice=abs(f.x-centre.x - 0.33*(f.y-centre.y));
    return (1.0-smoothstep(0.012,0.042,slice))*smoothstep(0.18,0.32,h21(cell+7.7));
}
vec3 stone(vec2 p,vec3 mid,float scale) {
    float a=layered_noise(p/scale);
    float b=smooth_noise(p/(scale*0.23));
    float pit=smoothstep(0.75,0.89,b);
    vec3 c=mid*(0.70+0.52*a);
    c=mix(c,c*0.45,pit*0.27);
    float l=crack_pattern(p,scale*2.8);
    c*=1.0-0.30*l;
    return c;
}
void vertex() {
    position_world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
    mesh_color=COLOR;
}
void fragment() {
    vec2 p=position_world;
    float broad=layered_noise(p/360.0);
    float wet=smoothstep(.62,.83,smooth_noise(p/220.0));
    vec3 c=vec3(.28);
    if (zone==1) {
        // Faith: warm worn slabs, diamond-facade engravings, and deep mortar.
        vec2 block=p/vec2(116.0,74.0);
        block.x+=mod(floor(block.y),2.0)*0.50;
        vec2 f=fract(block),edge=min(f,1.0-f);
        float grout=1.0-smoothstep(.014,.041,min(edge.x,edge.y));
        float chip=smoothstep(.71,.94,smooth_noise(p/19.0));
        c=stone(p,vec3(.355,.335,.323),95.0)*(0.93+.14*broad);
        c*=1.0-grout*.52;
        c*=1.0-chip*grout*.15;
        // Thin ornamental diagonal tracery belongs on every sixth slab.
        float carved=step(.76,h21(floor(block)/3.0));
        float motif=1.0-smoothstep(.02,.045,abs(f.x-f.y));
        c=mix(c,c*1.25,carved*motif*0.12);
        if (road_surface) {
            float stitch=1.0-smoothstep(.025,.055,abs(sin(p.x*.12)));
            vec3 carpet=vec3(.215,.042,.060);
            carpet*=.76+.28*layered_noise(p/170.0);
            c=mix(c,carpet,.81);
            c=mix(c,vec3(.55,.36,.19),stitch*.085);
        }
    } else if(zone==0) {
        // Domination: near-black volcanic masonry and violet mineral flecks.
        c=stone(p,vec3(.157,.148,.171),67.0);
        float trench=crack_pattern(p,112.0);
        c*=1.0-trench*.43;
        float purple=smoothstep(.72,.87,layered_noise(p/130.0));
        c=mix(c,vec3(.34,.29,.39),purple*.27);
        if(road_surface) c*=1.11;
    } else if(zone==2) {
        // Albino sulfur: ancient white mineral salt, ochre crust and marsh.
        c=stone(p,vec3(.34,.338,.218),78.0);
        float crust=smoothstep(.48,.73,layered_noise(p/200.0));
        c=mix(c,vec3(.43,.41,.18),crust*.63);
        float pale=smoothstep(.63,.83,smooth_noise(p/105.0));
        c=mix(c,vec3(.65,.61,.36),pale*.36);
        c*=1.0-wet*.17;
        if (road_surface) c=mix(c,vec3(.38,.34,.23),.22);
    } else {
        // Escaros: layered ash sandstone, coarse gravel, ochre deep fissures.
        c=stone(p,vec3(.25,.218,.196),65.0);
        float fault=1.0-smoothstep(.035,.12,abs(sin(p.x*.015+p.y*.019+smooth_noise(p/190.0))));
        c*=1.0-fault*.36;
        float ash=smoothstep(.67,.85,layered_noise(p/230.0));
        c=mix(c,vec3(.43,.30,.23),ash*.23);
        if(road_surface) c*=.97;
    }
    // Fine-to-mid-size surface roughness; consistent world-space UV across chunks.
    float grit=h21(floor(p/vec2(5.0,6.0)));
    c*=.955+.09*grit;
    // Vertices from AuthoredSurfaceStream carry only geometric tints.
    c*=mesh_color.rgb;
    float alpha=opacity*mesh_color.a;
    if(edge_fade) alpha*=smoothstep(.02,.14,min(UV.x,1.0-UV.x));
    COLOR=vec4(clamp(c,vec3(0.0),vec3(1.0)),alpha);
}
