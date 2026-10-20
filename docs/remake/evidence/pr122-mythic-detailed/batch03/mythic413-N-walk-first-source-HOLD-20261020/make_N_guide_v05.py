from pathlib import Path
import json,importlib.util,re
from PIL import Image,ImageDraw
out=Path(__file__).resolve().parent
recipe=(out/'N-walk-fixedbone-recipe-v04.py').read_text()
recipe=re.sub(r'PHASES = \(\n.*?\n\)', "PHASES = (\n ('left_heel_contact_right_airborne_departure', 'L', 64.23950718488129, 8.05212086, 20., -62.914891626825536, 20., -25.),\n ('left_midstance_right_swing_passage', 'L', 0., 6., 0., 0., 30., 8.),\n ('left_terminal_toe_support_right_approach', 'L', -62.914891626825536, 13.60712871, -25., 48., 15., 12.),\n ('right_heel_contact_left_airborne_departure', 'R', -62.914891626825536, 20., -25., 64.23950718488129, 8.05212086, 20.),\n ('right_midstance_left_swing_passage', 'R', 0., 30., 8., 0., 6., 0.),\n ('right_terminal_toe_support_left_approach', 'R', 48., 15., 12., -62.914891626825536, 13.60712871, -25.),\n)",recipe,flags=re.S)
recipe=recipe.replace('PELVIS_Z, HIP_HALF, SHOULDER_HALF = 110.','PELVIS_Z, HIP_HALF, SHOULDER_HALF = 100.').replace('460-SCALE*','430-SCALE*').replace('mul(UP,-65.)',"mul(UP,-35. if side=='R' else -65.)")
(out/'N-walk-fixedbone-recipe-v05.py').write_text(recipe)
spec=importlib.util.spec_from_file_location('n_guide_v3',out/'N-walk-fixedbone-recipe-v05.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
poses=[m.make_pose(i) for i in range(6)];atlas=Image.new('RGBA',(1024,1536),(0,0,0,0))
for pose in poses:
 i=pose['phase'];p=pose['points_cell'];panel=Image.new('RGBA',(512,512),(0,0,0,0));d=ImageDraw.Draw(panel)
 d.rectangle((12,12,499,499),outline=(200,200,200,150),width=1)
 for y,t in [(20,f'N BACK WALK {i}'),(35,'support '+pose['weight_support']),(60,'PURE BACK'),(75,'no eyes/chest'),(90,'R grip screen RIGHT')]:d.text((18,y),t,fill=(20,20,20,255))
 for a,b in pose['segments']:d.line([p[a],p[b]],fill=(35,35,35,255) if a.startswith('L_') or b.startswith('L_') else (110,110,110,255),width=5)
 d.line([p['L_shoulder'],p['R_shoulder']],fill=(30,30,30,255),width=6)
 for name in ['L_knee','R_knee','L_heel','L_toe','R_heel','R_toe']:
  x,y=p[name];d.ellipse((x-4,y-4,x+4,y+4),fill=(25,25,25,255))
 hx,hy=p['head'];d.ellipse((hx-28,hy-34,hx+28,hy+34),outline=(20,20,20,255),width=4);d.ellipse((hx-18,hy-48,hx+18,hy-18),outline=(20,20,20,255),width=4);d.line([(hx,hy-10),(hx,hy+24)],fill=(90,90,90,255),width=3)
 rx,ry=p['R_wrist'];sx=rx;top=430-m.SCALE*286.5*m.math.cos(m.ELEV+m.math.radians(5));bot=430
 d.line([(sx,top+50),(rx,ry),(sx,bot-40)],fill=(155,130,30,255),width=4)
 d.line([(sx,top),(sx-16,top+42),(sx,top+30),(sx+16,top+42),(sx,top)],fill=(155,130,30,255),width=3)
 d.polygon([(sx,top+62),(sx-10,top+80),(sx,top+98),(sx+10,top+80)],outline=(155,130,30,255),width=3)
 d.polygon([(sx,bot-60),(sx-10,bot-42),(sx,bot-28),(sx+10,bot-42)],outline=(155,130,30,255),width=3);d.line([(sx,bot-28),(sx,bot)],fill=(155,130,30,255),width=3)
 atlas.alpha_composite(panel,((i%2)*512,(i//2)*512))
 pose.update({'direction':'N','anatomical_near':'neither: symmetric pure back','anatomical_far':'neither: symmetric pure back','weapon':'one anatomical RIGHT-hand longgold double-ended spear; screen RIGHT','guide_status':'MOTION_AND_SCALE_INTENTION_ONLY_NOT_APPROVAL'})
atlas.save(out/'N-walk-fixedbone-guide-v05.png')
bg=Image.new('RGB',atlas.size,(190,190,190));bg.paste(atlas,mask=atlas.getchannel('A'));bg.thumbnail((682,1024));bg.save(out/'N-walk-guide-preview-v05.jpg',quality=78,optimize=True)
(out/'N-walk-fixedbone-guide-v05.json').write_text(json.dumps({'schema':'new-N-walk-guide-v3','camera_elevation_degrees':35.264389682754654,'fixed_bone_scale':1.9,'heading_world':[0,1,0],'raw_cell':[512,512],'logical_cell':[1024,1024],'logical_foot':[512,640],'intended_raw_source_anchor':[256,480],'target_neutral_whole_alpha16_height':464,'rigid_staff_world_length':286.5,'staff_axis_tilt_toward_south_degrees':5,'clock_world_root_delta_per_phase':16.8,'clock_scale':0.237068965517,'required_native_source_ground_delta':70.8654545455267,'poses':poses},indent=2)+'\n')
print(json.dumps({'guide_bytes':(out/'N-walk-fixedbone-guide-v05.png').stat().st_size,'preview_bytes':(out/'N-walk-guide-preview-v05.jpg').stat().st_size,'intended_neutral_whole_height':(481-top)}))
