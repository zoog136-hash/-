shader_type canvas_item;
render_mode unshaded;
uniform vec4 deep_color : source_color = vec4(.075,.19,.18,1.0);
uniform vec4 shallow_color : source_color = vec4(.16,.30,.28,1.0);
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
    float ripple=sin(world.x*.029+world.y*.016+TIME*.8)*sin(world.y*.051-TIME*1.1);
    float glint=pow(max(0.0,sin(world.x*.12+world.y*.033+TIME)*sin(world.y*.061-TIME*.7)),12.0);
    vec3 color=mix(deep_color.rgb,shallow_color.rgb,ripple*.5+.5);
    COLOR=vec4(color+glint*.055,1.0);
}
