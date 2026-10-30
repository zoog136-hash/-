"""New original 2-D joint diagram, not an edit of any existing character art."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
W, H = 1536, 1024
CW, CH = W//2, H/3
BLUE = '#247be7'  # anatomical RIGHT, near to this exact E-side camera
RED = '#df413b'   # anatomical LEFT, far from the camera
GRAY = '#697381'

# Each trajectory is hip -> knee -> ankle, plus heel/toe. Root coordinates are
# identical in all panels. A planted toe travels front -> beneath -> behind.
SUPPORT = [
    {'hip':[0,190], 'knee':[37,242], 'ankle':[59,293], 'heel':[44,303], 'toe':[86,303]},
    {'hip':[0,190], 'knee':[0,246], 'ankle':[-6,294], 'heel':[-25,303], 'toe':[18,303]},
    {'hip':[0,190], 'knee':[-34,239], 'ankle':[-65,282], 'heel':[-82,283], 'toe':[-43,303]},
]
SWING = [
    {'hip':[0,190], 'knee':[-50,234], 'ankle':[-77,259], 'heel':[-86,263], 'toe':[-48,270]},
    {'hip':[0,190], 'knee':[65,207], 'ankle':[39,249], 'heel':[30,253], 'toe':[70,255]},
    {'hip':[0,190], 'knee':[73,215], 'ankle':[87,261], 'heel':[76,269], 'toe':[116,270]},
]

image=Image.new('RGB',(W,H),'#f4f6fa')
draw=ImageDraw.Draw(image)
poses=[]
for row in range(3):
    for col in range(2):
        cx,cy=col*CW+350,round(row*CH)
        slot=row*2+col
        near=SUPPORT[row] if col==0 else SWING[row]
        far=SWING[row] if col==0 else SUPPORT[row]
        def xy(p):return(cx+p[0],cy+p[1])
        def limb(points,color,width=7):
            draw.line([xy(p) for p in points],fill=color,width=width,joint='curve')
        def joint(p,color,r=5):
            x,y=xy(p);draw.ellipse((x-r,y-r,x+r,y+r),fill=color,outline='white',width=1)
        draw.text((col*CW+15,cy+8),f'slot{slot}  '+('RIGHT near support' if col==0 else 'LEFT far support')+[' / toeplant',' / midstance',' / toeoff'][row],fill='#222831')
        draw.text((col*CW+15,cy+24),'BLUE = anatomical RIGHT near; RED = anatomical LEFT far; face/toes >',fill='#222831')
        # The line is a guide datum only; it must not appear in generated art.
        draw.line((col*CW+180,cy+303,col*CW+590,cy+303),fill='#adb7c4',width=2)
        for leg,color in [(far,RED),(near,BLUE)]:
            limb([leg['hip'],leg['knee'],leg['ankle']],color)
            limb([leg['ankle'],leg['heel'],leg['toe']],color,6)
            for p in leg.values():joint(p,color)
        # Fixed narrow side torso. The head has ONE eye and a right-pointing
        # nose, no second shoulder/chest plane that could invite a SE camera.
        draw.ellipse((cx-19,cy+111,cx+30,cy+194),fill='#dbe0e7',outline=GRAY,width=3)
        limb([[0,190],[6,145],[12,110]],GRAY,5)
        draw.ellipse((cx+1,cy+55,cx+43,cy+102),fill='#dbe0e7',outline=GRAY,width=3)
        draw.polygon([xy([40,72]),xy([58,79]),xy([41,84])],fill='#dbe0e7',outline=GRAY)
        draw.ellipse((cx+32,cy+68,cx+36,cy+72),fill='#222831')
        limb([[11,57],[-9,38],[-26,35]],GRAY,4)
        limb([[26,57],[6,37],[-9,31]],GRAY,4)
        # Far LEFT arm stays empty and behind. Near RIGHT arm alone grips axe.
        far_arm=[[2,120],[-33,155],[-43,190]]
        near_arm=[[11,120],[54,163],[105,163]]
        limb(far_arm,RED)
        for p in far_arm:joint(p,RED)
        limb([[-43,190],[-32,200]],RED,4)
        limb([[-43,190],[-46,203]],RED,4)
        limb([[82,224],[125,87]],'#313a46',7)
        draw.polygon([xy([121,87]),xy([155,78]),xy([165,102]),xy([146,126]),xy([113,114])],fill='#b7bfcb',outline='#313a46')
        limb(near_arm,BLUE)
        for p in near_arm:joint(p,BLUE)
        poses.append({'source_slot':slot,'support':'anatomical_RIGHT_near' if col==0 else 'anatomical_LEFT_far',
                      'stage':['toeplant','midstance','toeoff'][row],
                      'root':[cx,cy+190],'ground_y':cy+303,
                      'near_RIGHT_blue_joints':{k:list(xy(v)) for k,v in near.items()},
                      'far_LEFT_red_joints':{k:list(xy(v)) for k,v in far.items()},
                      'near_RIGHT_axe_arm':[list(xy(p)) for p in near_arm],
                      'far_LEFT_empty_arm':[list(xy(p)) for p in far_arm]})

png=OUT/'references/demon-E-run6-joint-guide.png'
assert not png.exists()
image.save(png)
meta={'schema':'pr122-demon-E-original-2D-joint-guide-v1','guide_is_new_code_drawn_diagram':True,
      'source_art_pixels_edited':False,'image_size':[W,H],'layout':[2,3],
      'camera':'exact RIGHT-facing side profile; all head/shoulder/pelvis projections fixed',
      'near_RIGHT':'blue skeleton, owns axe','far_LEFT':'red skeleton, empty claw',
      'playback_source_slots':[0,2,4,1,3,5],'poses':poses,
      'PNG_sha256':hashlib.sha256(png.read_bytes()).hexdigest()}
(OUT/'references/joint-guide.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps({'guide':str(png),'sha256':meta['PNG_sha256']}))
