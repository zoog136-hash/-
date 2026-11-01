"""Actual S-view cutouts for the shared-pose pilot; no E-view mirroring."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageChops,ImageFilter
R=Path(__file__).resolve().parents[2];src=R/'assets/actors/eight_direction/native_locomotion_staging/girtas_267/r053/S-idle.png';im=Image.open(src).convert('RGBA').crop((0,0,512,512));D=R/'assets/actors/shared_skin_pilot/girtas_267/front';D.mkdir(parents=True,exist_ok=True);parts={};masks={}
def mask(poly):
 m=Image.new('L',im.size);ImageDraw.Draw(m).polygon(poly,fill=255);return m
def save(k,poly,pivot,end=None):
 m=mask(poly);p=im.copy();p.putalpha(ImageChops.multiply(im.getchannel('A'),m));f=D/(k+'.png');p.save(f);masks[k]=m;parts[k]={'texture':'res://'+str(f.relative_to(R)),'pivot':pivot,'end':end,'polygon':poly,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
save('head',[(260,0),(318,0),(327,73),(320,94),(317,121),(304,140),(275,140),(260,121),(254,93)],[288,140])
save('upper_0',[(348,186),(380,186),(387,212),(378,240),(357,241),(344,220)],[363,193],[369,235])
save('lower_0',[(355,228),(381,225),(390,251),(383,278),(366,285),(353,268)],[369,235],[374,275])
save('hand_0',[(358,264),(383,260),(395,287),(381,309),(364,305),(351,287)],[374,275])
save('upper_1',[(188,184),(221,182),(229,206),(218,235),(192,240),(179,216)],[208,193],[198,235])
save('lower_1',[(181,225),(211,224),(219,247),(208,273),(192,284),(172,269)],[198,235],[186,276])
save('hand_1',[(171,262),(201,259),(213,280),(198,307),(188,337),(173,358),(137,380),(116,409),(91,440),(54,469),(8,496),(0,493),(25,462),(58,433),(79,396),(108,375),(142,354),(149,325),(159,294)],[186,276])
legs=[{'hip':[332,291],'knee':[346,365],'ankle':[357,456],'thigh':[(316,283),(346,281),(359,319),(363,352),(356,377),(334,379),(322,341)],'shin':[(330,358),(358,354),(370,397),(376,440),(369,465),(343,468),(331,422)],'foot':[(342,447),(371,447),(381,465),(385,488),(368,497),(342,480)]},{'hip':[244,291],'knee':[222,365],'ankle':[207,456],'thigh':[(226,281),(258,285),(253,324),(241,362),(235,380),(209,378),(207,345)],'shin':[(210,354),(237,359),(230,399),(222,441),(218,467),(192,467),(193,424)],'foot':[(192,447),(218,449),(229,472),(221,493),(199,498),(183,480)]}]
for i,l in enumerate(legs):
 for k,p,e in [('thigh',l['hip'],l['knee']),('shin',l['knee'],l['ankle']),('foot',l['ankle'],None)]:save(k+'_'+str(i),l[k],p,e)
for i,p in enumerate([[(325,140),(344,131),(367,143),(377,170),(377,190),(365,205),(343,195),(327,176)],[(211,140),(234,134),(251,150),(246,177),(228,197),(209,202),(191,186),(196,159)]]):save('shoulder_'+str(i),p,[363 if i==0 else 208,193])
removed=Image.new('L',im.size)
for m in masks.values():removed=ImageChops.lighter(removed,m)
body=im.copy();body.putalpha(ImageChops.subtract(im.getchannel('A'),removed))
# Local copies of visible armor fill only the joints exposed by part separation.
for dest,rect in [((198,180),(252,192,274,220)),((350,180),(302,192,324,220))]:body.alpha_composite(im.crop(rect),dest)
for k,pivot,poly in [('torso',[288,245],[(0,0),(512,0),(512,249),(0,249)]),('pelvis',[288,280],[(245,239),(333,239),(340,278),(325,334),(315,377),(284,390),(254,374),(247,320)]),('cape',[288,280],[(170,260),(246,260),(253,335),(281,385),(320,378),(338,281),(386,281),(401,445),(324,445),(289,462),(221,441),(165,428)])]:
 p=body.copy();p.putalpha(ImageChops.multiply(body.getchannel('A'),mask(poly)));f=D/(k+'.png');p.save(f);parts[k]={'texture':'res://'+str(f.relative_to(R)),'pivot':pivot,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
meta={'schema':1,'direction':'S','articulated_direction':'S','source':str(src.relative_to(R)),'source_cell':[0,0,512,512],'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'body_scale':0.219105011732,'authored_joint_backing':[{'destination':[198,180],'source_rect':[252,192,274,220]},{'destination':[350,180],'source_rect':[302,192,324,220]}],'parts':parts,'authorship':'Actual front-view source cutouts, fixed bind and 2D depth projection of shared pose; local visible-armor joint backing is authored.'}
(R/'data/animation/girtas_front_skin.json').write_text(json.dumps(meta,indent=2)+'\n');print('S source cutouts:',len(parts))
