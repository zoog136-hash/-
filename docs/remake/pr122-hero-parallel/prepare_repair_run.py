#!/usr/bin/env python3
"""RUN-only repair using the existing hero pose detector; old actions stay intact."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

from prepare_generated_sources import analyze, sha

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'docs/remake/pr122-hero-parallel/evidence/remediation18-20261023'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--id', required=True)
    parser.add_argument('--reuse-id')
    args = parser.parse_args()
    sid = args.id
    stage = json.loads((ROOT/'data/pr122_hero_parallel_staging.json').read_text())
    assert not stage['remediation_18']['actors']['transform:'+sid]['final_approved']
    baseline = json.loads((BASE/'baseline-profiles.json').read_text())[sid]
    out = ROOT/'assets/actors/eight_direction/hero_parallel'/('hero_repair_'+sid)/'r001'
    out.mkdir(parents=True, exist_ok=True)
    palette = None
    if args.reuse_id:
        assert args.reuse_id == '2' and sid in ['110','167']
        original = ROOT/'assets/actors/eight_direction/hero_parallel/hero_repair_2/r001/source-layout.json'
        source = copy.deepcopy(json.loads(original.read_text())['sources']['run'])
        palette = dict(source_actor='2',hue_shift=.28 if sid=='110' else .63,
                       hue_low=.58,hue_high=.88,minimum_saturation=.25)
    else:
        evidence = BASE/('layout-'+sid)/sha(__file__)[:12]
        source = analyze(out/'raw/source-run.png','run',evidence/'run-ownership.png',production_draft=True)
        # Save production findings even when a required real pose is missing.
        (evidence/'source-analysis.json').write_text(json.dumps(source,indent=2)+'\n')
        good = lambda d: source['counts'][d] >= 6
        assert good(2) and good(6), ('MISSING_SIX_REAL_S_OR_N_RUN_POSES',source['counts'])
        mapping = {2:(2,False),6:(6,False)}
        for preferred,other in [(4,0),(3,1),(5,7)]:
            assert good(preferred) or good(other), ('MISSING_SIX_REAL_SIDE_RUN_POSES',preferred,other,source['counts'])
            chosen=preferred if good(preferred) else other
            mapping[preferred]=(chosen,chosen!=preferred)
            mapping[other]=(chosen,chosen!=other)
        original=source['poses'];canonical=[];source['heading_reuse']={}
        source['source_counts']=source['counts']
        for direction in range(8):
            selected,mirrored=mapping[direction]
            group=[copy.deepcopy(p) for p in original if p['direction']==selected]
            for pose in group:pose.update(direction=direction,mirrored_x=mirrored)
            canonical.extend(group)
            source['heading_reuse'][str(direction)]=dict(source_direction=selected,mirrored_x=mirrored)
        source['poses']=canonical;source['counts']=[6]*8
    # Each variant keeps its own original projected body size and profile.
    south=[p['rect'][3] for p in source['poses'] if p['direction']==2]
    target=float(baseline['height']);height=sorted(south)[len(south)//2]
    scale=min(target/height,1.0);ground=float(baseline['ground'])-16
    for pose in source['poses']:
        x,y,w,h=pose['rect'];rx,ry=pose['root_x'],pose['root_y']
        for extent,space in [(max(rx-x,x+w-rx),104),(ry-y,ground-8),(y+h-ry,224-ground-8)]:
            if extent>0:scale=min(scale,space/extent)
    source['unit_scale']=1.0
    fingerprint=hashlib.sha256((sha(__file__)+sha(Path(__file__).with_name('prepare_generated_sources.py'))+source['raw_sha256']+json.dumps(baseline,sort_keys=True)+str(palette)).encode()).hexdigest()
    layout=dict(schema='hero-run-repair-layout-v1',id=sid,baseline=baseline,
                folder='res://'+str(out.relative_to(ROOT))+'/',sources={'run':source},
                uniform_scale=scale,cell=224,pad=16,ground=ground,fingerprint=fingerprint,
                existing_non_run_actions='PRESERVED_EXACT_TEXTURE_REGION_DURATION_AND_TIMING',
                new_death_source_directions=0,final_approved=False)
    if palette:layout['palette_variant']=palette
    (out/'source-layout.json').write_text(json.dumps(layout,indent=2)+'\n')
    print('HERO_RUN_REPAIR_LAYOUT_WRITTEN id='+sid+' run_poses=48 new_source_pngs='+('0' if palette else '1'))


if __name__=='__main__':main()
