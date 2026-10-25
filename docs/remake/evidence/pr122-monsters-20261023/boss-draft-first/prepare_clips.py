#!/usr/bin/env python3
"""Write the complete 33-clip first-pass queue from a dedicated boss source."""
import argparse
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
VIEWS=[('E','EAST pure right profile; nose and toes RIGHT; no front-facing chest. Anatomical RIGHT weapon arm is near/foreground, LEFT empty hand far.'),('SE','SOUTHEAST front three-quarter facing DOWN-RIGHT. Anatomical RIGHT weapon hand is screenLEFT, LEFT empty hand screenRIGHT.'),('S','SOUTH straight FRONT facing DOWN toward viewer. Anatomical RIGHT weapon hand is viewerLEFT, LEFT empty hand viewerRIGHT.'),('SW','SOUTHWEST front three-quarter facing DOWN-LEFT. Anatomical RIGHT weapon arm is far/screenLEFT, LEFT empty hand near/screenRIGHT.'),('W','WEST pure LEFT profile; nose and toes LEFT, not front chest. Anatomical RIGHT weapon arm is FAR, LEFT empty hand near/foreground.'),('NW','NORTHWEST REAR three-quarter facing UP-LEFT. Show broad back, not front chest. Anatomical RIGHT weapon arm is FAR/screenRIGHT, LEFT empty hand near/screenLEFT.'),('N','NORTH straight BACK facing UP away from viewer. Show back of head/torso. Anatomical RIGHT weapon hand is viewerRIGHT; LEFT empty hand viewerLEFT.'),('NE','NORTHEAST REAR three-quarter facing UP-RIGHT. Show back and right side. Anatomical RIGHT weapon arm is near/screenRIGHT, LEFT empty hand far/screenLEFT.')]
PHASES={
 'idle':'Six subtly distinct continuous alert breathing poses: neutral, inhale begins, chest/shoulders rise, peak breath, exhale, near-neutral settle. Grounded feet stay at fixed points; use mild cape/hair/wing motion, no whole-body translations.',
 'run':'Six clear locomotion poses in order: phase0 RIGHT leg contact, phase1 RIGHT leg compresses/LEFT free leg swings, phase2 RIGHT toeoff/LEFT knee drives, phase3 LEFT leg contact/RIGHT leg lifts, phase4 LEFT leg compresses/RIGHT free leg swings, phase5 LEFT toeoff/RIGHT knee drives. Clearly alternate anatomical support legs between0 and3. Planted sole LOWEST, lifted sole above it. Heavy grounded advance, not six copies of one crouch. For horse use a natural four-leg canter sequence, for spider alternating supported leg groups, for floating reaper rhythmic hovering robe propulsion without fake legs.',
 'attack':'Six distinct attack stages:0 ready stance,1 loaded anticipation,2 forward strike/contact extension,3 follow-through,4 recoil/recovery,5 guard restored. Preserve anatomical RIGHT weapon ownership; EMPTY LEFT hand stays visibly separate. Contact weapon extends forward toward facing enemy, not still overhead. Caster uses staff and free-hand spell thrust rather than changing to sword; unicorn lunges its single horn with grounded hindleg support; spider strikes with claws/front legs.',
 'hit':'Six distinct brief hit reactions and recovery:0 impact flinch,1 torso recoil,2 recoil peak,3 feet/body brace,4 recover,5 guard restored. Preserve body parts and weapon hand. No weapon swing interpreted as an attack, no dismemberment or loose floating parts.',
 'death':'Six non-graphic SOUTH death stages:0 wounded upright,1 knees/legs weaken,2 body descends,3 collapses,4 settles on ground,5 motionless full corpse. All armor/limbs/weapon/wings/tail remain attached or contiguous and fully visible. No gore, blood, dissolving particles or vanished body. Horse/spider collapse naturally with all limbs present.'}

def main():
    p=argparse.ArgumentParser();p.add_argument('slug');a=p.parse_args()
    plan=json.loads((HERE/'plan.json').read_text())
    actor=next(v for v in plan['actors'] if v['slug']==a.slug)
    source=HERE/a.slug/'raw/canonical-v01.png'
    assert source.exists()
    source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
    jobs=[]
    for role in ('idle','run','attack','hit','death'):
        for direction,view in VIEWS if role!='death' else [('S',VIEWS[2][1])]:
            prompt='Create a dedicated MYTHIC boss animation source sheet for exactly the supplied character, preserving its unique costume/materials/anatomy. '+actor['design']+'\nFixed camera throughout this sheet: '+view+'\nAction '+role.upper()+': '+PHASES[role]+'\nLayout is EXACTLY SIX separate complete poses in THREE COLUMNS and TWO ROWS (3x2), read row-major: TOP LEFT0, TOP MIDDLE1, TOP RIGHT2, BOTTOM LEFT3, BOTTOM MIDDLE4, BOTTOM RIGHT5. WIDE LANDSCAPE transparent canvas. Each full figure fits in the central45percent width and central60percent height of its own cell; huge clear gutters and outer margins. Keep head/body scale the same in all cells. All connected horns, cape, hair, weapons, wings, claws, tail and feet belong fully to their one pose, never reach another cell or canvas edge. Six distinct complete character bodies only, no detached fragments. TRUE empty alpha background, no floor/cast shadow/haze/aura/effects/grid/labels/text. Rotate in real3D for this view, never mirror the whole character or swap weapon hands. Full identity and silhouette at each phase; original source will be preserved exactly for whole-pose region extraction, not cut through fixed cell borders.'
            if a.slug in ('albino_unicorn','zenith_queen'):
                prompt+=' This creature has NO hand-held weapon; ignore humanoid weapon-side instructions. Preserve four horse legs or eight spider legs exactly as canonical identity.'
            job=dict(slug=a.slug,actor=actor['id'],clip=f'{direction}-{role}-v01',direction=direction,role=role,layout='phase_grid3',phase_count=6,reference_sha256=source_sha,request=dict(prompt=prompt,referenced_image_paths=[str(source)],transparent_background=True))
            path=HERE/a.slug/'requests'/f'{job["clip"]}.json'
            text=json.dumps(job,ensure_ascii=False,indent=2)+'\n'
            if path.exists():assert path.read_text()==text
            else:path.write_text(text)
            jobs.append(job)
    assert len(jobs)==33
    queue=HERE/a.slug/'draft-queue.json'
    text=json.dumps(jobs,ensure_ascii=False,indent=2)+'\n'
    if queue.exists():assert queue.read_text()==text
    else:queue.write_text(text)
    print(json.dumps(dict(slug=a.slug,clips=len(jobs),source_sha256=source_sha)))

if __name__=='__main__':main()
