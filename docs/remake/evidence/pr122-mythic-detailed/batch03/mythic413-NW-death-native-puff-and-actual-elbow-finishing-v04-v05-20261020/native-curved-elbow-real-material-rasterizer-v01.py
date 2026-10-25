def curved_elbow_surface(im,sourceS,sourceE,targetS,targetE,foreU,foreV,name):
 """One continuous original-RGBA sleeve; upper gold owns y<=540.

 The white native sleeve y540..570 is a smooth 3D surface between actual
 upperarm and forearm planes. A depth-buffered native UV mesh replaces the
 incompatible two straight material cuts. No new color or synthetic bridge.
 """
 from scipy.ndimage import map_coordinates
 sa=np.array(sourceS,float);se=np.array(sourceE,float);ts=np.array(targetS,float);te=np.array(targetE,float)
 sv=se-sa;slength=np.linalg.norm(sv);u=sv/slength;n=np.array([-u[1],u[0]]);T=(te-ts)/slength
 av=te-ts;cross=np.array([-av[1],av[0],0.]);cross/=np.linalg.norm(cross)
 U=T*u[0]+cross*n[0];V=T*u[1]+cross*n[1]
 fu=np.array(foreU);fv=np.array(foreV)
 def world(x,y):
  x,y=np.broadcast_arrays(np.asarray(x,float),np.asarray(y,float))
  upper=ts+(x-sa[0])[...,None]*U+(y-sa[1])[...,None]*V
  fore=te+(x-se[0])[...,None]*fu+(y-se[1])[...,None]*fv
  w=np.clip((y-540.)/30.,0,1);w=w*w*(3-2*w)
  return upper*(1-w[...,None])+fore*w[...,None]
 ar=np.asarray(im).astype(float)/255.;alpha=ar[:,:,3];ys,xs=np.where(alpha>0)
 x0=max(0,int(xs.min())-3);x1=min(N-1,int(xs.max())+3)
 y0=max(0,int(ys.min())-3);y1=min(N-1,int(ys.max())+3)
 gx=np.unique(np.r_[np.arange(x0,x1+1,5),x1]);gy=np.unique(np.r_[np.arange(y0,y1+1,5),y1,535,540,550,558,570])
 gy=gy[(gy>=y0)&(gy<=y1)];sx,sy=np.meshgrid(gx,gy);wp=world(sx,sy)
 tp=np.stack([wp[:,:,0]+PAD,ROOT[1]+CAM*wp[:,:,1]-wp[:,:,2]+PAD],axis=2)
 us=np.full((N,N),-100.,np.float32);vs=us.copy();depth=np.full((N,N),-np.inf,np.float32)
 triangles=0;degenerate=0
 for iy in range(len(gy)-1):
  for ix in range(len(gx)-1):
   for ids in [((iy,ix),(iy,ix+1),(iy+1,ix+1)),((iy,ix),(iy+1,ix+1),(iy+1,ix))]:
    q=np.array([tp[a,b]for a,b in ids]);s=np.array([[sx[a,b],sy[a,b]]for a,b in ids]);wq=np.array([wp[a,b]for a,b in ids])
    A=np.column_stack([q[1]-q[0],q[2]-q[0]]);det=np.linalg.det(A)
    if abs(det)<1e-7:degenerate+=1;continue
    lo=np.maximum(np.floor(q.min(axis=0)).astype(int),0);hi=np.minimum(np.ceil(q.max(axis=0)).astype(int),N-1)
    if np.any(hi<lo):continue
    tx,ty=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));b=np.linalg.inv(A)@np.stack([tx-q[0,0],ty-q[0,1]],axis=0).reshape(2,-1)
    b1=b[0].reshape(tx.shape);b2=b[1].reshape(tx.shape);b0=1-b1-b2;inside=(b0>=-1e-7)&(b1>=-1e-7)&(b2>=-1e-7)
    px=b0*s[0,0]+b1*s[1,0]+b2*s[2,0];py=b0*s[0,1]+b1*s[1,1]+b2*s[2,1]
    aa=map_coordinates(alpha,[py,px],order=1,mode='constant',cval=0,prefilter=False)
    cam=np.array([0.,1.,CAM]);dz=b0*(wq[0]@cam)+b1*(wq[1]@cam)+b2*(wq[2]@cam)
    take=inside&(aa>0)&(dz>=depth[ty,tx]-1e-6)
    if take.any():
     ry=ty[take];rx=tx[take];us[ry,rx]=px[take];vs[ry,rx]=py[take];depth[ry,rx]=dz[take]
    triangles+=1
 wa=map_coordinates(alpha,[vs,us],order=1,mode='constant',cval=0,prefilter=False)
 rgb=np.stack([map_coordinates(ar[:,:,k]*alpha,[vs,us],order=1,mode='constant',cval=0,prefilter=False)for k in range(3)],2)
 rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-8)
 out=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')
 actual=world(xs,ys);minimum=float(wp[:,:,2].min())
 surface_records.append(dict(name=name,kind='CONTINUOUS_ORIGINAL_RGBA_3D_UV_MESH',source_elbow_approx=se.tolist(),world_elbow=te.tolist(),upper_U=U.tolist(),upper_V=V.tolist(),fore_U=fu.tolist(),fore_V=fv.tolist(),source_white_transition_y=[540,570],source_goldband_y_le540_ownership='UPPER',source_distal_white_y_ge570_ownership='FORE',source_alpha_nonzero_pixels=int(len(xs)),actual_source_texel_min_Z=float(actual[:,2].min()),raster_support_guard_min_Z=minimum,guard_rule='Entire mesh vertex domain includes original actualalpha bbox plus3nativepx; every rasterized triangle barycentricZ>=vertexmin; transparent outside semantic UV',source_RGBA_colors='Original only, premultiplied native interpolation; no synthetic color',triangles=triangles,degenerate_triangles_skipped=degenerate,source_uv_bounds_padded=[x0,y0,x1,y1]))
 return out
