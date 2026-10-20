from pathlib import Path
B=Path(__file__).parent;p=B/'author-own-S-ATTACK6-final-complete-whitepuff-cloak-and-skin-joint-v06.py';s=p.read_text();s=s.replace("D=B/'actual-S-ATTACK6-own-native-articulated-rig-v06'","D=B/'actual-S-ATTACK6-own-native-articulated-rig-v07'").replace('actual-native-v06.png','actual-native-v07.png').replace('HOLD-contract-v06.json','HOLD-contract-v07.json').replace('map_coordinates,label,binary_closing','map_coordinates,label,binary_closing,distance_transform_edt').replace('import numpy as np,json,math,hashlib','import numpy as np,json,math,hashlib\nfrom scipy.spatial import cKDTree')
s=s.replace("visible=ellipse&closed&exposed;py,px=np.where(visible)","ba=np.array(body);la=np.array(lu);bm=ba[:,:,3]>100;lm=la[:,:,3]>100;db=distance_transform_edt(bm);dl=distance_transform_edt(lm);nb=distance_transform_edt(~bm);nl=distance_transform_edt(~lm);internal=ellipse&(distance_transform_edt(closed)>2);innerEdge=internal&(((bm&(db<3.6))&(nl<6))|((lm&(dl<3.6))&(nb<6)));visible=(ellipse&closed&exposed)|innerEdge;py,px=np.where(visible)")
old="rgba=np.stack([map_coordinates(skinOriginal[:,:,k].astype(float),[sy,sx],order=1,mode='constant',cval=0)for k in range(4)],1);cap[py,px]=np.uint8(np.clip(rgba+.5,0,255));barr=np.array(body);barr[py,px]=cap[py,px];body=Image.fromarray(barr)"
new="""rgba=np.stack([map_coordinates(skinOriginal[:,:,k].astype(float),[sy,sx],order=1,mode='constant',cval=0)for k in range(4)],1)
  # Match the photographed skin lighting on both actual joint surfaces; preserve fine own-source skin detail.
  neighbors=[]
  for surface in [ba,la]:
   rgb=surface[:,:,:3].astype(float);skinmask=ellipse&(surface[:,:,3]>150)&(rgb[:,:,0]>120)&(rgb[:,:,1]>90)&(rgb[:,:,2]>65)&(rgb[:,:,0]<rgb[:,:,1]*1.8)&(rgb[:,:,2]<rgb[:,:,1]*1.05);qy,qx=np.where(skinmask)
   if len(qx):
    dist,ids=cKDTree(np.column_stack((qx,qy))).query(np.column_stack((px,py)));neighbors.append((dist,surface[qy[ids],qx[ids],:3].astype(float)))
  if len(neighbors)==2:
   d0,c0=neighbors[0];d1,c1=neighbors[1];basecolor=(c0*(d1+.5)[:,None]+c1*(d0+.5)[:,None])/(d0+d1+1)[:,None];donor=skinOriginal[skinInput['source_opaque_skin_center'][1],skinInput['source_opaque_skin_center'][0],:3].astype(float);rgba[:,:3]=basecolor+.15*(rgba[:,:3]-donor)
  cap[py,px]=np.uint8(np.clip(rgba+.5,0,255));barr=np.array(body);barr[py,px]=cap[py,px];body=Image.fromarray(barr)"""
assert old in s;s=s.replace(old,new).replace("'original_opaque_visible_skin_modified':False","'original_raw_source_modified':False,'opaque_internal_old_part_outline_retouched_pixels':int((innerEdge&(ea[:,:,3]>=100)).sum()),'true_outer_skin_silhouette_outline_modified':False,'retouch_scope':'Broad bone-coherent actual-skin joint surface; only exposed joint and now-internal photographed part-edge contour. Neighbor body and upperarm actual skin lighting with15percent original donor fine texture. No line or root fit.'")
q=B/'author-own-S-ATTACK6-complete-whitepuff-and-continuous-natural-skin-joint-v07.py';q.write_text(s)
