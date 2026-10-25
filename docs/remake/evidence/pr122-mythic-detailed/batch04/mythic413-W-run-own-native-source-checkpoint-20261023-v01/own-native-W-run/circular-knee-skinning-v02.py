def warp_leg(name,bone):
    # Rotate around the shared knee. This preserves each texel's radius and
    # avoids the inner-knee collapse of linear matrix blending. The fixed
    # 200-native-pixel support belongs to the rig, not each frame's bounds.
    x0,y0,x1,y1 = 300,440,1080,1280
    wy,wx = np.mgrid[y0:y1,x0:x1]
    k0 = rest[name]['knee']
    k = bone['knee']
    U,L = bone['upper'],bone['lower']
    theta0 = math.atan2(U[1,0],U[0,0])
    theta1 = math.atan2(L[1,0],L[0,0])
    delta = (theta1-theta0+math.pi)%(2*math.pi)-math.pi
    span = 200.

    def forward(x,y,jacobian=False):
        t = np.clip((y-(k0[1]-span/2))/span,0.,1.)
        w = t*t*(3-2*t)
        theta = theta0+delta*w
        c,s = np.cos(theta),np.sin(theta)
        dx,dy = x-k0[0],y-k0[1]
        fx,fy = k[0]+c*dx-s*dy,k[1]+s*dx+c*dy
        if not jacobian:
            return fx,fy
        derivative = delta*6*t*(1-t)/span
        j00,j10 = c,s
        j01 = -s+derivative*(-s*dx-c*dy)
        j11 = c+derivative*(c*dx-s*dy)
        return fx,fy,j00,j01,j10,j11

    native_y,native_x = np.where(legs[name][:,:,3]>0)
    _,_,j00,j01,j10,j11 = forward(native_x,native_y,True)
    owned_minimum_jacobian = float((j00*j11-j01*j10).min())
    assert owned_minimum_jacobian>0, ('Native material fold',name,owned_minimum_jacobian)
    for original,target in [(rest[name]['hip'],bone['hip']),
                            (rest[name]['knee'],bone['knee']),
                            (rest[name]['heel'],bone['heel'])]:
        actual = np.array(forward(*original))
        assert np.linalg.norm(actual-target)<1e-8

    # Start at the circular mid-angle; solve the actual skinning map, keeping
    # the original inverse residual guard. No failed pixel is hidden.
    mid = theta0+delta/2
    cs,sn = math.cos(mid),math.sin(mid)
    sx = k0[0]+cs*(wx-k[0])+sn*(wy-k[1])
    sy = k0[1]-sn*(wx-k[0])+cs*(wy-k[1])
    for _ in range(40):
        fx,fy,j00,j01,j10,j11 = forward(sx,sy,True)
        det = j00*j11-j01*j10
        safe = np.where(abs(det)<0.0001,np.where(det<0,-0.0001,0.0001),det)
        dx = (j11*(fx-wx)-j01*(fy-wy))/safe
        dy = (-j10*(fx-wx)+j00*(fy-wy))/safe
        damping = np.minimum(1.,20./np.maximum(np.maximum(abs(dx),abs(dy)),1e-8))
        sx -= dx*damping
        sy -= dy*damping
    selected = map_coordinates(legs[name][:,:,3],[sy,sx],order=0,mode='constant',cval=0,prefilter=False)>0
    fx,fy = forward(sx,sy)
    inverse_error = float(max(np.max(abs(fx-wx)[selected]),np.max(abs(fy-wy)[selected])))
    assert inverse_error<0.0001, (name,inverse_error)
    small = sample(legs[name],sx,sy)
    alpha = np.array(small)[:,:,3]
    assert not np.any(np.r_[alpha[:3].ravel(),alpha[-3:].ravel(),alpha[:,:3].ravel(),alpha[:,-3:].ravel()]), 'Fixed leg support clipped'
    out = Image.new('RGBA',(SIZE,SIZE))
    out.paste(small,(x0+int(PAD[0]),y0+int(PAD[1])))
    bone['minimum_owned_skinning_jacobian'] = owned_minimum_jacobian
    bone['maximum_knee_radius_change'] = 0.
    return out,inverse_error
