"""Propose, never approve, source-pinned anatomical registration review sheets.

Alpha statistics are proposals only. Each frame requires a visual semantic review
(or an explicit correction) before production use. Original pixels remain intact.
"""
import argparse,hashlib,io,json,re,subprocess
from collections import OrderedDict,defaultdict
from pathlib import Path
import numpy as np
from scipy import ndimage
from PIL import Image,ImageDraw


def prepare(root,out):
    out.mkdir(parents=True,exist_ok=False)
    audit=json.loads((root/'docs/remake/evidence/pr122-final-approval-20261025/legendary-batch/selected-metadata-audit.json').read_text())
    proc=subprocess.Popen(['git','cat-file','--batch'],cwd=root,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
    cache=OrderedDict();pins={}
    def blob(path):
        path=path.removeprefix('res://')
        proc.stdin.write((audit['source_sha']+':'+path+'\n').encode());proc.stdin.flush();h=proc.stdout.readline().split()
        assert h[-1]!=b'missing',path
        data=proc.stdout.read(int(h[2]));assert proc.stdout.read(1)==b'\n'
        pins[path]=hashlib.sha256(data).hexdigest();return data
    def image(path):
        if path not in cache:
            cache[path]=Image.open(io.BytesIO(blob(path))).convert('RGBA')
            while len(cache)>40:cache.popitem(last=False)
        cache.move_to_end(path);return cache[path]
    def parse(row):
        raw=blob(row['selected_frames']);assert hashlib.sha256(raw).hexdigest()==row['sha256'];s=raw.decode()
        ext={i:p for p,i in re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]',s)}
        poses={}
        for key,part in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\](.*?)(?=\n\[|\Z)',s,re.S):
            path=ext[re.search(r'atlas = ExtResource\("([^"]+)"\)',part)[1]]
            rect=[float(v) for v in re.search(r'region = Rect2\(([^)]+)\)',part)[1].split(',')]
            margin=[float(v) for v in re.search(r'margin = Rect2\(([^)]+)\)',part)[1].split(',')]
            poses[key]=(path,rect,margin)
        order=re.findall(r'"texture": SubResource\("([^"]+)"\)',s.split('[resource]')[1]);assert len(order)==6
        return [poses[k] for k in order]
    actors=defaultdict(list)
    for r in audit['rows']:actors[r['slot'][0]].append(r)
    manifest={'source_sha':audit['source_sha'],'status':'PROPOSALS_NOT_APPROVED','policy':'No alpha/bbox-derived point is a reviewed anatomical foot until individually reviewed in source context','actors':{},'pins':pins}
    for key,rows in actors.items():
        records=[];heights=defaultdict(list);tiles=[]
        for row in rows:
            role=row['slot'][2];direction=row['slot'][1];frames=[]
            for phase,(path,region,margin) in enumerate(parse(row)):
                x,y,w,h=map(int,region);crop=image(path).crop((x,y,x+w,y+h));a=np.asarray(crop)[:,:,3]
                ys,xs=np.nonzero(a>=128);assert len(xs)
                # Restrict the proposal to opaque mass in the central body band;
                # weapons/effects can still fool this. Review is mandatory.
                solid=a>=192
                sy,sx=np.nonzero(solid)
                top,bottom=float(np.quantile(sy,.005)),float(np.quantile(sy,.9995))
                lower=solid.copy();lower[:int(top+(bottom-top)*.76),:]=False
                labels,count=ndimage.label(lower)
                candidates=[]
                for label,sl in enumerate(ndimage.find_objects(labels),1):
                    if sl is None:continue
                    mask=labels[sl]==label
                    if mask.sum()<max(8,solid.sum()*.001):continue
                    ly,lx=np.nonzero(mask);end=ly.max()
                    candidates.append((float(sl[1].start+np.median(lx[ly>=end-3])),float(sl[0].start+end),int(mask.sum())))
                # Midpoint of the substantial lower-body components, not one
                # lowest foot; detached/weapon components still require review.
                if candidates:
                    largest=max(c[2] for c in candidates)
                    feet=[c for c in candidates if c[2]>=largest*.15]
                    foot_x=(min(c[0] for c in feet)+max(c[0] for c in feet))*.5
                    foot_y=sum(c[1] for c in feet)/len(feet)
                else:foot_x=float(np.median(sx));foot_y=bottom
                mid=solid.copy();mid[:int(top+(bottom-top)*.2),:]=False;mid[int(top+(bottom-top)*.65):,:]=False
                my,mx=np.nonzero(mid);cx=float(np.median(mx)) if len(mx) else float(np.median(sx))
                half=max(6.,(float(np.quantile(sx,.8))-float(np.quantile(sx,.2)))*.25)
                central=solid[:,max(0,int(cx-half)):min(a.shape[1],int(cx+half)+1)]
                cy,cxx=np.nonzero(central)
                head_y=float(np.quantile(cy,.005)) if len(cy) else top
                body_height=max(1.,foot_y-head_y)
                heights[path].append(body_height)
                frames.append({'index':phase,'source':path,'source_sha256':pins[path.removeprefix('res://')],'region':region,'margin':margin,'proposal_anchor_in_region':[round(foot_x,2),round(foot_y,2)],'proposal_body_height':round(body_height,2),'semantic_review':'PENDING','role':role,'direction':direction})
                # Fixed original-crop fit, with proposal marks in original coordinates.
                fit=min(150/crop.width,152/crop.height)
                tile=Image.new('RGB',(160,184),(38,43,49));small=crop.resize((max(1,round(crop.width*fit)),max(1,round(crop.height*fit))))
                ox=(160-small.width)//2;oy=22+(152-small.height)//2;tile.paste(small,(ox,oy),small)
                draw=ImageDraw.Draw(tile);ax=ox+foot_x*fit;ay=oy+foot_y*fit
                draw.line((ax-7,ay,ax+7,ay),fill=(0,255,160),width=1);draw.line((ax,ay-6,ax,ay+6),fill=(0,255,160),width=1)
                draw.text((3,3),f'{direction} {role} {phase}',fill='white')
                tiles.append(tile)
            records.append({'slot':row['slot'],'selected_frames':row['selected_frames'],'selected_frames_sha256':row['sha256'],'frames':frames})
        # A constant scale per actual source SHA is proposed, not per-frame fitting.
        for r in records:
            for f in r['frames']:f['proposal_scale']=round(110/float(np.median(heights[f['source']])),6)
        folder=out/key.replace(':','_');folder.mkdir()
        pages=[]
        for start in range(0,len(tiles),48):
            page=Image.new('RGB',(960,1472),(30,32,36))
            for n,t in enumerate(tiles[start:start+48]):page.paste(t,((n%6)*160,(n//6)*184))
            filename=f'page-{start//48:02}.png';page.save(folder/filename);pages.append({'file':filename,'first_clip':start//6,'clip_count':min(8,len(records)-start//6)})
        data={'actor':key,'status':'PENDING_SEMANTIC_REVIEW','clips':records,'pages':pages};(folder/'proposals.json').write_text(json.dumps(data,indent=2)+'\n')
        manifest['actors'][key]={'clips':len(records),'frames':sum(len(r['frames']) for r in records),'review':str((folder/'proposals.json').relative_to(out))}
        print(key,len(records),'clips proposed',flush=True)
    proc.stdin.close();proc.wait()
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--output',type=Path,required=True);a=p.parse_args();prepare(a.root.resolve(),a.output.resolve())
