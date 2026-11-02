"""Verify a proposed display transform against independent original PNG route patches.

The result permits existing legacy navigation inspection only, never M terrain bits.
"""
import argparse,hashlib,json
from pathlib import Path
from PIL import Image
import numpy as np
from scipy.signal import fftconvolve
from scipy.ndimage import gaussian_filter,uniform_filter
Image.MAX_IMAGE_PIXELS=180000000
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('pack',type=Path);parser.add_argument('--reference',type=Path,required=True);parser.add_argument('--plan',type=Path,required=True);parser.add_argument('--review',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
root=args.pack;m=json.load(open(root/'map.json'));raw=Image.new('RGBA',tuple(m['art']['size']))
for r in m['art']['chunks']:
 with Image.open(root/r['file']) as p:raw.paste(p,tuple(r['position']))
plan=json.load(open(args.plan));expected_sha=plan['sources']['13474.png']['sha256']
if hashlib.sha256(args.reference.read_bytes()).hexdigest()!=expected_sha:raise ValueError('Reference SHA mismatch')
if hashlib.sha256(raw.tobytes()).hexdigest()!=m['art']['pixel_sha256']:raise ValueError('Restored raster SHA mismatch')
ref=Image.open(args.reference).convert('RGB')
sx,sy=21504/19998,6912/6428;results=[]
for key in ['albino_01','albino_02']:
 for idx,(x,y) in enumerate(plan['maps'][key]['route_checks']):
  cx,cy=x*sx,y*sy-1536;left,top=round(cx)-128,round(cy)-128
  if left<16 or top<16 or left+272>raw.width or top+272>raw.height:continue
  template=ref.transform((256,256),Image.Transform.AFFINE,(1/sx,0,left/sx,0,1/sy,(top+1536)/sy),Image.Resampling.BICUBIC)
  search=raw.crop((left-12,top-12,left+268,top+268)).convert('RGB')
  t=np.asarray(template.convert('L'),dtype=float);a=np.asarray(search.convert('L'),dtype=float)
  t-=gaussian_filter(t,3);a-=gaussian_filter(a,3);t-=t.mean()
  corr=fftconvolve(a,t[::-1,::-1],mode='valid');energy=fftconvolve(a*a,np.ones(t.shape),mode='valid')-fftconvolve(a,np.ones(t.shape),mode='valid')**2/t.size
  ncc=corr/np.sqrt(np.maximum(energy*(t*t).sum(),1e-10));iy,ix=np.unravel_index(ncc.argmax(),ncc.shape)
  matched=np.asarray(search)[iy:iy+256,ix:ix+256];expected=np.asarray(template)
  mae=float(np.abs(matched.astype(float)-expected).mean());result={'map':key,'route_index':idx,'legacy_anchor':[x,y],'predicted_raw_anchor':[cx,cy],'residual_pixels':[int(ix)-12,int(iy)-12],'highpass_ncc':float(ncc[iy,ix]),'rgb_mae':mae};results.append(result);print(json.dumps(result),flush=True)
accepted=len(results)==16 and all(r['highpass_ncc']>=.4 and max(abs(v) for v in r['residual_pixels'])<=1 for r in results)
result={'schema':1,'status':'VERIFIED_VISUAL_REGISTRATION_LEGACY_NAV_ONLY' if accepted else 'REJECTED',
 'source_pixel_sha256':m['art']['pixel_sha256'],'reference_sha256':expected_sha,
 'plan_sha256':hashlib.sha256(args.plan.read_bytes()).hexdigest(),'review_sha256':hashlib.sha256(args.review.read_bytes()).hexdigest(),
 'scale':[sx,sy],'translation':[0,-1536],'accepted_legacy_maps':['albino_01','albino_02'] if accepted else [],
 'anchors':results,'registration_residual_budget_pixels':1,'terrain_rules_changed':False,
 'limits':'Coordinate registration corroborated at 16 original route patches. This preserves manually reviewed legacy collision; it does not establish original M passability, height, portal triggers or actor footprint.'}
args.out.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':result['status'],'anchors':len(results)}))
