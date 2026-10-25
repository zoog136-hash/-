"""Keep technical failures, visual review flags and final approval separate."""
import argparse,collections,hashlib,json
from functools import lru_cache
from pathlib import Path
from PIL import Image

def analyze(root,plan,report):
    @lru_cache(maxsize=4)
    def picture(path):
        with Image.open(root/path.removeprefix('res://')) as im:return im.convert('RGBA')
    files={};clips=[];failures=[];pins=[];totals=collections.defaultdict(collections.Counter)
    for resource in report['resources']:
        for error in resource['failures']:failures.append(dict(resource=resource['frames'],error=error))
        for name,clip in resource['clips'].items():
            bad=[];review=[]
            if clip['count']<=0:bad.append('EMPTY_CLIP')
            if clip['speed']<=0:bad.append('NONPOSITIVE_SPEED')
            for f in clip['frames']:
                for error in f['failures']:bad.append(f"{f['index']}:{error}")
                path=f.get('source_path')
                if not path:continue
                if path not in files:
                    p=root/path.removeprefix('res://');files[path]=dict(bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
                levels=f.get('atlas_levels',[])
                if len(levels)>1:
                    review.append(dict(frame=f['index'],reason='NESTED_ATLAS_REQUIRES_RENDER_REVIEW'));continue
                alpha=picture(path).getchannel('A')
                if levels:
                    x,y,w,h=map(int,levels[0]['region']);alpha=alpha.crop((x,y,x+w,y+h))
                bounds=alpha.getbbox()
                if bounds is None:bad.append(f"{f['index']}:TRANSPARENT_FRAME")
                else:
                    # Touching the selected region is a review signal, not proof of lost pixels.
                    strong=alpha.point(lambda v:255 if v>16 else 0).getbbox()
                    if strong and (strong[0]==0 or strong[1]==0 or strong[2]==alpha.width or strong[3]==alpha.height):
                        review.append(dict(frame=f['index'],reason='REGION_EDGE_REQUIRES_SOURCE_CONTEXT',bbox=list(strong)))
            row=dict(resource=resource['frames'],clip=name,frames=clip['count'],technical_failures=bad,visual_review_flags=review,final_quality_approval='NOT_GRANTED')
            clips.append(row)
            for error in bad:failures.append(dict(resource=resource['frames'],clip=name,error=error))
        for e in resource['entries']:
            count=totals[e['category']+':'+e['scope']];count['entries']+=1
            for r in e.get('resolved',[]):
                if not r['required']:continue
                count['required_requests']+=1
                count['resolved_requests']+=int(r['role_available'])
                count['missing_requests']+=int(not r['role_available'])
                count['walk_reuse_requests']+=int(r['existing_runtime_walk_fallback'])
                count['playback_invalid_frames']+=int(r.get('playback_invalid_frame',False))
                if r['role_available'] and not r.get('playback_observed_phases'):count['requested_clip_not_observed']+=1
    for group in plan['resources']:
        for e in group['entries']:
            expected=e.get('recorded_frames_sha256')
            if expected and e.get('recorded_frames')==e['frames'] and expected!=group['sha256']:
                pins.append(dict(id=e['id'],register=e['register'],frames=e['frames'],expected=expected,actual=group['sha256']))
    return dict(schema='pr122-approval-audit-summary-v1',source_head=plan['head'],counts={k:dict(v) for k,v in totals.items()},unique_resources=len(report['resources']),unique_clips=len(clips),unique_texture_files=len(files),technical_failures=failures,staging_pin_mismatches=pins,visual_review_flagged_clips=sum(bool(c['visual_review_flags']) for c in clips),new_quality_approvals=0,limitations=['Region edge is a review flag, not automatically clipping','No semantic heading/pose/foot-contact approval from alpha bounds','Deterministic ActorMotion replay is not final Main combat/contact approval','Excluded unique assets retain their previous approvals; no reauthoring','Parallel hero/legendary branch candidates remain unmerged dependencies']),dict(clips=clips,textures=files)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--plan',type=Path,required=True);p.add_argument('--report',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    summary,details=analyze(a.root,json.loads(a.plan.read_text()),json.loads(a.report.read_text()))
    a.output.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n');a.output.with_name('clip-findings.json').write_text(json.dumps(details,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k not in ['technical_failures','staging_pin_mismatches']},ensure_ascii=False));print('technical_failures',len(summary['technical_failures']),'pin_mismatches',len(summary['staging_pin_mismatches']))
