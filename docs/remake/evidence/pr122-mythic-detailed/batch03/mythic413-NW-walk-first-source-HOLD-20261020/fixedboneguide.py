#!/usr/bin/env python3
"""413 NW WALK fixed-bone pose-guide recipe. Preparation only, no auto execution.

Future usage, after ROOT reports 267 all 48 tracks + actual default Main PASS,
2/31, and clears the existing pause:
  python3 fixedboneguide.py --render-png --ack-root-267-48-defaultmain-2of31 \
      --out /workspace/scratch/mythic413-NW-walk-guides-<new-id>

Uncalibrated human motion scaffold, NOT character art or acceptance evidence.
Use source portrait for identity/colors/one-weapon topology. No equipment is
invented here. Six labels match the saved contract; contact chronology and loop
timing are HOLD until actual source/motion review. No gait PASS is asserted.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

PAUSE = Path('/workspace/scratch/twilight-authoring-pause')
ROOT = Path('/workspace/twilight')
F = (-1 / math.sqrt(2), 1 / math.sqrt(2), 0.)  # literal NW, back 3/4
A = (-F[1], F[0], 0.)  # anatomical LEFT; near for camera from world south
UP = (0., 0., 1.)
ELEV = math.radians(35.264389682754654)
SCALE = 1.3
CELL = 512
ATLAS = (1024, 1536)
# Fixed WORLD lengths; provisional ratios, never measured identity claims.
THIGH, SHIN, FOOT = 61., 61., 24.
UPPER_ARM, FOREARM = 40., 38.
PELVIS_Z, HIP_HALF, SHOULDER_HALF = 110., 14., 23.
TORSO, NECK, HEAD_RADIUS = 70., 12., 17.
PHASES = (
 ('left_support_right_forward_contact', 'L', -12., 6., 0., 24., 8.05212086, 20.),
 ('left_support_midstance_right_passage', 'L', -12., 6., 0., 0., 27., 8.),
 ('left_to_right_support_transfer', 'R', -30., 13.60712871, -25., 24., 6., 0.),
 ('right_support_left_forward_contact', 'R', 24., 8.05212086, 20., -12., 6., 0.),
 ('right_support_midstance_left_passage', 'R', 0., 27., 8., -12., 6., 0.),
 ('right_to_left_support_transfer', 'L', 24., 6., 0., -30., 13.60712871, -25.),
)
def add(a,b): return tuple(x+y for x,y in zip(a,b))
def sub(a,b): return tuple(x-y for x,y in zip(a,b))
def mul(a,s): return tuple(x*s for x in a)
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def norm(a): return math.sqrt(dot(a,a))
def unit(a):
    n=norm(a)
    if n<1e-9: raise ValueError('degenerate direction')
    return mul(a,1/n)
def project(p):
    # Camera from south; +X screen right, +Y away/screen up, +Z up.
    return (256+SCALE*p[0],400-SCALE*(math.sin(ELEV)*p[1]+math.cos(ELEV)*p[2]))
def solve_joint(start,end,l1,l2,bend):
    delta=sub(end,start); dist=norm(delta)
    if not abs(l1-l2)+1e-7<dist<l1+l2-1e-7:
        raise ValueError('unreachable target; never stretch a bone')
    axis=unit(delta); along=(l1*l1-l2*l2+dist*dist)/(2*dist)
    normal=unit(sub(bend,mul(axis,dot(bend,axis))))
    joint=add(add(start,mul(axis,along)),mul(normal,math.sqrt(max(0,l1*l1-along*along))))
    assert abs(norm(sub(joint,start))-l1)<1e-7
    assert abs(norm(sub(end,joint))-l2)<1e-7
    return joint

def make_pose(index):
    label,support,ls,lz,lp,rs,rz,rp=PHASES[index]
    pelvis=(0.,0.,PELVIS_Z); chest=add(pelvis,mul(UP,TORSO))
    points={'pelvis':pelvis,'chest':chest,'neck':add(chest,mul(UP,NECK))}
    points['head']=add(points['neck'],mul(UP,HEAD_RADIUS))
    segments=[('pelvis','chest'),('chest','neck')]
    for side,sign,advance,ankle_z,pitch in [('L',1,ls,lz,lp),('R',-1,rs,rz,rp)]:
        hip=add(pelvis,mul(A,sign*HIP_HALF))
        ankle=add(add(mul(A,sign*HIP_HALF),mul(F,advance)),mul(UP,ankle_z))
        knee=solve_joint(hip,ankle,THIGH,SHIN,F)
        shoulder=add(chest,mul(A,sign*SHOULDER_HALF))
        # Neutral arms are schematic and deliberately do not assign a grip.
        wrist=add(add(shoulder,mul(UP,-65.)),mul(F,-6.))
        elbow=solve_joint(shoulder,wrist,UPPER_ARM,FOREARM,mul(F,-1.))
        points.update({side+'_hip':hip,side+'_knee':knee,side+'_ankle':ankle,
                       side+'_shoulder':shoulder,side+'_elbow':elbow,side+'_wrist':wrist})
        angle=math.radians(pitch)
        for name,offset in [('heel',-6.),('toe',18.)]:
            points[side+'_'+name]=add(add(ankle,mul(F,offset*math.cos(angle))),mul(UP,offset*math.sin(angle)-6.))
        assert abs(norm(sub(points[side+'_toe'],points[side+'_heel']))-FOOT)<1e-7
        segments += [(side+'_hip',side+'_knee'),(side+'_knee',side+'_ankle'),
                     (side+'_heel',side+'_toe'),('chest',side+'_shoulder'),
                     (side+'_shoulder',side+'_elbow'),(side+'_elbow',side+'_wrist')]
    segments += [('L_hip','R_hip')]
    # near/far is camera depth, never screen-left/right limb renaming.
    assert points['L_hip'][1] < points['R_hip'][1]
    return {'phase':index,'contract':label,'weight_support':support,
            'anatomical_near':'L','anatomical_far':'R',
            'points_world':points,'points_cell':{k:project(v) for k,v in points.items()},
            'segments':segments,'weapon':'HOLD: portrait-verified hand/topology required; no invented guide weapon',
            'timing_and_contact_continuity':'HOLD: pose intentions only'}

def render(out):
    from PIL import Image, ImageDraw
    poses=[make_pose(i) for i in range(6)]
    # Diagram palette is semantic only; never an authority for character colors.
    atlas=Image.new('RGBA',ATLAS,(0,0,0,0))
    for pose in poses:
        panel=Image.new('RGBA',(CELL,CELL),(0,0,0,0)); draw=ImageDraw.Draw(panel)
        p=pose['points_cell']
        # Far anatomical right first, near left last; no mirror operation.
        for side,ink in [('R',(140,140,140,255)),('',(75,75,75,255)),('L',(20,20,20,255))]:
            for a,b in pose['segments']:
                group='R' if a.startswith('R_') or b.startswith('R_') else 'L' if a.startswith('L_') or b.startswith('L_') else ''
                if group==side: draw.line([p[a],p[b]],fill=ink,width=3)
        hx,hy=p['head']; radius=HEAD_RADIUS*SCALE
        draw.ellipse((hx-radius,hy-radius,hx+radius,hy+radius),outline=(20,20,20,255),width=2)
        # Heading indicator is a pose diagram annotation, never character art.
        c=p['chest']; tip=project(add(pose['points_world']['chest'],mul(F,27.)))
        draw.line([c,tip],fill=(20,20,20,255),width=3)
        draw.text((100,100),f"NW WALK {pose['phase']} | L near / R far",fill=(20,20,20,255))
        draw.text((100,115),'POSE GUIDE ONLY - IDENTITY FROM PORTRAIT',fill=(20,20,20,255))
        index=pose['phase']; atlas.alpha_composite(panel,((index%2)*CELL,(index//2)*CELL))
    out=Path(out).resolve()
    if not out.is_relative_to(Path('/workspace/scratch')): raise SystemExit('scratch output only')
    out.mkdir(exist_ok=False)
    atlas.save(out/'NW-walk-fixedboneguide.png')
    (out/'NW-walk-fixedboneguide.json').write_text(json.dumps({'status':'GUIDE_ONLY_NOT_APPROVAL','poses':poses},indent=2)+'\n')
    return out/'NW-walk-fixedboneguide.png'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--render-png',action='store_true')
    parser.add_argument('--ack-root-267-48-defaultmain-2of31',action='store_true')
    parser.add_argument('--out')
    args=parser.parse_args()
    if not args.render_png:
        print('PREPARED_ONLY: no files/images emitted. 413 NW walk_5, six poses; calibration/identity/timing HOLD.')
        return
    if PAUSE.exists(): raise SystemExit('HOLD: existing authoring pause is present')
    if not args.ack_root_267_48_defaultmain_2of31 or not args.out:
        raise SystemExit('HOLD: require ROOT release after 267 all 48 + actual default Main PASS, 2/31, then new scratch out')
    print(render(args.out))
if __name__=='__main__': main()
