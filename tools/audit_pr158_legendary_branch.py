"""Read-only whole-corpus audit of an unmerged legendary branch; never promotes approval."""
import argparse,hashlib,io,json,re,subprocess
from collections import OrderedDict
from pathlib import Path
from PIL import Image

def run(ref):
    sha=subprocess.check_output(['git','rev-parse',ref],text=True).strip()
    proc=subprocess.Popen(['git','cat-file','--batch'],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
    def blob(path):
        proc.stdin.write((sha+':'+path.removeprefix('res://')+'\n').encode());proc.stdin.flush()
        header=proc.stdout.readline().decode().split()
        if header[-1]=='missing':raise FileNotFoundError(path)
        data=proc.stdout.read(int(header[2]));proc.stdout.read(1);return data
    manifest=json.loads(blob('data/pr122_legendary_parallel_staging.json'))
    libpath=manifest['corrections']['active_revision_library'];libbytes=blob(libpath)
    assert hashlib.sha256(libbytes).hexdigest()==manifest['corrections']['active_revision_library_sha256']
    revisions={tuple(r['slot']):r for r in json.loads(libbytes)['revisions']}
    rows=[];textures={};missing=[];alpha_cache=OrderedDict()
    for actor in manifest['actors']:
        slots={(d['direction'],d['role']) for d in actor['drafts']}
        for direction,role in manifest['production_order']:
            if (direction,role) not in slots:missing.append([actor['key'],direction,role])
        for draft in actor['drafts']:
            key=(actor['key'],draft['direction'],draft['role']);selected=revisions.get(key,draft)
            path=selected['SpriteFrames'];raw=blob(path);errors=[]
            if hashlib.sha256(raw).hexdigest()!=selected['SpriteFrames_sha256']:errors.append('FRAMES_PIN_MISMATCH')
            text=raw.decode();ext={ident:path for path,ident in re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]',text)}
            regions=[]
            for atlas,rect in re.findall(r'atlas = ExtResource\("([^"]+)"\)\nregion = Rect2\(([^)]+)\)',text):
                tp=ext[atlas]
                if tp not in textures:
                    data=blob(tp)
                    with Image.open(io.BytesIO(data)) as im:im.verify()
                    with Image.open(io.BytesIO(data)) as im:size=im.size
                    textures[tp]={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'size':size}
                x,y,w,h=map(float,rect.split(','));iw,ih=textures[tp]['size']
                if tp not in alpha_cache:
                    with Image.open(io.BytesIO(blob(tp))) as im:alpha_cache[tp]=im.convert('RGBA').getchannel('A').point(lambda v:255 if v>16 else 0)
                    if len(alpha_cache)>4:alpha_cache.popitem(last=False)
                alpha_cache.move_to_end(tp)
                box=alpha_cache[tp].crop(tuple(map(int,(x,y,x+w,y+h)))).getbbox()
                if box is None:errors.append('EMPTY_VISIBLE_POSE')
                if min(x,y)<0 or min(w,h)<=0 or x+w>iw or y+h>ih:errors.append('REGION_BOUNDS')
                regions.append({'texture':tp,'region':[x,y,w,h],'visible_alpha_bounds':box,'edge_review_flag':bool(box and (box[0]==0 or box[1]==0 or box[2]==w or box[3]==h))})
            if len(regions)!=6:errors.append('EXPECTED_SIX_REGIONS')
            rows.append({'slot':key,'selected_frames':path,'frames_sha256':hashlib.sha256(raw).hexdigest(),'active_revision':key in revisions,'regions':regions,'technical_errors':errors,'final_approved':False})
        print(actor['key'],len(rows),flush=True)
    proc.stdin.close();proc.wait()
    return {'source_sha':sha,'scope':'Read-only actual Git blobs, all active selected legendary revisions. PNG verification and region bounds are not visual or gameplay approval. No branch merge or runtime integration.','required':1320,'selected':len(rows),'missing':missing,'active_revision_slots':len(revisions),'texture_files':len(textures),'technical_error_clips':sum(bool(r['technical_errors']) for r in rows),'alpha_edge_flags':sum(f['edge_review_flag'] for r in rows for f in r['regions']),'edge_flags_are_not_automatic_defects':True,'new_final_approvals':0,'rows':rows,'textures':textures}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--ref',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=run(a.ref);a.output.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('DONE',r['selected'],'missing',r['missing'],'errors',r['technical_error_clips'])
